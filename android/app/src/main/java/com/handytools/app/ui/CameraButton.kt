package com.handytools.app.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.handytools.app.I18n
import java.io.File

/**
 * The camera button every photo and video tool offers beside "pick" (as on the iPhone): returns what to call when it's
 * tapped. It asks for the camera once if needed, opens the phone's own camera to take a photo (or record a clip when
 * [video]), and hands the result to [onTaken] — the same way a picked file arrives. If the camera is off for Tenzy it
 * says so and offers Settings. Nothing is kept beyond the app's own cache.
 */
@Composable
fun rememberCamera(video: Boolean = false, onTaken: (Uri) -> Unit): () -> Unit {
    val ctx = LocalContext.current
    var pending by rememberSaveable { mutableStateOf<String?>(null) }
    var off by remember { mutableStateOf(false) }
    val photo = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val u = pending; pending = null
        if (ok && u != null) onTaken(Uri.parse(u))
    }
    val clip = rememberLauncherForActivityResult(ActivityResultContracts.CaptureVideo()) { ok ->
        val u = pending; pending = null
        if (ok && u != null) onTaken(Uri.parse(u))
    }
    fun open() {
        val dir = File(ctx.cacheDir, "camera").apply { mkdirs() }
        val f = File(dir, (if (video) "clip-" else "photo-") + System.currentTimeMillis() + (if (video) ".mp4" else ".jpg"))
        val uri = FileProvider.getUriForFile(ctx, ctx.packageName + ".fileprovider", f)
        pending = uri.toString()
        runCatching { if (video) clip.launch(uri) else photo.launch(uri) }.onFailure { pending = null; off = true }
    }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> if (ok) open() else off = true }
    if (off) AlertDialog(
        onDismissRequest = { off = false },
        title = { Text(I18n.t("The camera is off for Tenzy")) },
        text = { Text(I18n.t("Turn on Camera for Tenzy in Settings to take a photo here. You can still pick one from your phone.")) },
        confirmButton = {
            TextButton({
                off = false
                runCatching { ctx.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + ctx.packageName)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
            }) { Text(I18n.t("Open Settings")) }
        },
        dismissButton = { TextButton({ off = false }) { Text(I18n.t("Not now")) } },
    )
    return {
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) open()
        else ask.launch(Manifest.permission.CAMERA)
    }
}
