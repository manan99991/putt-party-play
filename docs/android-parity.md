# Android catch-up plan (23 Nov 2026)

Manan, 23 Nov: "get them ready for big launch on both iOS and Android". The iPhone is ahead; this is the map of
what Android has, what it shares with the iPhone, and what it still needs. Play only lists what the Android build
really ships (rulebook §3), so a tool not built here stays out of the Play listing and screenshots.

## Step 1 — the Home shell (done 23 Nov, this commit)

Same design as the iPhone: a greeting, a search box, a For you card (the parked car to start), every tab on screen
at once, and tiles named for the job. Android's tabs follow its own tools: Camera, Photos & video, Files, Sound,
Words, My day, Phone, plus Business when "I run a small business" is on in Settings. A JVM test checks every tool
has one tile, no tab scrolls, and every tile says a different job.

## Step 2 — tools on both phones that need the iPhone's newer behaviour

| iPhone | Android today | Gap |
|---|---|---|
| Invoices & Quotes | Invoice (PDF only) | quotes, numbering, saved unpaid list, 3 a month free, overdue card |
| For you cards | car only | medicine, bills, birthdays, space, contacts backup, overdue invoice |
| Welcome (one screen) | three-page onboarding | one screen with the optional "What do you want help with?" |
| Contacts and backup | inside Clean Up | its own tile and the 90-day backup nudge |

## Step 3 — iPhone tools Android doesn't have yet (biggest use first)

1. Medicine Reminders, Morning Summary, Photo to Checklist, Mood Diary (My day)
2. PDF: Sign, Fill a Form, Redact, Mark up, Organize pages, Lock, Make searchable (some live inside Docs & Capture —
   each needs its own tile and screen)
3. Photo: Photo Studio, Sticker, Collage, Comic, Face Emoji; Video: effects, Post a Video, Animate, Fit under a limit
4. Audio: Editor, Convert, Song info, Soundboard, Audio Lab, Notes from Speech
5. Menu Assistant, Business Cards, Price Watch, Vault, Measure (ARCore), Fix files that won't open, Zip

Each one ships with: its tile and job name, translations in the 8 languages, a JVM test for its engine, and a
smoke open in the emulator job.

## Android-only tools (kept)

Network, Instruments, Hearing Boost, My Phone, Quick Buttons, Storage, Wallet, Alarms, Timers, Where I Parked,
Share & Connect. They sit in Home's tabs like every other tool.

## Gates (unchanged)

- Play upload only with Manan's yes (`Ship-Play=YES` or the workflow's ship input) — never from a routine push.
- Pricing change ($2.99/mo, $29.99/yr, 7-day trial, ads for free users) goes last, on both stores at once.
