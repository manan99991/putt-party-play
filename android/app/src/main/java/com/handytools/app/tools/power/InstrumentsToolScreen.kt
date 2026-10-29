package com.handytools.app.tools.power

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorManager
import android.location.LocationManager
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.handytools.app.ui.BigToggle
import com.handytools.app.ui.ChipRow
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HTextButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PermissionCard
import com.handytools.app.ui.Pill
import com.handytools.app.ui.PowerToolPage
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Instruments — level, compass, sound, light, altitude, metal, ruler, magnifier. One tab at a
 * time; each tab registers its own sensors while it is on screen and lets go when you switch.
 */
@Composable
fun InstrumentsToolScreen() {
    val tabs = listOf("Level", "Compass", "Sound", "Light", "Altitude", "Metal", "Ruler", "Magnifier")
    var tab by remember { mutableIntStateOf(0) }
    PowerToolPage("instruments", tabs, tab, { tab = it }) {
        when (tab) {
            0 -> LevelPanel()
            1 -> CompassPanel()
            2 -> SoundPanel()
            3 -> LightPanel()
            4 -> AltitudePanel()
            5 -> MetalPanel()
            6 -> RulerPanel()
            else -> MagnifierPanel()
        }
    }
}

// ---- Level ----------------------------------------------------------------------------------

@Composable
private fun LevelPanel() {
    val ctx = LocalContext.current
    val prefs = remember { InstrumentPrefs(ctx) }
    var mode by remember { mutableIntStateOf(0) } // 0 bubble, 1 bar
    var offRoll by remember { mutableFloatStateOf(prefs.levelOffRoll) }
    var offPitch by remember { mutableFloatStateOf(prefs.levelOffPitch) }
    var offBar by remember { mutableFloatStateOf(prefs.levelOffBar) }
    var gx by remember { mutableFloatStateOf(0f) }
    var gy by remember { mutableFloatStateOf(0f) }
    var gz by remember { mutableFloatStateOf(9.81f) }
    var got by remember { mutableStateOf(false) }
    val type = remember { if (instrHasSensor(ctx, Sensor.TYPE_GRAVITY)) Sensor.TYPE_GRAVITY else Sensor.TYPE_ACCELEROMETER }
    val present = rememberInstrSensor(type, SensorManager.SENSOR_DELAY_GAME) { e ->
        // Low-pass so the bubble glides instead of jittering.
        gx = gx * 0.8f + e.values[0] * 0.2f
        gy = gy * 0.8f + e.values[1] * 0.2f
        gz = gz * 0.8f + e.values[2] * 0.2f
        got = true
    }

    // Raw tilt angles in degrees. roll: around the long axis (x > 0 means the right edge is up).
    // pitch: around the short axis (y > 0 means the top edge is up, i.e. tilted toward you).
    val rawRoll = Math.toDegrees(atan2(gx.toDouble(), gz.toDouble())).toFloat()
    val rawPitch = Math.toDegrees(atan2(gy.toDouble(), gz.toDouble())).toFloat()
    val rawBar = Math.toDegrees(atan2(gx.toDouble(), sqrt((gy * gy + gz * gz).toDouble()))).toFloat()
    val roll = rawRoll - offRoll
    val pitch = rawPitch - offPitch
    val bar = rawBar - offBar
    val angle = if (mode == 0) hypot(roll, pitch) else abs(bar)
    val level = got && angle < 0.8f
    val sub = when {
        !present -> "No motion sensor on this phone"
        !got -> "Lay the phone on the surface"
        level -> "✓ Level"
        mode == 1 -> if (bar > 0) "Tilted left" else "Tilted right"
        abs(pitch) > abs(roll) -> if (pitch > 0) "Tilted toward you" else "Tilted away"
        else -> if (roll > 0) "Tilted left" else "Tilted right"
    }
    val border = Handy.palette.border
    val dotColor = if (level) HandyColors.Success else HandyColors.Accent

    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        if (mode == 0) {
            // Bubble gauge: 200dp circle, crosshair, dot that rolls to the low side.
            val nx = (-roll / 90f).coerceIn(-1f, 1f)
            val ny = (pitch / 90f).coerceIn(-1f, 1f)
            Canvas(Modifier.padding(top = 8.dp).size(200.dp)) {
                val r = size.minDimension / 2
                val inset = 10.dp.toPx()
                drawCircle(border, r, style = Stroke(2.dp.toPx()))
                drawCircle(border.copy(alpha = 0.6f), 14.dp.toPx(), style = Stroke(1.dp.toPx()))
                drawLine(border, Offset(center.x, inset), Offset(center.x, size.height - inset), 1.dp.toPx())
                drawLine(border, Offset(inset, center.y), Offset(size.width - inset, center.y), 1.dp.toPx())
                val dotR = 11.dp.toPx()
                drawCircle(dotColor, dotR, center = Offset(center.x + nx * (r - dotR - 2), center.y + ny * (r - dotR - 2)))
            }
        } else {
            // Bar: a horizontal spirit level for edges and shelves. Bubble slides to the high side.
            val bx = (bar / 45f).coerceIn(-1f, 1f)
            Box(
                Modifier.padding(top = 24.dp, bottom = 24.dp).fillMaxWidth().height(56.dp)
                    .clip(RoundedCornerShape(28.dp)).background(MaterialTheme.colorScheme.surface)
                    .border(2.dp, border, RoundedCornerShape(28.dp))
            ) {
                Canvas(Modifier.fillMaxSize()) {
                    val w = size.width
                    val lineW = 2.dp.toPx()
                    drawLine(border, Offset(w / 2 - 20.dp.toPx(), 0f), Offset(w / 2 - 20.dp.toPx(), size.height), lineW)
                    drawLine(border, Offset(w / 2 + 20.dp.toPx(), 0f), Offset(w / 2 + 20.dp.toPx(), size.height), lineW)
                    val bubbleW = 36.dp.toPx()
                    val travel = (w - bubbleW) / 2 - 6.dp.toPx()
                    val cx = w / 2 - bx * travel
                    drawRoundRect(
                        dotColor, topLeft = Offset(cx - bubbleW / 2, 6.dp.toPx()),
                        size = androidx.compose.ui.geometry.Size(bubbleW, size.height - 12.dp.toPx()),
                        cornerRadius = androidx.compose.ui.geometry.CornerRadius(20.dp.toPx())
                    )
                }
            }
        }
        InstrBigReadout(if (!present || !got) "—" else "%.1f°".format(angle), if (level) HandyColors.Success else HandyColors.Accent)
        InstrSubLine(sub, if (level) HandyColors.Success else Handy.palette.textSecondary)
        Spacer(Modifier.height(10.dp))
        ChipRow {
            HChip("Bubble", mode == 0) { mode = 0 }
            HChip("Bar", mode == 1) { mode = 1 }
            HChip("Calibrate", false) {
                offRoll = rawRoll; offPitch = rawPitch; offBar = rawBar
                prefs.levelOffRoll = rawRoll; prefs.levelOffPitch = rawPitch; prefs.levelOffBar = rawBar
                HandyHaptics.medium(ctx)
                Toast.makeText(ctx, "Zeroed to current angle", Toast.LENGTH_SHORT).show()
            }
        }
        if (offRoll != 0f || offPitch != 0f || offBar != 0f) {
            HTextButton("Reset zero") {
                offRoll = 0f; offPitch = 0f; offBar = 0f
                prefs.levelOffRoll = 0f; prefs.levelOffPitch = 0f; prefs.levelOffBar = 0f
            }
        }
        NoteText(
            if (mode == 0) "Lay the phone flat on the surface. Calibrate zeroes it against a surface you know is level."
            else "Stand the phone on its long edge along the shelf or frame. Calibrate zeroes it against a known level edge."
        )
    }
}

