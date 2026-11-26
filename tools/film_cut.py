#!/usr/bin/env python3
"""Where to cut one how-to film, from the test's own clock.

The recorder runs for the whole test; the test marks FILM-START, FILM-END and any FILM-PAUSE / FILM-RESUME pair with
the time it reached them ("FILM-START@1764160000.12"). Marks read off the build log arrive late and by a varying
amount (26 Nov: one film lost its first screen), so the cut uses the times inside the marks, not when they were seen.

Usage: film_cut.py <recorder start epoch> <marks file>
Prints: "<seconds into the recording to start> <seconds to keep> <ffmpeg select expression to drop, or ->"
"""
import sys


def plan(t0, marks):
    seen = {}
    for k, v in marks:
        seen.setdefault(k, []).append(v)
    start = min(seen["FILM-START"])
    end = min(v for v in seen["FILM-END"] if v > start)
    ss = max(0.0, start - t0 - 0.3)
    keep = end - t0 - ss
    pauses = sorted(set(seen.get("FILM-PAUSE", [])))
    resumes = sorted(set(seen.get("FILM-RESUME", [])))
    drops = []
    for p, r in zip(pauses, resumes):
        if r - p > 2:   # keep most of a second each side, so nothing jumps mid-tap
            drops.append(f"between(t,{p - t0 - ss + 0.8:.2f},{r - t0 - ss - 0.8:.2f})")
    return ss, keep, "+".join(drops) or "-"


def main():
    t0 = float(sys.argv[1])
    marks = []
    for line in open(sys.argv[2]):
        if "@" in line:
            k, v = line.strip().split("@", 1)
            try:
                marks.append((k, float(v)))
            except ValueError:
                pass
    ss, keep, drop = plan(t0, marks)
    print(f"{ss:.2f} {keep:.2f} {drop}")


if __name__ == "__main__":
    main()
