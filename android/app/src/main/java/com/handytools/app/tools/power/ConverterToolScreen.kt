package com.handytools.app.tools.power

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.InsertDriveFile
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import com.handytools.app.tools.Share
import com.handytools.app.ui.ChipRow
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.SectionLabel
import com.handytools.app.ui.SliderRow
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

private val IMAGE_FORMATS = listOf(ConverterEngine.ImageFormat.PNG, ConverterEngine.ImageFormat.JPEG, ConverterEngine.ImageFormat.WEBP)
private const val PDF_TARGET = 3 // index that means "Images -> one PDF"
private val VIDEO_TARGETS = listOf("480p" to 480, "720p" to 720, "1080p" to 1080, "Original" to 0)

/**
 * Universal Converter — hand it a file and it offers the conversions that genuinely work for that
 * type: images between PNG/JPEG/WEBP (HEIC in too), images <-> PDF, and audio/video transcode via
 * Media3, all on the phone. Best-effort: an unsupported type says so and points at what IS possible,
 * and nothing here touches a quota.
 */
@androidx.annotation.OptIn(UnstableApi::class)
@Composable
fun ConverterToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()

    var single by remember { mutableStateOf<ConverterEngine.Src?>(null) }
    var batch by remember { mutableStateOf<List<Uri>?>(null) }
    var skipped by remember { mutableIntStateOf(0) }   // non-image files dropped from a multi-pick
    var inspecting by remember { mutableStateOf(false) }

    var imgTarget by remember { mutableIntStateOf(1) }    // default JPEG
    var pdfTarget by remember { mutableIntStateOf(0) }    // 0 = PNG, 1 = JPEG
    var vidTarget by remember { mutableIntStateOf(1) }    // default 720p
    var vidMode by remember { mutableIntStateOf(0) }      // 0 = MP4, 1 = audio only (M4A), 2 = muted MP4
    var srcSizeText by remember { mutableStateOf<String?>(null) }
    var quality by remember { mutableFloatStateOf(90f) }

    var working by remember { mutableStateOf(false) }
    var progress by remember { mutableStateOf<Float?>(null) } // null while working = indeterminate
    var results by remember { mutableStateOf<List<File>?>(null) }
    var resultMime by remember { mutableStateOf("*/*") }
    var resultSummary by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var savedNote by remember { mutableStateOf<String?>(null) }
    var transformer by remember { mutableStateOf<Transformer?>(null) }

    fun reset() { results = null; resultSummary = null; error = null; savedNote = null }

    // One file of ANY type (image / PDF / audio / video) — full per-type conversion options.
    val pickOne = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { picked ->
        if (picked != null) { reset(); batch = null; skipped = 0; single = ConverterEngine.Src(picked, "", ConverterEngine.Category.OTHER, "") }
    }
    // Several photos at once via the Android photo picker — reliable multi-select (checkboxes), unlike
    // the document picker which needed a long-press selection mode and often picked just one.
    val pickPhotos = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(30)
    ) { picked ->
        if (!picked.isNullOrEmpty()) {
            reset(); single = null; skipped = 0
            if (picked.size == 1) single = ConverterEngine.Src(picked[0], "", ConverterEngine.Category.OTHER, "")
            else batch = picked
        }
    }

    // Identify a single pick off the main thread, then settle its real metadata.
    LaunchedEffect(single?.uri) {
        val u = single?.uri ?: return@LaunchedEffect
        if (single?.typeLabel?.isNotEmpty() == true) return@LaunchedEffect
        inspecting = true
        val s = withContext(Dispatchers.IO) { ConverterEngine.inspect(ctx, u) }
        srcSizeText = withContext(Dispatchers.IO) { ConverterEngine.humanSize(com.handytools.app.tools.power.FileViewer.sizeOf(ctx, u)) }
        single = s; inspecting = false
        imgTarget = if (s.category == ConverterEngine.Category.IMAGE) 1 else imgTarget
    }

    val saver = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("*/*")) { dest ->
        val file = results?.firstOrNull()
        if (dest != null && file != null) {
            scope.launch {
                val ok = withContext(Dispatchers.IO) {
                    runCatching { ctx.contentResolver.openOutputStream(dest)?.use { out -> file.inputStream().use { it.copyTo(out) } } }.isSuccess
                }
                savedNote = if (ok) "Saved to the location you chose." else "Couldn't write there — try Share instead."
            }
        }
    }

    // Save ALL converted files into a folder the user picks (SAF tree). Works API 26+, no extra deps.
    val saveTree = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { tree ->
        val files = results
        if (tree != null && files != null) {
            scope.launch {
                val n = withContext(Dispatchers.IO) {
                    runCatching {
                        val cr = ctx.contentResolver
                        val dirId = android.provider.DocumentsContract.getTreeDocumentId(tree)
                        val dir = android.provider.DocumentsContract.buildDocumentUriUsingTree(tree, dirId)
                        files.count { f ->
                            val doc = android.provider.DocumentsContract.createDocument(cr, dir, resultMime, f.name)
                            doc != null && cr.openOutputStream(doc)?.use { out -> f.inputStream().use { it.copyTo(out) } } != null
                        }
                    }.getOrDefault(0)
                }
                savedNote = if (n == files.size) "Saved all $n files to the folder you chose."
                    else if (n > 0) "Saved $n of ${files.size} — try Share for the rest."
                    else "Couldn't write there — try Share instead."
            }
        }
    }

    // ---- conversion runners ----

    fun showImages(files: List<File>, mime: String) {
        results = files.ifEmpty { null }
        resultMime = mime
        resultSummary = when {
            files.isEmpty() -> null
            files.size == 1 -> "Done · ${ConverterEngine.humanSize(files[0].length())}"
            else -> "Done · ${files.size} files"
        }
        error = if (files.isEmpty()) "Couldn't convert this one. The format may not be readable on this phone." else null
        working = false; progress = null
    }

    fun convertImageLike(uris: List<Uri>) {
        working = true; progress = null; reset()
        scope.launch {
            if (imgTarget == PDF_TARGET) {
                val pdf = withContext(Dispatchers.IO) { ConverterEngine.imagesToPdf(ctx, uris, quality.toInt()) }
                showImages(listOfNotNull(pdf), "application/pdf")
            } else {
                val fmt = IMAGE_FORMATS[imgTarget]
                val files = withContext(Dispatchers.IO) { uris.mapNotNull { ConverterEngine.convertImage(ctx, it, fmt, quality.toInt()) } }
                showImages(files, fmt.mime)
            }
        }
    }

    fun convertPdf(src: ConverterEngine.Src) {
        working = true; progress = null; reset()
        val fmt = if (pdfTarget == 1) ConverterEngine.ImageFormat.JPEG else ConverterEngine.ImageFormat.PNG
        scope.launch {
            val files = withContext(Dispatchers.IO) { ConverterEngine.pdfToImages(ctx, src.uri, fmt, quality.toInt()) }
            showImages(files, fmt.mime)
        }
    }

    fun runMedia(out: File, mime: String, start: (Transformer.Listener) -> Transformer) {
        working = true; progress = 0f; reset()
        val listener = object : Transformer.Listener {
            override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                transformer = null; working = false; progress = null
                results = listOf(out); resultMime = mime; resultSummary = "Done · ${ConverterEngine.humanSize(out.length())}"
            }
            override fun onError(composition: Composition, exportResult: ExportResult, exception: ExportException) {
                transformer = null; working = false; progress = null
                error = "Couldn't convert this (${exception.message?.take(80) ?: "the phone's codec refused it"})."
            }
        }
        val t = try { start(listener) } catch (e: Exception) {
            working = false; progress = null; error = "Couldn't start the conversion (${e.message?.take(80) ?: "unknown"})."; return
        }
        transformer = t
        scope.launch {
            val holder = ProgressHolder()
            while (transformer === t) {
                delay(300)
                if (transformer === t && t.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) progress = holder.progress / 100f
            }
        }
    }

    fun convert() {
        val b = batch
        val s = single
        when {
            b != null -> convertImageLike(b)
            s != null && s.category == ConverterEngine.Category.IMAGE -> convertImageLike(listOf(s.uri))
            s != null && s.category == ConverterEngine.Category.PDF -> convertPdf(s)
            s != null && s.category == ConverterEngine.Category.AUDIO -> {
                val out = File(ctx.cacheDir, "${ConverterEngine.baseName(s.name)}-audio-${System.currentTimeMillis()}.m4a")
                runMedia(out, "audio/mp4") { l -> ConverterEngine.startAudioExport(ctx, s.uri, out, l) }
            }
            s != null && s.category == ConverterEngine.Category.VIDEO -> {
                if (vidMode == 1) {
                    val out = File(ctx.cacheDir, "${ConverterEngine.baseName(s.name)}-audio-${System.currentTimeMillis()}.m4a")
                    runMedia(out, "audio/mp4") { l -> ConverterEngine.startAudioExport(ctx, s.uri, out, l) }
                } else {
                    val h = VIDEO_TARGETS[vidTarget].second
                    val tag = if (vidMode == 2) "muted" else if (h > 0) "${h}p" else "mp4"
                    val out = File(ctx.cacheDir, "${ConverterEngine.baseName(s.name)}-$tag-${System.currentTimeMillis()}.mp4")
                    runMedia(out, "video/mp4") { l -> ConverterEngine.startVideoExport(ctx, s.uri, if (h > 0) h else null, out, l, removeAudio = vidMode == 2) }
                }
            }
        }
    }

    PowerToolPage("converter") {
        HPrimaryButton("Choose a file", icon = Icons.Outlined.InsertDriveFile) { pickOne.launch(arrayOf("*/*")) }
        Spacer(Modifier.height(HandyTokens.Space8))
        HSecondaryButton("Choose several photos (batch)") {
            pickPhotos.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
        NoteText("One file — image, PDF, audio or video — for the full conversion options, or several photos at once to batch-convert or combine into one PDF. Everything runs on your phone and costs nothing.")

        if (inspecting) {
            Spacer(Modifier.height(HandyTokens.Space16))
            LinearProgressIndicator(Modifier.fillMaxWidth(), color = HandyColors.Accent)
        }

        val b = batch
        val s = single

        // ---- picked summary ----
        if (b != null) {
            Spacer(Modifier.height(HandyTokens.Space12))
            val sub = "Convert each, or combine into one PDF" +
                if (skipped > 0) " · $skipped non-image file${if (skipped == 1) "" else "s"} skipped — convert those one at a time" else ""
            PickedCard("${b.size} image${if (b.size == 1) "" else "s"} selected", sub)
        } else if (s != null && s.typeLabel.isNotEmpty()) {
            Spacer(Modifier.height(HandyTokens.Space12))
            PickedCard(s.name, s.typeLabel + (srcSizeText?.let { " · $it" } ?: ""))
        }

        // ---- target chooser ----
        val category = when {
            b != null -> ConverterEngine.Category.IMAGE
            s != null && s.typeLabel.isNotEmpty() -> s.category
            else -> null
        }

        when (category) {
            ConverterEngine.Category.IMAGE -> {
                SectionLabel("Convert to")
                ChipRow {
                    IMAGE_FORMATS.forEachIndexed { i, f -> HChip(f.label, imgTarget == i) { imgTarget = i; reset() } }
                    HChip(if (b != null) "Combine → PDF" else "PDF", imgTarget == PDF_TARGET) { imgTarget = PDF_TARGET; reset() }
                }
                if (imgTarget == 1 || imgTarget == 2 || imgTarget == PDF_TARGET) {
                    SliderRow("Quality", "${quality.toInt()}", quality, { quality = it }, 20f..100f)
                }
            }
            ConverterEngine.Category.PDF -> {
                SectionLabel("Convert pages to")
                ChipRow {
                    HChip("PNG", pdfTarget == 0) { pdfTarget = 0; reset() }
                    HChip("JPEG", pdfTarget == 1) { pdfTarget = 1; reset() }
                }
                if (pdfTarget == 1) SliderRow("Quality", "${quality.toInt()}", quality, { quality = it }, 20f..100f)
            }
            ConverterEngine.Category.AUDIO -> {
                SectionLabel("Convert to")
                ChipRow {
                    HChip("M4A (AAC)", true) { }
                }
            }
            ConverterEngine.Category.VIDEO -> {
                SectionLabel("Convert to")
                ChipRow {
                    HChip("MP4 video", vidMode == 0) { vidMode = 0; reset() }
                    HChip("Muted MP4", vidMode == 2) { vidMode = 2; reset() }
                    HChip("Audio only · M4A", vidMode == 1) { vidMode = 1; reset() }
                }
                if (vidMode != 1) {
                    SectionLabel("Resolution (H.264)")
                    ChipRow {
                        VIDEO_TARGETS.forEachIndexed { i, (label, _) -> HChip(label, vidTarget == i) { vidTarget = i; reset() } }
                    }
                }
            }
            ConverterEngine.Category.OTHER -> {
                Spacer(Modifier.height(HandyTokens.Space8))
                NoteText("I can't convert a \"${s?.typeLabel ?: "file"}\" yet — the converter handles images, PDFs, audio and video. Open it in the File Viewer to read it, or pick a different file.")
            }
            null -> {}
        }

        // ---- convert button ----
        if (category != null && category != ConverterEngine.Category.OTHER) {
            Spacer(Modifier.height(HandyTokens.Space16))
            HPrimaryButton(if (working) "Converting…" else "Convert", enabled = !working) { convert() }
        }

        // ---- progress ----
        if (working) {
            Spacer(Modifier.height(HandyTokens.Space12))
            val p = progress
            if (p != null) LinearProgressIndicator(progress = { p }, modifier = Modifier.fillMaxWidth(), color = HandyColors.Accent)
            else LinearProgressIndicator(modifier = Modifier.fillMaxWidth(), color = HandyColors.Accent)
            val pct = progress
            if (pct != null) NoteText("${(pct * 100).toInt()}%")
        }

        // ---- error ----
        error?.let {
            Spacer(Modifier.height(HandyTokens.Space12))
            Text(it, style = MaterialTheme.typography.bodyMedium, color = HandyColors.Danger)
        }

        // ---- result ----
        val out = results
        if (!working && out != null) {
            Spacer(Modifier.height(HandyTokens.Space16))
            HCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(HandyTokens.Space16)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Outlined.PhotoLibrary, null, Modifier.size(28.dp), tint = HandyColors.Success)
                        Spacer(Modifier.width(HandyTokens.Space12))
                        Column(Modifier.weight(1f)) {
                            Text("Converted", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                            resultSummary?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary) }
                        }
                    }
                    // Preview the actual output before saving/sharing — a thumbnail of the first result.
                    Spacer(Modifier.height(HandyTokens.Space12))
                    ConvertedPreview(out.first(), resultMime, extra = out.size - 1)
                    Spacer(Modifier.height(HandyTokens.Space12))
                    if (out.size == 1) {
                        HPrimaryButton("Save", icon = Icons.Outlined.Download) { saver.launch(out.first().name) }
                    } else {
                        HPrimaryButton("Save all ${out.size}", icon = Icons.Outlined.Download) { saveTree.launch(null) }
                    }
                    Spacer(Modifier.height(HandyTokens.Space8))
                    HSecondaryButton(if (out.size == 1) "Share" else "Share all ${out.size}") {
                        if (out.size == 1) Share.file(ctx, out.first(), resultMime) else Share.files(ctx, out, resultMime)
                    }
                    if (out.size > 1) NoteText("“Save all” writes every file to a folder you pick; Share hands them all over at once.")
                    savedNote?.let { NoteText(it) }
                }
            }
        }
    }
}

