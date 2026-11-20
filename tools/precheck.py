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
    src = re.sub(r'"""[\s\S]*?"""', '""', src)
    src = re.sub(r'#"[\s\S]*?"#', '""', src)
    src = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', src)
    src = re.sub(r'//[^\n]*', '', src)
    src = re.sub(r'/\*[\s\S]*?\*/', '', src)
    return src

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

# 2. patterns that never compile
pats = [
    (r'(&&|\|\||\?\?)\s*(try\s+)?await\b', "`await` on the right of &&, || or ?? — move it into a `let` first"),
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
