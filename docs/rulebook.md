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
- AdMob was removed (Nov 17 2026): no ads, no advertising identifier, no ATT prompt. Nothing is collected. Pro (25 Nov, Manan's pricing): two auto-renewing plans in
  the "Tenzy Pro" group, **monthly $2.99 and yearly $29.99, each with a 7-day free trial** (`fastlane subscriptions`
  sets both; people already on yearly at $19.99 keep their price). Both plans must be Add-for-Review'd with the version,
  each with its App Review screenshot (the current two-plan paywall). Ads for free users come later, once an ad
  network approves the account; until then no ads, no advertising identifier, no ATT prompt.
- The Contacts tool reads and writes contacts on-device only: find duplicates, merge, export a .vcf backup, and copy or move them between the user's own accounts (Gmail/iCloud/phone). Android already declares READ/WRITE_CONTACTS; iOS uses the same Contacts permission. A move always saves a backup first.
  Nothing from Contacts is uploaded or collected; declare accordingly and keep the usage string,
  reviewer notes and privacy policy aligned.
- Apple App Privacy: "Data Not Collected" (no ads, no analytics). Re-check the answers in App Store Connect
  match this before the next submit — they were set when AdMob was still in.
- Play Data safety: no data collected or shared; declare accordingly.
- Network calls the policy must name: See & Read / "Read the page at a link" (the page you give), Price Watch
  (the pages you add, via background refresh only), Daily Brief weather (Apple WeatherKit) and travel times
  (Apple Maps), all only with the person's own setup.
- Keep App Privacy / Data safety answers identical in substance to the privacy policy.

## 3. Honesty of the listing (both stores reject misrepresentation)

- Screenshots and descriptions must match the **shipped build**, not an older or aspirational one.
  Re-capture after any catalog change.
- Do not advertise tools that don't work on the target platform:
  - Android page-3 AI tiles fall back to a "needs Gemini Nano" card on most devices, and `signfill`
    is a Coming-Soon placeholder. These are **excluded** from the Play listing copy and screenshots
    until they genuinely work.
- Positioning (Nov 19 2026, Manan): Tenzy is a **personal assistant** — "Set it once. It's handled." No tool counts
  anywhere (not "30", not "60+", not "90 ready-made"). Never "#1/best/leading/only" (Apple 2.3.7, Play metadata policy),
  no "free"/price/"no ads" in subtitle or screenshots (description only), no competitor names. Medicine copy is
  reminders and logging, never outcomes; the description carries "doesn't give medical advice — check with your
  doctor or pharmacist" (Apple 1.4.1) and the Play listing adds "not a medical device" (Play health policy).
  The Android listing states only what the Android build ships.
- The listing must represent the **free/Pro split honestly**: thirteen tools are free (`Tool.freeIDs`: Flashlight,
  QR & Wi-Fi, See & Read, Measure, Cleaner, Translate, Vault, and since 25 Nov Home's "Most loved" row — Scan, What is
  this?, Read a menu, Sign a PDF, Make a sticker — plus Find my car), plus 2 saved tools of your own with the free
  builder steps; Invoices & Quotes (Business tab) makes 3 a month free (`Tool.meteredIDs`); the rest are Tenzy Pro.
  Do not imply the whole app is free. The paywall screen must show both prices, the 7-day trial terms,
  auto-renew disclosure, and working Terms (EULA) + Privacy links (Guideline 3.1.2).

## 4. Asset specs

- iOS is a **universal** app (iPhone + iPad: `TARGETED_DEVICE_FAMILY=1,2`), so App Store Connect
  requires BOTH screenshot sets — miss either and the version cannot be submitted:
  - iPhone 6.9" display, **1290×2796** (portrait).
  - iPad 13" display, **2064×2752** (portrait).
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
- NFC (`android.permission.NFC`, normal/install-time) is declared for the Codes tool, which reads NFC
  tags **on-device only** to show their contents — nothing uploaded or collected, so Data safety /
  App Privacy answers are unchanged. `android.hardware.nfc` is `required="false"` so non-NFC phones
  still install. Normal permissions need no Play declaration and carry no review/rejection risk.

- Build your own, reminders: a tool can carry a reminder the person sets. iOS uses local notifications (asked for when
  the switch is turned on; no usage string exists for notifications, add a reviewer note). Android uses ordinary inexact
  alarms and `RECEIVE_BOOT_COMPLETED` (normal, install-time, no Play declaration) to put reminders back after a restart.
  Never use exact alarms or full-screen intents here: those are reserved for alarm-clock apps and got the Alarm tool removed.
- Build your own, "offer on a new photo or screenshot" (Android only): a system job woken by photo-library changes shows
  a notification; nothing runs until the person taps it. It relies on the already-declared `READ_MEDIA_IMAGES`. The Play
  photo and video permissions declaration must describe this use too before it ships. On-device only, nothing uploaded.
- Build your own inputs: the contact pickers (iOS `CNContactPickerViewController`, Android `ACTION_PICK` on a phone row)
  hand over only the contact the person taps and need no permission. Speech uses the existing microphone and speech strings on iOS
  and the phone's own voice typing on Android.
- Shortcuts actions (iOS) run tools on the device and return the result to the shortcut. No new data leaves the phone.
- Animate's "Add music" (iOS) asks for Media & Apple Music (`NSAppleMusicUsageDescription`) only when the person taps "Show
  songs from the Music app". It lists songs that are on the phone and not copy-protected (`hasProtectedAsset == false`,
  not cloud items) and reads them on-device to put under a video; streamed Apple Music songs are never offered or copied.
  Files picked with "Browse all files" are copied into Tenzy's own Music folder. Nothing is uploaded, so App Privacy is
  unchanged. Never ship songs or loops in the app that Tenzy doesn't own the rights to.
