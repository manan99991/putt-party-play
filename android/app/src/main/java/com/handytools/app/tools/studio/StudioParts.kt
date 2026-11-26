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
import androidx.compose.foundation.layout.Column
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.handytools.app.I18n
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.rememberCamera
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/** One piece picked for a reel or a trailer: the clip (a photo is already made into one) and its thumbnail. */
class ClipPiece(val uri: Uri, val thumb: Bitmap?)

/**
 * "Your clips and photos" for Beat Reel and the trailer maker: the picked pieces four across (each removable), Choose
 * / Add more from the phone (videos and photos, photos made into short clips), and Record. [prefix] starts each tag.
 */
@Composable
fun ClipPicker(pieces: SnapshotStateList<ClipPiece>, prefix: String, enabled: Boolean) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var loading by remember { mutableStateOf(false) }
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
                if (clip != null) { pieces += ClipPiece(clip, withContext(Dispatchers.IO) { thumb(clip) }); added++ }
            }
            loading = false
            if (added == 0) error = "Those didn't load — try others."
        }
    }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(12)) { add(it) }
    val record = rememberCamera(video = true) { add(listOf(it)) }

    Column {
        Text(I18n.t("Your clips and photos"), style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(HandyTokens.Space8))
        pieces.chunked(4).forEach { row ->
            Row(Modifier.fillMaxWidth().padding(bottom = 6.dp).testTag("$prefix-pieces"), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                row.forEach { p ->
                    Box(Modifier.weight(1f).aspectRatio(9f / 16f).clip(RoundedCornerShape(10.dp)).background(Handy.palette.surfaceRaised)) {
                        p.thumb?.let { Image(it.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) }
                        Box(Modifier.align(Alignment.TopEnd).padding(4.dp).size(28.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.55f))
                            .clickable(enabled = enabled) { pieces.remove(p) }.semantics { contentDescription = I18n.t("Remove") }, contentAlignment = Alignment.Center) {
                            Icon(Icons.Outlined.Close, null, Modifier.size(16.dp), tint = Color.White)
                        }
                    }
                }
                repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
            HPrimaryButton(I18n.t(if (pieces.isEmpty()) "Choose" else "Add more"), Modifier.weight(1f).testTag("$prefix-pick"), enabled = enabled && !loading) {
                pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo))
            }
            HSecondaryButton(I18n.t("Record"), Modifier.weight(1f).testTag("tool-record"), enabled = enabled && !loading) { record() }
        }
        if (loading) {
            Spacer(Modifier.height(HandyTokens.Space8)); LinearProgressIndicator(Modifier.fillMaxWidth())
            Text(I18n.t("Getting them ready…"), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        error?.let { Spacer(Modifier.height(HandyTokens.Space8)); Text(I18n.t(it), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error) }
    }
}

/** A finished video playing in place, looping, tall. */
@Composable
fun ResultPlayer(file: File, tag: String) {
    AndroidView(
        factory = { c -> VideoView(c).apply { setVideoPath(file.absolutePath); setOnPreparedListener { it.isLooping = true; start() } } },
        modifier = Modifier.fillMaxWidth().aspectRatio(9f / 16f).heightIn(max = 520.dp).clip(RoundedCornerShape(14.dp)).testTag(tag),
    )
}