/** Preview of the converted output — an image/PDF-page/video-frame thumbnail, so the user sees the
 *  real result before saving or sharing. Falls back to a labelled tile for audio / unpreviewable types. */
@Composable
private fun ConvertedPreview(file: File, mime: String, extra: Int) {
    val ctx = LocalContext.current
    var bmp by remember(file.path, mime) { mutableStateOf<android.graphics.Bitmap?>(null) }
    var loading by remember(file.path, mime) { mutableStateOf(true) }
    LaunchedEffect(file.path, mime) {
        bmp = withContext(Dispatchers.IO) { loadPreviewBitmap(file, mime) }
        loading = false
    }
    Box(
        Modifier.fillMaxWidth().height(200.dp).clip(RoundedCornerShape(12.dp))
            .background(if (Handy.palette.isDark) Color(0xFF101014) else Color(0xFFEFF0F6)),
        contentAlignment = Alignment.Center
    ) {
        val b = bmp
        when {
            loading -> CircularProgressIndicator(color = HandyColors.Accent)
            b != null -> Image(b.asImageBitmap(), "Converted preview", Modifier.fillMaxWidth().height(200.dp), contentScale = ContentScale.Fit)
            mime.startsWith("audio/") -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Outlined.GraphicEq, null, Modifier.size(40.dp), tint = HandyColors.Accent)
                Spacer(Modifier.height(HandyTokens.Space8))
                Text("Audio ready — tap Share to play", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
            }
            else -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Outlined.InsertDriveFile, null, Modifier.size(40.dp), tint = HandyColors.Accent)
                Spacer(Modifier.height(HandyTokens.Space8))
                Text("Ready to save", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            }
        }
        if (extra > 0) {
            Box(
                Modifier.align(Alignment.BottomEnd).padding(HandyTokens.Space8)
                    .clip(RoundedCornerShape(50)).background(Color(0xCC000000)).padding(horizontal = 10.dp, vertical = 4.dp)
            ) { Text("+$extra more", style = MaterialTheme.typography.labelSmall, color = Color.White) }
        }
    }
}

