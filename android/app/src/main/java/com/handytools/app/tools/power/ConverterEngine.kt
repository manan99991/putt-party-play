package com.handytools.app.tools.power

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.Transformer
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.pdmodel.PDPageContentStream
import com.tom_roush.pdfbox.pdmodel.common.PDRectangle
import com.tom_roush.pdfbox.pdmodel.graphics.image.JPEGFactory
import java.io.File

/**
 * The engine behind the Universal Converter. Pure logic, no Compose — meant to run off the main
 * thread (image/PDF work) or to hand back a running Media3 [Transformer] the screen polls for
 * progress (audio/video). Everything stays on the phone; nothing is uploaded.
 *
 * It classifies the picked file by reusing [FileViewer.probe] (content first, extension second) and
 * then offers only the conversions that genuinely work for that type — best-effort, never a
 * dead-end. HEIC/HEIF input is decoded with [ImageDecoder] so it can become a normal JPEG/PNG.
 */
object ConverterEngine {

    enum class Category { IMAGE, PDF, AUDIO, VIDEO, OTHER }

    /** The user-facing output formats for a picture. */
    enum class ImageFormat(val label: String, val ext: String, val mime: String) {
        PNG("PNG", "png", "image/png"),
        JPEG("JPEG", "jpg", "image/jpeg"),
        WEBP("WEBP", "webp", "image/webp"),
    }

    data class Src(val uri: Uri, val name: String, val category: Category, val typeLabel: String)

    fun humanSize(bytes: Long): String = FileViewer.humanSize(bytes)

    /** Strip the extension so we can name the output after the input ("photo.heic" -> "photo"). */
    fun baseName(name: String): String = name.substringBeforeLast('.', name).ifBlank { "converted" }

    /** Identify the picked file. Safe to call off the main thread. */
    fun inspect(ctx: Context, uri: Uri): Src {
        val m = runCatching { FileViewer.probe(ctx, uri) }.getOrNull()
        val category = when (m?.kind) {
            FileViewer.Kind.IMAGE -> Category.IMAGE
            FileViewer.Kind.PDF -> Category.PDF
            FileViewer.Kind.AUDIO -> Category.AUDIO
            FileViewer.Kind.VIDEO -> Category.VIDEO
            else -> Category.OTHER
        }
        val name = m?.name ?: FileViewer.displayName(ctx, uri)
        return Src(uri, name, category, m?.typeLabel ?: "File")
    }

    // ---------------- images ----------------