// ---- Compass --------------------------------------------------------------------------------

@Composable
private fun CompassPanel() {
    val ctx = LocalContext.current
    var azimuth by remember { mutableFloatStateOf(0f) }
    var got by remember { mutableStateOf(false) }
    var accuracy by remember { mutableIntStateOf(SensorManager.SENSOR_STATUS_ACCURACY_HIGH) }
    var trueNorth by remember { mutableStateOf(false) }
    val rot = remember { FloatArray(9) }
    val orient = remember { FloatArray(3) }
    val grav = remember { FloatArray(3) }
    val geo = remember { FloatArray(3) }
    var haveGrav by remember { mutableStateOf(false) }
    var haveGeo by remember { mutableStateOf(false) }

    fun push(deg: Float) {
        var d = deg
        if (d < 0) d += 360f
        if (!got) { azimuth = d; got = true; return }
        // Shortest-path smoothing so 359 -> 1 doesn't spin the rose the long way round.
        val diff = ((d - azimuth + 540f) % 360f) - 180f
        azimuth = (azimuth + diff * 0.2f + 360f) % 360f
    }

    val hasRotVec = remember { instrHasSensor(ctx, Sensor.TYPE_ROTATION_VECTOR) }
    if (hasRotVec) {
        rememberInstrSensor(Sensor.TYPE_ROTATION_VECTOR, SensorManager.SENSOR_DELAY_GAME, onAccuracy = { accuracy = it }) { e ->
            SensorManager.getRotationMatrixFromVector(rot, e.values)
            SensorManager.getOrientation(rot, orient)
            push(Math.toDegrees(orient[0].toDouble()).toFloat())
        }
    } else {
        // Fallback: accelerometer + magnetometer.
        rememberInstrSensor(Sensor.TYPE_ACCELEROMETER, SensorManager.SENSOR_DELAY_GAME) { e ->
            for (i in 0..2) grav[i] = grav[i] * 0.8f + e.values[i] * 0.2f
            haveGrav = true
        }
        rememberInstrSensor(Sensor.TYPE_MAGNETIC_FIELD, SensorManager.SENSOR_DELAY_GAME, onAccuracy = { accuracy = it }) { e ->
            for (i in 0..2) geo[i] = geo[i] * 0.8f + e.values[i] * 0.2f
            haveGeo = true
            if (haveGrav && SensorManager.getRotationMatrix(rot, null, grav, geo)) {
                SensorManager.getOrientation(rot, orient)
                push(Math.toDegrees(orient[0].toDouble()).toFloat())
            }
        }
    }
    val hasMag = remember { instrHasSensor(ctx, Sensor.TYPE_MAGNETIC_FIELD) }
    val present = hasRotVec || hasMag

    // True north: only offered when we already have a location fix (no permission prompt here).
    val declination = remember {
        val fine = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) null else try {
            val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val loc = lm.getLastKnownLocation(LocationManager.GPS_PROVIDER) ?: lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            loc?.let { GeomagneticField(it.latitude.toFloat(), it.longitude.toFloat(), it.altitude.toFloat(), System.currentTimeMillis()).declination }
        } catch (_: SecurityException) { null } catch (_: Exception) { null }
    }
    val heading = ((azimuth + (if (trueNorth && declination != null) declination else 0f)) + 360f) % 360f
    val dirs = listOf("N", "NE", "E", "SE", "S", "SW", "W", "NW")
    val cardinal = dirs[((heading / 45f).roundToInt()) % 8]
    val border = Handy.palette.border
    val lowAcc = accuracy == SensorManager.SENSOR_STATUS_ACCURACY_LOW || accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE

    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.padding(top = 8.dp).size(200.dp), contentAlignment = Alignment.Center) {
            Box(Modifier.fillMaxSize().rotate(-heading)) {
                Canvas(Modifier.fillMaxSize()) {
                    val r = size.minDimension / 2
                    drawCircle(border, r, style = Stroke(3.dp.toPx()))
                    for (i in 0 until 72) {
                        val a = Math.toRadians(i * 5.0)
                        val len = if (i % 18 == 0) 0f else if (i % 6 == 0) 10.dp.toPx() else 5.dp.toPx()
                        if (len == 0f) continue
                        val sx = center.x + (r - 4.dp.toPx()) * kotlin.math.sin(a).toFloat()
                        val sy = center.y - (r - 4.dp.toPx()) * kotlin.math.cos(a).toFloat()
                        val ex = center.x + (r - 4.dp.toPx() - len) * kotlin.math.sin(a).toFloat()
                        val ey = center.y - (r - 4.dp.toPx() - len) * kotlin.math.cos(a).toFloat()
                        drawLine(border, Offset(sx, sy), Offset(ex, ey), 1.dp.toPx())
                    }
                }
                Text("N", Modifier.align(Alignment.TopCenter).padding(top = 8.dp), color = HandyColors.Danger, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                Text("S", Modifier.align(Alignment.BottomCenter).padding(bottom = 8.dp), fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                Text("W", Modifier.align(Alignment.CenterStart).padding(start = 10.dp), fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                Text("E", Modifier.align(Alignment.CenterEnd).padding(end = 10.dp), fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
            }
            // Fixed needle at the top: this is where the phone is pointing.
            Box(Modifier.align(Alignment.TopCenter).offset(y = 6.dp).width(3.dp).height(28.dp).background(HandyColors.Accent, RoundedCornerShape(2.dp)))
        }
        InstrBigReadout(if (!present || !got) "—" else "${heading.roundToInt()}° $cardinal")
        InstrSubLine(
            when {
                !present -> "No compass sensor on this phone"
                trueNorth && declination != null -> "true heading"
                else -> "magnetic heading"
            }
        )
        if (present && lowAcc) {
            Spacer(Modifier.height(8.dp))
            Pill("Accuracy low — move the phone in a figure 8", HandyColors.Amber)
        }
        if (present && declination != null) {
            Spacer(Modifier.height(8.dp))
            BigToggle("True north (adjusts ${"%+.1f".format(declination)}°)", trueNorth) { trueNorth = it }
        }
        NoteText(
            if (!present) "Without a magnetometer the compass can't read a heading. The Level tab still works."
            else "Hold the phone flat and keep it away from magnets, speakers and metal cases."
        )
    }
}

// ---- Sound ----------------------------------------------------------------------------------

@Composable
private fun SoundPanel() {
    val ctx = LocalContext.current
    fun hasMic() = ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    var granted by remember { mutableStateOf(hasMic()) }
    var denied by remember { mutableStateOf(false) }
    var running by remember { mutableStateOf(false) }
    var db by remember { mutableIntStateOf(0) }
    var peak by remember { mutableIntStateOf(0) }
    var sum by remember { mutableIntStateOf(0) }
    var n by remember { mutableIntStateOf(0) }
    val meter = remember {
        InstrSoundMeter { v -> db = v; if (v > peak) peak = v; sum += v; n += 1 }
    }
    fun start() {
        peak = 0; sum = 0; n = 0
        running = meter.start()
        if (!running) Toast.makeText(ctx, "Couldn't open the microphone", Toast.LENGTH_SHORT).show()
    }
    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        granted = ok; denied = !ok
        if (ok) start()
    }
    DisposableEffect(Unit) { onDispose { meter.stop() } }

    val color = when { db > 85 -> HandyColors.Danger; db > 70 -> HandyColors.Amber; else -> HandyColors.Accent }
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        if (denied) {
            PermissionCard(
                "Microphone", "Needed to measure how loud it is around you.", granted, instrAppSettingsIntent(ctx),
                "Open settings", privacy = "Audio is measured live and never recorded or saved."
            )
        }
        InstrBigReadout(if (running || n > 0) "$db" else "—", color)
        InstrSubLine("dB (approx.)")
        InstrBar(db / 120f, color)
        Row(Modifier.fillMaxWidth().padding(top = 4.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(if (n > 0) "$peak" else "—", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text("peak", style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(if (n > 0) "${sum / n}" else "—", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text("average", style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
            }
        }
        InstrRefTable(
            listOf(
                InstrRef("Quiet room", "30–40"),
                InstrRef("Conversation", "60"),
                InstrRef("Traffic", "80"),
                InstrRef("Harmful over time", "85+", HandyColors.Danger),
            )
        )
        Spacer(Modifier.height(16.dp))
        HPrimaryButton(if (running) "⏹ Stop" else "🎙 Start measuring") {
            if (running) { meter.stop(); running = false }
            else if (granted) start()
            else permLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
        NoteText("Phone mics aren't lab meters — treat readings as a guide, within a few dB.")
    }
}

// ---- Light ----------------------------------------------------------------------------------

@Composable
private fun LightPanel() {
    var lux by remember { mutableFloatStateOf(-1f) }
    val present = rememberInstrSensor(Sensor.TYPE_LIGHT) { e -> lux = e.values[0] }
    val desc = when {
        lux < 0f -> ""
        lux < 10f -> "Dark"
        lux < 100f -> "Dim"
        lux < 300f -> "Soft indoor light"
        lux < 1000f -> "Reading / office light"
        lux < 10000f -> "Bright — overcast outdoors"
        else -> "Daylight"
    }
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Pill(if (present) "Runs natively · ambient light sensor" else "No light sensor", if (present) HandyColors.Accent else HandyColors.Amber)
        InstrBigReadout(if (present && lux >= 0f) "${lux.roundToInt()}" else "—")
        InstrSubLine(if (present) (if (desc.isEmpty()) "lux" else "lux · $desc") else "lux")
        if (present) InstrBar((kotlin.math.log10((lux.coerceAtLeast(1f)).toDouble()).toFloat() / 5f))
        if (!present) {
            InstrSubLine("This phone has no ambient light sensor, so there's no live reading — use the table to judge by eye.", HandyColors.Amber)
        }
        InstrRefTable(
            listOf(
                InstrRef("Moonlight", "<1"),
                InstrRef("Dim hallway", "50"),
                InstrRef("Reading light", "300–500"),
                InstrRef("Office", "500"),
                InstrRef("Overcast day", "1,000"),
                InstrRef("Direct sunlight", "30,000+"),
            )
        )
        NoteText("The sensor sits near the front camera — don't cover the top of the phone.")
    }
}

// Shared by the altitude tab: a compact labelled value tile.
@Composable
internal fun InstrTile(modifier: Modifier, label: String, value: String, sub: String) {
    Column(
        modifier.clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surface)
            .border(1.dp, Handy.palette.border, RoundedCornerShape(16.dp)).padding(14.dp)
    ) {
        Text(label.uppercase(), style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
        Text(value, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.ExtraBold, modifier = Modifier.padding(top = 4.dp))
        Text(sub, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
    }
}