- The photo index (Search My Photos) builds on-device only, and only once photo access is already granted: quietly in
  the foreground (stops on Low Power Mode or a warm phone, pauses between photos), for the ~30 s iOS gives on leaving,
  and as a `BGProcessingTask` (`com.tenzy.toolkit.photoindex`, `requiresExternalPower = true`) to finish while charging.
  `UIBackgroundModes` includes `processing` for this alone; the reviewer note says so. Nothing is uploaded.
- Shortcuts action titles, descriptions and phrases must never contain "iPhone", "iPad", "Apple" or "Siri": App Store Connect rejects the upload (ITMS-90626) after the build has already passed. Say "your device".
- Build your own, steps that can be missing on a phone: `speechText` and `videoCaptions` need on-device speech recognition, `rewrite` needs an
  on-device writing model (never on Android today), `videoCaptions` is iPhone only. The app greys these out and says why. **Never list one
  of them in a store's copy or screenshots for a platform where it is unavailable** (section 3). Speech is recognised on the phone only
  (`requiresOnDeviceRecognition` on iOS, the on-device recogniser on Android); do not add a server fallback.
- Build your own, "Read the page at a link": fetches the one web page the person gave, over https, and keeps its words. Nothing about the
  person is sent besides the request itself, and nothing is collected, so Data safety / App Privacy answers are unchanged. Say this in the
  reviewer notes before a production release.
- Build your own, "Location" input: only when the button is tapped. iOS reuses `NSLocationWhenInUseUsageDescription`, whose wording now names
  this use; Android reuses the already-declared location permissions and asks at the tap. The location is put in the text box and goes
  nowhere unless the person sends the result. Add a reviewer note (iOS) before production.
- Build your own, "Record" (iOS) uses the existing microphone string; recordings stay in the app's temporary folder.
- Build your own, "Translate": iOS uses the system translator, which downloads languages from Apple with the person's consent. Android uses
  ML Kit's on-device translate packs (already used by the Translate tool) plus `com.google.mlkit:language-id` to detect the language on the
  phone. No text is sent to a server by Tenzy.
