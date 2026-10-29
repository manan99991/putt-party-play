package com.handytools.app.tools.power

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** What Capture decided the photo is. Labels are the prototype's "✓ Detected: X" strings. */
enum class CaptureKind(val label: String) {
    RECEIPT("Receipt"),
    CARD("Business card"),
    FLYER("Event flyer"),
    DOCUMENT("Document"),
    SIGN("Sign"),
}

/** Everything the Capture screen needs to show fields and drive the context actions. */
data class CaptureResult(
    val kind: CaptureKind,
    val text: String,
    val fields: List<Pair<String, String>>,
    // receipt
    val merchant: String = "",
    val total: String = "",
    val purchaseMs: Long? = null,
    val items: List<Pair<String, String>> = emptyList(),
    // business card
    val name: String = "",
    val title: String = "",
    val company: String = "",
    val email: String = "",
    val phone: String = "",
    // flyer
    val event: String = "",
    val startMs: Long? = null,
    val endMs: Long? = null,
    val venue: String = "",
    // document / sign
    val words: Int = 0,
) {
    /** One short sentence for read-aloud, like the prototype's speak() lines. */
    fun spoken(): String = when (kind) {
        CaptureKind.RECEIPT -> listOf(merchant, purchaseMs?.let { CaptureClassifier.dayFmt.format(Date(it)) }, total.takeIf { it.isNotBlank() }?.let { "total $it" })
            .filterNotNull().filter { it.isNotBlank() }.joinToString(", ").ifBlank { text }
        CaptureKind.CARD -> listOf(name, title, company).filter { it.isNotBlank() }.joinToString(", ").ifBlank { text }
        CaptureKind.FLYER -> listOf(event, startMs?.let { CaptureClassifier.whenFmt.format(Date(it)) }, venue).filterNotNull().filter { it.isNotBlank() }.joinToString(", ").ifBlank { text }
        CaptureKind.DOCUMENT, CaptureKind.SIGN -> text
    }
}

/**
 * Regex heuristics that turn recognised text into a Receipt / Business card / Event flyer /
 * Document / Sign, plus the fields each one needs. Pure text work — runs on every phone.
 */
object CaptureClassifier {
    val dayFmt: SimpleDateFormat get() = SimpleDateFormat("d MMM yyyy", Locale.getDefault())
    val whenFmt: SimpleDateFormat get() = SimpleDateFormat("EEE d MMM yyyy · h:mm a", Locale.getDefault())

    private val moneyRe = Regex("""(?:[$£€]\s?)(\d{1,3}(?:,\d{3})+(?:\.\d{2})?|\d+\.\d{2}|\d+)|(\d{1,3}(?:,\d{3})*\.\d{2})(?!\d)""")
    private val emailRe = Regex("""[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}""")
    private val phoneRe = Regex("""(?:\+?\d{1,3}[\s.-]?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}""")
    private val urlRe = Regex("""(?i)\b(?:https?://)?(?:www\.)?[a-z0-9\-]+\.(?:com|net|org|io|co|app|dev|me|us|uk)\b[^\s]*""")
    private val timeRe = Regex("""(?i)\b(\d{1,2})(?::(\d{2}))?\s*([ap])\.?m\.?\b""")
    private val timeRangeRe = Regex("""(?i)\b(\d{1,2})(?::(\d{2}))?\s*(?:([ap])\.?m\.?)?\s*[–\-—to]+\s*(\d{1,2})(?::(\d{2}))?\s*([ap])\.?m\.?""")
    private val dateRe = Regex(
        """(?i)(\d{4}-\d{1,2}-\d{1,2})""" +
            """|(\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4})""" +
            """|((?:mon|tue|wed|thu|fri|sat|sun)[a-z]*,?\s+)?(\d{1,2})(?:st|nd|rd|th)?\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?,?\s*(\d{4})?""" +
            """|((?:mon|tue|wed|thu|fri|sat|sun)[a-z]*,?\s+)?(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s*(\d{4})?"""
    )
    private val months = listOf("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")

