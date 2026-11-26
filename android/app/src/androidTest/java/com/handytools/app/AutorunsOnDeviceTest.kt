package com.handytools.app

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.media3.common.MimeTypes
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.handytools.app.tools.autoruns.HeavyVideos
import com.handytools.app.tools.autoruns.SmartRuns
import com.handytools.app.tools.studio.Reels
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * Smart autoruns made for real on an Android emulator: a wastefully big video is found in the phone's videos, re-saved
 * smaller, and checked frame by frame — it must be clearly smaller and clear the same-picture bar on every checked frame.
 */
@RunWith(AndroidJUnit4::class)
class AutorunsOnDeviceTest {
    private val ctx: Context get() = InstrumentationRegistry.getInstrumentation().targetContext

    /** A smooth picture with soft detail (gradients and rings): compresses well, so a smaller copy can look the same. */
    private fun picture(): Uri {
        val b = Bitmap.createBitmap(1080, 1920, Bitmap.Config.ARGB_8888)
        val c = Canvas(b); val p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.shader = LinearGradient(0f, 0f, 1080f, 1920f, intArrayOf(0xFF1E3A8A.toInt(), 0xFFF59E0B.toInt(), 0xFF10B981.toInt()), null, Shader.TileMode.CLAMP)
        c.drawRect(0f, 0f, 1080f, 1920f, p); p.shader = null
        p.style = Paint.Style.STROKE; p.strokeWidth = 18f
        for (i in 0 until 9) { p.color = android.graphics.Color.HSVToColor(floatArrayOf(i * 40f, 0.6f, 0.95f)); c.drawCircle(540f, 900f, 80f + i * 55f, p) }
        val f = File(ctx.cacheDir, "autorun-picture-${System.nanoTime()}.png")
        f.outputStream().use { b.compress(Bitmap.CompressFormat.PNG, 100, it) }
        return Uri.fromFile(f)
    }

    @Test fun aHeavyVideoIsFoundMadeSmallerAndLooksTheSame() {
        val clip = runBlocking { Reels.photoClip(ctx, picture()) } ?: throw AssertionError("no clip")
        // A wasteful copy, the way a phone camera saves: a high bitrate for what's in it.
        val heavy = runBlocking { HeavyVideos.encode(ctx, Uri.fromFile(clip), 24_000_000, MimeTypes.VIDEO_H264, constant = true) } ?: throw AssertionError("no heavy copy")
        // Into the phone's videos, so the autorun finds it the way it finds a real one.
        val v = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, "autorun-test-${System.nanoTime()}.mp4"); put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= 29) put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/TenzyTest")
        }
        val uri = ctx.contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, v) ?: throw AssertionError("couldn't add the video")
        try {
            ctx.contentResolver.openOutputStream(uri)!!.use { o -> heavy.inputStream().use { it.copyTo(o) } }
            val now = System.currentTimeMillis()
            // The test clip is short, so the bar is its own rate (bytes a minute), not 60 MB.
            val perMinute = heavy.length() / 3.0 * 60 * 0.5
            val found = HeavyVideos.find(ctx, (now - 10 * 60_000)..(now + 60_000), minBytes = Long.MAX_VALUE, minPerMinute = perMinute)
            println("AUTORUN| heavy copy ${heavy.length() / 1000} KB, found ${found.size}")
            val item = found.firstOrNull { it.uri == uri } ?: throw AssertionError("the heavy video wasn't found (${found.size} found)")
            val smaller = runBlocking { HeavyVideos.resave(ctx, item.uri, item.width, item.height) { } } ?: throw AssertionError("it couldn't be re-saved")
            val worst = runBlocking { HeavyVideos.worstMatch(ctx, item.uri, smaller, item.seconds) }
            println("AUTORUN| ${item.bytes / 1000} KB → ${smaller.length() / 1000} KB, worst frame ${"%.1f".format(worst)} dB (bar ${SmartRuns.SAME_PICTURE_DB})")
            assertTrue("the smaller copy should be clearly smaller (${smaller.length()} vs ${item.bytes})", smaller.length() < item.bytes * 0.6)
            assertTrue("every checked frame should look the same ($worst dB)", worst >= SmartRuns.SAME_PICTURE_DB)
            assertNotNull(HeavyVideos.notice(found))
        } finally {
            runCatching { ctx.contentResolver.delete(uri, null, null) }
        }
    }
}
