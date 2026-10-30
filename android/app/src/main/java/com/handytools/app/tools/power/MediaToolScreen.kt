package com.handytools.app.tools.power

import android.graphics.Bitmap
import android.graphics.Rect
import android.net.Uri
import android.widget.VideoView
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.Pill
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.PreviewBox
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.File

private val TABS = listOf("Shrink", "Remove bg", "Redact", "Passport", "Strip location", "Convert")
private val SHRINK_TARGETS = listOf("Under 500 KB", "Under 1 MB", "Under 2 MB", "Under 5 MB", "1080p", "720p")
private val SHRINK_KB = listOf(500L, 1024L, 2048L, 5120L, 0L, 0L)
private val SHRINK_PX = listOf(0, 0, 0, 0, 1080, 720)
private val VIDEO_TARGETS = listOf("1080p" to 1080, "720p" to 720, "480p" to 480)
private val BG_MODES = listOf("Transparent", "White", "Blur", "Colour")
private val BG_COLOURS = listOf(0xFF1F5EFF, 0xFFE53935, 0xFF2E7D32, 0xFFFFC107, 0xFF8E24AA, 0xFF111111)
private data class PassportSpec(val label: String, val w: Int, val h: Int, val dims: String)
private val PASSPORT = listOf(
    PassportSpec("US 2×2 in", 600, 600, "2×2 in @300dpi"),
    PassportSpec("EU 35×45 mm", 413, 531, "35×45 mm @300dpi"),
    PassportSpec("India 2×2", 600, 600, "51×51 mm @300dpi"),
    PassportSpec("UK 35×45", 413, 531, "35×45 mm @300dpi"),
)
private val CONVERSIONS = listOf("HEIC → JPG", "PNG → JPG", "MOV → MP4", "Video → GIF", "Video → Audio")
private val SENSITIVE = Regex("""(\d[\d ().\-]{3,}\d)|([A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})""")

private data class SavedOut(val file: File, val mime: String, val where: String)

