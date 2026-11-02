package com.handytools.app.tools.power

import android.graphics.Bitmap
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
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
import androidx.compose.runtime.mutableIntStateOf
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
import com.handytools.app.ui.ChipRow
import com.handytools.app.ui.HChip
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

private val TYPES = listOf("Red (protan)", "Green (deutan)", "Blue (tritan)")

/**
 * Color Vision — shifts the colours a given type of colour blindness confuses into ones the eye can
 * still tell apart, so red/green (or blue/yellow) stop looking the same. Pick a photo, pick your
 * type, compare. Pure on-device maths; nothing uploaded.
 */
@Composable
fun ColorVisionToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var src by remember { mutableStateOf<Bitmap?>(null) }
    var corrected by remember { mutableStateOf<Bitmap?>(null) }
    var type by remember { mutableIntStateOf(1) }       // deutan is the most common
    var working by remember { mutableStateOf(false) }
    var showOriginal by remember { mutableStateOf(false) }

    fun recompute() {
        val s = src ?: return
        working = true
        scope.launch {
            val out = withContext(Dispatchers.IO) { ColorVisionEngine.daltonize(s, type) }
            corrected = out; working = false
        }
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        working = true; corrected = null; showOriginal = false
        scope.launch {
            val bmp = withContext(Dispatchers.IO) { SafeBitmap.decode(ctx, uri, 1200) }
            src = bmp
            if (bmp == null) { working = false; return@launch }
            val out = withContext(Dispatchers.IO) { ColorVisionEngine.daltonize(bmp, type) }
            corrected = out; working = false
        }
    }

    fun save() {
        val bmp = corrected ?: return
        scope.launch {
            val f = withContext(Dispatchers.IO) {
                try {
                    val file = File(ctx.cacheDir, "Tenzy-colorvision-${System.currentTimeMillis()}.png")
                    FileOutputStream(file).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    file
                } catch (_: Throwable) { null }
            }
            if (f != null) Share.file(ctx, f, "image/png")
        }
    }

    PowerToolPage("colorvision") {
        val shown = if (showOriginal) src else (corrected ?: src)
        PreviewBox(minHeight = 220.dp) {
            if (shown != null) Image(shown.asImageBitmap(), null, Modifier.fillMaxWidth().heightIn(max = 420.dp).clip(RoundedCornerShape(12.dp)), contentScale = ContentScale.Fit)
            else Text(if (working) "Working…" else "Pick a photo to make confusable colours tell apart.", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary, modifier = Modifier.padding(horizontal = 20.dp))
        }
        if (src != null) {
            Spacer(Modifier.height(6.dp))
            Text(if (showOriginal) "Showing: original" else "Showing: corrected", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        Spacer(Modifier.height(12.dp))
        HSecondaryButton(if (src == null) "Choose a photo" else "Choose a different photo", Modifier.fillMaxWidth(), enabled = !working) {
            picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }

        if (src != null) {
            Spacer(Modifier.height(14.dp))
            SectionLabel("Colour-blindness type")
            ChipRow { TYPES.forEachIndexed { i, t -> HChip(t, type == i) { type = i; recompute() } } }
            Spacer(Modifier.height(12.dp))
            HSecondaryButton(if (showOriginal) "Show corrected" else "Compare with original", Modifier.fillMaxWidth()) { showOriginal = !showOriginal }
            if (corrected != null) {
                Spacer(Modifier.height(8.dp))
                HPrimaryButton("Save & share corrected", Modifier.fillMaxWidth()) { save() }
            }
        }
        NoteText("Daltonisation nudges the colours your type of colour blindness confuses into differences you can still see. It helps tell colours apart — it doesn't restore true colour. All on your phone.")
    }
}
