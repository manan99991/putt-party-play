# Tenzy — Icon, Background & Theme Asset Brief

One brief for **both apps** (iOS: 30 tools / Android: current catalog), all **5 themes**, every tool page, the home grid, and Settings. Goal: a single consistent visual system so every tool has a professional **icon** and a per-tool **background**, and every screen is clearly themed. Nothing here invents a tool — it covers exactly what ships in the build.

---

## 1. Global style

- **Icon style:** v4 **claymorphic** — soft 3D "clay" objects, rounded, gentle inner/outer shadow, a single soft top-left light source, subtle gradient on the form. Friendly, tactile, premium. One clear object per icon, centered, generous padding. **No text in the icon.**
- **Icon format:** transparent PNG, square, **no baked-in background square** (the old kit had an opaque white square — must be fully transparent). Export at **512×512** (plus @2x/@3x where the app needs it). Flat-on, not isometric unless the object reads better that way.
- **Background style:** the same claymorphic object (or a related motif) rendered large, sitting on the **right third** of a wide card, with a soft glow and a few sparkle/star accents, fading into transparency toward the left so the tool title stays crisp over it. Dark, low-contrast so white text reads on top.
- **Consistency rule:** every icon and background shares the same light direction, corner radius language, shadow softness, and sparkle treatment, so the whole app feels like one set.

---

## 2. The 5 themes (identical names + palettes on iOS and Android)

Each theme needs a **background variant** of every tool's card art (dark-friendly tint that matches the theme accent). Naming already used in code: `bg_<id>_<theme>_<variant>_card`.

| Theme | Mood | Accent | Accent 2 / glow | Surface / background |
|---|---|---|---|---|
| **Daylight** (default, free) | Clean, bright | `#1F5EFF` blue | `#1649D6` | Light `#F6F7FB` (adapts to system dark) |
| **Midnight** (Pro) | Dark glass, neon glow | `#3DE1FF` neon cyan | `#16B6D6` | Near-black `#0B0E14`, surfaces `#141925` |
| **Warm Paper** (Pro) | Editorial, warm, matte | `#C2502E` terracotta | `#E0795A` | Cream `#F6F1E7` |
| **Neo Pop** (Pro) | Bold, playful, punchy | `#FF2D87` hot pink | `#FF8A00` orange | Off-white `#FBF7F2` |
| **Mono** (Pro) | Minimal, stealth | `#FF5A1F` orange | `#E04715` | White `#FFFFFF` (accent is the only colour) |

Theme swatches on the Settings page are a 2-colour gradient per theme (the two accents above).

---

## 3. What to produce per tool

For **every** tool in section 5:
1. **One icon** (claymorphic, transparent 512×512) — reused across both apps where the tool concept matches.
2. **Background card art** (wide, right-anchored) in **5 theme variants** (Daylight, Midnight, Warm Paper, Neo Pop, Mono), each tinted to that theme's accent/glow. Android card art is **1290×440**, cropped so the art sits on the right third; iOS uses the strip art `bg_<id>_<theme>_<variant>_card`.
3. Use each tool's **signature colour** (below) as the dominant object/glow hue, then shift the background's overall wash to match the active theme.

---

## 4. Signature colours (the object/glow hue per tool)

Blue `#2B68FF` fileviewer · Blue `#3B82F6` docs/share · Violet `#8B5CF6` media/translate · Emerald `#10B981` cleanup/storage · Cyan `#06B6D4` converter · Rose `#F43F5E` instruments · Green `#22C55E` safety · Indigo `#6366F1` codes · Teal `#14B8A6` scrubber · Amber `#F59E0B` flashlight · Cyan `#0891B2` network/hearing · Red `#EF4444` voice · Amber `#D97706` memory · Sky `#0EA5E9` sorted · Orange `#EA580C` receipts/invoice · Indigo `#4F46E5` data grabber/scan&sort · Teal `#0D9488` see&read/text tools · Purple `#9333EA` identify · Sky `#0284C7` gps/parked · Deep-violet `#5B21B6` rest · Gold `#CA8A04` price check · Pink `#DB2777` long screenshot/gif maker · Violet `#7C3AED` color vision/quick · Teal `#0F766E` pro camera · Slate `#475569` my phone · Slate `#64748B` everything-else.

---

## 5. Master tool catalog — icon + background concept per tool

Each row = one icon + one 5-theme background set. "Apps" shows where it appears (names differ slightly between apps, noted).

