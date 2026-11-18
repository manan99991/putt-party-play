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
2. ~~PDF annotate~~ — **DONE** (Annotate tool `pdfannotate`: highlighter sweep + freehand draw, colour picker, per-page undo/clear, marks baked into the page via `DocEngine.annotate`, text kept selectable (re-OCR), preview before Save/Share; commit 8094673). Start at item 3.
3. ~~PDF convert~~ — **DONE** (Convert tool `pdfconvert`, page 4: PDF → image pages (JPEG/PNG) + PDF → text (.txt via embedded layer / OCR fallback), preview before Save/Share, lands in the share sheet; `DocEngine.pdfToImages` + unit test; commit 66fca2a, CI run #109 green). Start at item 4.
4. ~~Audio convert~~ — **DONE** (Audio Convert tool `audioconvert`, page 4: converts audio between M4A/AAC, WAV, AIFF, CAF on-device via a new `AudioConvert` engine — AVAssetReader→AVAssetWriter streaming (mirrors VideoEngine), preserves source sample rate/channels, live progress + time-left, finish-in-background + completion notification, play-preview before Save/Share, lands in the share sheet. Native-only subset (the path the prior run's codec note flagged safe): decodes MP3 and video audio, but honest that iPhone has no MP3 *encoder* — MP3 is input-only and the tool steers to M4A; no bundled LAME/Opus/FLAC. `AudioConvert.convert` + 2 unit tests (every format → non-empty playable asset of right length/ext; non-audio fails cleanly); commit eb05fb0, CI run #110 green). Start at item 5.
5. ~~Ringtone maker~~ — **DONE** (Ringtone tool `ringtone`, page 4: pick audio/video, trim a slice with start+length sliders (30s max), export `.m4r` via `AudioConvert.ringtone` — AVAssetExportSession AppleM4A + timeRange, clamped to source + 30s, hard timeout. Play-preview before Save/Share; lands in share sheet. Honest about the one manual step — iOS has no ringtone-set API, so it points to Files → GarageBand / Finder. Shares AudioPlayBar with Audio Convert; tile reuses `tool_audiolab` + TenzyArt alias. Unit test clamps a 60s request to a ~30s playable `.m4r`. commits 22fe751 + fix 1d61b96, CI run #112 green). Start at item 6.
6. ~~Audio trim / fades / dead-air~~ — **DONE** (Audio Editor tool `audioedit`, page 4: trim to a slice, linear fade in/out, and auto-remove dead air (RMS silence detection), preview before Save/Share; output M4A or WAV; source audio or a video's audio. New additive `AudioEdit` engine decodes to in-memory float PCM via `AVAssetReader` (random access, unlike `AudioConvert`'s stream), 30-min cap, writes via `AVAudioFile`; pure testable helpers `applyFades`/`silentRegions`/`keepSegments`/`process`. `AudioEditView` mirrors Ringtone (live progress, finish-in-background, `AudioPlayBar` preview, `ShareLink`). Reuses `tool_audiolab` asset + TenzyArt alias; search test asserts it owns fade/dead-air without outranking Audio Convert/Ringtone. 5 unit tests. commit e487546, CI run #113 green). Start at item 7.
7. **Audio cleanup** — noise reduction / speech enhance, preview before save.
8. **Meeting-notes rebuild** — on-device: clear to-do list + speaker turn-labels + summary + draft emails with dynamic names. Start processing the moment the file is picked.
9. **Soundboard** — extreme, character-true DSP voices (robot really robotic, alien alien), one radio-style picker with icons, share from that screen.
10. **Medication reminder** — customizable schedules (N× daily, after-N-months-from-logging), in-app notification/sound, in the new Explore section.
11. **Rebuilds** — spreadsheet, return-by, hide-faces recall, passport panel, cutout matte, scam/QR, menu assistant, collage/GIF, summaries, emoji-faces. One per run.
12. **Cross-cutting** — progress+notifications, preview-before-save, and real end-to-end output tests on every tool AND every chain (assert actual output, including step hand-offs).

## Serial / human-owned — do NOT auto-build in a parallel stream
These modify EXISTING tools (regression risk), so they are done serially with full
call-site impact analysis, not loosely in parallel:
- **Soundboard (#9)** — reworks the existing voice-changer tool's DSP.
- **Rebuilds (#11)** — all ten (spreadsheet, return-by, hide-faces, passport, cutout, scam/QR, menu, collage/GIF, summaries, emoji-faces) change existing tools.
- **Wave-1** — sticker-pack landing, animation extras, comic inking all change existing tools.
Autonomous streams skip these. The additive items (Meeting-notes #8, Medication reminder #10, the PDF suite, audio tags/compress/merge, zip-into-one) are fine to build in parallel.

## Human-gated (do NOT do autonomously — leave for the user)
- **Android port** of the validated batch (mandatory gate before any store submit).
- **Store submit** of either platform, and cancelling/releasing 1.2.57.
