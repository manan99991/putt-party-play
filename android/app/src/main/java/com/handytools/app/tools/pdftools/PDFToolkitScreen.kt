package com.handytools.app.tools.pdftools

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.graphics.pdf.PdfDocument
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

/** Photos → PDF, merge PDFs, and compress a PDF — no watermark. */
@Composable
fun PDFToolkitScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var mode by remember { mutableIntStateOf(0) }  // 0 images, 1 merge, 2 compress
    var images by remember { mutableStateOf<List<Uri>>(emptyList()) }
    var pdfs by remember { mutableStateOf<List<Uri>>(emptyList()) }
    var working by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }
    val overQuota = !Usage.hasRoom(ctx, "pdftools", Limits.FREE_PDF_OPS_PER_DAY)

    val imgPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(20)) { images = it; status = null }
    val pdfPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetMultipleContents()) { pdfs = it; status = null }

    fun reset() { images = emptyList(); pdfs = emptyList(); status = null }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("PDF Toolkit", "Photos → PDF, merge, and compress — no watermark.")
        Spacer(Modifier.size(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            HChip("Photos → PDF", mode == 0) { mode = 0; reset() }
            HChip("Merge", mode == 1) { mode = 1; reset() }
            HChip("Compress", mode == 2) { mode = 2; reset() }
        }
        Spacer(Modifier.size(12.dp))
        if (mode == 0) {
            HPrimaryButton(if (images.isEmpty()) "Pick photos" else "${images.size} photos", modifier = Modifier.fillMaxWidth()) {
                imgPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            }
        } else {
            HPrimaryButton(if (pdfs.isEmpty()) "Pick PDF${if (mode == 1) "s" else ""}" else "${pdfs.size} PDF(s)", modifier = Modifier.fillMaxWidth()) {
                pdfPicker.launch("application/pdf")
            }
        }

        val canRun = if (mode == 0) images.isNotEmpty() else if (mode == 1) pdfs.size >= 2 else pdfs.size == 1
        if (overQuota) Text("You've done today's ${Limits.FREE_PDF_OPS_PER_DAY} free PDF jobs. Go Pro for unlimited.",
            style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))
        Spacer(Modifier.size(12.dp))
        HPrimaryButton(if (working) "Working…" else listOf("Make PDF", "Merge PDFs", "Compress PDF")[mode],
            enabled = !working && !overQuota && canRun, modifier = Modifier.fillMaxWidth()) {
            if (!Usage.use(ctx, "pdftools", Limits.FREE_PDF_OPS_PER_DAY)) return@HPrimaryButton
            working = true; status = null
            scope.launch {
                val file = withContext(Dispatchers.IO) {
                    when (mode) {
                        0 -> imagesToPdf(ctx, images)
                        1 -> merge(ctx, pdfs)
                        else -> compress(ctx, pdfs.first())
                    }
                }
                working = false
                if (file != null) { status = "Done · ${file.length() / 1024} KB"; Share.file(ctx, file, "application/pdf") }
                else status = "Couldn't complete that. Check the files and try again."
            }
        }
        status?.let { Text(it, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 12.dp)) }
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

private fun outFile(ctx: Context) = File(ctx.cacheDir, "Tenzy-${System.currentTimeMillis()}.pdf")

private fun imagesToPdf(ctx: Context, uris: List<Uri>): File? {
    if (uris.isEmpty()) return null
    val doc = PdfDocument()
    uris.forEachIndexed { i, uri ->
        val bmp = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) } ?: return@forEachIndexed
        val page = doc.startPage(PdfDocument.PageInfo.Builder(612, 792, i + 1).create())
        val c = page.canvas
        c.drawColor(Color.WHITE)
        val box = Rect(24, 24, 588, 768)
        val scale = minOf(box.width().toFloat() / bmp.width, box.height().toFloat() / bmp.height)
        val w = (bmp.width * scale).toInt(); val h = (bmp.height * scale).toInt()
        val left = box.centerX() - w / 2; val top = box.centerY() - h / 2
        c.drawBitmap(bmp, null, Rect(left, top, left + w, top + h), null)
        doc.finishPage(page)
    }
    val f = outFile(ctx)
    FileOutputStream(f).use { doc.writeTo(it) }; doc.close()
    return f
}

private fun eachPage(ctx: Context, uri: Uri, scale: Float, block: (Bitmap, Int) -> Unit) {
    val pfd = ctx.contentResolver.openFileDescriptor(uri, "r") ?: return
    pfd.use {
        val renderer = PdfRenderer(it)
        for (i in 0 until renderer.pageCount) {
            val page = renderer.openPage(i)
            val bmp = Bitmap.createBitmap((page.width * scale).toInt().coerceAtLeast(1), (page.height * scale).toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
            bmp.eraseColor(Color.WHITE)
            page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            block(bmp, i)
            page.close()
        }
        renderer.close()
    }
}

private fun merge(ctx: Context, uris: List<Uri>): File? {
    if (uris.size < 2) return null
    val doc = PdfDocument(); var n = 0
    uris.forEach { uri ->
        eachPage(ctx, uri, 2f) { bmp, _ ->
            val page = doc.startPage(PdfDocument.PageInfo.Builder(bmp.width, bmp.height, ++n).create())
            page.canvas.drawBitmap(bmp, 0f, 0f, null)
            doc.finishPage(page)
        }
    }
    if (n == 0) return null
    val f = outFile(ctx)
    FileOutputStream(f).use { doc.writeTo(it) }; doc.close()
    return f
}

private fun compress(ctx: Context, uri: Uri): File? {
    val doc = PdfDocument(); var n = 0
    eachPage(ctx, uri, 1.3f) { bmp, _ ->
        // JPEG round-trip shrinks image-heavy pages.
        val jpeg = java.io.ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.JPEG, 50, it) }.toByteArray()
        val small = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)
        val page = doc.startPage(PdfDocument.PageInfo.Builder(small.width, small.height, ++n).create())
        page.canvas.drawBitmap(small, 0f, 0f, null)
        doc.finishPage(page)
    }
    if (n == 0) return null
    val f = outFile(ctx)
    FileOutputStream(f).use { doc.writeTo(it) }; doc.close()
    return f
}
