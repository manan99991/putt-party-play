package com.handytools.app.tools.scan

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DocumentScanner
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.ToolHeader
import java.io.File
import java.io.FileOutputStream

/** Full document scanner (ML Kit): auto-edge, multi-page, export a clean PDF. */
@Composable
fun DocScannerScreen() {
    val ctx = LocalContext.current
    val activity = ctx.findActivity()
    var status by remember { mutableStateOf<String?>(null) }
    val overQuota = !Usage.hasRoom(ctx, "scan", Limits.FREE_SCAN_PAGES)

    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { res ->
        val result = GmsDocumentScanningResult.fromActivityResultIntent(res.data)
        val pdfUri = result?.pdf?.uri
        if (pdfUri != null) {
            // Copy to cache so we can share it via our FileProvider.
            val f = File(ctx.cacheDir, "Tenzy-scan-${System.currentTimeMillis()}.pdf")
            ctx.contentResolver.openInputStream(pdfUri)?.use { input -> FileOutputStream(f).use { input.copyTo(it) } }
            status = "Scanned ${result.pdf?.pageCount ?: 0} page(s)"
            Share.file(ctx, f, "application/pdf")
        }
    }

    fun scan() {
        if (!Usage.use(ctx, "scan", Limits.FREE_SCAN_PAGES)) return
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(if (com.handytools.app.HandyApp.instance.billing.isPremium.value) 30 else 5)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_PDF)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        GmsDocumentScanning.getClient(options).getStartScanIntent(activity)
            .addOnSuccessListener { sender -> launcher.launch(IntentSenderRequest.Builder(sender).build()) }
            .addOnFailureListener { status = "Scanner unavailable on this device." }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        ToolHeader("Doc Scanner", "Scan pages with auto-edge detection, export a clean PDF.")
        Spacer(Modifier.size(24.dp))
        Icon(Icons.Outlined.DocumentScanner, null, tint = HandyColors.Accent, modifier = Modifier.size(64.dp))
        Spacer(Modifier.size(16.dp))
        Text("Point at a document — Tenzy finds the edges and straightens it.", color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.size(16.dp))
        if (overQuota) Text("You've scanned today's ${Limits.FREE_SCAN_PAGES} free times. Go Pro for unlimited.",
            style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(bottom = 8.dp))
        HPrimaryButton("Start scanning", enabled = !overQuota, modifier = Modifier.fillMaxWidth()) { scan() }
        status?.let { Spacer(Modifier.size(12.dp)); Text(it, style = MaterialTheme.typography.bodyMedium) }
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

private fun Context.findActivity(): Activity {
    var c: Context = this
    while (c is ContextWrapper) { if (c is Activity) return c; c = c.baseContext }
    error("No Activity")
}
