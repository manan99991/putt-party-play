package com.handytools.app.tools.shrink

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.OptIn
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
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.exifinterface.media.ExifInterface
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import com.handytools.app.HandyApp
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max
import kotlin.math.roundToInt

/** Make photos and videos smaller — on the phone, no watermark. Shows the real before→after saving. */
@OptIn(UnstableApi::class)
@Composable
fun ShrinkScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val premium by HandyApp.instance.billing.isPremium.collectAsState()

    var video by remember { mutableStateOf(false) }      // false = photos, true = video
    var photoUris by remember { mutableStateOf<List<Uri>>(emptyList()) }
    var videoUri by remember { mutableStateOf<Uri?>(null) }
    var photoLevel by remember { mutableIntStateOf(1) }  // 0 small, 1 medium, 2 large
    var videoLevel by remember { mutableIntStateOf(1) }
    var working by remember { mutableStateOf(false) }
    var result by remember { mutableStateOf<ShrinkResult?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    val photoSizes = listOf("Small" to 1080, "Medium" to 1600, "Large" to 2560)
    val videoSizes = listOf("Small · 480p" to 480, "Medium · 720p" to 720, "Large · 1080p" to 1080)

    val photoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(if (premium) 30 else 10)
    ) { photoUris = it; result = null; error = null }

    val videoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) {
        videoUri = it; result = null; error = null
    }

    val imgOverQuota = !Usage.hasRoom(ctx, "shrink_img", Limits.FREE_CONVERT_PER_DAY)
    val vidOverQuota = !Usage.hasRoom(ctx, "shrink_vid", Limits.FREE_VIDEO_PER_DAY)

    fun shrinkVideo() {
        val u = videoUri ?: return
        if (!Usage.use(ctx, "shrink_vid", Limits.FREE_VIDEO_PER_DAY)) return
        working = true; result = null; error = null
        val before = sizeOf(ctx, u)
        val out = File(ctx.cacheDir, "Tenzy-${System.currentTimeMillis()}.mp4")
        val presentation: Effect = Presentation.createForHeight(videoSizes[videoLevel].second)
        val edited = EditedMediaItem.Builder(MediaItem.fromUri(u))
            .setEffects(Effects(emptyList(), listOf(presentation))).build()
        val transformer = Transformer.Builder(ctx)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    working = false
                    result = ShrinkResult(1, before, out.length())
                    Share.file(ctx, out, "video/mp4")
                }
                override fun onError(composition: Composition, exportResult: ExportResult, exception: ExportException) {
                    working = false; error = "Couldn't shrink this video. Try a different clip."
                }
            }).build()
        runCatching { transformer.start(edited, out.absolutePath) }
            .onFailure { working = false; error = "Couldn't start — try a different clip." }
    }

    fun shrinkPhotos() {
        if (photoUris.isEmpty()) return
        if (!Usage.use(ctx, "shrink_img", Limits.FREE_CONVERT_PER_DAY)) return
        working = true; result = null; error = null
        scope.launch {
            val r = withContext(Dispatchers.IO) { shrinkImages(ctx, photoUris, photoSizes[photoLevel].second) }
            working = false
            if (r != null && r.files.isNotEmpty()) {
                result = ShrinkResult(r.files.size, r.before, r.after)
                Share.files(ctx, r.files, "image/jpeg")
            } else error = "Couldn't read those photos."
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Shrink", "Make photos and videos small enough to send or upload — on your phone, no watermark, no sign-in.")
        Spacer(Modifier.size(16.dp))

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            HChip("Photos", !video) { video = false; result = null; error = null }
            HChip("Video", video) { video = true; result = null; error = null }
        }
        Spacer(Modifier.size(14.dp))

        when {
            !video -> {
                HPrimaryButton(if (photoUris.isEmpty()) "Pick photos" else "${photoUris.size} selected", modifier = Modifier.fillMaxWidth()) {
                    photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                }
                if (photoUris.isNotEmpty()) {
                    Spacer(Modifier.size(12.dp))
                    Text("Size", style = MaterialTheme.typography.labelLarge, color = Handy.palette.textSecondary)
                    Spacer(Modifier.size(6.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        photoSizes.forEachIndexed { i, (l, px) -> HChip("$l · ${px}px", photoLevel == i) { photoLevel = i } }
                    }
                    if (imgOverQuota) Text("You've used today's ${Limits.FREE_CONVERT_PER_DAY} free photo batches. Go Pro for unlimited.",
                        style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))
                    Spacer(Modifier.size(12.dp))
                    HPrimaryButton(if (working) "Shrinking…" else "Shrink ${photoUris.size}", enabled = !working && !imgOverQuota, modifier = Modifier.fillMaxWidth()) { shrinkPhotos() }
                }
            }
            else -> {
                HPrimaryButton(if (videoUri == null) "Pick a video" else "Pick a different video", modifier = Modifier.fillMaxWidth()) {
                    videoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly))
                }
                if (videoUri != null) {
                    Spacer(Modifier.size(12.dp))
                    Text("Size", style = MaterialTheme.typography.labelLarge, color = Handy.palette.textSecondary)
                    Spacer(Modifier.size(6.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        videoSizes.forEachIndexed { i, (l, _) -> HChip(l, videoLevel == i) { videoLevel = i } }
                    }
                    if (vidOverQuota) Text("You've shrunk today's ${Limits.FREE_VIDEO_PER_DAY} free videos. Go Pro for unlimited.",
                        style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))
                    Spacer(Modifier.size(12.dp))
                    HPrimaryButton(if (working) "Shrinking…" else "Shrink video", enabled = !working && !vidOverQuota, modifier = Modifier.fillMaxWidth()) { shrinkVideo() }
                }
            }
        }

        error?.let { Spacer(Modifier.size(12.dp)); Text(it, color = HandyColors.Accent, style = MaterialTheme.typography.bodyMedium) }
        result?.let { r ->
            Spacer(Modifier.size(14.dp))
            HCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text(if (r.count == 1) "Done — shared" else "Done — ${r.count} shared", style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.size(4.dp))
                    Text("${human(r.before)} → ${human(r.after)}" + (percent(r.before, r.after)?.let { "  ·  $it smaller" } ?: ""),
                        color = Handy.palette.textSecondary)
                }
            }
        }

        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

