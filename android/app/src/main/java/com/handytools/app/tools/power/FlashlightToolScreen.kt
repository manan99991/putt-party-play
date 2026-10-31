package com.handytools.app.tools.power

import android.Manifest
import android.content.pm.PackageManager
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
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
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PermissionCard
import com.handytools.app.ui.Pill
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.SectionLabel
import com.handytools.app.ui.SliderRow
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.roundToInt
import kotlin.math.sin

private val PATTERNS = listOf("Steady", "Strobe", "SOS", "Beacon", "Pulse")
private val LAMP_COLOURS = listOf(
    Color(0xFFFF6B6B), Color(0xFFFFD166), Color(0xFF06D6A0), Color(0xFF4DABF7), Color(0xFFC77DFF), Color(0xFFFFFFFF)
)

/**
 * Flashlight+ — the real torch with patterns, brightness, Morse, a mirror, a colour lamp and a
 * full-screen white light. Everything stops and the screen brightness is restored on leaving.
 */
@Composable
fun FlashlightToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val torch = remember { FlTorch(ctx) }

    var on by remember { mutableStateOf(false) }
    var pattern by remember { mutableIntStateOf(0) }
    var brightness by remember { mutableFloatStateOf(0.7f) }
    var lamp by remember { mutableFloatStateOf(0f) }          // 0..1 — what the indicator and screen lamp show
    var job by remember { mutableStateOf<Job?>(null) }
    var morseJob by remember { mutableStateOf<Job?>(null) }
    var morseText by remember { mutableStateOf("HELP") }
    var morseCode by remember { mutableStateOf("") }
    var morseProgress by remember { mutableFloatStateOf(0f) }
    var morseRunning by remember { mutableStateOf(false) }
    var screenLight by remember { mutableStateOf(false) }
    var colourLamp by remember { mutableStateOf(false) }
    var colourIdx by remember { mutableIntStateOf(0) }
    var mirror by remember { mutableStateOf(false) }

    fun setLamp(v: Float) { lamp = v; torch.setFraction(v) }

    fun stopPattern() { job?.cancel(); job = null }

    fun runPattern() {
        stopPattern()
        if (!on) { setLamp(0f); return }
        when (pattern) {
            0 -> setLamp(1f)
            1 -> job = scope.launch { var s = false; while (isActive) { s = !s; setLamp(if (s) 1f else 0f); delay(80) } }
            2 -> job = scope.launch {
                val seq = FlMorse.sequence(FlMorse.encode("SOS"))
                while (isActive) { for ((v, d) in seq) { setLamp(if (v) 1f else 0f); delay(d) }; setLamp(0f); delay(1200) }
            }
            3 -> job = scope.launch { while (isActive) { setLamp(1f); delay(120); setLamp(0f); delay(1080) } }
            else -> job = scope.launch {
                if (torch.hasLevels) {
                    var t = 0.0
                    while (isActive) { t += 0.15; setLamp(((sin(t) + 1) / 2).toFloat().coerceIn(0.05f, 1f)); delay(40) }
                } else {
                    while (isActive) { setLamp(1f); delay(90); setLamp(0f); delay(90); setLamp(1f); delay(90); setLamp(0f); delay(600) }
                }
            }
        }
    }

    fun flashMorse(msg: String) {
        val code = FlMorse.encode(msg)
        morseCode = code
        if (code.isBlank()) { Toast.makeText(ctx, "Nothing to flash — letters and numbers only", Toast.LENGTH_SHORT).show(); return }
        morseJob?.cancel()
        stopPattern()
        morseJob = scope.launch {
            morseRunning = true
            val seq = FlMorse.sequence(code)
            val total = seq.sumOf { it.second }.coerceAtLeast(1L)
            var elapsed = 0L
            try {
                for ((v, d) in seq) { setLamp(if (v) 1f else 0f); elapsed += d; morseProgress = elapsed.toFloat() / total; delay(d) }
            } finally {
                morseRunning = false; morseProgress = 0f
            }
            setLamp(0f)
            runPattern() // back to whatever was running before
        }
    }

    // Window brightness: full while a lamp is open; the screen light follows the slider.
    DisposableEffect(screenLight, colourLamp, brightness) {
        when {
            screenLight -> flSetWindowBrightness(ctx, brightness.coerceIn(0.1f, 1f))
            colourLamp -> flSetWindowBrightness(ctx, 1f)
            else -> flSetWindowBrightness(ctx, null)
        }
        onDispose { flSetWindowBrightness(ctx, null) }
    }
    DisposableEffect(Unit) {
        onDispose { job?.cancel(); morseJob?.cancel(); torch.set(false) }
    }
    BackHandler(enabled = screenLight || colourLamp) { screenLight = false; colourLamp = false }

    val stateText = when {
        morseRunning -> "Flashing Morse"
        on -> "On · ${PATTERNS[pattern]}"
        else -> "Off"
    }

    Box(Modifier.fillMaxSize()) {
        PowerToolPage("flashlight") {
            if (!torch.hasFlash) Pill("No flash on this phone — the screen light stands in", HandyColors.Amber)
            LampStage(lamp * (0.35f + brightness * 0.65f), stateText)
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                HPrimaryButton(if (on) "⏻ Turn off" else "💡 Turn on", Modifier.weight(1f)) {
                    on = !on
                    HandyHaptics.light(ctx)
                    if (on && !torch.hasFlash) screenLight = true
                    runPattern()
                }
                HSecondaryButton("🖥 Screen light", Modifier.weight(1f)) { screenLight = true }
            }

            SectionLabel("Pattern")
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                PATTERNS.forEachIndexed { i, p ->
                    HChip(p, pattern == i) { pattern = i; if (on) runPattern() }
                }
            }

            SliderRow(
                "Brightness", "${(brightness * 100).roundToInt()}%", brightness,
                onChange = { v ->
                    brightness = v
                    if (torch.hasLevels) { torch.setStrength(v); if (on && pattern == 0 && !morseRunning) torch.set(true) }
                },
                range = 0.1f..1f
            )
            if (torch.hasFlash && !torch.hasLevels) {
                Text(
                    "This phone's torch has one brightness — the slider sets the screen light instead.",
                    style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary
                )
            }

            SectionLabel("Morse message")
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = morseText, onValueChange = { morseText = it }, modifier = Modifier.weight(1f),
                    placeholder = { Text("Type a message to flash…") }, singleLine = true
                )
                HPrimaryButton("Flash", Modifier.width(96.dp)) {
                    val m = morseText.trim()
                    if (m.isEmpty()) Toast.makeText(ctx, "Type a message", Toast.LENGTH_SHORT).show() else flashMorse(m)
                }
            }
            InstrBar(morseProgress)
            Text(
                if (morseCode.isEmpty()) FlMorse.encode(morseText) else morseCode,
                fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary
            )

            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                HSecondaryButton(if (mirror) "Close mirror" else "🪞 Mirror", Modifier.weight(1f)) { mirror = !mirror }
                HSecondaryButton("🎨 Colour lamp", Modifier.weight(1f)) { colourIdx = 0; colourLamp = true }
            }
            if (mirror) MirrorView()
            NoteText("The torch is the real camera flash. Patterns and Morse run on it; without a flash unit they run on the screen light.")
        }

        if (screenLight) {
            // Full-screen white. With no flash unit, running patterns play on it too.
            val patternDim = if (!torch.hasFlash && (on || morseRunning)) lamp else 1f
            ScreenLightOverlay(alpha = (0.3f + brightness * 0.7f) * patternDim, brightness = brightness,
                onBrightness = { brightness = it }, onClose = { screenLight = false })
        }
        if (colourLamp) {
            ColourLampOverlay(LAMP_COLOURS[colourIdx], onTap = { colourIdx = (colourIdx + 1) % LAMP_COLOURS.size }, onClose = { colourLamp = false })
        }
    }
}

