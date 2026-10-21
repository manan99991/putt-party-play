# Tenzy store rulebook

Read and apply this before any store submission, listing change, new tool, or third-party page.
It is the gate AGENTS.md points at. Keep it in sync with the actual pipeline and privacy policy.

## 1. Ad safety (protects the AdMob account)

- **Never serve live ad units outside a real production build.** Viewing or tapping your own live
  ads is the #1 cause of AdMob account bans (invalid traffic).
  - iOS: live units serve only in an App Store build (receipt check in `ios/HandyTools/Ads/Ads.swift`).
    TestFlight and dev use Google's reserved test units.
  - Android: live units serve only when built with `-PliveAds=true` (`BuildConfig.LIVE_ADS` in
    `android/app/src/main/java/com/handytools/app/ads/Ads.kt`). Debug and the internal-testing
    release use Google's test units.
- Banner sits in a labelled bottom chrome strip ("Ads keep Tenzy free / Remove ads"), fenced with a
  hairline and reserved height — no layout shift, no accidental taps.
- Interstitials: at most once every 3 minutes, only after a tool action completes. Never on launch.
- A rejection during AdMob/App review is **not** a ban. Fix and resubmit on the same account — never
  create a second account to get around a block (that is what turns a fixable rejection permanent).

## 2. Privacy & data declarations (must match `docs/privacy.html`)

- No analytics, no crash SDK, no account. Files stay on device.
- The only data collected is the advertising identifier used by AdMob to show/count ads; Pro disables
  ads and the ad code. Pro is a single auto-renewing subscription ($19.99/yr or $2.99/mo).
- Apple App Privacy: declare "Identifiers → Device ID" used for Third-Party Advertising, not linked to
  identity, not used for tracking beyond the ATT prompt.
- Play Data safety: no data collected or shared except the ad identifier; declare accordingly.
- Keep App Privacy / Data safety answers identical in substance to the privacy policy.

## 3. Honesty of the listing (both stores reject misrepresentation)

- Screenshots and descriptions must match the **shipped build**, not an older or aspirational one.
  Re-capture after any catalog change.
- Do not advertise tools that don't work on the target platform:
  - Android page-3 AI tiles fall back to a "needs Gemini Nano" card on most devices, and `signfill`
    is a Coming-Soon placeholder. These are **excluded** from the Play listing copy and screenshots
    until they genuinely work. iOS ships all 30 as working tools.
- "30 tools" is an iOS claim. The Android listing describes the real working subset without a count.

## 4. Asset specs

- iOS screenshots: 6.9" display, **1290×2796** (the one required size; Apple scales down).
- Play phone screenshots: each side 320–3840 px and ratio **≤ 2:1** → use **1080×1920** (1080×2400 is
  rejected). 2–8 images.
- Play feature graphic: **1024×500**, no alpha. Play high-res icon: **512×512** PNG.
- Pipeline: `store-screenshots/frame_screenshots.py` frames CI device captures to these sizes.

## 5. Metadata limits

- App Store: name ≤30, subtitle ≤30, keywords ≤100 (comma-separated, no spaces), promotional text
  ≤170, description ≤4000.
- Play: title ≤30, short description ≤80, full description ≤4000.
- Metadata lives in `ios/fastlane/metadata` and `android/fastlane/metadata`; it is the source of truth
  and is pushed by the pipeline, not typed into the console.

## 6. Permissions

- Every requested permission needs a usage string and a one-line reviewer justification
  (`ios/fastlane/metadata/review_information/notes.txt`; Play app-content declarations).
- Adding a tool that needs a new permission = update the usage string, the reviewer notes, the privacy
  policy, and this rulebook in the same change.

## 7. Release gating (nothing ships by accident)

- iOS TestFlight: `TESTFLIGHT_ENABLED=true` + commit trailer `Ship-Build=YES`.
- iOS App Store submit: `STORE_SUBMIT_ENABLED=true` + commit trailer `Ship-Store=YES`
  (`fastlane release` → deliver; release held for a manual tap after approval).
- Android: builds every push; auto-publishes to the Play **internal** track once
  `PLAY_SERVICE_ACCOUNT_JSON` is set; listing pushed by `fastlane listing` (best-effort).
- A plain push builds and tests only — it never deploys or submits.
