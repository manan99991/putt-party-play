# Placeholder recordings for the App Store preview

Drop simulator screen recordings here as MP4s, then swap each `PhoneSlot`'s
contents for an `<OffthreadVideo>`. Keep the phone bounds from `PhoneSlot`
(`phoneX/phoneY/phoneW/phoneH`) so the footage stays inside the frame.

Example — Scene 2 (Alarm Pro), replacing the mock slider:

```tsx
import { OffthreadVideo, staticFile } from "remotion";

<PhoneSlot label="alarm-editor.mov">
  <OffthreadVideo
    src={staticFile("placeholders/alarm-editor.mov")}
    style={{ width: "100%", height: "100%", objectFit: "cover" }}
  />
</PhoneSlot>
```

Suggested filenames (one per scene):
- `alarm-editor.mov` — real Alarm Pro editor, finger drags snooze 9 → 3 min
- `clips-flow.mov` — Safari Share Sheet "Save to Clips", then paste in Messages
- `text-from-image.mov` — screenshot picked, Vision highlight boxes, Copy all
- `photo-metadata.mov` — map under photo, "Make a clean copy", map disappears
- `home-grid.mov` — real Home grid (optional; the drawn grid already works)

Until a recording lands, the scene's drawn mock (or the "SIM RECORDING: …"
label) renders instead — the video still builds and the storyboard timing is
unchanged. This is the "placeholders I can swap" step from the preview brief.