/** Media Studio — shrink, remove bg, redact, passport, strip location, convert. All on the phone. */
@androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
@Composable
fun MediaToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()

    var tab by remember { mutableIntStateOf(0) }
    var photo by remember { mutableStateOf<MediaEngine.LoadedImage?>(null) }
    var photoUri by remember { mutableStateOf<Uri?>(null) }
    var video by remember { mutableStateOf<Uri?>(null) }
    var videoBytes by remember { mutableLongStateOf(0L) }
    var videoDims by remember { mutableStateOf<String?>(null) }
    var result by remember { mutableStateOf<Bitmap?>(null) }
    var resultTransparent by remember { mutableStateOf(false) }
    var resultBytes by remember { mutableLongStateOf(0L) }
    var resultDims by remember { mutableStateOf<String?>(null) }
    var working by remember { mutableStateOf(false) }
    var progress by remember { mutableStateOf<Float?>(null) }
    var status by remember { mutableStateOf<String?>(null) }
    var statusIsError by remember { mutableStateOf(false) }
    var saved by remember { mutableStateOf<SavedOut?>(null) }
    var transformer by remember { mutableStateOf<Transformer?>(null) }

    var shrinkSel by remember { mutableIntStateOf(1) }
    var vidSel by remember { mutableIntStateOf(1) }
    var bgSel by remember { mutableIntStateOf(0) }
    var bgColour by remember { mutableIntStateOf(0) }
    var modelMissing by remember { mutableStateOf(false) }

    // Cancel and release the video transcoder if the user leaves the tool, so it can't leak or fire its
    // completion onto a dead scope. (Full survive-and-resume needs a ViewModel — tracked separately.)
    DisposableEffect(Unit) { onDispose { transformer?.cancel() } }
    val boxes = remember { mutableStateListOf<Rect>() }
    var passportSel by remember { mutableIntStateOf(0) }
    var passportResult by remember { mutableStateOf<Bitmap?>(null) }
    var copiesSel by remember { mutableIntStateOf(6) }
    var exif by remember { mutableStateOf<MediaEngine.ExifRows?>(null) }
    var stripped by remember { mutableStateOf(false) }
    var convSel by remember { mutableIntStateOf(0) }

    val imgRoom = Usage.hasRoom(ctx, "media_img", Limits.FREE_CONVERT_PER_DAY)
    val vidRoom = Usage.hasRoom(ctx, "media_vid", Limits.FREE_VIDEO_PER_DAY)
    val bgRoom = Usage.hasRoom(ctx, "bgremove", Limits.FREE_BG_REMOVE_PER_DAY)

    fun clearResult() { result = null; resultBytes = 0L; resultDims = null; resultTransparent = false; saved = null; status = null; statusIsError = false; passportResult = null }

    fun info(msg: String) { status = msg; statusIsError = false }
    fun fail(msg: String) { status = msg; statusIsError = true; HandyHaptics.light(ctx) }

    fun loadPhoto(uri: Uri) {
        working = true; clearResult(); boxes.clear(); stripped = false; exif = null; video = null; videoDims = null
        scope.launch {
            val loaded = withContext(Dispatchers.IO) { MediaEngine.loadImage(ctx, uri) }
            val rows = withContext(Dispatchers.IO) { MediaEngine.readExif(ctx, uri) }
            working = false
            if (loaded == null) { fail("Couldn't open that photo. Try another one or pick it from a different album."); return@launch }
            photo = loaded; photoUri = uri; exif = rows
            val m = loaded.mime
            convSel = when { m.contains("heic") || m.contains("heif") -> 0; m.contains("png") -> 1; else -> 0 }
        }
    }

    fun loadVideo(uri: Uri) {
        clearResult(); boxes.clear(); photo = null; photoUri = null; exif = null
        video = uri; videoBytes = MediaEngine.sizeOf(ctx, uri)
        val m = MediaEngine.mimeOf(ctx, uri)
        convSel = if (m.contains("quicktime")) 2 else 3
        scope.launch { videoDims = withContext(Dispatchers.IO) { MediaEngine.videoDims(ctx, uri) } }
    }

    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { u -> if (u != null) loadPhoto(u) }
    val videoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { u -> if (u != null) loadVideo(u) }

    /** Common tail for every photo export: cache copy, gallery save, stats, quota (only now), share hook. */
    suspend fun finishImage(bytes: ByteArray, name: String, mime: String, preview: Bitmap, dims: String, transparent: Boolean, usage: String, limit: Int) {
        val out = withContext(Dispatchers.IO) {
            val f = MediaEngine.cacheFile(ctx, name, bytes)
            val uri = MediaEngine.saveToGallery(ctx, name, mime, MediaEngine.Kind.IMAGE, bytes = bytes)
            f to uri
        }
        working = false
        result = preview; resultTransparent = transparent; resultBytes = bytes.size.toLong(); resultDims = dims
        saved = SavedOut(out.first, mime, if (out.second != null) "Saved to Pictures/Tenzy" else "Couldn't save to Pictures on this phone — use Share")
        Usage.use(ctx, usage, limit)
        info("Done · ${MediaEngine.human(bytes.size.toLong())}")
        HandyHaptics.success(ctx)
    }

    /** One Transformer runner for shrink, remux and audio fallback. Progress polled on the main thread. */
    fun runVideo(edited: EditedMediaItem, configure: (Transformer.Builder) -> Transformer.Builder, outName: String, mime: String, kind: MediaEngine.Kind, onFail: (String) -> Unit) {
        val out = File(ctx.cacheDir, outName)
        working = true; progress = 0f; status = null; statusIsError = false; saved = null
        val t = configure(Transformer.Builder(ctx)).addListener(object : Transformer.Listener {
            override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                transformer = null
                scope.launch {
                    val uri = withContext(Dispatchers.IO) { MediaEngine.saveToGallery(ctx, outName, mime, kind, file = out) }
                    working = false; progress = null
                    resultBytes = out.length(); resultDims = withContext(Dispatchers.IO) { if (kind == MediaEngine.Kind.VIDEO) MediaEngine.videoDims(ctx, Uri.fromFile(out)) else "audio" }
                    val folder = if (kind == MediaEngine.Kind.VIDEO) "Movies/Tenzy" else "Music/Tenzy"
                    saved = SavedOut(out, mime, if (uri != null) "Saved to $folder" else "Couldn't save to $folder on this phone — use Share")
                    Usage.use(ctx, "media_vid", Limits.FREE_VIDEO_PER_DAY)
                    info("Done · ${MediaEngine.human(out.length())}")
                    HandyHaptics.success(ctx)
                }
            }
            override fun onError(composition: Composition, exportResult: ExportResult, exception: ExportException) {
                transformer = null; working = false; progress = null
                onFail(exception.message?.take(90) ?: "the phone's video codec refused it")
            }
        }).build()
        transformer = t
        try { t.start(edited, out.absolutePath) } catch (e: Exception) {
            transformer = null; working = false; progress = null; onFail(e.message?.take(90) ?: "couldn't start"); return
        }
        scope.launch {
            val holder = ProgressHolder()
            while (transformer === t) {
                delay(300)
                if (transformer === t && t.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) progress = holder.progress / 100f
            }
        }
    }

    fun shrink() {
        val p = photo
        if (p != null) {
            working = true; status = null; saved = null
            scope.launch {
                val enc = withContext(Dispatchers.IO) {
                    if (SHRINK_PX[shrinkSel] > 0) MediaEngine.shrinkToPx(p.bitmap, SHRINK_PX[shrinkSel]) else MediaEngine.shrinkToBytes(p.bitmap, SHRINK_KB[shrinkSel] * 1024)
                }
                val preview = withContext(Dispatchers.IO) { android.graphics.BitmapFactory.decodeByteArray(enc.bytes, 0, enc.bytes.size) } ?: p.bitmap
                val hit = SHRINK_KB[shrinkSel] == 0L || enc.bytes.size <= SHRINK_KB[shrinkSel] * 1024
                finishImage(enc.bytes, "${MediaEngine.baseName(p.name)}-small.jpg", "image/jpeg", preview, "${enc.width}×${enc.height}", false, "media_img", Limits.FREE_CONVERT_PER_DAY)
                if (!hit) info("Got it to ${MediaEngine.human(enc.bytes.size.toLong())} — as small as it goes without wrecking it. Saved anyway.")
            }
            return
        }
        val v = video
        if (v != null) {
            val h = VIDEO_TARGETS[vidSel].second
            val presentation: Effect = Presentation.createForHeight(h)
            val edited = EditedMediaItem.Builder(MediaItem.fromUri(v)).setEffects(Effects(emptyList(), listOf(presentation))).build()
            runVideo(edited, { it.setVideoMimeType(MimeTypes.VIDEO_H264) }, "Tenzy-${h}p-${System.currentTimeMillis()}.mp4", "video/mp4", MediaEngine.Kind.VIDEO) { why ->
                fail("Couldn't shrink this video ($why).")
            }
        }
    }

    fun removeBackground() {
        val p = photo ?: return
        working = true; status = null; saved = null; modelMissing = false
        scope.launch {
            val fg: Bitmap? = try {
                val seg = SubjectSegmentation.getClient(SubjectSegmenterOptions.Builder().enableForegroundBitmap().build())
                try { seg.process(InputImage.fromBitmap(p.bitmap, 0)).await().foregroundBitmap } finally { seg.close() }
            } catch (e: Exception) {
                working = false
                val m = (e.message ?: "").lowercase()
                if (m.contains("model") || m.contains("download") || m.contains("module") || m.contains("unavailable")) {
                    modelMissing = true; fail("The cut-out model isn't on this phone yet (it comes with Google Play services). Try Shrink or Redact meanwhile.")
                } else fail("Couldn't process that photo. Try one with a clearer subject.")
                return@launch
            }
            if (fg == null) { working = false; fail("Couldn't find a clear subject. Try a photo with a distinct foreground."); return@launch }
            val composed = withContext(Dispatchers.IO) {
                when (bgSel) {
                    0 -> fg
                    1 -> MediaEngine.onColor(fg, android.graphics.Color.WHITE)
                    2 -> MediaEngine.onBlur(p.bitmap, fg)
                    else -> MediaEngine.onColor(fg, BG_COLOURS[bgColour].toInt())
                }
            }
            val transparent = bgSel == 0
            val bytes = withContext(Dispatchers.IO) { if (transparent) MediaEngine.png(composed) else MediaEngine.jpeg(composed, 92) }
            finishImage(bytes, "${MediaEngine.baseName(p.name)}-cutout.${if (transparent) "png" else "jpg"}", if (transparent) "image/png" else "image/jpeg",
                composed, "${composed.width}×${composed.height}", transparent, "bgremove", Limits.FREE_BG_REMOVE_PER_DAY)
        }
    }

    fun findSensitiveText() {
        val p = photo ?: return
        working = true; status = null
        scope.launch {
            val found = withContext(Dispatchers.IO) {
                try {
                    val rec = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                    val vt = try { rec.process(InputImage.fromBitmap(p.bitmap, 0)).await() } finally { rec.close() }
                    val list = ArrayList<Rect>()
                    for (b in vt.textBlocks) for (l in b.lines) for (el in l.elements) if (SENSITIVE.containsMatchIn(el.text)) el.boundingBox?.let { list.add(it) }
                    list
                } catch (e: Exception) { null }
            }
            working = false
            if (found == null) fail("Couldn't read text in this photo — drag boxes by hand instead.")
            else { boxes.addAll(found); info(if (found.isEmpty()) "No numbers or emails spotted — drag to black out anything else." else "Boxed ${found.size} number${if (found.size == 1) "" else "s"}/emails · drag more or Save") }
        }
    }

    fun saveRedacted() {
        val p = photo ?: return
        working = true; status = null
        scope.launch {
            val flat = withContext(Dispatchers.IO) { MediaEngine.redacted(p.bitmap, boxes.toList()) }
            val bytes = withContext(Dispatchers.IO) { MediaEngine.jpeg(flat, 92) }
            finishImage(bytes, "${MediaEngine.baseName(p.name)}-redacted.jpg", "image/jpeg", flat, "${flat.width}×${flat.height}", false, "media_img", Limits.FREE_CONVERT_PER_DAY)
        }
    }

    fun cropPassport() {
        val p = photo ?: return
        val spec = PASSPORT[passportSel]
        working = true; status = null; saved = null
        scope.launch {
            val fg: Bitmap? = try {
                val seg = SubjectSegmentation.getClient(SubjectSegmenterOptions.Builder().enableForegroundBitmap().build())
                try { seg.process(InputImage.fromBitmap(p.bitmap, 0)).await().foregroundBitmap } finally { seg.close() }
            } catch (e: Exception) { null }
            val out = withContext(Dispatchers.IO) { if (fg != null) MediaEngine.composeIdPhoto(fg, spec.w, spec.h) else MediaEngine.centreCrop(p.bitmap, spec.w, spec.h) }
            passportResult = out
            val bytes = withContext(Dispatchers.IO) { MediaEngine.jpeg(out, 95) }
            finishImage(bytes, "${MediaEngine.baseName(p.name)}-passport.jpg", "image/jpeg", out, spec.dims, false, "media_img", Limits.FREE_CONVERT_PER_DAY)
            if (fg == null) info("Couldn't cut the person out cleanly, so this is a centred crop at the right ratio. Saved.")
        }
    }

    fun printSheet() {
        val pp = passportResult ?: return
        working = true; status = null
        scope.launch {
            val sheet = withContext(Dispatchers.IO) { MediaEngine.printSheet(pp, copiesSel) }
            val bytes = withContext(Dispatchers.IO) { MediaEngine.jpeg(sheet, 95) }
            finishImage(bytes, "Tenzy-passport-sheet-${copiesSel}.jpg", "image/jpeg", sheet, "4×6 in · $copiesSel copies", false, "media_img", Limits.FREE_CONVERT_PER_DAY)
        }
    }

    fun stripMetadata() {
        val p = photo ?: return
        working = true; status = null
        scope.launch {
            val bytes = withContext(Dispatchers.IO) { MediaEngine.jpeg(p.bitmap, 95) }
            finishImage(bytes, "${MediaEngine.baseName(p.name)}-clean.jpg", "image/jpeg", p.bitmap, "${p.bitmap.width}×${p.bitmap.height}", false, "media_img", Limits.FREE_CONVERT_PER_DAY)
            stripped = true
        }
    }

    fun convert() {
        val p = photo
        val v = video
        when (convSel) {
            0, 1 -> {
                if (p == null) { fail("Pick a photo for this one."); return }
                working = true; status = null
                scope.launch {
                    val bytes = withContext(Dispatchers.IO) { MediaEngine.jpeg(p.bitmap, 92) }
                    finishImage(bytes, "${MediaEngine.baseName(p.name)}.jpg", "image/jpeg", p.bitmap, "${p.bitmap.width}×${p.bitmap.height}", false, "media_img", Limits.FREE_CONVERT_PER_DAY)
                }
            }
            2 -> {
                if (v == null) { fail("Pick a video for this one."); return }
                val edited = EditedMediaItem.Builder(MediaItem.fromUri(v)).build()
                runVideo(edited, { it }, "Tenzy-${System.currentTimeMillis()}.mp4", "video/mp4", MediaEngine.Kind.VIDEO) { why -> fail("Couldn't convert this clip ($why). Try Shrink at 720p instead — that always re-encodes.") }
            }
            3 -> {
                if (v == null) { fail("Pick a video for this one."); return }
                working = true; status = null; saved = null
                scope.launch {
                    val out = withContext(Dispatchers.IO) { MediaEngine.videoToGif(ctx, v, 320) }
                    if (out == null) { working = false; fail("Couldn't read frames from that video. Try a short MP4."); return@launch }
                    val uri = withContext(Dispatchers.IO) { MediaEngine.saveToGallery(ctx, out.first.name, "image/gif", MediaEngine.Kind.IMAGE, file = out.first) }
                    working = false
                    result = out.second; resultTransparent = false; resultBytes = out.first.length(); resultDims = "${out.second.width}×${out.second.height} · first 4 s"
                    saved = SavedOut(out.first, "image/gif", if (uri != null) "Saved to Pictures/Tenzy" else "Couldn't save to Pictures on this phone — use Share")
                    Usage.use(ctx, "media_vid", Limits.FREE_VIDEO_PER_DAY)
                    info("GIF ready · ${MediaEngine.human(out.first.length())}"); HandyHaptics.success(ctx)
                }
            }
            else -> {
                if (v == null) { fail("Pick a video for this one."); return }
                working = true; status = null; saved = null
                scope.launch {
                    val out = File(ctx.cacheDir, "Tenzy-audio-${System.currentTimeMillis()}.m4a")
                    val ok = withContext(Dispatchers.IO) { runCatching { MediaEngine.extractAudio(ctx, v, out) }.isSuccess && out.length() > 0 }
                    if (ok) {
                        val uri = withContext(Dispatchers.IO) { MediaEngine.saveToGallery(ctx, out.name, "audio/mp4", MediaEngine.Kind.AUDIO, file = out) }
                        working = false
                        resultBytes = out.length(); resultDims = "audio only"
                        saved = SavedOut(out, "audio/mp4", if (uri != null) "Saved to Music/Tenzy" else "Couldn't save to Music on this phone — use Share")
                        Usage.use(ctx, "media_vid", Limits.FREE_VIDEO_PER_DAY)
                        info("Done · ${MediaEngine.human(out.length())}"); HandyHaptics.success(ctx)
                    } else {
                        // Not AAC (e.g. WebM/Opus) — re-encode the sound to AAC with the transcoder instead.
                        val edited = EditedMediaItem.Builder(MediaItem.fromUri(v)).setRemoveVideo(true).build()
                        runVideo(edited, { it.setAudioMimeType(MimeTypes.AUDIO_AAC) }, "Tenzy-audio-${System.currentTimeMillis()}.m4a", "audio/mp4", MediaEngine.Kind.AUDIO) { why -> fail("Couldn't pull the audio out ($why).") }
                    }
                }
            }
        }
    }

    // ----------------------------------------------------------------------------------------- UI
    PowerToolPage("media", tabs = TABS, selected = tab, onTab = { tab = it }) {
        val shown = result ?: photo?.bitmap
        val vid = video
        if (shown != null) {
            PhotoCanvas(shown, transparent = resultTransparent, redact = tab == 2 && result == null, guide = tab == 3 && passportResult == null, boxes = boxes)
        } else if (vid != null) {
            key(vid) {
                AndroidView(
                    factory = { c ->
                        VideoView(c).apply {
                            setVideoURI(vid)
                            setOnPreparedListener { mp -> mp.isLooping = true; seekTo(1) }
                            setOnClickListener { if (isPlaying) pause() else start() }
                        }
                    },
                    modifier = Modifier.fillMaxWidth().height(230.dp).clip(RoundedCornerShape(16.dp)).background(Color.Black)
                )
            }
            Text("Tap the video to play or pause", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 6.dp))
        } else {
            PreviewBox(minHeight = 170.dp) {
                Text("Pick a photo or video to get it ready to send, post or print.", style = MaterialTheme.typography.bodyMedium,
                    color = Handy.palette.textSecondary, modifier = Modifier.padding(horizontal = 24.dp))
            }
        }
        Spacer(Modifier.height(10.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            HPrimaryButton("Choose photo", Modifier.weight(1.2f), enabled = !working) { photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
            HSecondaryButton("Video", Modifier.weight(0.8f), enabled = !working) { videoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly)) }
        }
        if (photo != null || vid != null) {
            Spacer(Modifier.height(10.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Stat(MediaEngine.human(photo?.bytes ?: videoBytes), "original", Modifier.weight(1f))
                Stat(if (resultBytes > 0) MediaEngine.human(resultBytes) else "—", "result", Modifier.weight(1f))
                Stat(resultDims ?: photo?.let { "${it.bitmap.width}×${it.bitmap.height}" } ?: videoDims ?: "video", "size", Modifier.weight(1f))
            }
        }

        val hasPhoto = photo != null
        val hasVideo = vid != null
        when (tab) {
            0 -> {
                SectionLabel("Target")
                if (hasVideo) ChipRowScroll { VIDEO_TARGETS.forEachIndexed { i, (l, _) -> HChip(l, vidSel == i) { vidSel = i } } }
                else ChipRowScroll { SHRINK_TARGETS.forEachIndexed { i, l -> HChip(l, shrinkSel == i) { shrinkSel = i } } }
                val room = if (hasVideo) vidRoom else imgRoom
                QuotaNote(room, if (hasVideo) "videos" else "photos")
                Spacer(Modifier.height(12.dp))
                if (working && hasVideo) {
                    LinearProgressIndicator(progress = { progress ?: 0f }, modifier = Modifier.fillMaxWidth())
                    Text("Transcoding on the phone… ${((progress ?: 0f) * 100).toInt()}%", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 6.dp, bottom = 10.dp))
                }
                HPrimaryButton(if (working) "Shrinking…" else "Shrink", enabled = (hasPhoto || hasVideo) && !working && room) { shrink() }
                if (statusIsError && hasVideo && vidSel != 2) {
                    Spacer(Modifier.height(8.dp))
                    HSecondaryButton("Try 480p", enabled = !working) { vidSel = 2; shrink() }
                }
            }
            1 -> {
                Spacer(Modifier.height(10.dp))
                Pill("Runs natively · subject segmentation on the phone")
                ChipRowScroll { BG_MODES.forEachIndexed { i, l -> HChip(l, bgSel == i) { bgSel = i } } }
                if (bgSel == 3) {
                    Spacer(Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        BG_COLOURS.forEachIndexed { i, c ->
                            Box(Modifier.size(32.dp).clip(CircleShape).background(Color(c))
                                .border(if (bgColour == i) 3.dp else 1.dp, if (bgColour == i) HandyColors.Accent else Handy.palette.border, CircleShape)
                                .clickable { bgColour = i })
                        }
                    }
                }
                QuotaNote(bgRoom, "backgrounds")
                Spacer(Modifier.height(12.dp))
                HPrimaryButton(if (working) "Cutting out…" else "Remove background", enabled = hasPhoto && !working && bgRoom) { removeBackground() }
                if (hasVideo) NoteText("Background removal works on photos — choose a photo above.")
                if (modelMissing) {
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { HChip("Go to Shrink", false) { tab = 0 }; HChip("Go to Redact", false) { tab = 2 } }
                }
            }
            2 -> {
                NoteText("Drag on the photo to black out faces, names, card numbers. Numbers and emails can be auto-found on the phone.")
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    HChip("Find numbers & emails", false) { if (hasPhoto && !working) findSensitiveText() }
                    if (boxes.isNotEmpty()) HChip("${boxes.size} box${if (boxes.size == 1) "" else "es"}", true) {}
                }
                QuotaNote(imgRoom, "photos")
                Spacer(Modifier.height(12.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    HSecondaryButton("Undo", Modifier.weight(1f), enabled = boxes.isNotEmpty() && !working) { boxes.removeAt(boxes.size - 1); result = null }
                    HPrimaryButton(if (working) "Saving…" else "Save redacted", Modifier.weight(1.4f), enabled = hasPhoto && boxes.isNotEmpty() && !working && imgRoom) { saveRedacted() }
                }
                if (hasVideo) NoteText("Redact works on photos — choose a photo above.")
            }
            3 -> {
                Spacer(Modifier.height(10.dp))
                ChipRowScroll { PASSPORT.forEachIndexed { i, s -> HChip(s.label, passportSel == i) { passportSel = i; passportResult = null; result = null } } }
                QuotaNote(imgRoom, "photos")
                Spacer(Modifier.height(12.dp))
                HPrimaryButton(if (working) "Cropping…" else "Crop to passport size", enabled = hasPhoto && !working && imgRoom) { cropPassport() }
                if (passportResult != null) {
                    SectionLabel("Print sheet · 4×6 in")
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { HChip("4 copies", copiesSel == 4) { copiesSel = 4 }; HChip("6 copies", copiesSel == 6) { copiesSel = 6 } }
                    Spacer(Modifier.height(10.dp))
                    HSecondaryButton(if (working) "Building…" else "Save print sheet", enabled = !working && imgRoom) { printSheet() }
                }
                NoteText("Centres the face and crops to the exact ratio at 300 dpi; prints 4 or 6 on a 4×6 sheet. Always check your authority's exact rules before printing.")
                if (hasVideo) NoteText("Passport photos come from photos — choose a photo above.")
            }
            4 -> {
                Spacer(Modifier.height(10.dp))
                val rows = exif
                HCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp)) {
                        ExifRow("GPS location", if (stripped) null else rows?.gps, rows, stripped, hasPhoto)
                        ExifRow("Camera / device", if (stripped) null else rows?.device, rows, stripped, hasPhoto)
                        ExifRow("Date taken", if (stripped) null else rows?.date, rows, stripped, hasPhoto)
                    }
                }
                QuotaNote(imgRoom, "photos")
                Spacer(Modifier.height(12.dp))
                HPrimaryButton(if (working) "Saving…" else if (stripped) "Stripped ✓ — saved" else "Strip metadata & save", enabled = hasPhoto && !working && !stripped && imgRoom) { stripMetadata() }
                NoteText("Re-encodes the image so nothing hidden travels with it.")
                if (hasVideo) NoteText("This reads photo metadata — choose a photo above. Shrinking a video re-encodes it from scratch.")
            }
            else -> {
                Spacer(Modifier.height(10.dp))
                ChipRowScroll { CONVERSIONS.forEachIndexed { i, l -> HChip(l, convSel == i) { convSel = i } } }
                val needsVideo = convSel >= 2
                val room = if (needsVideo) vidRoom else imgRoom
                QuotaNote(room, if (needsVideo) "videos" else "photos")
                Spacer(Modifier.height(12.dp))
                if (working && needsVideo && progress != null) {
                    LinearProgressIndicator(progress = { progress ?: 0f }, modifier = Modifier.fillMaxWidth())
                    Spacer(Modifier.height(10.dp))
                }
                HPrimaryButton(if (working) "Converting…" else "Convert", enabled = !working && room && (if (needsVideo) hasVideo else hasPhoto)) { convert() }
                if (needsVideo && !hasVideo && hasPhoto) NoteText("That one needs a video — tap Video above.")
                if (!needsVideo && !hasPhoto && hasVideo) NoteText("That one needs a photo — tap Choose photo above.")
                Row(Modifier.padding(top = 12.dp), verticalAlignment = Alignment.CenterVertically) { Pill("Runs natively") }
                NoteText(if (convSel == 4) "Pulls the soundtrack out losslessly as M4A (phones can't write MP3 natively; M4A plays everywhere)." else "HEIC and video conversion use the phone's own codecs. Nothing is uploaded.")
            }
        }

        status?.let {
            Text(it, style = MaterialTheme.typography.bodyMedium, color = if (statusIsError) HandyColors.Danger else Handy.palette.textSecondary, modifier = Modifier.padding(top = 12.dp))
        }
        saved?.let { s ->
            Spacer(Modifier.height(12.dp))
            HCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(14.dp)) {
                    Text(s.where, style = MaterialTheme.typography.titleMedium)
                    Text("${s.file.name} · ${MediaEngine.human(s.file.length())}", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    Spacer(Modifier.height(10.dp))
                    HSecondaryButton("Share") { Share.file(ctx, s.file, s.mime) }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------------------- pieces

@Composable
private fun ChipRowScroll(content: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) { content() }
}

@Composable
private fun QuotaNote(room: Boolean, what: String) {
    if (!room) Text("You've used today's free $what. Go Pro for unlimited.", style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))
}

