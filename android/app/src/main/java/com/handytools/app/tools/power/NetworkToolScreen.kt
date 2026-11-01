package com.handytools.app.tools.power

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Devices
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.material.icons.outlined.Wifi
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.PreviewBox
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.InetAddress

private data class NetHost(val ip: String, val name: String)

/**
 * Network — the phone's connection as a proper tool. Three jobs, one per tab: measure your real
 * internet speed, read everything about the current connection, and see who else is on your Wi-Fi.
 * Everything runs on-device over the local network (the speed test pulls a file from Cloudflare);
 * nothing about your network is uploaded.
 */
@Composable
fun NetworkToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    @Suppress("DEPRECATION")
    val wifi = remember { ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager }
    val cm = remember { ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager }

    var tab by remember { mutableIntStateOf(0) }
    val tabs = listOf("Speed test", "This network", "Devices")
    val tabIcons = listOf(Icons.Outlined.Speed, Icons.Outlined.Wifi, Icons.Outlined.Devices)
    val tabTints = listOf(Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFF8B5CF6))

    // Shared state
    var info by remember { mutableStateOf<List<Pair<String, String>>>(emptyList()) }
    var mbps by remember { mutableStateOf<Double?>(null) }
    var latencyMs by remember { mutableStateOf<Long?>(null) }
    var testing by remember { mutableStateOf(false) }
    var speedError by remember { mutableStateOf<String?>(null) }
    var scanning by remember { mutableStateOf(false) }
    var progress by remember { mutableIntStateOf(0) }
    val hosts = remember { mutableStateListOf<NetHost>() }

    fun ipString(ip: Int): String =
        "${ip and 0xFF}.${(ip shr 8) and 0xFF}.${(ip shr 16) and 0xFF}.${(ip shr 24) and 0xFF}"

    fun refreshInfo() {
        val rows = mutableListOf<Pair<String, String>>()
        val net = cm.activeNetwork
        val caps = net?.let { cm.getNetworkCapabilities(it) }
        val onWifi = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        rows += "Connection" to when {
            onWifi -> "Wi-Fi"
            caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "Mobile data"
            else -> "Not connected"
        }
        @Suppress("DEPRECATION")
        run {
            val wi = wifi.connectionInfo
            if (onWifi && wi != null) {
                val rssi = wi.rssi
                val bars = WifiManager.calculateSignalLevel(rssi, 5)
                rows += "Signal" to "$rssi dBm  ($bars/4)"
                if (wi.linkSpeed > 0) rows += "Link speed" to "${wi.linkSpeed} Mbps"
            }
            val dhcp = wifi.dhcpInfo
            if (dhcp != null) {
                if (dhcp.ipAddress != 0) rows += "Your IP" to ipString(dhcp.ipAddress)
                if (dhcp.gateway != 0) rows += "Router" to ipString(dhcp.gateway)
                if (dhcp.dns1 != 0) rows += "DNS" to ipString(dhcp.dns1)
            }
        }
        info = rows
    }

    LaunchedEffect(Unit) { refreshInfo() }

    fun speedTest() {
        if (testing) return
        testing = true; speedError = null; mbps = null; latencyMs = null
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                try {
                    val conn = java.net.URL("https://speed.cloudflare.com/__down?bytes=10000000").openConnection() as java.net.HttpURLConnection
                    conn.connectTimeout = 8000; conn.readTimeout = 15000
                    val start = System.nanoTime()
                    var ttfb = 0L; var total = 0L
                    conn.inputStream.use { ins ->
                        val buf = ByteArray(32 * 1024)
                        var n = ins.read(buf)
                        if (n >= 0) ttfb = System.nanoTime() - start
                        while (n >= 0) { total += n; n = ins.read(buf) }
                    }
                    conn.disconnect()
                    val secs = (System.nanoTime() - start) / 1e9
                    val rate = if (secs > 0) total * 8 / secs / 1e6 else 0.0
                    rate to (ttfb / 1e6).toLong()
                } catch (_: Throwable) { null }
            }
            testing = false
            if (result != null) { mbps = result.first; latencyMs = result.second }
            else speedError = "Couldn't reach the test server. Check your connection and try again."
        }
    }

    fun scan() {
        if (scanning) return
        hosts.clear(); progress = 0; scanning = true
        scope.launch {
            @Suppress("DEPRECATION")
            val myIp = wifi.dhcpInfo?.ipAddress ?: 0
            if (myIp == 0) { scanning = false; return@launch }
            val prefix = "${myIp and 0xFF}.${(myIp shr 8) and 0xFF}.${(myIp shr 16) and 0xFF}."
            withContext(Dispatchers.IO) {
                (1..254).chunked(32).forEach { chunk ->
                    chunk.map { n ->
                        async {
                            val addr = "$prefix$n"
                            try {
                                val ia = InetAddress.getByName(addr)
                                if (ia.isReachable(400)) {
                                    val host = ia.canonicalHostName
                                    NetHost(addr, if (host == addr) "Device" else host)
                                } else null
                            } catch (_: Exception) { null }
                        }
                    }.awaitAll().filterNotNull().forEach { h -> hosts.add(h) }
                    progress += chunk.size
                }
            }
            hosts.sortBy { it.ip.substringAfterLast('.').toIntOrNull() ?: 0 }
            scanning = false
        }
    }

    PowerToolPage("network", tabs, tab, { tab = it }, tabIcons = tabIcons, accent = tabTints.getOrNull(tab)) {
        when (tab) {
            0 -> {
                NoteText("Measures your real download speed and latency by pulling a test file from Cloudflare — the honest number your phone actually gets right now. Uses about 10 MB of data; everything else stays on your device.")
                Spacer(Modifier.height(14.dp))
                PreviewBox(minHeight = 160.dp) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        when {
                            testing -> Text("Testing…", style = MaterialTheme.typography.titleMedium, color = Handy.palette.textSecondary)
                            mbps != null -> {
                                Row(verticalAlignment = Alignment.Bottom) {
                                    Text("%.1f".format(mbps), fontSize = 52.sp, fontWeight = FontWeight.ExtraBold, color = HandyColors.Accent)
                                    Text(" Mbps", fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = Handy.palette.textSecondary, modifier = Modifier.padding(bottom = 8.dp))
                                }
                                Text("download · ${latencyMs ?: 0} ms latency", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
                            }
                            speedError != null -> Text(speedError!!, style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary, modifier = Modifier.padding(horizontal = 20.dp))
                            else -> Text("Tap below to measure your real download speed.", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary, modifier = Modifier.padding(horizontal = 20.dp))
                        }
                    }
                }
                if (testing) {
                    Spacer(Modifier.height(12.dp))
                    LinearProgressIndicator(Modifier.fillMaxWidth(), color = HandyColors.Accent)
                }
                Spacer(Modifier.height(14.dp))
                HPrimaryButton(if (testing) "Testing…" else if (mbps != null) "Test again" else "Test my speed", enabled = !testing) { speedTest() }
            }
            1 -> {
                NoteText("Everything about your current connection, read straight from the phone — signal, link speed, your IP, the router and DNS. Nothing leaves the device.")
                Spacer(Modifier.height(10.dp))
                if (info.isEmpty()) {
                    Text("No connection details available.", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary, modifier = Modifier.padding(vertical = 12.dp))
                } else {
                    info.forEach { (k, v) ->
                        Row(Modifier.fillMaxWidth().padding(vertical = 7.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(k, color = Handy.palette.textSecondary)
                            Text(v, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onBackground)
                        }
                    }
                }
                Spacer(Modifier.height(14.dp))
                HSecondaryButton("Refresh") { refreshInfo() }
            }
            else -> {
                NoteText("Pings every address on your Wi-Fi to list the phones, laptops, TVs and smart-home gadgets connected to it — a quick \"who's on my network\". Runs on-device over the local network only.")
                Spacer(Modifier.height(14.dp))
                HPrimaryButton(if (scanning) "Scanning… $progress/254" else "Scan my network", enabled = !scanning) { scan() }
                Spacer(Modifier.height(12.dp))
                if (hosts.isNotEmpty()) {
                    SectionLabel("${hosts.size} device${if (hosts.size == 1) "" else "s"} found")
                    hosts.forEach { h ->
                        Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(h.ip, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onBackground)
                            Text(h.name, color = Handy.palette.textSecondary)
                        }
                    }
                } else if (!scanning) {
                    Box(Modifier.fillMaxWidth().padding(top = 4.dp)) {
                        Text("Tap Scan to list everything on your Wi-Fi. Join the Wi-Fi network first — this can't see devices over mobile data.", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
                    }
                }
            }
        }
    }
}
