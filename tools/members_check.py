"""Catch `Type.member` where the member is declared, but on a different type (e.g. ChainMedia.x when x lives in
Transcriber). Only lines changed against origin/handytools are checked, so old code never blocks a push."""
import re, os, subprocess, glob

def strip(s):
    out = []; i = 0; n = len(s)
    while i < n:
        c = s[i]
        if s.startswith('//', i):
            j = s.find('\n', i); i = n if j < 0 else j; continue
        if s.startswith('/*', i):
            j = s.find('*/', i + 2); i = n if j < 0 else j + 2; continue
        if c == '"':
            # skip a string, honouring \( ... ) interpolation with nesting
            raw = s.startswith('"""', i); q = '"""' if raw else '"'; i += len(q); depth = 0
            while i < n:
                if depth == 0 and s.startswith(q, i): i += len(q); break
                if s[i] == '\\' and i + 1 < n:
                    if s[i + 1] == '(' : depth += 1; i += 2; continue
                    i += 2; continue
                if depth and s[i] == '(': depth += 1
                elif depth and s[i] == ')': depth -= 1
                i += 1
            out.append('""'); continue
        out.append(c); i += 1
    return ''.join(out)

def enclosing_types(s):
    """For each declared member name: the set of type names whose body (or extension) it sits directly in."""
    decl = re.compile(r'\b(enum|struct|class|extension|actor|protocol)\s+(\w+)[^{;\n]*\{')
    res = {}; stack = []; i = 0
    tokens = re.finditer(r'\{|\}|\b(?:enum|struct|class|extension|actor|protocol)\s+\w+[^{;\n]*\{|\b(?:static\s+|class\s+)?(?:func|let|var|case)\s+[^\n{}]*', s)
    for m in tokens:
        t = m.group(0)
        if t == '{': stack.append(None); continue
        if t == '}':
            if stack: stack.pop()
            continue
        d = decl.match(t)
        if d: stack.append(d.group(2)); continue
        owner = next((x for x in reversed(stack) if x is not None), None)
        depth_ok = stack and stack[-1] is not None   # directly in the type body, not inside a function
        if owner and depth_ok:
            if t.startswith('case'):
                names = re.findall(r'(?:case|,)\s*(\w+)', t)
            else:
                names = re.findall(r'(?:func|let|var)\s+`?(\w+)', t) + re.findall(r',\s*(\w+)\s*[:=]', t)
            for nm in names: res.setdefault(nm, set()).add(owner)
    return res

def check(root, ios, base='origin/handytools'):
    files = [f for f in glob.glob(os.path.join(ios, '**/*.swift'), recursive=True)]
    owners = {}; types = set()
    for f in files:
        s = strip(open(f, encoding='utf-8').read())
        types.update(re.findall(r'\b(?:enum|struct|class|actor)\s+(\w+)', s))
        for k, v in enclosing_types(s).items(): owners.setdefault(k, set()).update(v)
    # Swift only (the check is about Swift members); vendored C/C++ sources may not be UTF-8.
    diff = subprocess.run(['git', 'diff', '-U0', base, '--', 'ios/**/*.swift', 'ios/*.swift'], cwd=root, capture_output=True, text=True, errors='replace').stdout
    bad = []; cur = None; line = 0
    for d in diff.split('\n'):
        if d.startswith('+++ '): cur = d[6:] if d.startswith('+++ b/') else None; continue
        m = re.match(r'@@ -\d+(?:,\d+)? \+(\d+)', d)
        if m: line = int(m.group(1)); continue
        if cur and d.startswith('+') and not d.startswith('+++'):
            code = strip(d[1:])
            for r in re.finditer(r'(?<![\w.])([A-Z]\w+)\.([a-z_]\w*)\b(?!\s*:)', code):
                t, mem = r.group(1), r.group(2)
                if t in types and mem in owners and t not in owners[mem]:
                    bad.append(f"{cur}:{line}: {t}.{mem} — `{mem}` is declared on {', '.join(sorted(owners[mem]))}, not {t}")
            line += 1
    return bad
