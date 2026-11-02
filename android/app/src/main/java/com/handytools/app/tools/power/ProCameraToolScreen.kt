package com.handytools.app.tools.power

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CaptureRequest
import android.os.Build
import android.provider.MediaStore
import android.util.Range
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.camera2.interop.Camera2CameraControl
import androidx.camera.camera2.interop.CaptureRequestOptions
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.handytools.app.ui.ChipRow
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PowerToolPage
import kotlin.math.ln
import kotlin.math.exp
import kotlin.math.roundToInt
import kotlin.math.roundToLong

/**
 * Pro Camera — manual control of the sensor when the phone supports it: ISO and shutter speed, with a
 * clean live preview, falling back to full auto on devices (or in situations) that don't allow manual
 * sensor control. Photos save to Pictures/Tenzy. Everything stays on the phone.
 */
@OptIn(ExperimentalCamera2Interop::class)
@Composable
fun ProCameraToolScreen() {
    val ctx = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current

    var granted by remember { mutableStateOf(ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    var camera by remember { mutableStateOf<Camera?>(null) }
    var provider by remember { mutableStateOf<ProcessCameraProvider?>(null) }
    val previewView = remember { PreviewView(ctx) }
    val imageCapture = remember { ImageCapture.Builder().build() }

    // Device manual ranges (null = no manual sensor support).
    val ranges = remember {
        try {
            val cm = ctx.getSystemService(CameraManager::class.java)
            val backId = cm.cameraIdList.firstOrNull { cm.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK }
            val chars = backId?.let { cm.getCameraCharacteristics(it) }
            val caps = chars?.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
            val manual = caps?.contains(CameraMetadata.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR) == true
            if (!manual) null else {
                val iso = chars?.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
                val exp = chars?.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
                if (iso != null && exp != null) iso to exp else null
            }
        } catch (_: Throwable) { null }
    }
    @Suppress("UNCHECKED_CAST")
    val isoRange = ranges?.first as? Range<Int>
    @Suppress("UNCHECKED_CAST")
    val expRange = ranges?.second as? Range<Long>

    var manual by remember { mutableStateOf(false) }
    var isoFrac by remember { mutableFloatStateOf(0.3f) }
    var expFrac by remember { mutableFloatStateOf(0.3f) }

    fun isoValue(): Int = isoRange?.let { (it.lower + (it.upper - it.lower) * isoFrac).roundToInt().coerceIn(it.lower, it.upper) } ?: 0
    // Exposure maps on a log scale so the slider feels even across 1/10000s .. 1s.
    fun expNanos(): Long = expRange?.let {
        val lo = ln(it.lower.coerceAtLeast(1L).toDouble()); val hi = ln(it.upper.toDouble())
        exp(lo + (hi - lo) * expFrac).roundToLong().coerceIn(it.lower, it.upper)
    } ?: 0L

    fun applyManual() {
        val cam = camera ?: return
        try {
            val c2 = Camera2CameraControl.from(cam.cameraControl)
            val b = CaptureRequestOptions.Builder()
            if (manual && isoRange != null && expRange != null) {
                b.setCaptureRequestOption(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_OFF)
                b.setCaptureRequestOption(CaptureRequest.SENSOR_SENSITIVITY, isoValue())
                b.setCaptureRequestOption(CaptureRequest.SENSOR_EXPOSURE_TIME, expNanos())
            } else {
                b.setCaptureRequestOption(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON)
            }
            c2.setCaptureRequestOptions(b.build())
        } catch (_: Throwable) {}
    }

    fun bind() {
        val future = ProcessCameraProvider.getInstance(ctx)
        future.addListener({
            try {
                val p = future.get(); provider = p
                val preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }
                p.unbindAll()
                camera = p.bindToLifecycle(lifecycle, CameraSelector.DEFAULT_BACK_CAMERA, preview, imageCapture)
                applyManual()
            } catch (_: Throwable) {}
        }, ContextCompat.getMainExecutor(ctx))
    }

    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> granted = ok; if (ok) bind() }
    DisposableEffect(granted) {
        if (granted) bind()
        onDispose { try { provider?.unbindAll() } catch (_: Throwable) {} }
    }

    fun capture() {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "Tenzy-${System.currentTimeMillis()}.jpg")
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Tenzy")
        }
        val output = ImageCapture.OutputFileOptions.Builder(ctx.contentResolver, MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values).build()
        imageCapture.takePicture(output, ContextCompat.getMainExecutor(ctx), object : ImageCapture.OnImageSavedCallback {
            override fun onImageSaved(result: ImageCapture.OutputFileResults) { Toast.makeText(ctx, "Saved to Pictures/Tenzy", Toast.LENGTH_SHORT).show() }
            override fun onError(exc: ImageCaptureException) { Toast.makeText(ctx, "Couldn't save that shot.", Toast.LENGTH_SHORT).show() }
        })
    }

    PowerToolPage("procam") {
        if (!granted) {
            Text("Pro Camera needs camera access. Nothing is uploaded — photos save to your gallery only.", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
            Spacer(Modifier.height(12.dp))
            HPrimaryButton("Allow camera") { permLauncher.launch(Manifest.permission.CAMERA) }
        } else {
            Box(Modifier.fillMaxWidth().aspectRatio(3f / 4f).clip(RoundedCornerShape(16.dp))) {
                AndroidView(factory = { previewView }, modifier = Modifier.fillMaxWidth())
            }
            Spacer(Modifier.height(12.dp))
            if (isoRange != null && expRange != null) {
                ChipRow {
                    HChip("Auto", !manual) { manual = false; applyManual() }
                    HChip("Manual", manual) { manual = true; applyManual() }
                }
                if (manual) {
                    Spacer(Modifier.height(10.dp))
                    Text("ISO ${isoValue()}", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, color = HandyColors.Accent)
                    Slider(value = isoFrac, onValueChange = { isoFrac = it; applyManual() }, modifier = Modifier.fillMaxWidth())
                    val sec = expNanos() / 1e9
                    val label = if (sec >= 1) "%.1f s".format(sec) else "1/${(1 / sec).roundToInt()} s"
                    Text("Shutter $label", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, color = HandyColors.Accent)
                    Slider(value = expFrac, onValueChange = { expFrac = it; applyManual() }, modifier = Modifier.fillMaxWidth())
                }
            } else {
                Text("This phone doesn't expose manual sensor control, so Pro Camera runs in auto.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            }
            Spacer(Modifier.height(14.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                HPrimaryButton("Capture", Modifier.fillMaxWidth()) { capture() }
            }
        }
        NoteText("Manual ISO and shutter work on phones that allow it (most mid-range and up); elsewhere it falls back to auto so you always get a shot. Photos save to Pictures/Tenzy — nothing leaves the phone.")
    }
}
