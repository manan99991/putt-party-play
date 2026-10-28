package com.handytools.app.tools.audiocut

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RangeSlider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.nio.ByteBuffer

/**
 * Ringtone & Audio Cutter. Pick a song or recording, drag the handles to the part you want, and
 * export a trimmed clip (great for a custom ringtone or a shareable snippet). The trim is a
 * lossless copy of the original audio — fast, no re-encoding — and runs entirely on-device.
 */
@Composable
fun AudioCutterScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var uri by remember { mutableStateOf<Uri?>(null) }
    var durationMs by remember { mutableStateOf(0L) }
    var range by remember { mutableStateOf(0f..0f) }
    var busy by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { u ->
        if (u == null) return@rememberLauncherForActivityResult
        uri = u; status = null
        val dur = audioDurationMs(ctx, u)
        durationMs = dur
        range = 0f..(dur.toFloat())
    }

    fun export() {
        val u = uri ?: return
        if (range.endInclusive - range.start < 500f) { status = "Pick at least half a second."; return }
        busy = true; status = null
        scope.launch {
            val ok = withContext(Dispatchers.IO) {
                try {
                    val out = File(ctx.cacheDir, "clip_${System.currentTimeMillis()}.m4a")
                    trimAudio(ctx, u, (range.start * 1000).toLong(), (range.endInclusive * 1000).toLong(), out)
                    out
                } catch (e: Exception) { null }
            }
            busy = false
            if (ok != null) { Share.file(ctx, ok, "audio/mp4"); HandyHaptics.success(ctx) }
            else status = "Couldn't trim that file. Try an MP3, M4A or recording."
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Ringtone & Audio Cutter", "Trim a song or recording down to the part you want, then share it or save it as a ringtone.")
        Spacer(Modifier.size(16.dp))

        if (uri == null) {
            Text("Choose an audio file to start.", color = Handy.palette.textSecondary)
            Spacer(Modifier.size(16.dp))
            HPrimaryButton("Choose audio") { picker.launch("audio/*") }
            Spacer(Modifier.weight(1f))
        } else if (durationMs <= 0L) {
            Text(status ?: "Couldn't read that file. Try an MP3, M4A or recording.", color = HandyColors.Accent)
            Spacer(Modifier.size(16.dp))
            HPrimaryButton("Choose another") { picker.launch("audio/*") }
            Spacer(Modifier.weight(1f))
        } else {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween) {
                Text(fmt(range.start.toLong()), fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onBackground)
                Text(fmt(range.endInclusive.toLong()), fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onBackground)
            }
            RangeSlider(value = range, onValueChange = { range = it }, valueRange = 0f..durationMs.toFloat())
            Text("Clip length  ${fmt((range.endInclusive - range.start).toLong())}", color = Handy.palette.textSecondary, fontSize = 13.sp)

            Spacer(Modifier.size(20.dp))
            HPrimaryButton(if (busy) "Trimming…" else "Export clip", enabled = !busy) { export() }
            status?.let { Spacer(Modifier.size(8.dp)); Text(it, color = HandyColors.Accent) }
            Spacer(Modifier.size(10.dp))
            HSecondaryButton("Choose another file", modifier = Modifier.fillMaxWidth(), enabled = !busy) {
                picker.launch("audio/*")
            }
            Spacer(Modifier.weight(1f))
        }

        BannerAd()
    }
}

private fun fmt(ms: Long): String {
    val s = ms / 1000; return "%d:%02d".format(s / 60, s % 60)
}

private fun audioDurationMs(ctx: Context, uri: Uri): Long {
    val mmr = MediaMetadataRetriever()
    return try {
        mmr.setDataSource(ctx, uri)
        mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
    } catch (e: Exception) { 0L } finally {
        try { mmr.release() } catch (_: Exception) {}
    }
}

/** Lossless container copy of the selected time span into an MP4/M4A file. */
private fun trimAudio(ctx: Context, uri: Uri, startUs0: Long, endUs0: Long, out: File) {
    val startUs = startUs0 * 1000
    val endUs = endUs0 * 1000
    val extractor = MediaExtractor()
    extractor.setDataSource(ctx, uri, null)
    var audioTrack = -1
    var format: MediaFormat? = null
    for (i in 0 until extractor.trackCount) {
        val f = extractor.getTrackFormat(i)
        if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) { audioTrack = i; format = f; break }
    }
    if (audioTrack < 0 || format == null) { extractor.release(); throw IllegalStateException("no audio track") }
    extractor.selectTrack(audioTrack)

    val muxer = MediaMuxer(out.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    val outTrack = muxer.addTrack(format)
    muxer.start()

    val maxChunk = 256 * 1024
    val buffer = ByteBuffer.allocate(maxChunk)
    val bufferInfo = android.media.MediaCodec.BufferInfo()
    extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
    try {
        while (true) {
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) break
            val ptUs = extractor.sampleTime
            if (ptUs > endUs) break
            if (ptUs >= startUs) {
                bufferInfo.offset = 0
                bufferInfo.size = sampleSize
                bufferInfo.presentationTimeUs = ptUs - startUs
                bufferInfo.flags = extractor.sampleFlags
                muxer.writeSampleData(outTrack, buffer, bufferInfo)
            }
            if (!extractor.advance()) break
        }
    } finally {
        try { muxer.stop() } catch (_: Exception) {}
        muxer.release()
        extractor.release()
    }
}