    private val receiptWords = listOf("total", "subtotal", "sub-total", "tax", "vat", "cash", "change", "visa", "mastercard", "amex", "debit", "credit", "card", "tender", "receipt", "qty", "item", "balance", "tip", "gratuity", "thank you", "store", "cashier", "order", "invoice", "amount due", "paid")
    private val cardWords = listOf("manager", "director", "head of", "engineer", "consultant", "founder", "ceo", "cto", "cfo", "coo", "vp", "president", "partner", "sales", "marketing", "designer", "developer", "attorney", "agent", "realtor", "owner", "specialist", "analyst", "associate", "executive", "officer", "lead", "coordinator", "representative", "md", "phd", "dds", "llc", "inc", "ltd", "gmbh", "corp")
    private val flyerWords = listOf("join us", "free entry", "tickets", "admission", "live music", "doors open", "rsvp", "party", "festival", "concert", "show", "market", "fair", "fundraiser", "workshop", "meetup", "open house", "sale", "grand opening", "all welcome", "everyone welcome", "food trucks", "performance", "gig", "event", "celebrat", "invite")
    private val venueWords = listOf("park", "hall", "center", "centre", "street", " st", " ave", "avenue", "road", " rd", "blvd", "boulevard", "plaza", "square", "arena", "stadium", "theater", "theatre", "church", "school", "library", "club", "bar", "cafe", "restaurant", "hotel", "room", "field", "garden", "gallery", "museum", "campus", "lane", " dr", "drive", "downtown", "suite", "floor")

    fun classify(text: String): CaptureResult {
        val lines = text.lines().map { it.trim() }.filter { it.isNotBlank() }
        val lower = text.lowercase()
        val words = text.split(Regex("\\s+")).filter { it.isNotBlank() }.size
        val money = moneyRe.findAll(text).toList()
        val emails = emailRe.findAll(text).map { it.value }.toList()
        val phones = phoneRe.findAll(text).map { it.value.trim() }.filter { it.count { c -> c.isDigit() } >= 10 }.toList()
        val dates = dateRe.findAll(text).toList()
        val times = timeRe.findAll(text).toList()
        val hasUrl = urlRe.containsMatchIn(text)

        fun count(list: List<String>) = list.count { lower.contains(it) }

        var receipt = 0
        receipt += count(receiptWords) * 2
        receipt += minOf(money.size, 6) * 2
        if (Regex("""(?i)\btotal\b""").containsMatchIn(text) && money.isNotEmpty()) receipt += 6
        if (lines.count { lineItem(it) != null } >= 2) receipt += 4

        var card = 0
        if (emails.isNotEmpty()) card += 5
        if (phones.isNotEmpty()) card += 4
        if (hasUrl) card += 2
        card += count(cardWords) * 2
        if (lines.size in 3..12 && words <= 45) card += 3
        if (money.isNotEmpty()) card -= 3

        var flyer = 0
        flyer += count(flyerWords) * 3
        if (dates.isNotEmpty()) flyer += 3
        if (times.isNotEmpty()) flyer += 3
        if (dates.isNotEmpty() && times.isNotEmpty()) flyer += 3
        flyer += minOf(count(venueWords), 3) * 2
        if (money.size > 3) flyer -= 3
        if (emails.isNotEmpty() && phones.isNotEmpty() && dates.isEmpty()) flyer -= 4

        val sign = lines.size <= 3 && words <= 8 && text.count { it.isUpperCase() } >= (text.count { it.isLetter() } * 0.6).toInt() && money.isEmpty() && emails.isEmpty()

        val kind = when {
            receipt >= 8 && receipt >= card && receipt >= flyer -> CaptureKind.RECEIPT
            card >= 9 && card >= flyer -> CaptureKind.CARD
            flyer >= 9 -> CaptureKind.FLYER
            sign -> CaptureKind.SIGN
            else -> CaptureKind.DOCUMENT
        }
        return when (kind) {
            CaptureKind.RECEIPT -> receiptResult(text, lines, money, dates)
            CaptureKind.CARD -> cardResult(text, lines, emails, phones)
            CaptureKind.FLYER -> flyerResult(text, lines, dates)
            CaptureKind.SIGN -> CaptureResult(CaptureKind.SIGN, text, listOf("Type" to "Sign", "Words" to "$words"), words = words)
            CaptureKind.DOCUMENT -> {
                val type = guessDocType(lower)
                CaptureResult(CaptureKind.DOCUMENT, text, listOf("Type" to type, "Pages" to "1", "Words" to "$words"), words = words)
            }
        }
    }

    private fun guessDocType(lower: String): String = when {
        lower.contains("agreement") || lower.contains("contract") -> "Agreement"
        lower.contains("invoice") -> "Invoice"
        lower.contains("letter") || lower.contains("dear ") -> "Letter"
        lower.contains("menu") -> "Menu"
        lower.contains("notice") -> "Notice"
        lower.contains("form") || lower.contains("signature") -> "Form"
        lower.contains("recipe") || lower.contains("ingredients") -> "Recipe"
        lower.contains("policy") -> "Policy"
        lower.contains("ticket") || lower.contains("boarding") -> "Ticket"
        else -> "Document"
    }

    // ---- receipt ----

