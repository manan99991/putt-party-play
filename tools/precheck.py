#!/usr/bin/env python3
"""Checks that catch the mistakes that cost a whole CI round trip, in seconds, before a push.
Run: python3 tools/precheck.py   (exit 1 on any problem)

1. Share-sheet target: every type the share extension's files use must be defined in a file that target compiles
   (project.yml lists them by hand), or in its stand-ins (ShareExtension/EngineShims.swift).
2. Swift patterns that never compile: `if let (a, b) =`, `guard let (a, b) =`, `await` inside `&&`/`||`/`??`
   right-hand sides, `try await` inside an autoclosure.
3. Brace balance per file.
4. Every L("…") literal has a translation entry (warning only).
"""
import re, sys, glob, json, os
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ios = os.path.join(root, "ios")
bad = []

def strip(src):
    # One left-to-right pass (strings, raw strings, comments) — separate regex passes mistook "/#" in an
    # ordinary string for the start of a raw string.
    import members_check as _mc
    return _mc.strip(src)

files = glob.glob(os.path.join(ios, "**", "*.swift"), recursive=True)
code = {f: open(f, encoding="utf-8").read() for f in files}
clean = {f: strip(s) for f, s in code.items()}

decl = re.compile(r'^(?:(?:public|private|fileprivate|internal|final|@MainActor)\s+)*(?:enum|struct|class|protocol|actor|typealias)\s+([A-Z]\w*)', re.M)
defs = {}
for f, s in clean.items():
    for m in decl.finditer(s):
        defs.setdefault(m.group(1), set()).add(f)

# 1. share extension membership
proj = open(os.path.join(ios, "project.yml")).read()
sec = proj[proj.index("  ShareExtension:"):proj.index("  StickyWidget:")]
src_block = sec[sec.index("sources:"):sec.index("entitlements:")]
paths = [l.strip()[2:].strip() for l in src_block.splitlines() if l.strip().startswith("- ")]
members = set()
for pth in paths:
    full = os.path.join(ios, pth)
    if os.path.isdir(full):
        members |= {f for f in files if f.startswith(full + os.sep)}
    else:
        members.add(full)
member_defs = set()
anydecl = re.compile(r'\b(?:enum|struct|class|protocol|actor|typealias)\s+([A-Z]\w*)')
for f in members:
    for m in anydecl.finditer(clean.get(f, "")):
        member_defs.add(m.group(1))
member_defs |= set(re.findall(r'\bextension\s+([A-Z]\w*)', " ".join(clean.get(f, "") for f in members)))
app_types = {t for t, fs in defs.items() if fs and not (fs & members)}
for f in sorted(members):
    s = clean.get(f, "")
    used = set(re.findall(r'\b([A-Z]\w+)\s*(?:\.|\(|<|:|\])', s))
    for t in sorted(used & app_types - member_defs):
        bad.append(f"share extension: {os.path.relpath(f, ios)} uses {t}, defined only in {', '.join(os.path.relpath(x, ios) for x in defs[t])} — add that file to ShareExtension sources in project.yml or a stand-in in EngineShims.swift")

# 1c. Top-level functions too (L(...) for translations was missed once): a free function a share-extension file calls
# must be defined in a file that target compiles.
topfn = re.compile(r'^(?:@\w+\s+)*(?:private\s+|fileprivate\s+|internal\s+|public\s+)?func\s+(\w+)\s*[(<]', re.M)
fn_defs = {}
for f, s2 in clean.items():
    for m in topfn.finditer(s2): fn_defs.setdefault(m.group(1), set()).add(f)
member_fns = {n for n, fs in fn_defs.items() if fs & members}
app_fns = {n for n, fs in fn_defs.items() if not (fs & members)}
for f in sorted(members):
    # Calls inside string interpolation count too ("\\(L("Page"))"), so only comments are stripped here.
    s2 = re.sub(r'/\*[\s\S]*?\*/', '', re.sub(r'//[^\n]*', '', code.get(f, "")))
    for n in sorted(app_fns - member_fns):
        if re.search(r'(?<![\w.])' + re.escape(n) + r'\(', s2):
            bad.append(f"share extension: {os.path.relpath(f, ios)} calls {n}(), defined only in {', '.join(os.path.relpath(x, ios) for x in fn_defs[n])} — add that file to ShareExtension sources in project.yml")

import sys as _s0; _s0.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# 1b. stand-ins must have every member the extension's files call: `VideoEngine.run` used by SizeTarget (compiled
# into the share extension) must exist on the VideoEngine stand-in, not only on the app's VideoEngine.
shims = os.path.join(ios, "ShareExtension", "EngineShims.swift")
if os.path.exists(shims):
    import members_check as _mc
    shim_src = _mc.strip(open(shims, encoding="utf-8").read())
    shim_owned = _mc.enclosing_types(shim_src)
    shim_types = set(re.findall(r'\b(?:enum|struct|class|actor)\s+(\w+)', shim_src))
    for f in sorted(members):
        if f == shims: continue
        s2 = clean.get(f, "")
        own_types = set(re.findall(r'\b(?:enum|struct|class|actor|extension)\s+(\w+)', s2))
        for m in re.finditer(r'(?<![\w.])([A-Z]\w+)\.([a-z_]\w*)\s*\(', s2):
            t, mem = m.group(1), m.group(2)
            if t in shim_types and t not in own_types and t not in member_defs - shim_types and not (mem in shim_owned and t in shim_owned[mem]):
                bad.append(f"share extension: {os.path.relpath(f, ios)} calls {t}.{mem}, but the {t} stand-in in EngineShims.swift has no {mem}")

