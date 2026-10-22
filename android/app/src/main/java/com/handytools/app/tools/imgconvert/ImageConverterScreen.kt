package com.handytools.app.tools.imgconvert

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
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
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.handytools.app.HandyApp
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
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
import kotlin.math.min

/** HEIC→JPG/PNG, resize and compress, in a batch. Shares the results. */
@Composable
fun ImageConverterScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val premium by HandyApp.instance.billing.isPremium.collectAsState()
    var uris by remember { mutableStateOf<List<Uri>>(emptyList()) }
    var png by remember { mutableStateOf(false) }
    var sizeIdx by remember { mutableIntStateOf(0) }
    var quality by remember { mutableIntStateOf(80) }
    var working by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val sizes = listOf("Original" to 0, "Max 2048" to 2048, "Max 1024" to 1024)
    val overQuota = !Usage.hasRoom(ctx, "imgconvert", Limits.FREE_CONVERT_PER_DAY)

    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(if (premium) 30 else 5)
    ) { uris = it }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Image Converter", "HEIC to JPG/PNG, resize and compress — in a batch.")
        Spacer(Modifier.size(12.dp))
        HPrimaryButton(if (uris.isEmpty()) "Pick photos" else "${uris.size} selected", modifier = Modifier.fillMaxWidth()) {
            picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
        if (uris.isNotEmpty()) {
            Spacer(Modifier.size(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                HChip("JPG", !png) { png = false }; HChip("PNG", png) { png = true }
            }
            Spacer(Modifier.size(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                sizes.forEachIndexed { i, (label, _) -> HChip(label, sizeIdx == i) { sizeIdx = i } }
            }
            if (!png) {
                Spacer(Modifier.size(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(50, 70, 80, 90).forEach { q -> HChip("$q%", quality == q) { quality = q } }
                }
            }
            if (overQuota) Text("You've converted today's ${Limits.FREE_CONVERT_PER_DAY} free batches. Go Pro for unlimited.",
                style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))
            Spacer(Modifier.size(12.dp))
            HPrimaryButton(if (working) "Converting…" else "Convert ${uris.size}", enabled = !working && !overQuota, modifier = Modifier.fillMaxWidth()) {
                working = true; error = null
                scope.launch {
                    val files = withContext(Dispatchers.IO) { convert(ctx, uris, png, sizes[sizeIdx].second, quality) }
                    working = false
                    if (files.isNotEmpty()) {
                        Usage.use(ctx, "imgconvert", Limits.FREE_CONVERT_PER_DAY)   // only count a batch that actually produced files
                        Share.files(ctx, files, if (png) "image/png" else "image/jpeg")
                    } else error = "Couldn't convert those images. Try different files."
                }
            }
            error?.let { Text(it, color = HandyColors.Danger, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp)) }
        }
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

private fun convert(ctx: Context, uris: List<Uri>, png: Boolean, maxDim: Int, quality: Int): List<File> {
    val out = mutableListOf<File>()
    uris.forEachIndexed { i, uri ->
        val bmp = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) } ?: return@forEachIndexed
        val scaled = if (maxDim > 0 && max(bmp.width, bmp.height) > maxDim) {
            val s = maxDim.toFloat() / max(bmp.width, bmp.height)
            Bitmap.createScaledBitmap(bmp, (bmp.width * s).toInt(), (bmp.height * s).toInt(), true)
        } else bmp
        val ext = if (png) "png" else "jpg"
        val file = File(ctx.cacheDir, "Tenzy-${i + 1}-${System.currentTimeMillis()}.$ext")
        FileOutputStream(file).use {
            scaled.compress(if (png) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG, if (png) 100 else quality, it)
        }
        out.add(file)
    }
    return out
}

private fun max(a: Int, b: Int) = if (a > b) a else b
