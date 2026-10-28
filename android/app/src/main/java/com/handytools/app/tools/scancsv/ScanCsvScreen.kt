package com.handytools.app.tools.scancsv

import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.dp
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Scan to Table / CSV. Snap or pick a photo of a receipt, list or simple table; the text is read
 * on-device, grouped into rows by line position and columns by left-to-right order, and shown as an
 * editable CSV you can fix before saving or sharing a .csv file. Runs entirely on the phone.
 */
@Composable
fun ScanCsvScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var csv by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }

    val recognizer = remember { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        busy = true; status = null; csv = ""
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                try {
                    val bmp = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) }
                        ?: return@withContext null
                    buildCsv(recognizer.process(InputImage.fromBitmap(bmp, 0)).await())
                } catch (e: Exception) { null }
            }
            busy = false
            if (result == null) status = "Couldn't read that image. Try a clearer, straight-on photo."
            else if (result.isBlank()) status = "No text found. Try a clearer, straight-on photo."
            else { csv = result; HandyHaptics.success(ctx) }
        }
    }

    fun export() {
        if (csv.isBlank()) return
        val file = File(ctx.cacheDir, "table_${System.currentTimeMillis()}.csv")
        file.writeText(csv)
        Share.file(ctx, file, "text/csv")
        HandyHaptics.light(ctx)
    }

    Column(
        Modifier.fillMaxWidth().statusBarsPadding().padding(20.dp).verticalScroll(rememberScrollState())
    ) {
        ToolHeader("Scan to Table / CSV", "Photograph a receipt, list or table and turn it into a spreadsheet-ready CSV you can edit and share.")
        Spacer(Modifier.size(16.dp))

        HPrimaryButton(if (busy) "Reading…" else "Choose a photo", modifier = Modifier.fillMaxWidth(), enabled = !busy) {
            picker.launch("image/*")
        }
        status?.let { Spacer(Modifier.size(10.dp)); Text(it, color = Handy.palette.textSecondary, fontSize = 13.sp) }

        if (csv.isNotBlank()) {
            Spacer(Modifier.size(16.dp))
            Text("Rows & columns (comma-separated). Fix anything the scan got wrong:", color = Handy.palette.textSecondary, fontSize = 13.sp)
            Spacer(Modifier.size(8.dp))
            OutlinedTextField(
                value = csv,
                onValueChange = { csv = it },
                modifier = Modifier.fillMaxWidth(),
                minLines = 6,
            )
            Spacer(Modifier.size(12.dp))
            HSecondaryButton("Save & share .csv", modifier = Modifier.fillMaxWidth()) { export() }
        }

        Spacer(Modifier.size(16.dp))
        Text(
            "Reads text on your phone — the photo is never uploaded. OCR isn't perfect, so check the values before you rely on them.",
            color = Handy.palette.textSecondary, fontSize = 12.sp,
        )
        Spacer(Modifier.size(16.dp))
        BannerAd()
    }
}

/** Group recognised lines into rows by vertical position, cells left-to-right, as escaped CSV. */
private fun buildCsv(vt: com.google.mlkit.vision.text.Text): String {
    data class Cell(val text: String, val left: Int, val top: Int, val height: Int)
    val cells = ArrayList<Cell>()
    for (block in vt.textBlocks) for (line in block.lines) {
        val r = line.boundingBox ?: continue
        if (line.text.isBlank()) continue
        cells.add(Cell(line.text.trim(), r.left, r.top, r.height()))
    }
    if (cells.isEmpty()) return ""
    val heights = cells.map { it.height }.sorted()
    val medianH = heights[heights.size / 2].toDouble().coerceAtLeast(1.0)
    val tol = 0.6 * medianH
    val sorted = cells.sortedBy { it.top + it.height / 2.0 }
    val rows = ArrayList<MutableList<Cell>>()
    var cur = mutableListOf(sorted[0])
    var lastCenter = sorted[0].top + sorted[0].height / 2.0
    for (c in sorted.drop(1)) {
        val cy = c.top + c.height / 2.0
        if (cy - lastCenter > tol) { rows.add(cur); cur = mutableListOf(c) } else cur.add(c)
        lastCenter = cy
    }
    rows.add(cur)
    return rows.joinToString("\n") { row ->
        row.sortedBy { it.left }.joinToString(",") { esc(it.text) }
    }
}

private fun esc(v: String): String =
    if (v.any { it == ',' || it == '"' || it == '\n' || it == '\r' }) "\"" + v.replace("\"", "\"\"") + "\"" else v
