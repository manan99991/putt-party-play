#!/usr/bin/env python3
"""Store slides from today's app (Nov 21 2026): the personal-assistant positioning, the Aurora look.

Input: raw simulator captures named <mode>-<route>.png (as ScreenshotTests saves them).
Output: framed slides at the store sizes — iPhone 6.9" 1320x2868, iPad 13" 2064x2752. RGB, no alpha.

Rules from docs/rulebook.md §3: no tool counts, no "#1/best", no "free"/price/"no ads" on a slide, nothing the
build doesn't do. Each caption is a job the person has, not a feature list.

  python3 v3_slides.py --input shots/ --device iphone --output out/
"""
import argparse, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# (capture route, headline, supporting line, glow colour)
SLIDES = [
    ("home",                       "Say what you need.",        "Tenzy finds the way — or builds it.",            (210, 255, 58)),
    ("brief",                      "Your day, looked after.",   "Doses, bills, birthdays, weather — one note.",    (59, 130, 246)),
    ("medreminder",                "Medicines, remembered.",    "A Taken button, refills, a nudge if you miss one.", (34, 197, 94)),
    ("run-photo-to-pdf-b-done",    "Paper to PDF, properly.",   "Straightened, cleaned, searchable.",              (236, 72, 153)),
    ("run-receipt-to-row-b-done",  "Receipts, sorted.",         "Items and total, straight into your expenses.",   (20, 184, 166)),
    ("thinking",                   "Think it through.",         "Worries and choices, sorted into next steps.",    (34, 197, 94)),
    ("fitit",                      "Fits any upload limit.",    "Photo, video or PDF — just under the size.",      (139, 92, 246)),
    ("pdfsign",                    "Sign and send.",            "Signs right where the form asks.", (239, 68, 68)),
]

SIZES = {"iphone": (1320, 2868), "ipad": (2064, 2752)}
CROP = {"iphone": 1.0, "ipad": 0.58}
BG = (5, 4, 12)
FONT_B = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
FONT_R = "/usr/share/fonts/opentype/inter/Inter-Medium.otf"


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)


def rounded(img, r):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, img.width - 1, img.height - 1], r, fill=255)
    out = Image.new("RGBA", img.size)
    out.paste(img.convert("RGBA"), (0, 0), m)
    return out, m


def slide(capture, title, sub, glow, size, crop=1.0):
    W, H = size
    canvas = Image.new("RGB", (W, H), BG)
    # A soft glow in the job's colour behind the phone.
    g = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(g)
    cx, cy, rad = W // 2, int(H * 0.62), int(W * 0.55)
    d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=tuple(int(c * 0.45) for c in glow))
    canvas = Image.blend(canvas, g.filter(ImageFilter.GaussianBlur(W // 5)), 1.0)
    draw = ImageDraw.Draw(canvas)

    margin = int(W * 0.08)
    t_size = int(W * (0.088 if W < 1600 else 0.062))
    s_size = int(t_size * 0.46)
    ft, fs = font(FONT_B, t_size), font(FONT_R, s_size)
    y = int(H * 0.065)
    # Headline: wrap to the width.
    def wrap(text, f):
        words, line, lines = text.split(), "", []
        for w in words:
            test = (line + " " + w).strip()
            if draw.textlength(test, font=f) > W - 2 * margin and line:
                lines.append(line); line = w
            else:
                line = test
        return lines + [line]
    for ln in wrap(title, ft):
        draw.text((margin, y), ln, font=ft, fill=(255, 255, 255))
        y += int(t_size * 1.12)
    y += int(s_size * 0.4)
    # The supporting line wraps too: "Initials on every page." ran off the edge of the iPhone slide.
    for ln in wrap(sub, fs):
        draw.text((margin, y), ln, font=fs, fill=(210, 255, 58))
        y += int(s_size * 1.3)
    y += int(s_size * 0.6)

    # The screen: scaled to fit what's left, rounded, with a hairline and a shadow; bottom bleeds off the edge.
    shot = capture.convert("RGB")
    # An iPad screen holds an iPhone's worth of content spread thin; showing its top part makes the words readable.
    if crop < 1:
        # Fill the slide's width and let the screen run off the bottom, like the iPhone slides.
        fit = (W - 2 * int(W * 0.08)) / shot.width
        need = int((H - y + int(H * 0.06)) / fit)
        shot = shot.crop((0, 0, shot.width, min(shot.height, need)))
    avail_h = H - y + int(H * 0.06)
    scale = min((W - 2 * margin) / shot.width, avail_h / shot.height)
    sw, sh = int(shot.width * scale), int(shot.height * scale)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    r = int(sw * 0.075)
    rs, mask = rounded(shot, r)
    x0 = (W - sw) // 2
    sh_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh_layer).rounded_rectangle([x0, y + 30, x0 + sw, y + 30 + sh], r, fill=(0, 0, 0, 170))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), sh_layer.filter(ImageFilter.GaussianBlur(40)))
    canvas.paste(rs, (x0, y), mask)
    ImageDraw.Draw(canvas).rounded_rectangle([x0, y, x0 + sw - 1, y + sh - 1], r, outline=(255, 255, 255, 60), width=3)
    return canvas.convert("RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--device", choices=SIZES.keys(), default="iphone")
    ap.add_argument("--mode", default="dark")
    a = ap.parse_args()
    os.makedirs(a.output, exist_ok=True)
    n = 0
    for route, title, sub, glow in SLIDES:
        p = os.path.join(a.input, f"{a.mode}-{route}.png")
        if not os.path.exists(p):
            print("skip (no capture):", p); continue
        n += 1
        slide(Image.open(p), title, sub, glow, SIZES[a.device], CROP[a.device]).save(os.path.join(a.output, f"{a.device}-{n:02d}.png"))
    print(n, "slides")


if __name__ == "__main__":
    main()
