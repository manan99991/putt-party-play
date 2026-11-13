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
- Video became a starting point later (see "Video tools" below).
- UNBUILT in CI (builds paused for cost).

### How-it-works card and "What do you have?" — iOS and Android
- A three-idea card at the top of Build your own until "Got it" (start with what you have, stack steps, choose how it ends), with "Show me one" opening the Privacy share shield starter in the builder so its previews run on the sample. "How does this work?" brings it back. Hidden from automated iOS runs.
- Starters can be narrowed to "A photo or scan" or "Text". Same wording both sides (`BuilderIntro`).
- UNBUILT in CI (builds paused for cost).

### Wi-Fi join code, and two more steps on Android
- `wifiQr` (both): finds the network name and password in text (labels followed by ":" or "="; or exactly two single words) and makes a Wi-Fi QR code a guest's camera joins from. Open networks are marked open; awkward characters are escaped. Starter "Wi-Fi sign to a code guests scan" (Read text, then Wi-Fi join code). Describe it: "wifi".
- Android gained `identify` (top three guesses with how sure, barcode first) and `cutout` (Google's on-device cut-out; if its one-time model isn't on the phone the step says how to get it). Starters "What is this?" and "Cut out a subject" added on Android.
- Android gained the remaining four steps later (see "Every step on both phones" below).
- iOS: the start picker has a line sending video to Fit It, since video is not a builder step.
- UNBUILT in CI (builds paused for cost).

### Return-by reminder — iOS and Android
- `returnBy`: a receipt's text becomes a calendar entry "Last day to return: <store>" at 9:00, so many days after the receipt's date (today if it shows none). Window is 14, 30, 60 or 90 days (default 30). A window that has already ended says so instead of making a stale entry.
- Starter on both: "Receipt to a return-by reminder" (Read text, then Return-by reminder). Same rules both sides (`ChainText.returnDeadline` / `TextTidy.returnDeadline`).
- UNBUILT in CI (builds paused for cost).

### Every step on both phones
- Android gained `priceCompare` (a faithful port of the iPhone unit-price rules, `PriceDeal`), `describe`, `enhance` and `passportPhoto`. A unit test lists every iPhone step id and fails if Android is missing one, so a tool always pastes across.
- Real differences that remain:
  - `describe`: iPhone uses its scene describer (and the on-device model where available); Android builds one or two sentences from detected things, people and the first words. Plainer, same job.
  - `enhance`: iPhone uses its photo enhancer; Android stretches tones between the real darkest and brightest parts and lifts colour slightly.
  - `passportPhoto`: Android cuts the person out and centres them on white at the official size; without the cut-out model it crops instead. iPhone places by face position.
  - `identify` on Android names objects and reads barcodes; it does not name plants or breeds the way the iPhone one can.

### Video tools — iOS and Android
- A tool can start with a video. Steps: `videoShrink` (10, 16, 25, 50 or 100 MB; best effort, re-saved so the location is left behind), `videoStill`, `videoMute`, `videoAudio`. A still can go on into the photo steps (still, read text, summarize).
- A video stays a file on disk and steps pass its location along (`ChainPayload.video(URL)` / `Payload.Clip`). Starters: email under 25 MB, chat under 16 MB, grab a still, without its sound. Describe it understands "video".
- iPhone uses the same engine as Fit It and Video. Android runs its own exports (`VideoSteps`, Media3), one retry smaller if the first lands over the limit.
- Not in the share sheet (it takes photos and text only). The editor shows what each video step will do rather than a sample result.

### Share sheet finishes the job — iOS
- When a tool run from the Share menu ends with "Email it" or "Message it", the result screen offers that first: the composer opens filled in with the result attached. "Open it" endings are not possible from inside another app's share sheet, so those fall back to Share.
- Results from the share sheet now take the tool's file name when it has one.

### Free logic check
- `tools/logic-check/run.sh` compiles the plain logic of both platforms on Linux and runs the unit tests that need no phone (66 Android, 67 iOS at the time of writing). It caught a wrong assertion name and two stale counts before any paid build.
- UNBUILT in CI as of this entry: everything from "Paperwork, part 2" down still needs its first real build.

### New starts and steps, with a check for what the phone can do — iOS and Android
Asked for as "build them all, with a graceful error when the phone doesn't support it; they can build whatever tools are available".

