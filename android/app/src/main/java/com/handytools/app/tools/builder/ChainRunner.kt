package com.handytools.app.tools.builder

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Rect
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.tools.power.CaptureClassifier
import com.handytools.app.tools.power.MediaEngine
import com.handytools.app.tools.power.ScrubberEngine
import com.handytools.app.tools.power.VoiceText
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

sealed class Payload {
    class Pic(val bmp: Bitmap) : Payload()
    class Words(val text: String) : Payload()
    class Doc(val bytes: ByteArray, val ext: String) : Payload()

    val kind: Kind get() = when (this) {
        is Pic -> Kind.IMAGE
        is Words -> Kind.TEXT
        is Doc -> if (ext in listOf("jpg", "jpeg", "png")) Kind.PHOTO_FILE else Kind.FILE
    }
}

sealed class Outcome {
    class Done(val value: Payload) : Outcome()
    class Stopped(val why: String) : Outcome()
}

object ChainRunner {
    /** One PDF with a page per picture, each page the shape of its picture (long side 842 pt, like A4). */
    fun onePdf(pages: List<android.graphics.Bitmap>, onePage: Boolean = false): ByteArray {
        val doc = android.graphics.pdf.PdfDocument()
        if (onePage && pages.size > 1) {
            // Every picture on one A4-shaped sheet, stacked top to bottom, each as large as fits (both sides of an ID).
            val w = 595; val h = 842
            val page = doc.startPage(android.graphics.pdf.PdfDocument.PageInfo.Builder(w, h, 1).create())
            val paint = android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG)
            TextTidy.slots(pages.size, w.toFloat(), h.toFloat(), 34f).forEachIndexed { i, s ->
                val bmp = pages[i]
                val k = minOf((s[2] - s[0]) / bmp.width, (s[3] - s[1]) / bmp.height)
                val bw = bmp.width * k; val bh = bmp.height * k
                val cx = (s[0] + s[2]) / 2f; val cy = (s[1] + s[3]) / 2f
                page.canvas.drawBitmap(bmp, null, android.graphics.RectF(cx - bw / 2f, cy - bh / 2f, cx + bw / 2f, cy + bh / 2f), paint)
            }
            doc.finishPage(page)
            val out = java.io.ByteArrayOutputStream(); doc.writeTo(out); doc.close()
            return out.toByteArray()
        }
        pages.forEachIndexed { i, bmp ->
            val scale = 842f / maxOf(bmp.width, bmp.height)
            val w = (bmp.width * scale).toInt().coerceAtLeast(1); val h = (bmp.height * scale).toInt().coerceAtLeast(1)
            val page = doc.startPage(android.graphics.pdf.PdfDocument.PageInfo.Builder(w, h, i + 1).create())
            page.canvas.drawBitmap(bmp, null, android.graphics.Rect(0, 0, w, h), android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG))
            doc.finishPage(page)
        }
        val out = java.io.ByteArrayOutputStream(); doc.writeTo(out); doc.close()
        return out.toByteArray()
    }

    /** Runs every step in order; a step that cannot produce anything stops the chain and names itself. */
    /** @param dryRun true while the builder previews on sample data, so a step that keeps something (a running list) doesn't save it. */
    suspend fun run(chain: Chain, input: Payload, dryRun: Boolean = false): Outcome {
        chain.problem(input.kind)?.let { return Outcome.Stopped(it) }
        var v = input
        for (s in chain.steps) when (val r = apply(s, v, dryRun)) {
            is Outcome.Done -> v = r.value
            is Outcome.Stopped -> return r
        }
        return Outcome.Done(v)
    }

    suspend fun apply(step: Step, raw: Payload, dryRun: Boolean = false): Outcome = withContext(Dispatchers.Default) {
        val b = step.block
        fun none() = Outcome.Stopped(
            if (b.takes == Kind.TEXT) "${b.title} didn't find anything in that text." else "${b.title} didn't find anything in it. Try a clearer or closer picture.")
        fun fail() = Outcome.Stopped("${b.title} couldn't finish. Try again.")

        // A photo saved as bytes by an earlier step is opened again for the next one.
        val input = if (b.takes == Kind.IMAGE && raw is Payload.Doc && raw.kind == Kind.PHOTO_FILE)
            BitmapFactory.decodeByteArray(raw.bytes, 0, raw.bytes.size)?.let { Payload.Pic(it) } ?: return@withContext fail()
        else raw

        try {
            when {
                b == Block.READ_TEXT && input is Payload.Pic -> {
                    val r = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                    val text = try { r.process(InputImage.fromBitmap(input.bmp, 0)).await().text.trim() } finally { r.close() }
                    if (text.isEmpty()) none() else Outcome.Done(Payload.Words(text))
                }
                b == Block.PULL_RECEIPT && input is Payload.Words -> {
                    val r = CaptureClassifier.classify(input.text)
                    if (r.total.isBlank() && r.items.isEmpty()) none() else Outcome.Done(Payload.Words(CaptureClassifier.csv(r)))
                }
                b == Block.CHAT_LINK && input is Payload.Words ->
                    TextTidy.chatLink(input.text, step.settings["cc"] ?: TextTidy.callingCode(java.util.Locale.getDefault().country))?.let { Outcome.Done(Payload.Words(it)) } ?: none()
                b == Block.PRICE_COMPARE && input is Payload.Words ->
                    PriceDeal.bestDeal(input.text)?.let { Outcome.Done(Payload.Words(it)) } ?: none()
                b == Block.DESCRIBE && input is Payload.Pic -> {
                    // Built from what the phone can detect on its own: the things in it, the people, the words.
                    val image = InputImage.fromBitmap(input.bmp, 0)
                    val labels = try {
                        com.google.mlkit.vision.label.ImageLabeling.getClient(com.google.mlkit.vision.label.defaults.ImageLabelerOptions.DEFAULT_OPTIONS)
                            .process(image).await().sortedByDescending { it.confidence }.filter { it.confidence >= 0.6f }.map { it.text }
                    } catch (_: Throwable) { emptyList() }
                    val faces = try { ScrubberEngine.detectFaces(input.bmp).size } catch (_: Throwable) { 0 }
                    val words = try {
                        val r = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                        try { r.process(image).await().text.trim() } finally { r.close() }
                    } catch (_: Throwable) { "" }
                    val line = PriceDeal.describe(labels, faces, words)
                    if (line.isEmpty()) none() else Outcome.Done(Payload.Words(line))
                }
                b == Block.ENHANCE && input is Payload.Pic -> {
                    // Stretches the tones between the darkest and brightest real parts of the photo, and lifts colour a little.
                    val src = input.bmp
                    val small = if (maxOf(src.width, src.height) > 256) android.graphics.Bitmap.createScaledBitmap(src, maxOf(1, src.width * 256 / maxOf(src.width, src.height)), maxOf(1, src.height * 256 / maxOf(src.width, src.height)), true) else src
                    val px = IntArray(small.width * small.height); small.getPixels(px, 0, small.width, 0, 0, small.width, small.height)
                    val hist = IntArray(256)
                    for (p in px) hist[((p shr 16 and 0xFF) * 299 + (p shr 8 and 0xFF) * 587 + (p and 0xFF) * 114) / 1000]++
                    val (lo, hi) = PriceDeal.levels(hist)
                    val scale = 255f / (hi - lo).coerceAtLeast(1)
                    val m = android.graphics.ColorMatrix().apply { setSaturation(1.12f) }
                    m.postConcat(android.graphics.ColorMatrix(floatArrayOf(scale, 0f, 0f, 0f, -lo * scale, 0f, scale, 0f, 0f, -lo * scale, 0f, 0f, scale, 0f, -lo * scale, 0f, 0f, 0f, 1f, 0f)))
                    val out = android.graphics.Bitmap.createBitmap(src.width, src.height, android.graphics.Bitmap.Config.ARGB_8888)
                    android.graphics.Canvas(out).drawBitmap(src, 0f, 0f, android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG).apply { colorFilter = android.graphics.ColorMatrixColorFilter(m) })
                    Outcome.Done(Payload.Pic(out))
                }
                b == Block.PASSPORT_PHOTO && input is Payload.Pic -> {
                    // Cut the person out and centre them on white at the official size. Without the cut-out model, crop instead: still a usable photo.
                    val (w, h) = PriceDeal.passportSize(step.settings["country"])
                    val seg = com.google.mlkit.vision.segmentation.subject.SubjectSegmentation.getClient(
                        com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions.Builder().enableForegroundBitmap().build())
                    val fg = try { seg.process(InputImage.fromBitmap(input.bmp, 0)).await().foregroundBitmap } catch (_: Throwable) { null } finally { runCatching { seg.close() } }
                    val photo = if (fg != null) MediaEngine.composeIdPhoto(fg, w, h) else MediaEngine.centreCrop(input.bmp, w, h)
                    Outcome.Done(Payload.Doc(MediaEngine.jpeg(photo, 95), "jpg"))
                }
                b == Block.IDENTIFY && input is Payload.Pic -> {
                    val image = InputImage.fromBitmap(input.bmp, 0)
                    val barcode = try { com.google.mlkit.vision.barcode.BarcodeScanning.getClient().process(image).await().firstOrNull()?.rawValue } catch (_: Throwable) { null }
                    val labels = try {
                        com.google.mlkit.vision.label.ImageLabeling.getClient(com.google.mlkit.vision.label.defaults.ImageLabelerOptions.DEFAULT_OPTIONS)
                            .process(image).await().sortedByDescending { it.confidence }.take(3).map { it.text to it.confidence }
                    } catch (_: Throwable) { emptyList() }
                    val lines = TextTidy.identifyLines(barcode, labels)
                    if (lines.isEmpty()) none() else Outcome.Done(Payload.Words(lines))
                }
                b == Block.CUTOUT && input is Payload.Pic -> {
                    // Google's on-device cut-out. Its model is a one-time download; without it the step says so plainly.
                    val seg = com.google.mlkit.vision.segmentation.subject.SubjectSegmentation.getClient(
                        com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions.Builder().enableForegroundBitmap().build())
                    try {
                        val fg = seg.process(InputImage.fromBitmap(input.bmp, 0)).await().foregroundBitmap
                        if (fg == null) none() else Outcome.Done(Payload.Pic(fg))
                    } catch (_: Throwable) {
                        Outcome.Stopped("Cut out subject needs a one-time download that isn't on this phone yet. Open Media Studio, remove a background once while online, then run this again.")
                    } finally { runCatching { seg.close() } }
                }
                b == Block.RETURN_BY && input is Payload.Words -> {
                    // The last day to take it back, counted from the date on the receipt (today if it shows none), as a calendar entry.
                    val r = CaptureClassifier.classify(input.text)
                    val days = TextTidy.returnDays(step.settings["days"])
                    val due = TextTidy.returnDeadline(r.purchaseMs, days, System.currentTimeMillis())
                    when {
                        r.total.isBlank() && r.items.isEmpty() && r.purchaseMs == null -> none()
                        due <= System.currentTimeMillis() -> Outcome.Stopped("The $days-day return window for this receipt has already ended.")
                        else -> Outcome.Done(Payload.Doc(ics(TextTidy.returnTitle(r.merchant), due, due + 1_800_000L, "").toByteArray(), "ics"))
                    }
                }
                b == Block.WIFI_QR && input is Payload.Words -> {
                    // The network name and password from a router label or a cafe sign, as a code a guest's camera joins from.
                    val code = TextTidy.wifiCode(input.text)
                    if (code == null) none() else com.handytools.app.tools.power.CodesEngine.qr(code)?.let { Outcome.Done(Payload.Pic(it)) } ?: fail()
                }
                b == Block.CONTACT_QR && input is Payload.Words -> {
                    // Only what is in the text goes into the code, so you choose what the other person gets.
                    val c = CaptureClassifier.classify(input.text)
                    if (c.phone.isBlank() && c.email.isBlank()) Outcome.Stopped("Contact as a QR code needs a phone number or an email, and didn't find one.")
                    else com.handytools.app.tools.power.CodesEngine.qr(vcard(c.name, c.title, c.company, c.phone, c.email))?.let { Outcome.Done(Payload.Pic(it)) } ?: fail()
                }
                b == Block.EXPENSE_ROW && input is Payload.Words -> {
                    val r = CaptureClassifier.classify(input.text)
                    if (r.total.isBlank() && r.items.isEmpty()) none() else Outcome.Done(Payload.Words(TextTidy.expenseRow(r.purchaseMs, r.merchant, r.total)))
                }
                b == Block.ADD_TO_LIST && input is Payload.Words -> {
                    // Every run adds to the same sheet (one per month by default) and hands back the whole sheet.
                    val name = TextTidy.fileName(step.settings["list"] ?: TextTidy.DEFAULT_LIST, "List", ext = "csv")
                    val file = runCatching { java.io.File(java.io.File(com.handytools.app.HandyApp.instance.filesDir, "lists").also { it.mkdirs() }, name) }.getOrNull()
                    val old = if (dryRun) "" else runCatching { file?.takeIf { it.exists() }?.readText() ?: "" }.getOrDefault("")
                    val merged = TextTidy.mergedList(old, input.text)
                    if (merged.isEmpty()) none()
                    else if (!dryRun && (file == null || runCatching { file.writeText(merged) }.isFailure)) fail()
                    else Outcome.Done(Payload.Doc(merged.toByteArray(), "csv"))
                }
                b == Block.SUMMARIZE && input is Payload.Words -> {
                    val n = (step.settings["sentences"]?.toIntOrNull() ?: 3).coerceAtLeast(1)
                    val s = VoiceText.sentences(input.text).take(n)
                    if (s.isEmpty()) none() else Outcome.Done(Payload.Words(s.joinToString(" ")))
                }
                b == Block.ACTION_ITEMS && input is Payload.Words -> {
                    val items = VoiceText.sentences(input.text).filter { VoiceText.TODO.containsMatchIn(it) }
                    if (items.isEmpty()) none() else Outcome.Done(Payload.Words(items.joinToString("\n") { "• $it" }))
                }
                b == Block.SCAM_CHECK && input is Payload.Words ->
                    if (input.text.isBlank()) none() else {
                        val r = com.handytools.app.tools.shield.ScamAnalyzer.analyze(input.text)
                        Outcome.Done(Payload.Words(TextTidy.scamReport(r.verdict.label, r.findings.sortedByDescending { it.weight }.map { it.title },
                            r.links.filter { it.issues.isNotEmpty() }.map { "Link ${it.host}: ${it.issues.joinToString("; ")}" },
                            com.handytools.app.tools.shield.ScamAnalyzer.advice(r).firstOrNull())))
                    }
                b == Block.CLEAN_LINKS && input is Payload.Words ->
                    TextTidy.cleanLinks(input.text)?.let { Outcome.Done(Payload.Words(it)) } ?: none()
                b == Block.MAKE_QR && input is Payload.Words ->
                    if (input.text.isBlank()) none()
                    else com.handytools.app.tools.power.CodesEngine.qr(input.text.trim())?.let { Outcome.Done(Payload.Pic(it)) }
                        ?: Outcome.Stopped("Make a QR code couldn't fit that much text into one code. Try something shorter.")
                b == Block.PHOTO_PDF && input is Payload.Pic -> {
                    Outcome.Done(Payload.Doc(onePdf(listOf(input.bmp)), "pdf"))
                }
                b == Block.CLEAN_TEXT && input is Payload.Words ->
                    TextTidy.clean(input.text).let { if (it.isEmpty()) none() else Outcome.Done(Payload.Words(it)) }
                b == Block.PULL_DETAILS && input is Payload.Words ->
                    TextTidy.details(input.text).let { if (it.isEmpty()) none() else Outcome.Done(Payload.Words(it.text)) }
                b == Block.MAKE_TABLE && input is Payload.Words ->
                    TextTidy.tableCsv(input.text).let { if (it.isEmpty()) none() else Outcome.Done(Payload.Doc(it.toByteArray(), "csv")) }
                b == Block.SHRINK && input is Payload.Pic -> {
                    val mb = step.settings["mb"]?.toDoubleOrNull() ?: 2.0
                    val e = MediaEngine.shrinkToBytes(input.bmp, (mb.coerceAtLeast(0.01) * 1_048_576).toLong())
                    Outcome.Done(Payload.Doc(e.bytes, "jpg"))
                }
                b == Block.STAMP && input is Payload.Pic -> {
                    // Burned into the picture, so the signature can't be lifted off the page afterwards.
                    val spots = StampPlan.parse(step.settings["marks"] ?: StampPlan.STANDARD)
                    val ctx = com.handytools.app.HandyApp.instance
                    val sig = if (spots.any { it.mark == StampPlan.SIG }) StampBook.signature(ctx) else null
                    val name = StampBook.name(ctx).trim()
                    when {
                        spots.isEmpty() -> Outcome.Stopped("Sign and stamp has nothing to place. Turn on the signature, your name or the date.")
                        spots.any { it.mark == StampPlan.SIG } && sig == null -> Outcome.Stopped("Sign and stamp needs your signature. Edit the tool and draw it.")
                        spots.any { it.mark == StampPlan.NAME } && name.isEmpty() -> Outcome.Stopped("Sign and stamp needs your name. Edit the tool and type it in.")
                        else -> Outcome.Done(Payload.Pic(StampBook.render(input.bmp, spots, sig, name, java.util.Date())))
                    }
                }
                b == Block.WATERMARK && input is Payload.Pic -> {
                    // Repeats the line diagonally across the whole picture, see-through, so it can't be cropped away.
                    // The date is stamped at run time, so a copy made today can't be passed off later.
                    val line = TextTidy.watermarkLine(step.settings["text"] ?: "", java.util.Date())
                    val out = input.bmp.copy(android.graphics.Bitmap.Config.ARGB_8888, true)
                    val c = android.graphics.Canvas(out)
                    val size = maxOf(14f, minOf(out.width, out.height) / 20f)
                    val fill = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.argb(115, 255, 255, 255); textSize = size; isFakeBoldText = true }
                    val edge = android.graphics.Paint(fill).apply { color = android.graphics.Color.argb(115, 0, 0, 0); style = android.graphics.Paint.Style.STROKE; strokeWidth = size / 14f }
                    val tw = fill.measureText(line)
                    val reach = Math.hypot(out.width.toDouble(), out.height.toDouble()).toFloat() / 2f
                    c.translate(out.width / 2f, out.height / 2f); c.rotate(-30f)
                    var y = -reach; var row = 0
                    while (y < reach) {
                        var x = -reach - if (row % 2 == 0) 0f else tw / 2f
                        while (x < reach) { c.drawText(line, x, y, edge); c.drawText(line, x, y, fill); x += tw + size * 2 }
                        y += size * 3.6f; row++
                    }
                    Outcome.Done(Payload.Pic(out))
                }
                b == Block.RESIZE_PHOTO && input is Payload.Pic -> {
                    val px = TextTidy.pixels(step.settings["size"] ?: "") ?: return@withContext Outcome.Stopped("Exact pixel size needs a size like 600x600.")
                    // Scale to cover the exact size and trim the overflow evenly, so nothing is stretched.
                    val (w, h) = px
                    val s = maxOf(w.toFloat() / input.bmp.width, h.toFloat() / input.bmp.height)
                    val sw = input.bmp.width * s; val sh = input.bmp.height * s
                    val out = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
                    android.graphics.Canvas(out).drawBitmap(input.bmp, null, android.graphics.RectF((w - sw) / 2f, (h - sh) / 2f, (w + sw) / 2f, (h + sh) / 2f), android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG))
                    Outcome.Done(Payload.Pic(out))
                }
                b == Block.STRIP_LOCATION && input is Payload.Pic -> Outcome.Done(Payload.Doc(MediaEngine.jpeg(input.bmp, 92), "jpg"))
                b == Block.CONVERT && input is Payload.Pic ->
                    if (step.settings["format"].equals("PNG", true)) Outcome.Done(Payload.Doc(MediaEngine.png(input.bmp), "png"))
                    else Outcome.Done(Payload.Doc(MediaEngine.jpeg(input.bmp, 90), "jpg"))
                b == Block.HIDE_SENSITIVE && input is Payload.Pic -> {
                    val rects = ArrayList<Rect>(ScrubberEngine.detectFaces(input.bmp))
                    rects.addAll(personalText(input.bmp))
                    val out = if (rects.isEmpty()) input.bmp else ScrubberEngine.scrub(input.bmp, rects, ScrubberEngine.HideStyle.PIXELATE)
                    Outcome.Done(Payload.Doc(MediaEngine.jpeg(out, 92), "jpg"))
                }
                b == Block.BUSINESS_CARD && input is Payload.Words -> {
                    val c = CaptureClassifier.classify(input.text)
                    // A contact with only a name can't be saved or sent by most apps, so it needs a way to reach the person.
                    if (c.phone.isBlank() && c.email.isBlank()) Outcome.Stopped("Make a contact needs a phone number or an email, and didn't find one. Try a business card or a signature.")
                    else Outcome.Done(Payload.Doc(vcard(c.name, c.title, c.company, c.phone, c.email).toByteArray(), "vcf"))
                }
                b == Block.CALENDAR_EVENT && input is Payload.Words -> {
                    val c = CaptureClassifier.classify(input.text)
                    val start = c.startMs
                    if (start == null) none()
                    else Outcome.Done(Payload.Doc(ics(c.event.ifBlank { "Event" }, start, c.endMs, c.venue).toByteArray(), "ics"))
                }
                else -> Outcome.Stopped("${b.title} can't use that input.")
            }
        } catch (_: Exception) { fail() }
    }

    /** Only text that looks personal (long digit runs, emails) is covered, so the rest of the photo stays readable. */
    private suspend fun personalText(bmp: Bitmap): List<Rect> {
        val r = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        return try {
            r.process(InputImage.fromBitmap(bmp, 0)).await().textBlocks
                .filter { it.text.count { c -> c.isDigit() } >= 6 || it.text.contains('@') }
                .mapNotNull { it.boundingBox }
        } catch (_: Exception) { emptyList() } finally { r.close() }
    }

    private fun vcard(name: String, title: String, company: String, phone: String, email: String) = buildString {
        append("BEGIN:VCARD\nVERSION:3.0\n")
        append("FN:").append(name.ifBlank { email.ifBlank { phone } }).append('\n')
        if (company.isNotBlank()) append("ORG:").append(company).append('\n')
        if (title.isNotBlank()) append("TITLE:").append(title).append('\n')
        if (phone.isNotBlank()) append("TEL:").append(phone).append('\n')
        if (email.isNotBlank()) append("EMAIL:").append(email).append('\n')
        append("END:VCARD\n")
    }

    private fun ics(title: String, start: Long, end: Long?, where: String): String {
        val f = SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        return buildString {
            append("BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Tenzy//EN\nBEGIN:VEVENT\n")
            append("UID:").append(start).append("@tenzy\n")
            append("DTSTAMP:").append(f.format(Date())).append('\n')
            append("DTSTART:").append(f.format(Date(start))).append('\n')
            append("DTEND:").append(f.format(Date(end ?: (start + 3_600_000L)))).append('\n')
            append("SUMMARY:").append(title).append('\n')
            if (where.isNotBlank()) append("LOCATION:").append(where).append('\n')
            append("END:VEVENT\nEND:VCALENDAR\n")
        }
    }
}
