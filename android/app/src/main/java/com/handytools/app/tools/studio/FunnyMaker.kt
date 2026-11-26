package com.handytools.app.tools.studio

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Typeface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.MatrixTransformation
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.RgbFilter
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import com.google.common.collect.ImmutableList
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.handytools.app.tools.power.FileTranscriber
import com.handytools.app.tools.power.MediaEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.coroutines.resume
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Funny Moments on Android (the iPhone's): the video with its moment in — the picture stopped where the joke says
 * (made grey for the record scratch and the crickets), the zoom, shake, bounce and flash from FunnyPlan, the words on
 * the freeze, the sound kept and the joke's own sound on top. Made on the phone with Media3; nothing leaves it.
 */
@androidx.annotation.OptIn(UnstableApi::class)
object FunnyMaker {
    private fun dir(ctx: Context) = File(ctx.cacheDir, "funny").also { it.mkdirs() }

    /** A copy of the video in the app's cache (Android's audio reader wants a file). */
    suspend fun local(ctx: Context, uri: Uri): File? = withContext(Dispatchers.IO) {
        if (uri.scheme == "file") return@withContext uri.path?.let { File(it) }
        val f = File(dir(ctx), "source-${System.nanoTime()}.mp4")
        runCatching { ctx.contentResolver.openInputStream(uri)?.use { i -> f.outputStream().use { i.copyTo(it) } } }
        if (f.length() > 0) f else { f.delete(); null }
    }

    /** The video's sound as mono samples and their rate, or null when it has none. */
    suspend fun sound(file: File): Pair<FloatArray, Int>? = withContext(Dispatchers.IO) {
        val (pcm, rate) = FileTranscriber.monoPcm(file) ?: return@withContext null
        try {
            val b = pcm.readBytes(); val bb = ByteBuffer.wrap(b).order(ByteOrder.LITTLE_ENDIAN)
            FloatArray(b.size / 2) { bb.getShort(it * 2) / 32768f } to rate
        } finally { pcm.delete() }
    }

    /** Where the moment is, found for you: the loudest laugh or shout (60% in when there's no sound). */
    suspend fun findMoment(ctx: Context, uri: Uri, kind: String): Pair<Double, Double>? {
        val f = local(ctx, uri) ?: return null
        val duration = MediaEngine.videoDurationMs(ctx, Uri.fromFile(f)) / 1000.0
        val s = sound(f)
        val loud = s?.let { FunnyPlan.loudness(it.first, it.second) } ?: emptyList()
        return FunnyPlan.moment(loud, 0.05, duration, kind) to duration
    }

    private fun even(v: Int) = max(2, v - v % 2)

    /** The video with the moment in. Null if the phone couldn't make it. */
    suspend fun make(ctx: Context, source: Uri, kindId: String, at: Double?, words: String?, progress: (Double) -> Unit = {}): File? {
        val k = FunnyPlan.kind(kindId)
        val src = local(ctx, source) ?: return null
        val srcUri = Uri.fromFile(src)
        val duration = MediaEngine.videoDurationMs(ctx, srcUri) / 1000.0
        if (duration < 0.5) return null
        val sound = sound(src)
        val t = (at ?: FunnyPlan.moment(sound?.let { FunnyPlan.loudness(it.first, it.second) } ?: emptyList(), 0.05, duration, kindId))
            .coerceIn(0.0, duration - 1.0 / 30)
        progress(0.05)

        // The frame at the moment: its size sets the output's, and its face is where the zoom goes.
        val still = withContext(Dispatchers.IO) {
            runCatching { MediaMetadataRetriever().run { setDataSource(src.absolutePath); val b = getFrameAtTime((t * 1e6).toLong(), MediaMetadataRetriever.OPTION_CLOSEST); release(); b } }.getOrNull()
        } ?: return null
        val scale = min(1f, 1920f / max(still.width, still.height))
        val w = even((still.width * scale).roundToInt()); val h = even((still.height * scale).roundToInt())
        val focus = faceFocus(still)
        val frame = Presentation.createForWidthAndHeight(w, h, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP)

        // The edit: up to the moment, the stopped frame, the rest (ba-dum-tss ends on its freeze).
        val items = mutableListOf<EditedMediaItem>()
        fun piece(from: Double, to: Double) {
            if (to - from < 0.05) return
            val clip = MediaItem.Builder().setUri(srcUri).setClippingConfiguration(MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs((from * 1000).toLong()).setEndPositionMs((to * 1000).toLong()).build()).build()
            items += EditedMediaItem.Builder(clip).setRemoveAudio(true).setEffects(Effects(emptyList(), listOf(frame))).build()
        }
        piece(0.0, t)
        if (k.freeze > 0) {
            val png = File(dir(ctx), "still-${System.nanoTime()}.png")
            withContext(Dispatchers.IO) { png.outputStream().use { still.compress(Bitmap.CompressFormat.PNG, 100, it) } }
            val fx = mutableListOf<Effect>()
            if (kindId != "rimshot") fx += RgbFilter.createGrayscaleFilter()
            fx += frame
            val stopped = MediaItem.Builder().setUri(Uri.fromFile(png)).setImageDurationMs((k.freeze * 1000).toLong()).build()
            // A still made into frames first, so the edit is all video.
            val clip = File(dir(ctx), "still-${System.nanoTime()}.mp4")
            val ok = Reels.export(ctx, Composition.Builder(listOf(EditedMediaItemSequence(listOf(
                EditedMediaItem.Builder(stopped).setFrameRate(30).setEffects(Effects(emptyList(), fx)).build())))).build(), clip) { }
            png.delete()
            if (!ok) return null
            items += EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(clip))).setRemoveAudio(true).setEffects(Effects(emptyList(), listOf(frame))).build()
        }
        if (kindId != "rimshot") piece(t, duration)
        val total = t + k.freeze + if (kindId != "rimshot") duration - t else 0.0
        progress(0.2)

        // The sound: the video's own, silent through the freeze, the joke's sound at the moment.
        val music = File(dir(ctx), "sound-${System.nanoTime()}.wav")
        withContext(Dispatchers.Default) {
            val out = FloatArray((total * Synth.RATE).toInt() + 1)
            sound?.let { (x, r) ->
                val ratio = r / Synth.RATE
                fun put(fromS: Double, toS: Double, atS: Double) {
                    val n = ((toS - fromS) * Synth.RATE).toInt()
                    for (i in 0 until n) {
                        val p = (fromS * Synth.RATE + i) * ratio; val a = p.toInt()
                        if (a + 1 >= x.size) break
                        val j = (atS * Synth.RATE).toInt() + i
                        if (j < out.size) out[j] = x[a] + (x[a + 1] - x[a]) * (p - a).toFloat()
                    }
                }
                put(0.0, t, 0.0)
                if (kindId != "rimshot") put(t, duration, t + k.freeze)
            }
            Synth.mix(Synth.effect(k.sound), out, t, 0.9f)
            music.writeBytes(Synth.wav(out))
        }

        // The picture's moves (toward the face), then the flash and the words.
        val freeze = k.freeze
        val move = MatrixTransformation { us ->
            val l = FunnyPlan.look(kindId, us / 1e6 - t, freeze)
            val z = max(1.0, l.zoom).toFloat()
            Matrix().apply {
                setScale(z * (2 - l.squash).toFloat(), z * l.squash.toFloat(), focus.first * 2 - 1, 1 - focus.second * 2)
                postTranslate((l.dx * 2).toFloat(), (-l.dy * 2).toFloat())
            }
        }
        val white = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.WHITE) }
        val said = (words ?: k.words).trim()
        val caption = if (freeze > 0 && said.isNotEmpty()) caption(said, w, h) else null
        val layers = listOfNotNull(
            TimedOverlay({ s -> FunnyPlan.look(kindId, s - t, freeze).flash.takeIf { it > 0 }?.let { white to it.toFloat() } }),
            caption?.let { cap -> TimedOverlay({ s -> FunnyPlan.look(kindId, s - t, freeze).words.takeIf { it > 0 }?.let { cap to it.toFloat() } }) },
        )
        val composition = Composition.Builder(listOf(
            EditedMediaItemSequence(items),
            EditedMediaItemSequence(listOf(EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(music))).build())),
        )).setEffects(Effects(emptyList(), listOf<Effect>(move, OverlayEffect(ImmutableList.copyOf<androidx.media3.effect.TextureOverlay>(layers))))).build()
        val out = File(dir(ctx), "Tenzy funny ${System.currentTimeMillis()}.mp4")
        val ok = Reels.export(ctx, composition, out) { p -> progress(0.2 + 0.8 * p) }
        music.delete()
        progress(1.0)
        return if (ok && out.length() > 0) out else { out.delete(); null }
    }

    /** Where to zoom: the biggest face (0…1 across and down), or the middle a little high. */
    private suspend fun faceFocus(b: Bitmap): Pair<Float, Float> = withTimeoutOrNull(4_000L) {
        suspendCancellableCoroutine<Pair<Float, Float>> { cont ->
            val fallback = 0.5f to 0.42f
            runCatching {
                FaceDetection.getClient().process(InputImage.fromBitmap(b, 0))
                    .addOnSuccessListener { faces ->
                        val f = faces.maxByOrNull { it.boundingBox.width() }
                        if (cont.isActive) cont.resume(f?.let { it.boundingBox.exactCenterX() / b.width to it.boundingBox.exactCenterY() / b.height } ?: fallback)
                    }
                    .addOnFailureListener { if (cont.isActive) cont.resume(fallback) }
            }.onFailure { if (cont.isActive) cont.resume(fallback) }
        }
    } ?: (0.5f to 0.42f)

    /** The words on the freeze, low on the frame, white with a dark edge so they read on anything. */
    fun caption(text: String, w: Int, h: Int): Bitmap {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val size = w * 0.075f
        val fill = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textSize = size; color = Color.WHITE; setShadowLayer(size * 0.18f, 0f, size * 0.04f, Color.argb(140, 0, 0, 0)) }
        val edge = TextPaint(fill).apply { style = Paint.Style.STROKE; strokeWidth = size * 0.08f; color = Color.argb(160, 0, 0, 0); clearShadowLayer() }
        val width = (w * 0.88f).toInt()
        fun layout(p: TextPaint) = StaticLayout.Builder.obtain(text, 0, text.length, p, width).setAlignment(Layout.Alignment.ALIGN_CENTER).build()
        val c = Canvas(bmp)
        val l = layout(fill)
        c.translate((w - width) / 2f, h * 0.82f - l.height / 2f)
        layout(edge).draw(c); l.draw(c)
        return bmp
    }
}