private data class ShrinkResult(val count: Int, val before: Long, val after: Long)
private data class ImgOut(val files: List<File>, val before: Long, val after: Long)

/** Decode (downsampled to avoid OOM), honour EXIF orientation, scale to maxDim, re-encode JPEG. */
private fun shrinkImages(ctx: Context, uris: List<Uri>, maxDim: Int): ImgOut {
    val out = mutableListOf<File>()
    var before = 0L; var after = 0L
    uris.forEachIndexed { i, uri ->
        before += sizeOf(ctx, uri)
        // Bounds pass to pick a safe inSampleSize for very large photos.
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        val longest = max(bounds.outWidth, bounds.outHeight)
        var sample = 1
        if (longest > 0) while (longest / (sample * 2) >= maxDim) sample *= 2
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        val decoded = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
            ?: return@forEachIndexed
        val oriented = applyOrientation(ctx, uri, decoded)
        val longestNow = max(oriented.width, oriented.height)
        val scaled = if (longestNow > maxDim) {
            val s = maxDim.toFloat() / longestNow
            Bitmap.createScaledBitmap(oriented, (oriented.width * s).roundToInt().coerceAtLeast(1), (oriented.height * s).roundToInt().coerceAtLeast(1), true)
        } else oriented
        val file = File(ctx.cacheDir, "Tenzy-shrunk-${i + 1}-${System.currentTimeMillis()}.jpg")
        FileOutputStream(file).use { scaled.compress(Bitmap.CompressFormat.JPEG, 82, it) }
        after += file.length()
        out.add(file)
        if (scaled != oriented) scaled.recycle()
        if (oriented != decoded) oriented.recycle()
        decoded.recycle()
    }
    return ImgOut(out, before, after)
}

private fun applyOrientation(ctx: Context, uri: Uri, bmp: Bitmap): Bitmap {
    val orientation = runCatching {
        ctx.contentResolver.openInputStream(uri)?.use {
            ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        } ?: ExifInterface.ORIENTATION_NORMAL
    }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
    val m = Matrix()
    when (orientation) {
        ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
        ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
        ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
        ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.postScale(-1f, 1f)
        ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.postScale(1f, -1f)
        else -> return bmp
    }
    return runCatching { Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true) }.getOrDefault(bmp)
}

private fun sizeOf(ctx: Context, uri: Uri): Long =
    runCatching { ctx.contentResolver.openFileDescriptor(uri, "r")?.use { it.statSize.coerceAtLeast(0) } ?: 0L }.getOrDefault(0L)

private fun human(bytes: Long): String {
    if (bytes <= 0) return "0 MB"
    val mb = bytes / 1024.0 / 1024.0
    return if (mb < 1) "%.0f KB".format(bytes / 1024.0) else "%.1f MB".format(mb)
}

private fun percent(before: Long, after: Long): String? {
    if (before <= 0 || after <= 0 || after >= before) return null
    return "${(100 - after * 100 / before)}%"
}
