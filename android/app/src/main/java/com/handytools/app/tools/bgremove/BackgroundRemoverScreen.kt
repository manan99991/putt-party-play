package com.handytools.app.tools.bgremove

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.ToolHeader
import java.io.File
import java.io.FileOutputStream

/** Cut the subject out of a photo with ML Kit subject segmentation — no watermark. */
@Composable
fun BackgroundRemoverScreen() {
    val ctx = LocalContext.current
    var source by remember { mutableStateOf<Bitmap?>(null) }
    var result by remember { mutableStateOf<Bitmap?>(null) }
    var working by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val overQuota = !Usage.hasRoom(ctx, "bgremove", Limits.FREE_BG_REMOVE_PER_DAY)

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        result = null; error = null
        if (uri != null) source = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) }
    }

    fun remove() {
        val bmp = source ?: return
        if (!Usage.use(ctx, "bgremove", Limits.FREE_BG_REMOVE_PER_DAY)) return
        working = true; error = null
        val segmenter = SubjectSegmentation.getClient(
            SubjectSegmenterOptions.Builder().enableForegroundBitmap().build()
        )
        segmenter.process(InputImage.fromBitmap(bmp, 0))
            .addOnSuccessListener { res ->
                working = false
                val fg = res.foregroundBitmap
                if (fg != null) result = fg else error = "Couldn't find a clear subject. Try a photo with a distinct foreground."
                segmenter.close()
            }
            .addOnFailureListener { working = false; error = "Couldn't process that photo."; segmenter.close() }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Background Remover", "Cut the subject out cleanly — on your phone, no watermark.")
        Spacer(Modifier.size(12.dp))
        HPrimaryButton(if (source == null) "Pick a photo" else "Pick a different photo", modifier = Modifier.fillMaxWidth()) {
            picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
        (result ?: source)?.let {
            Spacer(Modifier.size(12.dp))
            Image(it.asImageBitmap(), null, Modifier.fillMaxWidth().heightIn(max = 280.dp))
        }
        if (source != null && result == null) {
            if (overQuota) Text("You've removed today's ${Limits.FREE_BG_REMOVE_PER_DAY} free backgrounds. Go Pro for unlimited.",
                style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))
            Spacer(Modifier.size(12.dp))
            HPrimaryButton(if (working) "Removing…" else "Remove background", enabled = !working && !overQuota, modifier = Modifier.fillMaxWidth()) { remove() }
        }
        error?.let { Text(it, color = HandyColors.Danger, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp)) }
        result?.let { bmp ->
            Spacer(Modifier.size(12.dp))
            HPrimaryButton("Save or share (PNG)", modifier = Modifier.fillMaxWidth()) {
                val f = File(ctx.cacheDir, "Tenzy-cutout-${System.currentTimeMillis()}.png")
                FileOutputStream(f).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
                Share.file(ctx, f, "image/png")
            }
        }
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}