    /** "Oat milk ........ 4.99" → ("Oat milk", "4.99"). */
    fun lineItem(line: String): Pair<String, String>? {
        val m = Regex("""^(.*?[A-Za-z].*?)\s*[.\s]{1,}\s*[$£€]?\s?(\d{1,3}(?:,\d{3})*\.\d{2})\s*[A-Z]?$""").find(line.trim()) ?: return null
        val name = m.groupValues[1].trim().trimEnd('.', ':', '-', ' ')
        if (name.isBlank() || name.length > 48) return null
        if (Regex("""(?i)\b(total|subtotal|sub-total|tax|vat|change|cash|tender|visa|mastercard|amex|debit|credit|balance|tip|due|paid)\b""").containsMatchIn(name)) return null
        return name to m.groupValues[2].replace(",", "")
    }

    private fun receiptResult(text: String, lines: List<String>, money: List<MatchResult>, dates: List<MatchResult>): CaptureResult {
        val merchant = lines.firstOrNull { l ->
            l.length in 3..40 && l.any { it.isLetter() } && !moneyRe.containsMatchIn(l) && !dateRe.containsMatchIn(l) &&
                !Regex("""(?i)^(receipt|invoice|tel|phone|www|http|\d)""").containsMatchIn(l)
        } ?: lines.firstOrNull().orEmpty()
        // Prefer the amount on a "total" line; else the biggest amount seen.
        val totalLine = lines.lastOrNull { Regex("""(?i)\btotal\b""").containsMatchIn(it) && !Regex("""(?i)sub""").containsMatchIn(it) && moneyRe.containsMatchIn(it) }
        val total = totalLine?.let { moneyRe.findAll(it).lastOrNull()?.value?.trim() }
            ?: money.maxByOrNull { numeric(it.value) }?.value?.trim().orEmpty()
        val date = dates.firstNotNullOfOrNull { parseDate(it.value) }
        val card = Regex("""(?i)\b(visa|mastercard|master card|amex|american express|discover|debit|credit)\b[^\d\n]*(\*{2,}|x{2,}|•{2,})?\s?(\d{4})""").find(text)
            ?.let { "${it.groupValues[1].replaceFirstChar { c -> c.uppercase() }} ••${it.groupValues[3]}" }
            ?: Regex("""(?i)\b(visa|mastercard|amex|discover|cash)\b""").find(text)?.value?.replaceFirstChar { it.uppercase() }.orEmpty()
        val items = lines.mapNotNull { lineItem(it) }
        val fields = ArrayList<Pair<String, String>>()
        fields.add("Merchant" to merchant.ifBlank { "—" })
        fields.add("Date" to (date?.let { dayFmt.format(Date(it)) } ?: "—"))
        fields.add("Total" to total.ifBlank { "—" })
        if (card.isNotBlank()) fields.add("Card" to card)
        if (items.isNotEmpty()) fields.add("Items" to "${items.size}")
        return CaptureResult(CaptureKind.RECEIPT, text, fields, merchant = merchant, total = total, purchaseMs = date, items = items)
    }

    private fun numeric(s: String): Double = s.filter { it.isDigit() || it == '.' }.toDoubleOrNull() ?: 0.0

    // ---- business card ----

    private fun cardResult(text: String, lines: List<String>, emails: List<String>, phones: List<String>): CaptureResult {
        val email = emails.firstOrNull().orEmpty()
        val phone = phones.firstOrNull().orEmpty()
        val plain = lines.filter { l ->
            !emailRe.containsMatchIn(l) && !phoneRe.containsMatchIn(l) && !urlRe.containsMatchIn(l) &&
                !Regex("""(?i)^(tel|phone|mobile|cell|fax|email|e-mail|www|office)\b""").containsMatchIn(l) && l.any { it.isLetter() }
        }
        val titleIdx = plain.indexOfFirst { l -> cardWords.any { w -> Regex("""(?i)\b${Regex.escape(w)}\b""").containsMatchIn(l) } && l.split(" ").size <= 6 }
        val title = if (titleIdx >= 0) plain[titleIdx] else ""
        // Name: a 2–4 word line of capitalised words, ideally right above the title.
        fun looksLikeName(l: String): Boolean {
            val w = l.split(Regex("\\s+")).filter { it.isNotBlank() }
            return w.size in 2..4 && w.all { it.first().isUpperCase() || it.first() == '(' } && !l.any { it.isDigit() } &&
                !Regex("""(?i)\b(inc|llc|ltd|corp|co|gmbh|group|labs|studio|solutions|partners|associates|company|agency)\b""").containsMatchIn(l)
        }
        val name = (if (titleIdx > 0) plain.subList(0, titleIdx).lastOrNull { looksLikeName(it) } else null)
            ?: plain.firstOrNull { looksLikeName(it) } ?: plain.firstOrNull().orEmpty()
        val company = plain.firstOrNull { it != name && it != title && (Regex("""(?i)\b(inc|llc|ltd|corp|co\.|gmbh|group|labs|studio|solutions|partners|associates|company|agency|technologies|consulting)\b""").containsMatchIn(it)) }
            ?: plain.firstOrNull { it != name && it != title && it.length in 2..40 }
            ?: email.substringAfter('@').substringBefore('.').replaceFirstChar { it.uppercase() }
        val fields = ArrayList<Pair<String, String>>()
        fields.add("Name" to name.ifBlank { "—" })
        if (title.isNotBlank()) fields.add("Title" to title)
        if (company.isNotBlank()) fields.add("Company" to company)
        if (email.isNotBlank()) fields.add("Email" to email)
        if (phone.isNotBlank()) fields.add("Phone" to phone)
        return CaptureResult(CaptureKind.CARD, text, fields, name = name, title = title, company = company, email = email, phone = phone)
    }

