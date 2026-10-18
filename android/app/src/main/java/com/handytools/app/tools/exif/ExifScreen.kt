package com.handytools.app.tools.exif

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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.exifinterface.media.ExifInterface
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.ToolHeader
import java.io.File
import java.io.FileOutputStream

/** See the hidden data in a photo (location, device, date) and strip it before sharing. */
@Composable
fun ExifScreen() {
    val ctx = LocalContext.current
    var uri by remember { mutableStateOf<Uri?>(null) }
    var rows by remember { mutableStateOf<List<Pair<String, String>>>(emptyList()) }
    var hasLocation by remember { mutableStateOf(false) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { picked ->
        uri = picked
        rows = emptyList(); hasLocation = false
        if (picked != null) {
            ctx.contentResolver.openInputStream(picked)?.use { stream ->
                val exif = ExifInterface(stream)
                val list = mutableListOf<Pair<String, String>>()
                val latLong = FloatArray(2)
                if (exif.getLatLong(latLong)) { list.add("Location" to "%.5f, %.5f".format(latLong[0], latLong[1])); hasLocation = true }
                exif.getAttribute(ExifInterface.TAG_DATETIME)?.let { list.add("Taken" to it) }
                exif.getAttribute(ExifInterface.TAG_MAKE)?.let { mk -> list.add("Camera" to (mk + " " + (exif.getAttribute(ExifInterface.TAG_MODEL) ?: ""))) }
                val w = exif.getAttribute(ExifInterface.TAG_IMAGE_WIDTH); val h = exif.getAttribute(ExifInterface.TAG_IMAGE_LENGTH)
                if (w != null && h != null) list.add("Size" to "$w × $h")
                rows = list
            }
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Photo Metadata", "See what a photo reveals — and strip it before sharing.")
        Spacer(Modifier.size(12.dp))
        HPrimaryButton(if (uri == null) "Pick a photo" else "Pick a different photo", modifier = Modifier.fillMaxWidth()) {
            picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
        if (uri != null) {
            Spacer(Modifier.size(12.dp))
            if (rows.isEmpty()) Text("No metadata found — this photo is already clean.", color = Handy.palette.textSecondary)
            else rows.forEach { (k, v) ->
                Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(k, color = Handy.palette.textSecondary)
                    Text(v, style = MaterialTheme.typography.bodyMedium)
                }
            }
            Spacer(Modifier.size(12.dp))
            HSecondaryButton("Strip & share a clean copy", modifier = Modifier.fillMaxWidth()) {
                val u = uri ?: return@HSecondaryButton
                val bmp = ctx.contentResolver.openInputStream(u)?.use { BitmapFactory.decodeStream(it) } ?: return@HSecondaryButton
                val f = File(ctx.cacheDir, "Tenzy-clean-${System.currentTimeMillis()}.jpg")
                FileOutputStream(f).use { bmp.compress(android.graphics.Bitmap.CompressFormat.JPEG, 95, it) }
                Share.file(ctx, f, "image/jpeg")
            }
        }
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}
