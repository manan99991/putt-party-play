package com.handytools.app.tools.heartrate

import android.Manifest
import android.content.pm.PackageManager
import androidx.annotation.OptIn
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.ToolHeader
import java.util.concurrent.Executors

/**
 * Heart Rate. Measures your pulse with the back camera + flash: cover the lens and flash with a
 * fingertip and hold still. A camera-based reading is a wellness estimate, not a medical device.
 * All processing is on-device; no images are kept.
 */
@Composable
fun HeartRateScreen() {
    val ctx = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current
    var granted by remember {
        mutableStateOf(ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED)
    }
    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted = it }

    var measuring by remember { mutableStateOf(false) }
    var bpm by remember { mutableStateOf(0) }
    var fingerOn by remember { mutableStateOf(false) }
    var progress by remember { mutableStateOf(0f) }
    val analyzer = remember { PpgAnalyzer() }

    DisposableEffect(granted, measuring) {
        if (!granted || !measuring) {
            onDispose { }
        } else {
            analyzer.reset()
            analyzer.onResult = { b, finger, p -> bpm = b; fingerOn = finger; progress = p }
            val future = ProcessCameraProvider.getInstance(ctx)
            val exec = Executors.newSingleThreadExecutor()
            var provider: ProcessCameraProvider? = null
            future.addListener({
                try {
                    provider = future.get()
                    val analysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                    analysis.setAnalyzer(exec) { proxy -> analyzer.onFrame(proxy) }
                    provider?.unbindAll()
                    val cam = provider?.bindToLifecycle(lifecycle, CameraSelector.DEFAULT_BACK_CAMERA, analysis)
                    cam?.cameraControl?.enableTorch(true)
                } catch (_: Exception) { }
            }, ContextCompat.getMainExecutor(ctx))
            onDispose {
                try { provider?.unbindAll() } catch (_: Exception) {}
                exec.shutdown()
            }
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Heart Rate", "Cover the back camera and flash with a fingertip and hold still. This is a wellness estimate, not a medical device.")
        Spacer(Modifier.size(24.dp))

        if (!granted) {
            Text("Camera access is needed to read your pulse from your fingertip. No images are saved or uploaded.", color = Handy.palette.textSecondary)
            Spacer(Modifier.size(16.dp))
            HSecondaryButton("Allow camera", modifier = Modifier.fillMaxWidth()) { permLauncher.launch(Manifest.permission.CAMERA) }
        } else {
            Box(Modifier.fillMaxWidth().padding(vertical = 12.dp), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        if (bpm > 0) "$bpm" else "– –",
                        fontSize = 84.sp, fontWeight = FontWeight.Bold,
                        color = if (bpm > 0) HandyColors.Accent else MaterialTheme.colorScheme.onBackground
                    )
                    Text("BPM", color = Handy.palette.textSecondary)
                    Spacer(Modifier.size(10.dp))
                    Text(
                        when {
                            !measuring -> "Tap Start, then cover the camera and flash."
                            !fingerOn -> "Cover the back camera + flash with your fingertip."
                            bpm == 0 -> "Reading… hold still (${(progress * 100).toInt()}%)"
                            else -> "Holding steady — keep still for a stronger reading."
                        },
                        color = Handy.palette.textSecondary, textAlign = TextAlign.Center
                    )
                }
            }
            Spacer(Modifier.size(20.dp))
            HPrimaryButton(if (measuring) "Stop" else "Start") {
                if (measuring) { measuring = false } else { bpm = 0; fingerOn = false; progress = 0f; measuring = true }
            }
        }

        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

/**
 * Photoplethysmography from the camera: the mean brightness of each frame rises and falls with
 * each heartbeat when a fingertip is lit by the flash. We collect ~a 12s rolling window, detrend
 * it, find the beats, and report BPM from the median beat interval.
 */
private class PpgAnalyzer {
    var onResult: (Int, Boolean, Float) -> Unit = { _, _, _ -> }
    private val times = ArrayDeque<Double>()
    private val vals = ArrayDeque<Double>()
    private val window = 12.0  // seconds

    fun reset() { times.clear(); vals.clear() }

    @OptIn(ExperimentalGetImage::class)
    fun onFrame(proxy: ImageProxy) {
        try {
            val img = proxy.image ?: return
            val y = img.planes[0].buffer
            val size = y.remaining()
            // Subsample the luma plane for a cheap mean brightness.
            var sum = 0L; var count = 0
            val step = (size / 2000).coerceAtLeast(1)
            var i = 0
            while (i < size) { sum += (y.get(i).toInt() and 0xFF); count++; i += step }
            val mean = if (count > 0) sum.toDouble() / count else 0.0
            val t = proxy.imageInfo.timestamp / 1_000_000_000.0

            // Finger present when the flash-lit fingertip makes the frame bright.
            val fingerOn = mean > 90.0

            if (fingerOn) {
                times.addLast(t); vals.addLast(mean)
                while (times.isNotEmpty() && t - times.first() > window) { times.removeFirst(); vals.removeFirst() }
            } else {
                times.clear(); vals.clear()
            }

            val span = if (times.size > 1) times.last() - times.first() else 0.0
            val progress = (span / 8.0).coerceIn(0.0, 1.0).toFloat()
            val bpm = if (span >= 6.0) estimateBpm() else 0
            onResult(bpm, fingerOn, progress)
        } catch (_: Exception) {
        } finally {
            proxy.close()
        }
    }

    private fun estimateBpm(): Int {
        val n = vals.size
        if (n < 20) return 0
        val t = times.toDoubleArray()
        val v = vals.toDoubleArray()
        // Detrend with a moving average (~0.75s window estimated from sample rate).
        val rate = n / (t[n - 1] - t[0])
        val w = (rate * 0.75).toInt().coerceIn(3, n / 2)
        val d = DoubleArray(n)
        for (k in 0 until n) {
            var s = 0.0; var c = 0
            for (j in maxOf(0, k - w)..minOf(n - 1, k + w)) { s += v[j]; c++ }
            d[k] = v[k] - s / c
        }
        // Peak picking with a refractory period (>= 0.33s → <= 180 bpm).
        val peaks = ArrayList<Double>()
        var last = -1.0
        for (k in 1 until n - 1) {
            if (d[k] > 0 && d[k] >= d[k - 1] && d[k] > d[k + 1]) {
                if (last < 0 || t[k] - last >= 0.33) { peaks.add(t[k]); last = t[k] }
            }
        }
        if (peaks.size < 4) return 0
        val intervals = DoubleArray(peaks.size - 1) { peaks[it + 1] - peaks[it] }
        intervals.sort()
        val median = intervals[intervals.size / 2]
        if (median <= 0) return 0
        val bpm = (60.0 / median).toInt()
        return if (bpm in 40..200) bpm else 0
    }
}
