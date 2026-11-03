# Tenzy — Icon, Colour, Background & Theme Asset Brief (v2)

One brief for **both apps** (iOS: 30 tools · Android: current catalog), all **5 themes**, every tool page, the home grid, the group screens, Settings, onboarding and the paywall.

**The goal — read this first.** Picking a theme must re-skin the **whole app**, not just the page backgrounds. Under each theme every tool's **icon**, its **signature colour**, its **background card**, and the surrounding **surfaces** all shift together to one coherent look. A user on *Midnight* should see neon-lit clay icons on black; a user on *Mono* should see near-monochrome icons with a single orange spot — same objects, re-finished. That means every tool ships **5 icon variants + 5 background variants** (not one icon reused across themes), and the signature colour is transformed per theme by the recipe in §3.

Nothing here invents a tool — it covers exactly what ships.

---

## 1. Global style (shared by every asset, every theme)

- **Icon style:** v4 **claymorphic** — soft 3D "clay" objects, rounded, gentle inner/outer shadow, a single soft **top-left** light source, subtle gradient on the form. One clear object per icon, centred, generous padding. **No text in the icon.**
- **Icon format:** transparent PNG, square, **no baked-in background square** (the old kit had an opaque white square — must be fully transparent). Export **512×512** (+ @2x/@3x where needed). Flat-on, not isometric unless the object reads better that way.
- **Background style:** the icon's object (or a related motif) rendered large on the **right third** of a wide card, soft glow + a few sparkle/star accents, fading to transparent toward the left so the white tool title stays crisp. Low-contrast so text reads on top.
- **One-system rule:** across every icon, every background, every theme, keep the **same light direction, corner-radius language, shadow softness and sparkle treatment**. Only the finish and palette change per theme — never the object, never the lighting angle.

---

## 2. The 5 themes (identical names + palettes on iOS and Android)

| Theme | Mood | Accent | Accent 2 / glow | Surface / background | Text on surface |
|---|---|---|---|---|---|
| **Daylight** (default, free) | Clean, bright | `#1F5EFF` blue | `#1649D6` | Light `#F6F7FB` (adapts to system dark) | near-black |
| **Midnight** (Pro) | Dark glass, neon glow | `#3DE1FF` neon cyan | `#16B6D6` | Near-black `#0B0E14`, surfaces `#141925` | white |
| **Warm Paper** (Pro) | Editorial, warm, matte | `#C2502E` terracotta | `#E0795A` | Cream `#F6F1E7` | warm charcoal |
| **Neo Pop** (Pro) | Bold, playful, punchy | `#FF2D87` hot pink | `#FF8A00` orange | Off-white `#FBF7F2` | near-black |
| **Mono** (Pro) | Minimal, stealth | `#FF5A1F` orange | `#E04715` | White `#FFFFFF` (accent is the only colour) | near-black |

Settings swatches are a 2-colour gradient per theme (the two accents above).

---

## 3. The per-theme transformation recipe (the heart of v2)

Take a tool's **signature hue** `H` (§5) and its clay object, and re-finish it per theme. Apply the **same recipe to the icon, the background glow, and the on-page accent** so a tool stays recognisable but clearly belongs to the active theme.

