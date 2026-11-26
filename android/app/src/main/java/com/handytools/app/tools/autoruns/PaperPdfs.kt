package com.handytools.app.tools.autoruns

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import android.net.Uri
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.tools.power.CaptureClassifier
import com.handytools.app.tools.power.CaptureKind
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.atan2
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Today's paper into searchable PDFs (the iPhone's autorun, the Android way): today's photos of letters, bills, forms
 * and pages become PDFs — each page cropped to its words, turned straight, the paper whitened and the ink darkened,
 * with an invisible text layer so its words can be found, selected and copied. Pages photographed one after another
 * are one document (a "Page 1 of" starts a new one), named from what the page says, never from an address, a date or
 * a greeting. Receipts and business cards are left to their own autoruns. Nothing leaves the phone.
 */
object PaperPdfs {
    data class Page(val id: String, val taken: Long, val text: String)
    data class Doc(val title: String, val pages: List<String>, val file: File, val taken: Long, val words: Int)

    // ---- the iPhone's pure rules ----

    fun startsADocument(text: String): Boolean {
        val t = text.lowercase()
        return Regex("\\bpage\\s+1\\s+(of|/)\\s*\\d+").containsMatchIn(t) || Regex("(?m)^\\s*1\\s*/\\s*\\d+\\s*$").containsMatchIn(t)
    }

    /** Pages photographed within [gapMs] of each other are one document — unless a page says it is the first. */
    fun group(pages: List<Page>, gapMs: Long = 180_000): List<List<String>> {
        val out = ArrayList<MutableList<String>>()
        var last: Long? = null
        for (p in pages.sortedBy { it.taken }) {
            val l = last
            if (l != null && p.taken - l <= gapMs && !startsADocument(p.text) && out.isNotEmpty()) out.last().add(p.id) else out.add(mutableListOf(p.id))
            last = p.taken
        }
        return out
    }

    val kinds = listOf("agreement", "contract", "lease", "invoice", "statement", "notice", "letter", "report", "form", "application",
        "certificate", "policy", "bill", "estimate", "quote", "quotation", "proposal", "minutes", "agenda", "itinerary",
        "prescription", "permit", "license", "licence", "registration", "declaration", "summary", "schedule",
        "confirmation", "receipt", "order", "tax", "w-2", "1099", "pay stub", "payslip", "transcript", "resume", "syllabus")

    private val street = Regex("\\d{1,5}\\s+\\w+\\s+(st|street|ave|avenue|rd|road|blvd|dr|drive|ln|lane|way|ct)\\b")
    private val contact = Regex("@|www\\.|https?://|\\(\\d{3}\\)|\\d{3}[-.\\s]\\d{3}[-.\\s]\\d{4}")
    private val dateish = Regex("\\b\\d{1,4}[/.-]\\d{1,2}[/.-]\\d{1,4}\\b|\\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\\.?\\s+\\d{1,2}\\b|\\b\\d{1,2}\\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)", RegexOption.IGNORE_CASE)

    /** A short, true name from the page's own words: the line naming what it is, else the first heading-like line. */
    fun title(text: String): String {
        val lines = text.lines().map { it.trim() }.take(14)
        fun usable(l: String): Boolean {
            val letters = l.count { it.isLetter() }
            if (letters < 4 || l.length > 70 || letters.toDouble() / max(1, l.length) <= 0.55) return false
            val low = l.lowercase()
            if (low.startsWith("dear ") || low.startsWith("to:") || low.startsWith("from:") || low.startsWith("date")) return false
            if (street.containsMatchIn(low) || contact.containsMatchIn(low)) return false
            if (dateish.containsMatchIn(l) && letters < 12) return false
            return true
        }
        val named = lines.firstOrNull { l -> usable(l) && l.split(" ").size <= 8 && kinds.any { k -> Regex("\\b" + Regex.escape(k) + "\\b").containsMatchIn(l.lowercase()) } }
        return tidy(named ?: lines.firstOrNull { usable(it) && it.split(" ").size <= 8 } ?: "")
    }

    /** "RESIDENTIAL LEASE AGREEMENT" → "Residential Lease Agreement"; a mixed-case line is kept as written. */
    fun tidy(s: String): String {
        val t = s.trim { it == ' ' || it in ":-–—.,;" }
        if (t != t.uppercase() || t.none { it.isLetter() }) return t
        val small = setOf("of", "and", "the", "for", "to", "in", "on", "a", "an", "or", "by")
        return t.lowercase().split(" ").mapIndexed { i, w ->
            when {
                i > 0 && w in small -> w
                w.length <= 3 && (w.any { it.isDigit() } || w in setOf("llc", "inc", "usa", "irs", "w-2")) -> w.uppercase()
                else -> w.replaceFirstChar { it.uppercase() }
            }
        }.joinToString(" ")
    }

    fun fileName(title: String, day: Long): String {
        val clean = title.map { if (it in "/\\:?%*|\"<>\n\r\t") ' ' else it }.joinToString("").split(" ").filter { it.isNotEmpty() }.joinToString(" ")
        val name = clean.ifEmpty { com.handytools.app.I18n.t("Document") }.take(60)
        return "$name ${SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(day))}.pdf"
    }

    /** A page: a document's words, enough of them, not a receipt or a business card. */
    fun isPaper(text: String): Boolean {
        val words = text.split(Regex("\\s+")).count { it.length > 1 }
        if (words < 40) return false
        val k = CaptureClassifier.classify(text).kind
        return k != CaptureKind.RECEIPT && k != CaptureKind.CARD
    }

