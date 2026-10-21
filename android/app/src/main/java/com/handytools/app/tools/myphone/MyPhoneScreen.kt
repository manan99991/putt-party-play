package com.handytools.app.tools.myphone

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.os.SystemClock
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.ToolHeader
import java.net.NetworkInterface

private data class Section(val title: String, val rows: List<Pair<String, String>>)

@Composable
fun MyPhoneScreen() {
    val ctx = LocalContext.current
    var sections by remember { mutableStateOf(collect(ctx)) }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("My Phone", "Everything about this phone at a glance — battery, storage, memory, screen and network. All read on-device.")
        Spacer(Modifier.size(16.dp))

        Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState())) {
            sections.forEach { s ->
                HCard(Modifier.fillMaxWidth().padding(bottom = 10.dp)) {
                    Column(Modifier.padding(16.dp)) {
                        Text(s.title, style = MaterialTheme.typography.titleMedium)
                        Spacer(Modifier.size(8.dp))
                        s.rows.forEach { (label, value) ->
                            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                                Text(label, color = Handy.palette.textSecondary, modifier = Modifier.weight(1f))
                                Spacer(Modifier.size(10.dp))
                                Text(value, style = MaterialTheme.typography.bodyMedium)
                            }
                        }
                    }
                }
            }
        }

        Spacer(Modifier.size(8.dp))
        HSecondaryButton("Refresh", modifier = Modifier.fillMaxWidth()) { sections = collect(ctx) }
        Spacer(Modifier.size(8.dp))
        HSecondaryButton("Copy summary", modifier = Modifier.fillMaxWidth()) {
            Share.text(ctx, sections.joinToString("\n\n") { s -> s.title + "\n" + s.rows.joinToString("\n") { "${it.first}: ${it.second}" } })
        }
        BannerAd()
    }
}

private fun collect(ctx: Context): List<Section> {
    val out = ArrayList<Section>()

    // Battery
    run {
        val bm = ctx.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val pct = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)?.takeIf { it in 0..100 }
        val status = ctx.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val charging = status?.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
            ?.let { it == BatteryManager.BATTERY_STATUS_CHARGING || it == BatteryManager.BATTERY_STATUS_FULL } ?: false
        val tempC = status?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1)?.takeIf { it > 0 }?.let { it / 10.0 }
        val health = when (status?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1)) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "Good"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheating"
            BatteryManager.BATTERY_HEALTH_DEAD -> "Dead"
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Over voltage"
            BatteryManager.BATTERY_HEALTH_COLD -> "Cold"
            else -> "Unknown"
        }
        val rows = ArrayList<Pair<String, String>>()
        if (pct != null) rows.add("Charge" to "$pct%")
        rows.add("Status" to if (charging) "Charging" else "On battery")
        rows.add("Health" to health)
        if (tempC != null) rows.add("Temperature" to "%.1f°C".format(tempC))
        out.add(Section("Battery", rows))
    }

    // Storage
    run {
        val stat = StatFs(Environment.getDataDirectory().absolutePath)
        val total = stat.totalBytes
        val free = stat.availableBytes
        out.add(Section("Storage", listOf(
            "Free" to human(free),
            "Used" to human((total - free).coerceAtLeast(0)),
            "Total" to human(total)
        )))
    }

    // Memory
    run {
        val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val mi = ActivityManager.MemoryInfo()
        am?.getMemoryInfo(mi)
        out.add(Section("Memory (RAM)", listOf(
            "Available" to human(mi.availMem),
            "Total" to human(mi.totalMem),
            "Low memory" to if (mi.lowMemory) "Yes" else "No"
        )))
    }

    // Screen
    run {
        val dm = ctx.resources.displayMetrics
        out.add(Section("Screen", listOf(
            "Resolution" to "${dm.widthPixels} × ${dm.heightPixels}",
            "Density" to "${dm.densityDpi} dpi",
            "Scale" to "%.1fx".format(dm.density)
        )))
    }

    // Device + system
    run {
        val uptime = SystemClock.elapsedRealtime() / 1000
        val h = uptime / 3600; val m = (uptime % 3600) / 60
        out.add(Section("Device", listOf(
            "Model" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "Android" to "${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
            "Uptime" to "${h}h ${m}m"
        )))
    }

    // Network
    run {
        val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        val caps = cm?.getNetworkCapabilities(cm.activeNetwork)
        val type = when {
            caps == null -> "Offline"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "Wi-Fi"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Cellular"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
            else -> "Connected"
        }
        val rows = ArrayList<Pair<String, String>>()
        rows.add("Connection" to type)
        localIp()?.let { rows.add("Local IP" to it) }
        out.add(Section("Network", rows))
    }

    return out
}

private fun localIp(): String? = runCatching {
    for (nif in java.util.Collections.list(NetworkInterface.getNetworkInterfaces())) {
        for (addr in java.util.Collections.list(nif.inetAddresses)) {
            if (!addr.isLoopbackAddress && addr.hostAddress?.contains(':') == false) return@runCatching addr.hostAddress
        }
    }
    null
}.getOrNull()

private fun human(bytes: Long): String {
    if (bytes <= 0) return "0 MB"
    val mb = bytes / 1024.0 / 1024.0
    return if (mb < 1024) "%.0f MB".format(mb) else "%.1f GB".format(mb / 1024.0)
}
