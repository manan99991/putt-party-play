package com.handytools.app.tools.studio

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.widget.VideoView
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.handytools.app.I18n
import com.handytools.app.tools.Share
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HTextButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.rememberCamera
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/** One piece picked for the reel: the clip (a photo is already a clip) and its thumbnail. */
private class Piece(val uri: Uri, val thumb: Bitmap?)

/**
 * Beat Reel (the iPhone's, on Android): pick or film a few clips and photos, pick the music's style and the length,
 * and Tenzy cuts a tall reel to the beat. Watch it, then share it.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun BeatReelScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val pieces = remember { mutableStateListOf<Piece>() }
    var loading by remember { mutableStateOf(false) }
    var style by remember { mutableStateOf("upbeat") }
    var length by remember { mutableStateOf<Double?>(null) }
    var working by remember { mutableStateOf<Job?>(null) }
    var progress by remember { mutableStateOf(0.0) }
    var result by remember { mutableStateOf<File?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    fun thumb(u: Uri): Bitmap? = runCatching {
        MediaMetadataRetriever().run { setDataSource(ctx, u); val b = getFrameAtTime(500_000); release(); b }
    }.getOrNull()?.let { Bitmap.createScaledBitmap(it, 180, (180f * it.height / it.width).toInt().coerceAtLeast(1), true) }

    fun add(uris: List<Uri>) {
        if (uris.isEmpty()) return
        loading = true; error = null
        scope.launch {
            var added = 0
            for (u in uris) {
                val isPhoto = ctx.contentResolver.getType(u)?.startsWith("image/") == true
                val clip = if (isPhoto) Reels.photoClip(ctx, u)?.let { Uri.fromFile(it) } else u
                if (clip != null) { pieces += Piece(clip, withContext(Dispatchers.IO) { thumb(clip) }); added++ }
            }
            loading = false
            if (added == 0) error = "Those didn't load — try others."
        }
    }

    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(12)) { add(it) }
    val record = rememberCamera(video = true) { add(listOf(it)) }

    fun make() {
        error = null; progress = 0.0
        val uris = pieces.map { it.uri }
        working = scope.launch {
            val out = Reels.make(ctx, uris, style, length) { p -> progress = p }
            working = null
            if (out == null) error = "Couldn't make the reel — try other clips." else result = out
        }
    }

    PowerToolPage("beatreel") {
        val done = result
        if (done != null) {
            AndroidView(
                factory = { c -> VideoView(c).apply { setVideoPath(done.absolutePath); setOnPreparedListener { it.isLooping = true; start() } } },
                modifier = Modifier.fillMaxWidth().aspectRatio(9f / 16f).heightIn(max = 520.dp).clip(RoundedCornerShape(14.dp)).testTag("reel-result"),
            )
            Spacer(Modifier.height(HandyTokens.Space12))
            HPrimaryButton(I18n.t("Share"), Modifier.testTag("reel-share")) { Share.file(ctx, done, "video/mp4") }
            HTextButton(I18n.t("Change the music or length"), Modifier.fillMaxWidth()) { result = null }
            return@PowerToolPage
        }

        Text(I18n.t("Your clips and photos"), style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(HandyTokens.Space8))
        if (pieces.isNotEmpty()) {
            pieces.chunked(4).forEach { row ->
                Row(Modifier.fillMaxWidth().padding(bottom = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    row.forEach { p ->
                        Box(Modifier.weight(1f).aspectRatio(9f / 16f).clip(RoundedCornerShape(10.dp)).background(Handy.palette.surfaceRaised)) {
                            p.thumb?.let { Image(it.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) }
                            Box(Modifier.align(Alignment.TopEnd).padding(4.dp).size(28.dp).clip(CircleShape).background(androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.55f))
                                .clickable { pieces.remove(p) }.semantics { contentDescription = I18n.t("Remove") }, contentAlignment = Alignment.Center) {
                                Icon(Icons.Outlined.Close, null, Modifier.size(16.dp), tint = androidx.compose.ui.graphics.Color.White)
                            }
                        }
                    }
                    repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
            HPrimaryButton(I18n.t(if (pieces.isEmpty()) "Choose" else "Add more"), Modifier.weight(1f).testTag("reel-pick"), enabled = !loading && working == null) {
                pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo))
            }
            HSecondaryButton(I18n.t("Record"), Modifier.weight(1f).testTag("tool-record"), enabled = !loading && working == null) { record() }
        }
        if (loading) { Spacer(Modifier.height(HandyTokens.Space8)); LinearProgressIndicator(Modifier.fillMaxWidth()); Text(I18n.t("Getting them ready…"), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary) }

        if (pieces.isNotEmpty()) {
            Spacer(Modifier.height(HandyTokens.Space16))
            Text(I18n.t("The music"), style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(HandyTokens.Space8))
            FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Synth.styles.forEach { s ->
                    Box(Modifier.testTag("reel-style-${s.id}").semantics { selected = style == s.id }) {
                        HChip("${s.emoji} ${I18n.t(s.name)} · ${s.bpm.toInt()} BPM", selected = style == s.id) { style = s.id }
                    }
                }
            }
            Spacer(Modifier.height(HandyTokens.Space12))
            Text(I18n.t("Length"), style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.height(6.dp))
            FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("Auto" to null, "15 s" to 15.0, "30 s" to 30.0, "60 s" to 60.0).forEach { (label, s) ->
                    HChip(I18n.t(label), selected = length == s) { length = s }
                }
            }
            Spacer(Modifier.height(HandyTokens.Space16))
            HPrimaryButton(I18n.t("Make my reel"), Modifier.testTag("reel-make"), enabled = working == null && !loading) { make() }
            if (working != null) {
                Spacer(Modifier.height(HandyTokens.Space8))
                LinearProgressIndicator({ progress.toFloat().coerceIn(0f, 1f) }, Modifier.fillMaxWidth())
                Text(I18n.t("Cutting to the beat…"), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                HTextButton(I18n.t("Stop"), Modifier.fillMaxWidth()) { working?.cancel(); working = null }
            }
        }
        error?.let { Spacer(Modifier.height(HandyTokens.Space8)); Text(I18n.t(it), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error) }
    }
}