    // ---- on the phone ----

    /** One page made clean: cropped to its words (with a margin), turned straight, paper whitened, ink darkened. */
    private fun clean(photo: Bitmap, t: Text): Pair<Bitmap, Matrix> {
        // The words' slant, from the long text lines.
        val angles = t.textBlocks.flatMap { it.lines }.mapNotNull { l ->
            val p = l.cornerPoints ?: return@mapNotNull null
            if (p.size < 2 || l.text.length < 12) null else Math.toDegrees(atan2((p[1].y - p[0].y).toDouble(), (p[1].x - p[0].x).toDouble()))
        }.sorted()
        val angle = if (angles.isEmpty()) 0.0 else angles[angles.size / 2]
        val box = t.textBlocks.mapNotNull { it.boundingBox }.fold(null as Rect?) { a, b -> if (a == null) Rect(b) else a.apply { union(b) } } ?: Rect(0, 0, photo.width, photo.height)
        val margin = (max(box.width(), box.height()) * 0.06).roundToInt()
        val crop = Rect(max(0, box.left - margin), max(0, box.top - margin), min(photo.width, box.right + margin), min(photo.height, box.bottom + margin))
        val m = Matrix().apply { postTranslate(-crop.left.toFloat(), -crop.top.toFloat()); postRotate(-angle.toFloat(), crop.width() / 2f, crop.height() / 2f) }
        val out = Bitmap.createBitmap(crop.width(), crop.height(), Bitmap.Config.ARGB_8888)
        val c = Canvas(out); c.drawColor(android.graphics.Color.WHITE)
        // Grey, then a strong contrast around the paper's brightness: the paper goes white, the ink dark.
        val cm = ColorMatrix().apply { setSaturation(0f) }
        val k = 1.7f; val shift = -255f * 0.42f
        cm.postConcat(ColorMatrix(floatArrayOf(k, 0f, 0f, 0f, shift, 0f, k, 0f, 0f, shift, 0f, 0f, k, 0f, shift, 0f, 0f, 0f, 1f, 0f)))
        c.drawBitmap(photo, m, Paint(Paint.FILTER_BITMAP_FLAG).apply { colorFilter = ColorMatrixColorFilter(cm) })
        return out to m
    }

    /** Today's pages as PDFs. [progress] runs 0…1. */
    suspend fun make(ctx: Context, window: LongRange, progress: (Double) -> Unit = {}): List<Doc> = withContext(Dispatchers.Default) {
        val photos = PhotoDays.find(ctx, window).filterNot { it.screenshot }
        val reader = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val read = LinkedHashMap<String, Pair<Uri, Text>>()
        val pages = ArrayList<Page>()
        try {
            photos.forEachIndexed { i, p ->
                ensureActive()
                progress(0.7 * (i + 1) / max(1, photos.size))
                val b = PhotoDays.small(ctx, p.uri, 2000) ?: return@forEachIndexed
                val t = runCatching { Tasks.await(reader.process(InputImage.fromBitmap(b, 0))) }.getOrNull()
                b.recycle()
                if (t == null || !isPaper(t.text)) return@forEachIndexed
                read[p.uri.toString()] = p.uri to t; pages += Page(p.uri.toString(), p.created, t.text)
            }
        } finally { reader.close() }
        val dir = File(ctx.filesDir, "papers").also { it.mkdirs() }
        val groups = group(pages)
        groups.mapIndexedNotNull { gi, ids ->
            progress(0.7 + 0.3 * (gi + 1) / groups.size)
            val pdf = PdfDocument()
            var words = 0
            ids.forEachIndexed { n, id ->
                val (uri, t) = read[id] ?: return@forEachIndexed
                val photo = PhotoDays.small(ctx, uri, 2000) ?: return@forEachIndexed
                val (page, m) = clean(photo, t)
                photo.recycle()
                // A US Letter / A4-shaped page at 72 dpi, the cleaned picture fitted in, the words laid invisibly over it.
                val pw = 612; val ph = max(612, (612f * page.height / page.width).roundToInt())
                val p = pdf.startPage(PdfDocument.PageInfo.Builder(pw, ph, n + 1).create())
                val s = pw.toFloat() / page.width
                p.canvas.drawBitmap(page, null, RectF(0f, 0f, pw.toFloat(), page.height * s), Paint(Paint.FILTER_BITMAP_FLAG))
                val ink = Paint(Paint.ANTI_ALIAS_FLAG).apply { alpha = 0 }
                t.textBlocks.flatMap { it.lines }.forEach { l ->
                    val bb = l.boundingBox ?: return@forEach
                    val pts = floatArrayOf(bb.left.toFloat(), bb.bottom.toFloat()); m.mapPoints(pts)
                    ink.textSize = max(4f, bb.height() * s * 0.85f)
                    p.canvas.drawText(l.text, pts[0] * s, pts[1] * s, ink)
                    words += l.text.split(" ").size
                }
                pdf.finishPage(p)
                page.recycle()
            }
            val first = read[ids.first()]?.second?.text.orEmpty()
            val name = fileName(title(first), pages.first { it.id == ids.first() }.taken)
            val f = File(dir, name)
            runCatching { f.outputStream().use { pdf.writeTo(it) } }
            pdf.close()
            if (f.length() > 0) Doc(title(first).ifEmpty { com.handytools.app.I18n.t("Document") }, ids, f, pages.first { it.id == ids.first() }.taken, words) else null
        }
    }
}
