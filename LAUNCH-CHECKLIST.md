# HandyTools — launch checklist

Both apps compile green on CI (branch `handytools`). This is what's left between "builds" and "in the stores", in order. Every step is a few minutes; nothing here needs code.

## Where things are

- Source + CI: `manan99991/putt-party-play`, branch `handytools` (public repo — move it to a private repo once GitHub billing is sorted: `git clone -b handytools … && git push <new-repo> handytools:main`)
- Android debug APK, direct install link: https://github.com/manan99991/putt-party-play/releases/download/handytools-android-latest/HandyTools-debug.apk
- Signed release bundle for Play Console: `HandyTools-release.aab` (sent in chat, signed with `upload-keystore.jks`)
- CI build logs + outputs: branch `ci-logs`

## Android — today

1. **Test:** open the APK link on your phone → install → go through all 10 tools. Each tool asks for its one permission inline.
2. **Play Console → Create app** "HandyTools", package `com.handytools.app`.
3. **Monetize → Subscriptions → Create:** product id `handytools_pro_yearly`, base plan id `yearly`, period 1 year, price $9.99 (or whatever). Activate.
4. **Release → Testing → Internal testing → Create release:** upload `HandyTools-release.aab`. Play App Signing: accept (the uploaded key becomes your upload key — keep `upload-keystore.jks` + `KEYSTORE-README.txt` backed up).
5. **App content declarations** (Play reviews these; the wording below is accurate):
   - Accessibility service: "Multi-clipboard: captures text the user copies in other apps and lets them paste it back; full-page screenshot scrolls on the user's behalf. Core user-facing feature, not analytics."
   - Foreground services: mediaProjection (screenshots/OCR), specialUse ×3 (alarm ringing, floating notepad, keep-screen-on).
   - Notification listener: "Notification history the user can review. Stored locally only."
   - Data safety: no data collected except ad SDK; no data shared.
6. **AdMob → Apps → Add app (Android):** copy App ID into `android/app/build.gradle.kts` (`admobAppId`), create a Banner + Interstitial unit, paste into `android/app/src/main/java/com/handytools/app/ads/Ads.kt`. Push → CI rebuilds → re-sign + upload.
7. For CI to sign automatically, add repo secrets: `ANDROID_KEYSTORE_B64` (base64 of the jks), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` = `handytools`, `ANDROID_KEY_PASSWORD`. After that every push produces a Play-ready `.aab`.

## iOS — today (≈15 min, then CI does TestFlight on every push)

1. **developer.apple.com → Identifiers:** register App ID `com.handytools.app` with App Groups, Live Activities (and let Xcode/CI register the three extension IDs automatically).
2. **App Store Connect → Apps → New app:** HandyTools, bundle `com.handytools.app`.
3. **ASC → Users and Access → Integrations → App Store Connect API → Team keys → Generate:** role *App Manager*. Download the `.p8` once. Note Key ID and Issuer ID.
4. **GitHub repo → Settings → Secrets and variables → Actions:**
   - Secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_B64` (`base64 -i AuthKey_XXXX.p8`), `APPLE_TEAM_ID`
   - Variable: `TESTFLIGHT_ENABLED` = `true`
5. **Actions → iOS → Run workflow.** The `testflight` job archives with automatic signing and uploads. Build shows in TestFlight in ~10 min. Add yourself as an internal tester.
6. **ASC → Subscriptions:** group "HandyTools Pro", product id `handytools_pro_yearly`, 1 year.
7. **AdMob → Apps → Add app (iOS):** put the App ID in `ios/project.yml` (`GADApplicationIdentifier`) and the two unit ids in `ios/HandyTools/Ads/Ads.swift`.
8. App Review notes to paste: "The keyboard extension requests Full Access only to read the system clipboard into the user's clip stack; nothing is transmitted. AlarmKit is used for user-created alarms. Microphone is used for the live decibel meter; audio is metered, not recorded."

## Both

- Privacy policy URL is required by both stores and by AdMob. One paragraph is enough (everything stays on device; ad SDK collects standard ad identifiers; Pro removes ads). Host it on GitHub Pages in 2 minutes.
- Screenshots: 2–4 per store. The home grid plus Alarm Pro and Multi-Clipboard are the ones that sell it.
- GitHub billing: Actions are currently refused on your private repos ("recent account payments have failed or spending limit"). Public repos are free, which is why the code lives on `putt-party-play` for now.
- Housekeeping: a stray empty branch `handytools` was left on `app-calculator` (the build attempt before billing blocked it) — delete it from the GitHub UI; the session proxy wouldn't allow branch deletes.
