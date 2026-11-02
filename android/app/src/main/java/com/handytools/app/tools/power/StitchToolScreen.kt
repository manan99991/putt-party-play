package com.handytools.app.tools.power

import android.graphics.Bitmap
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.handytools.app.SafeBitmap
import com.handytools.app.tools.Share
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.PreviewBox
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

/**
 * Long Screenshot — stitch a set of scrolling screenshots into one tall image. It detects the band
 * each shot shares with the next and removes the duplication, so a chat, article or page reads as one
 * continuous picture. Everything runs on the phone.
 */
@Composable
fun StitchToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var sources by remember { mutableStateOf<List<Uri>>(emptyList()) }
    var result by remember { mutableStateOf<Bitmap?>(null) }
    var working by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(8)) { uris ->
        if (uris.isNotEmpty()) { sources = uris; result = null; error = null }
    }

    fun stitch() {
        if (sources.size < 2) return
        working = true; result = null; error = null
        scope.launch {
            val out = withContext(Dispatchers.IO) {
                try {
                    val bmps = sources.mapNotNull { SafeBitmap.decode(ctx, it, 1600) }
                    if (bmps.size < 2) null else StitchEngine.stitch(bmps)
                } catch (_: Throwable) { null }
            }
            working = false
            if (out == null) error = "Couldn't stitch those. Use screenshots from the same screen, picked top-to-bottom."
            else result = out
        }
    }

    fun save() {
        val bmp = result ?: return
        scope.launch {
            val f = withContext(Dispatchers.IO) {
                try {
                    val file = File(ctx.cacheDir, "Tenzy-long-${System.currentTimeMillis()}.png")
                    FileOutputStream(file).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    file
                } catch (_: Throwable) { null }
            }
            if (f != null) Share.file(ctx, f, "image/png")
        }
    }

    PowerToolPage("stitch") {
        val r = result
        PreviewBox(minHeight = 220.dp) {
            if (r != null) Image(r.asImageBitmap(), null, Modifier.fillMaxWidth().heightIn(max = 460.dp).clip(RoundedCornerShape(12.dp)), contentScale = ContentScale.FillWidth)
            else Text(if (working) "Stitching…" else if (sources.isNotEmpty()) "${sources.size} shots ready — tap Stitch." else "Pick 2–8 scrolling screenshots, in order from top to bottom.",
                style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary, modifier = Modifier.padding(horizontal = 20.dp))
        }
        Spacer(Modifier.height(12.dp))
        HSecondaryButton(if (sources.isEmpty()) "Pick screenshots" else "Pick different screenshots", Modifier.fillMaxWidth(), enabled = !working) {
            picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
        if (sources.size >= 2) {
            Spacer(Modifier.height(8.dp))
            HPrimaryButton(if (working) "Stitching…" else "Stitch into one", enabled = !working) { stitch() }
        }
        if (r != null) {
            Spacer(Modifier.height(8.dp))
            SectionLabel("${r.width} × ${r.height}")
            HPrimaryButton("Save & share", Modifier.fillMaxWidth()) { save() }
        }
        error?.let { Spacer(Modifier.height(10.dp)); Text(it, color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium) }
        NoteText("Works best on screenshots of the same screen taken as you scroll, picked in order. Tenzy finds the overlap between each pair and joins them seamlessly — all on your phone.")
    }
}