    /**
     * Decode any still image to a software bitmap we can re-compress. [ImageDecoder] (API 28+) reads
     * HEIC/HEIF and the usual formats; older phones fall back to the shared Documents decoder. We
     * force a software allocation so [Bitmap.compress] works (a hardware bitmap can't be encoded).
     */
    fun decodeBitmap(ctx: Context, uri: Uri): Bitmap? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            runCatching {
                val source = ImageDecoder.createSource(ctx.contentResolver, uri)
                return ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                    decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                    decoder.isMutableRequired = false
                }
            }
        }
        return DocEngine.loadBitmap(ctx, uri, 4096)
    }

    @Suppress("DEPRECATION")
    private fun compressFormat(fmt: ImageFormat): Bitmap.CompressFormat = when (fmt) {
        ImageFormat.PNG -> Bitmap.CompressFormat.PNG
        ImageFormat.JPEG -> Bitmap.CompressFormat.JPEG
        ImageFormat.WEBP ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) Bitmap.CompressFormat.WEBP_LOSSY
            else Bitmap.CompressFormat.WEBP
    }

    /** JPEG has no alpha — flatten transparency onto white so it doesn't come out black. */
    private fun flattenIfNeeded(src: Bitmap, fmt: ImageFormat): Bitmap {
        if (fmt != ImageFormat.JPEG || !src.hasAlpha()) return src
        val out = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        canvas.drawColor(Color.WHITE)
        canvas.drawBitmap(src, 0f, 0f, null)
        return out
    }

    private fun scaleDown(src: Bitmap, maxEdge: Int): Bitmap {
        val longest = maxOf(src.width, src.height)
        if (longest <= maxEdge) return src
        val ratio = maxEdge.toFloat() / longest
        return Bitmap.createScaledBitmap(src, (src.width * ratio).toInt().coerceAtLeast(1), (src.height * ratio).toInt().coerceAtLeast(1), true)
    }

    /** Convert one image to [fmt]. Quality is ignored for PNG (lossless). Returns a cache file. */
    fun convertImage(ctx: Context, uri: Uri, fmt: ImageFormat, quality: Int): File? {
        val decoded = decodeBitmap(ctx, uri) ?: return null
        val bmp = flattenIfNeeded(decoded, fmt)
        val out = File(ctx.cacheDir, "Converted-${System.currentTimeMillis()}.${fmt.ext}")
        return try {
            out.outputStream().use { bmp.compress(compressFormat(fmt), quality.coerceIn(1, 100), it) }
            out
        } catch (_: Throwable) { null }
    }

    /** Combine the picked images, in order, into a single PDF (one image per page) via PDFBox. */
    fun imagesToPdf(ctx: Context, uris: List<Uri>, jpegQuality: Int = 85): File? {
        if (uris.isEmpty()) return null
        if (!pdfboxReady) { PDFBoxResourceLoader.init(ctx.applicationContext); pdfboxReady = true }
        val doc = PDDocument()
        return try {
            for (u in uris) {
                val raw = decodeBitmap(ctx, u) ?: continue
                val bmp = flattenIfNeeded(scaleDown(raw, 2200), ImageFormat.JPEG)
                val page = PDPage(PDRectangle(bmp.width.toFloat(), bmp.height.toFloat()))
                doc.addPage(page)
                val img = JPEGFactory.createFromImage(doc, bmp, jpegQuality.coerceIn(1, 100) / 100f)
                PDPageContentStream(doc, page).use { it.drawImage(img, 0f, 0f, bmp.width.toFloat(), bmp.height.toFloat()) }
            }
            if (doc.numberOfPages == 0) return null
            val out = File(ctx.cacheDir, "Converted-${System.currentTimeMillis()}.pdf")
            doc.save(out)
            out
        } catch (_: Throwable) { null } finally { runCatching { doc.close() } }
    }

    @Volatile private var pdfboxReady = false

    // ---------------- PDF -> images ----------------

    /** Render every PDF page to an image file (PNG or JPEG). [targetWidth] px wide at page aspect. */
    fun pdfToImages(ctx: Context, uri: Uri, fmt: ImageFormat, quality: Int, targetWidth: Int = 1654): List<File> {
        val out = ArrayList<File>()
        try {
            ctx.contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
                PdfRenderer(pfd).use { renderer ->
                    for (i in 0 until renderer.pageCount) {
                        renderer.openPage(i).use { page ->
                            val w = targetWidth
                            val h = (w.toFloat() / page.width * page.height).toInt().coerceAtLeast(1)
                            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                            bmp.eraseColor(Color.WHITE)
                            page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            val f = File(ctx.cacheDir, "Page-${i + 1}-${System.currentTimeMillis()}.${fmt.ext}")
                            f.outputStream().use { bmp.compress(compressFormat(fmt), quality.coerceIn(1, 100), it) }
                            out.add(f)
                        }
                    }
                }
            }
        } catch (_: Throwable) { /* return whatever rendered */ }
        return out
    }

    // ---------------- audio / video (Media3 Transformer) ----------------

    /**
     * Pull/transcode the audio track to AAC in an .m4a container. Returns the running [Transformer];
     * call this on a thread with a Looper (the main thread) and poll `getProgress` from there.
     */
    @UnstableApi
    fun startAudioExport(ctx: Context, uri: Uri, out: File, listener: Transformer.Listener): Transformer {
        val edited = EditedMediaItem.Builder(MediaItem.fromUri(uri)).setRemoveVideo(true).build()
        val transformer = Transformer.Builder(ctx).setAudioMimeType(MimeTypes.AUDIO_AAC).addListener(listener).build()
        transformer.start(edited, out.absolutePath)
        return transformer
    }

    /**
     * Transcode to an H.264 MP4, optionally scaling down to [height] px (null keeps the original
     * resolution). Returns the running [Transformer] — same threading note as [startAudioExport].
     */
    @UnstableApi
    fun startVideoExport(ctx: Context, uri: Uri, height: Int?, out: File, listener: Transformer.Listener): Transformer {
        val effects = if (height != null && height > 0) Effects(emptyList(), listOf(Presentation.createForHeight(height)))
        else Effects(emptyList(), emptyList())
        val edited = EditedMediaItem.Builder(MediaItem.fromUri(uri)).setEffects(effects).build()
        val transformer = Transformer.Builder(ctx).setVideoMimeType(MimeTypes.VIDEO_H264).addListener(listener).build()
        transformer.start(edited, out.absolutePath)
        return transformer
    }
}