### Photo / video / files
- **Studio** (iOS) / **Media Studio** (Android) — enhance, cut out background, passport photo, resize. *Icon:* two stacked rounded photo tiles, one lifting with a sparkle (background removal). *BG:* the stacked tiles motif, right third.
- **Pro Camera** — manual ISO, shutter, RAW. *Icon:* a clay camera body with a prominent lens + a manual dial. *BG:* lens + dial, glint on the glass.
- **Video** — shrink, trim, convert, GIF. *Icon:* a play triangle inside a rounded film frame. *BG:* film frame with a scrub bar.
- **Format Fixer** — HEIC/MOV → JPG/MP4 in batch. *Icon:* two file chips with a convert arrow between them. *BG:* file chips + cyclic arrows.
- **Fit It** — shrink to an exact size limit. *Icon:* a file being squeezed by two inward arrows with a target tag. *BG:* file + size gauge.
- **Privacy Scrubber** (iOS) / **Scrubber** (Android) — strip location/metadata, blur faces & plates. *Icon:* a photo with a blur brush + an eye-off. *BG:* photo with a blurred patch and a shield.
- **Identify** — point the camera, know what it is. *Icon:* a viewfinder/reticle over a leaf or object with a question spark. *BG:* reticle + recognised object.
- **Long Screenshot** (Android) / **stitch** — stitch scrolling shots into one tall image. *Icon:* two phone screens merging into one tall strip. *BG:* overlapping tall strips.
- **QR & Wi-Fi** — scan, make & share Wi-Fi codes. *Icon:* a clay QR square with a Wi-Fi arc. *BG:* QR + Wi-Fi waves.
- **Cleaner** — find duplicates & big files, free up space. *Icon:* a sparkle broom sweeping duplicate photo tiles. *BG:* duplicate tiles + sparkles.
- **File Opener** (Android "File Opener" / iOS "fileviewer") — open almost any file. *Icon:* a folder/file with a magnifier revealing contents. *BG:* layered file types fanned out.

### Documents / everyday
- **Scan** — scan, OCR, sign & fill PDFs. *Icon:* a document with a scan line + a pen tip. *BG:* document + scan beam.
- **Data Grabber** (iOS/Android "Data Grabber", Android route scancsv) — receipt → rows/contacts/dates. *Icon:* a receipt turning into a small table/grid. *BG:* receipt + grid cells.
- **Sorted** — snap a bill → calendar it. *Icon:* a bill with a calendar badge + due dot. *BG:* bill + mini calendar.
- **Memory** — ask your screenshots anything. *Icon:* a stack of screenshots with a search/question spark. *BG:* screenshot stack + magnifier.
- **Warranty & Receipts** (iOS) / **Receipts** (Android) — file receipts, never miss a warranty. *Icon:* a receipt in a protective shield/folder with a clock. *BG:* receipt + shield + timer.
- **Text Studio** (iOS) / **Text Tools** (Android, route texttools) — fix, rewrite, reply, summarize / clean & change text. *Icon:* an "Aa" clay block with a magic sparkle. *BG:* text lines + sparkle wand.
- **Translate** — text, camera, voice, offline. *Icon:* two speech bubbles with "A / 文" characters. *BG:* bubbles + language glyphs.
- **Voice → Notes** (iOS, voicenotes) — transcript, summary, to-dos. *Icon:* a mic turning into text lines. *BG:* mic + waveform + lines.
- **Message Shield** (iOS "Message Shield" / Android "Safety") — spot scams, see why. *Icon:* a chat bubble inside a clay shield with a check. *BG:* shield + flagged message.
- **Contacts** — find duplicates, merge & back up. *Icon:* two contact cards merging into one. *BG:* overlapping contact cards.
- **Invoice** (Android, route invoice) — quick PDF invoices. *Icon:* an invoice sheet with a "$" line + PDF corner. *BG:* invoice sheet + currency.
- **Price Check** — best deal per unit, budget, label decode. *Icon:* a price tag with a ÷ / unit-scale. *BG:* tag + comparison bars.
- **Scan & Sort** (Android launcher tile, route scansort) — the group tile that opens Data Grabber + Receipts + Sorted + Translate. *Icon:* a document scanner glyph with sorting arrows. *BG:* paper + sorting lanes.

