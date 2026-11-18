# Tenzy — autonomous build queue

This file is the source of truth for the autonomous build loop. A scheduled run reads it,
does the **top undone item**, checks it off, and pushes one validation commit. One item per run.

## Hard rules (never break)
- **Never** put `Ship-Build=YES`, `Ship-Store=YES`, or `Ship-Stage=YES` anywhere in a commit message. CI reads that string anywhere in the message and would fire a real store/TestFlight job. Validation commits only.
- **Never** run a store submit, `fastlane deliver`, or anything that ships. Store release is gated on the user (they must first cancel the pending **1.2.57** in App Store Connect).
- iOS-first. Can't compile Swift in the Linux container — verify every edit by brace/paren/bracket balance (`grep -oF`), and let **CI** be the compile gate. Push, then confirm the run goes green.
- Add or keep a unit test whenever the change is logic (engine behaviour, parsing, math). A tool with a UI control must actually work on real input, never dead-end, never burn quota on failure.
- Every tool: live progress + time-left, finish-in-background + completion notification, **preview before Save/Share**, land the output in its right native place.
- Do **one** item per run. If an item needs a human decision or you get blocked, write a one-line note on the live tracker and stop — do not thrash.
- If the previous push's CI is **red**, fix that before starting anything new.
- End commit messages with the attribution lines this session is given.

## Repo
- `github.com/manan99991/putt-party-play`, branch `handytools`. Clone fresh, `cd` in, work there.
- Read `docs/rulebook.md` before any store listing, new tool, or third-party page change (per AGENTS.md).

## Live tracker
- Artifact DB `https://claude.ai/artifact/LbW1poYhdBDuQQsKX8PGdN`, collection `items`, fields `{order, section, status, title, detail, tag}`.
- Mark an item `building` when you start, `done` once its CI is green. Use a fresh `doc_id`.

## Ordered queue (do the top undone one)
1. ~~Redaction UI~~ — **DONE** (Redact PDF tool `pdfredact`, drag-to-black-out + preview + true removal; commit d58160a4). Start at item 2.
2. **PDF annotate** — marker/highlight + freehand on a page, flatten into the PDF, preview before save.
3. **PDF convert** — PDF → image pages, and PDF → text (reuse `importPDF` / OCR). Land in the share sheet.
4. **Audio convert** — between the common phone formats (bundle codecs where iOS lacks them); honest about what each phone can do.
5. **Ringtone maker** — trim a clip to ≤30s, export `.m4r`, hand off to the right place (state the manual GarageBand step honestly — iOS won't let an app set ringtones directly).
6. **Audio trim / fades / dead-air** — cut, fade in/out, auto-remove silence, preview.
7. **Audio cleanup** — noise reduction / speech enhance, preview before save.
8. **Meeting-notes rebuild** — on-device: clear to-do list + speaker turn-labels + summary + draft emails with dynamic names. Start processing the moment the file is picked.
9. **Soundboard** — extreme, character-true DSP voices (robot really robotic, alien alien), one radio-style picker with icons, share from that screen.
10. **Medication reminder** — customizable schedules (N× daily, after-N-months-from-logging), in-app notification/sound, in the new Explore section.
11. **Rebuilds** — spreadsheet, return-by, hide-faces recall, passport panel, cutout matte, scam/QR, menu assistant, collage/GIF, summaries, emoji-faces. One per run.
12. **Cross-cutting** — progress+notifications, preview-before-save, and real end-to-end output tests on every tool AND every chain (assert actual output, including step hand-offs).

## Human-gated (do NOT do autonomously — leave for the user)
- **Android port** of the validated batch (mandatory gate before any store submit).
- **Store submit** of either platform, and cancelling/releasing 1.2.57.