| Theme | Clay finish | What happens to the signature hue `H` | Glow / light | Ambient the object sits on |
|---|---|---|---|---|
| **Daylight** | Bright, clean, glossy-matte clay | **`H` as-is** — this is the reference render | soft white top-left highlight, gentle ambient occlusion | light neutral, faint cool shadow |
| **Midnight** | Dark glassy clay, slightly translucent, rim-lit | `H` pushed to an **emissive neon** version (raise value, add bloom); blend a touch of theme cyan `#3DE1FF` into the glow | strong coloured rim-light + soft outer bloom, edges glow on black | near-black `#0B0E14`; object reads by its own light |
| **Warm Paper** | **Matte**, paper-grain, no gloss | `H` warmed and slightly muted — nudged toward its warm neighbour (blues → slate-teal, greens → olive, violets → plum); terracotta `#C2502E` tints the shadows | soft, low-contrast, warm; shadows brown not grey | cream `#F6F1E7`; subtle paper texture |
| **Neo Pop** | Bold, saturated, slightly flatter clay with a crisp hard drop-shadow | `H` kept vivid and paired as a **duotone** with hot-pink `#FF2D87` / orange `#FF8A00` accents (one as the object, one as a pop highlight) | punchy, high-chroma, minimal blur; a clean offset shadow | off-white `#FBF7F2`; confident, graphic |
| **Mono** | Near-**greyscale** clay, soft neutral | `H` **desaturated to grey**; the orange accent `#FF5A1F` appears as the **single spot colour** on one key detail only | low, neutral; one warm accent highlight | white `#FFFFFF`; stealth, one spot of colour |

**Rules of thumb:** the object and its pose never change between themes — only finish, palette and the surface behind it. In Mono, let exactly one element carry the orange. In Midnight, the icon must read on black (no dark-on-dark). In Warm Paper, kill all gloss. In Neo Pop, saturation and a hard shadow do the work.

---

## 4. Signature colours (the base hue `H` per tool, = the Daylight render)

Blue `#2B68FF` fileviewer · Blue `#3B82F6` docs/share · Violet `#8B5CF6` media/translate · Emerald `#10B981` cleanup · Emerald `#059669` storage · Cyan `#06B6D4` converter · Rose `#F43F5E` instruments · Green `#22C55E` safety · Indigo `#6366F1` codes/texttools · Teal `#14B8A6` scrubber · Amber `#F59E0B` flashlight/quick · Sky `#0EA5E9` network/hearing/sorted · Red `#EF4444` voice · Amber `#D97706` memory · Orange `#EA580C` receipts · Indigo `#4338CA` invoice · Indigo `#4F46E5` data grabber/scan&sort · Teal `#0D9488` see&read · Purple `#9333EA` identify · Sky `#0284C7` gps · Green `#16A34A` parked · Deep-violet `#5B21B6` rest · Gold `#CA8A04` price check · Pink `#DB2777` long screenshot · Purple `#A855F7` gif maker · Violet `#7C3AED` color vision · Teal `#0F766E` pro camera · Blue `#2563EB` my phone · Slate `#64748B` everything-else.

> These match `toolTint()` in the Android code, so the in-app page backdrop and the asset glow already agree under Daylight; §3 then shifts both per theme.

---

## 5. Master tool catalog — icon + background concept per tool

Each row = one object, rendered as **5 themed icons + 5 themed backgrounds** (§3). "Apps" notes where it appears; names differ slightly between apps.

### Photo / video / files
- **Studio** (iOS) / **Media Studio** (Android) — enhance, cut out background, passport photo, resize. *Object:* two stacked rounded photo tiles, one lifting with a sparkle.
- **Pro Camera** — manual ISO, shutter, RAW. *Object:* a clay camera body, prominent lens + manual dial, glint on the glass.
- **Video** — shrink, trim, convert, GIF. *Object:* a play triangle inside a rounded film frame + scrub bar.
- **Format Fixer** — HEIC/MOV → JPG/MP4 batch. *Object:* two file chips with a convert arrow between them.
- **Fit It** — shrink to an exact size limit. *Object:* a file squeezed by two inward arrows + a target tag / size gauge.
- **Privacy Scrubber** (iOS) / **Scrubber** (Android) — strip location/metadata, blur faces & plates. *Object:* a photo with a blur patch + a shield / eye-off.
- **Identify** — point the camera, know what it is. *Object:* a viewfinder reticle over an object with a question spark.
- **Long Screenshot** (Android) / **stitch** — stitch scrolling shots into one tall image. *Object:* two phone screens merging into one tall strip.
- **QR & Wi-Fi** — scan, make & share Wi-Fi codes. *Object:* a clay QR square with a Wi-Fi arc.
- **Cleaner** — find duplicates & big files. *Object:* a sparkle broom sweeping duplicate photo tiles.
- **File Opener / File Viewer** — open almost any file. *Object:* a folder/file with a magnifier, layered file types fanned out.

