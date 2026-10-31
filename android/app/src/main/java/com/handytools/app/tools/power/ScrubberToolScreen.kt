package com.handytools.app.tools.power

import android.graphics.Bitmap
import android.graphics.Rect
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AddPhotoAlternate
import androidx.compose.material.icons.outlined.Movie
import androidx.compose.material.icons.outlined.Save
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import com.google.common.collect.ImmutableList
import com.handytools.app.tools.Share
import com.handytools.app.ui.BigToggle
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.PreviewBox
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/** One picked photo: the loaded bitmap plus the faces and text found in it (bitmap pixel coords). */
private class Shot(val uri: Uri, val bitmap: Bitmap, val faces: List<Rect>, val text: List<Rect>)

/**
 * Scrubber. Hand it a photo (or several) and it finds every face and every piece of text — licence
 * plates, names, addresses, card and account numbers are all text — and paints them out, then writes
 * a clean copy with no location or metadata. Drag on the image to hide anything the detector missed.
 * Everything runs on your phone; nothing is uploaded and it never costs you a credit.
 */
@OptIn(UnstableApi::class)
@Composable
fun ScrubberToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()

    val shots = remember { mutableStateListOf<Shot>() }
    val manual = remember { mutableStateMapOf<Uri, SnapshotStateList<Rect>>() }
    var current by remember { mutableIntStateOf(0) }

    var hideFaces by remember { mutableStateOf(true) }
    var hideText by remember { mutableStateOf(true) }
    var stripMeta by remember { mutableStateOf(true) }
    var style by remember { mutableStateOf(ScrubberEngine.HideStyle.PIXELATE) }

    var loading by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }

    // Preview of the currently selected shot, re-scrubbed whenever a toggle, style or brush changes.
    var preview by remember { mutableStateOf<Bitmap?>(null) }
    var manualRev by remember { mutableIntStateOf(0) }

    // --- video state (best-effort path) ---
    var videoUri by remember { mutableStateOf<Uri?>(null) }
    var videoWorking by remember { mutableStateOf(false) }
    var videoProgress by remember { mutableStateOf<Float?>(null) }
    var videoStatus by remember { mutableStateOf<String?>(null) }
    var transformer by remember { mutableStateOf<Transformer?>(null) }
    DisposableEffect(Unit) { onDispose { try { transformer?.cancel() } catch (_: Exception) {} } }

    fun rectsFor(shot: Shot): List<Rect> {
        val out = ArrayList<Rect>()
        if (hideFaces) out.addAll(shot.faces)
        if (hideText) out.addAll(shot.text)
        manual[shot.uri]?.let { out.addAll(it) }
        return out
    }

    val imagePicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { picked ->
        if (picked.isNullOrEmpty()) return@rememberLauncherForActivityResult
        videoUri = null; videoStatus = null
        loading = true; status = null
        scope.launch {
            val loaded = withContext(Dispatchers.IO) {
                picked.mapNotNull { uri ->
                    val bmp = ScrubberEngine.loadBitmap(ctx, uri) ?: return@mapNotNull null
                    val faces = ScrubberEngine.detectFaces(bmp)
                    val text = ScrubberEngine.detectText(bmp)
                    Shot(uri, bmp, faces, text)
                }
            }
            loading = false
            if (loaded.isEmpty()) { status = "Couldn't open those images — try a different photo."; return@launch }
            shots.clear(); manual.clear(); shots.addAll(loaded); current = 0
        }
    }

    val videoPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { picked ->
        if (picked == null) return@rememberLauncherForActivityResult
        shots.clear(); manual.clear(); preview = null
        videoUri = picked; videoStatus = null; videoProgress = null
    }

    val saveImage = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("image/jpeg")) { uri ->
        val out = preview
        if (uri == null || out == null) return@rememberLauncherForActivityResult
        scope.launch {
            val ok = withContext(Dispatchers.IO) { ScrubberEngine.writeBitmapToUri(ctx, out, uri, png = false) }
            status = if (ok) "Saved a clean copy — no location or metadata." else "Couldn't save there. Try Share instead."
        }
    }

    // Recompute the preview for the selected shot off the main thread.
    LaunchedEffect(shots.size, current, hideFaces, hideText, style, manualRev) {
        val shot = shots.getOrNull(current) ?: run { preview = null; return@LaunchedEffect }
        preview = withContext(Dispatchers.IO) { ScrubberEngine.scrub(shot.bitmap, rectsFor(shot), style) }
    }

    fun shareAll() {
        if (shots.isEmpty()) return
        loading = true
        scope.launch {
            val files = withContext(Dispatchers.IO) {
                shots.mapNotNull { shot ->
                    val scrubbed = ScrubberEngine.scrub(shot.bitmap, rectsFor(shot), style)
                    ScrubberEngine.writeBitmap(ctx, scrubbed, png = false)
                }
            }
            loading = false
            if (files.isEmpty()) { status = "Couldn't prepare the images to share." } else Share.files(ctx, files, "image/jpeg")
        }
    }

    fun scrubVideo() {
        val src = videoUri ?: return
        videoWorking = true; videoProgress = 0f; videoStatus = null
        scope.launch {
            val info = withContext(Dispatchers.IO) { ScrubberEngine.videoInfo(ctx, src) }
            val rects = withContext(Dispatchers.IO) { ScrubberEngine.detectVideoBoxes(ctx, src, hideFaces, hideText) }
            val overlayBmp = if (info != null) ScrubberEngine.overlayBitmap(info.width, info.height, rects) else null
            val videoEffects = ArrayList<Effect>()
            if (overlayBmp != null) {
                val overlay: TextureOverlay = BitmapOverlay.createStaticBitmapOverlay(overlayBmp)
                videoEffects.add(OverlayEffect(ImmutableList.of(overlay)))
            }
            val out = File(ctx.cacheDir, "Scrubbed-${System.currentTimeMillis()}.mp4")
            val edited = EditedMediaItem.Builder(MediaItem.fromUri(src))
                .setEffects(Effects(emptyList(), videoEffects)).build()
            val t = Transformer.Builder(ctx)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, result: ExportResult) {
                        transformer = null; videoWorking = false; videoProgress = null
                        videoStatus = "Done — clean copy with metadata stripped."
                        Share.file(ctx, out, "video/mp4")
                    }
                    override fun onError(composition: Composition, result: ExportResult, exception: ExportException) {
                        transformer = null; videoWorking = false; videoProgress = null
                        videoStatus = "Couldn't process this clip (${exception.message?.take(70) ?: "codec refused it"}). Try a shorter video."
                    }
                }).build()
            transformer = t
            try {
                t.start(edited, out.absolutePath)
            } catch (e: Exception) {
                transformer = null; videoWorking = false; videoProgress = null
                videoStatus = "Couldn't start — ${e.message?.take(70) ?: "this device refused it"}."
                return@launch
            }
            val holder = ProgressHolder()
            while (transformer === t) {
                delay(300)
                if (transformer === t && t.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    videoProgress = holder.progress / 100f
                }
            }
        }
    }

    PowerToolPage("scrubber") {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
            HPrimaryButton("Pick photos", Modifier.weight(1f), icon = Icons.Outlined.AddPhotoAlternate) {
                imagePicker.launch(arrayOf("image/*"))
            }
            HSecondaryButton("Video", Modifier.weight(1f)) {
                videoPicker.launch(arrayOf("video/*"))
            }
        }
        NoteText("Finds faces and text — plates, names, addresses, card and account numbers — and paints them out, then saves a copy with no location or metadata. It all runs on your phone; nothing is uploaded and it never uses a credit.")

        status?.let { Spacer(Modifier.height(HandyTokens.Space8)); Text(it, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary) }

        // ---------------- toggles (shared by photo + video) ----------------
        if (shots.isNotEmpty() || videoUri != null) {
            Spacer(Modifier.height(HandyTokens.Space8))
            SectionLabel("What to hide")
            BigToggle("Hide faces", hideFaces) { hideFaces = it }
            BigToggle("Hide text (plates, names, numbers)", hideText) { hideText = it }
            BigToggle("Strip location & metadata", stripMeta) { stripMeta = it }
            Spacer(Modifier.height(HandyTokens.Space8))
            SectionLabel("Style")
            Row(horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                ScrubberEngine.HideStyle.values().forEach { s ->
                    HChip(s.label, style == s) { style = s }
                }
            }
        }

        // ---------------- photo path ----------------
        if (loading && shots.isEmpty() && videoUri == null) {
            Spacer(Modifier.height(HandyTokens.Space24))
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = HandyColors.Accent) }
        }

        val shot = shots.getOrNull(current)
        if (shot != null) {
            Spacer(Modifier.height(HandyTokens.Space12))
            if (shots.size > 1) {
                Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                    shots.forEachIndexed { i, _ -> HChip("Photo ${i + 1}", i == current) { current = i } }
                }
                Spacer(Modifier.height(HandyTokens.Space8))
            }

            val shown = preview ?: shot.bitmap
            val list = manual.getOrPut(shot.uri) { mutableStateListOf() }
            BoxWithConstraints(Modifier.fillMaxWidth()) {
                val wPx = with(LocalDensity.current) { maxWidth.toPx() }
                val scale = shown.width / wPx // bitmap px per screen px
                val brushPx = (shown.width * 0.08f).toInt().coerceAtLeast(16)
                var dragPx by remember(shot.uri) { mutableStateOf(0) }
                Box(
                    Modifier.fillMaxWidth().aspectRatio(shown.width.toFloat() / shown.height)
                        .clip(RoundedCornerShape(16.dp)).background(HandyColors.SurfaceDark)
                        .pointerInput(shot.uri) {
                            detectDragGestures(
                                onDragEnd = { manualRev++ },
                            ) { change, _ ->
                                change.consume()
                                val bx = (change.position.x * scale).toInt()
                                val by = (change.position.y * scale).toInt()
                                list.add(ScrubberEngine.brushRect(bx, by, brushPx))
                                dragPx++
                            }
                        }
                ) {
                    Image(shown.asImageBitmap(), "Scrubbed preview", Modifier.matchParentSize())
                    // Live feedback while dragging: translucent accent boxes the brush is laying down
                    // (the real pixelation is baked into the preview on drag end).
                    Canvas(Modifier.matchParentSize()) {
                        @Suppress("UNUSED_EXPRESSION") dragPx // read so the canvas redraws mid-drag
                        for (r in list) {
                            drawRect(
                                HandyColors.Accent.copy(alpha = 0.28f),
                                topLeft = Offset(r.left / scale, r.top / scale),
                                size = Size(r.width() / scale, r.height() / scale),
                            )
                        }
                    }
                }
            }
            Spacer(Modifier.height(HandyTokens.Space8))
            Text(
                "Hiding ${rectsFor(shot).size} area${if (rectsFor(shot).size == 1) "" else "s"} · drag on the photo to hide more.",
                style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary,
            )
            if (list.isNotEmpty()) {
                Spacer(Modifier.height(HandyTokens.Space8))
                HSecondaryButton("Clear my brush strokes") { list.clear(); manualRev++ }
            }

            Spacer(Modifier.height(HandyTokens.Space12))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                HPrimaryButton("Save", Modifier.weight(1f), enabled = !loading && preview != null, icon = Icons.Outlined.Save) {
                    val name = "Scrubbed-${System.currentTimeMillis()}.jpg"
                    saveImage.launch(name)
                }
                HSecondaryButton(if (shots.size > 1) "Share all" else "Share", Modifier.weight(1f), enabled = !loading) { shareAll() }
            }
        }

        // ---------------- video path (best-effort) ----------------
        val v = videoUri
        if (v != null) {
            Spacer(Modifier.height(HandyTokens.Space12))
            PreviewBox {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    androidx.compose.material3.Icon(Icons.Outlined.Movie, null, Modifier.size(28.dp), tint = HandyColors.Accent)
                    Spacer(Modifier.height(HandyTokens.Space8))
                    Text("Video ready to scrub", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                }
            }
            Spacer(Modifier.height(HandyTokens.Space8))
            Text(
                "Heavy job — best for short clips. The detector samples frames and burns fixed boxes over the faces and text it finds, then re-encodes the clip so all metadata (including location) is dropped.",
                style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary,
            )
            if (videoWorking) {
                Spacer(Modifier.height(HandyTokens.Space12))
                val p = videoProgress
                if (p != null && p > 0f) LinearProgressIndicator(progress = { p }, modifier = Modifier.fillMaxWidth(), color = HandyColors.Accent)
                else LinearProgressIndicator(Modifier.fillMaxWidth(), color = HandyColors.Accent)
            }
            Spacer(Modifier.height(HandyTokens.Space12))
            HPrimaryButton(if (videoWorking) "Scrubbing video…" else "Scrub video", enabled = !videoWorking, icon = Icons.Outlined.Movie) { scrubVideo() }
            videoStatus?.let { Spacer(Modifier.height(HandyTokens.Space8)); Text(it, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary) }
        }
    }
}
