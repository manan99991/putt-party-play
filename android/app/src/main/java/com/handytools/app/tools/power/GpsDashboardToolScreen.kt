package com.handytools.app.tools.power

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.PreviewBox
import java.util.Locale
import kotlin.math.roundToInt

/**
 * GPS Dashboard — a live read-out of your speed, heading, altitude and fix quality straight from the
 * phone's GNSS, for a drive, ride or hike. On-device only; nothing is sent anywhere.
 */
@Composable
fun GpsDashboardToolScreen() {
    val ctx = LocalContext.current
    val lm = remember { ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager }
    fun hasLoc() = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    var granted by remember { mutableStateOf(hasLoc()) }
    var fix by remember { mutableStateOf<Location?>(null) }
    var locationOff by remember { mutableStateOf(false) }
    // US users read mph first; the row below always shows km/h too.
    val metricFirst = remember { !Locale.getDefault().country.equals("US", true) }

    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted = it }
    val listener = remember { LocationListener { loc -> fix = loc } }

    DisposableEffect(granted) {
        if (granted && hasLoc()) {
            locationOff = !lm.isProviderEnabled(LocationManager.GPS_PROVIDER) && !lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            try {
                lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)?.let { if (fix == null) fix = it }
                if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, listener)
                if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 2000L, 0f, listener)
            } catch (_: SecurityException) {}
        }
        onDispose { try { lm.removeUpdates(listener) } catch (_: Exception) {} }
    }

    PowerToolPage("gpsdash") {
        if (!granted) {
            PreviewBox(minHeight = 160.dp) {
                Text("GPS Dashboard needs location access to read your speed and position. Nothing is uploaded — it stays on your phone.",
                    style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary, modifier = Modifier.padding(horizontal = 20.dp))
            }
            Spacer(Modifier.height(12.dp))
            HPrimaryButton("Allow location") { permLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION) }
        } else {
            val f = fix
            val mps = if (f != null && f.hasSpeed()) f.speed else 0f
            val mph = mps * 2.236936f
            val kmh = mps * 3.6f
            PreviewBox(minHeight = 170.dp) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    if (f == null) {
                        Text(if (locationOff) "Turn on Location to get a fix." else "Getting a GPS fix…", style = MaterialTheme.typography.titleMedium, color = Handy.palette.textSecondary)
                    } else {
                        Row(verticalAlignment = Alignment.Bottom) {
                            Text(if (metricFirst) "${kmh.roundToInt()}" else "${mph.roundToInt()}", fontSize = 60.sp, fontWeight = FontWeight.ExtraBold, color = HandyColors.Accent)
                            Text(if (metricFirst) " km/h" else " mph", fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = Handy.palette.textSecondary, modifier = Modifier.padding(bottom = 10.dp))
                        }
                        Text(if (metricFirst) "${mph.roundToInt()} mph" else "${kmh.roundToInt()} km/h", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
                    }
                }
            }
            if (f != null) {
                Spacer(Modifier.height(12.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    DashStat(if (f.hasBearing()) "${f.bearing.roundToInt()}° ${cardinal(f.bearing)}" else "—", "heading", Modifier.weight(1f))
                    DashStat(if (f.hasAltitude()) "${(f.altitude * 3.28084).roundToInt()} ft" else "—", "altitude", Modifier.weight(1f))
                    DashStat(if (f.hasAccuracy()) "±${f.accuracy.roundToInt()} m" else "—", "accuracy", Modifier.weight(1f))
                }
                Spacer(Modifier.height(10.dp))
                HCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp)) {
                        Text("Position", style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
                        Spacer(Modifier.height(4.dp))
                        Text("%.5f, %.5f".format(f.latitude, f.longitude), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurface)
                    }
                }
            }
        }
        NoteText("Reads the phone's GNSS directly. Speed and heading need you to be moving, and a clear view of the sky gives the best fix. Nothing is sent anywhere.")
    }
}

@Composable
private fun DashStat(value: String, label: String, modifier: Modifier) {
    HCard(modifier) {
        Box(Modifier.fillMaxWidth().height(72.dp), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                Text(label, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            }
        }
    }
}

private fun cardinal(bearing: Float): String {
    val dirs = listOf("N", "NE", "E", "SE", "S", "SW", "W", "NW")
    return dirs[(((bearing % 360) + 360) % 360 / 45f).roundToInt() % 8]
}
