# Tenzy tools v2 — the 30 (iOS)

Branch `tools-v2` (staged; deploy = merge into `handytools` when the owner says "deploy").
Every tool below is routed in `ios/HandyTools/App.swift` (`ToolDestination`) and has:
engine code in `ios/HandyTools/Engines/`, a view in `ios/HandyTools/Tools/`, unit tests in
`HandyToolsTests/EngineTests.swift`, and a live-user UI flow in `HandyToolsUITests/ToolFlowTests.swift`.

Inclusion rule (owner's): a tool is in only if it (1) exposes options iOS doesn't easily give you,
or (2) merges several common tools into one better one. Count stays a multiple of 10.

## Page 1 · Files, docs & sharing

| id | Tool | What it does that iOS doesn't | Engine |
|---|---|---|---|
| fitit | Fit It | Photo/video/PDF → exact size limit (2 MB portal, 25 MB email, 200 KB gov photo…) | SizeTarget |
| scan | Scan | Scan/photos/PDF(s) → clean up → saved signature + ink + typed fields → OCR → **searchable PDF** (invisible text layer), under-size, split | DocEngine |
| studio | Studio | Cut-out (bg colours), passport/ID photo (5 specs + print sheet), resize (px or size), convert JPG/PNG/HEIC | ImageStudio |
| video | Video | Shrink to limit (bitrate read-out), trim (no re-encode), MP4, mute, audio-only, GIF (video or photos); chainable; background-safe | VideoEngine, SizeTarget |
| formatfix | Format Fixer | Batch HEIC/MOV → JPG/PNG/MP4 the rest of the world opens | VideoEngine |
| scrub | Privacy Scrubber | Shows GPS/device metadata on a map, auto-boxes faces/text, paints them out, exports a clean copy | Scrubber |
| capture | Capture | Live text + code reader: tap a line or grab all → copy / translate / call / open / calendar / ask | DataScanner, Detected |
| qrwifi | QR & Wi‑Fi | Smart scan results, make link/Wi‑Fi/contact/phone/batch codes, printable Wi‑Fi card | QRPayload, QRGen |
| stitch | Long Screenshot | Stitches overlapping screenshots, removes repeated chrome | Stitcher |
| shareready | Share‑Ready | One-tap recipes: portal 2 MB, email 20 MB, message, gov photo — convert + strip + fit | SizeTarget, VideoEngine |

## Page 2 · Camera, sensors & everyday

| id | Tool | Highlights | Engine |
|---|---|---|---|
| light | Flashlight+ | Patterns, SOS, **Morse a message**, auto-off, full-screen light tones, front-camera mirror | Torch, FrameCamera |
| instruments | Instruments | Level/protractor (zero-able), true-north compass, sound meter (trace, peak, calibration), lux meter, barometer/altimeter, metal detector, calibratable ruler | SensorMath + sensors |
| measure | Measure | AR tape: distance chains, area (Newell), height from floor; LiDAR mesh when present | MeasureMath, ARKit |
| magnify | Magnifier+ | 12× zoom, freeze-then-zoom, high-contrast/inverted/yellow-on-black/white-on-blue, sharpen, torch, save | FrameCamera, CI |
| procam | Pro Camera | Manual ISO/shutter/focus/WB, EV, peaking, zebras, histogram, grid, RAW+HEIF, frame-averaged long exposure | ProCameraController, ProImage |
| gpsdash | GPS Dashboard | Speed/heading/altitude/accuracy, trip computer with noise filtering, windshield HUD, coordinates (DD/DMS/link), park & walk back | TripTracker, GeoFormat |
| audiolab | Audio Lab | Chromatic tuner (NSDF), instrument presets, A4 calibration, tone generator, L/R + sweep tests, 165 Hz water eject | Pitch, ToneGenerator, Tuner |
| rest | Rest | Synthesized white/pink/brown/fan/rain/ocean (never loop), fading sleep timer, background audio, **night recorder** keeps only loud moments | NoiseSynth, SoundEventDetector |
| colorvision | Color Vision | Live daltonization (protan/deutan/tritan, severity, strength), one-hue highlight, colour namer, simulate; camera or photo | ColorVision (matrices, cubes) |
| describe | Scene Describer | Vision labels/people/animals/text → spoken sentence; continuous; read text aloud; AI polish | SceneDescriber, Speaker |

## Page 3 · Words, AI & accessibility

| id | Tool | Highlights | Engine |
|---|---|---|---|
| textstudio | Text Studio | Fix / rewrite (tones) / shorten / expand / bullets / summarize / reply / subject; spell-check + extractive fallbacks | TextTools, AIEngine |
| translate | Translate | Text, **Talk** (two-way spoken conversation), photo OCR; Apple on-device Translation | Translation, SpeechStream |
| voicenotes | Voice → Notes | Unlimited rolling on-device transcript, summary + to-dos, saved searchable notes | SpeechStream, TextTools |
| livecaptions | Live Captions | Continuous captions, language picker, big text, type-to-speak, save | SpeechStream, Speaker |
| shield | Message Shield | Explained scam findings + link checks + advice; screenshot OCR; AI second opinion | ScamAnalyzer |
| readaloud | Read Aloud | Text/PDF/photo/web → sentence-highlighted TTS, voices, speed, background, export audio | Reader, ReadSource |
| explain | Plain‑English Explainer | AI four-part walkthrough + 110-term glossary + red-flag clauses (always on) | Glossary, AIEngine |
| datagrab | Data Grabber | Receipt → CSV/expense row, card → vCard, flyer → .ics, table → CSV | DataGrab |
| clips | Clipboard | Stack + per-clip actions (clean tracking links, call/map/calendar), snippets | ClipStore, SnippetStore, LinkCleaner |
| vault | Vault | AES-GCM under biometry-gated Keychain key; secrets w/ 30-s clipboard; camera-direct photos; move-from-Photos; documents; shred | VaultCrypto, VaultStore |

## Quality gate (runs on every push to a staging branch — `ios-check.yml`)

1. `xcodebuild test` on the newest iPhone simulator.
2. **EngineTests** — deterministic fixtures (rendered text, noise, synthetic movie, synthesized tones)
   assert real outcomes: PDF `findString("HELLO")` hits, shrink lands under the byte limit, deutan
   matrices collapse red/green, 440 Hz detects within 1.5 Hz, the receipt parses to 13.72, the
   phishing link is flagged, AES tampering is rejected, …
3. **ToolSmokeTests** — opens all 30 tools by deep link.
4. **ToolFlowTests** — launches each tool with `-sample` (generated photo / screenshots / receipt /
   document / movie preloaded) and drives it like a user: taps the primary action, switches modes,
   types into fields, and asserts the outcome (share button, verdict, result card).
5. Failures are posted as check annotations (`::error::`), readable via the API when log downloads are blocked.

`ios-shots.yml` (touch `ios/.shots`) screenshots every route light+dark into `ci-logs:ios-shots-v2/`.

## Device-only behaviour (can't be exercised on the simulator)

Camera (Scan camera, Capture live, Color Vision live, Magnifier live, Pro Camera, Measure AR,
Scene Describer live, mirror), torch, microphone/speech (tuner, captions, voice notes, night
recorder), barometer/magnetometer/GPS, Translation language downloads, Apple Intelligence
(iPhone 15 Pro+), Face ID (Vault unlock). Everything else runs identically on the simulator.

## Not in the app (decided)

Alarm Pro, Sticky Notes (+ widget content), Wallet, Timers, Web Clip, Pocket, Photo Studio,
the ten "AI_*" one-shot tools — superseded by the 30 above. `StickyWidget` target still exists
in the project (orphaned); remove or repurpose before 1.2.

## Deploy

1. Owner says "deploy".
2. Merge `tools-v2` → `handytools` (carries shared-cert Fastfile, layout fix, Web→Home + Rate/About fixes).
3. `IOS_DIST_P12_B64` secret must be set in this repo (and in app-calculator) — see `ios/fastlane/Fastfile`.
4. `ios.yml` builds, screenshots every route, uploads to TestFlight.
