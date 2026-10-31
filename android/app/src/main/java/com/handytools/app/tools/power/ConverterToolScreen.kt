package com.handytools.app.tools.power

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material.icons.outlined.InsertDriveFile
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
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
    var inspecting by remember { mutableStateOf(false) }

    var imgTarget by remember { mutableIntStateOf(1) }    // default JPEG
    var pdfTarget by remember { mutableIntStateOf(0) }    // 0 = PNG, 1 = JPEG
    var vidTarget by remember { mutableIntStateOf(1) }    // default 720p
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

    val pickOne = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { picked ->
        if (picked != null) { batch = null; single = null; reset(); single = ConverterEngine.Src(picked, "", ConverterEngine.Category.OTHER, "") }
    }
    val pickImages = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { picked ->
        if (!picked.isNullOrEmpty()) { single = null; reset(); batch = picked }
    }

    // Identify a single pick off the main thread, then settle its real metadata.
    LaunchedEffect(single?.uri) {
        val u = single?.uri ?: return@LaunchedEffect
        if (single?.typeLabel?.isNotEmpty() == true) return@LaunchedEffect
        inspecting = true
        val s = withContext(Dispatchers.IO) { ConverterEngine.inspect(ctx, u) }
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
                val h = VIDEO_TARGETS[vidTarget].second
                val out = File(ctx.cacheDir, "${ConverterEngine.baseName(s.name)}-${if (h > 0) "${h}p" else "mp4"}-${System.currentTimeMillis()}.mp4")
                runMedia(out, "video/mp4") { l -> ConverterEngine.startVideoExport(ctx, s.uri, if (h > 0) h else null, out, l) }
            }
        }
    }

    PowerToolPage("converter") {
        HPrimaryButton("Choose a file", icon = Icons.Outlined.InsertDriveFile) { pickOne.launch(arrayOf("*/*")) }
        Spacer(Modifier.height(HandyTokens.Space8))
        HSecondaryButton("Choose images (batch or combine to PDF)") { pickImages.launch(arrayOf("image/*")) }
        NoteText("Images (PNG/JPEG/WEBP, HEIC in), images ↔ PDF, and audio/video transcode. It all runs on your phone and costs nothing.")

        if (inspecting) {
            Spacer(Modifier.height(HandyTokens.Space16))
            LinearProgressIndicator(Modifier.fillMaxWidth(), color = HandyColors.Accent)
        }

        val b = batch
        val s = single

        // ---- picked summary ----
        if (b != null) {
            Spacer(Modifier.height(HandyTokens.Space12))
            PickedCard("${b.size} image${if (b.size == 1) "" else "s"} selected", "Convert each, or combine into one PDF")
        } else if (s != null && s.typeLabel.isNotEmpty()) {
            Spacer(Modifier.height(HandyTokens.Space12))
            PickedCard(s.name, s.typeLabel)
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
                SectionLabel("MP4 (H.264) · size")
                ChipRow {
                    VIDEO_TARGETS.forEachIndexed { i, (label, _) -> HChip(label, vidTarget == i) { vidTarget = i; reset() } }
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
                    Spacer(Modifier.height(HandyTokens.Space12))
                    HPrimaryButton(if (out.size == 1) "Save" else "Save first file", icon = Icons.Outlined.Download) {
                        val f = out.first()
                        saver.launch(f.name)
                    }
                    Spacer(Modifier.height(HandyTokens.Space8))
                    HSecondaryButton(if (out.size == 1) "Share" else "Share all ${out.size}") {
                        if (out.size == 1) Share.file(ctx, out.first(), resultMime) else Share.files(ctx, out, resultMime)
                    }
                    if (out.size > 1) NoteText("Share hands over all ${out.size} files at once; Save stores the first.")
                    savedNote?.let { NoteText(it) }
                }
            }
        }
    }
}

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
