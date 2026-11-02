package com.handytools.app.tools.power

import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.handytools.app.SafeBitmap
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.PreviewBox
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

private data class IdResult(val labels: List<Pair<String, Int>>, val barcode: String?)

/**
 * Identify — point a photo at something and know what it is. On-device ML Kit labels the main
 * objects (with a confidence %), and if there's a barcode it reads that too, with a one-tap web
 * lookup. Everything runs on the phone; the photo is never uploaded.
 */
@Composable
fun IdentifyToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var preview by remember { mutableStateOf<Bitmap?>(null) }
    var result by remember { mutableStateOf<IdResult?>(null) }
    var working by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        working = true; result = null; error = null; preview = null
        scope.launch {
            val bmp = withContext(Dispatchers.IO) { SafeBitmap.decode(ctx, uri, 1600) }
            if (bmp == null) { working = false; error = "Couldn't read that photo. Try another."; return@launch }
            preview = bmp
            val res = withContext(Dispatchers.IO) {
                try {
                    val image = InputImage.fromBitmap(bmp, 0)
                    val labels = ImageLabeling.getClient(ImageLabelerOptions.DEFAULT_OPTIONS).process(image).await()
                        .sortedByDescending { it.confidence }.take(5)
                        .map { it.text to (it.confidence * 100).toInt() }
                    val barcode = try { BarcodeScanning.getClient().process(image).await().firstOrNull()?.rawValue } catch (_: Throwable) { null }
                    IdResult(labels, barcode)
                } catch (_: Throwable) { null }
            }
            working = false
            if (res == null || (res.labels.isEmpty() && res.barcode == null))
                error = "Couldn't make out what's in that photo. Try a clearer, closer shot."
            else result = res
        }
    }

    fun lookUp(q: String) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=" + Uri.encode(q)))
        runCatching { ctx.startActivity(intent) }
    }

    PowerToolPage("identify") {
        PreviewBox(minHeight = 200.dp) {
            val p = preview
            if (p != null) Image(p.asImageBitmap(), null, Modifier.fillMaxWidth().height(200.dp).clip(RoundedCornerShape(16.dp)), contentScale = ContentScale.Fit)
            else Text(if (working) "Looking…" else "Pick a photo of a thing, plant, animal or product.", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary, modifier = Modifier.padding(horizontal = 20.dp))
        }
        Spacer(Modifier.height(12.dp))
        HPrimaryButton(if (working) "Looking…" else if (result != null) "Identify another" else "Choose a photo", enabled = !working) {
            picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
        error?.let { Spacer(Modifier.height(12.dp)); Text(it, color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium) }

        result?.let { r ->
            if (r.labels.isNotEmpty()) {
                Spacer(Modifier.height(16.dp))
                SectionLabel("Looks like")
                r.labels.forEachIndexed { i, (name, pct) ->
                    HCard(Modifier.fillMaxWidth()) {
                        Row(Modifier.fillMaxWidth().padding(14.dp)) {
                            Text(name, style = MaterialTheme.typography.bodyLarge, fontWeight = if (i == 0) FontWeight.Bold else FontWeight.Normal, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.weight(1f))
                            Text("$pct%", style = MaterialTheme.typography.bodyMedium, color = if (i == 0) HandyColors.Accent else Handy.palette.textSecondary)
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                }
                HSecondaryButton("Search the web for \"${r.labels.first().first}\"", Modifier.fillMaxWidth()) { lookUp(r.labels.first().first) }
            }
            if (r.barcode != null) {
                Spacer(Modifier.height(16.dp))
                SectionLabel("Barcode")
                HCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp)) {
                        Text(r.barcode, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurface)
                        Spacer(Modifier.height(8.dp))
                        HSecondaryButton("Look up this product", Modifier.fillMaxWidth()) { lookUp(r.barcode) }
                    }
                }
            }
        }
        NoteText("Recognises everyday objects, plants, animals and products on-device — the photo never leaves your phone. For a web lookup it opens your browser.")
    }
}
