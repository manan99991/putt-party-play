package com.handytools.app.tools.signfill

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.ToolHeader
import java.io.File
import java.io.FileOutputStream

private class Stroke2(val points: MutableList<Offset>, val argb: Int)

/**
 * Doc Signer. Opens a PDF (first page) or an image, lets you sign and mark it up by hand, and
 * exports a flattened PDF you can share or save. On-device only — the document never leaves the
 * phone. Replaces the old "Coming soon" tile, so tapping Sign & Fill now does the real thing.
 */
@Composable
fun DocSignerScreen() {
    val ctx = LocalContext.current
    var page by remember { mutableStateOf<Bitmap?>(null) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var boxSize by remember { mutableStateOf(IntSize.Zero) }
    val strokes = remember { mutableStateListOf<Stroke2>() }
    var current by remember { mutableStateOf<Stroke2?>(null) }
    var inkArgb by remember { mutableStateOf(0xFF111111.toInt()) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        loading = true; error = null; strokes.clear(); current = null
        try {
            page = loadDocument(ctx, uri)
            if (page == null) error = "Couldn't open that file. Try a PDF or an image."
        } catch (e: Exception) {
            error = "Couldn't open that file. Try a PDF or an image."
        }
        loading = false
    }

    fun export() {
        val bmp = page ?: return
        val box = boxSize
        if (box.width == 0 || box.height == 0) return
        try {
            val out = File(ctx.cacheDir, "signed_${System.currentTimeMillis()}.pdf")
            val doc = PdfDocument()
            val info = PdfDocument.PageInfo.Builder(bmp.width, bmp.height, 1).create()
            val pg = doc.startPage(info)
            val c = pg.canvas
            c.drawBitmap(bmp, 0f, 0f, null)
            val sx = bmp.width.toFloat() / box.width
            val sy = bmp.height.toFloat() / box.height
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND
                strokeWidth = 3.5f * sx
            }
            strokes.forEach { s ->
                paint.color = s.argb
                val p = android.graphics.Path()
                s.points.forEachIndexed { i, o ->
                    val x = o.x * sx; val y = o.y * sy
                    if (i == 0) p.moveTo(x, y) else p.lineTo(x, y)
                }
                c.drawPath(p, paint)
            }
            doc.finishPage(pg)
            FileOutputStream(out).use { doc.writeTo(it) }
            doc.close()
            Share.file(ctx, out, "application/pdf")
            HandyHaptics.success(ctx)
        } catch (e: Exception) {
            error = "Couldn't save the PDF. Please try again."
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Sign & Fill", "Open a PDF or photo of a form, sign and mark it up with your finger, then export a flattened PDF.")
        Spacer(Modifier.size(16.dp))

        val bmp = page
        if (bmp == null) {
            Text(
                if (loading) "Opening…"
                else error ?: "Choose a document to get started. PDFs open to the first page; photos of a form work too.",
                color = if (error != null) HandyColors.Accent else Handy.palette.textSecondary
            )
            Spacer(Modifier.size(16.dp))
            HPrimaryButton("Choose a document", enabled = !loading) {
                picker.launch(arrayOf("application/pdf", "image/*"))
            }
            Spacer(Modifier.weight(1f))
        } else {
            // Ink color chips.
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                HChip("Black ink", inkArgb == 0xFF111111.toInt()) { inkArgb = 0xFF111111.toInt() }
                HChip("Blue ink", inkArgb == 0xFF1F5EFF.toInt()) { inkArgb = 0xFF1F5EFF.toInt() }
            }
            Spacer(Modifier.size(10.dp))

            Box(
                Modifier.fillMaxWidth()
                    .aspectRatio(bmp.width.toFloat() / bmp.height)
                    .background(Color.White)
                    .onSizeChanged { boxSize = it },
                contentAlignment = Alignment.Center
            ) {
                Image(bmp.asImageBitmap(), contentDescription = "Document", modifier = Modifier.fillMaxSize())
                Canvas(
                    Modifier.fillMaxSize().pointerInput(inkArgb) {
                        detectDragGestures(
                            onDragStart = { current = Stroke2(mutableListOf(it), inkArgb) },
                            onDrag = { change, _ -> current?.points?.add(change.position); change.consume() },
                            onDragEnd = { current?.let { strokes.add(it) }; current = null },
                            onDragCancel = { current = null }
                        )
                    }
                ) {
                    (strokes + listOfNotNull(current)).forEach { s ->
                        if (s.points.size > 1) {
                            val path = Path()
                            path.moveTo(s.points[0].x, s.points[0].y)
                            for (i in 1 until s.points.size) path.lineTo(s.points[i].x, s.points[i].y)
                            drawPath(
                                path, Color(s.argb),
                                style = Stroke(width = 3.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.size(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                HSecondaryButton("Undo", modifier = Modifier.weight(1f), enabled = strokes.isNotEmpty()) {
                    if (strokes.isNotEmpty()) strokes.removeAt(strokes.lastIndex); HandyHaptics.light(ctx)
                }
                HSecondaryButton("Clear", modifier = Modifier.weight(1f), enabled = strokes.isNotEmpty()) {
                    strokes.clear(); HandyHaptics.light(ctx)
                }
            }
            Spacer(Modifier.size(8.dp))
            HPrimaryButton("Export signed PDF") { export() }
            Spacer(Modifier.size(16.dp))
        }

        BannerAd()
    }
}

/** Load a PDF's first page or an image into a bitmap, scaled so the long edge is ~1600px. */
private fun loadDocument(ctx: android.content.Context, uri: Uri): Bitmap? {
    val type = ctx.contentResolver.getType(uri) ?: ""
    if (type == "application/pdf") {
        val pfd = ctx.contentResolver.openFileDescriptor(uri, "r") ?: return null
        pfd.use {
            PdfRenderer(it).use { renderer ->
                if (renderer.pageCount == 0) return null
                renderer.openPage(0).use { p ->
                    val scale = 1600f / maxOf(p.width, p.height)
                    val w = (p.width * scale).toInt().coerceAtLeast(1)
                    val h = (p.height * scale).toInt().coerceAtLeast(1)
                    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                    bmp.eraseColor(android.graphics.Color.WHITE)
                    p.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    return bmp
                }
            }
        }
    } else {
        ctx.contentResolver.openInputStream(uri)?.use { input ->
            val raw = BitmapFactory.decodeStream(input) ?: return null
            val scale = 1600f / maxOf(raw.width, raw.height)
            if (scale >= 1f) return raw.copy(Bitmap.Config.ARGB_8888, false)
            val w = (raw.width * scale).toInt().coerceAtLeast(1)
            val h = (raw.height * scale).toInt().coerceAtLeast(1)
            return Bitmap.createScaledBitmap(raw, w, h, true)
        }
    }
    return null
}
