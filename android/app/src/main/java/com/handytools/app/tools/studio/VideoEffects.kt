package com.handytools.app.tools.studio

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.graphics.Typeface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.Contrast
import androidx.media3.effect.HslAdjustment
import androidx.media3.effect.MatrixTransformation
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.RgbAdjustment
import androidx.media3.effect.RgbFilter
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import com.google.common.collect.ImmutableList
import com.handytools.app.tools.power.MediaEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Video Effects on Android (the iPhone's tool, its look, light, motion, texture and words): a look graded over the
 * whole video, a light laid on it, the picture moving (slow zoom, a punch on the beat of its own sound, handheld,
 * drift), a texture (film grain, VHS, cinema bars) and words that arrive the way you pick. Made on the phone with
 * Media3; the sound is kept. Pure parts (choices, timings, beats) are unit-tested.
 */
@androidx.annotation.OptIn(UnstableApi::class)
object VideoEffects {
    data class Choice(val id: String, val name: String, val emoji: String)

    val looks = listOf(
        Choice("none", "Original", "⚪️"), Choice("vivid", "Vivid", "🌈"), Choice("cinema", "Cinematic", "🎬"), Choice("golden", "Golden", "🌅"),
        Choice("dream", "Dreamy", "☁️"), Choice("retro", "Retro film", "📼"), Choice("noir", "Black & white", "🖤"), Choice("moon", "Moonlight", "🌙"),
        Choice("neon", "Neon", "💜"), Choice("sepia", "Vintage", "🟤"),
    )
    val lights = listOf(
        Choice("none", "None", "⚪️"), Choice("glow", "Glow", "✨"), Choice("leak", "Light leaks", "🔥"), Choice("sun", "Golden sun", "☀️"),
        Choice("flare", "Flare sweep", "💫"), Choice("vignette", "Vignette", "🔦"),
    )
    val motions = listOf(
        Choice("none", "Still", "⚪️"), Choice("zoom", "Slow zoom", "🔍"), Choice("pulse", "Beat punch", "🥁"),
        Choice("shake", "Handheld", "📳"), Choice("drift", "Drift", "🎞️"),
    )
    val textures = listOf(Choice("none", "Clean", "⚪️"), Choice("grain", "Film grain", "🎞️"), Choice("vhs", "VHS", "📼"), Choice("bars", "Cinema bars", "🎬"))
    val wordStyles = listOf(Choice("pop", "Pop", "💥"), Choice("slide", "Slide up", "⬆️"), Choice("fade", "Fade", "🌫️"), Choice("bounce", "Bounce", "🏀"))
    /** What goes behind the person (the iPhone's list): the person stays, the rest is swapped. */
    val backgrounds = listOf(
        Choice("none", "As filmed", "⚪️"), Choice("blur", "Portrait blur", "🌫️"), Choice("colorpop", "Colour pop", "🎨"), Choice("studio", "Studio", "🤍"),
        Choice("sunset", "Sunset", "🌇"), Choice("night", "Night city", "🌃"), Choice("pastel", "Pastel", "🩵"), Choice("photo", "Your photo", "🖼️"),
    )
    /** Every face and body effect (FaceFun), with "Off" first. */
    val funnies: List<Choice> = listOf(Choice("none", "Off", "⚪️")) + FaceFun.effects.map { Choice(it.id, it.name, it.emoji) }

    data class Recipe(val look: String = "none", val light: String = "none", val motion: String = "none", val texture: String = "none",
                      val words: String = "", val wordStyle: String = "pop", val background: String = "none", val funny: String = "none",
                      /** Their own photo behind them (background "photo"), the sound ("original", "none", "synth:<style>", "file") and
                       *  their own song, and with music on how much of the video's own sound stays (0 just music … 1 just the video). */
                      val backdrop: String? = null, val music: String = "original", val song: String? = null, val keep: Double = 0.25,
                      val amount: Float = 0.6f) {
        val isPlain: Boolean get() = look == "none" && light == "none" && motion == "none" && texture == "none" && words.isBlank() &&
            background == "none" && funny == "none" && music == "original"
    }

    // MARK: pure timings (the iPhone's)

    fun wobble(x: Double) = (sin(x) + 0.6 * sin(2.17 * x + 1.3) + 0.3 * sin(3.91 * x + 2.1)) / 1.9

    /** Beat times from loudness every [hop] seconds: where it jumps up clearly, at least 0.22 s apart. */
    fun beats(e: List<Double>, hop: Double): List<Double> {
        if (e.size <= 4) return emptyList()
        val flux = e.indices.map { i -> if (i == 0) 0.0 else max(0.0, e[i] - e[i - 1]) }
        val mean = flux.average()
        val sd = sqrt(flux.sumOf { (it - mean) * (it - mean) } / flux.size)
        if (sd <= 1e-6) return emptyList()
        val bar = mean + 1.2 * sd
        val out = mutableListOf<Double>(); var last = -1.0
        for (i in 1 until flux.size - 1) if (flux[i] > bar && flux[i] >= flux[i - 1] && flux[i] >= flux[i + 1]) {
            val t = i * hop
            if (t - last >= 0.22) { out += t; last = t }
        }
        return out
    }

    /** A steady beat (twice a second) for videos with no sound or nothing to dance to. */
    fun steady(duration: Double): List<Double> = generateSequence(0.25) { it + 0.5 }.takeWhile { it < max(0.25, duration) }.toList()

    /** How the words look at t: how see-through, how big, how far up (share of the height). */
    fun wordsMotion(style: String, t: Double): Triple<Double, Double, Double> {
        val s = max(0.0, t - 0.2)
        return when (style) {
            "fade" -> Triple(min(1.0, s / 0.7), 1.0, 0.0)
            "slide" -> { val p = min(1.0, s / 0.55); val e = 1 - (1 - p).pow(3); Triple(min(1.0, s / 0.3), 1.0, -0.08 * (1 - e)) }
            "bounce" -> {
                val p = min(1.0, s / 0.45)
                val pop = if (p < 1) 1.18 * sin(p * PI / 2) - 0.18 * sin(p * PI) else 1.0
                Triple(min(1.0, s / 0.2), pop, if (s > 0.45) 0.006 * sin((s - 0.45) * 4.2) else 0.0)
            }
            else -> { val p = min(1.0, s / 0.4); val scale = if (p < 1) 0.4 + 0.75 * p + 0.25 * sin(p * PI) * (1 - p) * 2 else 1.0; Triple(min(1.0, s / 0.15), min(1.2, scale), 0.0) }
        }
    }

    /** How the picture moves at t of duration: scale and nudge (fractions of the frame), never showing an edge. */
    fun motion(id: String, t: Double, duration: Double, beats: List<Double>, a: Double = 0.6): Triple<Double, Double, Double> {
        val p = if (duration > 0) (t / duration).coerceIn(0.0, 1.0) else 0.0
        var s = 1.0; var dx = 0.0; var dy = 0.0
        when (id) {
            "zoom" -> s = 1 + 0.16 * a * (p * p * (3 - 2 * p))
            "pulse" -> s = 1 + 0.11 * a * Reels.punch(t, beats)
            "shake" -> { s = 1 + 0.045 * a; dx = wobble(t * 7.3) * 0.014 * a; dy = wobble(t * 6.1 + 5) * 0.012 * a }
            "drift" -> { s = 1.06 + 0.08 * a; dx = (p * 2 - 1) * (s - 1) / 2 * 0.9 }
        }
        val slack = (s - 1) / 2
        return Triple(s, dx.coerceIn(-slack, slack), dy.coerceIn(-slack, slack))
    }

    // MARK: the effects

    fun look(id: String): List<Effect> = when (id) {
        "golden" -> listOf(RgbAdjustment.Builder().setRedScale(1.08f).setBlueScale(0.84f).build(), HslAdjustment.Builder().adjustSaturation(10f).adjustLightness(3f).build(), Contrast(0.1f))
        "retro" -> listOf(HslAdjustment.Builder().adjustSaturation(-22f).build(), RgbAdjustment.Builder().setRedScale(1.06f).setBlueScale(0.86f).build(), Contrast(-0.06f))
        "noir" -> listOf(RgbFilter.createGrayscaleFilter(), Contrast(0.25f))
        "moon" -> listOf(HslAdjustment.Builder().adjustSaturation(-25f).adjustLightness(-4f).build(), RgbAdjustment.Builder().setRedScale(0.86f).setGreenScale(0.95f).setBlueScale(1.1f).build())
        "sepia" -> listOf(RgbFilter.createGrayscaleFilter(), RgbAdjustment.Builder().setRedScale(1.12f).setGreenScale(0.98f).setBlueScale(0.78f).build(), Contrast(0.08f))
        else -> Reels.look(id)
    }

    private fun picture(w: Int, h: Int, draw: (Canvas, Paint) -> Unit): Bitmap =
        Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).also { draw(Canvas(it), Paint(Paint.ANTI_ALIAS_FLAG)) }

    /** A light as a full-frame picture at the video's size. */
    fun lightPicture(id: String, w: Int, h: Int): Bitmap? {
        val r = max(w, h).toFloat()
        val shader = when (id) {
            "vignette" -> RadialGradient(w / 2f, h / 2f, r * 0.62f, intArrayOf(Color.TRANSPARENT, Color.TRANSPARENT, Color.argb(150, 0, 0, 0)), floatArrayOf(0f, 0.55f, 1f), Shader.TileMode.CLAMP)
            "leak" -> RadialGradient(w * 0.05f, h * 0.08f, r * 0.55f, intArrayOf(Color.argb(110, 255, 140, 60), Color.TRANSPARENT), null, Shader.TileMode.CLAMP)
            "sun" -> RadialGradient(w * 0.8f, 0f, r * 0.7f, intArrayOf(Color.argb(120, 255, 200, 90), Color.TRANSPARENT), null, Shader.TileMode.CLAMP)
            "flare" -> android.graphics.LinearGradient(0f, 0f, w.toFloat(), h.toFloat(), intArrayOf(Color.TRANSPARENT, Color.argb(70, 255, 120, 255), Color.TRANSPARENT), floatArrayOf(0.3f, 0.5f, 0.7f), Shader.TileMode.CLAMP)
            "glow" -> RadialGradient(w / 2f, h * 0.4f, r * 0.7f, intArrayOf(Color.argb(45, 255, 240, 220), Color.TRANSPARENT), null, Shader.TileMode.CLAMP)
            else -> return null
        }
        return picture(w, h) { c, p -> p.shader = shader; c.drawRect(0f, 0f, w.toFloat(), h.toFloat(), p) }
    }

    /** Film grain: a few frames of fine noise, cycled. */
    private fun grain(w: Int, h: Int, seed: Long): Bitmap {
        val small = Bitmap.createBitmap(w / 2, h / 2, Bitmap.Config.ARGB_8888)
        val r = SeededRandom(seed)
        val px = IntArray(small.width * small.height) { val v = (r.next() * 255).toInt(); Color.argb(26, v, v, v) }
        small.setPixels(px, 0, small.width, 0, 0, small.width, small.height)
        return Bitmap.createScaledBitmap(small, w, h, false)
    }

    /** VHS: soft scan lines across the frame. */
    private fun scanLines(w: Int, h: Int): Bitmap = picture(w, h) { c, p ->
        p.color = Color.argb(40, 0, 0, 0)
        var y = 0f
        while (y < h) { c.drawRect(0f, y, w.toFloat(), y + 2f, p); y += 6f }
    }

    private fun bars(w: Int, h: Int): Bitmap = picture(w, h) { c, p ->
        p.color = Color.BLACK
        val bar = h * 0.09f
        c.drawRect(0f, 0f, w.toFloat(), bar, p); c.drawRect(0f, h - bar, w.toFloat(), h.toFloat(), p)
    }

    /** The words, bold and white with a dark edge, on a picture just big enough for them. */
    fun wordsPicture(text: String, w: Int): Bitmap {
        val size = w * 0.085f
        val fill = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textSize = size; color = Color.WHITE; setShadowLayer(size * 0.18f, 0f, size * 0.04f, Color.argb(140, 0, 0, 0)) }
        val edge = TextPaint(fill).apply { style = Paint.Style.STROKE; strokeWidth = size * 0.08f; color = Color.argb(160, 0, 0, 0); clearShadowLayer() }
        val width = (w * 0.88f).toInt()
        fun layout(p: TextPaint) = StaticLayout.Builder.obtain(text, 0, text.length, p, width).setAlignment(Layout.Alignment.ALIGN_CENTER).build()
        val l = layout(fill)
        val pad = (size * 0.6f).toInt()
        return Bitmap.createBitmap(width + pad * 2, l.height + pad * 2, Bitmap.Config.ARGB_8888).also { b ->
            val c = Canvas(b); c.translate(pad.toFloat(), pad.toFloat()); layout(edge).draw(c); l.draw(c)
        }
    }

    /** Why the music couldn't go in on the last make (the video then kept its own sound), for the screen to say. */
    @Volatile var lastSoundProblem: String? = null

    /** A photo picked for behind the person, upright and at most [maxSide] on its long side. */
    fun loadPhoto(ctx: Context, uri: Uri, maxSide: Int): Bitmap? = com.handytools.app.tools.autoruns.PhotoDays.small(ctx, uri, maxSide)

    /** The video's upright size, kept at most 1920 (or [maxSide]) on its long side. */
    fun size(ctx: Context, uri: Uri, maxSide: Int = 1920): Pair<Int, Int> {
        val (w0, h0) = runCatching {
            MediaMetadataRetriever().run {
                setDataSource(ctx, uri)
                val w = extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 1080
                val h = extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 1920
                val rot = extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
                release()
                if (rot % 180 != 0) h to w else w to h
            }
        }.getOrDefault(1080 to 1920)
        val k = min(1.0, maxSide.toDouble() / max(w0, h0))
        fun even(v: Double) = max(2, v.roundToInt().let { it - it % 2 })
        return even(w0 * k) to even(h0 * k)
    }

    /** The video with [r] on it. [preview] makes a short, smaller copy of the first seconds to watch before saving. */
    suspend fun make(ctx: Context, uri: Uri, r: Recipe, preview: Boolean = false, progress: (Double) -> Unit = {},
                     /** For the tests: the people already found (a drawn face the finder wouldn't see). */
                     given: People? = null): File? {
        val duration = MediaEngine.videoDurationMs(ctx, uri) / 1000.0
        if (duration <= 0.1) return null
        val (w, h) = size(ctx, uri, if (preview) 960 else 1920)
        val length = if (preview) min(duration, 6.0) else duration

        // The beats of its own sound, for the beat punch (a steady beat when there's nothing clear).
        val beats = if (r.motion == "pulse" && r.music.startsWith("synth:")) {
            Synth.track(r.music.removePrefix("synth:"), duration).beats
        } else if (r.motion == "pulse") {
            val local = FunnyMaker.local(ctx, uri)
            val sound = local?.let { FunnyMaker.sound(it) }
            val found = sound?.let { beats(FunnyPlan.loudness(it.first, it.second, 0.05), 0.05) } ?: emptyList()
            if (found.size >= 3) found else steady(duration)
        } else emptyList()

        // The sound first: made as one file so the music (and how much of the video's own sound stays) is exactly what's saved.
        val sound = VideoSound.build(ctx, uri, r.music, r.song?.let { Uri.parse(it) }, r.keep, length)

        val item = MediaItem.Builder().setUri(uri).apply {
            if (preview) setClippingConfiguration(MediaItem.ClippingConfiguration.Builder().setEndPositionMs((length * 1000).toLong()).build())
        }.build()
        val video = mutableListOf<Effect>(Presentation.createForWidthAndHeight(w, h, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP))
        // Behind the person and funny faces first, on the clean picture (the iPhone's order): the people are found
        // once, a few times a second, then the GPU follows them frame by frame.
        val people = r.background != "none" || r.funny != "none"
        val share = if (people) 0.3 else 0.0
        var found: People? = null
        if (people) {
            found = given ?: People.find(ctx, uri, length, masks = r.background != "none" || FaceFun.needsMask(r.funny), faces = r.funny != "none") { p -> progress(p * share) }
            val photo = if (r.background == "photo") r.backdrop?.let { withContext(Dispatchers.IO) { loadPhoto(ctx, Uri.parse(it), 1600) } } else null
            if (found != null && r.background != "none") video += PeopleEffect(found, r.background, "none", r.amount, photo)
            if (found != null && r.funny != "none") video += FaceFunEffect(found, r.funny, r.amount)
        }
        video += look(r.look)
        if (r.texture == "vhs") video += HslAdjustment.Builder().adjustSaturation(-12f).build()
        if (r.motion != "none") video += MatrixTransformation { us ->
            val (s, dx, dy) = motion(r.motion, us / 1e6, duration, beats)
            Matrix().apply { setScale(s.toFloat(), s.toFloat()); postTranslate((dx * 2).toFloat(), (dy * 2).toFloat()) }
        }
        val layers = mutableListOf<TextureOverlay>()
        // The face stickers, drawn by Tenzy on every frame where the faces are.
        found?.let { f -> if (r.funny != "none") layers += StickerOverlay(f, r.funny, w, h) }
        lightPicture(r.light, w, h)?.let { layers += BitmapOverlay.createStaticBitmapOverlay(it) }
        when (r.texture) {
            "grain" -> { val frames = (0 until 4).map { grain(w, h, 7L + it) }; layers += TimedOverlay({ t -> frames[((t * 24).toInt()) % 4] to 1f }) }
            "vhs" -> layers += BitmapOverlay.createStaticBitmapOverlay(scanLines(w, h))
            "bars" -> layers += BitmapOverlay.createStaticBitmapOverlay(bars(w, h))
        }
        val words = r.words.trim()
        if (words.isNotEmpty()) {
            val pic = withContext(Dispatchers.Default) { wordsPicture(words, w) }
            layers += TimedOverlay(
                { t -> wordsMotion(r.wordStyle, t).first.takeIf { it > 0 }?.let { pic to it.toFloat() } },
                { t -> wordsMotion(r.wordStyle, t).second.toFloat() },
                { t -> 0f to (0.68 + wordsMotion(r.wordStyle, t).third * 2).toFloat() },   // near the top, like the iPhone; "lift" raises it
            )
        }
        if (layers.isNotEmpty()) video += OverlayEffect(ImmutableList.copyOf(layers))

        val edited = EditedMediaItem.Builder(item).setEffects(Effects(emptyList(), video)).setRemoveAudio(r.music != "original").build()
        val out = File(File(ctx.cacheDir, "effects").also { it.mkdirs() }, (if (preview) "preview-" else "Tenzy video ") + System.currentTimeMillis() + ".mp4")
        val sequences = mutableListOf(EditedMediaItemSequence(listOf(edited)))
        sound.file?.let { f ->
            val clip = MediaItem.Builder().setUri(Uri.fromFile(f)).setClippingConfiguration(
                MediaItem.ClippingConfiguration.Builder().setEndPositionMs((length * 1000).toLong()).build()).build()
            sequences += EditedMediaItemSequence(listOf(EditedMediaItem.Builder(clip).build()))
        }
        val ok = Reels.export(ctx, Composition.Builder(sequences).build(), out) { p -> progress(share + (1 - share) * p) }
        sound.file?.delete()
        lastSoundProblem = sound.problem
        return if (ok && out.length() > 0) out else { out.delete(); null }
    }

}
