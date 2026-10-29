package com.handytools.app.tools.power

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.net.Uri
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.TranslateRemoteModel
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.tasks.await
import java.util.Locale

/** One translated text block from a photo. */
data class OverlayLine(val original: String, val translated: String)

/** ML Kit on-device translation + the camera overlay. Models download once, then everything is offline. */
object TranslateEngine {
    data class Lang(val code: String, val name: String)

    /** Every language ML Kit can translate, by English display name. */
    val LANGS: List<Lang> by lazy {
        TranslateLanguage.getAllLanguages().map { Lang(it, displayName(it)) }.sortedBy { it.name }
    }

    private fun displayName(code: String): String {
        val n = Locale.forLanguageTag(code).getDisplayLanguage(Locale.ENGLISH)
        return (if (n.isBlank()) code else n).replaceFirstChar { it.uppercase() }
    }

    fun name(code: String): String = LANGS.firstOrNull { it.code == code }?.name ?: displayName(code)

    /** A sensible regional locale for speech + TTS, since ML Kit codes are bare ("es", "pt"). */
    fun locale(code: String): Locale = Locale.forLanguageTag(
        when (code) {
            "en" -> "en-US"; "es" -> "es-ES"; "pt" -> "pt-BR"; "zh" -> "zh-CN"; "fr" -> "fr-FR"; "de" -> "de-DE"
            "it" -> "it-IT"; "ja" -> "ja-JP"; "ko" -> "ko-KR"; "hi" -> "hi-IN"; "ar" -> "ar-SA"; "ru" -> "ru-RU"
            else -> code
        }
    )

    private fun mlCode(code: String): String = TranslateLanguage.fromLanguageTag(code) ?: TranslateLanguage.ENGLISH

    /** True when the pack for [code] is on the phone. English is the pivot and never needs one. */
    suspend fun isDownloaded(code: String): Boolean {
        if (code == "en") return true
        return try {
            RemoteModelManager.getInstance().isModelDownloaded(TranslateRemoteModel.Builder(mlCode(code)).build()).await()
        } catch (e: Exception) { false }
    }

    suspend fun bothDownloaded(src: String, tgt: String): Boolean = isDownloaded(src) && isDownloaded(tgt)

    /**
     * Translate [text] from [src] to [tgt]. Downloads the packs first if needed ([onDownloading] fires once
     * so the UI can show the progress state). Throws on failure — caller decides what to tell the user.
     */
    suspend fun translate(src: String, tgt: String, text: String, onDownloading: () -> Unit = {}): String {
        val opts = TranslatorOptions.Builder().setSourceLanguage(mlCode(src)).setTargetLanguage(mlCode(tgt)).build()
        val client = Translation.getClient(opts)
        try {
            if (!bothDownloaded(src, tgt)) onDownloading()
            client.downloadModelIfNeeded().await()
            return client.translate(text).await()
        } finally {
            client.close()
        }
    }

    /** Just fetch the packs, for the "Download for offline" button. */
    suspend fun download(src: String, tgt: String) {
        val opts = TranslatorOptions.Builder().setSourceLanguage(mlCode(src)).setTargetLanguage(mlCode(tgt)).build()
        val client = Translation.getClient(opts)
        try { client.downloadModelIfNeeded().await() } finally { client.close() }
    }

    /**
     * Recognise the text blocks in [bmp] (Latin script), translate each, and paint the translation over the
     * original block: dark rounded box + white text fitted to the block's bounding box. Returns the painted
     * copy plus the lines; an empty list means no readable text.
     */
    suspend fun translateImage(bmp: Bitmap, src: String, tgt: String, onDownloading: () -> Unit = {}): Pair<Bitmap, List<OverlayLine>> {
        val vt = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS).process(InputImage.fromBitmap(bmp, 0)).await()
        val blocks = vt.textBlocks.filter { it.boundingBox != null && it.text.isNotBlank() }
        if (blocks.isEmpty()) return bmp to emptyList()

