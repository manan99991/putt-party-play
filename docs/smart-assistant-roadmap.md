# Tenzy — Smart Assistant Roadmap & Living Bug List

The anchor for turning every Tenzy tool into a proactive, intelligent assistant, and
for the full-app review in progress. Nothing here gets dropped. Status is honest:
`DONE` = in the code and tested, `BATCH` = fixed, waiting in the held batch (not
deployed), `BUILDING` = in progress, `PLANNED` = designed, not built, `HARD` =
real feasibility limits, called out plainly.

Owner: Claude (build + test) · Manan (review + final go). Deploys are **held** until
Manan finishes the review and says go — then ONE clean build, verified green, deployed once.

---

## 0. The bar (applies to every tool, custom-built or pre-built)

1. **Explains itself** — what it does + what good input looks like, the moment it opens.
2. **Never dead-ends** — best-effort on any input; a failure gives a specific, actionable message, never a blocked screen, and never costs the user's quota.
3. **Shows a preview** — every output (photo, PDF, text/CSV, video, batch) is shown in-app before Save/Share.
4. **Confirms what happened** — a per-step "here's what it did" report, end to end.
5. **Deepened to the max** — solves one real job better than the commodity alternative; smart defaults; the output is genuinely good, not a thin wrapper.
6. **Proven** — real-data tests assert the actual OUTPUT, positive and negative, for every tool AND every flow/handoff. A silent under-deliver is a test failure, not just a code bug.
7. **Finishes + notifies** — runs to completion backgrounded or not; live progress with honest time-remaining; notifies on completion.

---

## 1. The task brain — "a task can be anything in the world"

Each task the user speaks/types is classified by intent and routed to the right action/app.
The planner orders tasks, estimates time, and hands each one a one-tap action.

| Intent | Example | Action / app | Status |
|---|---|---|---|
| Go somewhere | "take Dion to the temple", "buy water from a grocery store" | Apple + Google Maps **directions** link; (Phase 2) real in-app drive-time ETA | **BATCH** (links) / PLANNED (ETA) |
| Email someone | "remind me to email the landlord about the lease" | **Mail draft** with subject prefilled (mailto) → (Phase 2) draft the body too | **BATCH** (draft) / PLANNED (body) |
| Call someone | "call mom at 555-123-4567" | one-tap **tel:** call | **BATCH** |
| Message someone | "text Sam I'm running late" | iMessage/WhatsApp deep link + drafted text | PLANNED |
| Buy things / groceries | "make a grocery list and get them from Walmart" | **grocery checklist** (tick-off) + **Directions** to the named/nearest store + at the shelf, **Price Check** unit-price compare for best value | PLANNED |
| Remind me / appointment | "on Monday I go to X" | real **Reminder + Calendar event** (EventKit) the system triggers | PLANNED |
| Look something up | "find the best value for X" | **Price Check** unit-price compare (on a photo) + web search; no live cross-store prices (see §1 decision) | PLANNED |
| Monitor a condition | "if screenshots > 100, remind me" | background check → notification → deep link (see §3) | PLANNED |

**Ordering & time:** obvious "first/finally" tasks are ordered now (BATCH). Phase 2 geocodes each
place (MapKit `MKLocalSearch`), computes real drive times (`MKDirections`) from where the user is,
orders stops for the shortest trip, and builds a timeline with "leave by" times + a summary.
**Weather-aware** nudges ("rain — leave early") via WeatherKit.

**Safety already built:** the planner never turns a person into a map search ("send it to Ana"
stays a plain task); the open "to/at/from X" path only fires on a real place type.