/** The lamp indicator: a 120dp disc that glows with the current level. */
@Composable
private fun LampStage(level: Float, state: String) {
    val off = if (Handy.palette.isDark) Color(0xFF2A2A3A) else Color(0xFFD9DAE3)
    val warm = Color(0xFFFFF3C8)
    val glow = Color(0xFFFFEBA0)
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surface).padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Canvas(Modifier.size(150.dp)) {
            val r = 60.dp.toPx()
            if (level > 0.02f) {
                drawCircle(
                    Brush.radialGradient(listOf(glow.copy(alpha = 0.8f * level), Color.Transparent), center = center, radius = r + 15.dp.toPx() * level + 1f),
                    radius = r + 15.dp.toPx() * level + 1f, center = center
                )
            }
            drawCircle(lerp(off, warm, level.coerceIn(0f, 1f)), r, center)
        }
        Text(state, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, textAlign = TextAlign.Center)
    }
}

/** Front camera, mirrored (CameraX mirrors the front preview by default), with a zoom slider. */
@Composable
private fun MirrorView() {
    val ctx = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current
    var granted by remember { mutableStateOf(ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    var denied by remember { mutableStateOf(false) }
    var zoom by remember { mutableFloatStateOf(1f) }
    var maxZoom by remember { mutableFloatStateOf(3f) }
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
            val cam = runCatching { p.bindToLifecycle(lifecycle, CameraSelector.DEFAULT_FRONT_CAMERA, preview) }.getOrNull()
            if (cam == null) { Toast.makeText(ctx, "No front camera on this phone", Toast.LENGTH_SHORT).show(); return@addListener }
            camera = cam
            maxZoom = (cam.cameraInfo.zoomState.value?.maxZoomRatio ?: 3f).coerceAtLeast(1.01f)
            cam.cameraControl.setZoomRatio(zoom.coerceIn(1f, maxZoom))
        }, ContextCompat.getMainExecutor(ctx))
    }
    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        granted = ok; denied = !ok
        if (ok) bind()
    }
    DisposableEffect(Unit) {
        if (granted) bind() else permLauncher.launch(Manifest.permission.CAMERA)
        onDispose { provider?.unbindAll() }
    }

    Column(Modifier.fillMaxWidth().padding(top = 10.dp)) {
        if (denied) {
            PermissionCard("Camera", "Needed for the mirror.", granted, instrAppSettingsIntent(ctx), "Open settings", privacy = "The preview is never saved.")
        }
        Box(Modifier.fillMaxWidth().aspectRatio(3f / 4f).clip(RoundedCornerShape(16.dp)).background(Color.Black)) {
            AndroidView(factory = { previewView }, modifier = Modifier.fillMaxSize())
        }
        SliderRow("Zoom", "%.1f×".format(zoom), zoom, { zoom = it; camera?.cameraControl?.setZoomRatio(it) }, 1f..maxZoom)
    }
}

