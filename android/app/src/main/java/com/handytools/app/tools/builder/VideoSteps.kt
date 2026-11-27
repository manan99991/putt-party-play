package com.handytools.app.tools.builder

import android.content.Context
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import com.handytools.app.tools.power.MediaEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import kotlin.coroutines.resume

/**
 * The video steps of Build your own. Each one re-saves the video with Android's own encoder and waits for it to
 * finish, so a step can sit in a chain like any other. A re-saved video carries no location or camera details.
 */
@androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
object VideoSteps {
    private fun outFile(ctx: Context, ext: String): File =
        File(File(ctx.cacheDir, "video-steps").also { it.mkdirs() }, "tenzy-${System.currentTimeMillis()}.$ext")

    /** Runs one export to the end. False if the phone's encoder refuses it or it takes longer than 15 minutes. */
    private suspend fun export(ctx: Context, item: EditedMediaItem, out: File, bitrate: Int?): Boolean = withContext(Dispatchers.Main) {
        withTimeoutOrNull(15 * 60_000L) {
            suspendCancellableCoroutine<Boolean> { cont ->
                val listener = object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) { if (cont.isActive) cont.resume(true) }
                    override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) { if (cont.isActive) cont.resume(false) }
                }
                try {
                    val b = Transformer.Builder(ctx).setVideoMimeType(MimeTypes.VIDEO_H264).addListener(listener)
                    if (bitrate != null) b.setEncoderFactory(
                        DefaultEncoderFactory.Builder(ctx).setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(bitrate).build()).build())
                    val t = b.build()
                    cont.invokeOnCancellation { runCatching { t.cancel() } }
                    t.start(item, out.absolutePath)
                } catch (_: Throwable) { if (cont.isActive) cont.resume(false) }
            }
        } ?: false
    }

    /**
     * The video under [limitMb]. A video already under the limit is still re-saved, so its location is left behind.
     * If the first try lands over the limit it goes once more, smaller. Best effort: the smallest result is returned
     * even if a very long video can't be brought all the way down. Null only when the video can't be read at all.
     */
    suspend fun shrink(ctx: Context, uri: Uri, limitMb: Int): File? {
        val target = limitMb.toLong() * 1_048_576L
        val duration = MediaEngine.videoDurationMs(ctx, uri)
        val srcHeight = MediaEngine.videoHeightPx(ctx, uri)
        var bitrate = TextTidy.videoBitrate(target, duration)
        var best: File? = null
        for (attempt in 0 until 2) {
            val wanted = TextTidy.videoHeight(bitrate)
            val effects = if (srcHeight == 0 || srcHeight > wanted) Effects(emptyList(), listOf(Presentation.createForHeight(wanted))) else Effects(emptyList(), emptyList())
            val out = outFile(ctx, "mp4")
            val ok = export(ctx, EditedMediaItem.Builder(MediaItem.fromUri(uri)).setEffects(effects).build(), out, bitrate)
            if (!ok || out.length() == 0L) { out.delete(); break }
            if (best == null || out.length() < (best?.length() ?: Long.MAX_VALUE)) { best?.delete(); best = out } else out.delete()
            if (out.length() <= target) break
            bitrate = (bitrate * 0.7).toInt().coerceAtLeast(150_000)
        }
        return best
    }

    /** The same video with no sound. */
    suspend fun mute(ctx: Context, uri: Uri): File? {
        val out = outFile(ctx, "mp4")
        val ok = export(ctx, EditedMediaItem.Builder(MediaItem.fromUri(uri)).setRemoveAudio(true).build(), out, null)
        return if (ok && out.length() > 0L) out else { out.delete(); null }
    }

    /** Only the part between [startMs] and [endMs]. */
    suspend fun trim(ctx: Context, uri: Uri, startMs: Long, endMs: Long): File? {
        val out = outFile(ctx, "mp4")
        val clip = MediaItem.Builder().setUri(uri)
            .setClippingConfiguration(MediaItem.ClippingConfiguration.Builder().setStartPositionMs(startMs).setEndPositionMs(endMs).build()).build()
        val ok = export(ctx, EditedMediaItem.Builder(clip).build(), out, null)
        return if (ok && out.length() > 0L) out else { out.delete(); null }
    }

    /** The video turned by a quarter or half turn. [clockwise] is 90, 180 or 270. */
    suspend fun rotate(ctx: Context, uri: Uri, clockwise: Int): File? {
        val out = outFile(ctx, "mp4")
        // The effect counts turns the other way round (anticlockwise), so a turn to the right is a negative angle.
        val turn = androidx.media3.effect.ScaleAndRotateTransformation.Builder().setRotationDegrees(-clockwise.toFloat()).build()
        val ok = export(ctx, EditedMediaItem.Builder(MediaItem.fromUri(uri)).setEffects(Effects(emptyList(), listOf(turn))).build(), out, null)
        return if (ok && out.length() > 0L) out else { out.delete(); null }
    }

    /** The middle of the frame at 9:16 (a phone held upright). */
    suspend fun vertical(ctx: Context, uri: Uri, blurredEdges: Boolean = false): File? {
        val out = outFile(ctx, "mp4")
        val aspect = if (blurredEdges) displayAspect(ctx, uri) else null
        val effects = if (aspect != null && aspect > 9f / 16f) {
            // The whole picture kept, full width, over a blurred copy of itself filling the tall screen: squeeze the
            // frame into 9:16, blur that, then lay the sharp frame on top at its true shape.
            listOf(Presentation.createForAspectRatio(9f / 16f, Presentation.LAYOUT_STRETCH_TO_FIT),
                androidx.media3.effect.GaussianBlurWithFrameOverlaid(24f, 1f, (9f / 16f) / aspect))
        } else listOf(Presentation.createForAspectRatio(9f / 16f, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP))
        val ok = export(ctx, EditedMediaItem.Builder(MediaItem.fromUri(uri)).setEffects(Effects(emptyList(), effects)).build(), out, null)
        return if (ok && out.length() > 0L) out else { out.delete(); null }
    }

    /** Width over height as the video is shown (its rotation applied); null if it can't be read. */
    private fun displayAspect(ctx: Context, uri: Uri): Float? {
        val mmr = android.media.MediaMetadataRetriever()
        return try {
            mmr.setDataSource(ctx, uri)
            val w = mmr.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toFloatOrNull() ?: return null
            val h = mmr.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toFloatOrNull() ?: return null
            val rot = mmr.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            if (w <= 0f || h <= 0f) null else if (rot % 180 != 0) h / w else w / h
        } catch (_: Throwable) { null } finally { runCatching { mmr.release() } }
    }

    /** The same video played [rate] times as fast (0.5 is slow motion). It comes out without sound, since sound at another speed is only noise. */
    suspend fun speed(ctx: Context, uri: Uri, rate: Double): File? {
        if (rate <= 0.0) return null
        val out = outFile(ctx, "mp4")
        val pace = androidx.media3.effect.SpeedChangeEffect(rate.toFloat())
        val ok = export(ctx, EditedMediaItem.Builder(MediaItem.fromUri(uri)).setRemoveAudio(true).setEffects(Effects(emptyList(), listOf(pace))).build(), out, null)
        return if (ok && out.length() > 0L) out else { out.delete(); null }
    }

    /** Just the sound, as the bytes of an .m4a file. Null when the video has no sound. */
    suspend fun audio(ctx: Context, uri: Uri): ByteArray? = withContext(Dispatchers.IO) {
        val out = outFile(ctx, "m4a")
        try {
            MediaEngine.extractAudio(ctx, uri, out)
            if (out.length() > 0L) out.readBytes() else null
        } catch (_: Throwable) { null } finally { out.delete() }
    }
}