- A PDF password set in "Lock with a password" is stored with the tool on the device and stripped from shared tools. Do not log it.
- The iPhone share sheet declares `NSExtensionActivationSupportsFileWithMaxCount` so PDFs can be shared to Tenzy. It therefore also appears
  for other files; those get a plain "Tenzy can run your tools on photos, PDFs, links and text from here" screen. Do not claim video or
  audio sharing on iPhone in any listing.
- Android home-screen shortcuts for tools use the launcher's own pin prompt (`ShortcutManagerCompat.requestPinShortcut`): no permission, the
  person confirms each one. The iPhone My Tools widget reads only tool names from the app group.
- Build your own, the "Just for fun" steps (sticker, emoji over faces, meme text, emoji mosaic, boomerang GIF, speed change, photos as a GIF): all
  drawn on the device, no new permission, nothing sent anywhere, so Data safety / App Privacy answers are unchanged. "Emoji over faces" finds
  faces with the phone's own detector (Vision on iOS, ML Kit on Android, both already in the app). Starting a video tool from a Live Photo is
  iPhone only and uses the system photo picker (no photo-library permission): **never mention Live Photos in the Play listing.** Do not describe
  any of these as a "face animator", "deepfake" or "AI" feature: nothing animates or alters a face, and the stores review those claims harder.
- Build your own, "Recent results": the last 20 results are copied into the app's own folder so they survive closing the screen. They never
  leave the phone, are not backed up by Tenzy anywhere, and the person can remove one or clear them all. Results can hold personal things (a
  signed form, a face), so never read, upload or show them outside that screen. Data safety / App Privacy answers are unchanged.
- Build your own, tool links: `docs/t.html` is our own page on the website. The tool rides after "#" in the link, which a browser never sends
  to a server, and the page has no scripts, fonts or images from anywhere else and no analytics: keep it that way. A link never carries
  recipients, reminder times or a PDF password. Manan approved publishing it on 12 Nov 2026 and it is live at `manan99991.github.io/tenzy/t.html` (the `tenzy` website repo holds
  the published copy; keep the two files the same). Any later change to the page is a public change and needs his yes again. `ToolLink.live`
  (iOS) and `ToolLink.LIVE` (Android) switch link and QR sharing on or off. Android declares a `tenzy://import` link filter; an
  imported tool is only saved to My tools, never run by itself.