# 2. patterns that never compile
pats = [
    (r'(&&|\|\||\?\?)[\s(]*(try[?!]?\s+)?await\b', "`await` on the right of &&, || or ?? — move it into a `let` first"),
    (r'\bXCT(?:Unwrap|Assert\w*)\((?:try\s+)?await\b', "`await` inside an XCTest assertion (it's an autoclosure) — move it into a `let` first"),
]
for f, s in clean.items():
    for pat, why in pats:
        for m in re.finditer(pat, s):
            line = s[:m.start()].count("\n") + 1
            bad.append(f"{os.path.relpath(f, ios)}:{line}: {why}")
    # 3. braces: the open/close difference must not change from the last pushed version (string
    # interpolation makes the raw count fuzzy, so compare like with like).
    import subprocess
    rel = os.path.relpath(f, root)
    old = subprocess.run(["git", "show", f"origin/handytools:{rel}"], cwd=root, capture_output=True, text=True).stdout
    for o, c in (("{", "}"), ("(", ")")):
        now = s.count(o) - s.count(c)
        before = (strip(old).count(o) - strip(old).count(c)) if old else 0
        if now != before:
            # A push that slipped through with a broken file must be repairable: going back to the balance the
            # file had in one of the few versions before it is a repair, not a new imbalance.
            earlier = []
            for back in range(1, 4):
                prev = subprocess.run(["git", "show", f"origin/handytools~{back}:{rel}"], cwd=root, capture_output=True, text=True).stdout
                if prev: earlier.append(strip(prev).count(o) - strip(prev).count(c))
            if now in earlier:
                continue
            bad.append(f"{os.path.relpath(f, ios)}: '{o}{c}' balance changed ({before} → {now}) — a missing or extra {o if now > before else c}")

# 2b. a single-# raw string that contains "# closes early (#"href="#x"# ends at href=") — and a guard whose
# else-block is followed by ", name = value" (only a let/var list can continue with a comma).
for f in clean:
    for n, ln in enumerate(open(f, encoding="utf-8").read().split("\n"), 1):
        for m in re.finditer(r'(?<![#"])#"', ln):
            close = ln.find('"#', m.end())
            if close >= 0 and close + 2 < len(ln) and re.match(r'[\w\\<"/]', ln[close + 2]):
                bad.append(f"{os.path.relpath(f, ios)}:{n}: raw string #\"…\"# has a \"# inside it, so it ends early — use ##\"…\"## or a normal string")
        if re.match(r'\s*guard\b', ln) and re.search(r'\}\s*,\s*\w+\s*=', ln):
            bad.append(f"{os.path.relpath(f, ios)}:{n}: ', name = …' after a guard's else block doesn't compile — move it into the let above")

# 2c. `Type.member` where the member exists but on another type (ChainMedia.x when x is Transcriber's) — changed lines only.
import sys as _sys; _sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import members_check
bad += members_check.check(root, ios)

# 2d. The same type declared twice in one target (a test class added under a name another file already uses) —
# a whole CI compile round was lost to this on 21 Nov. Private/fileprivate types may repeat across files.
topdecl = re.compile(r'^(?!\s)(?:@\w+\s+)*(?:(public|internal|final|open)\s+)*(?:final\s+)?(class|struct|enum|actor|protocol)\s+([A-Z]\w*)', re.M)
for target in ("HandyTools", "HandyToolsTests", "HandyToolsUITests", "ShareExtension"):
    seen = {}
    for f, s2 in clean.items():
        if os.path.relpath(f, ios).split(os.sep)[0] != target: continue
        for m in topdecl.finditer(s2):
            seen.setdefault(m.group(3), []).append(os.path.relpath(f, ios))
    for name, fs in seen.items():
        if len(set(fs)) > 1:
            bad.append(f"{target}: {name} is declared in {', '.join(sorted(set(fs)))} — rename one")

# 4. translations
tr = json.load(open(os.path.join(ios, "HandyTools", "translations.json")))
miss = set()
for f, s in code.items():
    if "/HandyTools/" not in f: continue
    for m in re.finditer(r'\bL\("((?:[^"\\]|\\.)*)"\)', s):
        k = m.group(1)
        if "\\(" in k: continue
        k = k.replace('\\"', '"').replace("\\\\", "\\")
        if k.strip() and k not in tr and not re.fullmatch(r"[\W\d]*|[A-Za-z]{1,4}|[a-z./]+", k): miss.add(k)

for b in bad: print("✗", b)
if miss: print(f"! {len(miss)} strings without translations (run the translation pass):", "; ".join(sorted(miss)[:15]), "…" if len(miss) > 15 else "")
print("precheck:", "FAILED" if bad else "ok", f"({len(files)} files)")
sys.exit(1 if bad else 0)
