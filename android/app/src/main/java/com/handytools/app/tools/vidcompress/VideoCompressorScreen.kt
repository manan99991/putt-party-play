package com.handytools.app.tools.vidcompress

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.ToolHeader
import java.io.File

/** Shrink a video with Media3 — scales down and re-encodes, all on the phone. */
@androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
@Composable
fun VideoCompressorScreen() {
    val ctx = LocalContext.current
    var uri by remember { mutableStateOf<Uri?>(null) }
    var quality by remember { mutableIntStateOf(1) }
    var working by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }
    val heights = listOf("Small" to 480, "Medium" to 720, "Large" to 1080)
    val overQuota = !Usage.hasRoom(ctx, "video", Limits.FREE_VIDEO_PER_DAY)

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri = it; status = null }

    fun compress() {
        val u = uri ?: return
        if (!Usage.use(ctx, "video", Limits.FREE_VIDEO_PER_DAY)) return
        working = true; status = null
        val out = File(ctx.cacheDir, "Tenzy-${System.currentTimeMillis()}.mp4")
        val presentation: Effect = Presentation.createForHeight(heights[quality].second)
        val edited = EditedMediaItem.Builder(MediaItem.fromUri(u))
            .setEffects(Effects(emptyList(), listOf(presentation))).build()
        val transformer = Transformer.Builder(ctx)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, result: ExportResult) {
                    working = false; status = "Done · ${out.length() / 1024 / 1024} MB"; Share.file(ctx, out, "video/mp4")
                }
                override fun onError(composition: Composition, result: ExportResult, exception: ExportException) {
                    working = false; status = "Couldn't compress this video."
                }
            }).build()
        transformer.start(edited, out.absolutePath)
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Video Compressor", "Make a video small enough to send — all on your phone.")
        Spacer(Modifier.size(12.dp))
        HPrimaryButton(if (uri == null) "Pick a video" else "Pick a different video", modifier = Modifier.fillMaxWidth()) {
            picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly))
        }
        if (uri != null) {
            Spacer(Modifier.size(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                heights.forEachIndexed { i, (l, h) -> HChip("$l · ${h}p", quality == i) { quality = i } }
            }
            if (overQuota) Text("You've compressed today's ${Limits.FREE_VIDEO_PER_DAY} free videos. Go Pro for unlimited.",
                style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))
            Spacer(Modifier.size(12.dp))
            HPrimaryButton(if (working) "Compressing…" else "Compress", enabled = !working && !overQuota, modifier = Modifier.fillMaxWidth()) { compress() }
        }
        status?.let { Spacer(Modifier.size(12.dp)); Text(it, style = MaterialTheme.typography.bodyMedium) }
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}