@Composable
private fun ScreenLightOverlay(alpha: Float, brightness: Float, onBrightness: (Float) -> Unit, onClose: () -> Unit) {
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        Box(Modifier.fillMaxSize().background(Color.White.copy(alpha = alpha.coerceIn(0.05f, 1f))))
        Column(Modifier.fillMaxSize()) {
            // Tap-anywhere-to-close scrim: an empty interactive region needs a name for screen readers.
            Box(Modifier.weight(1f).fillMaxWidth().clickable(onClick = onClose).semantics { contentDescription = "Close screen light" })
            Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp).navigationBarsPadding().padding(bottom = 20.dp)) {
                Slider(
                    value = brightness, onValueChange = onBrightness, valueRange = 0.1f..1f,
                    colors = SliderDefaults.colors(thumbColor = Color(0xFF444444), activeTrackColor = Color(0xFF444444), inactiveTrackColor = Color(0x33000000))
                )
                Text(
                    "tap above to close · slider sets brightness", style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF666666), textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

@Composable
private fun ColourLampOverlay(colour: Color, onTap: () -> Unit, onClose: () -> Unit) {
    Box(
        Modifier.fillMaxSize().background(colour).pointerInput(Unit) {
            detectTapGestures(onTap = { onTap() }, onLongPress = { onClose() })
        }
    ) {
        Text(
            "tap to change colour · hold to close", style = MaterialTheme.typography.bodySmall,
            color = Color(0x80000000), textAlign = TextAlign.Center,
            modifier = Modifier.align(Alignment.BottomCenter).fillMaxWidth().navigationBarsPadding().padding(bottom = 30.dp)
        )
    }
}
