# Tenzy Gold Book — the standard every tool and every page is held to

From Manan's own words (Nov 2026). Every tool — the 65 tools, the 91 ready-made tools, anything built in Build your
own, and the Share sheet — is scored against every rule below. A tool is **done** only when it passes all of them.
"How it's checked" says what proves each rule; a rule with no automatic check is checked by Claude on screenshots
of the real screen with real files in it, in light and dark, before the tool is closed.

The goal in one line: **robust, beautiful, powerful, efficient, and very easy to use** — someone who has never seen
Tenzy says their problem, gets it solved first try, and thinks "wow, I never knew I needed this".

## A. Purpose — why the tool exists
| # | Rule | How it's checked |
|---|---|---|
| A1 | Solves one clear real-world job, better than the built-in or commodity way (not a thin wrapper, not a gimmick). | Audit: name the job and the better-than; a tool that can't is merged or cut. |
| A2 | Opens with its purpose obvious: what it's for, what to give it, what you'll get — in plain words. | Screenshot: hero card says the job, the input tip names the real input. |
| A3 | Makes the best result for the person automatically — smart defaults, few options, a non-expert gets a great outcome. | Real-file run with defaults only must produce a good result. |
| A4 | Goes beyond what other apps do: a wow detail, rich well-chosen styles/options where taste matters (many sticker looks, not one). | Audit against the obvious alternative app. |

## B. Function — it works, every time
| # | Rule | How it's checked |
|---|---|---|
| B1 | Every control shown works on the person's input. Nothing decorative, nothing dead. | Smoke + edge test (every control reachable), real-file tests. |
| B2 | Best effort on anything given: wrong type, huge, empty, odd language — handled with a result or a clear next step, never a dead end, never raw code. | Real-input tests (91 + 65), defect-patterns.md section A. |
| B3 | Never crashes, including reading the screen like VoiceOver. | Real-input and smoke tests read every screen in full. |
| B4 | A failed run never uses up the person's limit. | Unit tests on the limits. |
| B5 | Real output asserted, not just "it opened": the file is read back and the promise checked (size, pages, words, length). | Per-tool output tests; FinishFacts. |
| B6 | Runs to the end if the app goes to the background; tells the person when it's done. | Phone check (simulator can't prove background). |
| B7 | Anything that can run on its own offers a reminder/alert, set once, with a Test run that proves it. | Audit + phone check of the alert. |

## C. Display — every page is beautiful
| # | Rule | How it's checked |
|---|---|---|
| C1 | Opens on the tool's own card: its colour and mark, name, one line on the job, the steps (for flows), the input tip. | Screenshot review. |
| C2 | Inputs grouped and labelled ("Start with"), the main action obvious (one primary button). | Screenshot review. |
| C3 | While working: one working card — real progress and time left where measurable, a running clock otherwise, Stop. Never a frozen spinner, never repeated banners. | BusySpinner/WorkingCard everywhere; screenshot of the working state. |
| C4 | The result first and big: a preview of exactly what was made before Save/Share (photo, PDF page, play bar, video, table). | Screenshot of the finished state. |
| C5 | Rich, useful information on the result: what changed, size before/after, what was found, what to do next. | Screenshot review against the job. |
| C6 | Nothing clipped, wrapped mid-word or off the edge; looks right in light and dark, iPhone and iPad. | Edge test + light/dark screenshots + iPad pass. |
| C7 | Calm, consistent look: same spacing, type and components as every other tool; no clutter. | Screenshot review side by side. |

## D. Ease — effortless for someone new
| # | Rule | How it's checked |
|---|---|---|
| D1 | Problem first: the person can just say what they need and land on the fix; "start with what you have" works from any photo, PDF, video, recording, file or text. | Home "What do you need?" + Ready now; guide tests. |
| D2 | Never overwhelm: the right 2–3 choices up front, the rest one tap away. Each job offered once — no duplicates, no copies. | ChainSame tests; screenshot of the guide. |
| D3 | Plain words everywhere; a short "how to use" for anything with setup, including setup on another phone. | Screenshot review; translations in 8 languages. |
| D4 | The result lands where it belongs: sticker → sticker drawer, number → call button, data → a real spreadsheet, transformation → a share-ready video. | Audit per tool of the finish actions. |
| D5 | Consistent at every door: the tool screen, the ready-made tools, Build your own and the Share sheet give the same result and finish. | Same finish screen from every door (ResultScreenTests, real-input tests). |
| D6 | Fast and light: no needless waits, battery-aware, within App Store policy. | Timing in the real-input run; rulebook.md. |

## E. Proof — how a tool gets closed
1. Build and every test green (unit, 65-tool smoke on iPhone and iPad, flows, real files through every tool).
2. Claude reviews the screenshots of the tool — open, working, finished — in light and dark against C1–C7.
3. Claude scores it A1–D6 on the tool's scorecard; any miss is fixed or written down as a gap with the reason.
4. Only rules that need a real phone (camera, sensors, microphone, real notifications, background, touch drawing,
   Apple's subject cut-out) go to Manan, as a short specific list.
