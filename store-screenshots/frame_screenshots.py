#!/usr/bin/env python3
"""HandyTools store screenshot framing pipeline (kit prompt 5).

Turns raw CI captures named like CI publishes them
    {platform}-{mode}-{route}.png      e.g. ios-light-home.png, android-dark-ocr.png
into framed store slides, six per platform.

Framing spec (from the product brief):
  - Canvas: iOS 1290x2796 (6.9"), Android 1080x2400 (Play). RGB, no alpha.
  - Background: solid #1F5EFF on odd slides, #0E0E12 on even slides.
  - Device frame: drawn flat bezel (iPhone-style with Dynamic Island / Pixel-style
    with punch-hole camera), height = 78% of canvas height, horizontally centered,
    bottom-anchored with 60px bleeding off the bottom edge. Capture fills the
    device screen (cover-crop).
  - Caption above the device: main line 72px bold white, tight tracking,
    left-aligned at 96px margin; one supporting line 36px white at 80% below it.
  - Slide 6 is a special split: free-state home (left half) + Pro-state home
    (right half), one slide.

Slide -> capture mapping (all captures come from the CI route lists):
  1 Home             = {platform}-light-home.png
  2 Alarm editor     = {platform}-light-alarm.png
                       (shows whatever the CI `alarm` route renders: alarm list/editor)
  3 Clipboard stack  = android-light-clipboard.png / ios-light-clips.png
  4 android "Grab the whole thing" = android-dark-screenshot.png
    ios                            = ios-dark-ocr.png
  5 android "See what's hidden"    = android-dark-volume.png
    ios                            = ios-dark-exif.png
  6 Free vs Pro split = {platform}-light-home.png (free, left)
                      + {platform}-light-homepro.png (pro, right).
    CI must add the pro-state capture named e.g. ios-light-homepro.png /
    android-light-homepro.png (same framing as home, captured in Pro state with
    the ad strip removed). If the pro capture is missing, slide 6 is skipped with
    a clear message and never faked.

Usage:
  python3 frame_screenshots.py [--input ./captures] [--output ./output]
  python3 frame_screenshots.py --plates          # 12 internal design plates

Missing inputs are skipped with a printed reason; exit code stays 0.
A platform zip (output/{ios,android}.zip) is written only when all 6 slides
for that platform are complete.
"""

import argparse
import io
import os
import sys
import zipfile
from PIL import Image, ImageDraw, ImageFont

BLUE = (0x1F, 0x5E, 0xFF)      # #1F5EFF
DARK = (0x0E, 0x0E, 0x12)      # #0E0E12
WHITE = (255, 255, 255)
WHITE80 = (204, 204, 204)      # white at 80%
BEZEL = (26, 26, 30)
BEZEL_IOS = (10, 10, 12)
GREY = (110, 114, 126)         # placeholder ink

BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

CANVAS = {"ios": (1290, 2796), "android": (1080, 2400)}
# device width/height ratios used for the drawn bezel
BEZEL_RATIO = {"ios": 0.467, "android": 0.446}
CAPTION_X = 96

SLIDES = [
    dict(n=1, caption="10 tools. One app.", support="The utilities your phone forgot.",
         route="home", mode="light"),
    dict(n=2, caption="Your snooze. Your rules.", support="Set the snooze length once.",
         route="alarm", mode="light"),
    dict(n=3, caption="Copy five. Paste any.", support="Clipboard history, stacked and ready.",
         route={"android": "clipboard", "ios": "clips"}, mode="light"),
    dict(n=4, caption="Grab the whole thing",
         support={"android": "Full-page screenshots, stitched.",
                  "ios": "Words lifted straight from the image."},
         route={"android": "screenshot", "ios": "ocr"}, mode="dark"),
    dict(n=5, caption="See what's hidden",
         support={"android": "Every volume, one desk.",
                  "ios": "Location and metadata, exposed."},
         route={"android": "volume", "ios": "exif"}, mode="dark"),
    dict(n=6, caption="Pro: ads gone. $9.99 a year.",
         support="Free on the left. Pro on the right.", split=True),
]


