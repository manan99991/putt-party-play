# Tenzy defect patterns — the iron-clad QA checklist

Every item here is a **real bug found in the 15 Nov full-app review**, turned into a pass/fail gate.
Run this against **every tool — pre-built AND custom-built — and every flow/chain**, in that tool's
own context. A miss is a **test failure, not a cosmetic note**. The mobileqa agent is the final gate;
Claude runs this list first (unit-test the logic, reproduce off-device, green build) before handing over.

How to use: for each tool, drive the real flow with real data (not just "does it open"), and assert the
actual OUTPUT. Walk the hard cases on purpose — empty, huge, wrong-type, wrong-language, malformed,
offline, backgrounded. "Gracefully" is the bar: never a dead end, never a crash, never a silent nothing.

## A. Input handling (never dead-end — best-effort on anything)
1. **Wrong-type input is handled, not rejected.** Paste an image into a text tool → read its words (OCR).
   Give a zip/office file → unpack or extract text; never "couldn't open". Non-link text to a link tool →
   don't offer it as a dead option.
2. **Empty / nothing-copied / nothing-selected** → a clear, specific next step, never a blank result.
3. **Huge input** (a whole file, a 20-min recording, 20 photos) → bounded, scrollable, completes.
4. **Malformed / unexpected content** (raw HTML/JS/CSS, a scanned PDF with no text, a corrupt image) →
   stripped to something useful or a precise message; **never dump raw markup/code** at the user.
5. **A failed operation never consumes the user's quota/limit.**

## B. Output & preview (standing guiding rule)
6. **Preview before Save/Share for every output type** — photo, PDF, text/CSV, **video (player)**,
   **audio (player)**, and each item in a **batch**. The user confirms what was built before it leaves.
7. **Bounded result boxes** — long text/results scroll *inside* a fixed box; the page never stretches a
   whole screen before the actions.
8. **Readable, not raw** — a file shows its name + readable content, never a tag/byte dump.
9. **Multi-item results offer the obvious choice** (e.g. image→PDF: one combined PDF vs separate).

## C. Options (smart default + only the few that matter)
10. **Each tool exposes the 1–3 options relevant to its type**, best default pre-selected — speed, size,
    format, merge-vs-separate, language, voice, length. Not a wall of knobs; custom tools inherit from
    their blocks.
11. **Format choices where they matter** (audio m4a/wav/aac, etc.) with a sensible default.

## D. Correctness & depth (earn the place, not a thin wrapper)
12. **The tool does the smart thing, not the lazy one** — "best frame" not a fixed midpoint; a real
    effect not one gimmick; the deepest honest result on-device.
13. **AI verdicts are right both ways** — no false negatives (missed scam) AND no false positives
    (genuine message/file called a scam). Signals corroborate; legit brands/domains whitelisted.
14. **Language-aware** — transcription/translation/AI output in the content's / user's language, not
    device-English only. Honest when a language isn't on-device supported.

## E. State, progress, lifecycle (standing rules)
15. **Fresh slate on launch** — a tool never opens showing a previous run's input/result.
16. **Live progress with honest time-remaining** (or an elapsed timer), accurate even if backgrounded —
    never a frozen/ambiguous spinner.
17. **Runs to completion backgrounded**, and **notifies on finish**.

## F. Controls & copy
18. **Every visible control actually does something visible** — no silent button (the Paste bug);
    feedback shows where the user is looking, not behind a sheet.
19. **Clear, correct copy** — labels/subtitles match what the tool does; no duplicate/misleading text;
    the screen explains itself and "works best with…" on open.
20. **Clipboard/type awareness** — show what's on the clipboard (prompt-free) so the user knows what
    they're working with.

## G. Design
21. **Ground, not flat** — gradient chassis + raised cards; one signal-coloured hero per screen.

## H. Store & privacy (never get flagged)
22. On-device only for AI (no cloud, no data leaves the phone); permission strings present; no
    background-mode over-claim; deletes via the system confirm; no copycat names/mascot/look of other
    apps; IAPs attached in the same submission. (Apply the Reckato rejection history before any submit.)

---

### Review-to-test traceability (already pinned in `ReviewRegressionTests.swift`)
- Scam false-negative (Amazon job) → `testAmazonJobScamIsLikelyScam`
- Scam false-positives (itinerary, googleapis, inferred http) → `testTravelItineraryIsNotAScam`,
  `testLegitGoogleSubdomainIsNotALookAlike`, `testInferredSchemeIsNotReportedAsUnencrypted`
- Raw markup dump → `testHtmlFileIsStrippedToReadableText`
- QR preview classification → `testQRWifiParsed`, `testQRLinkParsedAndOpenable`, `testQRContactParsed`, …

Every new tool/flow adds its own real-data output assertions here before it ships.
