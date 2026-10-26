package com.handytools.app.tools.netscout

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.InetAddress

private data class Host(val ip: String, val name: String)

/**
 * Network Scout. Shows the current Wi-Fi connection (signal, speed, your IP, gateway, DNS) and, on
 * demand, sweeps the local /24 subnet to list the devices that answer — a quick "who's on my
 * Wi-Fi" without any cloud service. Everything runs on-device over the local network.
 */
@Composable
fun NetworkScoutScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    @Suppress("DEPRECATION")
    val wifi = remember { ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager }
    val cm = remember { ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager }

    var info by remember { mutableStateOf<List<Pair<String, String>>>(emptyList()) }
    var scanning by remember { mutableStateOf(false) }
    var progress by remember { mutableStateOf(0) }
    val hosts = remember { mutableStateListOf<Host>() }

    fun ipString(ip: Int): String =
        "${ip and 0xFF}.${(ip shr 8) and 0xFF}.${(ip shr 16) and 0xFF}.${(ip shr 24) and 0xFF}"

    LaunchedEffect(Unit) {
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
                                    Host(addr, if (host == addr) "Device" else host)
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

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Network Scout", "See your Wi-Fi connection and who else is on the network. Scanning stays on your local network — nothing is uploaded.")
        Spacer(Modifier.size(16.dp))

        info.forEach { (k, v) ->
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(k, color = Handy.palette.textSecondary)
                Text(v, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onBackground)
            }
        }

        Spacer(Modifier.size(16.dp))
        HPrimaryButton(if (scanning) "Scanning… $progress/254" else "Scan my network", enabled = !scanning) { scan() }
        Spacer(Modifier.size(12.dp))

        if (hosts.isNotEmpty()) {
            Text("${hosts.size} device${if (hosts.size == 1) "" else "s"} found", color = Handy.palette.textSecondary)
            Spacer(Modifier.size(6.dp))
            LazyColumn(Modifier.fillMaxWidth().weight(1f)) {
                items(hosts) { h ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(h.ip, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onBackground)
                        Text(h.name, color = Handy.palette.textSecondary)
                    }
                }
            }
        } else if (!scanning) {
            Text("Tap Scan to list the phones, laptops, TVs and smart-home gadgets on your Wi-Fi.", color = Handy.palette.textSecondary)
            Spacer(Modifier.weight(1f))
        } else {
            Spacer(Modifier.weight(1f))
        }

        BannerAd()
    }
}