        val opts = TranslatorOptions.Builder().setSourceLanguage(mlCode(src)).setTargetLanguage(mlCode(tgt)).build()
        val client = Translation.getClient(opts)
        val lines = ArrayList<OverlayLine>()
        try {
            if (!bothDownloaded(src, tgt)) onDownloading()
            client.downloadModelIfNeeded().await()
            for (b in blocks) {
                val original = b.text.replace('\n', ' ').trim()
                val translated = try { client.translate(original).await() } catch (e: Exception) { original }
                lines.add(OverlayLine(original, translated))
            }
        } finally { client.close() }

        val out = bmp.copy(Bitmap.Config.ARGB_8888, true)
        val canvas = Canvas(out)
        val bg = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xE0101018.toInt() }
        val tp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFFFFFFF.toInt() }
        val pad = (out.width * 0.006f).coerceAtLeast(3f)
        blocks.forEachIndexed { i, b ->
            val r: Rect = b.boundingBox ?: return@forEachIndexed
            val text = lines[i].translated
            val lineCount = b.lines.size.coerceAtLeast(1)
            val boxW = (r.width() - pad * 2).coerceAtLeast(8f)
            var textSize = (r.height().toFloat() / lineCount) * 0.78f
            textSize = textSize.coerceAtLeast(10f)
            var layout = fitLayout(text, tp, textSize, boxW.toInt())
            var tries = 0
            while (layout.height > r.height() + pad * 2 && tries < 5 && textSize > 9f) {
                textSize *= 0.82f
                layout = fitLayout(text, tp, textSize, boxW.toInt())
                tries++
            }
            val boxH = (layout.height + pad * 2).coerceAtLeast(r.height().toFloat())
            val box = RectF(r.left.toFloat(), r.top.toFloat(), r.right.toFloat(), r.top + boxH)
            canvas.drawRoundRect(box, pad * 2, pad * 2, bg)
            canvas.save()
            canvas.translate(r.left + pad, r.top + pad)
            layout.draw(canvas)
            canvas.restore()
        }
        return out to lines
    }

    private fun fitLayout(text: String, tp: TextPaint, size: Float, width: Int): StaticLayout {
        tp.textSize = size
        return StaticLayout.Builder.obtain(text, 0, text.length, tp, width.coerceAtLeast(1))
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(false)
            .build()
    }

    /** Decode a photo at most [maxSide] px on its long edge, EXIF-rotated so text is upright. */
    fun loadBitmap(ctx: Context, uri: Uri, maxSide: Int = 1600): Bitmap? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            var sample = 1
            while ((bounds.outWidth / sample) > maxSide * 2 || (bounds.outHeight / sample) > maxSide * 2) sample *= 2
            val opts = BitmapFactory.Options().apply { inSampleSize = sample }
            val decoded = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) } ?: return null
            val longest = maxOf(decoded.width, decoded.height)
            val scaled = if (longest > maxSide) {
                val f = maxSide.toFloat() / longest
                Bitmap.createScaledBitmap(decoded, (decoded.width * f).toInt().coerceAtLeast(1), (decoded.height * f).toInt().coerceAtLeast(1), true)
            } else decoded
            applyOrientation(ctx, uri, scaled)
        } catch (e: Exception) { null }
    }

    private fun applyOrientation(ctx: Context, uri: Uri, bmp: Bitmap): Bitmap {
        val orientation = runCatching {
            ctx.contentResolver.openInputStream(uri)?.use {
                ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            } ?: ExifInterface.ORIENTATION_NORMAL
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val m = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.postScale(1f, -1f)
            else -> return bmp
        }
        return runCatching { Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true) }.getOrDefault(bmp)
    }

    private const val PREFS = "translate_tool"
    fun savedPair(ctx: Context): Pair<String, String> {
        val p = ctx.getSharedPreferences(PREFS, 0)
        return (p.getString("from", "en") ?: "en") to (p.getString("to", "es") ?: "es")
    }
    fun savePair(ctx: Context, from: String, to: String) {
        ctx.getSharedPreferences(PREFS, 0).edit().putString("from", from).putString("to", to).apply()
    }
}
