# HandyTools store-screenshot framing pipeline (prompt 5)

Turns raw CI captures into the six framed store slides per platform — light design plates plus the final store-ready PNGs, per the product brief.

## What it does

`frame_screenshots.py` (Python + PIL) frames each capture in a drawn flat device bezel:

- Canvas **1290×2796** for iOS (6.9"), **1080×2400** for Play. RGB, no alpha.
- Solid **#1F5EFF** on odd slides, **#0E0E12** on even slides.
- Device frame: iPhone-style (Dynamic Island) / Pixel-style (punch-hole camera), height = 78% of canvas height, centered, bottom-anchored with 60px bleeding off the bottom; the capture fills the device screen (cover-crop).
- Caption above the device: main line **72px bold white**, left-aligned at 96px margin; one supporting line **36px white at 80%** below it.
- Slide 6 is special: one slide with **two half-scale devices side by side** — free-state home on the left, Pro-state home on the right, with a divider between them.

## CI capture naming (input)

CI publishes raw captures to the `ci-logs` branch named `{platform}-{mode}-{route}.png`, e.g. `ios-light-home.png`, `android-dark-ocr.png` (see `.github/workflows/{android,ios}.yml` route lists).

Slide → route mapping used here:

| Slide | Main caption | Capture (Android) | Capture (iOS) | Mode |
|---|---|---|---|---|
| 1 | 10 tools. One app. | `android-light-home.png` | `ios-light-home.png` | light |
| 2 | Your snooze. Your rules. | `android-light-alarm.png` | `ios-light-alarm.png` | light |
| 3 | Copy five. Paste any. | `android-light-clipboard.png` | `ios-light-clips.png` | light |
| 4 | Grab the whole thing | `android-dark-screenshot.png` | `ios-dark-ocr.png` | dark |
| 5 | See what's hidden | `android-dark-volume.png` | `ios-dark-exif.png` | dark |
| 6 | Pro: ads gone. $9.99 a year. | `android-light-home.png` + `android-light-homepro.png` | `ios-light-home.png` + `ios-light-homepro.png` | light |

Support lines: 1 "The utilities your phone forgot." · 2 "Set the snooze length once." · 3 "Clipboard history, stacked and ready." · 4 Android "Full-page screenshots, stitched." / iOS "Words lifted straight from the image." · 5 Android "Every volume, one desk." / iOS "Location and metadata, exposed." · 6 "Free on the left. Pro on the right."

Notes:
- Slide 2's "Alarm editor" shows whatever the CI `alarm` route renders (alarm list/editor). If the route only shows the list, the slide still works — the caption is about the snooze feature.
- **Slide 6 needs a pro-state home capture CI does not produce today**: `{platform}-light-homepro.png` (same route as home, captured in Pro state with the ad strip removed). Until CI adds it, slide 6 is skipped with a clear message and never faked — missing inputs are always skipped (exit 0), never synthesized.
- Captures should be taken with the status bar at **9:41, full battery** (CI sets this on the iOS simulator; the Android route list should match).

## How to run

```bash
# 1. Copy the raw captures into ./captures (default) or point --input at them
python3 store-screenshots/frame_screenshots.py --input ./captures --output ./output

# Slides land in output/ios/ and output/android/; a zip per platform
# (output/ios.zip, output/android.zip) is written when all 6 slides complete.
```

```bash
# 2. Internal design plates only (never submitted to a store):
python3 store-screenshots/frame_screenshots.py --plates
# -> plates/ios/0N-slideN.png and plates/android/0N-slideN.png
```

## Fonts

This build uses DejaVuSans (Bold/Regular), which ships on the CI/dev machine. The store builds should substitute the brand geometric sans (Inter / Manrope / SF Pro) in `BOLD`/`REG` at the top of the script — the 72/36px sizes and 96px left margin stay the same.

## Not store-submittable

The `plates/` renderings use an empty device frame with a "CAPTURE PENDING" placeholder — they exist so the framing can be reviewed before CI produces captures. Real store slides require real app captures from the CI emulator/simulator runs.
