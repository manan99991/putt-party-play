package com.handytools.app.tools.studio

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Typeface
import android.net.Uri
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.MatrixTransformation
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.OverlaySettings
import androidx.media3.effect.Presentation
import androidx.media3.effect.SpeedChangeEffect
import androidx.media3.effect.StaticOverlaySettings
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import com.google.common.collect.ImmutableList
import com.handytools.app.I18n
import com.handytools.app.tools.power.MediaEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.math.abs

/**
 * Movie Trailer on Android (the iPhone's): your clips and photos as a half-minute trailer — black title cards with a
 * deep narrator, slow motion, quicker cuts, a montage that builds, the title on a huge hit, "Coming soon". The score
 * is Tenzy's own (TrailerPlan + Synth) and the narrator is the phone's own text-to-speech voice, low and slow —
 * never a real person's voice. Made on the phone with Media3.
 */
@androidx.annotation.OptIn(UnstableApi::class)
object TrailerMaker {
    fun defaultLines(): List<String> = listOf(I18n.t("In a world where anything can happen…"), I18n.t("One story was waiting to be told."), I18n.t("This year, get ready for…"))

    private fun dir(ctx: Context) = File(ctx.cacheDir, "trailers").also { it.mkdirs() }

    // MARK: the narrator

    private suspend fun engine(ctx: Context): TextToSpeech? = withContext(Dispatchers.Main) {
        withTimeoutOrNull(8_000L) {
            suspendCancellableCoroutine<TextToSpeech?> { cont ->
                val holder = arrayOfNulls<TextToSpeech>(1)
                holder[0] = TextToSpeech(ctx.applicationContext) { status ->
                    val t = holder[0]
                    if (status == TextToSpeech.SUCCESS) { if (cont.isActive) cont.resume(t) else t?.shutdown() }
                    else { t?.shutdown(); if (cont.isActive) cont.resume(null) }
                }
            }
        }
    }

    /** Each line spoken low and slow by the phone's own voice, deepened and given a hall, as samples at Synth.RATE. */
    suspend fun narrate(ctx: Context, lines: List<String>): List<FloatArray> {
        val tts = engine(ctx) ?: return lines.map { FloatArray(0) }
        return try {
            tts.setPitch(0.62f); tts.setSpeechRate(0.82f)
            lines.map { line -> deepen(speakToSamples(ctx, tts, line)) }
        } finally { runCatching { tts.shutdown() } }
    }

