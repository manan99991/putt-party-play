# TestFlight ship log

- 2026-11-02 — build pushed to TestFlight alongside the Android 24-tool internal release.
2026-11-03T04:44:28Z submit retrigger
- 2026-11-19 — TestFlight build requested by Manan: Contacts Pro, Daily Brief, Paperwork, Caregiver, My tools fixes, Ringtone, Zip, QR styles, Fit It, Format Fixer, voices, open any file, templates, Sorted, Long Screenshot, alerts (all green in CI).
- 2026-11-20 — daily TestFlight (standing yes): signature pad 5 inks, Protect PDF all-at-once, 26 animation styles, Celebrate, ringtone export retry (all green on 8408c3cc).
- 2026-11-20 — retry of today's TestFlight: run 44725365648 passed every test but the non-gating screenshot step hung for 2 h and took the build down; that step is now capped at 30 min and can't fail the build.
- 2026-11-20 — today's TestFlight, third attempt: run 44753284462 passed every test but froze copying its log (old full-history fetch, fixed in 3c9…); this build carries everything from today: signature 5 inks, Protect PDF, 26 animation styles, Celebrate, ringtone fix, audio tools, Think it through (rebuilt), Paste, receipt screenshots, Organize Pages text, passport/profile safety net.
- 2026-11-20 — fourth attempt: 44779973948 failed one timing test (video recorder dropped 12 of 60 frames on a loaded test machine). Offline recording now waits for the encoder instead of dropping frames.
- 2026-11-20 — fifth attempt: 44787986861 passed every test again, then the screenshot step hung 46 min past its 30-min cap. Screenshots no longer run on TestFlight builds at all.
