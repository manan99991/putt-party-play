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

### "Then": send a result to a set person — iOS and Android
- A tool can now end with Share (default), Email or Message, with an optional recipient. When the run finishes the system composer opens already filled in (recipient, subject = tool name, result attached or pasted); the person taps Send. No app may send by itself on either platform.
- Android also has "WhatsApp" (opens WhatsApp with the result attached; the person picks the chat). iOS has no way to open WhatsApp with a file, so a tool made on Android that ends in WhatsApp loads on iPhone and ends with Save or share.
- If the phone can't do it (no Mail account, no SMS, WhatsApp not installed) the tool says so and falls back to the share menu; never a dead button.
- A copied/shared tool never carries the recipient address.
- Android: image results now have a "Save or share" button (there was none).
- Not yet: the share-sheet extension on iOS still ends with Share only.

### More blocks (tranche 1) — iOS and Android
- Both: `scamCheck` (verdict, top reasons, one thing to do), `cleanLinks` (strip tracking from every link in the text), `makeQr` (text or link to a QR image), `photoPdf` (photo to PDF; searchable on iOS, plain on Android).
- iOS only for now: `priceCompare` (best deal by unit price), `describe` (what the photo shows), `identify` (plant, animal, object or barcode). Android has no matching engine wired yet, so a tool using these can't be imported on Android.
- iOS: these also run in the share sheet (their engines are compiled into the extension; the on-device model polish and speech are stubbed there).
- Describe it understands: scam, best deal, tracking/clean link, QR, PDF, identify, describe (the last three and best deal on iOS only).
- New starters: "Is this message a scam?", "Link without the tracking", "Photo to PDF", "Text or link to QR code" (both); "Shelf photo to best deal", "What is this?" (iOS).

### Builder: start from what you have, steps grouped by goal — iOS and Android
- A new tool first asks "What do you start with?" (A photo / Text). After that the add-step list shows only steps that fit, under goal headings: Make it easy to send, Keep it private, Make it look better, Read what's in it, Understand it, Clean it up, Turn it into something, Money. Same goal wording on both platforms (`Block.goal`).
- Video, voice, contacts and files are named as coming next; they are not start options yet.

### Upload-form and ID blocks — iOS and Android
- `watermark`: repeats your words plus the day it ran diagonally across the photo (default "For verification only"). `resizePhoto`: exact pixel size by cover-and-trim (35x45 mm = 413x531, 600x600, 1080 square, 4:5, 16:9).
- Shrink to size now picks from a list of limits down to 20 KB (was 0.25 MB minimum) for portals that demand 20-100 KB.
- New starters on both: "Privacy share shield" (hide faces and numbers, strip location, under 2 MB), "ID copy with a safety watermark", "Portal photo: 35x45 mm under 50 KB".
- Describe it (iOS): understands "watermark", "under 50 kb", "35x45" / "pixels". Android planner not yet.

### Paperwork, part 1: scan to start, and one PDF for all pages — iOS and Android
- Run screen of any photo-first tool has "Scan a document" next to "Choose photos" (iOS: Apple's document camera; Android: Google's document scanner, falling back to choosing photos where it is missing). Several pages run as a batch.
- Tool option "Put all pages or photos into one PDF" (`combine`). iOS joins whatever the pages became (PDFs page after page, pictures a page each). Android keeps each page as a picture and builds the PDF at the end, so a trailing "Make a PDF" step is skipped per page. Text or mixed results stay separate on both.
- New starter on both: "Scan pages into one PDF".
- Not yet: saved stamps (signature, name, date), the stamp step, the naming step.

### Paperwork, part 2: sign and stamp, file names — iOS (stamp), both (names)
- iOS `stamp` ("Sign and stamp"): puts the saved signature, your name and today's date on the page at remembered places (fractions of the page, `StampPlan`), burned in. Editor: toggles, draw-once signature, drag chips on a sample page. Run screen asks for the signature or name up front if the tool needs them and they aren't saved. The signature moved to the App Group (one-time copy) so the share sheet can sign.
- Both: a tool can name its result file (`fileName`, "{date}" and "{tool}" tokens, unsafe characters dropped, -1, -2 for several). Same rules in `ChainName` (iOS) and `TextTidy.fileName` (Android).
- Both: new goal heading "Paperwork" (first in the list) holding Make a PDF, and Sign and stamp on iOS.
- iOS starter: "Sign a form and send it" (stamp, PDF, one PDF for all pages, email, named "Signed form {date}").
- Android got the stamp step later (see "Sign and stamp on Android" below).
- UNBUILT: everything in this section was written while CI builds were paused for cost, so it has not been compiled or run.

### Receipts: one expense row, and a running sheet — iOS and Android
- `expenseRow`: a receipt's text as one row (Date, Merchant, Total, Tax, Currency; Android fills date, merchant and total only). `addToList`: adds the rows to the same CSV every run and hands back the whole sheet; the sheet name takes "{month}" so a new one starts each month (default "Expenses {month}"). The header is never repeated; two identical purchases are both kept.
- Builder previews run as a dry run on both platforms, so trying a tool on the sample never writes to a real sheet.
- Starter on both: "Receipt into this month's expense sheet". Describe it: "expense sheet", "ledger", "running list".
- Sheets live on the phone (iOS App Group "Lists" folder; Android files/lists). Not yet: a screen to see, rename or clear sheets; return and warranty reminders.
- UNBUILT in CI (builds paused for cost).

