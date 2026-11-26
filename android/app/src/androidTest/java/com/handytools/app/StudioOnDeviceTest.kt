package com.handytools.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.BitmapFactory
import android.graphics.Paint
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.ParcelFileDescriptor
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.handytools.app.tools.studio.FunnyMaker
import com.handytools.app.tools.studio.People
import com.handytools.app.tools.studio.Reels
import com.handytools.app.tools.studio.Synth
import com.handytools.app.tools.studio.TrailerMaker
import com.handytools.app.tools.studio.TrailerPlan
import com.handytools.app.tools.studio.VideoEffects
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * The studio tools made for real on an Android emulator, the way the iPhone's tests make them on the simulator: a
 * photo becomes a clip, a Beat Reel, a trailer, a funny moment and a video with effects come out the right size and
 * length, with sound, and the frames show what each promises (a black card with words, colour after it, grey on
 * the freeze, black and white with cinema bars).
 */
@RunWith(AndroidJUnit4::class)
class StudioOnDeviceTest {
    private val ctx: Context get() = InstrumentationRegistry.getInstrumentation().targetContext

    /** A busy, colourful picture (stripes and a disc), saved as a PNG. */
    private fun picture(hue: Float): Uri {
        val b = Bitmap.createBitmap(720, 1280, Bitmap.Config.ARGB_8888)
        val c = Canvas(b); val p = Paint(Paint.ANTI_ALIAS_FLAG)
        for (i in 0 until 16) { p.color = Color.HSVToColor(floatArrayOf((hue + i * 22f) % 360f, 0.85f, 0.95f)); c.drawRect(0f, i * 80f, 720f, (i + 1) * 80f, p) }
        p.color = Color.rgb(250, 220, 190); c.drawCircle(360f, 520f, 150f, p)
        val f = File(ctx.cacheDir, "test-picture-${System.nanoTime()}.png")
        f.outputStream().use { b.compress(Bitmap.CompressFormat.PNG, 100, it) }
        return Uri.fromFile(f)
    }

    private fun clip(hue: Float): Uri = runBlocking {
        Uri.fromFile(Reels.photoClip(ctx, picture(hue)) ?: throw AssertionError("a photo couldn't be made into a clip"))
    }

