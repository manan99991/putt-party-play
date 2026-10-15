# HandyTools App Store preview — Remotion project (prompt 6)

20-second, silent-safe App Store preview for HandyTools iOS. Portrait **886×1920**, 30fps, **600 frames** (no audio track; music is optional and not included).

## Storyboard / frame table

| Frames | Time | Scene | Caption |
|---|---|---|---|
| 0–59 | 0–2s | Icon on blue, wordmark fades in | — |
| 60–179 | 2–6s | Alarm Pro — finger drags the snooze slider from 9 to 3 min | Your snooze. Your rules. |
| 180–299 | 6–10s | Multi-Clipboard — Share Sheet "Save to Clips" in Safari, then the Clips keyboard pastes it in Messages | Copy five. Paste any. |
| 300–419 | 10–14s | Text from Image — screenshot picked, highlight boxes animate on, Copy all tapped | Grab the words. |
| 420–539 | 14–18s | Photo Metadata — map appears under a photo, "Make a clean copy" tapped, map disappears, "Location stripped ✓" | Strip what's hidden. |
| 540–599 | 18–20s | Home grid | 10 tools. One app. |

Transitions are hard cuts; motion inside scenes mirrors the app's real motion (springs, 200–280ms-feel entrances). Captions are white brand type on a blue bottom band (`CaptionBand`). The finger is a 48pt translucent circle with a press pulse (`FingerTap`).

## Swapping in real recordings

See `public/placeholders/README.md` — replace a scene's `PhoneSlot` contents with an `<OffthreadVideo>` pointing at the recording, keeping the phone bounds. Timing stays identical.

## Brand assets

- `public/icon.png` — the live Direction A app icon (`ios/HandyTools/Assets.xcassets/AppIcon.appiconset/icon-1024.png`). Since the icon pick is final, no swap is expected.
- `src/brand.ts` — #1F5EFF, #0E0E12, surfaces, font stack, canvas constants, mirroring the app design tokens.

## Render

```bash
cd preview-video
npm install
npm run start      # Remotion Studio, scrub and review
npm run render     # -> out/handytools-preview.mp4
```

Not rendered in the dev session that built this — `node_modules` is intentionally absent. First render happens on a dev machine after `npm install`.
