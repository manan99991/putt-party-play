package com.handytools.app.tools.magnifier

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
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
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.ToolHeader

/** Camera magnifier — zoom way past the Camera app and light it up to read fine print. */
@Composable
fun MagnifierScreen() {
    val ctx = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current
    var granted by remember { mutableStateOf(ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    var zoom by remember { mutableFloatStateOf(0.3f) }
    var torchOn by remember { mutableStateOf(false) }
    var camera by remember { mutableStateOf<Camera?>(null) }

    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted = it }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Magnifier", "Read the fine print — zoom and light it up.")
        Spacer(Modifier.size(12.dp))
        if (!granted) {
            HSecondaryButton("Allow camera", modifier = Modifier.fillMaxWidth()) { permLauncher.launch(Manifest.permission.CAMERA) }
        } else {
            AndroidView(
                factory = { context ->
                    val pv = PreviewView(context)
                    val providerFuture = ProcessCameraProvider.getInstance(context)
                    providerFuture.addListener({
                        val provider = providerFuture.get()
                        val preview = Preview.Builder().build().also { it.surfaceProvider = pv.surfaceProvider }
                        provider.unbindAll()
                        camera = provider.bindToLifecycle(lifecycle, CameraSelector.DEFAULT_BACK_CAMERA, preview)
                        camera?.cameraControl?.setLinearZoom(zoom)
                    }, ContextCompat.getMainExecutor(context))
                    pv
                },
                modifier = Modifier.fillMaxWidth().aspectRatio(3f / 4f).clip(RoundedCornerShape(16.dp))
            )
            Spacer(Modifier.size(12.dp))
            Text("Zoom", color = Handy.palette.textSecondary)
            Slider(value = zoom, onValueChange = { zoom = it; camera?.cameraControl?.setLinearZoom(it) })
            Spacer(Modifier.size(8.dp))
            HSecondaryButton(if (torchOn) "Light off" else "Light on", modifier = Modifier.fillMaxWidth()) {
                torchOn = !torchOn; camera?.cameraControl?.enableTorch(torchOn)
            }
        }
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}
