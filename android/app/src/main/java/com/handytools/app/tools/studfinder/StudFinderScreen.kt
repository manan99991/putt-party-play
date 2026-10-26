package com.handytools.app.tools.studfinder

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.ToolHeader
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Stud & metal finder. Reads the phone's magnetometer (the same sensor the compass uses) and
 * shows how far the field has moved from a baseline you set against open wall — the reading
 * jumps over the nails/screws in a stud, and over pipes and conduit. Works on any phone that
 * has a magnetic sensor (nearly all do); degrades to a clear message if one isn't present,
 * never a blank or dead screen.
 */
@Composable
fun StudFinderScreen() {
    val ctx = LocalContext.current
    val sm = remember { ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager }
    val sensor = remember { sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) }

    var raw by remember { mutableStateOf(0f) }
    var baseline by remember { mutableStateOf<Float?>(null) }
    var peak by remember { mutableStateOf(0f) }
    var lastBuzz by remember { mutableStateOf(0L) }

    DisposableEffect(sensor) {
        val listener = if (sensor == null) null else object : SensorEventListener {
            override fun onSensorChanged(e: SensorEvent) {
                val m = sqrt(e.values[0] * e.values[0] + e.values[1] * e.values[1] + e.values[2] * e.values[2])
                raw = m
                val b = baseline ?: return
                val dev = abs(m - b)
                if (dev > peak) peak = dev
                // Pulse as you cross a strong reading, but no faster than every 180ms.
                if (dev > 20f) {
                    val now = System.currentTimeMillis()
                    if (now - lastBuzz > 180) { HandyHaptics.light(ctx); lastBuzz = now }
                }
            }
            override fun onAccuracyChanged(s: Sensor?, a: Int) {}
        }
        if (sensor != null && listener != null) {
            sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_GAME)
        }
        onDispose { if (listener != null) sm.unregisterListener(listener) }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader(
            "Stud & Metal Finder",
            "Hold the phone flat to the wall, tap Calibrate, then slide it slowly across. The reading climbs over studs, nails, pipes and wiring."
        )
        Spacer(Modifier.size(20.dp))

        if (sensor == null) {
            Text(
                "This phone doesn't report a magnetic sensor, so the finder can't run here. It's the same sensor the compass uses — most phones have one, but a few budget models leave it out.",
                color = Handy.palette.textSecondary
            )
        } else {
            val b = baseline
            val dev = if (b == null) 0f else abs(raw - b)
            val hot = dev > 20f
            val fill by animateFloatAsState(min(1f, dev / 60f), label = "fill")
            val numColor by animateColorAsState(
                if (hot) HandyColors.Accent else MaterialTheme.colorScheme.onBackground, label = "num"
            )

            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    if (b == null) "–" else "%.0f".format(dev),
                    fontSize = 76.sp, fontWeight = FontWeight.Bold, color = numColor
                )
                Text("µT from baseline", color = Handy.palette.textSecondary)
                Spacer(Modifier.size(6.dp))
                Text(
                    if (b == null) "Calibrate against open wall to start"
                    else "Field now %.0f · Strongest this sweep %.0f".format(raw, peak),
                    color = Handy.palette.textSecondary, fontSize = 13.sp, textAlign = TextAlign.Center
                )
            }

            Spacer(Modifier.size(24.dp))

            // Vertical strength meter.
            Box(
                Modifier.fillMaxWidth().height(220.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(Handy.palette.surfaceRaised),
                contentAlignment = Alignment.BottomCenter
            ) {
                Box(
                    Modifier.fillMaxWidth().fillMaxHeight(fill)
                        .clip(RoundedCornerShape(18.dp))
                        .background(if (hot) HandyColors.Accent else MaterialTheme.colorScheme.primary.copy(alpha = 0.55f))
                )
                if (b == null) {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("Not calibrated", color = Handy.palette.textSecondary)
                    }
                }
            }

            Spacer(Modifier.size(24.dp))
            HPrimaryButton(if (b == null) "Calibrate here" else "Re-calibrate") {
                baseline = raw; peak = 0f; HandyHaptics.success(ctx)
            }
        }

        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}
