package com.handytools.app.tools.gifmaker

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

private data class Size(val label: String, val width: Int)
private val SIZES = listOf(Size("Small", 180), Size("Medium", 240), Size("Large", 320), Size("HD", 480))
private data class Len(val label: String, val ms: Long)
private val LENGTHS = listOf(Len("4 s", 4000L), Len("8 s", 8000L), Len("15 s", 15000L))
private data class Smooth(val label: String, val fps: Int)
private val SMOOTHS = listOf(Smooth("8 fps", 8), Smooth("12 fps", 12), Smooth("15 fps", 15))
private data class From(val label: String, val where: Int)   // 0 start, 1 middle, 2 end
private val FROMS = listOf(From("From start", 0), From("From middle", 1), From("Last part", 2))

/**
 * GIF Maker. Pick a short video; frames from the part you choose (up to 15 s) are sampled, scaled and
 * encoded into a looping GIF you can share. Encoding runs entirely on the phone — no upload, no
 * watermark. Keep clips short for a smaller file.
 */
@Composable
fun GifMakerScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var sizeSel by remember { mutableStateOf(SIZES[1]) }
    var lenSel by remember { mutableStateOf(LENGTHS[0]) }
    var smoothSel by remember { mutableStateOf(SMOOTHS[1]) }
    var fromSel by remember { mutableStateOf(FROMS[0]) }
    var busy by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }
    var gif by remember { mutableStateOf<File?>(null) }
    var preview by remember { mutableStateOf<Bitmap?>(null) }

    fun build(uri: Uri) {
        busy = true; status = null; gif = null; preview = null
        scope.launch {
            val out = withContext(Dispatchers.IO) {
                val mmr = MediaMetadataRetriever()
                try {
                    mmr.setDataSource(ctx, uri)
                    val durMs = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                    if (durMs <= 0L) return@withContext null
                    val spanMs = minOf(durMs, lenSel.ms)
                    val startMs = when (fromSel.where) { 1 -> ((durMs - spanMs) / 2).coerceAtLeast(0L); 2 -> (durMs - spanMs).coerceAtLeast(0L); else -> 0L }
                    val targetW = sizeSel.width
                    val stepMs = (1000L / smoothSel.fps).coerceAtLeast(40L)
                    val frames = ArrayList<Bitmap>()
                    var tw = 0; var th = 0
                    var maxFrames = 150
                    var t = 0L
                    while (t < spanMs && frames.size < maxFrames) {
                        // Exact-frame seek: the sync-frame shortcut repeats the same keyframe for ~1s at a time.
                        val raw = mmr.getFrameAtTime((startMs + t) * 1000, MediaMetadataRetriever.OPTION_CLOSEST)
                        if (raw != null) {
                            if (tw == 0) {
                                tw = (targetW / 2) * 2
                                th = (targetW.toFloat() / raw.width * raw.height).toInt().let { (it / 2) * 2 }.coerceAtLeast(2)
                                // Keep every frame in memory at once under ~72 MB so long/HD GIFs can't crash low-RAM phones.
                                maxFrames = (72_000_000L / (tw.toLong() * th * 4)).toInt().coerceIn(20, 150)
                            }
                            val scaled = Bitmap.createScaledBitmap(raw, tw, th, true)
                            if (scaled != raw) raw.recycle()
                            frames.add(scaled)
                        }
                        t += stepMs
                    }
                    if (frames.isEmpty()) return@withContext null
                    val delayCs = (stepMs / 10).toInt().coerceIn(4, 25)
                    // If memory capped the frame count, stretch the delay so the GIF still covers the chosen length.
                    val realDelay = if (frames.size > 1 && frames.size * stepMs < spanMs) ((spanMs / frames.size) / 10).toInt().coerceIn(4, 50) else delayCs
                    val bytes = GifEncoder.encode(frames, realDelay)
                    val first = frames.first()
                    val previewBmp = first.copy(first.config ?: Bitmap.Config.ARGB_8888, false)
                    frames.forEach { it.recycle() }
                    val file = File(ctx.cacheDir, "gif_${System.currentTimeMillis()}.gif")
                    file.writeBytes(bytes)
                    file to previewBmp
                } catch (e: Exception) { null } finally { try { mmr.release() } catch (_: Exception) {} }
            }
            busy = false
            if (out == null) status = "Couldn't read that video. Try a short MP4."
            else { gif = out.first; preview = out.second; HandyHaptics.success(ctx) }
        }
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { u: Uri? ->
        if (u != null) build(u)
    }

    PowerToolPage("gifmaker") {
        Text("Size", color = Handy.palette.textSecondary, fontSize = 13.sp)
        Spacer(Modifier.size(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SIZES.forEach { s -> HChip(s.label, s == sizeSel) { sizeSel = s; gif = null; preview = null } }
        }

        Spacer(Modifier.size(14.dp))
        Text("Length", color = Handy.palette.textSecondary, fontSize = 13.sp)
        Spacer(Modifier.size(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            LENGTHS.forEach { l -> HChip(l.label, l == lenSel) { lenSel = l; gif = null; preview = null } }
        }
        Spacer(Modifier.size(14.dp))
        Text("Smoothness", color = Handy.palette.textSecondary, fontSize = 13.sp)
        Spacer(Modifier.size(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SMOOTHS.forEach { m -> HChip(m.label, m == smoothSel) { smoothSel = m; gif = null; preview = null } }
        }
        Spacer(Modifier.size(14.dp))
        Text("Which part", color = Handy.palette.textSecondary, fontSize = 13.sp)
        Spacer(Modifier.size(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FROMS.forEach { f -> HChip(f.label, f == fromSel) { fromSel = f; gif = null; preview = null } }
        }

        Spacer(Modifier.size(16.dp))
        HPrimaryButton(if (busy) "Building GIF…" else "Choose a video", modifier = Modifier.fillMaxWidth(), enabled = !busy) {
            picker.launch("video/*")
        }
        status?.let { Spacer(Modifier.size(10.dp)); Text(it, color = Handy.palette.textSecondary, fontSize = 13.sp) }

        preview?.let { bmp ->
            Spacer(Modifier.size(16.dp))
            Image(bmp.asImageBitmap(), contentDescription = "First frame", modifier = Modifier.fillMaxWidth().heightIn(max = 300.dp))
            gif?.let { f ->
                val kb = (f.length() / 1024)
                Text("GIF ready · ${kb} KB", color = Handy.palette.textSecondary, fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
                Spacer(Modifier.size(10.dp))
                HSecondaryButton("Share GIF", modifier = Modifier.fillMaxWidth()) { Share.file(ctx, f, "image/gif"); HandyHaptics.light(ctx) }
            }
        }

        Spacer(Modifier.size(16.dp))
        Text(
            "Encoded on your phone — nothing is uploaded. The preview shows the first frame; the saved file loops. Longer, smoother and bigger GIFs make larger files — if memory runs short the frame rate is lowered automatically.",
            color = Handy.palette.textSecondary, fontSize = 12.sp,
        )
    }
}