### People and ID jobs — iOS and Android
- `chatLink`: a wa.me link for the number in the text (country code added only when missing; per-step default from the phone's region). New ending "Open" follows the link the tool made. Starter: "WhatsApp a number without saving it".
- `contactQr`: the contact details in the text as a QR code another phone can scan (needs a phone or email). Starter: "My contact as a QR code".
- With "one PDF": "All on a single page" lays every photo on one A4-shaped sheet. Starter: "Both sides of an ID on one page" (watermarked).
- Same rules both platforms (`ChainText.chatLink` / `TextTidy.chatLink`, `slots`). iOS opens the link automatically when the run finishes; Android shows an "Open it" button.
- UNBUILT in CI (builds paused for cost).

### Reminders: run a tool at a set time — iOS and Android
- A tool can carry a reminder (`schedule`: hour, minute, days with 1 = Sunday ... 7 = Saturday, empty = every day). Same JSON on both; never included in "Copy to share", and a pasted tool arrives without one. Same label wording ("Weekdays at 6:30 PM").
- It is a reminder, not a silent background run: the phone shows a notification at that time and tapping it opens the tool ready to run. The editor says so.
- iOS: repeating local notifications (`ToolSchedules`, one per chosen weekday, capped at 56 for the 64-per-app limit); `ToolNotifications` routes the tap to Build your own, which opens the tool.
- Android: ordinary inexact alarms (`ToolReminders`, no exact-alarm permission, can be a few minutes late), re-armed after each one, on app start and after a restart (new normal permission RECEIVE_BOOT_COMPLETED). Asks for notification permission when the switch is turned on.
- Editor: "Remind me to run this" switch, time, day chips (Mon first). The tool row shows the reminder.
- UNBUILT in CI (builds paused for cost).

### Shortcuts actions: tools that run by themselves — iOS only
- Three actions in the Shortcuts app: "Run a Tool on a Photo", "Run a Tool on Text" (both run in the background and hand the result back as a file; text results are a .txt Shortcuts reads as text) and "Open a Tool". Saved tools and starters are both offered.
- This is the iPhone route to real automation: a Shortcuts automation (time of day, arriving somewhere, Action button, Back Tap, opening an app) can take a photo or the clipboard, run a Tenzy tool, and send the result on.
- Android has no Shortcuts app. Its equivalent (a tool that runs when a new photo or screenshot appears) is not built yet.
- UNBUILT in CI (builds paused for cost). App Intents code is the least certain of the unbuilt work: expect compile fixes on the first build.

### A tool that offers itself on a new photo or screenshot — Android only
- A tool that starts with a photo can be set to "New photo" or "New screenshot" (`auto`, kept on the phone, never shared). When one appears, Tenzy shows a notification; tapping it runs the tool on that picture and the tool's ending (WhatsApp, email, share) follows. Nothing runs until the tap.
- How: a system job woken by photo-library changes (`PhotoWatch`, no running service), re-armed after each firing, on app start and after a restart. Skips pictures older than two minutes and Tenzy's own saved results. Needs "all photos" access and notifications.
- iOS cannot notice a new photo. The iPhone route is the Shortcuts actions above.
- UNBUILT in CI (builds paused for cost).

### My sheets — iOS and Android
- A screen listing the sheets tools add to: entries and last change, tap to see the rows, Send (the .csv file), Rename, Undo last (removes the newest entry, the header always stays), Delete with a confirm. Shown in Build your own once a sheet exists.
- Same wording and rules both sides (`RunningList` / `SheetStore` + `TextTidy.sheetRows`, `withoutLastRow`, `sheetSummary`).
- UNBUILT in CI (builds paused for cost).

### Sign and stamp on Android
- `stamp` now exists on Android with the same plan text as iOS (`StampPlan`), so a tool using it copies between phones. Signature is drawn once and kept in the app's files (`StampBook`), name is typed once; both stay on the phone.
- Editor: three switches, draw-once pad, name field, and a small page where each label is dragged into place. Starter "Sign a form and send it" added on Android.
- Difference: Android sizes the text to its width with a cap of 5% of page height; iOS uses its own font-fit. Close, not pixel-identical.
- UNBUILT in CI (builds paused for cost).

### More ways in: speak, a contact, a PDF — iOS and Android
- Text tools: four buttons above the text box. Paste; Speak (iOS: on-device live dictation via `SpeechStream`; Android: the phone's own voice typing screen); Contact (the one contact tapped, as name / phone / email lines; iOS gives all phones and emails, Android gives the name and the tapped number); PDF (its words).
- Photo tools: "Choose a PDF" turns each page into a picture (long side about 2000 px, up to 20) and runs the steps on every page, like scanned pages.
- A PDF with no text layer gets a plain message pointing to a photo tool with Read text.
- No new permissions: both contact pickers hand over only the tapped contact; iOS speech and microphone strings already existed.
- Not done: video as a starting point (needs a new kind of result that isn't held in memory).
- UNBUILT in CI (builds paused for cost).

### How-it-works card and "What do you have?" — iOS and Android
- A three-idea card at the top of Build your own until "Got it" (start with what you have, stack steps, choose how it ends), with "Show me one" opening the Privacy share shield starter in the builder so its previews run on the sample. "How does this work?" brings it back. Hidden from automated iOS runs.
- Starters can be narrowed to "A photo or scan" or "Text". Same wording both sides (`BuilderIntro`).
- UNBUILT in CI (builds paused for cost).