### HARD / honest limits
- **"Cheapest Walmart" / live competitive prices across stores** — DECISION (Manan, 15 Nov):
  **skip the live cross-store price lookup** (no reliable free/legal data source; we don't fake it).
  Replace it with the **best feasible shopping assistant**, built to be genuinely useful:
  1. Parse the items into a **grocery checklist** the user ticks off (Reminders / Notes / an
     Excel-or-Numbers file with checkboxes).
  2. One-tap **Directions** to the store they named, or the nearest one.
  3. At the shelf, **Price Check** compares unit prices on a photo so they still get the best value
     per item.
  Revisit only if a paid pricing API ever becomes acceptable.
- **Deep "what is this?" identification** — on-device vision returns a short label, not a
  paragraph. Options: enrich the on-device output (label + category + attributes + a useful line),
  or route "What is this?" through a cloud vision model for a real, detailed answer. Decision pending.
- **Deep receipt extraction** — improve the on-device parser (merchant, date, every line item,
  subtotal/tax/total, currency). Accurate structured extraction is achievable on-device with work;
  tracked in the batch.

---

## 2. Day planning (Phase 2)

- Geocode places, real drive-time ETAs from current location, optimal stop order.
- A timeline: "leave by 9:10 · Walmart ~12 min · shelter ~8 min · temple ~15 min."
- Weather-aware adjustments.
- Needs: foreground location + network (iOS prompts at use). No background location (Play policy).

---

## 3. Proactive, background, notification-driven (minimal effort after setup)

The **screenshot-count tool** is the template for a whole class of **monitoring tools**:
- A tool watches a condition (screenshots > N, a bill due, a warranty expiring, duplicates piling up).
- When it trips, it fires a **local notification**: "As per your setup, you've hit 100 screenshots."
- The notification carries a **deep link** (`tenzy://tool/<id>?…`) that opens that exact tool,
  **pre-loaded and pre-selected** — e.g. all 100 screenshots selected, user just deselects a few
  or confirms, and they go to the Recently Deleted (recycle) bin via the system photo delete
  (which always shows Apple's confirmation).
- Also powers: "Today is Monday — you wanted to leave for X; weather's good, leave early; you have
  an appointment."

**Honest iOS limit:** background execution is constrained. We use the real mechanisms —
`PHPhotoLibraryChangeObserver` (photo changes while the app runs / on open), `BGTaskScheduler`
background refresh (opportunistic, not exact-time), and local notifications. We frame it honestly
("checks when you open it / periodically"), never promise real-time monitoring iOS can't deliver
(that's an App Store 2.5.4 rejection). Exact-time nudges go through Calendar/Reminders, which the
system triggers reliably.

---

## 4. Plug into the user's life (integrations)

- **Calendar + Reminders (EventKit)** — turn tasks into real events/reminders the OS triggers.
  Needs calendar/reminders permission strings. PLANNED.
- **Notes / lists** — push a list out; or create a **spreadsheet (Excel/Numbers) with tick-off
  checkboxes** ("bought apples ✓"). PLANNED.
- **Mail / Phone / Messages / Maps** — deep links. Mail/Phone/Maps: BATCH. Messages: PLANNED.

---

## 5. The full-app review — running bug list (held for one batch deploy)

### Fixed, in the batch (NOT deployed)
1. Transcription — full transcript, time-remaining with animated icon, copy confirmation.
2. Dead-ends / useless errors → best-effort delivery + specific, actionable messages.
3. Every flow explains itself + "works best with…".
4. Templates grid — whole card tappable + themed gradient.
5. Optional middle step killing a flow (Find links blocked everything) → type-safe pass-through.
6. Stuck "Trying it on a sample…" preview.
7. **Face detection missing faces** (Hide faces, Emoji) → latest model + body-detection safety net.
8. **Preview on EVERY output type** — photos, PDFs, **text/CSV/vCard/ICS**, and batch thumbnails.
9. Signature pad didn't ink with a finger → fixed (canvas scroll was eating the stroke).
10. Batch showed "49 characters" instead of the answer → now shows each item's actual text.
11. Tool reopened showing a previous run's image → fresh slate on each launch.
12. Smart task actions (maps/email/call routing) — Phase 1.
13. Confirmation report — per-step "here's what it did".

### Still open in this batch
- Meme: caption doesn't update the preview after first input; keyboard won't close on tap →
  live preview + tap-anywhere-to-dismiss (app-wide).
- Tools with unclear purpose ("Before and after", etc.) → clear in-app explanation + example,
  and judge each against the "earns its place" bar.
- "Sign a form": signature now inks; fix the confusing "edit the tool" prompt (point at the
  Draw-my-signature button that's right there) and make the no-signature-yet state obvious.
- "What is this?" depth + receipt-extraction depth (see §1 HARD).
- Standalone (non-Builder) tools: audit each for preview + best-effort + explains-itself parity.
- Android parity for all of the above.

---

## 6. Store-compliance guardrails (so none of this risks rejection)

- Clear purpose string for every new permission (Calendar, Reminders, Photos, Location);
  request only on user action.
- Photo deletes go through the system confirmation (never silent) → Recently Deleted.
- Only declare background modes we genuinely use; never promise real-time background monitoring.
- WeatherKit: show the required Apple Weather attribution.
- Play: foreground location only (no background location), Calendar/inexact reminders (no
  exact-alarm permission), tel: links (no CALL_PHONE), no SMS/call-log.
- Keep IAPs attached in the same submission (Apple A4, the #1 recurring risk), review notes with
  the binary, screenshots matching the build, no "free" without "optional Pro", no Pro backdoor
  in production, Play data claims sourced. (From the Reckato rejection history.)

---

## 7. Testing (the proof)

- CI golden tests for every deterministic tool/flow — positive (delivers) and negative
  (graceful, never dead-ends), including every block and every template handoff. DONE/BATCH.
- Device-farm (mobileqa) real-data assertions for the ML/camera/audio tools — a real sample run
  on a real device, asserting the output is substantially complete (needs the ANTHROPIC_API_KEY
  secret restored). PLANNED.
