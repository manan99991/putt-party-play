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
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

private data class Size(val label: String, val width: Int)
private val SIZES = listOf(Size("Small", 180), Size("Medium", 240), Size("Large", 320))

/**
 * GIF Maker. Pick a short video; up to ~20 frames from its first few seconds are sampled, scaled and
 * encoded into a looping GIF you can share. Encoding runs entirely on the phone — no upload, no
 * watermark. Keep clips short for a smaller file.
 */
@Composable
fun GifMakerScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var sizeSel by remember { mutableStateOf(SIZES[1]) }
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
                    val spanMs = minOf(durMs, 4000L)
                    val count = 20
                    val stepMs = (spanMs / count).coerceAtLeast(60L)
                    val targetW = sizeSel.width
                    val frames = ArrayList<Bitmap>()
                    var t = 0L
                    var tw = 0; var th = 0
                    while (t < spanMs && frames.size < count) {
                        val raw = mmr.getFrameAtTime(t * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                        if (raw != null) {
                            if (tw == 0) {
                                tw = (targetW / 2) * 2
                                th = (targetW.toFloat() / raw.width * raw.height).toInt().let { (it / 2) * 2 }.coerceAtLeast(2)
                            }
                            val scaled = Bitmap.createScaledBitmap(raw, tw, th, true)
                            if (scaled != raw) raw.recycle()
                            frames.add(scaled)
                        }
                        t += stepMs
                    }
                    if (frames.isEmpty()) return@withContext null
                    val delayCs = (stepMs / 10).toInt().coerceIn(4, 25)
                    val bytes = GifEncoder.encode(frames, delayCs)
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

    Column(
        Modifier.fillMaxWidth().statusBarsPadding().padding(20.dp).verticalScroll(rememberScrollState())
    ) {
        ToolHeader("GIF Maker", "Turn a short video into a looping GIF you can share anywhere.")
        Spacer(Modifier.size(16.dp))

        Text("Size", color = Handy.palette.textSecondary, fontSize = 13.sp)
        Spacer(Modifier.size(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SIZES.forEach { s -> HChip(s.label, s == sizeSel) { sizeSel = s; gif = null; preview = null } }
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
            "Encoded on your phone — nothing is uploaded. The preview shows the first frame; the saved file loops. Shorter clips make smaller, smoother GIFs.",
            color = Handy.palette.textSecondary, fontSize = 12.sp,
        )
        Spacer(Modifier.size(16.dp))
        BannerAd()
    }
}
