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
import com.handytools.app.ui.ChipRow
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.NoteText
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

private val PATTERNS = listOf("Steady", "Strobe", "SOS")

/**
 * Flashlight — dead simple: one big on/off, three patterns (Steady / Strobe / SOS), a brightness
 * slider, and a full-screen screen-light for phones with no flash. Everything stops and the screen
 * brightness is restored on leaving.
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
    var screenLight by remember { mutableStateOf(false) }

    fun setLamp(v: Float) { lamp = v; torch.setFraction(v) }

    fun stopPattern() { job?.cancel(); job = null }

    fun runPattern() {
        stopPattern()
        if (!on) { setLamp(0f); return }
        when (pattern) {
            0 -> setLamp(1f)
            1 -> job = scope.launch { var s = false; while (isActive) { s = !s; setLamp(if (s) 1f else 0f); delay(80) } }
            else -> job = scope.launch {
                val seq = FlMorse.sequence(FlMorse.encode("SOS"))
                while (isActive) { for ((v, d) in seq) { setLamp(if (v) 1f else 0f); delay(d) }; setLamp(0f); delay(1200) }
            }
        }
    }

    // Window brightness: the screen light follows the slider; restored to the system value otherwise.
    DisposableEffect(screenLight, brightness) {
        if (screenLight) flSetWindowBrightness(ctx, brightness.coerceIn(0.1f, 1f)) else flSetWindowBrightness(ctx, null)
        onDispose { flSetWindowBrightness(ctx, null) }
    }
    DisposableEffect(Unit) {
        onDispose { job?.cancel(); torch.set(false) }
    }
    BackHandler(enabled = screenLight) { screenLight = false }

    val stateText = if (on) "On · ${PATTERNS[pattern]}" else "Off"

    Box(Modifier.fillMaxSize()) {
        PowerToolPage("flashlight") {
            if (!torch.hasFlash) Pill("No flash on this phone — the screen light stands in", HandyColors.Amber)
            LampStage(lamp * (0.35f + brightness * 0.65f), stateText)
            Spacer(Modifier.height(HandyTokens.Space16))

            // One obvious action, front and centre.
            HPrimaryButton(if (on) "⏻  Turn off" else "💡  Turn on") {
                on = !on
                HandyHaptics.light(ctx)
                if (on && !torch.hasFlash) screenLight = true
                runPattern()
            }

            SectionLabel("Pattern")
            ChipRow {
                PATTERNS.forEachIndexed { i, p ->
                    HChip(p, pattern == i) { pattern = i; if (on) runPattern() }
                }
            }

            SliderRow(
                "Brightness", "${(brightness * 100).roundToInt()}%", brightness,
                onChange = { v ->
                    brightness = v
                    if (torch.hasLevels) { torch.setStrength(v); if (on && pattern == 0) torch.set(true) }
                },
                range = 0.1f..1f
            )
            if (torch.hasFlash && !torch.hasLevels) {
                Text(
                    "This phone's torch has one brightness — the slider sets the screen light instead.",
                    style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary
                )
            }

            Spacer(Modifier.height(HandyTokens.Space12))
            HSecondaryButton("🖥  Full-screen light") { screenLight = true }
            NoteText("Turns your whole screen into a bright light — handy when your phone has no camera flash.")
        }

        if (screenLight) {
            // Full-screen white. With no flash unit, a running pattern plays on it too.
            val patternDim = if (!torch.hasFlash && on) lamp else 1f
            ScreenLightOverlay(alpha = (0.3f + brightness * 0.7f) * patternDim, brightness = brightness,
                onBrightness = { brightness = it }, onClose = { screenLight = false })
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

