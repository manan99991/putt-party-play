package com.handytools.app.tools.power

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.provider.OpenableColumns
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.tasks.await
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

/** Page filters for the Scan tab, applied with a ColorMatrix on the bitmap. */
internal enum class DocScanFilter(val label: String) { COLOR("Color"), GRAY("Grayscale"), BW("B&W") }

/** One scanned page: the source bitmap plus a rotation in degrees (0/90/180/270). */
internal class DocScanPage(val source: Bitmap, val rotation: Int = 0)

/** Something placed on a page in Sign & fill. Coordinates are fractions of the page size. */
internal data class SignPlaced(
    val id: Long,
    val isSignature: Boolean,
    val cx: Float,
    val cy: Float,
    val w: Float,          // width as a fraction of page width (signature only)
    val textFrac: Float,   // text height as a fraction of page height (text only)
    val text: String,
    val bitmap: Bitmap?,
)

internal data class DocPdfInfo(val uri: Uri, val name: String, val size: Long, val pages: Int)

/** On-device document helpers shared by the Documents tool. Nothing leaves the phone. */
internal object DocEngine {

    fun findActivity(ctx: Context): Activity? {
        var c: Context = ctx
        while (c is ContextWrapper) { if (c is Activity) return c; c = c.baseContext }
        return null
    }

    fun outFile(ctx: Context, prefix: String, ext: String = "pdf") =
        File(ctx.cacheDir, "$prefix-${System.currentTimeMillis()}.$ext")

    // ------------------------------------------------------------------ bitmaps

