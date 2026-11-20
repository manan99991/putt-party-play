#!/usr/bin/env python3
"""Summarise simulator .ips crash reports: exception, thread names, and the crashed thread's frames
(app frames in full, system frames counted), so a deep-recursion crash shows which of our views loops."""
import json, sys, collections
for path in sys.argv[1:]:
    raw = open(path, encoding="utf-8", errors="replace").read()
    head, _, body = raw.partition("\n")
    try:
        d = json.loads(body)
    except Exception as e:
        print("==", path, "unreadable", e); continue
    imgs = d.get("usedImages", [])
    def img(i): return (imgs[i].get("name") if i is not None and i < len(imgs) else "?") or "?"
    print("==", path)
    print("exception:", d.get("exception"))
    for t in d.get("threads", []):
        if t.get("name"): print("thread name:", t["name"])
    ft = d.get("faultingThread", 0)
    frames = d["threads"][ft].get("frames", [])
    print("crashed thread frames:", len(frames))
    app = [f for f in frames if img(f.get("imageIndex")) in ("HandyTools", "HandyTools.debug.dylib")]
    print("app frames:", len(app))
    c = collections.Counter(f.get("symbol", "?") + "  [" + img(f.get("imageIndex")) + "]" for f in app)
    for s, n in c.most_common(40): print(f"{n:6d}  {s}")
    print("outermost 60 frames:")
    for f in frames[-60:]: print("   ", img(f.get("imageIndex")), f.get("symbol", "?"), f.get("sourceFile", ""), f.get("sourceLine", ""))
    sysc = collections.Counter(f.get("symbol", "?") for f in frames)
    print("most repeated:")
    for s, n in sysc.most_common(15): print(f"{n:6d}  {s}")
