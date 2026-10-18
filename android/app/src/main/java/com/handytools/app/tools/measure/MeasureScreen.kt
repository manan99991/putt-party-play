package com.handytools.app.tools.measure

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.HChip
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.ToolHeader
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** Pocket instruments — a bubble level and a compass, from the phone's sensors. */
@Composable
fun MeasureScreen() {
    var mode by remember { mutableIntStateOf(0) }
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        ToolHeader("Measure", "Level and compass, from your phone's sensors.")
        Spacer(Modifier.size(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.align(Alignment.Start)) {
            HChip("Level", mode == 0) { mode = 0 }
            HChip("Compass", mode == 1) { mode = 1 }
        }
        Spacer(Modifier.size(24.dp))
        if (mode == 0) LevelGauge() else CompassGauge()
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

@Composable
private fun LevelGauge() {
    val ctx = LocalContext.current
    var gx by remember { mutableFloatStateOf(0f) }
    var gy by remember { mutableFloatStateOf(0f) }
    SensorEffect(ctx, Sensor.TYPE_ACCELEROMETER) { e ->
        // Low-pass to steady the bubble.
        gx = gx * 0.8f + e.values[0] * 0.2f
        gy = gy * 0.8f + e.values[1] * 0.2f
    }
    val nx = (-gx / 9.81f).coerceIn(-1f, 1f)
    val ny = (gy / 9.81f).coerceIn(-1f, 1f)
    val angle = Math.toDegrees(atan2(sqrt((gx * gx + gy * gy).toDouble()), 9.81))
    val level = abs(nx) < 0.03f && abs(ny) < 0.03f
    val border = Handy.palette.border
    val textSecondary = Handy.palette.textSecondary
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        Canvas(Modifier.size(260.dp)) {
            val r = size.minDimension / 2
            drawCircle(border, r, style = Stroke(2f))
            drawCircle(border.copy(alpha = 0.5f), 44f, style = Stroke(1f))
            drawCircle(if (level) HandyColors.Success else HandyColors.Accent,
                28f, center = Offset(center.x + nx * (r - 40), center.y + ny * (r - 40)))
        }
        Spacer(Modifier.size(16.dp))
        Text("%.1f°".format(angle), fontSize = 40.sp, fontWeight = FontWeight.Bold,
            color = if (level) HandyColors.Success else Handy.palette.textSecondary)
    }
}

@Composable
private fun CompassGauge() {
    val ctx = LocalContext.current
    var azimuth by remember { mutableFloatStateOf(0f) }
    val rot = remember { FloatArray(9) }
    val orient = remember { FloatArray(3) }
    SensorEffect(ctx, Sensor.TYPE_ROTATION_VECTOR) { e ->
        SensorManager.getRotationMatrixFromVector(rot, e.values)
        SensorManager.getOrientation(rot, orient)
        var deg = Math.toDegrees(orient[0].toDouble()).toFloat()
        if (deg < 0) deg += 360f
        azimuth = azimuth * 0.85f + deg * 0.15f
    }
    val dirs = listOf("N", "NE", "E", "SE", "S", "SW", "W", "NW")
    val cardinal = dirs[(((azimuth + 22.5f) / 45f).toInt()) % 8]
    val border = Handy.palette.border
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        Box(contentAlignment = Alignment.Center) {
            Canvas(Modifier.size(250.dp)) {
                drawCircle(border, size.minDimension / 2, style = Stroke(2f))
            }
            Text("${azimuth.roundToInt()}°  $cardinal", fontSize = 36.sp, fontWeight = FontWeight.Bold)
        }
    }
}

/** Registers a sensor listener for the composable's lifetime. */
@Composable
private fun SensorEffect(ctx: Context, type: Int, onChange: (SensorEvent) -> Unit) {
    DisposableEffect(type) {
        val sm = ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = sm.getDefaultSensor(type)
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) { onChange(event) }
            override fun onAccuracyChanged(s: Sensor?, a: Int) {}
        }
        if (sensor != null) sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_UI)
        onDispose { sm.unregisterListener(listener) }
    }
}