/** Decode a small preview bitmap for the converted output, off the main thread. */
private fun loadPreviewBitmap(file: File, mime: String): android.graphics.Bitmap? = runCatching {
    when {
        mime.startsWith("image/") -> {
            val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.path, o)
            val sample = (maxOf(o.outWidth, o.outHeight) / 1200).coerceAtLeast(1)
            BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample })
        }
        mime == "application/pdf" -> {
            android.os.ParcelFileDescriptor.open(file, android.os.ParcelFileDescriptor.MODE_READ_ONLY).use { pfd ->
                android.graphics.pdf.PdfRenderer(pfd).use { r ->
                    if (r.pageCount == 0) null else r.openPage(0).use { pg ->
                        val w = 1240; val h = (w * pg.height.toFloat() / pg.width.coerceAtLeast(1)).toInt().coerceAtLeast(1)
                        val out = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
                        out.eraseColor(android.graphics.Color.WHITE)
                        pg.render(out, null, null, android.graphics.pdf.PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        out
                    }
                }
            }
        }
        mime.startsWith("video/") -> {
            val mr = android.media.MediaMetadataRetriever()
            try { mr.setDataSource(file.path); mr.getFrameAtTime(0) } finally { mr.release() }
        }
        else -> null
    }
}.getOrNull()

@Composable
private fun PickedCard(title: String, subtitle: String) {
    HCard(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(HandyTokens.Space16)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Outlined.InsertDriveFile, null, Modifier.size(28.dp), tint = HandyColors.Accent)
                Spacer(Modifier.width(HandyTokens.Space12))
                Column(Modifier.weight(1f)) {
                    Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface, maxLines = 2)
                    Text(subtitle, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                }
            }
        }
    }
}
