# Motion + performance — CI measurement runbook (prompt 1)

The motion layer and perf hooks are in the code. This machine has no Android SDK or Xcode,
so the numbers below are measured by CI on real emulator/simulator runs, not estimated here.
Leave a `// MEASURE:` comment in code at each instrument point (done) and fill this table from CI.

## Targets
- Cold start (process start → first frame): **< 800ms**
- Scroll / sheet drag: **no frame > 16ms** on Home scroll and the clipboard panel
- Motion tokens: fast 120 / base 200 / slow 280; ease-out enter, ease-in exit; press 0.98

## Android (Macrobenchmark on the CI emulator)
1. Baseline + candidate: `./gradlew :app:assembleRelease` on the merge commit vs the base commit.
2. Cold start:
   `adb shell am start -W -n com.handytools.app/.MainActivity` → record `TotalTime`.
   Or Macrobenchmark `StartupTimingMetric` (compilationMode = None) over 10 iterations.
3. Frame timing on Home scroll + clipboard panel:
   `adb shell dumpsys gfxinfo com.handytools.app framestats` after a scripted scroll
   (Macrobenchmark `FrameTimingMetric` preferred) → record p50/p90/p99 frame times and jank count.
4. What the code does for these numbers: AdMob init + billing connection run after the first
   decorView draw (HandyApp schedules them there); Room is pre-warmed on Dispatchers.IO in
   `Application.onCreate`; the ad banner reserves 60dp from the first frame so nothing jumps;
   LazyColumn/LazyVGrid items carry stable keys; stitching/OCR run on Dispatchers.IO/Default
   with progress toasts.

## iOS (Instruments on the CI simulator)
1. `xctrace record --template 'App Launch' --device <sim> --launch -- com.handytools.app`
   → record time to first frame.
2. Core Animation FPS instrument while scrolling Home and dragging the clipboard panel
   → record min FPS / dropped frames.
3. What the code does: `AdsBootstrap.start()` defers `MobileAds.shared.start()` until the
   first `didBecomeActive` (post-first-frame); sheets stay native with drag-to-dismiss;
   Reduce Motion flips entrances to crossfades.

## Reduce Motion checks (both)
- iOS: enable Reduce Motion → every entrance becomes a crossfade; alarm ring glow/pulse freeze.
- Android: `adb shell settings put global animator_duration_scale 0` → entrances crossfade,
  ring glow/pulse freeze, caret stops blinking.
