package com.handytools.app.tools.idphoto

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

private data class Spec(val label: String, val w: Int, val h: Int)

// 300 dpi print sizes
private val SPECS = listOf(
    Spec("US 2×2 in", 600, 600),
    Spec("UK / EU 35×45 mm", 413, 531),
    Spec("India 51×51 mm", 602, 602),
)

/**
 * Passport / ID Photo. Pick a head-and-shoulders photo; the subject is cut out on-device, placed on
 * a clean white background and sized to a standard print spec you can send to a print shop. A helper
 * to get the framing and background right — always check your authority's exact requirements.
 */
@Composable
fun PassportPhotoScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var spec by remember { mutableStateOf(SPECS[0]) }
    var result by remember { mutableStateOf<Bitmap?>(null) }
    var busy by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }

    fun process(uri: Uri) {
        busy = true; status = null; result = null
        scope.launch {
            val out = withContext(Dispatchers.IO) {
                try {
                    val src = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) }
                        ?: return@withContext null
                    val segmenter = SubjectSegmentation.getClient(
                        SubjectSegmenterOptions.Builder().enableForegroundBitmap().build()
                    )
                    val fg = try {
                        segmenter.process(InputImage.fromBitmap(src, 0)).await().foregroundBitmap
                    } finally { segmenter.close() }
                    if (fg == null) null else composeIdPhoto(fg, spec)
                } catch (e: Exception) { null }
            }
            busy = false
            if (out == null) status = "Couldn't find a clear person in that photo. Use a plain, well-lit head-and-shoulders shot."
            else { result = out; HandyHaptics.success(ctx) }
        }
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { u: Uri? ->
        if (u != null) process(u)
    }

    fun export() {
        val bmp = result ?: return
        val file = File(ctx.cacheDir, "id_photo_${System.currentTimeMillis()}.jpg")
        FileOutputStream(file).use { bmp.compress(Bitmap.CompressFormat.JPEG, 95, it) }
        Share.file(ctx, file, "image/jpeg")
        HandyHaptics.light(ctx)
    }

    Column(
        Modifier.fillMaxWidth().statusBarsPadding().padding(20.dp).verticalScroll(rememberScrollState())
    ) {
        ToolHeader("Passport / ID Photo", "Turn a head-and-shoulders photo into a white-background ID photo at the right print size.")
        Spacer(Modifier.size(16.dp))

        Text("Size", color = Handy.palette.textSecondary, fontSize = 13.sp)
        Spacer(Modifier.size(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SPECS.forEach { s -> HChip(s.label, s == spec) { spec = s; result = null } }
        }

        Spacer(Modifier.size(16.dp))
        HPrimaryButton(if (busy) "Processing…" else "Choose a photo", modifier = Modifier.fillMaxWidth(), enabled = !busy) {
            picker.launch("image/*")
        }
        status?.let { Spacer(Modifier.size(10.dp)); Text(it, color = Handy.palette.textSecondary, fontSize = 13.sp) }

        result?.let { bmp ->
            Spacer(Modifier.size(16.dp))
            Image(bmp.asImageBitmap(), contentDescription = "ID photo preview", modifier = Modifier.fillMaxWidth().heightIn(max = 360.dp))
            Spacer(Modifier.size(12.dp))
            HSecondaryButton("Save & share", modifier = Modifier.fillMaxWidth()) { export() }
        }

        Spacer(Modifier.size(16.dp))
        Text(
            "Cut out on your phone — the photo is never uploaded. This gets the background and size right; always double-check your passport/visa authority's exact rules (expression, glasses, head height) before printing.",
            color = Handy.palette.textSecondary, fontSize = 12.sp,
        )
        Spacer(Modifier.size(16.dp))
        BannerAd()
    }
}

/** Place the cut-out subject, centred, on a white canvas of the spec size with standard headroom. */
private fun composeIdPhoto(fg: Bitmap, spec: Spec): Bitmap {
    val out = Bitmap.createBitmap(spec.w, spec.h, Bitmap.Config.ARGB_8888)
    val c = Canvas(out)
    c.drawColor(Color.WHITE)
    val b = alphaBounds(fg) ?: Rect(0, 0, fg.width, fg.height)
    val subH = (b.height()).coerceAtLeast(1).toFloat()
    // Subject occupies ~72% of the frame height, top of head ~12% down.
    val scale = (0.72f * spec.h) / subH
    val subjCenterX = (b.left + b.right) / 2f
    val left = spec.w / 2f - subjCenterX * scale
    val top = 0.12f * spec.h - b.top * scale
    val m = Matrix().apply { postScale(scale, scale); postTranslate(left, top) }
    c.drawBitmap(fg, m, Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
    return out
}

/** Bounding box of the non-transparent pixels. */
private fun alphaBounds(bmp: Bitmap): Rect? {
    val w = bmp.width; val h = bmp.height
    val px = IntArray(w * h)
    bmp.getPixels(px, 0, w, 0, 0, w, h)
    var minX = w; var minY = h; var maxX = -1; var maxY = -1
    for (y in 0 until h) {
        val row = y * w
        for (x in 0 until w) {
            val a = (px[row + x] ushr 24) and 0xff
            if (a > 16) {
                if (x < minX) minX = x
                if (x > maxX) maxX = x
                if (y < minY) minY = y
                if (y > maxY) maxY = y
            }
        }
    }
    return if (maxX < 0) null else Rect(minX, minY, maxX, maxY)
}
