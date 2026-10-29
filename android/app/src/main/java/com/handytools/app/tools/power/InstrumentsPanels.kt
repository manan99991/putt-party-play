package com.handytools.app.tools.power

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.hardware.Sensor
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.provider.Settings
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.handytools.app.ui.BigToggle
import com.handytools.app.ui.ChipRow
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HTextButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PermissionCard
import com.handytools.app.ui.Pill
import com.handytools.app.ui.PreviewBox
import com.handytools.app.ui.SectionLabel
import com.handytools.app.ui.SliderRow
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.math.sqrt

// ---- Altitude -------------------------------------------------------------------------------

@SuppressLint("MissingPermission")
@Composable
internal fun AltitudePanel() {
    val ctx = LocalContext.current
    val prefs = remember { InstrumentPrefs(ctx) }
    val lm = remember { ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager }

    // Barometer: steadier, but drifts with the weather.
    var pressure by remember { mutableFloatStateOf(Float.NaN) }
    val hasBaro = rememberInstrSensor(Sensor.TYPE_PRESSURE) { e ->
        pressure = if (pressure.isNaN()) e.values[0] else pressure * 0.9f + e.values[0] * 0.1f
    }
    val baroAlt: Float? = if (hasBaro && !pressure.isNaN()) SensorManager.getAltitude(SensorManager.PRESSURE_STANDARD_ATMOSPHERE, pressure) else null

    // GPS: absolute, but needs sky.
    fun hasLoc() = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    var granted by remember { mutableStateOf(hasLoc()) }
    var denied by remember { mutableStateOf(false) }
    var fix by remember { mutableStateOf<Location?>(null) }
    var searching by remember { mutableStateOf(false) }
    var locationOff by remember { mutableStateOf(false) }
    val listener = remember { LocationListener { loc -> if (loc.hasAltitude()) { fix = loc; searching = false } } }
    fun startGps() {
        locationOff = !lm.isProviderEnabled(LocationManager.GPS_PROVIDER) && !lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        if (locationOff) return
        searching = true
        try {
            lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)?.let { if (it.hasAltitude() && fix == null) fix = it }
            if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, listener)
            if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 2000L, 0f, listener)
        } catch (_: SecurityException) { searching = false }
    }
    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        granted = ok; denied = !ok
        if (ok) startGps()
    }
    DisposableEffect(Unit) { onDispose { lm.removeUpdates(listener) } }

    val gpsAlt: Float? = fix?.let { it.altitude.toFloat() }
    val best: Float? = baroAlt ?: gpsAlt
    var ref by remember { mutableFloatStateOf(prefs.altRef) }

    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        if (denied) {
            PermissionCard(
                "Location", "Needed to read altitude from GPS.", granted, instrAppSettingsIntent(ctx),
                "Open settings", privacy = "Used only on this screen. Nothing is stored or uploaded."
            )
        }
        InstrBigReadout(if (best != null) "${best.roundToInt()} m" else "—")
        InstrSubLine(
            when {
                best == null && searching -> "Getting fix…"
                best == null && !hasBaro -> "metres above sea level · tap Get altitude"
                baroAlt != null -> "metres above sea level · barometer"
                else -> "metres above sea level · GPS"
            }
        )
        if (!ref.isNaN() && best != null) {
            val gain = best - ref
            Spacer(Modifier.height(6.dp))
            Pill("${if (gain >= 0) "+" else ""}${gain.roundToInt()} m since reference", if (gain >= 0) HandyColors.Success else HandyColors.Amber)
        }
        Row(Modifier.fillMaxWidth().padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            InstrTile(
                Modifier.weight(1f), "Barometer",
                if (baroAlt != null) "${baroAlt.roundToInt()} m" else "—",
                if (!hasBaro) "No barometer on this phone" else if (baroAlt == null) "Reading…" else "± ~5 m · %.1f hPa".format(pressure)
            )
            InstrTile(
                Modifier.weight(1f), "GPS",
                if (gpsAlt != null) "${gpsAlt.roundToInt()} m" else "—",
                when {
                    fix != null && fix!!.hasVerticalAccuracy() -> "± ${fix!!.verticalAccuracyMeters.roundToInt()} m · GPS"
                    fix != null -> "accuracy unknown · GPS"
                    searching -> "Waiting for satellites…"
                    else -> "Tap Get altitude"
                }
            )
        }
        if (locationOff) {
            Spacer(Modifier.height(8.dp))
            Pill("Location is off on this phone", HandyColors.Amber)
            HTextButton("Turn on location") { ctx.startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
        }
        Spacer(Modifier.height(12.dp))
        HPrimaryButton(if (searching) "Getting fix…" else "📍 Get altitude") {
            if (granted) startGps() else permLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        Spacer(Modifier.height(8.dp))
        HSecondaryButton("Set current as reference", enabled = best != null) {
            if (best != null) {
                ref = best; prefs.altRef = best
                HandyHaptics.medium(ctx)
                Toast.makeText(ctx, "Reference set — gains show from here", Toast.LENGTH_SHORT).show()
            }
        }
        if (!ref.isNaN()) HTextButton("Clear reference") { ref = Float.NaN; prefs.altRef = Float.NaN }
        NoteText(
            if (hasBaro) "The barometer gives a steady reading and tracks gains well; GPS pins it to sea level outdoors. Both are shown so you can compare."
            else "GPS altitude needs a clear view of the sky and can be off by 10–20 m. Set a reference at the bottom of a climb to track your gain."
        )
    }
}