- **Two new things a tool can start with**: a recording (`audio`) and a PDF (`pdf`). Both travel as file bytes; the kind comes from the file ending (pdf, or m4a/mp3/wav/aac/caf/ogg/flac). `photoPdf` now gives a PDF and `videoAudio` gives a recording, so "photo, make a PDF, lock it" and "video, keep the sound, write out what is said" chain.
- **16 new steps, same ids on both phones**: `speechText`, `readAloud`, `translate`, `rewrite`, `readCode`, `pageText`, `textPdf`, `pdfShrink`, `pdfLock`, `pdfPages`, `pdfText`, `videoTrim`, `videoGif`, `videoRotate`, `videoVertical`, `videoCaptions`. 52 steps in all. The Android test now fails if the two lists differ in either direction.
- **What a phone can't do is said, not hidden**: `Block.unavailable` (iOS) / `ExtraSteps.unavailable` (Android) gives one sentence or nothing. A step the phone can't run is listed greyed out under "Not on this phone" with the reason; a starter that needs one is not offered; a saved or pasted tool that has one shows a warning and, if run, stops with the same sentence. Every other step keeps working.
  - `speechText`, `videoCaptions`: only where speech is recognised on the phone itself (iPhone: on-device recognition for the phone's language; Android: version 13 or newer with a recogniser). A recording is never sent away.
  - `rewrite`: iPhone needs the on-device writing model. **Android has no writing model, so it is always unavailable there.**
  - `videoCaptions`: **iPhone only for now.** Android says so and points to "Keep only the sound" then "Write out what is said".
- **Several photos into one picture**: a tool can end as a collage (`collage` on the chain, same grid maths both sides). Several PDFs can be joined into one (`combine` on a PDF tool).
- **More ways in**: Location (address and a map link into the text box) on both; Record on the run screen on iPhone (Android picks a recording made in the phone's recorder).
- **15 new starters** (49 in all), same ids both sides: voice memo to notes, meeting recording to tasks, is this QR code safe, sign or menu to English, web page to a clean PDF, web page to 3 sentences, text to an audio file, PDF under 5 MB for email, join PDFs, first page of a PDF, first 30 seconds cropped tall, video to a GIF, what was said in a video, photos into one collage, send where I am.
- Real differences that remain:
  - `translate`: iPhone uses the system translator (it asks before downloading a language, and only works while Tenzy is open on screen); Android uses the same on-device packs as its Translate tool and a new small on-device language detector.
  - `pdfShrink`: iPhone works down to the size picked; Android makes one smaller copy and never hands back a bigger one. `pdfPages` and `pdfLock` keep the PDF's real text on both (PDFKit / pdfbox).
  - `readAloud`: iPhone gives an .m4a, Android a .wav and reads the first 3,900 characters (the system voice's limit).
  - `videoGif`: the first 6 seconds on iPhone, the first 4 on Android (its GIF Maker recipe).
  - iPhone share sheet: runs the code, link, text-to-PDF and PDF steps; steps that need a voice, the translator, speech or the video encoder are app only, so tools using them aren't offered there.
- A PDF password typed into "Lock with a password" is kept with the tool on the phone and is left out when the tool is copied to share (unit-tested on iOS).
- "Describe it" understands the new jobs on both (same keyword rules, same tests).
- Local logic check: 75 Android and 80 iOS tests. The check now deletes the old build first, after it once reported a stale result.
- NOT YET RUN ON A PHONE by anyone: everything in this entry.

### Names, a smarter Describe it, and three faster ways in — iOS and Android
Asked for after the first phone pass: "let them name the tool", "make Describe it much smarter, even with spelling mistakes or half the information", plus the three ideas agreed before it.

- **Names**: Rename in a tool's menu on both. A tool saved with no name (or left as "My tool") is named for what it does: a starter's name when the steps match one, otherwise "First step + Second step" or "First step + 2 more". Describe it uses the request as the name only when it is 28 characters or fewer; a long sentence no longer becomes the name. The editor says what the name will be. Fixed the My tools row on iPhone, where a long name squeezed the Run button.
- **Describe it reads what people actually type** (`PlannerWords`, same lists and rules both sides, same tests):
  - Spelling: a word of five letters or more that is one slip away (two for long words) from exactly one word the rules know, with the same first letter, is read as that word. "shrnk my foto and remve the loction" works. Swapped letters count as one slip. Short forms (pic, vid, msg) are spelt out. Words it doesn't know, numbers and punctuation are untouched, and a list of ordinary words (store, phone, price...) is never "corrected".
  - Meaning: "personal data / sensitive / confidential" means cover faces and numbers and drop the location; posting a photo online or to a social app means drop the location and shrink it. "...and email it" or "...text it" sets how the tool ends.
  - Half a request: if no rule fits, the starter whose name shares a word with the request is used (so "colage" opens the collage starter); failing that, the most useful tool for the kind of thing mentioned (a photo: safe to share and small). The editor then says it is a best guess. Only a request that names nothing Tenzy works with gets "I couldn't tell".
  - iPhone: the rules now go first and the on-device model is only asked when the rules are unsure. Before, the model went first and could ignore half the sentence.
  - Android's Describe it gained the photo jobs it was missing (identify, describe, cut out, enhance, passport, watermark, exact size, kilobyte limits, PDF last).
- **Start with what you have**: a card at the top of Build your own. Pick a photo, video, file (PDF, recording) or paste text or a link, and the tools that fit are listed, yours first; tap one and it runs on it.
- **Share from any app**: Android now offers tools for a shared video, recording, PDF, link or text (before: photos only; a shared link went straight to the web-shortcut tool, which is still one tap away from the list). iPhone's Share menu now takes PDFs as well as photos, links and text. Videos and recordings can't run inside the iPhone share sheet (its memory limit, and no speech or video engine there), and it says so.
- **One tap from the Home screen**: Android: "Add to Home screen" in a tool's menu pins it as its own icon. iPhone: a second widget, **My Tools**, shows the first four tools (small size: the first one); "Move to top" chooses which. iPhone has no way for an app to add its own Home Screen icon, so the menu item explains how to add the widget.
- Local logic check: 84 Android and 87 iOS tests.
- NOT YET RUN ON A PHONE by anyone: everything in this entry.

### Updates that ask for themselves — Android
- Internal testers were staying on old builds because Play's background auto-update can take days. The app now asks Play for a newer build on each cold open and shows Play's full-screen update step. iPhone: TestFlight has its own Automatic Updates switch per tester; an app cannot trigger a TestFlight update.
- It takes effect from the build after the one that carries it, so testers need one manual update first.

### Just for fun: stickers, emoji faces, memes, mosaics, boomerangs and speed — iOS and Android
- Six new steps with the same ids on both phones, under a new goal "Just for fun": `sticker`, `emojiFaces`, `meme`, `emojiMosaic`, `videoSpeed`, `videoLoop`. 58 steps on each phone.
- A new option on a photo tool, `gif`: several photos play one after another as one GIF (next to "one PDF" and "collage"; only one of the three can be on).
- Eight new starters with the same ids (57 on each phone): photos-gif, sticker-maker, emoji-faces, meme, emoji-mosaic, video-boomerang, video-slowmo, video-fast.
- Describe it reads the fun requests first ("make a meme", "boomerang", "slow mo", "sticker of my dog", "gif from my photos"). "sticker" now makes a sticker; "remove the background" still cuts out.
- A meme's words can be typed on the run screen each time; the step's own words are only the starting text. With no words yet, the builder preview shows TOP LINE / BOTTOM LINE.
- Differences that are on purpose:
  - iPhone: any video tool can also start from a Live Photo (its short video). Android has no Live Photos, so there is no such button.
  - Sticker cut-out: iPhone uses the system's subject lift; Android uses Google's on-device cut-out, which needs its one-time download (the step says so).
  - Boomerang GIF: iPhone 400 px and 25 frames, Android 360 px and 20 frames (Android's GIF writer is slower).
  - Speed change drops the sound on both.
- Not checked on a real phone yet: every drawing step here. The unit tests cover the logic and, on iPhone, the drawing sizes.

### Sketch and comic, voice changer, before and after, recent results, tool links — iOS and Android
- Two new steps with the same ids on both phones (60 each): `artFilter` (pencil sketch, comic, black and white, pop art) and `voiceChange` (chipmunk, deep, giant). Six new starters (63 each).
- `artFilter` is the same arithmetic on both phones (`PixelArt`, plain numbers, unit-tested on both), worked out at up to 1600 px on the long side.
- `voiceChange` plays the recording faster or slower, so the pitch and the length change together. It gives a .wav. At most the first ten minutes.
- A new option on a photo tool, `versus`: the first and last photo side by side with BEFORE and AFTER on them. Only one of one-PDF, collage, GIF and before/after can be on.
- Recent results: the last 20 results are kept in the app's own folder and listed under "Recent results" on Build your own, with Save or share, Copy, Remove and Clear. A result over 150 MB is not kept.
- Tool links: a tool can travel as `https://manan99991.github.io/tenzy/t.html#<tool>` or a QR code of it. Both apps open `tenzy://import?d=<tool>` and paste a link with the Paste button. Sharing was switched off until the page was published; Manan approved it on 12 Nov 2026, the page is live, and `ToolLink.live` / `ToolLink.LIVE` are now true (iOS 1.2.57, Android 1.0.14).
- Differences that are on purpose: iPhone shows the QR sheet as a sheet, Android as a dialog. On iPhone a batch run is kept as one entry with all its files; the same on Android.
- The local Android check now refuses org.json the way Android's plain unit tests do, after a test that used it passed locally and failed in CI.
- Not checked on a real phone yet: all of it.

### Monetization model + Aurora default — iOS and Android
- Free tier now: keep up to 2 saved tools (`BuilderLimits.canSave`), built only from the 10 basic free steps. Every other step is a Pro step (`Block.isProStep`); `Chain.needsPro`/`proSteps` are shared, pure and unit-tested on both phones (Android 95, iOS 98).
- Gating UI mirrored on both: the add-step picker marks Pro steps "Pro" and routes a free tap to the paywall; Save and the run screen block a free user on a tool that uses a Pro step, with a lock card / upgrade. The in-builder "the basics are free; the rest are Pro" note shows for free users.
- Paywall copy updated on both (unlock all tools, every builder step, unlimited saved tools, no ads, no daily limits); builder intro mentions the free/Pro split. No live store metadata touched — marketing lives in `docs/listing-draft.md` (consolidated update section) until Manan approves.
- Look: Aurora (Direction C) is the free default theme on iOS — dark ground, lime accent (with an `onAccent` token so bright accents keep dark button text), flat per-tool gradient Home tiles. **Android theme parity is the one remaining build task.**