### Documents / everyday
- **Scan** — scan, OCR, sign & fill PDFs. *Object:* a document with a scan beam + a pen tip.
- **Data Grabber** (Android route scancsv) — receipt → rows/contacts/dates. *Object:* a receipt turning into a small table/grid.
- **Sorted** — snap a bill → calendar it. *Object:* a bill with a calendar badge + due dot.
- **Memory** — ask your screenshots anything. *Object:* a stack of screenshots with a search/question spark.
- **Warranty & Receipts** (iOS) / **Receipts** (Android) — file receipts, track warranties. *Object:* a receipt in a protective shield/folder with a clock.
- **Text Studio** (iOS) / **Text Tools** (Android, texttools) — fix / clean / rewrite text. *Object:* an "Aa" clay block with a magic sparkle wand.
- **Translate** — text, camera, voice, offline. *Object:* two speech bubbles with "A / 文".
- **Voice → Notes** (iOS, voicenotes) — transcript, summary, to-dos. *Object:* a mic turning into text lines + waveform.
- **Message Shield** (iOS) / **Safety** (Android) — spot scams, see why. *Object:* a chat bubble inside a clay shield with a check.
- **Contacts** — find duplicates, merge & back up. *Object:* two contact cards merging into one.
- **Invoice** (Android, invoice) — quick PDF invoices. *Object:* an invoice sheet with a "$" line + PDF corner.
- **Price Check** — unit price, budget, label decode. *Object:* a price tag with a ÷ / comparison bars.
- **Scan & Sort** (Android group tile, scansort → Data Grabber + Receipts + Sorted + Translate). *Object:* a document scanner glyph with sorting arrows / lanes.

### Tools & instruments
- **Flashlight+** (iOS) / **Instruments** (Android hosts it) — strobe, SOS, screen light, mirror. *Object:* a clay torch with a beam + tiny SOS morse dots.
- **Measure** — AR tape: distance, height, area (+ level, compass). *Object:* a tape-measure curl with a level bubble.
- **See & Read** (both, seeread) — magnify, read aloud, gist. *Object:* a magnifier over text with a small speaker / sound waves.
- **GPS Dashboard** — speed, heading, altitude HUD. *Object:* a speedometer gauge with a compass needle + HUD arc.
- **Audio Lab** (iOS) — tuner, test tones, speaker test. *Object:* a tuning fork + a frequency dial.
- **Rest** — white/pink/brown noise + rain/ocean/fan + sleep timer (Android) / white noise + snore recorder (iOS). *Object:* a crescent moon with soft wave bands + a "z".
- **Color Vision** — live colour-blind correction & naming. *Object:* an eye over a colour-swatch wheel / shifting bands.
- **Network** (Android) — speed test, Wi-Fi details, device scan. *Object:* a Wi-Fi arc with a speed gauge + device nodes.
- **Codes** (Android) — scan & make QR/barcodes. *Object:* a clay QR with a scan bracket + barcode strip.
- **Voice** (Android) — record, transcribe, trim. *Object:* a mic with a waveform + scissors.
- **Where I Parked** (Android, parked) — save & find your car. *Object:* a car with a map pin + compass arrow.
- **Quick Buttons** (Android, quick) — one-tap flashlight/brightness/camera/hotspot. *Object:* a 2×2 grid of rounded action buttons.
- **Hearing Boost** (Android, hearing) — amplify sound around you. *Object:* an ear with rising sound waves + a boost arrow.
- **My Phone** (Android, myphone) — device info at a glance. *Object:* a phone outline with stat bars / a small gauge.
- **GIF Maker** (Android, gifmaker) — short video → looping GIF. *Object:* a film frame morphing into a looping-arrow GIF badge.
- **Storage** (Android, storage) — what's filling the phone. *Object:* a pie/bar storage gauge over stacked file blocks.
- **Vault** (iOS only; removed from Android) — Face ID locker. *Object:* a clay padlock with a Face ID dot grid.

