package com.handytools.app.tools.redact

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Paint
import android.graphics.Rect
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
import java.io.FileOutputStream

private val sensitive = Regex("""(\d[\d ().\-]{3,}\d)|([A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})""")

/**
 * Redact. Pick a screenshot or photo; numbers and email addresses are found on-device and blacked
 * out automatically, and you can tap anywhere (a face, a signature, an address) to add your own
 * black box. Export a flattened copy with the hidden parts permanently removed. Nothing is uploaded.
 */
@Composable
fun RedactScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var bmp by remember { mutableStateOf<Bitmap?>(null) }
    var autoOn by remember { mutableStateOf(true) }
    var busy by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }
    val autoRects = remember { mutableStateListOf<Rect>() }
    val manualRects = remember { mutableStateListOf<Rect>() }

    val recognizer = remember { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        busy = true; status = null; autoRects.clear(); manualRects.clear(); bmp = null
        scope.launch {
            val loaded = withContext(Dispatchers.IO) {
                try {
                    val b = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) }
                        ?: return@withContext null
                    val found = ArrayList<Rect>()
                    val vt = recognizer.process(InputImage.fromBitmap(b, 0)).await()
                    for (block in vt.textBlocks) for (line in block.lines) for (el in line.elements) {
                        if (sensitive.containsMatchIn(el.text)) el.boundingBox?.let { found.add(it) }
                    }
                    b to found
                } catch (e: Exception) { null }
            }
            busy = false
            if (loaded == null) { status = "Couldn't open that image."; return@launch }
            bmp = loaded.first
            autoRects.addAll(loaded.second)
            HandyHaptics.light(ctx)
        }
    }

    fun export() {
        val src = bmp ?: return
        busy = true
        scope.launch {
            val out = withContext(Dispatchers.IO) {
                try {
                    val copy = src.copy(Bitmap.Config.ARGB_8888, true)
                    val c = android.graphics.Canvas(copy)
                    val p = Paint().apply { color = android.graphics.Color.BLACK }
                    if (autoOn) autoRects.forEach { c.drawRect(it, p) }
                    manualRects.forEach { c.drawRect(it, p) }
                    val f = File(ctx.cacheDir, "redacted_${System.currentTimeMillis()}.jpg")
                    FileOutputStream(f).use { copy.compress(Bitmap.CompressFormat.JPEG, 92, it) }
                    f
                } catch (e: Exception) { null }
            }
            busy = false
            if (out != null) { Share.file(ctx, out, "image/jpeg"); HandyHaptics.success(ctx) }
            else status = "Couldn't export. Try a smaller image."
        }
    }

    Column(
        Modifier.fillMaxWidth().statusBarsPadding().padding(20.dp).verticalScroll(rememberScrollState())
    ) {
        ToolHeader("Redact", "Black out numbers, faces and anything private before you share a screenshot or photo.")
        Spacer(Modifier.size(16.dp))

        HPrimaryButton(if (busy) "Working…" else "Choose an image", modifier = Modifier.fillMaxWidth(), enabled = !busy) {
            picker.launch("image/*")
        }
        status?.let { Spacer(Modifier.size(10.dp)); Text(it, color = Handy.palette.textSecondary, fontSize = 13.sp) }

        val current = bmp
        if (current != null) {
            Spacer(Modifier.size(14.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Auto-hide numbers & emails (${autoRects.size})", color = MaterialTheme.colorScheme.onBackground, fontSize = 14.sp)
                Switch(checked = autoOn, onCheckedChange = { autoOn = it })
            }
            Spacer(Modifier.size(6.dp))
            Text("Tap the image to add a box over a face or anything else. Tap a box again to remove it.", color = Handy.palette.textSecondary, fontSize = 12.sp)
            Spacer(Modifier.size(10.dp))

            BoxWithConstraints(Modifier.fillMaxWidth()) {
                val wPx = with(LocalDensity.current) { maxWidth.toPx() }
                val scale = current.width / wPx // bitmap px per screen px
                Box(
                    Modifier.fillMaxWidth().aspectRatio(current.width.toFloat() / current.height)
                        .pointerInput(current) {
                            detectTapGestures { off ->
                                val bx = (off.x * scale).toInt()
                                val by = (off.y * scale).toInt()
                                val hitIdx = manualRects.indexOfFirst { it.contains(bx, by) }
                                if (hitIdx >= 0) manualRects.removeAt(hitIdx)
                                else {
                                    val half = (current.width * 0.09f).toInt().coerceAtLeast(12)
                                    manualRects.add(Rect(bx - half, by - half, bx + half, by + half))
                                }
                                HandyHaptics.light(ctx)
                            }
                        }
                ) {
                    Image(current.asImageBitmap(), contentDescription = "Image to redact", modifier = Modifier.matchParentSize())
                    Canvas(Modifier.matchParentSize()) {
                        val rects = (if (autoOn) autoRects else emptyList()) + manualRects
                        for (r in rects) {
                            drawRect(
                                Color.Black,
                                topLeft = Offset(r.left / scale, r.top / scale),
                                size = Size(r.width() / scale, r.height() / scale),
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.size(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                if (manualRects.isNotEmpty()) HSecondaryButton("Undo my boxes", modifier = Modifier.weight(1f)) { manualRects.clear() }
                HSecondaryButton("Export", modifier = Modifier.weight(1f), enabled = !busy) { export() }
            }
        }

        Spacer(Modifier.size(16.dp))
        Text(
            "The exported image is flattened — the black boxes are burned in, so the hidden pixels are gone for good. All on your phone; nothing is uploaded.",
            color = Handy.palette.textSecondary, fontSize = 12.sp,
        )
        Spacer(Modifier.size(16.dp))
        BannerAd()
    }
}
