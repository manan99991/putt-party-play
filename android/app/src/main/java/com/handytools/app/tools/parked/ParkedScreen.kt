package com.handytools.app.tools.parked

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.ToolHeader
import kotlin.math.roundToInt

private const val PREFS = "parked_spot"

/**
 * Where'd I Park. Drops a GPS pin where you leave the car (plus an optional note like a level or
 * row), then walks you back: live distance and a compass arrow that points at the spot as you
 * turn. Pin is stored locally in SharedPreferences — nothing leaves the phone. Degrades cleanly
 * if location is off or permission is denied: it says what to do instead of showing a dead screen.
 */
@SuppressLint("MissingPermission")
@Composable
fun ParkedScreen() {
    val ctx = LocalContext.current
    val sm = remember { ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager }
    val lm = remember { ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager }
    val prefs = remember { ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE) }

    fun hasLoc() = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED

    var granted by remember { mutableStateOf(hasLoc()) }
    var here by remember { mutableStateOf<Location?>(null) }
    var azimuth by remember { mutableStateOf(0f) }

    // Saved pin.
    var savedLat by remember { mutableStateOf(if (prefs.contains("lat")) prefs.getFloat("lat", 0f).toDouble() else null) }
    var savedLon by remember { mutableStateOf(if (prefs.contains("lon")) prefs.getFloat("lon", 0f).toDouble() else null) }
    var note by remember { mutableStateOf(prefs.getString("note", "") ?: "") }

    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        granted = hasLoc()
    }

    // Live location while the screen is visible.
    DisposableEffect(granted) {
        if (!granted) {
            onDispose { }
        } else {
            val listener = LocationListener { loc -> here = loc }
            val providers = buildList {
                if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) add(LocationManager.GPS_PROVIDER)
                if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) add(LocationManager.NETWORK_PROVIDER)
            }
            try {
                providers.forEach { p ->
                    lm.getLastKnownLocation(p)?.let { if (here == null) here = it }
                    lm.requestLocationUpdates(p, 1000L, 0.5f, listener)
                }
            } catch (_: SecurityException) {}
            onDispose { lm.removeUpdates(listener) }
        }
    }

    // Device heading.
    DisposableEffect(Unit) {
        val rot = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        val listener = if (rot == null) null else object : SensorEventListener {
            private val R = FloatArray(9)
            private val orient = FloatArray(3)
            override fun onSensorChanged(e: SensorEvent) {
                SensorManager.getRotationMatrixFromVector(R, e.values)
                SensorManager.getOrientation(R, orient)
                azimuth = ((Math.toDegrees(orient[0].toDouble()) + 360) % 360).toFloat()
            }
            override fun onAccuracyChanged(s: Sensor?, a: Int) {}
        }
        if (rot != null && listener != null) sm.registerListener(listener, rot, SensorManager.SENSOR_DELAY_UI)
        onDispose { if (listener != null) sm.unregisterListener(listener) }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Where'd I Park", "Drop a pin at the car, then follow the arrow back. The pin stays on your phone.")
        Spacer(Modifier.size(20.dp))

        if (!granted) {
            Text(
                "Turn on location to drop and find your parking pin. Your location is used only on this phone to measure the distance back — it's never uploaded.",
                color = Handy.palette.textSecondary
            )
            Spacer(Modifier.size(16.dp))
            HSecondaryButton("Allow location", modifier = Modifier.fillMaxWidth()) {
                permLauncher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
            }
        } else {
            val sLat = savedLat
            val sLon = savedLon
            val cur = here

            if (sLat != null && sLon != null) {
                // Distance + bearing to the saved pin.
                var distM = Float.NaN
                var bearing = 0f
                if (cur != null) {
                    val res = FloatArray(2)
                    Location.distanceBetween(cur.latitude, cur.longitude, sLat, sLon, res)
                    distM = res[0]
                    bearing = res[1]  // degrees from current to car
                }
                val arrowDeg = (bearing - azimuth + 360) % 360

                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(Modifier.size(140.dp), contentAlignment = Alignment.Center) {
                        Icon(
                            Icons.Filled.Navigation, contentDescription = "Direction to car",
                            tint = HandyColors.Accent,
                            modifier = Modifier.size(120.dp).rotate(if (distM.isNaN()) 0f else arrowDeg)
                        )
                    }
                    Spacer(Modifier.size(12.dp))
                    Text(
                        if (distM.isNaN()) "Finding you…" else formatDistance(distM),
                        fontSize = 40.sp, fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onBackground
                    )
                    if (note.isNotBlank()) {
                        Text(note, color = Handy.palette.textSecondary, textAlign = TextAlign.Center)
                    }
                    Text(
                        if (distM.isNaN()) "Getting a GPS fix — step outside if it's slow."
                        else "to your parking pin",
                        color = Handy.palette.textSecondary, fontSize = 13.sp
                    )
                }
                Spacer(Modifier.size(28.dp))
                HSecondaryButton("Clear pin", modifier = Modifier.fillMaxWidth()) {
                    prefs.edit().clear().apply()
                    savedLat = null; savedLon = null; note = ""
                    HandyHaptics.light(ctx)
                }
            } else {
                Text(
                    "Park, then tap below to save this spot. Add a note if the lot has levels or rows.",
                    color = Handy.palette.textSecondary
                )
                Spacer(Modifier.size(16.dp))
                OutlinedTextField(
                    value = note, onValueChange = { note = it },
                    label = { Text("Note (optional) — e.g. Level 3, Blue") },
                    modifier = Modifier.fillMaxWidth(), singleLine = true
                )
                Spacer(Modifier.size(16.dp))
                val loc = here
                HPrimaryButton("Save this spot", enabled = loc != null) {
                    if (loc != null) {
                        prefs.edit()
                            .putFloat("lat", loc.latitude.toFloat())
                            .putFloat("lon", loc.longitude.toFloat())
                            .putString("note", note)
                            .apply()
                        savedLat = loc.latitude; savedLon = loc.longitude
                        HandyHaptics.success(ctx)
                    }
                }
                if (here == null) {
                    Spacer(Modifier.size(8.dp))
                    Text("Getting a GPS fix… step outside if it's slow.", color = Handy.palette.textSecondary, fontSize = 13.sp)
                }
            }
        }

        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

private fun formatDistance(m: Float): String =
    if (m < 1000) "${m.roundToInt()} m" else "%.1f km".format(m / 1000f)