### Group / system tiles (Android)
- **Everything else** (more) — drawer of less-used tools. *Object:* a 2×2 "apps" grid / "⋯", soft mixed glyphs, slate.

> A tool in both apps reuses the **same object**; it still needs its 5 themed icon + 5 themed background variants.

---

## 6. Per-app page map (so nothing is missed)

**iOS — 3 pages, 2-column grid (30 tools):**
- Page 1 (everyday): Studio, Pro Camera, Video, Format Fixer, Fit It, Privacy Scrubber, Identify, Long Screenshot, QR & Wi-Fi, Cleaner
- Page 2 (docs/helpful): Scan, Data Grabber, Sorted, Memory, Warranty & Receipts, Text Studio, Translate, Voice → Notes, Message Shield, Contacts
- Page 3 (tools/AI): Flashlight+, Measure, GPS Dashboard, Audio Lab, Rest, See & Read, Color Vision, File Opener, Price Check, Vault

**Android — one scrolling grid (23 tiles):** File Viewer, Docs & Capture, **Scan & Sort** (→ Data Grabber, Receipts, Sorted, Translate), Media Studio, Clean Up, Converter, Instruments, Safety, Share & Connect, Network, Codes, Scrubber, Voice, Memory, Where I Parked, Invoice, Storage, GIF Maker, Text Tools, My Phone, Hearing Boost, Quick Buttons, **Everything else** (→ See & Read, Identify, GPS Dashboard, Rest, Price Check, Long Screenshot, Color Vision, Pro Camera).

Every tile — including the two **group tiles** (Scan & Sort, Everything else) — needs its 5 themed icons + 5 themed backgrounds.

---

## 7. Every screen the theme must re-skin (not just tiles)

So the app looks "universally better," the theme drives all of these — most from palette tokens in code, but list them so none is skipped in design review:
- **Home grid** — background wash, tile surfaces, tile icon finish, title text colour (all per §3).
- **Each tool page** (PowerToolPage) — the top gradient backdrop uses the tool's themed signature hue; header icon is the themed icon variant; surfaces/cards/text follow the theme.
- **Group screens** (Scan & Sort, Everything else) — themed backdrop + themed entry icons.
- **Settings** — theme picker swatches, selected check, Pro lock badges; the whole page in theme surfaces.
- **Onboarding** — themed accent + themed hero icons.
- **Paywall / Go Pro** — themed accent, price card, trial copy; must stay legible in all 5.
- **Banner/empty/permission states** — themed accent + text colours.

---

## 8. Deliverables checklist (what to send back)

For each tool in §5, for **each of the 5 themes** (daylight, midnight, warmpaper, neopop, mono):
- `ic_<id>_<theme>.png` — claymorphic icon, transparent, **512×512** (+ @2x/@3x if easy), finished per §3.
- `card_<id>_<theme>.png` (Android, **1290×440**, art on right third) **and** `bg_<id>_<theme>_<variant>_card.png` (iOS strip) — background, glow tinted per §3.

Plus the Tenzy app mark (the "t") transparent at 512/1024 if refreshed.

**Tool IDs:** fileviewer, docs, media(studio), cleanup, converter, instruments, safety, share, network, codes, scrubber, voice, translate, memory, sorted, receipts(warranty), scancsv(datagrab), seeread, identify, gpsdash, rest, pricecheck, stitch, colorvision, procam, vault, light(flashlight), measure, scan, textstudio, voicenotes, shield, contacts, fitit, formatfix, video, audiolab, parked, invoice, storage, gifmaker, texttools, myphone, hearing, quick, scansort, more.

**Theme keys:** daylight, midnight, warmpaper, neopop, mono.

Keep light source, shadow softness, corner-radius language and sparkle treatment identical across every asset so the whole set — all 5 themes — reads as one system.