- Outside the app (24 Nov): Control Center / Lock Screen / Action-button controls (Save where I parked, Scan, What is this?,
  Translate) and the Shortcuts action "Save Where I Parked" (made for an automation when the car's Bluetooth disconnects)
  all **open Tenzy** and do the work in the foreground with the existing when-in-use location (the automation steps offer
  CarPlay or Bluetooth disconnecting). A pin only uses a fresh fix taken after saving began (ParkFix), never the phone's
  remembered old one. The parking meter shows as a Live Activity on the Lock Screen
  and in the Dynamic Island (`NSSupportsLiveActivities`, local only, no push), started when the person sets a meter and
  ended when it's cancelled or the car is cleared. Nothing is collected. Reviewer note before production: say the controls
  and the Shortcuts action open the app, and the Live Activity is the meter countdown.
- Automatic parking (25 Nov, Manan: "build around existing permissions"): GPS Dashboard > "Save my spot automatically", **off by
  default**. Uses only When In Use location and Motion & Fitness (both already declared; the two usage strings now name this
  use) plus `UIBackgroundModes: location` and a `CLBackgroundActivitySession` started when the person switches it on (iPhone
  shows the blue location indicator). **Never request Always location** for it. Cell-level accuracy off the road, full GPS only
  while the motion chip or speed says driving; the spot is saved on the phone when the person walks away (or after three minutes
  still), with a local notification and a "Not my car" undo. Nothing is uploaded, so App Privacy stays "Data Not Collected".
  Reviewer note explains it (BACKGROUND LOCATION). The privacy policy needs one line about it before the store submit (drafted in
  docs/listing-draft.md; the website change needs Manan's yes). Android port: same switch, foreground-service-free design to
  be chosen at port time (Android background location is a Play declaration; ask before adding it).
- "Change the voice" only changes speed and pitch. Do not describe it as voice cloning or as sounding like a real person.
- Build your own, Pro steps: only the 10 basic steps are free (`Block.freeStepIDs` / `FREE_STEP_IDS`, matched on both
  phones): Read text, Tidy text, Summarize, Find links/emails/phones, Clean tracking, Make a QR code, Wi-Fi join code,
  Contact as a QR code, WhatsApp link, Translate. Every other step is a Pro step (`isProStep`). A free user can see the
  Pro steps (marked "Pro"/locked in the picker) but can't add, save or run a tool that uses one — `Chain.needsPro` gates
  the add-step menu, Save, and the run screen, all pointing at the paywall. Keep this set, the paywall copy, and the
  listing's free/Pro paragraph in step. The 10 free steps align with the 7 free built-in tools; don't quietly widen it.
- Build your own, free vs Pro: building and running tools is **unlimited for everyone** (free included), and so is receiving a tool from a
  shared link. The free tier **keeps `BuilderLimits.freeSaved` (2) of your own saved tools**; saving a 3rd from the editor, Duplicate, or the
  in-app Paste opens the paywall instead (the built tool is not lost — the editor stays open, and Save works once the person is Pro). Pro lifts
  the cap. The number lives in `BuilderLimits` on both phones (one source, unit-tested); keep the paywall copy ("Build unlimited tools") and this
  rule in step. A tool opened from a shared link at launch is not gated, so the sharing growth loop stays open even past the cap.
- Listing changes for Build your own are drafted in `docs/listing-draft.md`. That file is not pushed by the pipeline; copy
  from it into the metadata folders only after the features ship and Manan approves.

## 7. Release gating (nothing ships by accident)

- iOS TestFlight: `TESTFLIGHT_ENABLED=true` + commit trailer `Ship-Build=YES`.
- iOS App Store submit: `STORE_SUBMIT_ENABLED=true` + commit trailer `Ship-Store=YES`
  (`fastlane release` → deliver; release held for a manual tap after approval).
- Android: builds every push; auto-publishes to the Play **internal** track once
  `PLAY_SERVICE_ACCOUNT_JSON` is set; listing pushed by `fastlane listing` (best-effort).
- A plain push builds and tests only — it never deploys or submits.
- Android asks Google Play for a newer build each time the app is opened from cold and shows Play's own full-screen update step
  (`MainActivity.checkForUpdate`, `com.google.android.play:app-update`). It can be backed out of, by design: a failed download must never
  lock anyone out. This applies to every track, production included; revisit before a production release if asking on every open is too much
  for the public (Play's update priority can limit it to important releases).

## 8. Fixing a failing test (Manan, 23 Nov: "stop repeating the same failures")

- **No re-send on an unproven fix.** A test that failed a TestFlight run is fixed, then proven green on its own
  through `ios/REPRO_TESTS.txt` (the iOS crash repro workflow, ~20 min) before `Ship-Build=YES` goes on any commit.
- **Same failure twice = the theory was wrong.** Stop changing code; add diagnostics that print what the app actually saw
  (values, indices, points) and run them alone first. Never change a threshold to make a check pass.
- **Find when it last passed.** `git log` the code under test between the last green run and the first red one, and read
  that diff before guessing. (23 Nov: the dissolve check broke when the simulator pop-out was switched off, not from drawing.)
- **Prove the mechanism, not the hope.** A fix that depends on something being called (a delegate, a callback, an event)
  must show it was called, in a test or a printed trace.
