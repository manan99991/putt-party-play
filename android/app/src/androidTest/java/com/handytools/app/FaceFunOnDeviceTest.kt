package com.handytools.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.handytools.app.tools.studio.FaceEngine
import com.handytools.app.tools.studio.FaceFun
import com.handytools.app.tools.studio.FaceSpot
import com.handytools.app.tools.studio.FunnyMaker
import com.handytools.app.tools.studio.People
import com.handytools.app.tools.studio.Reels
import com.handytools.app.tools.studio.Spot
import com.handytools.app.tools.studio.VideoEffects
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * The Video Studio on a real Android device (27 Nov): every face and body effect put on a video for real, proved on
 * its pixels — it changes the face and (unless it's a whole-picture mood) leaves the far corner alone — first on a
 * drawn face with known points (the pictures are saved to look at; a drawing, never a real photo), then on the private
 * real photos (numbers only). And the music: Tenzy's own music is under the whole saved video; "No sound" has none.
 */
@RunWith(AndroidJUnit4::class)
class FaceFunOnDeviceTest {
    private val ctx: Context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private val W = 720; private val H = 960

    private fun frame(f: File, t: Double): Bitmap = MediaMetadataRetriever().run {
        setDataSource(f.absolutePath)
        val b = getFrameAtTime((t * 1e6).toLong(), MediaMetadataRetriever.OPTION_CLOSEST)!!
        release(); b
    }

    private fun diff(a: Bitmap, b: Bitmap, x0: Float, y0: Float, x1: Float, y1: Float): Double {
        var s = 0.0; var n = 0
        val bb = if (b.width != a.width || b.height != a.height) Bitmap.createScaledBitmap(b, a.width, a.height, true) else b
        for (y in (y0.coerceIn(0f, 1f) * a.height).toInt() until (y1.coerceIn(0f, 1f) * a.height).toInt() step 3)
            for (x in (x0.coerceIn(0f, 1f) * a.width).toInt() until (x1.coerceIn(0f, 1f) * a.width).toInt() step 3) {
                val p = a.getPixel(x, y); val q = bb.getPixel(x, y)
                s += (abs(Color.red(p) - Color.red(q)) + abs(Color.green(p) - Color.green(q)) + abs(Color.blue(p) - Color.blue(q))) / 3.0; n++
            }
        return if (n > 0) s / n else 0.0
    }

    /** A still picture as a 3-second clip (no movement, so the face stays exactly where it was drawn). */
    private fun still(b: Bitmap, name: String): File {
        val pic = File(ctx.cacheDir, "$name.png").also { f -> f.outputStream().use { b.compress(Bitmap.CompressFormat.PNG, 100, it) } }
        val item = MediaItem.Builder().setUri(Uri.fromFile(pic)).setImageDurationMs(3000).build()
        val edited = EditedMediaItem.Builder(item).setFrameRate(30)
            .setEffects(Effects(emptyList(), listOf(Presentation.createForWidthAndHeight(b.width, b.height, Presentation.LAYOUT_SCALE_TO_FIT)))).build()
        val out = File(ctx.cacheDir, "$name.mp4")
        val ok = runBlocking { Reels.export(ctx, Composition.Builder(listOf(EditedMediaItemSequence(listOf(edited)))).build(), out) { } }
        assertTrue("the still clip couldn't be made", ok && out.length() > 0)
        return out
    }

    /** The drawn head and shoulders (the iPhone test's drawing, y down), and where the person is. */
    private fun drawing(mask: Boolean): Bitmap {
        val b = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        val c = Canvas(b); val p = Paint(Paint.ANTI_ALIAS_FLAG)
        fun col(r: Int, g: Int, bl: Int) = if (mask) Color.WHITE else Color.rgb(r, g, bl)
        if (mask) c.drawColor(Color.BLACK) else {
            c.drawColor(Color.rgb(158, 199, 230))
            p.color = Color.rgb(102, 148, 191); p.strokeWidth = 3f
            for (x in 0..W step 60) c.drawLine(x.toFloat(), 0f, x.toFloat(), H.toFloat(), p)
            for (y in 0..H step 60) c.drawLine(0f, y.toFloat(), W.toFloat(), y.toFloat(), p)
        }
        fun oval(x: Float, yUp: Float, w: Float, h: Float, colour: Int) { p.color = colour; p.style = Paint.Style.FILL; c.drawOval(RectF(x, H - yUp - h, x + w, H - yUp), p) }
        oval(110f, -260f, 500f, 600f, col(51, 115, 89))
        p.color = col(219, 168, 138); c.drawRect(318f, H - 430f, 402f, H - 300f, p)
        oval(236f, 470f, 248f, 400f, col(56, 36, 26))
        oval(262f, 400f, 196f, 440f, col(237, 189, 158))
        c.save(); c.clipRect(0f, 0f, W.toFloat(), H - 742f); oval(250f, 420f, 220f, 436f, col(56, 36, 26)); c.restore()
        if (!mask) {
            p.color = Color.rgb(51, 31, 20); p.strokeWidth = 7f; p.strokeCap = Paint.Cap.ROUND
            for (x in listOf(300f, 420f)) c.drawLine(x - 26, H - 640f, x + 26, H - 644f, p)
            for (x in listOf(300f, 420f)) { oval(x - 24, 588f, 48f, 24f, Color.WHITE); oval(x - 10, 590f, 20f, 20f, Color.rgb(51, 89, 153)) }
            p.color = Color.rgb(179, 128, 107); p.strokeWidth = 5f
            c.drawLine(360f, H - 600f, 350f, H - 545f, p); c.drawLine(350f, H - 545f, 372f, H - 540f, p)
            oval(310f, 466f, 100f, 28f, Color.rgb(199, 77, 82))
        }
        return b
    }

    /** The drawn face, as the finder would give it (fractions, y down). */
    private fun drawnPeople(): People {
        val f = FaceSpot(0.5f, 400f / H, 320f / W, listOf(Spot(300f / W, 360f / H), Spot(420f / W, 360f / H)), 0f, Spot(0.5f, 480f / H), Spot(355f / W, 418f / H))
        val m = Bitmap.createScaledBitmap(drawing(true), 180, 240, true)
        val bytes = ByteArray(180 * 240) { i -> Color.red(m.getPixel(i % 180, i / 180)).toByte() }
        val count = 26
        return People(1.0 / 8, 180, 240, List(count) { bytes }, List(count) { listOf(f) })
    }

    /**
     * The same clip through the Studio with nothing chosen: every saved video is a fresh encode, which moves flat colour
     * by a point or so everywhere, so each effect is measured against this — the same encode without the effect — not
     * against the original clip.
     */
    private fun baseline(clip: File, people: People? = null): Bitmap {
        // With people: the same face pass with nothing chosen ("plainpass" is no effect), so only the effect differs.
        val r = if (people != null) VideoEffects.Recipe(funny = "plainpass") else VideoEffects.Recipe()
        val out = runBlocking { VideoEffects.make(ctx, Uri.fromFile(clip), r, given = people) } ?: throw AssertionError("the plain re-save couldn't be made")
        return frame(out, 1.0).also { out.delete() }
    }

    /** A small whole person (the drawn head and shoulders at 40 %, with a body and legs below), for Long legs. */
    private fun wholeBody(): Bitmap {
        val b = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        val c = Canvas(b); val p = Paint(Paint.ANTI_ALIAS_FLAG)
        c.drawColor(Color.rgb(158, 199, 230))
        p.color = Color.rgb(102, 148, 191); p.strokeWidth = 3f
        for (x in 0..W step 60) c.drawLine(x.toFloat(), 0f, x.toFloat(), H.toFloat(), p)
        for (y in 0..H step 60) c.drawLine(0f, y.toFloat(), W.toFloat(), y.toFloat(), p)
        c.drawBitmap(Bitmap.createScaledBitmap(drawing(false), 288, 384, true), 216f, 0f, null)
        p.color = Color.rgb(51, 115, 89); c.drawRect(270f, 370f, 450f, 560f, p)
        p.color = Color.rgb(40, 52, 90); c.drawRect(282f, 560f, 352f, 930f, p); c.drawRect(368f, 560f, 438f, 930f, p)
        p.color = Color.rgb(30, 30, 30); c.drawRect(272f, 920f, 356f, 950f, p); c.drawRect(364f, 920f, 448f, 950f, p)
        return b
    }

    private fun onePerson(f: FaceSpot): People = People(1.0 / 8, 180, 240, List(26) { ByteArray(180 * 240) }, List(26) { listOf(f) })

    @Test fun everyFaceEffectOnADrawnFace() {
        val pic = drawing(false)
        val clip = still(pic, "facefun-drawn")
        val people = drawnPeople()
        val plain = baseline(clip, people)
        println("FACEFUN|drawn|pipeline|corner ${"%.1f".format(diff(baseline(clip), plain, 0f, 1f - 80f / H, 80f / W, 1f))}")
        val shots = mutableListOf("As filmed" to plain)
        val failures = mutableListOf<String>()
        for (e in FaceFun.effects) {
            if (e.id == "longlegs") continue
            val out = runBlocking { VideoEffects.make(ctx, Uri.fromFile(clip), VideoEffects.Recipe(funny = e.id, amount = 0.7f), given = people) }
            if (out == null) { failures += "${e.id}: not made"; continue }
            val f = frame(out, 1.0)
            val head = diff(plain, f, 180f / W, 40f / H, 540f / W, 600f / H)
            val corner = diff(plain, f, 0f, 1f - 80f / H, 80f / W, 1f)
            println("FACEFUN|drawn|${e.id}|head ${"%.1f".format(head)}|corner ${"%.1f".format(corner)}")
            if (head < 0.8) failures += "${e.id} did nothing to the face ($head)"
            if (e.id !in FaceFun.wholePicture && corner > 0.8) failures += "${e.id} changed the far corner ($corner)"
            shots += e.name to f
            out.delete()
        }
        // Long legs needs legs in the shot: a small whole person, legs drawn longer, the head left where it was.
        run {
            val body = still(wholeBody(), "facefun-body")
            val face0 = FaceSpot(0.5f, 160f / H, 128f / W, listOf(Spot(336f / W, 144f / H), Spot(384f / W, 144f / H)), 0f, Spot(0.5f, 192f / H), Spot(358f / W, 167f / H))
            val before = baseline(body, onePerson(face0))
            val face = FaceSpot(0.5f, 160f / H, 128f / W, listOf(Spot(336f / W, 144f / H), Spot(384f / W, 144f / H)), 0f, Spot(0.5f, 192f / H), Spot(358f / W, 167f / H))
            val out = runBlocking { VideoEffects.make(ctx, Uri.fromFile(body), VideoEffects.Recipe(funny = "longlegs", amount = 0.7f), given = onePerson(face)) }
            if (out == null) { failures += "longlegs: not made"; return@run }
            val f = frame(out, 1.0); out.delete()
            val legs = diff(before, f, 0f, 0.55f, 1f, 1f)
            println("FACEFUN|drawn|longlegs|legs ${"%.1f".format(legs)}")
            if (legs < 0.8) failures += "long legs changed nothing ($legs)"
            shots += "Long legs (before)" to before
            shots += "Long legs" to f
        }
        // Stickers land where they belong: shades on the eyes, a crown above the head, a moustache under the nose.
        fun shot(name: String) = shots.first { it.first == name }.second
        val eyes = diff(plain, shot("Cool shades"), 250f / W, 330f / H, 470f / W, 390f / H)
        val crown = diff(plain, shot("Crown"), 280f / W, 40f / H, 440f / W, 160f / H)
        val tache = diff(plain, shot("Moustache"), 310f / W, 428f / H, 410f / W, 464f / H)
        println("FACEFUN|drawn|stickers|shades on eyes ${"%.1f".format(eyes)}|crown above ${"%.1f".format(crown)}|moustache ${"%.1f".format(tache)}")
        if (eyes < 30) failures += "the shades aren't on the eyes ($eyes)"
        if (crown < 15) failures += "the crown isn't above the head ($crown)"
        if (tache < 30) failures += "the moustache isn't under the nose ($tache)"
        sheets(shots, "facefun")
        assertTrue(failures.joinToString("; "), failures.isEmpty())
    }

    /** Sheets of twelve (four across) with names, in the app's files for the workflow to pull. A drawing only. */
    private fun sheets(shots: List<Pair<String, Bitmap>>, name: String) {
        val dir = File(ctx.filesDir, "facefun").also { it.mkdirs() }
        val cw = 270; val ch = 360; val label = 30
        shots.chunked(12).forEachIndexed { page, part ->
            val rows = (part.size + 3) / 4
            val sheet = Bitmap.createBitmap(cw * 4, (ch + label) * rows, Bitmap.Config.ARGB_8888)
            val c = Canvas(sheet); c.drawColor(Color.WHITE)
            val p = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { textSize = 20f; color = Color.BLACK; isFakeBoldText = true }
            part.forEachIndexed { i, (n, b) ->
                val x = (i % 4) * cw; val y = (i / 4) * (ch + label)
                c.drawBitmap(b, null, RectF(x.toFloat(), y.toFloat(), (x + cw).toFloat(), (y + ch).toFloat()), p)
                c.drawText(n, x + 6f, y + ch + 22f, p)
            }
            File(dir, "$name-${page + 1}.jpg").outputStream().use { sheet.compress(Bitmap.CompressFormat.JPEG, 85, it) }
        }
    }

    @Test fun everyFaceEffectOnRealFaces() {
        val ui = InstrumentationRegistry.getInstrumentation().uiAutomation
        val names = android.os.ParcelFileDescriptor.AutoCloseInputStream(ui.executeShellCommand("ls /data/local/tmp/real")).bufferedReader().readText()
            .lines().map { it.trim() }.filter { n -> listOf(".jpg", ".jpeg", ".png").any { n.lowercase().endsWith(it) } }.sorted()
        assumeTrue("no private photos", names.isNotEmpty())
        var tried = 0
        for (n in names) {
            if (tried >= 1) break
            val local = File(ctx.cacheDir, "real-$n")
            android.os.ParcelFileDescriptor.AutoCloseInputStream(ui.executeShellCommand("cat /data/local/tmp/real/$n")).use { i -> local.outputStream().use { i.copyTo(it) } }
            val opts = BitmapFactory.Options().apply { inSampleSize = 4 }
            val small = BitmapFactory.decodeFile(local.path, opts) ?: continue
            val k = min(1f, 900f / max(small.width, small.height))
            val pic = Bitmap.createScaledBitmap(small, ((small.width * k).toInt() / 2) * 2, ((small.height * k).toInt() / 2) * 2, true)
            val face = runCatching { Tasks.await(FaceDetection.getClient().process(InputImage.fromBitmap(pic, 0))) }.getOrNull().orEmpty().maxByOrNull { it.boundingBox.width() }?.boundingBox ?: continue
            if (face.width() < pic.width * 0.12) continue
            tried++
            val clip = still(pic, "facefun-real")
            local.delete()
            // What the face engine sees on it (numbers only), found once and used for every effect.
            val found = runBlocking { People.find(ctx, Uri.fromFile(clip), 3.0, masks = true, faces = true, parts = true, fill = true) }
            val plain = baseline(clip, found)
            val spot = found?.facesAt(1.0)?.firstOrNull()
            println("FACEFUN|real|photo${tried + 0}|finder|faces ${found?.facesAt(1.0)?.size ?: -1}|x ${"%.2f".format(spot?.x ?: -1f)} vs ${"%.2f".format((face.left + face.right) / 2f / pic.width)}" +
                "|y ${"%.2f".format(spot?.y ?: -1f)} vs ${"%.2f".format((face.top + face.bottom) / 2f / pic.height)}|size ${"%.2f".format(spot?.size ?: -1f)} vs ${"%.2f".format(face.width() / pic.width.toFloat())}" +
                "|eyes ${spot?.eyes?.size ?: -1}|mouth ${spot?.mouth != null}")
            val fx0 = face.left / pic.width.toFloat(); val fx1 = face.right / pic.width.toFloat()
            val fy0 = face.top / pic.height.toFloat(); val fy1 = face.bottom / pic.height.toFloat()
            val cx = (fx0 + fx1) / 2
            val failures = mutableListOf<String>()
            for (e in FaceFun.effects) {
                val out = runBlocking { VideoEffects.make(ctx, Uri.fromFile(clip), VideoEffects.Recipe(funny = e.id, amount = 0.7f), given = found) }
                if (out == null) { failures += "${e.id}: not made"; continue }
                val f = frame(out, 1.0)
                val head = diff(plain, f, fx0 - 0.1f, fy0 - 0.15f, fx1 + 0.1f, fy1 + 0.05f)
                val far = if (cx > 0.5f) diff(plain, f, 0f, 0.88f, 0.15f, 1f) else diff(plain, f, 0.85f, 0.88f, 1f, 1f)
                println("FACEFUN|real|photo$tried|${e.id}|head ${"%.1f".format(head)}|far ${"%.1f".format(far)}")
                if (e.id != "longlegs" && head < 0.6) failures += "${e.id} did nothing to the face ($head)"
                if (e.id !in FaceFun.wholePicture && far > 2.0) failures += "${e.id} changed the far corner ($far)"
                out.delete()
            }
            assertTrue("photo $tried: " + failures.joinToString("; "), failures.isEmpty())
        }
        assumeTrue("no private photo had a clear face", tried > 0)
    }

    /**
     * The face engine follows small, moving and tilted real faces on every look (the private photos made into a
     * 1280 x 720 home video). Numbers only.
     */
    @Test fun theEngineFollowsSmallMovingRealFaces() {
        val ui = InstrumentationRegistry.getInstrumentation().uiAutomation
        val names = android.os.ParcelFileDescriptor.AutoCloseInputStream(ui.executeShellCommand("ls /data/local/tmp/real")).bufferedReader().readText()
            .lines().map { it.trim() }.filter { n -> listOf(".jpg", ".jpeg", ".png").any { n.lowercase().endsWith(it) } }.sorted()
        assumeTrue("no private photos", names.isNotEmpty())
        var tried = 0
        for (n in names) {
            if (tried >= 3) break
            val local = File(ctx.cacheDir, "eng-$n")
            android.os.ParcelFileDescriptor.AutoCloseInputStream(ui.executeShellCommand("cat /data/local/tmp/real/$n")).use { i -> local.outputStream().use { i.copyTo(it) } }
            val pic = BitmapFactory.decodeFile(local.path, BitmapFactory.Options().apply { inSampleSize = 2 }) ?: continue
            local.delete()
            val face = runCatching { Tasks.await(FaceDetection.getClient().process(InputImage.fromBitmap(pic, 0))) }.getOrNull().orEmpty().maxByOrNull { it.boundingBox.width() } ?: continue
            if (face.boundingBox.width() < pic.width * 0.1) continue
            tried++
            for ((label, scale, turn) in listOf(Triple("small", 0.55f, 0f), Triple("tilted", 0.8f, 20f))) {
                val engine = FaceEngine.open(ctx) ?: throw AssertionError("the face engine didn't load")
                var found = 0; var onFace = 0; var last: FloatArray? = null; val jumps = ArrayList<Float>()
                val frames = 30
                for (i in 0 until frames) {
                    val f = Bitmap.createBitmap(1280, 720, Bitmap.Config.ARGB_8888)
                    val c = Canvas(f); c.drawColor(Color.rgb(140, 128, 115))
                    val k = scale * 720 / pic.height
                    val m = android.graphics.Matrix().apply {
                        postTranslate(-pic.width / 2f, -pic.height / 2f); postScale(k, k); postRotate(turn)
                        postTranslate(640f + i * 6 - 90, 360f + (kotlin.math.sin(i * 0.3) * 12).toFloat())
                    }
                    c.drawBitmap(pic, m, Paint(Paint.FILTER_BITMAP_FLAG))
                    val look = engine.step(f, i / 30.0, wantParts = false)
                    val truth = runCatching { Tasks.await(FaceDetection.getClient().process(InputImage.fromBitmap(f, 0))) }.getOrNull().orEmpty().maxByOrNull { it.boundingBox.width() }
                    f.recycle()
                    val mesh = look.meshes.firstOrNull() ?: continue
                    found++
                    val b = FaceEngine.box(mesh); val cx = (b[0] + b[2]) / 2; val cy = (b[1] + b[3]) / 2
                    if (truth != null && kotlin.math.hypot(cx - truth.boundingBox.exactCenterX(), cy - truth.boundingBox.exactCenterY()) < truth.boundingBox.width() * 0.3f) onFace++
                    last?.let { jumps += kotlin.math.hypot(cx - it[0] - 6, cy - it[1]) }
                    last = floatArrayOf(cx, cy)
                }
                engine.close()
                val worst = jumps.sorted().dropLast(1).lastOrNull() ?: 0f
                println("FACEFUN|engine|photo$tried|$label|found $found/$frames|on face $onFace|worst jump ${"%.1f".format(worst)}")
                assertTrue("photo $tried $label: the face was lost ($found/$frames)", found >= frames * 9 / 10)
                assertTrue("photo $tried $label: the mesh wasn't on the face ($onFace/$found)", onFace >= found * 8 / 10)
                assertTrue("photo $tried $label: the face jumps ($worst)", worst < 25f)
            }
        }
        assumeTrue("no private photo had a clear face", tried > 0)
    }

    /** The loudness of a saved video's sound over each half second, or null if it has no sound. */
    private fun loudness(f: File): List<Double>? {
        val x = MediaExtractor(); x.setDataSource(f.path)
        val has = (0 until x.trackCount).any { x.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true }
        x.release()
        if (!has) return null
        val (pcm, rate) = runBlocking { FunnyMaker.sound(f) } ?: return emptyList()
        val win = rate / 2
        return (0 until pcm.size / win).map { k -> sqrt((0 until win).sumOf { i -> (pcm[k * win + i] * pcm[k * win + i]).toDouble() } / win) }
    }

    @Test fun musicIsUnderTheWholeVideoAndNoSoundHasNone() {
        val clip = still(drawing(false), "facefun-music")
        val withMusic = runBlocking { VideoEffects.make(ctx, Uri.fromFile(clip), VideoEffects.Recipe(music = "synth:party", keep = 0.0)) }
            ?: throw AssertionError("the video with music couldn't be made")
        val loud = loudness(withMusic) ?: throw AssertionError("the saved video has no sound")
        println("FACEFUN|music|" + loud.joinToString(" ") { "%.3f".format(it) })
        assertTrue("too short: ${loud.size}", loud.size >= 4)
        loud.dropLast(2).forEachIndexed { i, v -> assertTrue("the music stops at ${i / 2.0} s ($v)", v > 0.02) }
        val quiet = runBlocking { VideoEffects.make(ctx, Uri.fromFile(clip), VideoEffects.Recipe(music = "none")) } ?: throw AssertionError("no-sound video not made")
        assertTrue("\"No sound\" kept a sound track", loudness(quiet) == null)
    }
}