### Tools & instruments
- **Flashlight+** (iOS "Flashlight+" / Android "Instruments" hosts it) — strobe, SOS, screen light, mirror. *Icon:* a clay torch with a beam + tiny SOS dots. *BG:* torch beam + morse dots.
- **Measure** — AR tape: distance, height, area (+ level, compass, meters). *Icon:* a tape measure curl with a ruler tick. *BG:* tape + level bubble.
- **See & Read** (both, seeread) — magnify, read aloud, gist. *Icon:* a magnifier over text with a small speaker. *BG:* magnifier + text + sound waves.
- **GPS Dashboard** — speed, heading, altitude, HUD. *Icon:* a speedometer gauge with a compass needle. *BG:* gauge + HUD arc.
- **Audio Lab** (iOS) — tuner, test tones, speaker test. *Icon:* a tuning fork + a waveform dial. *BG:* fork + frequency bars.
- **Rest** — white/pink/brown noise + rain/ocean/fan + sleep timer (Android) / white noise + snore recorder (iOS). *Icon:* a crescent moon with soft sound waves + a "z". *BG:* moon + gentle wave bands.
- **Color Vision** — live colour-blind correction & colour naming. *Icon:* an eye over a colour-swatch wheel. *BG:* eye + shifting colour bands.
- **Network** (Android) — speed test, Wi-Fi details, device scan. *Icon:* a Wi-Fi arc with a speed gauge + device dots. *BG:* signal waves + device nodes.
- **Codes** (Android) — scan & make QR/barcodes. *Icon:* a clay QR with a scan bracket. *BG:* QR + barcode strip.
- **Voice** (Android) — record, transcribe, trim. *Icon:* a mic with a waveform + scissors. *BG:* mic + waveform.
- **Where I Parked** (Android, route parked) — save & find your car. *Icon:* a car with a map pin. *BG:* car + pin + compass arrow.
- **Quick Buttons** (Android, route quick) — one-tap flashlight/brightness/camera/hotspot. *Icon:* a 2×2 grid of rounded action buttons. *BG:* button grid.
- **Hearing Boost** (Android, route hearing) — amplify sound around you. *Icon:* an ear with sound waves + a boost arrow. *BG:* ear + rising waves.
- **My Phone** (Android, route myphone) — device info at a glance. *Icon:* a phone outline with a small gauge/stats bars. *BG:* phone + stat bars.
- **Vault** (iOS only now — removed from Android) — Face ID locker. *Icon:* a clay padlock with a Face ID dot grid. *BG:* padlock + face mesh.

### Group / system tiles (Android)
- **Everything else** (route more) — the drawer of less-used tools. *Icon:* a 2×2 "apps" grid / "⋯". *BG:* soft grid of mixed glyphs, slate.

> Any tool present in both apps reuses the **same icon**; only the background's theme tint changes. Tools that exist in just one app are noted above.

---

## 6. Per-app page map (so nothing is missed)

**iOS — 3 pages, 2-column grid (30 tools):**
- Page 1 (everyday): Studio, Pro Camera, Video, Format Fixer, Fit It, Privacy Scrubber, Identify, Long Screenshot, QR & Wi-Fi, Cleaner
- Page 2 (docs/helpful): Scan, Data Grabber, Sorted, Memory, Warranty & Receipts, Text Studio, Translate, Voice → Notes, Message Shield, Contacts
- Page 3 (tools/AI): Flashlight+, Measure, GPS Dashboard, Audio Lab, Rest, See & Read, Color Vision, File Opener, Price Check, Vault

**Android — one scrolling grid (current):** File Viewer, Docs & Capture, **Scan & Sort** (→ Data Grabber, Receipts, Sorted, Translate), Media Studio, Clean Up, Converter, Instruments, Safety, Share & Connect, Network, Codes, Scrubber, Voice, Memory, Where I Parked, Invoice, Storage, GIF Maker, Text Tools, My Phone, Hearing Boost, Quick Buttons, **Everything else** (→ See & Read, Identify, GPS Dashboard, Rest, Price Check, Long Screenshot, Color Vision, Pro Camera).

Every tile needs its icon + 5-theme background. Group tiles (Scan & Sort, Everything else) need their own icon + background too.

---

## 7. Settings page

- **Theme picker:** 5 swatches, each a 2-colour gradient (section 2). A check-mark on the selected one; a lock badge on Pro themes for free users. These are rendered in-app from the palette — no asset needed, but the **gradients must match** the brief exactly.
- **Header/About:** the Tenzy app icon (the blue "t" mark) — keep the current mark but provide it transparent at 512/1024 if you want it refreshed.
- Rows (Permissions, Privacy, Send feedback, Rate, About) use simple line icons already in-app; optional: claymorphic mini-icons in the same style if you want them upgraded.

---

## 8. Deliverables checklist (what to send back)

For each tool in section 5:
- `ic_<id>.png` — claymorphic icon, transparent, 512×512 (+ @2x/@3x if easy).
- `card_<id>.png` (Android, 1290×440, art on right third) **and** `bg_<id>_<theme>_<variant>_card.png` (iOS) for **all 5 themes**: daylight, midnight, warmpaper, neopop, mono.

Tool IDs to use: fileviewer, docs, media(studio), cleanup, converter, instruments, safety, share, network, codes, scrubber, voice, translate, memory, sorted, receipts(warranty), scancsv(datagrab), lens(seeread), identify, gpsdash, rest, pricecheck, stitch, colorvision, procam, vault, light(flashlight), measure, scan, textstudio, voicenotes, shield, contacts, fitit, formatfix, video, audiolab, parked, invoice, storage, gifmaker, texttools, myphone, hearing, quick, scansort, more.

Keep the light source, shadow softness, corner-radius language and sparkle treatment identical across every asset so the set reads as one system.