    // ---- flyer ----

    private fun flyerResult(text: String, lines: List<String>, dates: List<MatchResult>): CaptureResult {
        val event = lines.firstOrNull { l ->
            l.length in 4..60 && l.any { it.isLetter() } && !dateRe.containsMatchIn(l) && !timeRe.containsMatchIn(l) &&
                !venueWords.any { v -> l.lowercase().contains(v.trim()) && v.trim().length > 3 }
        } ?: lines.firstOrNull().orEmpty()
        val dayMs = dates.firstNotNullOfOrNull { parseDate(it.value) }
        val range = timeRangeRe.find(text)
        val single = timeRe.find(text)
        var startMs: Long? = null
        var endMs: Long? = null
        if (dayMs != null) {
            val cal = Calendar.getInstance().apply { timeInMillis = dayMs }
            if (range != null) {
                val endAp = range.groupValues[6]
                val startAp = range.groupValues[3].ifBlank { endAp }
                startMs = at(cal, range.groupValues[1].toInt(), range.groupValues[2].toIntOrNull() ?: 0, startAp)
                endMs = at(cal, range.groupValues[4].toInt(), range.groupValues[5].toIntOrNull() ?: 0, endAp)
            } else if (single != null) {
                startMs = at(cal, single.groupValues[1].toInt(), single.groupValues[2].toIntOrNull() ?: 0, single.groupValues[3])
                endMs = startMs + 2 * 3_600_000L
            } else {
                startMs = dayMs; endMs = dayMs + 24 * 3_600_000L
            }
        }
        val venue = lines.firstOrNull { l -> l != event && venueWords.any { v -> l.lowercase().contains(v) } && !timeRe.containsMatchIn(l) }
            ?: lines.firstOrNull { l -> l != event && Regex("""^\d{1,5}\s+\w+""").containsMatchIn(l) }.orEmpty()
        val whenText = when {
            startMs != null && range != null -> dayFmt.format(Date(startMs)) + " · " + range.value.trim()
            startMs != null && single != null -> whenFmt.format(Date(startMs))
            dayMs != null -> dayFmt.format(Date(dayMs))
            single != null -> single.value.trim()
            else -> "—"
        }
        val fields = listOf("Event" to event.ifBlank { "—" }, "When" to whenText, "Where" to venue.ifBlank { "—" })
        return CaptureResult(CaptureKind.FLYER, text, fields, event = event, startMs = startMs, endMs = endMs, venue = venue)
    }

    private fun at(day: Calendar, hour12: Int, minute: Int, ap: String): Long {
        var h = hour12 % 12
        if (ap.lowercase().startsWith("p")) h += 12
        val c = day.clone() as Calendar
        c.set(Calendar.HOUR_OF_DAY, h); c.set(Calendar.MINUTE, minute); c.set(Calendar.SECOND, 0); c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis
    }