def route_of(x, platform):
    return x[platform] if isinstance(x, dict) else x


def load_capture(path):
    im = Image.open(path).convert("RGB")
    return im


def cover_into(im, box):
    """Cover-crop `im` into the (w, h) box."""
    w, h = box
    sw, sh = im.size
    scale = max(w / sw, h / sh)
    im = im.resize((int(sw * scale) + 1, int(sh * scale) + 1), Image.LANCZOS)
    x = (im.width - w) // 2
    y = (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


def draw_device(platform, scale_w, bleed=60, capture=None, placeholder=False):
    """Draw a bezel + screen and return (device_image, screen_offset).

    Device total width = scale_w; height from BEZEL_RATIO. The whole device is
    returned as an image whose bottom extends `bleed` px below where it will be
    pasted (caller pastes at canvas bottom + bleed offset).
    """
    dw = int(scale_w)
    dh = int(dw / BEZEL_RATIO[platform])
    dev = Image.new("RGB", (dw, dh), BEZEL_IOS if platform == "ios" else BEZEL)
    d = ImageDraw.Draw(dev)
    d.rounded_rectangle([0, 0, dw - 1, dh - 1], radius=int(dw * 0.115), fill=BEZEL)
    inset = max(4, int(dw * 0.028))
    d.rounded_rectangle([inset, inset, dw - 1 - inset, dh - 1 - inset],
                        radius=int(dw * 0.09), fill=(0, 0, 0))
    sw, sh = dw - 2 * inset, dh - 2 * inset
    if capture is not None:
        screen = cover_into(capture, (sw, sh))
    else:
        screen = Image.new("RGB", (sw, sh), (0xF6, 0xF7, 0xFB))
        sd = ImageDraw.Draw(screen)
        f = ImageFont.truetype(REG, max(18, sw // 12))
        t = "CAPTURE PENDING"
        bb = sd.textbbox((0, 0), t, font=f)
        sd.text(((sw - (bb[2] - bb[0])) / 2, (sh - (bb[3] - bb[1])) / 2), t,
                font=f, fill=GREY)
    dev.paste(screen, (inset, inset))
    d = ImageDraw.Draw(dev)
    if platform == "ios":
        # Dynamic Island
        iw, ih = int(dw * 0.32), max(6, int(dw * 0.075))
        ix = (dw - iw) // 2
        d.rounded_rectangle([ix, inset + int(dw * 0.035), ix + iw,
                             inset + int(dw * 0.035) + ih], radius=ih // 2,
                            fill=(0, 0, 0))
    else:
        # punch-hole camera
        r = max(3, int(dw * 0.018))
        cx = dw // 2
        d.ellipse([cx - r, inset + int(dw * 0.045) - r,
                   cx + r, inset + int(dw * 0.045) + r], fill=(0, 0, 0))
    return dev, (inset, inset)


def draw_captions(canvas, slide, top_y):
    """Main 72px bold white caption + 36px 80%-white support line."""
    d = ImageDraw.Draw(canvas)
    fb = ImageFont.truetype(BOLD, 72)
    fr = ImageFont.truetype(REG, 36)
    y = top_y
    d.text((CAPTION_X, y), slide["caption"], font=fb, fill=WHITE)
    bb = d.textbbox((CAPTION_X, y), slide["caption"], font=fb)
    y = bb[3] + 22
    d.text((CAPTION_X, y), slide["support"], font=fr, fill=WHITE80)
    bb2 = d.textbbox((CAPTION_X, y), slide["support"], font=fr)
    return bb2[3]


def frame_slide(platform, slide, captures, placeholder=False):
    """Build one framed slide. `captures` maps 'free'/'pro' or 'single' -> Image."""
    slide = dict(slide)
    slide["support"] = route_of(slide["support"], platform)
    cw, ch = CANVAS[platform]
    bg = BLUE if slide["n"] % 2 == 1 else DARK
    canvas = Image.new("RGB", (cw, ch), bg)
    dev_h = int(ch * 0.78)
    bleed = 60
    if slide.get("split"):
        # two devices, 62% scale, centered in each half
        sub_h = int(dev_h * 0.62)
        half = cw // 2
        for i, key in enumerate(("free", "pro")):
            cap = captures.get(key)
            sw_ = int(sub_h * BEZEL_RATIO[platform])
            dev, _ = draw_device(platform, sw_, bleed, cap,
                                 placeholder=(placeholder and cap is None))
            x = (half - dev.width) // 2 + i * half
            y = ch - dev.height + bleed
            canvas.paste(dev, (x, y))
            if i == 0:  # divider
                d = ImageDraw.Draw(canvas)
                d.line([(half, y + 80), (half, ch - 80)], fill=WHITE80, width=3)
    else:
        dw = int(dev_h * BEZEL_RATIO[platform])
        dev, _ = draw_device(platform, dw, bleed, captures.get("single"),
                             placeholder=(placeholder and captures.get("single") is None))
        x = (cw - dev.width) // 2
        y = ch - dev.height + bleed
        canvas.paste(dev, (x, y))
    bottom = draw_captions(canvas, slide, int(ch * 0.055))
    return canvas


def capture_name(platform, mode, route):
    return f"{platform}-{mode}-{route}.png"


def build(input_dir, output_dir, plates=False):
    results = {"ios": [], "android": []}
    for platform in ("ios", "android"):
        cw, ch = CANVAS[platform]
        done = []
        for slide in SLIDES:
            n = slide["n"]
            out_name = f"{n:02d}-slide{n}.png"
            if slide.get("split"):
                if plates:
                    canvas = frame_slide(platform, slide, {}, placeholder=True)
                else:
                    free_p = os.path.join(input_dir, f"{platform}-light-home.png")
                    pro_p = os.path.join(input_dir, f"{platform}-light-homepro.png")
                    if os.path.exists(free_p) and os.path.exists(pro_p):
                        canvas = frame_slide(platform, slide, {
                            "free": load_capture(free_p), "pro": load_capture(pro_p)})
                    else:
                        missing = [p for p in (free_p, pro_p) if not os.path.exists(p)]
                        print(f"[{platform}] slide 6: SKIP (split slide needs the pro-state "
                              f"home capture; missing: {', '.join(os.path.basename(p) for p in missing)}). "
                              f"Not faked. CI must add {platform}-light-homepro.png.")
                        continue
            else:
                if plates:
                    canvas = frame_slide(platform, slide, {}, placeholder=True)
                    dest = os.path.join(output_dir, platform, out_name)
                    os.makedirs(os.path.dirname(dest), exist_ok=True)
                    canvas.save(dest)
                    print(f"[{platform}] plate {n} -> {dest}")
                    done.append(dest)
                    continue
                r = route_of(slide["route"], platform)
                p = os.path.join(input_dir, capture_name(platform, slide["mode"], r))
                if os.path.exists(p):
                    canvas = frame_slide(platform, slide, {"single": load_capture(p)})
                else:
                    print(f"[{platform}] slide {n} ('{slide['caption']}'): SKIP "
                          f"(missing {os.path.basename(p)})")
                    continue
            dest = os.path.join(output_dir, platform, out_name)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            canvas.save(dest)
            print(f"[{platform}] slide {n} -> {dest}")
            done.append(dest)
        results[platform] = done
        if len(done) == 6 and not plates:
            zipp = os.path.join(output_dir, f"{platform}.zip")
            with zipfile.ZipFile(zipp, "w", zipfile.ZIP_DEFLATED) as z:
                for f in done:
                    z.write(f, os.path.basename(f))
            print(f"[{platform}] zip -> {zipp} (6 slides)")
        elif not plates:
            print(f"[{platform}] no zip: only {len(done)}/6 slides complete")
    return results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default="./captures")
    ap.add_argument("--output", default="./output")
    ap.add_argument("--plates", action="store_true",
                    help="render the 12 internal design plates (internal-only, "
                         "not store-submittable)")
    args = ap.parse_args()
    if args.plates:
        build(None, "plates", plates=True)
    else:
        if not os.path.isdir(args.input):
            print(f"input dir {args.input} not found; nothing to frame (exit 0)")
            return 0
        build(args.input, args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
