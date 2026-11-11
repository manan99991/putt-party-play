# iOS parity log (read-only audit, nothing deployed to iOS)

Rule: every enhancement made to an existing Android tool also goes into iOS. Nothing is changed or shipped on iOS until the first App Store review clears. Then bundle into one update.

Audit date: 2026-11-05. Source: ios/HandyTools (read only).

## Android enhancements to port (builds 159-161)
| Android change | iOS status | Work for iOS |
|---|---|---|
| Keep 4K / original in video shrink | VideoEngine.transcodeH264 has maxDimension nil = original, but no visible 4K choice found in Video shrink options | Confirm the shrink UI offers an original-resolution choice; add if missing |
| Photos kept up to 4096 px | Studio resize already offers 4096 px, 2048, 1280, 800 | Nothing |
| GIF length, smoothness, start point, size | Already richer than Android (start, length, fps 8/10/15, speed, width) | Nothing. Check max length is above 3 s |
| Scan resolution up from 2200 px | ScanView loads at 2400 px; Capture loads at 1600 px | Raise Capture 1600 to ~3200 for sharper text |
| PDF export sharpness (150/200/300 dpi) | FormatFix renders PDF previews at 240 px; check the real PDF to image export path | Find the export path and add a dpi choice |
| Batch video queue | FormatFix already batches 10 free / unlimited Pro. Video shrink is one at a time | Add multi-select queue to Video shrink |
| Audio quality choice (64-320 kbps) | Audio uses AVAssetExportPresetAppleM4A, no bitrate choice | Add a bitrate choice (AVAssetWriter AAC settings) |
| Rest: smooth brown, ocean, fan | iOS uses AudioLab; not checked | Listen-check brown noise for clipping |
| Back arrow on every screen | iOS: dead-end sweep was done before submit | Re-check Settings and Privacy |
| Voice file transcription | iOS uses SFSpeechRecognizer; not affected by the Samsung mic clash | Nothing |

## iOS-only findings (not Android issues)
- File Viewer text preview cut at 20,000 characters (Android 60,000). Raise or load on scroll.
- CaptureView downscales to 1600 px, the lowest cap found on either platform.
- ScanView page thumbnails 1400 px are fine; source 2400 px could go higher.

## Next
1. Wait for Apple review. 2. Fix the items above in one branch. 3. Build and test, then ship via Ship-Build, Ship-Stage and Ship-Store.

## Update 2026-11-05 (iOS work started, user approved full plan "A")
Done on branch handytools-fixes-pending (not yet shipped, nothing touched in App Store Connect):
- Per-theme tool icons: 150 imagesets ic_<id>_<theme> (256px), shown on every home card and every tool page header, SF Symbol fallback.
- Capture tool image cap 1600 -> 2400 px.
- File Viewer text preview 20,000 -> 60,000 characters.

Checked, no change needed:
- Video shrink already allows 3840 px (4K), it never forced 1080p, so "Keep 4K" is already covered.
- iOS has no PDF-to-image export, so the Android sharpness choice has no iOS equivalent.

Not ported (separate, bigger changes): batch queue in Video shrink (Format Fixer already batches), audio bitrate choice.

Open check: App Store Connect shows the version in review as 1.2.34 but ios/project.yml says 1.2.43. Confirm the digits before resubmitting.

- Flashlight+ (iOS): screen now stays awake while the torch is on, and the torch relights when the app returns to the foreground. Fixes the torch dying when auto-lock kicked in. Android keeps the torch on through screen-off already (CameraManager), so no change there.

## Builder (chain tools) — iOS and Android
- iOS: `Engines/ChainRunner.swift`, `ChainPlanner.swift`, `Tools/BuilderView.swift`, `BuilderStyle.swift`.
- Android: `tools/builder/Chain.kt`, `ChainRunner.kt`, `BuilderScreen.kt`; entry row on Home, route `builder`.
- Shared format: `tenzy-tool:{json}` with the same block ids. Android has 10 of the 13 blocks; cutout, enhance and passportPhoto are iOS-only for now, so a tool using them pastes on Android with a plain "can't be added" note.
- Describe it: both platforms have the keyword planner. iOS also uses the on-device language model where the phone has one (Apple Foundation Models). Android has no equivalent bundled, so it is keyword-only.
- Live per-step preview runs on a sample in both editors (receipt sample for read-text chains, sample text for text chains, sample photo otherwise).

### Builder v2 (batch + text blocks) — iOS and Android
- New blocks, same ids on both: `cleanText` (Tidy text), `pullDetails` (links, emails, phones), `makeTable` (text to CSV). Pure logic in `TextTidy.swift` / `TextTidy.kt`, same rules and same regexes; unit-tested on both (`TextBlockTests`, `BuilderLogicTest`).
- Batch run: any photo-first tool takes up to 20 photos at once; each result is written to a temp folder as it finishes, a failed photo gets its own note and never stops the rest; one "Save or share all" and "Copy all text".
- Describe it: understands the new blocks and chains tidy → next step ("tidy my notes then summarize in 2 sentences"). "Tidy up this photo" stays a picture job.
- Duplicate on saved tools; text previews for CSV, contact and calendar files while building; clearer "found nothing" wording for text blocks.
- Still iOS-only blocks: cutout, enhance, passportPhoto (an Android phone can't import tools that use them).
- No new permission, no new data; Privacy policy and rulebook unchanged.

### Share to Tenzy (run a tool on what you share) — iOS and Android
- iOS: the share-sheet entry is now "Tenzy" (was "Save to Clips", text and links only). It accepts up to 20 photos, text and links, lists the user's tools that fit (own tools first, last-used on top), runs the tool inside the share sheet, then offers Share (onward to WhatsApp, Mail, Messages...), Copy and Done. "Save to Clips" is still the first row for text. Photos are opened at sharing size (3000 px long side) so a 48 MP photo stays inside the share sheet's memory limit.
- iOS: saved tools moved to the App Group (one-time copy from the app's own defaults) so the share sheet sees them. The chain runner and its engines are compiled into the extension; video helpers are stubbed there because video tools are not offered in the share sheet.
- Android: a photo shared to Tenzy now opens "Run a tool on this photo" (pick a tool, it runs at once, result has Share). "Just open the photo" keeps the old File Opener path; other file types still open in File Opener.
- Both: "Make a contact" stops with a plain reason when there is no phone or email (a name-only contact can't be sent by WhatsApp or Messages).
- Not yet on Android: sharing several photos at once, or text, into a tool.