    private suspend fun speakToSamples(ctx: Context, tts: TextToSpeech, text: String): Pair<FloatArray, Int>? {
        if (text.isBlank()) return null
        val f = File(dir(ctx), "line-${System.nanoTime()}.wav")
        val id = UUID.randomUUID().toString()
        val ok = withContext(Dispatchers.Main) {
            withTimeoutOrNull(20_000L) {
                suspendCancellableCoroutine<Boolean> { cont ->
                    tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(utteranceId: String?) {}
                        override fun onDone(utteranceId: String?) { if (utteranceId == id && cont.isActive) cont.resume(true) }
                        @Deprecated("Deprecated in Java")
                        override fun onError(utteranceId: String?) { if (utteranceId == id && cont.isActive) cont.resume(false) }
                        override fun onError(utteranceId: String?, errorCode: Int) { if (utteranceId == id && cont.isActive) cont.resume(false) }
                    })
                    if (tts.synthesizeToFile(text, Bundle(), f, id) != TextToSpeech.SUCCESS && cont.isActive) cont.resume(false)
                }
            } ?: false
        }
        return try { if (ok) withContext(Dispatchers.IO) { readWav(f.readBytes()) } else null } finally { f.delete() }
    }

    /** Mono samples and the rate of a plain PCM .wav file. Null if it isn't one. */
    fun readWav(b: ByteArray): Pair<FloatArray, Int>? {
        if (b.size < 44 || String(b, 0, 4) != "RIFF" || String(b, 8, 4) != "WAVE") return null
        val bb = ByteBuffer.wrap(b).order(ByteOrder.LITTLE_ENDIAN)
        var p = 12; var rate = 0; var channels = 1; var bits = 16
        while (p + 8 <= b.size) {
            val id = String(b, p, 4); val len = bb.getInt(p + 4)
            if (id == "fmt ") { channels = bb.getShort(p + 10).toInt().coerceAtLeast(1); rate = bb.getInt(p + 12); bits = bb.getShort(p + 22).toInt() }
            if (id == "data") {
                if (bits != 16 || rate <= 0) return null
                val n = (minOf(len, b.size - p - 8) / 2) / channels
                return FloatArray(n) { i -> var s = 0f; for (c in 0 until channels) s += bb.getShort(p + 8 + (i * channels + c) * 2) / 32768f; s / channels } to rate
            }
            p += 8 + len + (len and 1)
        }
        return null
    }

    /** To the music's rate, then the trailer sound: more chest, a little edge, a big hall. */
    fun deepen(said: Pair<FloatArray, Int>?): FloatArray {
        val (raw, r) = said ?: return FloatArray(0)
        if (raw.size < r / 10) return FloatArray(0)
        val ratio = r / Synth.RATE
        val n = (raw.size / ratio).toInt()
        var y = FloatArray(n) { i -> val x = i * ratio; val a = x.toInt(); val f = (x - a).toFloat(); if (a + 1 < raw.size) raw[a] * (1 - f) + raw[a + 1] * f else raw[minOf(a, raw.size - 1)] }
        y = Dsp.filter(y, "lowshelf", 140.0, gainDB = 6.0, rate = Synth.RATE)
        y = Dsp.filter(y, "peak", 2800.0, q = 1.0, gainDB = 3.0, rate = Synth.RATE)
        y = Dsp.drive(y, 1.3f)
        y = Dsp.echoes(y, listOf(0.11, 0.19), 0.22f, Synth.RATE)
        return Dsp.level(y)
    }

    // MARK: the cards

    /** A card's words on a clear full frame: tall serif capitals, spaced wide, softly glowing (warm gold for the title). */
    fun card(text: String, title: Boolean, end: Boolean): Bitmap {
        val bmp = Bitmap.createBitmap(Reels.W, Reels.H, Bitmap.Config.ARGB_8888)
        val words = text.trim().uppercase()
        if (words.isEmpty()) return bmp
        val size = Reels.W * if (title) 0.12f else if (end) 0.06f else 0.062f
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
            textSize = size; letterSpacing = 0.12f
            color = if (title) Color.rgb(255, 237, 199) else Color.rgb(242, 242, 242)
            setShadowLayer(size * 0.5f, 0f, 0f, Color.argb(if (title) 190 else 115, 255, 217, 140))
        }
        val width = (Reels.W * 0.84f).toInt()
        val layout = StaticLayout.Builder.obtain(words, 0, words.length, paint, width).setAlignment(Layout.Alignment.ALIGN_CENTER)
            .setLineSpacing(size * 0.25f, 1f).build()
        val c = Canvas(bmp)
        c.translate((Reels.W - width) / 2f, (Reels.H - layout.height) / 2f)
        layout.draw(c)
        return bmp
    }

    /** One picture laid over the video, changing with time: [pick] gives the picture and how see-through, [scaleAt] how big. */
    private class Timed(private val pick: (Double) -> Pair<Bitmap, Float>?, private val scaleAt: (Double) -> Float = { 1f }) : BitmapOverlay() {
        private val clear = Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888)
        override fun getBitmap(presentationTimeUs: Long): Bitmap = pick(presentationTimeUs / 1e6)?.first ?: clear
        override fun getOverlaySettings(presentationTimeUs: Long): OverlaySettings {
            val t = presentationTimeUs / 1e6
            val a = pick(t)?.second ?: 0f
            val s = scaleAt(t)
            return StaticOverlaySettings.Builder().setAlphaScale(a.coerceIn(0f, 1f)).setScale(s, s).build()
        }
    }

    private fun solid(color: Int): Bitmap = Bitmap.createBitmap(Reels.W, Reels.H, Bitmap.Config.ARGB_8888).apply { eraseColor(color) }

    /** Black frames the length of the longest card, to sit under the cards (the cards are drawn over them). */
    private suspend fun blackClip(ctx: Context, seconds: Double): File? {
        val png = File(dir(ctx), "black-${System.nanoTime()}.png")
        withContext(Dispatchers.IO) { png.outputStream().use { solid(Color.BLACK).compress(Bitmap.CompressFormat.PNG, 100, it) } }
        val item = MediaItem.Builder().setUri(Uri.fromFile(png)).setImageDurationMs((seconds * 1000).toLong() + 200).build()
        val edited = EditedMediaItem.Builder(item).setFrameRate(30)
            .setEffects(Effects(emptyList(), listOf(Presentation.createForWidthAndHeight(Reels.W, Reels.H, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP)))).build()
        val out = File(dir(ctx), "black-${System.nanoTime()}.mp4")
        val ok = Reels.export(ctx, Composition.Builder(listOf(EditedMediaItemSequence(listOf(edited)))).build(), out) { }
        png.delete()
        return if (ok && out.length() > 0) out else { out.delete(); null }
    }

    // MARK: making it

    /** The trailer from [sources] (videos; photos already made into clips) with [lines] on the cards and [title]. */
    suspend fun make(ctx: Context, sources: List<Uri>, title: String, lines: List<String>, progress: (Double) -> Unit = {}): File? {
        val found = sources.map { it to MediaEngine.videoDurationMs(ctx, it) / 1000.0 }.filter { it.second > 0.2 }
        if (found.isEmpty()) return null
        val ps = TrailerPlan.parts()
        val name = title.trim().ifEmpty { I18n.t("The Adventure") }
        val defaults = defaultLines()
        val spoken = (0 until 3).map { i -> lines.getOrNull(i)?.trim()?.ifEmpty { null } ?: defaults[i] } + listOf(name, I18n.t("Coming soon"))
        progress(0.02)

        // The sound: the score with the narrator on top, as long as the trailer.
        val voices = narrate(ctx, spoken)
        progress(0.1)
        val total = ps.last().end
        val music = File(dir(ctx), "score-${System.nanoTime()}.wav")
        withContext(Dispatchers.Default) {
            val sound = TrailerPlan.score(ps)
            TrailerPlan.cues(ps).forEach { (at, line) -> TrailerPlan.mixVoice(voices[line], sound, at) }
            music.writeBytes(Synth.wav(Dsp.level(sound).copyOf((total * Synth.RATE).toInt())))
        }

        // The pictures: black under each card, the clips (slow, quick, montage) everywhere else, upright and tall.
        val black = blackClip(ctx, ps.filter { it.isCard }.maxOf { it.length }) ?: return null
        val srcs = found.map { it.first }
        val cuts = TrailerPlan.cuts(ps, found.map { it.second })
        val cardIdx = ps.filter { it.isCard }
        var ci = 0
        val tall = Presentation.createForWidthAndHeight(Reels.W, Reels.H, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP)
        val items = cuts.map { c ->
            if (c.length < 0.05) {
                val len = cardIdx[ci++].length
                val clip = MediaItem.Builder().setUri(Uri.fromFile(black))
                    .setClippingConfiguration(MediaItem.ClippingConfiguration.Builder().setStartPositionMs(0).setEndPositionMs((len * 1000).toLong()).build()).build()
                EditedMediaItem.Builder(clip).setRemoveAudio(true).setEffects(Effects(emptyList(), listOf(tall))).build()
            } else {
                val clip = MediaItem.Builder().setUri(srcs[c.clip])
                    .setClippingConfiguration(MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs((c.from * 1000).toLong()).setEndPositionMs(((c.from + c.length) * 1000).toLong()).build()).build()
                val fx = mutableListOf<Effect>()
                val speed = c.length / c.lasts
                if (abs(speed - 1) > 0.01) fx += SpeedChangeEffect(speed.toFloat())
                fx += tall
                EditedMediaItem.Builder(clip).setRemoveAudio(true).setEffects(Effects(emptyList(), fx)).build()
            }
        }

        // Over it all: the cinema look on the shots, a punch on every hit, then the cards' black and words, then the flash.
        val hits = TrailerPlan.hits(ps)
        val titleAt = ps.first { it.kind == TrailerPlan.Kind.TITLE }.start
        fun cardAt(t: Double) = cardIdx.firstOrNull { t >= it.start && t < it.end }
        val pictures = cardIdx.associateWith { p ->
            card(when (p.kind) { TrailerPlan.Kind.TITLE -> spoken[3]; TrailerPlan.Kind.END -> spoken[4]; else -> spoken[p.line ?: 0] },
                p.kind == TrailerPlan.Kind.TITLE, p.kind == TrailerPlan.Kind.END)
        }
        val blackFrame = solid(Color.BLACK); val white = solid(Color.rgb(255, 247, 230))
        val punch = MatrixTransformation { us ->
            val t = us / 1e6
            val s = if (cardAt(t) != null) 1f else (1 + 0.11 * 0.65 * Reels.punch(t, hits)).toFloat()
            Matrix().apply { setScale(s, s) }
        }
        val layers = mutableListOf<TextureOverlay>()
        Reels.lightPicture("vignette")?.let { layers += BitmapOverlay.createStaticBitmapOverlay(it) }
        layers += BitmapOverlay.createStaticBitmapOverlay(Reels.barsPicture())
        layers += Timed({ t -> if (cardAt(t) != null) blackFrame to 1f else null })
        layers += Timed({ t ->
            cardAt(t)?.let { p ->
                val l = TrailerPlan.cardLook(t - p.start, p.length, p.kind == TrailerPlan.Kind.TITLE, p.kind == TrailerPlan.Kind.END)
                pictures.getValue(p) to l.first.toFloat()
            }
        }, { t -> cardAt(t)?.let { p -> TrailerPlan.cardLook(t - p.start, p.length, p.kind == TrailerPlan.Kind.TITLE, p.kind == TrailerPlan.Kind.END).second.toFloat() } ?: 1f })
        layers += Timed({ t -> TrailerPlan.flash(t, hits, titleAt).takeIf { it > 0 }?.let { white to it.toFloat() } })

        val composition = Composition.Builder(listOf(
            EditedMediaItemSequence(items),
            EditedMediaItemSequence(listOf(EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(music))).build())),
        )).setEffects(Effects(emptyList(), Reels.look("cinema") + listOf<Effect>(punch, OverlayEffect(ImmutableList.copyOf(layers))))).build()
        val out = File(dir(ctx), "Tenzy trailer ${System.currentTimeMillis()}.mp4")
        val ok = Reels.export(ctx, composition, out) { p -> progress(0.15 + 0.85 * p) }
        music.delete(); black.delete()
        progress(1.0)
        return if (ok && out.length() > 0) out else { out.delete(); null }
    }
}
