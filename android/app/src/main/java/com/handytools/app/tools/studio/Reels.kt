package com.handytools.app.tools.studio

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.Contrast
import androidx.media3.effect.HslAdjustment
import androidx.media3.effect.MatrixTransformation
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.RgbAdjustment
import androidx.media3.effect.SpeedChangeEffect
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import com.google.common.collect.ImmutableList
import com.handytools.app.tools.power.MediaEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import kotlin.coroutines.resume
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Beat Reel on Android (the iPhone's BeatReel): a few clips and photos become one tall reel cut to the beat of
 * Tenzy's own music — every cut on a beat, whole bars, a slow-motion moment where the music drops, a punch on every
 * beat, the style's look on top, and the last shot slowing while the final hit rings. Made on the phone with
 * Android's own video tools (Media3); the music is Tenzy's own (Synth), so the reel can be posted anywhere.
 */
@androidx.annotation.OptIn(UnstableApi::class)
object Reels {
    const val W = 1080
    const val H = 1920
    /** How long the last shot carries on after the final beat, while the music's last hit rings. */
    const val RING_OUT = 0.8

    /** One piece of the reel: which clip, where in it, how long in the clip and how long in the reel. */
    data class Cut(val clip: Int, val from: Double, val length: Double, val lasts: Double) {
        val slow: Boolean get() = lasts > length * 1.2
    }

    /**
     * How the reel is cut — the iPhone's plan exactly: 60% of what was given (12–60 s) in whole bars, cuts on beats,
     * every clip taking turns with its turns spread through it, one slow-motion moment at the first cut of bar two.
     */
    fun plan(lengths: List<Double>, style: Synth.Style, seconds: Double? = null): Pair<List<Cut>, Double> {
        if (lengths.none { it > 0.2 }) return emptyList<Cut>() to 0.0
        val beat = 60 / style.bpm; val bar = beat * 4; val cutLen = beat * style.beatsPerCut
        val want = seconds ?: min(60.0, max(12.0, lengths.sum() * 0.6))
        val bars = max(2, (want / bar).roundToInt())
        val total = bars * bar
        val count = (total / cutLen).roundToInt()
        val slowAt = (bar / cutLen).roundToInt()
        val uses = IntArray(lengths.size)
        val order = (0 until count).map { i -> (i % lengths.size).also { uses[it]++ } }
        val seen = IntArray(lengths.size)
        val cuts = order.mapIndexed { i, c ->
            val slow = i == slowAt && count > slowAt + 1
            val need = if (slow) cutLen / 2 else cutLen
            val len = min(need, max(0.1, lengths[c]))
            val margin = min(0.4, max(0.0, (lengths[c] - len) / 4))
            val room = max(0.0, lengths[c] - len - 2 * margin)
            val from = margin + room * (seen[c] + 0.5) / max(1, uses[c])
            seen[c]++
            Cut(c, from, len, cutLen)
        }
        return cuts to total
    }

    /** The punch on a beat: 1 right on it, fading over a tenth of a second. Pure. */
    fun punch(t: Double, beats: List<Double>): Double {
        var e = 0.0
        for (b in beats) if (b <= t && t - b < 0.6) e = max(e, exp(-(t - b) / 0.11))
        return e
    }

    private fun dir(ctx: Context) = File(ctx.cacheDir, "reels").also { it.mkdirs() }

    /** A photo as a 3-second tall clip with a slow push-in, so it can sit in a reel with the videos. */
    suspend fun photoClip(ctx: Context, uri: Uri): File? {
        val item = MediaItem.Builder().setUri(uri).setImageDurationMs(3000).build()
        val push = MatrixTransformation { us -> val s = (1 + 0.08 * (us / 3e6).coerceIn(0.0, 1.0)).toFloat(); Matrix().apply { setScale(s, s) } }
        val edited = EditedMediaItem.Builder(item).setFrameRate(30)
            .setEffects(Effects(emptyList(), listOf(Presentation.createForWidthAndHeight(W, H, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP), push))).build()
        val out = File(dir(ctx), "photo-${System.nanoTime()}.mp4")
        val ok = export(ctx, Composition.Builder(listOf(EditedMediaItemSequence(listOf(edited)))).build(), out) { }
        return if (ok && out.length() > 0) out else { out.delete(); null }
    }

    /** The reel from [sources] (videos; photos are made into clips first). Null if the phone couldn't make it. */
    suspend fun make(ctx: Context, sources: List<Uri>, styleId: String, seconds: Double? = null, progress: (Double) -> Unit = {}): File? {
        val st = Synth.style(styleId)
        val found = sources.map { it to MediaEngine.videoDurationMs(ctx, it) / 1000.0 }.filter { it.second > 0.2 }
        if (found.isEmpty()) return null
        val (cuts, total) = plan(found.map { it.second }, st, seconds)
        if (cuts.isEmpty()) return null
        progress(0.03)

        // The music, exactly as long as the reel.
        val track = withContext(Dispatchers.Default) { Synth.track(st.id, total) }
        val all = total + RING_OUT
        val music = File(dir(ctx), "music-${System.nanoTime()}.wav")
        withContext(Dispatchers.IO) { music.writeBytes(Synth.wav(track.samples.copyOf((all * Synth.RATE).toInt()))) }

        // Every cut in turn, upright and filling the tall frame; the slow moment stretched; the last one slowing
        // into the ring-out.
        val items = cuts.mapIndexed { i, c ->
            val lasts = c.lasts + if (i == cuts.lastIndex) RING_OUT else 0.0
            val clip = MediaItem.Builder().setUri(found[c.clip].first)
                .setClippingConfiguration(MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs((c.from * 1000).toLong()).setEndPositionMs(((c.from + c.length) * 1000).toLong()).build()).build()
            val fx = mutableListOf<Effect>()
            val speed = c.length / lasts
            if (abs(speed - 1) > 0.01) fx += SpeedChangeEffect(speed.toFloat())
            fx += Presentation.createForWidthAndHeight(W, H, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP)
            EditedMediaItem.Builder(clip).setRemoveAudio(true).setEffects(Effects(emptyList(), fx)).build()
        }
        val sound = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(music))).build()
        // The style over it all: its look and light, and a punch on every beat of the music.
        val beats = track.beats
        val hit = MatrixTransformation { us -> val s = (1 + 0.11 * 0.55 * punch(us / 1e6, beats)).toFloat(); Matrix().apply { setScale(s, s) } }
        val composition = Composition.Builder(listOf(EditedMediaItemSequence(items), EditedMediaItemSequence(listOf(sound))))
            .setEffects(Effects(emptyList(), look(st.look) + listOf<Effect>(hit) + light(st.light, st.id == "epic")))
            .build()
        val out = File(dir(ctx), "Tenzy reel ${System.currentTimeMillis()}.mp4")
        val ok = export(ctx, composition, out) { p -> progress(0.05 + 0.95 * p) }
        music.delete()
        progress(1.0)
        return if (ok && out.length() > 0) out else { out.delete(); null }
    }

    /** A style's colour: vivid, neon, dreamy or cinematic, as Android's own colour effects. */
    fun look(id: String): List<Effect> = when (id) {
        "vivid" -> listOf(HslAdjustment.Builder().adjustSaturation(25f).build(), Contrast(0.12f))
        "neon" -> listOf(HslAdjustment.Builder().adjustSaturation(35f).build(), RgbAdjustment.Builder().setRedScale(1.06f).setGreenScale(0.94f).setBlueScale(1.12f).build(), Contrast(0.18f))
        "dream" -> listOf(HslAdjustment.Builder().adjustSaturation(-8f).adjustLightness(6f).build(), RgbAdjustment.Builder().setRedScale(1.04f).setBlueScale(0.98f).build(), Contrast(-0.08f))
        "cinema" -> listOf(HslAdjustment.Builder().adjustSaturation(-12f).build(), RgbAdjustment.Builder().setRedScale(1.05f).setGreenScale(1.0f).setBlueScale(0.96f).build(), Contrast(0.2f))
        else -> emptyList()
    }

    /** A style's light, drawn once as a full-frame picture laid over the video: a warm leak, a flare, a glow or a vignette (with cinema bars for epic). */
    fun light(id: String, bars: Boolean): List<Effect> {
        val layers = mutableListOf<TextureOverlay>()
        lightPicture(id)?.let { layers += BitmapOverlay.createStaticBitmapOverlay(it) }
        if (bars) layers += BitmapOverlay.createStaticBitmapOverlay(barsPicture())
        return if (layers.isEmpty()) emptyList() else listOf(OverlayEffect(ImmutableList.copyOf(layers)))
    }

    fun lightPicture(id: String): Bitmap? {
        val bmp = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp); val p = Paint(Paint.ANTI_ALIAS_FLAG)
        when (id) {
            "vignette" -> p.shader = RadialGradient(W / 2f, H / 2f, H * 0.62f, intArrayOf(Color.TRANSPARENT, Color.TRANSPARENT, Color.argb(150, 0, 0, 0)), floatArrayOf(0f, 0.55f, 1f), Shader.TileMode.CLAMP)
            "leak" -> p.shader = RadialGradient(W * 0.05f, H * 0.08f, H * 0.55f, intArrayOf(Color.argb(110, 255, 140, 60), Color.TRANSPARENT), null, Shader.TileMode.CLAMP)
            "flare" -> p.shader = LinearGradient(0f, 0f, W.toFloat(), H.toFloat(), intArrayOf(Color.TRANSPARENT, Color.argb(70, 255, 120, 255), Color.TRANSPARENT), floatArrayOf(0.3f, 0.5f, 0.7f), Shader.TileMode.CLAMP)
            "glow" -> p.shader = RadialGradient(W / 2f, H * 0.4f, H * 0.7f, intArrayOf(Color.argb(45, 255, 240, 220), Color.TRANSPARENT), null, Shader.TileMode.CLAMP)
            else -> return null
        }
        c.drawRect(0f, 0f, W.toFloat(), H.toFloat(), p)
        return bmp
    }

    /** Black bars above and below, like a film. */
    fun barsPicture(): Bitmap {
        val bmp = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp); val p = Paint().apply { color = Color.BLACK }
        val bar = H * 0.09f
        c.drawRect(0f, 0f, W.toFloat(), bar, p); c.drawRect(0f, H - bar, W.toFloat(), H.toFloat(), p)
        return bmp
    }

    /** Runs one export to the end, reporting 0…1 as it goes. False if the phone refuses it or it takes over 20 minutes. */
    suspend fun export(ctx: Context, composition: Composition, out: File, progress: (Double) -> Unit): Boolean = withContext(Dispatchers.Main) {
        withTimeoutOrNull(20 * 60_000L) {
            suspendCancellableCoroutine<Boolean> { cont ->
                val ticker = Handler(Looper.getMainLooper())
                val listener = object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) { ticker.removeCallbacksAndMessages(null); if (cont.isActive) cont.resume(true) }
                    override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) { ticker.removeCallbacksAndMessages(null); if (cont.isActive) cont.resume(false) }
                }
                val t = try {
                    Transformer.Builder(ctx).setVideoMimeType(MimeTypes.VIDEO_H264).setAudioMimeType(MimeTypes.AUDIO_AAC).addListener(listener).build()
                } catch (_: Throwable) { cont.resume(false); return@suspendCancellableCoroutine }
                cont.invokeOnCancellation { ticker.removeCallbacksAndMessages(null); runCatching { t.cancel() } }
                try { t.start(composition, out.absolutePath) } catch (_: Throwable) { if (cont.isActive) cont.resume(false); return@suspendCancellableCoroutine }
                val holder = ProgressHolder()
                ticker.post(object : Runnable {
                    override fun run() {
                        if (!cont.isActive) return
                        if (t.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) progress(holder.progress / 100.0)
                        ticker.postDelayed(this, 300)
                    }
                })
            }
        } ?: false
    }
}
