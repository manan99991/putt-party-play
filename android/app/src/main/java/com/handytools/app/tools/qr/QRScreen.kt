package com.handytools.app.tools.qr

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.OptIn
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.wallet.Barcodes
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.ToolHeader
import java.util.concurrent.Executors

/** Scan any QR/barcode, or make your own Wi-Fi / link code. */
@Composable
fun QRScreen() {
    var mode by remember { mutableIntStateOf(0) }
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("QR & Barcode", "Scan a code, or make your own.")
        Spacer(Modifier.size(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            HChip("Scan", mode == 0) { mode = 0 }
            HChip("Make", mode == 1) { mode = 1 }
        }
        Spacer(Modifier.size(12.dp))
        if (mode == 0) Scan() else Make()
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

@OptIn(ExperimentalGetImage::class)
@Composable
private fun Scan() {
    val ctx = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current
    var granted by remember { mutableStateOf(ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    var result by remember { mutableStateOf<String?>(null) }
    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted = it }

    if (!granted) {
        HSecondaryButton("Allow camera", modifier = Modifier.fillMaxWidth()) { permLauncher.launch(Manifest.permission.CAMERA) }
        return
    }
    AndroidView(
        factory = { context ->
            val pv = PreviewView(context)
            val future = ProcessCameraProvider.getInstance(context)
            val scanner = BarcodeScanning.getClient()
            val exec = Executors.newSingleThreadExecutor()
            future.addListener({
                val provider = future.get()
                val preview = Preview.Builder().build().also { it.surfaceProvider = pv.surfaceProvider }
                val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                analysis.setAnalyzer(exec) { proxy ->
                    val mediaImage = proxy.image
                    if (mediaImage != null && result == null) {
                        scanner.process(InputImage.fromMediaImage(mediaImage, proxy.imageInfo.rotationDegrees))
                            .addOnSuccessListener { codes -> codes.firstOrNull()?.rawValue?.let { result = it } }
                            .addOnCompleteListener { proxy.close() }
                    } else proxy.close()
                }
                provider.unbindAll()
                provider.bindToLifecycle(lifecycle, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
            }, ContextCompat.getMainExecutor(context))
            pv
        },
        modifier = Modifier.fillMaxWidth().aspectRatio(3f / 4f).clip(RoundedCornerShape(16.dp))
    )
    result?.let { r ->
        Spacer(Modifier.size(12.dp))
        Text(r, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.size(8.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            if (r.startsWith("http")) HPrimaryButton("Open", modifier = Modifier.weight(1f)) {
                ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(r)))
            }
            HSecondaryButton("Scan again", modifier = Modifier.weight(1f)) { result = null }
        }
    }
}

@Composable
private fun Make() {
    var text by remember { mutableStateOf("") }
    val bmp = remember(text) { if (text.isBlank()) null else Barcodes.make(text, true) }
    Column(Modifier.fillMaxWidth()) {
        OutlinedTextField(text, { text = it }, label = { Text("Link or text") }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.size(16.dp))
        bmp?.let {
            Box(Modifier.fillMaxWidth(), contentAlignment = androidx.compose.ui.Alignment.Center) {
                Box(Modifier.background(androidx.compose.ui.graphics.Color.White).padding(12.dp)) {
                    Image(it.asImageBitmap(), null, Modifier.size(240.dp))
                }
            }
        } ?: Text("Type a link or text to make a QR code.", color = Handy.palette.textSecondary)
    }
}