// ---- Metal ----------------------------------------------------------------------------------

@Composable
internal fun MetalPanel() {
    val ctx = LocalContext.current
    val prefs = remember { InstrumentPrefs(ctx) }
    var mag by remember { mutableFloatStateOf(0f) }
    var baseline by remember { mutableFloatStateOf(Float.NaN) }
    var samples by remember { mutableIntStateOf(0) }
    var accuracy by remember { mutableIntStateOf(SensorManager.SENSOR_STATUS_ACCURACY_HIGH) }
    var beep by remember { mutableStateOf(prefs.metalBeep) }
    var threshold by remember { mutableFloatStateOf(prefs.metalThreshold) }
    var lastBeep by remember { mutableStateOf(0L) }
    val tone = remember { runCatching { ToneGenerator(AudioManager.STREAM_MUSIC, 80) }.getOrNull() }
    DisposableEffect(Unit) { onDispose { tone?.release() } }

    val present = rememberInstrSensor(Sensor.TYPE_MAGNETIC_FIELD, SensorManager.SENSOR_DELAY_GAME, onAccuracy = { accuracy = it }) { e ->
        val m = sqrt(e.values[0] * e.values[0] + e.values[1] * e.values[1] + e.values[2] * e.values[2])
        mag = if (samples == 0) m else mag * 0.7f + m * 0.3f
        samples += 1
        if (baseline.isNaN() && samples > 12) baseline = mag
        val d = if (baseline.isNaN()) 0f else abs(mag - baseline)
        if (beep && d > threshold) {
            val now = System.currentTimeMillis()
            if (now - lastBeep > 350) {
                lastBeep = now
                tone?.startTone(ToneGenerator.TONE_PROP_BEEP, 80)
                HandyHaptics.medium(ctx)
            }
        }
    }
    val delta = if (baseline.isNaN()) 0f else abs(mag - baseline)
    val hot = delta > threshold
    val dial = Handy.palette.border
    val color = when { hot -> HandyColors.Danger; delta > threshold / 2 -> HandyColors.Amber; else -> HandyColors.Accent }

    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Pill(if (present) "Runs natively · magnetometer" else "No magnetometer", if (present) HandyColors.Accent else HandyColors.Amber)
        InstrBigReadout(if (present && samples > 0) "${mag.roundToInt()} µT" else "—", color)
        InstrSubLine(
            when {
                !present -> "This phone has no magnetometer, so it can't sense metal."
                baseline.isNaN() -> "Hold still a moment to set the baseline…"
                hot -> "Metal nearby"
                else -> "${if (mag - baseline >= 0) "+" else "−"}${delta.roundToInt()} µT from baseline"
            }, if (hot) HandyColors.Danger else Handy.palette.textSecondary
        )
        // Needle: a half-dial that swings with the change from baseline.
        Canvas(Modifier.padding(top = 6.dp).fillMaxWidth().height(90.dp)) {
            val r = minOf(size.width / 2, size.height) - 6.dp.toPx()
            val c = Offset(size.width / 2, size.height - 4.dp.toPx())
            drawArc(
                dial, startAngle = 180f, sweepAngle = 180f, useCenter = false,
                topLeft = Offset(c.x - r, c.y - r), size = Size(r * 2, r * 2), style = Stroke(3.dp.toPx())
            )
            val frac = (delta / 150f).coerceIn(0f, 1f)
            val a = Math.toRadians((180.0 + 180.0 * frac))
            val end = Offset(c.x + r * kotlin.math.cos(a).toFloat(), c.y + r * kotlin.math.sin(a).toFloat())
            drawLine(color, c, end, 3.dp.toPx())
            drawCircle(color, 5.dp.toPx(), c)
        }
        InstrBar(delta / 150f, color)
        InstrSubLine("move the phone near metal — the needle jumps")
        Spacer(Modifier.height(8.dp))
        ChipRow {
            HChip("Calibrate here", false) {
                baseline = mag
                HandyHaptics.light(ctx)
                Toast.makeText(ctx, "Baseline set to ${mag.roundToInt()} µT", Toast.LENGTH_SHORT).show()
            }
        }
        if (present && (accuracy == SensorManager.SENSOR_STATUS_ACCURACY_LOW || accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE)) {
            Spacer(Modifier.height(8.dp))
            Pill("Accuracy low — move the phone in a figure 8", HandyColors.Amber)
        }
        BigToggle("Beep and buzz near metal", beep) { beep = it; prefs.metalBeep = it }
        SliderRow("Sensitivity", "${threshold.roundToInt()} µT", threshold, { threshold = it }, 10f..100f, onFinished = { prefs.metalThreshold = threshold })
        NoteText("Lower sensitivity values trigger sooner. The sensor sits near the top of the phone — sweep that end over the wall or ground.")
    }
}

