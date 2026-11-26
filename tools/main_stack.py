#!/usr/bin/env python3
"""Where the app's main thread is, from one macOS `sample` of the simulator app (read on stdin, demangled).

Prints nothing when the main thread is idle (waiting in its run loop). When it is busy — the app has stopped
answering, the way the how-to film froze at the end of a receipts Test run (26 Nov) — prints the hot path as
"HANG|" lines: only function names and modules, never data. Used by the iOS repro workflow.
"""
import re
import sys
import time

# Waiting in its own run loop is idle. Waiting anywhere else (a lock, a semaphore, a reply from another process) is
# the main thread stuck, and is printed.
IDLE = "__CFRunLoopServiceMachPort"


def main_thread_lines(text):
    lines, inside = [], False
    for ln in text.splitlines():
        if re.match(r"^    \d+ ", ln):          # a thread's header
            inside = "com.apple.main-thread" in ln
            if inside:
                lines.append(ln)
            continue
        if inside:
            if not ln.startswith("    +"):
                break
            lines.append(ln)
    return lines


def hot_path(lines):
    if not lines:
        return 0, []
    total = int(re.match(r"^    (\d+)", lines[0]).group(1))
    path = []
    for ln in lines[1:]:
        m = re.match(r"^    \+([ !:|+]*?)(\d+) (.*)$", ln)
        if not m:
            continue
        count, what = int(m.group(2)), m.group(3)
        if count < 0.6 * total:
            continue
        what = re.sub(r"\s*\[0x[0-9a-f]+(,0x[0-9a-f]+)*\]", "", what)
        what = re.sub(r"\s+\+ \d+$", "", what).strip()
        path.append((len(m.group(1)), count, what))
    return total, path


def main():
    total, path = hot_path(main_thread_lines(sys.stdin.read()))
    if not path:
        return
    if any(IDLE in p[2] for p in path):
        return
    stamp = time.strftime("%H:%M:%S")
    print(f"HANG| {stamp} main thread busy in {path[-1][1]}/{total} samples")
    for _, count, what in path[-40:]:
        print(f"HANG|   {count:>5} {what[:180]}")


if __name__ == "__main__":
    main()
