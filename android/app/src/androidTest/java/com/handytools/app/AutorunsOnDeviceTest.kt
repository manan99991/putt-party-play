package com.handytools.app

import android.content.ContentProviderOperation
import android.content.ContentValues
import android.provider.ContactsContract
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
import com.handytools.app.tools.autoruns.ContactsBackup
import com.handytools.app.tools.autoruns.HeavyVideos
import com.handytools.app.tools.autoruns.PhotoDays
import com.handytools.app.tools.autoruns.WeekFilm
import com.handytools.app.tools.autoruns.ReadyToPost
import com.handytools.app.tools.autoruns.SmartRuns
import com.handytools.app.tools.studio.Reels
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertNotNull
import org.junit.Assume.assumeTrue
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

    /** Adds a contact the way the Contacts app would; its contact id. */
    private fun addContact(name: String, number: String): Long {
        val ops = arrayListOf(
            ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
                .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, null).withValue(ContactsContract.RawContacts.ACCOUNT_NAME, null).build(),
            ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI).withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
                .withValue(ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME, name).build(),
            ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI).withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
                .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, number).build(),
        )
        val res = ctx.contentResolver.applyBatch(ContactsContract.AUTHORITY, ops)
        return android.content.ContentUris.parseId(res[0].uri!!)
    }

    @Test fun theWeeklyContactsCopyNoticesWhoDisappeared() {
        val keep = addContact("Tenzy Keeper", "+1 312 555 0101")
        val leave = addContact("Tenzy Leaver", "+1 312 555 0102")
        try {
            val first = ContactsBackup.make(ctx) ?: throw AssertionError("no copy was made")
            assertTrue("both test contacts are in the copy (${first.count})", ContactsBackup.parse(first.file.readText()).map { it.name }.containsAll(listOf("Tenzy Keeper", "Tenzy Leaver")))
            ctx.contentResolver.delete(android.content.ContentUris.withAppendedId(ContactsContract.RawContacts.CONTENT_URI, leave), null, null)
            val second = ContactsBackup.make(ctx, System.currentTimeMillis() + 60_000) ?: throw AssertionError("no second copy")
            println("AUTORUN| contacts: ${first.count} then ${second.count}, gone ${second.gone.map { it.name }}")
            assertTrue("the deleted contact should be noticed", second.gone.any { it.name == "Tenzy Leaver" })
            assertTrue("the kept one isn't gone", second.gone.none { it.name == "Tenzy Keeper" })
            val back = ContactsBackup.handBack(ctx, second.gone)
            assertTrue("the hand-back file holds the whole card", back.readText().contains("Tenzy Leaver") && back.readText().contains("BEGIN:VCARD"))
        } finally {
            for (id in listOf(keep, leave)) runCatching { ctx.contentResolver.delete(android.content.ContentUris.withAppendedId(ContactsContract.RawContacts.CONTENT_URI, id), null, null) }
            ContactsBackup.copies(ctx).forEach { it.delete() }
        }
    }

    @androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
    @Test fun aWideClipIsMadeTallWithItsWholePictureAndASoftFill() {
        // A wide clip, the way most phones film sideways.
        val item = androidx.media3.common.MediaItem.Builder().setUri(picture()).setImageDurationMs(3000).build()
        val edited = androidx.media3.transformer.EditedMediaItem.Builder(item).setFrameRate(30)
            .setEffects(androidx.media3.transformer.Effects(emptyList(), listOf(androidx.media3.effect.Presentation.createForWidthAndHeight(1280, 720,
                androidx.media3.effect.Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP)))).build()
        val wide = File(ctx.cacheDir, "wide-${System.nanoTime()}.mp4")
        assertTrue("no wide clip", runBlocking { Reels.export(ctx, androidx.media3.transformer.Composition.Builder(listOf(androidx.media3.transformer.EditedMediaItemSequence(listOf(edited)))).build(), wide) { } })
        val out = runBlocking { ReadyToPost.make(ctx, Uri.fromFile(wide)) } ?: throw AssertionError("it wasn't made ready")
        val r = android.media.MediaMetadataRetriever().apply { setDataSource(out.absolutePath) }
        val w = r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)!!.toInt()
        val h = r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)!!.toInt()
        val f = r.getFrameAtTime(1_500_000, android.media.MediaMetadataRetriever.OPTION_CLOSEST)!!; r.release()
        assertTrue("tall 1080×1920 (${w}×$h)", w == ReadyToPost.W && h == ReadyToPost.H)
        fun lum(y0: Int, y1: Int): Double { var s = 0.0; var n = 0
            for (y in y0 until y1 step 8) for (x in 0 until f.width step 8) { val c = f.getPixel(x, y); s += 0.2126 * android.graphics.Color.red(c) + 0.7152 * android.graphics.Color.green(c) + 0.0722 * android.graphics.Color.blue(c); n++ }
            return s / n }
        val top = lum(0, 300); val middle = lum(800, 1100)
        println("AUTORUN| ready to post: top band ${"%.0f".format(top)}, middle ${"%.0f".format(middle)}")
        assertTrue("above the clip is a soft fill of it, not black bars ($top)", top > 25)
        assertTrue("the clip itself is in the middle, brighter than its dimmed fill ($middle vs $top)", middle > top)
    }

    /** The private test photos (decrypted on the build machine only, pushed to the emulator), put into the phone's
     *  photos the way a camera would; their uris. Empty when absent. */
    private fun realPhotosInGallery(max: Int = 12): List<Uri> {
        val ui = InstrumentationRegistry.getInstrumentation().uiAutomation
        fun shell(cmd: String) = android.os.ParcelFileDescriptor.AutoCloseInputStream(ui.executeShellCommand(cmd))
        val names = shell("ls /data/local/tmp/real").bufferedReader().readText().lines().map { it.trim() }
            .filter { n -> listOf(".jpg", ".jpeg", ".png").any { n.lowercase().endsWith(it) } }.sorted().take(max)
        return names.mapNotNull { n ->
            val v = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, "autorun-test-${System.nanoTime()}." + n.substringAfterLast('.'))
                put(MediaStore.Images.Media.MIME_TYPE, if (n.lowercase().endsWith(".png")) "image/png" else "image/jpeg")
                if (Build.VERSION.SDK_INT >= 29) put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/TenzyTest")
            }
            val uri = ctx.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, v) ?: return@mapNotNull null
            ctx.contentResolver.openOutputStream(uri)?.use { o -> shell("cat /data/local/tmp/real/$n").use { it.copyTo(o) } }
            uri
        }
    }

    @Test fun todaysPhotosOfPeopleBecomeOneCollageAndTheWeekAFilm() {
        val added = realPhotosInGallery()
        assumeTrue("private photos not on this device", added.isNotEmpty())
        try {
            val now = System.currentTimeMillis()
            val photos = PhotoDays.find(ctx, (now - 10 * 60_000)..(now + 60_000))
            val read = runBlocking { PhotoDays.read(ctx, photos) }
            val picks = com.handytools.app.tools.autoruns.SmartRuns.collagePicks(read)
            println("AUTORUN| collage: ${photos.size} photos, ${read.count { (it.seen?.faces ?: 0) > 0 }} with faces, ${picks.size} picked")
            assertTrue("the photos put in are found (${photos.size} of ${added.size})", photos.size >= added.size)
            assumeTrue("too few sharp photos of people in the private set", picks.size >= 2)
            val collage = runBlocking { PhotoDays.collage(ctx, picks.map { Uri.parse(it.id) }) } ?: throw AssertionError("no collage")
            val o = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }.also { android.graphics.BitmapFactory.decodeFile(collage.path, it) }
            println("AUTORUN| collage ${o.outWidth}×${o.outHeight}")
            assertTrue("one 1080-wide picture holding them (${o.outWidth}×${o.outHeight})", o.outWidth == 1080 && o.outHeight > 300)
            val film = runBlocking { WeekFilm.make(ctx, (now - 10 * 60_000)..(now + 60_000), { }) { } }
            if (picks.size >= 4) {
                assertNotNull("with enough moments, the week becomes a film", film)
                val r = android.media.MediaMetadataRetriever().apply { setDataSource(film!!.absolutePath) }
                val secs = r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)!!.toLong() / 1000.0; r.release()
                println("AUTORUN| week film ${"%.1f".format(secs)} s from ${picks.size} moments")
                assertTrue("a real film (${secs}s)", secs > 6)
            }
        } finally {
            added.forEach { runCatching { ctx.contentResolver.delete(it, null, null) } }
        }
    }
}
