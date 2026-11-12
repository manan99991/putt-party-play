# Store listing draft: Tenzy with Build your own

Status: DRAFT. Nothing here is live. The live text is still in `ios/fastlane/metadata` and `android/fastlane/metadata`
and has not been touched. This goes live only after (1) the build containing these features has shipped and been tried
on a phone, (2) screenshots are re-captured from that build, and (3) Manan says yes.

## The name

Keep **Tenzy**. Changing the name on either store resets search ranking and confuses the people who already have it.
What changes is the line after the name and the first screen of the description: from "a box of 30 tools" to
"make a tool that does your whole job".

## App Store (iPhone)

| Field | Limit | Proposed | Length |
|---|---|---|---|
| Name | 30 | Tenzy: Scan, Shrink & Automate | 30 |
| Subtitle | 30 | Build your own phone tools | 26 |
| Promotional text | 170 | Build a tool once, use it forever: scan, sign, hide private details, shrink under a limit, send. Runs on your phone. No account. 3-day Pro trial. | 145 |
| Keywords | 100 | compress,pdf,scanner,sign,ocr,shortcuts,automation,watermark,receipt,resize,heic,metadata,translate | 99 |

Description, new opening (the tool list, free/Pro paragraph, privacy and subscription paragraphs stay as they are):

```
Scan a form, sign it, and have the email ready to send. One tap.
Hide the private parts of a photo, strip its location, shrink it. One tap.
Snap a receipt and it lands as a row in this month's expense sheet. One tap.

Tenzy is 30 small tools in one app, and now you can snap them together. Build your own turns the job you do over and
over into a single tool: pick what you start with (a photo, a scan, a PDF, some text, something you say, a contact),
stack the steps, choose how it ends. Describe it in your own words and Tenzy lines up the steps for you.

BUILD YOUR OWN
• Start from a ready-made tool or build from nothing
• Paperwork: scan pages into one PDF, sign and date in the same place every time, name the file
• Upload forms: exact pixel size, under 20 KB to 10 MB, both sides of an ID on one page, a safety watermark
• Privacy: hide numbers and faces, strip location, clean tracking out of links
• Money: a receipt becomes one row in a sheet that grows all month
• Video: fit one under 25 MB for email or 16 MB for chat, pull out a still, remove the sound
• Run it from the Share menu in any app, from a reminder, or from the Shortcuts app
• Everything runs on your iPhone. Nothing is uploaded.
```

Build your own is a Tenzy Pro tool on iPhone. The free/Pro paragraph must keep saying so (rulebook section 3).

## Google Play (Android)

| Field | Limit | Proposed | Length |
|---|---|---|---|
| Title | 30 | Tenzy: Scan, Shrink & Automate | 30 |
| Short description | 80 | Build one-tap tools: scan, sign, hide private details, shrink, send. On-device. | 79 |

Full description, new opening (rest unchanged):

```
Tenzy is one app for the jobs your phone usually makes you download a separate app for. Now you can snap those jobs
together: Build your own turns the thing you do over and over into a single tool.

BUILD YOUR OWN
• Scan pages into one PDF, sign and date it, and open the email ready to send
• Hide private details, strip the location and shrink a photo, then send it on WhatsApp
• Snap a receipt and it becomes a row in this month's expense sheet
• Exact pixel size and size limits down to 20 KB for upload forms; both sides of an ID on one page
• A tool can offer itself when you take a photo or a screenshot, or remind you at a set time
• Video: fit one under a size limit, pull out a still, remove the sound
• Share a photo to Tenzy from any app and pick the tool to run
• Runs on your phone. Nothing is uploaded.
```

Android now has every step the iPhone has, but three are plainer there (describe, enhance, identify): do not promise
"names any plant or breed" or "AI description" on Play (rulebook section 3: only what works on the platform).

## Lines that are only true after the unbuilt work ships

Do not publish these until the build that contains them is live:
- "from a reminder", "from the Shortcuts app" (iPhone)
- "sign and date" on Android, "offer itself when you take a photo or a screenshot", "remind you at a set time" (Android)
- "something you say, a contact", "a PDF" as starting points (both)
- "a sheet that grows all month" is in the code but has not been compiled yet (both)

Already shipped (iOS 1.2.51 on TestFlight, Android 1.0.7 internal): scan to start a tool, one PDF for all pages,
watermark, exact pixel size, size limits down to 20 KB, the Share menu, email and message endings.

## Reviewer notes to add with the same release (iPhone)

- Notifications: used only for reminders the person sets on their own tools ("Remind me to run this"). Asked for when
  they switch a reminder on. No marketing notifications.
- Shortcuts actions: "Run a Tool on a Photo", "Run a Tool on Text", "Open a Tool". They run on the device and return
  the result to the shortcut. Nothing is uploaded.
- Contact picker in Build your own uses Apple's picker, which gives the app only the contact the person taps. No new
  permission.

## Screenshots to re-capture

1. Build your own home with the how-it-works card
2. The builder with three steps and their previews
3. A finished run with the email ready to send
4. The Share menu showing Tenzy
5. My sheets

## Added with the new starts and steps (not live, needs Manan's yes)

Lines that become true once the recording, PDF, link, code, translate and extra video steps ship. Check each against the platform before using it.

- Both stores: "Start with a photo, a video, a recording, a PDF, a link or plain text." "Turn a voice memo into notes." (Android: only say this
  with "on Android 13 and newer".) "Join, shrink, trim or password-lock a PDF." "Check a QR code before you open it." "Save a web page as a
  clean PDF." "Translate a sign or a menu from a photo." "Trim a video, crop it tall, or make a GIF."
- iPhone only: "Add captions to a video." "Rewrite text clearer or more formal" (say "on phones with Apple Intelligence").
- Do not put captions or rewriting in the Play listing at all.
- Reviewer notes to add (iPhone): Location is read only when the person taps Location in a tool; "Read the page at a link" fetches the single
  page the person entered; speech is recognised on the device.

## Added with the fun steps (not live, needs Manan's yes)

- Both stores: "Turn a photo into a sticker." "Put an emoji over every face." "Make a meme." "Rebuild a photo from emojis." "Boomerang GIFs, slow
  motion and fast-forward." "Play your photos as one GIF."
- iPhone only: "Start a video tool from a Live Photo." Never mention Live Photos in the Play listing.
- Do not call any of this "AI". Nothing here uses a model beyond the phone's own face finder and cut-out.

## Added with sketch, voices, before/after and recent results (not live, needs Manan's yes)

- Both stores: "Turn a photo into a pencil sketch, a comic or pop art." "Chipmunk and deep voices for any recording." "Before and after, side by
  side." "Your last 20 results are kept on your phone."
- Tool links and QR codes: say nothing until the link page is published and sharing is switched on.