    /** Decode an image URI honoring EXIF rotation, scaled so the long edge is at most [maxEdge]. */
    fun loadBitmap(ctx: Context, uri: Uri, maxEdge: Int = 2000, lowMem: Boolean = false): Bitmap? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) } ?: return null
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxEdge) sample *= 2
            val opts = BitmapFactory.Options().apply { inSampleSize = sample; if (lowMem) inPreferredConfig = Bitmap.Config.RGB_565 }
            var bmp = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) } ?: return null
            val rot = try {
                ctx.contentResolver.openInputStream(uri)?.use { ExifInterface(it).rotationDegrees } ?: 0
            } catch (_: Exception) { 0 }
            val scale = maxEdge.toFloat() / maxOf(bmp.width, bmp.height)
            if (scale < 1f) bmp = Bitmap.createScaledBitmap(bmp, (bmp.width * scale).toInt().coerceAtLeast(1), (bmp.height * scale).toInt().coerceAtLeast(1), true)
            if (rot != 0) {
                val m = Matrix().apply { postRotate(rot.toFloat()) }
                bmp = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
            }
            bmp
        } catch (_: Exception) { null } catch (_: OutOfMemoryError) { null }
    }

    /** Rotate + filter a page into a fresh bitmap (what the preview shows and the PDF gets). */
    fun process(src: Bitmap, rotation: Int, filter: DocScanFilter, lowMem: Boolean = false): Bitmap {
        val swap = rotation % 180 != 0
        val w = if (swap) src.height else src.width
        val h = if (swap) src.width else src.height
        val out = Bitmap.createBitmap(w, h, if (lowMem) Bitmap.Config.RGB_565 else Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        c.drawColor(Color.WHITE)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
        when (filter) {
            DocScanFilter.COLOR -> {}
            DocScanFilter.GRAY -> paint.colorFilter = ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(0f) })
            DocScanFilter.BW -> {
                val cm = ColorMatrix().apply { setSaturation(0f) }
                val s = 1.8f; val t = (1f - s) * 128f + 14f
                cm.postConcat(ColorMatrix(floatArrayOf(s, 0f, 0f, 0f, t, 0f, s, 0f, 0f, t, 0f, 0f, s, 0f, t, 0f, 0f, 0f, 1f, 0f)))
                paint.colorFilter = ColorMatrixColorFilter(cm)
            }
        }
        c.save()
        c.translate(w / 2f, h / 2f)
        c.rotate(rotation.toFloat())
        c.drawBitmap(src, -src.width / 2f, -src.height / 2f, paint)
        c.restore()
        return out
    }

    fun thumbnail(src: Bitmap, maxEdge: Int = 240): Bitmap {
        val scale = maxEdge.toFloat() / maxOf(src.width, src.height)
        if (scale >= 1f) return src
        return Bitmap.createScaledBitmap(src, (src.width * scale).toInt().coerceAtLeast(1), (src.height * scale).toInt().coerceAtLeast(1), true)
    }

    // ------------------------------------------------------------------ scan → searchable PDF

    /**
     * Writes every page to an A4 PDF. Each page's recognised text (ML Kit, on-device) is drawn
     * underneath the page image at the block positions so the PDF is searchable without the text
     * ever being visible. If OCR fails for a page we still export the image page — never fail.
     */
    suspend fun exportSearchablePdf(ctx: Context, pages: List<DocScanPage>, filter: DocScanFilter): File? {
        if (pages.isEmpty()) return null
        val recognizer = try { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) } catch (_: Exception) { null }
        val doc = PdfDocument()
        try {
            pages.forEachIndexed { i, src ->
                // NOTE: PdfDocument records pages and only rasterises at writeTo(), so every bitmap drawn
                // must stay alive (never recycled) until the file is written. RGB_565 halves the cost.
                val bmp = process(src.source, src.rotation, filter, lowMem = true)
                val landscape = bmp.width > bmp.height
                val pw = if (landscape) 842 else 595
                val ph = if (landscape) 595 else 842
                val page = doc.startPage(PdfDocument.PageInfo.Builder(pw, ph, i + 1).create())
                val c = page.canvas
                c.drawColor(Color.WHITE)
                val scale = minOf(pw.toFloat() / bmp.width, ph.toFloat() / bmp.height)
                val w = bmp.width * scale; val h = bmp.height * scale
                val left = (pw - w) / 2f; val top = (ph - h) / 2f
                val text = try {
                    if (recognizer == null) null else {
                        val ocrIn = if (bmp.config == Bitmap.Config.ARGB_8888) bmp else (bmp.copy(Bitmap.Config.ARGB_8888, false) ?: bmp)
                        val t = recognizer.process(InputImage.fromBitmap(ocrIn, 0)).await()
                        if (ocrIn !== bmp) ocrIn.recycle()
                        t
                    }
                } catch (_: Exception) { null }
                if (text != null) {
                    // Alpha 1 (not 0): the PDF backend drops fully transparent draws entirely.
                    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK; alpha = 1 }
                    for (block in text.textBlocks) for (line in block.lines) {
                        val box = line.boundingBox ?: continue
                        val lh = box.height() * scale
                        if (lh < 1f || line.text.isBlank()) continue
                        paint.textSize = lh * 0.85f
                        paint.textScaleX = 1f
                        val measured = paint.measureText(line.text)
                        if (measured > 0f) paint.textScaleX = (box.width() * scale / measured).coerceIn(0.3f, 3f)
                        c.drawText(line.text, left + box.left * scale, top + box.bottom * scale - lh * 0.2f, paint)
                    }
                }
                c.drawBitmap(bmp, null, RectF(left, top, left + w, top + h), Paint(Paint.FILTER_BITMAP_FLAG))
                doc.finishPage(page)
            }
            val f = outFile(ctx, "Tenzy-scan")
            FileOutputStream(f).use { doc.writeTo(it) }
            return f
        } catch (_: Exception) {
            return null
        } finally {
            doc.close()
            try { recognizer?.close() } catch (_: Exception) {}
        }
    }

    // ------------------------------------------------------------------ PDF reading

    fun isPdf(ctx: Context, uri: Uri): Boolean {
        val t = ctx.contentResolver.getType(uri) ?: ""
        if (t == "application/pdf") return true
        return displayName(ctx, uri).lowercase().endsWith(".pdf")
    }

    fun displayName(ctx: Context, uri: Uri): String {
        try {
            ctx.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst() && !c.isNull(0)) return c.getString(0)
            }
        } catch (_: Exception) {}
        return uri.lastPathSegment?.substringAfterLast('/') ?: "file"
    }

    fun pdfInfo(ctx: Context, uri: Uri): DocPdfInfo {
        var name = "document.pdf"; var size = -1L
        try {
            ctx.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    if (!c.isNull(0)) name = c.getString(0)
                    if (!c.isNull(1)) size = c.getLong(1)
                }
            }
        } catch (_: Exception) {}
        return DocPdfInfo(uri, name, size, pdfPageCount(ctx, uri))
    }

    fun pdfPageCount(ctx: Context, uri: Uri): Int = try {
        ctx.contentResolver.openFileDescriptor(uri, "r")?.use { pfd -> PdfRenderer(pfd).use { it.pageCount } } ?: 0
    } catch (_: Exception) { 0 }

    fun renderPdfPage(ctx: Context, uri: Uri, index: Int, maxEdge: Int = 1600): Bitmap? = try {
        ctx.contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
            PdfRenderer(pfd).use { r ->
                if (index !in 0 until r.pageCount) null
                else r.openPage(index).use { p ->
                    val scale = maxEdge.toFloat() / maxOf(p.width, p.height)
                    val bmp = Bitmap.createBitmap((p.width * scale).toInt().coerceAtLeast(1), (p.height * scale).toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
                    bmp.eraseColor(Color.WHITE)
                    p.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    bmp
                }
            }
        }
    } catch (_: Exception) { null } catch (_: OutOfMemoryError) { null }

    /** PDF page [index] or the image itself, for the Sign & fill preview. */
    fun loadPage(ctx: Context, uri: Uri, isPdf: Boolean, index: Int, maxEdge: Int = 1600): Bitmap? =
        if (isPdf) renderPdfPage(ctx, uri, index, maxEdge) else loadBitmap(ctx, uri, maxEdge)

    private fun eachPage(ctx: Context, uri: Uri, scale: Float, block: (Bitmap, Int) -> Unit) {
        ctx.contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
            PdfRenderer(pfd).use { r ->
                for (i in 0 until r.pageCount) {
                    r.openPage(i).use { p ->
                        val bmp = Bitmap.createBitmap((p.width * scale).toInt().coerceAtLeast(1), (p.height * scale).toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
                        bmp.eraseColor(Color.WHITE)
                        p.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        // Keep the 565 copy (half the memory); bitmaps drawn into a PdfDocument must
                        // outlive writeTo(), so the callback never recycles what it draws.
                        val small = bmp.copy(Bitmap.Config.RGB_565, false) ?: bmp
                        if (small !== bmp) bmp.recycle()
                        block(small, i)
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------ sign & fill export

    /** Draw [items] onto page bitmap [bmp] (same maths as the on-screen overlay). */
    fun drawPlaced(c: Canvas, bmp: Bitmap, items: List<SignPlaced>) {
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFF14148A.toInt() }
        val bmpPaint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
        items.forEach { it ->
            val sig = it.bitmap
            if (it.isSignature && sig != null) {
                val w = it.w * bmp.width
                val h = w * sig.height / sig.width
                val l = it.cx * bmp.width - w / 2f; val t = it.cy * bmp.height - h / 2f
                c.drawBitmap(sig, null, RectF(l, t, l + w, t + h), bmpPaint)
            } else if (!it.isSignature) {
                textPaint.textSize = it.textFrac * bmp.height
                val tw = textPaint.measureText(it.text)
                c.drawText(it.text, it.cx * bmp.width - tw / 2f, it.cy * bmp.height + textPaint.textSize * 0.35f, textPaint)
            }
        }
    }

    /** Flatten every page (PDF) or the single image with its placed items into a new PDF. */
    fun exportSigned(ctx: Context, uri: Uri, isPdf: Boolean, pageCount: Int, items: Map<Int, List<SignPlaced>>): File? {
        val doc = PdfDocument()
        try {
            var n = 0
            if (isPdf) {
                eachPage(ctx, uri, 2f) { bmp, i ->
                    val page = doc.startPage(PdfDocument.PageInfo.Builder(bmp.width, bmp.height, ++n).create())
                    page.canvas.drawBitmap(bmp, 0f, 0f, null)
                    drawPlaced(page.canvas, bmp, items[i] ?: emptyList())
                    doc.finishPage(page)
                }
            } else {
                val bmp = loadBitmap(ctx, uri, 2000) ?: return null
                val page = doc.startPage(PdfDocument.PageInfo.Builder(bmp.width, bmp.height, ++n).create())
                page.canvas.drawBitmap(bmp, 0f, 0f, null)
                drawPlaced(page.canvas, bmp, items[0] ?: emptyList())
                doc.finishPage(page)
            }
            if (n == 0) return null
            val f = outFile(ctx, "Tenzy-signed")
            FileOutputStream(f).use { doc.writeTo(it) }
            return f
        } catch (_: Exception) {
            return null
        } finally { doc.close() }
    }

    // ------------------------------------------------------------------ merge / split / compress / rotate / images

    fun merge(ctx: Context, uris: List<Uri>): File? {
        if (uris.isEmpty()) return null
        val doc = PdfDocument(); var n = 0
        try {
            uris.forEach { uri ->
                try {
                    eachPage(ctx, uri, 2f) { bmp, _ ->
                        val page = doc.startPage(PdfDocument.PageInfo.Builder(bmp.width, bmp.height, ++n).create())
                        page.canvas.drawBitmap(bmp, 0f, 0f, null)
                        doc.finishPage(page)
                    }
                } catch (_: Exception) {}
            }
            if (n == 0) return null
            val f = outFile(ctx, "Tenzy-merged")
            FileOutputStream(f).use { doc.writeTo(it) }
            return f
        } catch (_: Exception) { return null } finally { doc.close() }
    }

    /** Pages (0-based) → one PDF; null → every page as its own PDF (capped at [maxFiles]). */
    fun split(ctx: Context, uri: Uri, pages: List<Int>?, maxFiles: Int = 30): List<File> {
        val out = ArrayList<File>()
        try {
            if (pages != null && pages.isNotEmpty()) {
                val want = pages.toSet()
                val doc = PdfDocument(); var n = 0
                eachPage(ctx, uri, 2f) { bmp, i ->
                    if (i in want) {
                        val page = doc.startPage(PdfDocument.PageInfo.Builder(bmp.width, bmp.height, ++n).create())
                        page.canvas.drawBitmap(bmp, 0f, 0f, null)
                        doc.finishPage(page)
                    }
                }
                if (n > 0) {
                    val f = outFile(ctx, "Tenzy-pages")
                    FileOutputStream(f).use { doc.writeTo(it) }
                    out += f
                }
                doc.close()
            } else {
                eachPage(ctx, uri, 2f) { bmp, i ->
                    if (out.size < maxFiles) {
                        val doc = PdfDocument()
                        val page = doc.startPage(PdfDocument.PageInfo.Builder(bmp.width, bmp.height, 1).create())
                        page.canvas.drawBitmap(bmp, 0f, 0f, null)
                        doc.finishPage(page)
                        val f = File(ctx.cacheDir, "Tenzy-page-${i + 1}-${System.currentTimeMillis()}.pdf")
                        FileOutputStream(f).use { doc.writeTo(it) }
                        doc.close()
                        out += f
                    }
                }
            }
        } catch (_: Exception) {}
        return out
    }

    fun compress(ctx: Context, uri: Uri): File? {
        val doc = PdfDocument(); var n = 0
        try {
            eachPage(ctx, uri, 1.3f) { bmp, _ ->
                val jpeg = ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.JPEG, 50, it) }.toByteArray()
                val small = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size) ?: return@eachPage
                val page = doc.startPage(PdfDocument.PageInfo.Builder(small.width, small.height, ++n).create())
                page.canvas.drawBitmap(small, 0f, 0f, null)
                doc.finishPage(page)
            }
            if (n == 0) return null
            val f = outFile(ctx, "Tenzy-small")
            FileOutputStream(f).use { doc.writeTo(it) }
            return f
        } catch (_: Exception) { return null } finally { doc.close() }
    }

    fun rotate(ctx: Context, uri: Uri, degrees: Int): File? {
        val doc = PdfDocument(); var n = 0
        try {
            eachPage(ctx, uri, 2f) { bmp, _ ->
                val m = Matrix().apply { postRotate(degrees.toFloat()) }
                val r = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
                val page = doc.startPage(PdfDocument.PageInfo.Builder(r.width, r.height, ++n).create())
                page.canvas.drawBitmap(r, 0f, 0f, null)
                doc.finishPage(page)
                if (r !== bmp) bmp.recycle()
            }
            if (n == 0) return null
            val f = outFile(ctx, "Tenzy-rotated")
            FileOutputStream(f).use { doc.writeTo(it) }
            return f
        } catch (_: Exception) { return null } finally { doc.close() }
    }

    fun toImages(ctx: Context, uri: Uri, max: Int = 20): List<File> {
        val out = ArrayList<File>()
        try {
            eachPage(ctx, uri, 2f) { bmp, i ->
                if (out.size < max) {
                    val f = File(ctx.cacheDir, "Tenzy-page-${i + 1}-${System.currentTimeMillis()}.jpg")
                    FileOutputStream(f).use { bmp.compress(Bitmap.CompressFormat.JPEG, 90, it) }
                    bmp.recycle()
                    out += f
                }
            }
        } catch (_: Exception) {}
        return out
    }

    /** "1-3, 5" → [0,1,2,4] clipped to [max]. Empty/garbage → empty list (meaning: every page). */
    fun parseRange(s: String, max: Int): List<Int> {
        val out = LinkedHashSet<Int>()
        s.split(",", ";", " ").map { it.trim() }.filter { it.isNotEmpty() }.forEach { part ->
            val m = Regex("""^(\d+)\s*[-–]\s*(\d+)$""").find(part)
            if (m != null) {
                val a = m.groupValues[1].toInt(); val b = m.groupValues[2].toInt()
                for (p in minOf(a, b)..maxOf(a, b)) if (p in 1..max) out += p - 1
            } else part.toIntOrNull()?.let { if (it in 1..max) out += it - 1 }
        }
        return out.toList()
    }

    fun prettySize(bytes: Long): String {
        if (bytes <= 0) return ""
        val kb = bytes / 1024.0
        return if (kb < 1024) "%.0f KB".format(kb) else "%.2f MB".format(kb / 1024)
    }
}
