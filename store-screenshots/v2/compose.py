#!/usr/bin/env python3
"""Compose the Nov 2026 store screenshots from real app captures.

Each frame = headline + one line + a real Tenzy capture in a device frame + feature chips that name what
else that screen does. Rendered with Playwright (Inter Display, local fonts) at exact store sizes:
  iPhone 6.9"  1290 x 2796   (App Store)
  iPad 13"     2064 x 2752   (App Store)
  Play phone   1080 x 1920   (Google Play; only from Android captures, see README)

Usage:
  python3 compose.py --captures DIR --out DIR [--device iphone|ipad|both]
Captures are named hero-iphone-<route>.png / hero-ipad-<route>.png (CI "Capture-Shots=YES" run).
A missing capture is skipped with a message, never faked.
"""
import argparse, base64, json, pathlib, sys
from playwright.sync_api import sync_playwright

HERE = pathlib.Path(__file__).parent
SIZES = {"iphone": (1290, 2796), "ipad": (2064, 2752)}
ACCENT = "#D2FF3A"


def data_url(p: pathlib.Path) -> str:
    return "data:image/png;base64," + base64.b64encode(p.read_bytes()).decode()


def page_html(f: dict, shot: str, device: str, w: int, h: int, index: int) -> str:
    ipad = device == "ipad"
    # Device box: the capture keeps its own aspect; the frame is sized from the canvas.
    dev_w = int(w * (0.74 if ipad else 0.70))
    radius = 64 if ipad else 96
    head_px = 150 if ipad else 128
    sub_px = 52 if ipad else 50
    chips = f.get("chips", [])
    bubble = ""
    if f.get("bubble"):
        steps = "".join(f'<span class="step">{s}</span>' + ('<span class="arrow">→</span>' if k < len(f["steps"]) - 1 else "")
                        for k, s in enumerate(f["steps"]))
        bubble = f'<div class="bubble">{f["bubble"]}<div class="steps">{steps}</div></div>'
    glow_x = 20 + (index * 37) % 60
    chip_html = "".join(f'<div class="chip">{c}</div>' for c in chips)
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family: Disp; src: local('Inter Display Bold'), local('InterDisplay-Bold'); font-weight: 700; }}
@font-face {{ font-family: Disp; src: local('Inter Display SemiBold'), local('InterDisplay-SemiBold'); font-weight: 600; }}
@font-face {{ font-family: Txt; src: local('Inter Medium'), local('Inter-Medium'); font-weight: 500; }}
* {{ box-sizing: border-box; margin: 0; }}
html, body {{ width: {w}px; height: {h}px; overflow: hidden; }}
body {{ background: #070912; color: #fff; font-family: Txt, 'Inter', sans-serif; display: flex; flex-direction: column; position: relative; }}
.bg {{ position: absolute; inset: 0; z-index: 0;
  background:
    radial-gradient(1200px 900px at {glow_x}% 6%, rgba(210,255,58,.22), transparent 60%),
    radial-gradient(1100px 1200px at {100-glow_x}% 78%, rgba(120,92,255,.30), transparent 62%),
    linear-gradient(180deg, #0B0E1D 0%, #070912 100%); }}
.top, .band, .stage {{ position: relative; z-index: 1; }}
.top {{ padding: {int(h*0.05)}px {int(w*0.075)}px 0; }}
h1 {{ font: 700 {head_px}px/1.02 Disp, sans-serif; letter-spacing: -3px; }}
.sub {{ margin-top: 30px; font-size: {sub_px}px; line-height: 1.3; color: rgba(255,255,255,.76); }}
.band {{ padding: {int(h*0.028)}px {int(w*0.06)}px 0; display: flex; flex-wrap: wrap; gap: 18px 16px; justify-content: center; }}
.chip {{ font: 600 {int(sub_px*0.74)}px Disp; padding: 18px 28px; border-radius: 999px; white-space: nowrap;
  background: rgba(20,24,42,.9); border: 2px solid rgba(210,255,58,.38); }}
.bubble {{ margin: 0 {int(w*0.06)}px; background: #fff; color: #0B0E1D; border-radius: 44px; padding: 38px 46px; font: 600 {int(sub_px*0.96)}px/1.3 Disp; }}
.steps {{ margin-top: 24px; display: flex; flex-wrap: wrap; gap: 12px; align-items: center; }}
.step {{ background: {ACCENT}; color: #0B0E1D; border-radius: 999px; padding: 12px 24px; font-size: {int(sub_px*0.76)}px; }}
.arrow {{ font-size: {int(sub_px*0.86)}px; color: #6a6f86; }}
.stage {{ flex: 1; overflow: hidden; margin-top: {int(h*0.03)}px; display: flex; justify-content: center; }}
.device {{ width: {dev_w}px; align-self: flex-start; border-radius: {radius}px; padding: {16 if ipad else 18}px;
  background: linear-gradient(160deg,#2c3044,#11131e);
  box-shadow: 0 60px 140px rgba(0,0,0,.65), 0 0 0 2px rgba(255,255,255,.08), 0 0 160px rgba(210,255,58,.12); }}
.device img {{ display: block; width: 100%; border-radius: {radius-16}px; }}
</style></head><body><div class="bg"></div>
<div class="top"><h1>{f["h"]}</h1><div class="sub">{f["sub"]}</div></div>
{f'<div class="band">{chip_html}</div>' if chips else ''}
{bubble and f'<div class="band" style="display:block">{bubble}</div>'}
<div class="stage"><div class="device"><img src="{shot}"></div></div>
</body></html>"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--captures", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--device", default="both")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    frames = json.loads((HERE / "frames.json").read_text())
    caps, out = pathlib.Path(a.captures), pathlib.Path(a.out)
    devices = ["iphone", "ipad"] if a.device == "both" else [a.device]
    made = 0
    with sync_playwright() as p:
        b = p.chromium.launch()
        for dev in devices:
            w, h = SIZES[dev]
            pg = b.new_page(viewport={"width": w, "height": h}, device_scale_factor=1)
            (out / dev).mkdir(parents=True, exist_ok=True)
            for i, f in enumerate(frames):
                if a.only and f["id"] not in a.only.split(","):
                    continue
                cap = caps / f"hero-{dev}-{f['route']}.png"
                if not cap.exists():
                    print(f"skip {dev} {f['id']}: no capture {cap.name}", file=sys.stderr); continue
                pg.set_content(page_html(f, data_url(cap), dev, w, h, i), wait_until="load")
                pg.screenshot(path=str(out / dev / f"{f['id']}.png"), full_page=False, omit_background=False)
                made += 1
        b.close()
    print(f"made {made} frames")


if __name__ == "__main__":
    main()