// ---- Ruler ----------------------------------------------------------------------------------

@Composable
internal fun RulerPanel() {
    val ctx = LocalContext.current
    val prefs = remember { InstrumentPrefs(ctx) }
    val rawPxPerCm = remember { ctx.resources.displayMetrics.xdpi / 2.54f }
    var factor by remember { mutableFloatStateOf(prefs.rulerFactor) }
    var unit by remember { mutableIntStateOf(0) } // 0 cm, 1 inches
    var calibrating by remember { mutableStateOf(false) }
    val measurer = rememberTextMeasurer()
    val tickColor = MaterialTheme.colorScheme.onSurface
    val minorColor = Handy.palette.textSecondary
    val labelStyle = TextStyle(fontSize = 12.sp, color = Handy.palette.textSecondary)
    val pxPerCm = rawPxPerCm * factor
    var widthPx by remember { mutableIntStateOf(0) }

    Column(Modifier.fillMaxWidth()) {
        Canvas(
            Modifier.fillMaxWidth().height(120.dp).onSizeChanged { widthPx = it.width }
                .clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surface)
        ) {
            val ppu = if (unit == 0) pxPerCm else pxPerCm * 2.54f
            val sub = if (unit == 0) 10 else 16
            var u = 0
            while (u * ppu < size.width) {
                for (s in 0 until sub) {
                    val x = u * ppu + s * ppu / sub
                    if (x > size.width) break
                    val big = s == 0
                    val mid = if (unit == 0) s == 5 else s % 4 == 0
                    val h = if (big) 40.dp.toPx() else if (mid) 24.dp.toPx() else 12.dp.toPx()
                    drawLine(if (big) tickColor else minorColor, Offset(x, size.height), Offset(x, size.height - h), if (big) 2f else 1f)
                    if (big) drawText(measurer, "$u", topLeft = Offset(x + 4.dp.toPx(), size.height - 62.dp.toPx()), style = labelStyle)
                }
                u++
            }
        }
        if (calibrating) {
            // Drag the card outline until it matches a real credit card (85.6 mm wide).
            val cardW = 8.56f * pxPerCm
            SectionLabel("Hold a card against the screen · drag to match its width")
            Box(
                Modifier.fillMaxWidth().height(80.dp).pointerInput(Unit) {
                    detectHorizontalDragGestures { _, dx ->
                        factor = (factor + dx / (8.56f * rawPxPerCm)).coerceIn(0.6f, 1.6f)
                    }
                }
            ) {
                Box(
                    Modifier.width((cardW / ctx.resources.displayMetrics.density).dp).fillMaxSize()
                        .clip(RoundedCornerShape(8.dp)).background(HandyColors.Accent.copy(alpha = 0.18f))
                        .border(2.dp, HandyColors.Accent, RoundedCornerShape(8.dp)),
                    contentAlignment = Alignment.Center
                ) { Text("85.6 mm", style = MaterialTheme.typography.labelMedium, color = HandyColors.Accent, fontWeight = FontWeight.SemiBold) }
            }
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                HPrimaryButton("Done", Modifier.weight(1f)) {
                    prefs.rulerFactor = factor; calibrating = false
                    HandyHaptics.medium(ctx)
                    Toast.makeText(ctx, "Ruler calibrated", Toast.LENGTH_SHORT).show()
                }
                HSecondaryButton("Reset", Modifier.weight(1f)) { factor = 1f; prefs.rulerFactor = 1f }
            }
        } else {
            Spacer(Modifier.height(10.dp))
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                HChip("cm", unit == 0) { unit = 0 }
                HChip("inches", unit == 1) { unit = 1 }
                HChip("Calibrate with a card", false) { calibrating = true }
            }
        }
        val spanCm = if (widthPx > 0) widthPx / pxPerCm else 0f
        NoteText(
            (if (factor == 1f) "Calibrated to this screen's pixel density." else "Calibrated with a card (${(factor * 100).roundToInt()}% of the screen's stated density).") +
                if (spanCm > 0f) " The ruler spans %.1f cm (%.2f in) edge to edge.".format(spanCm, spanCm / 2.54f) else ""
        )
    }
}

