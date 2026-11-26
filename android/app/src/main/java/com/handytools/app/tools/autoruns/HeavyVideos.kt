package com.handytools.app.tools.autoruns

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EncoderUtil
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import kotlin.coroutines.resume
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Make today's heavy videos smaller (the iPhone's autorun): the day's big videos re-saved in a smaller format at the
 * same picture size and frame rate (HEVC where the phone has it), each checked frame by frame against its original —
 * seven frames must all clear the same-picture bar — and offered only when it saves real space. The smaller copy is
 * saved next to the original with its date; the original is deleted only when the person asks and the phone confirms.
 */
@androidx.annotation.OptIn(UnstableApi::class)
object HeavyVideos {
    data class Item(val uri: Uri, val name: String, val bytes: Long, val seconds: Double, val width: Int, val height: Int, val created: Long)

    /** A smaller copy that passed: where it is, how big, and the worst frame's match (dB). */
    data class Smaller(val item: Item, val file: File, val bytes: Long, val worstDb: Double) {
        val saving: Long get() = item.bytes - bytes
    }

    const val FRAMES_CHECKED = 7

    /** The heavy videos added in [window], biggest first. Empty without permission to read videos. */
    fun find(ctx: Context, window: LongRange, minBytes: Long = 60_000_000, minPerMinute: Double = 25_000_000.0): List<Item> = runCatching {
        val cols = arrayOf(MediaStore.Video.Media._ID, MediaStore.Video.Media.DISPLAY_NAME, MediaStore.Video.Media.SIZE, MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.WIDTH, MediaStore.Video.Media.HEIGHT, MediaStore.Video.Media.DATE_ADDED)
        val all = ArrayList<Item>()
        ctx.contentResolver.query(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, cols,
            "${MediaStore.Video.Media.DATE_ADDED} >= ? AND ${MediaStore.Video.Media.DATE_ADDED} <= ?",
            arrayOf((window.first / 1000).toString(), (window.last / 1000 + 1).toString()), null)?.use { c ->
            while (c.moveToNext()) {
                val id = c.getLong(0)
                all += Item(ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id), c.getString(1) ?: "Video",
                    c.getLong(2), c.getLong(3) / 1000.0, c.getInt(4), c.getInt(5), c.getLong(6) * 1000)
            }
        }
        val heavy = SmartRuns.heavy(all.map { SmartRuns.Found(it.uri.toString(), it.created, isVideo = true, bytes = it.bytes, seconds = it.seconds, width = it.width, height = it.height) },
            minBytes, minPerMinute)
        heavy.mapNotNull { f -> all.firstOrNull { it.uri.toString() == f.id } }
    }.getOrDefault(emptyList())

    fun notice(found: List<Item>): String {
        val total = human(found.sumOf { it.bytes })
        return if (found.size == 1) com.handytools.app.I18n.t("1 video (%s) could be smaller and look the same.").format(total)
               else com.handytools.app.I18n.t("%d videos (%s) could be smaller and look the same.").format(found.size, total)
    }

    fun human(bytes: Long): String = when {
        bytes >= 1_000_000_000 -> "%.1f GB".format(bytes / 1e9)
        bytes >= 1_000_000 -> "${(bytes / 1e6).roundToInt()} MB"
        else -> "${max(1, (bytes / 1e3).roundToInt())} KB"
    }

    /** The bitrate for the smaller copy: enough per pixel to look the same (HEVC needs less than H.264). */
    fun bitrate(width: Int, height: Int, fps: Double, hevc: Boolean): Int {
        val perPixel = if (hevc) 0.065 else 0.1
        return (width.toDouble() * height * fps.coerceIn(24.0, 60.0) * perPixel).roundToInt().coerceIn(1_500_000, 40_000_000)
    }

    /** Re-saves [uri] smaller into the cache. null if the phone couldn't. */
    suspend fun resave(ctx: Context, uri: Uri, width: Int, height: Int, progress: (Double) -> Unit): File? {
        val fps = runCatching {
            MediaMetadataRetriever().run {
                setDataSource(ctx, uri)
                val n = extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT)?.toDoubleOrNull()
                val ms = extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toDoubleOrNull()
                release()
                if (n != null && ms != null && ms > 0) n / (ms / 1000) else 30.0
            }
        }.getOrDefault(30.0)
        val hevc = runCatching { EncoderUtil.getSupportedEncoders(MimeTypes.VIDEO_H265).isNotEmpty() }.getOrDefault(false)
        val mime = if (hevc) MimeTypes.VIDEO_H265 else MimeTypes.VIDEO_H264
        return encode(ctx, uri, bitrate(max(width, 2), max(height, 2), fps, hevc), mime, progress)
    }

    /** [uri] encoded again at [bitrate] in [mime] (sound kept as it is), into the cache. null if the phone couldn't. */
    suspend fun encode(ctx: Context, uri: Uri, bitrate: Int, mime: String, progress: (Double) -> Unit = {}, constant: Boolean = false): File? {
        val out = File(File(ctx.cacheDir, "autoruns").also { it.mkdirs() }, "smaller-${System.nanoTime()}.mp4")
        val ok = withContext(Dispatchers.Main) {
            withTimeoutOrNull(30 * 60_000L) {
                suspendCancellableCoroutine<Boolean> { cont ->
                    val ticker = Handler(Looper.getMainLooper())
                    val listener = object : Transformer.Listener {
                        override fun onCompleted(composition: Composition, exportResult: ExportResult) { ticker.removeCallbacksAndMessages(null); if (cont.isActive) cont.resume(true) }
                        override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) { ticker.removeCallbacksAndMessages(null); if (cont.isActive) cont.resume(false) }
                    }
                    val t = try {
                        val enc = DefaultEncoderFactory.Builder(ctx)
                            .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(bitrate)
                                .apply { if (constant) setBitrateMode(android.media.MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR) }.build())
                            .setEnableFallback(true).build()
                        Transformer.Builder(ctx).setVideoMimeType(mime).setEncoderFactory(enc).addListener(listener).build()
                    } catch (_: Throwable) { cont.resume(false); return@suspendCancellableCoroutine }
                    cont.invokeOnCancellation { ticker.removeCallbacksAndMessages(null); runCatching { t.cancel() } }
                    try { t.start(EditedMediaItem.Builder(MediaItem.fromUri(uri)).build(), out.absolutePath) }
                    catch (_: Throwable) { if (cont.isActive) cont.resume(false); return@suspendCancellableCoroutine }
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
        return if (ok && out.length() > 0) out else { out.delete(); null }
    }

    /** A frame as grey bytes at [w]×[h]. */
    private fun grey(b: Bitmap, w: Int, h: Int): ByteArray {
        val s = Bitmap.createScaledBitmap(b, w, h, true)
        val px = IntArray(w * h); s.getPixels(px, 0, w, 0, 0, w, h)
        if (s !== b) s.recycle()
        return ByteArray(px.size) { i -> val c = px[i]; (0.299 * Color.red(c) + 0.587 * Color.green(c) + 0.114 * Color.blue(c)).roundToInt().coerceIn(0, 255).toByte() }
    }

    /** The worst match (dB) over [FRAMES_CHECKED] frames spread through the video; 0 if a frame couldn't be read. */
    suspend fun worstMatch(ctx: Context, original: Uri, smaller: File, seconds: Double): Double = withContext(Dispatchers.Default) {
        val a = MediaMetadataRetriever(); val b = MediaMetadataRetriever()
        try {
            a.setDataSource(ctx, original); b.setDataSource(smaller.absolutePath)
            var worst = 99.0
            for (i in 0 until FRAMES_CHECKED) {
                val t = (seconds * (i + 0.5) / FRAMES_CHECKED * 1e6).toLong()
                val fa = a.getFrameAtTime(t, MediaMetadataRetriever.OPTION_CLOSEST) ?: return@withContext 0.0
                val fb = b.getFrameAtTime(t, MediaMetadataRetriever.OPTION_CLOSEST) ?: return@withContext 0.0
                val w = 320; val h = max(2, (320.0 * fa.height / max(1, fa.width)).roundToInt())
                worst = min(worst, SmartRuns.psnr(grey(fa, w, h), grey(fb, w, h)))
                fa.recycle(); fb.recycle()
            }
            worst
        } catch (_: Exception) { 0.0 } finally { runCatching { a.release() }; runCatching { b.release() } }
    }

    /** A smaller copy of [item] that looks the same and saves real space, or null (the reason in [why]). */
    suspend fun prepare(ctx: Context, item: Item, progress: (Double) -> Unit, why: (String) -> Unit = {}): Smaller? {
        val file = resave(ctx, item.uri, item.width, item.height) { p -> progress(p * 0.9) } ?: run { why("This phone couldn't re-save it."); return null }
        val size = file.length()
        if (!SmartRuns.worthIt(item.bytes, size)) { file.delete(); why("It's already about as small as it can be."); return null }
        val worst = worstMatch(ctx, item.uri, file, item.seconds)
        progress(1.0)
        if (worst < SmartRuns.SAME_PICTURE_DB) { file.delete(); why("Smaller, it wouldn't look the same."); return null }
        return Smaller(item, file, size, worst)
    }

    /** Saves the smaller copy beside the original in the phone's videos, with the original's date. The saved copy's uri. */
    fun save(ctx: Context, s: Smaller): Uri? = ReadyToPost.saveVideo(ctx, s.file, s.item.name.substringBeforeLast('.') + " (smaller).mp4", s.item.created)
}