    /** Best-effort date parse of one matched token. Year defaults to this year (next, if that day has passed). */
    fun parseDate(raw: String): Long? {
        val s = raw.trim()
        val fmts = listOf("yyyy-M-d", "M/d/yyyy", "d/M/yyyy", "M/d/yy", "d-M-yyyy", "M-d-yyyy", "d.M.yyyy", "d MMM yyyy", "d MMMM yyyy", "MMM d yyyy", "MMMM d yyyy", "MMM d, yyyy", "MMMM d, yyyy", "EEE d MMM yyyy", "EEEE d MMMM yyyy", "EEE, MMM d, yyyy", "EEE MMM d yyyy")
        val cleaned = s.replace(Regex("""(\d)(st|nd|rd|th)"""), "$1").replace(Regex("""(?i)\bsept\b"""), "Sep").replace(",", "")
        for (f in fmts) {
            val fmt = SimpleDateFormat(f.replace(",", ""), Locale.US).apply { isLenient = false }
            val d = runCatching { fmt.parse(cleaned) }.getOrNull()
            if (d != null) return d.time
        }
        // No year: "18 Jul" / "Jul 18"
        val m = Regex("""(?i)(?:(\d{1,2})\s+([a-z]{3,9}))|(?:([a-z]{3,9})\s+(\d{1,2}))""").find(cleaned) ?: return null
        val dayStr = m.groupValues[1].ifBlank { m.groupValues[4] }
        val monStr = m.groupValues[2].ifBlank { m.groupValues[3] }.lowercase().take(3)
        val mon = months.indexOf(monStr); val day = dayStr.toIntOrNull() ?: return null
        if (mon < 0 || day !in 1..31) return null
        val now = Calendar.getInstance()
        val c = Calendar.getInstance().apply { set(Calendar.MONTH, mon); set(Calendar.DAY_OF_MONTH, day); set(Calendar.HOUR_OF_DAY, 9); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
        if (c.before(now) && now.timeInMillis - c.timeInMillis > 60L * 24 * 3_600_000L) c.add(Calendar.YEAR, 1)
        return c.timeInMillis
    }

    // ---- exports ----

    fun csv(r: CaptureResult): String {
        val sb = StringBuilder("Item,Price\n")
        r.items.forEach { (n, p) -> sb.append('"').append(n.replace("\"", "\"\"")).append("\",").append(p).append('\n') }
        if (r.items.isEmpty()) r.text.lines().filter { it.isNotBlank() }.forEach { sb.append('"').append(it.trim().replace("\"", "\"\"")).append("\",\n") }
        if (r.total.isNotBlank()) sb.append("Total,").append(r.total.filter { it.isDigit() || it == '.' }).append('\n')
        return sb.toString()
    }

    fun fileStem(r: CaptureResult): String {
        val base = when (r.kind) {
            CaptureKind.RECEIPT -> r.merchant
            CaptureKind.CARD -> r.name
            CaptureKind.FLYER -> r.event
            else -> r.text.lines().firstOrNull { it.isNotBlank() }.orEmpty()
        }.lowercase().replace(Regex("[^a-z0-9]+"), "-").trim('-').take(32).ifBlank { "capture" }
        return base + "-" + SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    }
}

/** Bitmap in/out for Capture: decode with EXIF rotation, scale for OCR, and save as PDF / JPEG. */
object CaptureImages {
    fun load(ctx: Context, uri: Uri, maxDim: Int = 2200): Bitmap? = runCatching {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (bounds.outWidth / sample > maxDim || bounds.outHeight / sample > maxDim) sample *= 2
        val decoded = ctx.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: return null
        val orientation = runCatching {
            ctx.contentResolver.openInputStream(uri)?.use { ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL) }
        }.getOrNull() ?: ExifInterface.ORIENTATION_NORMAL
        val m = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.postScale(1f, -1f)
            else -> return decoded
        }
        val out = runCatching { Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, m, true) }.getOrDefault(decoded)
        if (out !== decoded) decoded.recycle()
        out
    }.getOrNull()

    fun saveJpeg(bmp: Bitmap, file: File, quality: Int = 90): File {
        file.outputStream().use { bmp.compress(Bitmap.CompressFormat.JPEG, quality, it) }
        return file
    }

    /** One A4 page with the photo fitted inside the margins. Text is left out on purpose — the
     *  "All text" section is where it lives, and Copy puts it anywhere. */
    fun toPdf(bmp: Bitmap, file: File): File {
        val w = 595; val h = 842; val margin = 24f
        val doc = PdfDocument()
        val page = doc.startPage(PdfDocument.PageInfo.Builder(w, h, 1).create())
        val availW = w - 2 * margin; val availH = h - 2 * margin
        val scale = minOf(availW / bmp.width, availH / bmp.height)
        val dw = bmp.width * scale; val dh = bmp.height * scale
        val left = (w - dw) / 2f; val top = (h - dh) / 2f
        val c: Canvas = page.canvas
        c.drawBitmap(bmp, null, RectF(left, top, left + dw, top + dh), Paint(Paint.FILTER_BITMAP_FLAG))
        doc.finishPage(page)
        file.outputStream().use { doc.writeTo(it) }
        doc.close()
        return file
    }
}