// ---- Magnifier ------------------------------------------------------------------------------

@Composable
internal fun MagnifierPanel() {
    val ctx = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current
    val scope = rememberCoroutineScope()
    var granted by remember { mutableStateOf(ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    var denied by remember { mutableStateOf(false) }
    var started by remember { mutableStateOf(false) }
    var zoom by remember { mutableFloatStateOf(2f) }
    var maxZoom by remember { mutableFloatStateOf(4f) }
    var torchOn by remember { mutableStateOf(false) }
    var frozen by remember { mutableStateOf<Bitmap?>(null) }
    var camera by remember { mutableStateOf<Camera?>(null) }
    var provider by remember { mutableStateOf<ProcessCameraProvider?>(null) }
    val previewView = remember { PreviewView(ctx) }

    fun bind() {
        val future = ProcessCameraProvider.getInstance(ctx)
        future.addListener({
            val p = future.get()
            provider = p
            val preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }
            p.unbindAll()
            val cam = p.bindToLifecycle(lifecycle, CameraSelector.DEFAULT_BACK_CAMERA, preview)
            camera = cam
            maxZoom = (cam.cameraInfo.zoomState.value?.maxZoomRatio ?: 4f).coerceAtLeast(1.01f)
            zoom = zoom.coerceIn(1f, maxZoom)
            cam.cameraControl.setZoomRatio(zoom)
            if (torchOn) cam.cameraControl.enableTorch(true)
            started = true
        }, ContextCompat.getMainExecutor(ctx))
    }
    fun stop() {
        camera?.cameraControl?.enableTorch(false)
        provider?.unbindAll(); camera = null; started = false; frozen = null; torchOn = false
    }
    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        granted = ok; denied = !ok
        if (ok) bind()
    }
    DisposableEffect(Unit) { onDispose { camera?.cameraControl?.enableTorch(false); provider?.unbindAll() } }

    Column(Modifier.fillMaxWidth()) {
        if (denied) {
            PermissionCard("Camera", "Needed to magnify what the camera sees.", granted, instrAppSettingsIntent(ctx), "Open settings", privacy = "Frames stay on your phone unless you tap Save.")
        }
        if (!started) {
            PreviewBox(minHeight = 240.dp) {
                Text("Camera zoom with light.", color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium)
            }
        } else {
            Box(Modifier.fillMaxWidth().aspectRatio(3f / 4f).clip(RoundedCornerShape(16.dp)).background(androidx.compose.ui.graphics.Color.Black)) {
                AndroidView(factory = { previewView }, modifier = Modifier.fillMaxSize())
                val f = frozen
                if (f != null) {
                    Image(f.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                    Box(Modifier.align(Alignment.TopStart).padding(10.dp)) { Pill("Frozen", HandyColors.Amber) }
                }
            }
        }
        SliderRow("Zoom", "%.1f×".format(zoom), zoom, { zoom = it; camera?.cameraControl?.setZoomRatio(it) }, 1f..maxZoom)
        if (!started) {
            HPrimaryButton("🔍 Start") { if (granted) bind() else permLauncher.launch(Manifest.permission.CAMERA) }
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                HSecondaryButton(if (torchOn) "Light off" else "💡 Light", Modifier.weight(1f)) {
                    torchOn = !torchOn; camera?.cameraControl?.enableTorch(torchOn)
                }
                HSecondaryButton(if (frozen == null) "❄️ Freeze" else "▶ Live", Modifier.weight(1f)) {
                    if (frozen != null) frozen = null
                    else {
                        val b = previewView.bitmap
                        if (b == null) Toast.makeText(ctx, "Camera is still starting — try again", Toast.LENGTH_SHORT).show()
                        else { frozen = b; HandyHaptics.light(ctx) }
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
            HPrimaryButton("Save frame") {
                val b = frozen ?: previewView.bitmap
                if (b == null) Toast.makeText(ctx, "Nothing to save yet", Toast.LENGTH_SHORT).show()
                else scope.launch {
                    val ok = instrSaveBitmap(ctx, b, "Magnifier")
                    if (ok) HandyHaptics.success(ctx)
                    Toast.makeText(ctx, if (ok) "Saved to Pictures/Tenzy" else "Couldn't save the frame", Toast.LENGTH_SHORT).show()
                }
            }
            Spacer(Modifier.height(8.dp))
            HSecondaryButton("Stop") { stop() }
        }
        NoteText("Zoom goes past what the Camera app allows. Freeze to read fine print without holding still.")
    }
}
