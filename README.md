# HandyTools

Two native apps, 10 tools each, ads + yearly subscription built in.

```
handytools/
  android/   Kotlin + Jetpack Compose, minSdk 26, targetSdk 35
  ios/       SwiftUI, iOS 26+, XcodeGen project
```

## The tools

| # | Android | iOS |
|---|---|---|
| 1 | **Multi-Clipboard** — accessibility service catches every copy from any app; floating bubble to paste any of them or copy all | **Multi-Clipboard** — Share Sheet "Save to Clips" + custom keyboard with the stack; tap to paste anywhere |
| 2 | **Screenshot+** — floating button over any app; single / burst / full-page (scrolls + stitches); respects FLAG_SECURE | **Alarm Pro** — AlarmKit; custom snooze length, repeat days, sounds; rings through Silent + Focus |
| 3 | **Easy Buttons** — flashlight (+ brightness on Android 13+), hotspot, camera, video, selfie; Quick Settings tile | **Flashlight Dimmer** — true brightness slider, strobe, SOS |
| 4 | **Web → Home** — paste URL, auto name + icon, pinned launcher shortcut; also works via Share | **Web → Home** — generates a Web Clip profile (name + icon auto-picked); or guided Safari route |
| 5 | **Alarm Pro** — per-alarm volume, snooze length, max snoozes, ramp-up, math-to-dismiss, auto-stop, custom sound | **Sticky Note** — one note, editable in-app, visible on home + lock screen widget |
| 6 | **Volume Mixer** — ring / media / alarm / notifications / calls / system on one screen + presets | **Text from Image** — on-device OCR of any screenshot, copy all |
| 7 | **Grab Screen Text** — floating button OCRs whatever is on screen (ML Kit, offline) | **Doc Scanner** — VisionKit scanner, multi-page PDF, share |
| 8 | **Notification Log** — keeps 7 days of notifications, including dismissed ones | **Decibel Meter** — live dB with peak, nothing recorded |
| 9 | **Scratchpad Bubble** — note that floats over every app, autosaves | **Photo Metadata** — see GPS/device/time, make a clean copy |
| 10 | **Keep Awake** — screen stays on, optional auto-off | **QR Tools** — scan any code; make link or Wi-Fi join codes |

Why they differ: iOS doesn't let third-party apps read the clipboard in the background, capture other apps, change system volumes, draw overlays, read notifications, or add home-screen shortcuts. Everything on the iOS list is something Apple actually permits.

## Monetization (both)

- **Ads:** AdMob. Adaptive banner at the bottom of every screen + an interstitial after a tool finishes, max once per 3 min. Both disappear for Pro.
- **Pro:** one yearly auto-renewing subscription, product id `handytools_pro_yearly`. Also unlocks unlimited clips (free: 20) and alarms (free: 3).
- Test ad unit IDs are hard-coded. **Replace before release** or AdMob will flag the account:
  - Android: `app/build.gradle.kts` (`admobAppId`) and `ads/Ads.kt` (`AdUnits`)
  - iOS: `project.yml` (`GADApplicationIdentifier`) and `Ads/Ads.swift` (`AdUnits`)

## Android — build & run

1. Open `android/` in Android Studio (Ladybug or newer). Let Gradle sync.
2. Run on a real device (overlays, MediaProjection, alarms don't behave on emulators).
3. Each tool shows an inline card that deep-links to the one permission it needs. Nothing is requested up front.

**Play Console, one time:**
- Monetize → Subscriptions → create `handytools_pro_yearly`, base plan `yearly`, period P1Y. Optional 7-day trial.
- App content → Declarations: **Accessibility service** (clipboard stack / full-page screenshot — "user-facing productivity"), **Foreground services** (mediaProjection, specialUse ×3), **Notification listener**. Play reviews these by hand; the in-app explanations are written to pass.
- Sign with an upload key, build `./gradlew bundleRelease`.

## iOS — build & run

1. `brew install xcodegen`, then `cd ios && xcodegen`. Open `HandyTools.xcodeproj`.
2. Set your team id in `project.yml` (`DEVELOPMENT_TEAM`) and in `Products.storekit`. Regenerate.
3. Requires Xcode 26 / iOS 26 (AlarmKit). Run on a real device.
4. For local purchase testing: Edit Scheme → Run → Options → StoreKit Configuration → `Products.storekit`.

**App Store Connect, one time:**
- Subscriptions → group "HandyTools Pro" → product `handytools_pro_yearly`, 1 year. Optional 1-week intro offer.
- Capabilities already in the project: App Groups (`group.com.handytools.shared`), AlarmKit, Live Activities.
- Review notes to include: keyboard requests Full Access only to read the clipboard for the Clips stack; nothing leaves the device.

## CI (GitHub Actions, branch `handytools`)

- `.github/workflows/android.yml` — builds debug APK + release AAB on every push, publishes both to the `ci-logs` branch and attaches the APK to the `handytools-android-latest` GitHub Release. Signs the AAB when the four `ANDROID_*` secrets exist.
- `.github/workflows/ios.yml` — builds the app + 3 extensions on `macos-26` / Xcode 26.6 (simulator, unsigned) on every push; the `testflight` job archives and uploads when `TESTFLIGHT_ENABLED=true` and the `ASC_*` secrets exist.
- Both compile clean as of this commit. See `LAUNCH-CHECKLIST.md` for the store steps.

## Known edges

- **Android hotspot:** no public API since Android 8. The button opens the tethering toggle directly.
- **Android full-page screenshot:** needs the accessibility service to scroll; stitches by finding the overlap between frames. Works on list/scroll views; won't on apps that block capture (we detect the black frame and tell the user).
- **iOS alarm volume:** AlarmKit plays at system alarm volume. No app can set per-alarm volume on iOS. Snooze length, sound, repeat days are the win.
- **iOS Web → Home:** the profile route is unsigned, so iOS shows "Not signed" before install. That's normal for Web Clip profiles. If you'd rather avoid it, the Safari route is one tap away.
- **AlarmKit:** API shipped with iOS 26.0; if Apple renames a parameter in a point release, `AlarmProView.swift` is the only file to touch.

## Privacy copy (for both store listings)

Everything HandyTools captures — clipboard text, screenshots, notifications, notes — stays on your phone. No accounts, no cloud, no analytics beyond what the ad SDK collects (and that's gone with Pro).