    private data class Info(val w: Int, val h: Int, val seconds: Double)
    private fun info(f: File): Info = MediaMetadataRetriever().run {
        setDataSource(f.absolutePath)
        val w = extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)!!.toInt()
        val h = extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)!!.toInt()
        val rot = extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
        val d = extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)!!.toLong() / 1000.0
        release()
        if (rot % 180 != 0) Info(h, w, d) else Info(w, h, d)
    }

    private fun hasSound(f: File): Boolean {
        val x = MediaExtractor(); x.setDataSource(f.absolutePath)
        val yes = (0 until x.trackCount).any { x.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true }
        x.release(); return yes
    }

    private fun frame(f: File, t: Double): Bitmap = MediaMetadataRetriever().run {
        setDataSource(f.absolutePath)
        val b = getFrameAtTime((t * 1e6).toLong(), MediaMetadataRetriever.OPTION_CLOSEST)!!
        release(); b
    }

    /** Mean and brightest luminance (0…255), and average colourfulness. */
    private fun stats(b: Bitmap): Triple<Double, Double, Double> {
        val s = Bitmap.createScaledBitmap(b, 180, 320, true)
        var sum = 0.0; var top = 0.0; var col = 0.0
        val px = IntArray(s.width * s.height); s.getPixels(px, 0, s.width, 0, 0, s.width, s.height)
        for (c in px) {
            val r = Color.red(c).toDouble(); val g = Color.green(c).toDouble(); val bl = Color.blue(c).toDouble()
            val l = 0.2126 * r + 0.7152 * g + 0.0722 * bl
            sum += l; top = max(top, l); col += max(r, max(g, bl)) - min(r, min(g, bl))
        }
        return Triple(sum / px.size, top, col / px.size)
    }

    @Test fun aPhotoBecomesATallClip() {
        val c = File(clip(0f).path!!)
        val i = info(c)
        assertEquals(Reels.W, i.w); assertEquals(Reels.H, i.h); assertEquals(3.0, i.seconds, 0.3)
    }

    @Test fun aBeatReelIsReallyMade() {
        val clips = listOf(clip(0f), clip(200f))
        val out = runBlocking { Reels.make(ctx, clips, "party", 8.0) } ?: throw AssertionError("the reel wasn't made")
        val i = info(out)
        assertEquals(Reels.W, i.w); assertEquals(Reels.H, i.h)
        val planned = Reels.plan(listOf(3.0, 3.0), Synth.style("party"), 8.0).second
        assertEquals("the reel is its bars plus the last ring", planned + Reels.RING_OUT, i.seconds, 0.5)
        assertTrue("the reel has no music", hasSound(out))
    }

    @Test fun aTrailerIsReallyMade() {
        val clips = listOf(clip(0f), clip(200f))
        val out = runBlocking { TrailerMaker.make(ctx, clips, "The Test", emptyList()) } ?: throw AssertionError("the trailer wasn't made")
        val i = info(out)
        assertEquals(Reels.W, i.w); assertEquals(Reels.H, i.h)
        assertEquals(TrailerPlan.parts().last().end, i.seconds, 0.5)
        assertTrue("the trailer has no sound", hasSound(out))
        val card = stats(frame(out, 1.2)); val shot = stats(frame(out, TrailerPlan.bar + 1.0))
        assertTrue("the card should be black (${card.first})", card.first < 60); assertTrue("the card has no words (${card.second})", card.second > 150)
        assertTrue("the shot after the card should be the clip, in colour (${shot.third} vs ${card.third})", shot.third > card.third + 10)
    }

    @Test fun aFunnyMomentIsReallyMade() {
        val src = clip(120f)
        val out = runBlocking { FunnyMaker.make(ctx, src, "scratch", 1.5, null) } ?: throw AssertionError("the funny moment wasn't made")
        assertEquals("the freeze adds its length", 3.0 + 2.6, info(out).seconds, 0.4)
        assertTrue("the record scratch's sound is missing", hasSound(out))
        val before = stats(frame(out, 0.8)); val frozen = stats(frame(out, 2.8))
        assertTrue("the frozen frame should be grey (${frozen.third} vs ${before.third})", frozen.third < before.third * 0.45)
    }

    @Test fun videoEffectsAreReallyPutOn() {
        val src = clip(30f)
        val out = runBlocking { VideoEffects.make(ctx, src, VideoEffects.Recipe(look = "noir", texture = "bars", words = "Hello")) }
            ?: throw AssertionError("the effects weren't put on")
        assertEquals(3.0, info(out).seconds, 0.3)
        val f = frame(out, 1.5)
        assertTrue("black and white should have no colour (${stats(f).third})", stats(f).third < 12)
        val topRow = IntArray(f.width); f.getPixels(topRow, 0, f.width, 0, 2, f.width, 1)
        assertTrue("cinema bars: the top should be black", topRow.all { Color.red(it) < 30 && Color.green(it) < 30 && Color.blue(it) < 30 })
        val preview = runBlocking { VideoEffects.make(ctx, src, VideoEffects.Recipe(look = "vivid"), preview = true) } ?: throw AssertionError("no preview")
        assertEquals("a preview is smaller", 960, max(info(preview).w, info(preview).h))
    }

    /** Colourfulness (max − min of r, g, b) at the points of [b] where [keep] says so, on a grid; -1 if too few. */
    private fun colourWhere(b: Bitmap, keep: (Float, Float) -> Boolean): Double {
        var s = 0.0; var n = 0
        for (y in 0 until b.height step 12) for (x in 0 until b.width step 12) {
            if (!keep(x.toFloat() / b.width, y.toFloat() / b.height)) continue
            val c = b.getPixel(x, y)
            s += max(Color.red(c), max(Color.green(c), Color.blue(c))) - min(Color.red(c), min(Color.green(c), Color.blue(c))); n++
        }
        return if (n > 30) s / n else -1.0
    }

    /** Mean difference (0…255) between two frames inside a box given as fractions (y down). */
    private fun differenceIn(a: Bitmap, b: Bitmap, x0: Float, y0: Float, x1: Float, y1: Float): Double {
        var s = 0.0; var n = 0
        for (y in (y0.coerceIn(0f, 1f) * a.height).toInt() until (y1.coerceIn(0f, 1f) * a.height).toInt() step 4)
            for (x in (x0.coerceIn(0f, 1f) * a.width).toInt() until (x1.coerceIn(0f, 1f) * a.width).toInt() step 4) {
                val p = a.getPixel(x, y); val q = b.getPixel(x, y)
                s += (abs(Color.red(p) - Color.red(q)) + abs(Color.green(p) - Color.green(q)) + abs(Color.blue(p) - Color.blue(q))) / 3.0; n++
            }
        return if (n > 0) s / n else 0.0
    }

    @Test fun colourPopGreysWhatIsntAPerson() {
        val src = clip(60f)
        val plain = stats(frame(File(src.path!!), 1.5)).third
        val out = runBlocking { VideoEffects.make(ctx, src, VideoEffects.Recipe(background = "colorpop")) } ?: throw AssertionError("colour pop wasn't put on")
        assertEquals(3.0, info(out).seconds, 0.3)
        val popped = stats(frame(out, 1.5)).third
        assertTrue("with nobody in it, colour pop should grey the picture ($popped vs $plain)", popped < plain * 0.5)
    }

    /** The private test photos (decrypted on the build machine only, pushed to the emulator), copied in; empty when absent. */
    private fun realPhotos(): List<File> {
        val ui = InstrumentationRegistry.getInstrumentation().uiAutomation
        fun shell(cmd: String) = ParcelFileDescriptor.AutoCloseInputStream(ui.executeShellCommand(cmd))
        val names = shell("ls /data/local/tmp/real").bufferedReader().readText().lines().map { it.trim() }
            .filter { n -> listOf(".jpg", ".jpeg", ".png", ".heic").any { n.lowercase().endsWith(it) } }.sorted()
        return names.map { n -> File(ctx.cacheDir, "real-${names.indexOf(n)}." + n.substringAfterLast('.')).also { f -> shell("cat /data/local/tmp/real/$n").use { i -> f.outputStream().use { i.copyTo(it) } } } }
            .filter { it.length() > 0 }
    }

    @Test fun realPeopleGetTheirBackgroundAndFunnyFace() {
        val photos = realPhotos()
        assumeTrue("private photos not on this device", photos.isNotEmpty())
        var tried = 0
        for (photo in photos) {
            if (tried >= 2) break
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }.also { BitmapFactory.decodeFile(photo.path, it) }
            if (bounds.outWidth <= 0) continue
            val clipFile = runBlocking { Reels.photoClip(ctx, Uri.fromFile(photo)) } ?: continue
            val clipUri = Uri.fromFile(clipFile)
            val plain = frame(clipFile, 1.0)
            val small = Bitmap.createScaledBitmap(plain, plain.width / 2, plain.height / 2, true)
            val face = runCatching { Tasks.await(FaceDetection.getClient().process(InputImage.fromBitmap(small, 0))) }.getOrNull().orEmpty()
                .maxByOrNull { it.boundingBox.width() }?.boundingBox ?: continue
            if (face.width() < small.width * 0.12) continue
            val people = runBlocking { People.find(ctx, clipUri, 1.5, masks = true, faces = false) } ?: continue
            val mask = people.masks[people.around(1.0).first]
            val share = People.share(mask)
            if (share < 0.05 || share > 0.8) continue
            fun isPerson(x: Float, y: Float) = People.valueAt(mask, people.maskW, people.maskH, x, y) > 230
            fun isBehind(x: Float, y: Float) = People.valueAt(mask, people.maskW, people.maskH, x, y) < 20
            val plainPerson = colourWhere(plain) { x, y -> isPerson(x, y) }
            if (plainPerson < 15) continue                 // a black-and-white photo says nothing here
            tried++

            val popped = frame(runBlocking { VideoEffects.make(ctx, clipUri, VideoEffects.Recipe(background = "colorpop")) } ?: throw AssertionError("colour pop wasn't put on"), 1.0)
            val behind = colourWhere(popped) { x, y -> isBehind(x, y) }; val person = colourWhere(popped) { x, y -> isPerson(x, y) }
            println("PEOPLE| photo $tried: person share ${"%.2f".format(share)}, colour on the person ${"%.1f".format(plainPerson)} → ${"%.1f".format(person)}, behind → ${"%.1f".format(behind)}")
            assertTrue("behind the person should be grey ($behind)", behind in 0.0..10.0)
            assertTrue("the person should keep their colour ($person vs $plainPerson)", person > plainPerson * 0.5)

            val big = frame(runBlocking { VideoEffects.make(ctx, clipUri, VideoEffects.Recipe(funny = "bighead")) } ?: throw AssertionError("big head wasn't put on"), 1.0)
            val fx0 = face.left / small.width.toFloat(); val fx1 = face.right / small.width.toFloat()
            val fy0 = face.top / small.height.toFloat(); val fy1 = face.bottom / small.height.toFloat()
            val onFace = differenceIn(plain, big, fx0, fy0, fx1, fy1)
            // Far from the face: the side of the frame away from it, low down.
            val far = if ((fx0 + fx1) / 2 > 0.5f) differenceIn(plain, big, 0f, 0.85f, 0.2f, 1f) else differenceIn(plain, big, 0.8f, 0.85f, 1f, 1f)
            println("PEOPLE| photo $tried: big head changed the face by ${"%.1f".format(onFace)}, far from it by ${"%.1f".format(far)}")
            assertTrue("big head should change the face ($onFace)", onFace > 10)
            assertTrue("big head shouldn't change what's far from the face ($far)", far < 8)
        }
        assumeTrue("no private photo had a clear face and person", tried > 0)
    }
}
