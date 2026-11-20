# Tenzy — what Manan asked for, and the check that proves it

Every request goes here **before** any code, in his words, with the check that proves it everywhere it applies.
Nothing is reported as done until its check passes in CI. The tracker reads from this, not from memory.

**Doors** — every job can be reached from: (1) its tool screen, (2) the ready-made tools, (3) Build your own,
(4) the Share sheet / "What to do with it". A requirement covers all four unless it says otherwise.

| # | What was asked (his words, short) | Applies to | Check that proves it | Status |
|---|---|---|---|---|
| R1 | "support each and every file" — the 253-format list he sent | File Opener, Open With, Just open it | `FormatCoverageTests` (every format read, or on the public not-yet list with the reason); `FileReadersTests` (real bytes per family) | 253 accounted for; not-yet list being built down |
| R2 | One finished result screen per job, the same from every door | All 90 ready-made tools | `ResultScreenTests` (fails on any tool landing on the plain result unless on the known-gap list; list may only shrink) | 17 of 90 on their real screen |
| R3 | Your own watermark on ID copies | Both ID tools, Scan, Builder step | `PromiseTests.testWatermarkToolsLetYouTypeYourOwnWords` | built, check in CI |
| R4 | Signature pad draws and never saves blank | Builder sign tools, Scan, Sign PDF | `PromiseTests.testSignaturePadWontSaveBlank` + unit `inkCoverage` | built, check in CI |
| R5 | Keep every picked file; act on all of them | Join & Speed, every multi-file tool | review of every tab-switch (only one offender, fixed); UI check to add | built |
| R6 | Fingers removed from document photos | Scan, Builder scan, every document intake | `PageFlattenTests` + real-photo QA | built, real-file proof pending |
| R7 | Receipts read from screenshots; only receipts become expenses; no duplicates | Expense sheet, Data Grabber, Warranty | `RunningListTests`, `PrivatePhotoAccuracyTests.testReceipts` | built, QuickBooks date still missed |
| R8 | "What is this?" names written things and reads them | Identify tool, Builder, Share sheet | `PaperTests` + `ToolOutputQualityTests.testIdentifyNamesWrittenThingsByKind` | built, real-file score pending |
| R9 | Never mark done unless it meets the bar | Tracker | Tracker stage "Built" = CI green; "Done" = real-file check + his phone check | in force |