@Composable
private fun Stat(value: String, label: String, modifier: Modifier) {
    Column(modifier.clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surface).padding(vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, maxLines = 1)
        Text(label, style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
    }
}

@Composable
private fun ExifRow(label: String, value: String?, rows: MediaEngine.ExifRows?, stripped: Boolean, hasPhoto: Boolean) {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium)
        val (text, tint) = when {
            stripped -> "Removed" to HandyColors.Success
            !hasPhoto -> "—" to Handy.palette.textSecondary
            rows == null -> "…" to Handy.palette.textSecondary
            !rows.readOk -> "Couldn't read" to HandyColors.Amber
            value == null -> "None" to Handy.palette.textSecondary
            else -> value to HandyColors.Amber
        }
        Text(text, color = tint, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, maxLines = 1)
    }
}

/** The big preview: checkerboard under transparent results, drag-to-redact boxes, passport guide. */
@Composable
private fun PhotoCanvas(bmp: Bitmap, transparent: Boolean, redact: Boolean, guide: Boolean, boxes: androidx.compose.runtime.snapshots.SnapshotStateList<Rect>) {
    var boxSize by remember { mutableStateOf(IntSize.Zero) }
    var dragStart by remember { mutableStateOf<Offset?>(null) }
    var dragNow by remember { mutableStateOf<Offset?>(null) }
    val checker = Handy.palette.border
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Box(
            Modifier.heightIn(max = 360.dp).aspectRatio(bmp.width.toFloat() / bmp.height.coerceAtLeast(1))
                .clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surface)
                .onSizeChanged { boxSize = it }
                .pointerInput(redact, bmp) {
                    if (!redact) return@pointerInput
                    detectDragGestures(
                        onDragStart = { dragStart = it; dragNow = it },
                        onDrag = { change, _ -> dragNow = change.position; change.consume() },
                        onDragEnd = {
                            val s = dragStart; val e = dragNow
                            if (s != null && e != null && boxSize.width > 0) {
                                val sx = bmp.width.toFloat() / boxSize.width
                                val sy = bmp.height.toFloat() / boxSize.height
                                val r = Rect((minOf(s.x, e.x) * sx).toInt(), (minOf(s.y, e.y) * sy).toInt(), (maxOf(s.x, e.x) * sx).toInt(), (maxOf(s.y, e.y) * sy).toInt())
                                if (r.width() > 4 && r.height() > 4) boxes.add(r)
                            }
                            dragStart = null; dragNow = null
                        },
                        onDragCancel = { dragStart = null; dragNow = null }
                    )
                }
        ) {
            if (transparent) Canvas(Modifier.matchParentSize()) {
                val sq = 12.dp.toPx()
                var y = 0f; var row = 0
                while (y < size.height) {
                    var x = 0f; var col = 0
                    while (x < size.width) {
                        if ((row + col) % 2 == 0) drawRect(checker, topLeft = Offset(x, y), size = Size(sq, sq))
                        x += sq; col++
                    }
                    y += sq; row++
                }
            }
            Image(bmp.asImageBitmap(), contentDescription = "Preview", modifier = Modifier.matchParentSize(), contentScale = ContentScale.FillBounds)
            Canvas(Modifier.matchParentSize()) {
                if (boxSize.width == 0) return@Canvas
                val sx = size.width / bmp.width
                val sy = size.height / bmp.height
                if (redact) {
                    boxes.forEach { r -> drawRect(Color.Black, topLeft = Offset(r.left * sx, r.top * sy), size = Size(r.width() * sx, r.height() * sy)) }
                    val s = dragStart; val e = dragNow
                    if (s != null && e != null) drawRect(Color.Black.copy(alpha = 0.7f), topLeft = Offset(minOf(s.x, e.x), minOf(s.y, e.y)), size = Size(kotlin.math.abs(e.x - s.x), kotlin.math.abs(e.y - s.y)))
                }
                if (guide) {
                    val w = size.width; val h = size.height
                    val ovalW = w * 0.42f; val ovalH = h * 0.56f
                    drawOval(HandyColors.Accent, topLeft = Offset((w - ovalW) / 2, h * 0.12f), size = Size(ovalW, ovalH), style = Stroke(width = 2.dp.toPx()))
                    drawLine(HandyColors.Accent.copy(alpha = 0.5f), Offset(w / 2, 0f), Offset(w / 2, h), strokeWidth = 1.dp.toPx())
                }
            }
        }
    }
    if (guide) Text("Line the head up inside the oval — it's cut out and centred for you.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 6.dp))
    if (redact) Text("Drag a box over anything to hide it. Undo removes the last one.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 6.dp))
}
