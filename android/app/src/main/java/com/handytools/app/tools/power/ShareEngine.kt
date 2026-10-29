package com.handytools.app.tools.power

import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSuggestion
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.EncodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeWriter
import kotlinx.coroutines.tasks.await
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.Inet4Address
import java.net.URL

internal enum class CodeKind(val label: String) { LINK("Link"), WIFI("Wi-Fi login"), TEXT("Text"), CONTACT("Contact"), BARCODE("Barcode") }

internal data class Decoded(val raw: String, val kind: CodeKind)
internal data class WifiCreds(val ssid: String, val password: String, val security: String, val hidden: Boolean)
internal data class ContactInfo(val name: String, val phone: String, val email: String)
internal data class NetInfo(
    val connected: Boolean, val wifi: Boolean, val ssid: String?, val rssi: Int?, val linkSpeed: Int?,
    val ip: String?, val gateway: String?, val dns: String?,
)

/** QR / Wi-Fi / network helpers for Share & Connect. All on-device; the speed test is the only network call. */
internal object ShareEngine {

    // ------------------------------------------------------------------ QR

    fun qr(text: String, size: Int = 640): Bitmap? = try {
        val hints = mapOf(EncodeHintType.MARGIN to 1)
        val m = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, size, size, hints)
        val w = m.width; val h = m.height
        val px = IntArray(w * h)
        for (y in 0 until h) { val o = y * w; for (x in 0 until w) px[o + x] = if (m.get(x, y)) android.graphics.Color.BLACK else android.graphics.Color.WHITE }
        Bitmap.createBitmap(w, h, Bitmap.Config.RGB_565).apply { setPixels(px, 0, w, 0, 0, w, h) }
    } catch (_: Exception) { null }

    private fun esc(s: String) = s.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace(":", "\\:")

    /** security: "WPA", "WEP" or "nopass". */
    fun wifiString(ssid: String, password: String, security: String): String {
        val t = if (password.isBlank()) "nopass" else security
        return "WIFI:T:$t;S:${esc(ssid)};${if (password.isBlank()) "" else "P:${esc(password)};"};"
    }

    fun vcard(name: String, phone: String, email: String): String = buildString {
        append("BEGIN:VCARD\nVERSION:3.0\n")
        if (name.isNotBlank()) append("FN:").append(name.trim()).append('\n')
        if (phone.isNotBlank()) append("TEL:").append(phone.trim()).append('\n')
        if (email.isNotBlank()) append("EMAIL:").append(email.trim()).append('\n')
        append("END:VCARD")
    }

    fun savePng(ctx: Context, bmp: Bitmap, name: String): Boolean = try {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= 29) put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Tenzy")
        }
        val uri = ctx.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        if (uri == null) false
        else {
            ctx.contentResolver.openOutputStream(uri)?.use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
            true
        }
    } catch (_: Exception) { false }

    fun pngFile(ctx: Context, bmp: Bitmap, prefix: String): File? = try {
        val f = File(ctx.cacheDir, "$prefix-${System.currentTimeMillis()}.png")
        FileOutputStream(f).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        f
    } catch (_: Exception) { null }

    // ------------------------------------------------------------------ decoding

    fun classify(raw: String, isQr: Boolean): Decoded {
        val t = raw.trim()
        val kind = when {
            t.startsWith("WIFI:", ignoreCase = true) -> CodeKind.WIFI
            t.startsWith("BEGIN:VCARD", ignoreCase = true) || t.startsWith("MECARD:", ignoreCase = true) -> CodeKind.CONTACT
            Regex("^(https?://|www\\.)", RegexOption.IGNORE_CASE).containsMatchIn(t) -> CodeKind.LINK
            !isQr -> CodeKind.BARCODE
            else -> CodeKind.TEXT
        }
        return Decoded(t, kind)
    }

    /** ML Kit first (handles rotated/perspective codes), zxing as a fallback. */
    suspend fun decodeImage(ctx: Context, uri: Uri): Decoded? {
        try {
            val img = InputImage.fromFilePath(ctx, uri)
            val scanner = BarcodeScanning.getClient()
            val codes = try { scanner.process(img).await() } finally { scanner.close() }
            val first = codes.firstOrNull { !it.rawValue.isNullOrBlank() }
            if (first != null) return classify(first.rawValue ?: "", first.format == Barcode.FORMAT_QR_CODE)
        } catch (_: Exception) {}
        return try {
            val bmp = DocEngine.loadBitmap(ctx, uri, 1600) ?: return null
            val w = bmp.width; val h = bmp.height
            val px = IntArray(w * h)
            bmp.getPixels(px, 0, w, 0, 0, w, h)
            val result = MultiFormatReader().decode(BinaryBitmap(HybridBinarizer(RGBLuminanceSource(w, h, px))))
            classify(result.text, result.barcodeFormat == BarcodeFormat.QR_CODE)
        } catch (_: Exception) { null }
    }

    /** Parses WIFI:T:WPA;S:name;P:pass;H:true;; (handles \; \: \\ escapes). */
    fun parseWifi(raw: String): WifiCreds? {
        val body = raw.trim().removePrefix("WIFI:").removePrefix("wifi:")
        val fields = HashMap<String, String>()
        val sb = StringBuilder(); var i = 0
        while (i < body.length) {
            val c = body[i]
            if (c == '\\' && i + 1 < body.length) { sb.append(body[i + 1]); i += 2; continue }
            if (c == ';') {
                val f = sb.toString(); sb.setLength(0)
                val k = f.substringBefore(':', ""); val v = f.substringAfter(':', "")
                if (k.isNotEmpty()) fields[k.uppercase()] = v
            } else sb.append(c)
            i++
        }
        val ssid = fields["S"] ?: return null
        if (ssid.isBlank()) return null
        val sec = (fields["T"] ?: "").uppercase().ifBlank { if ((fields["P"] ?: "").isBlank()) "NOPASS" else "WPA" }
        return WifiCreds(ssid, fields["P"] ?: "", sec, (fields["H"] ?: "").equals("true", true))
    }

    fun parseContact(raw: String): ContactInfo {
        var name = ""; var phone = ""; var email = ""
        if (raw.trim().startsWith("MECARD:", true)) {
            raw.trim().removePrefix("MECARD:").split(";").forEach { f ->
                val k = f.substringBefore(':', "").uppercase(); val v = f.substringAfter(':', "")
                when (k) { "N" -> name = v.replace(",", " ").trim(); "TEL" -> if (phone.isEmpty()) phone = v; "EMAIL" -> if (email.isEmpty()) email = v }
            }
        } else {
            raw.lines().forEach { line ->
                val key = line.substringBefore(':').substringBefore(';').uppercase()
                val value = line.substringAfter(':', "").trim()
                when (key) {
                    "FN" -> name = value
                    "N" -> if (name.isEmpty()) name = value.split(";").filter { it.isNotBlank() }.reversed().joinToString(" ")
                    "TEL" -> if (phone.isEmpty()) phone = value
                    "EMAIL" -> if (email.isEmpty()) email = value
                }
            }
        }
        return ContactInfo(name, phone, email)
    }

    fun copy(ctx: Context, label: String, text: String) {
        (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText(label, text))
    }

    fun insertContactIntent(c: ContactInfo): Intent {
        val i = Intent(android.provider.ContactsContract.Intents.Insert.ACTION).setType(android.provider.ContactsContract.RawContacts.CONTENT_TYPE)
        if (c.name.isNotBlank()) i.putExtra(android.provider.ContactsContract.Intents.Insert.NAME, c.name)
        if (c.phone.isNotBlank()) i.putExtra(android.provider.ContactsContract.Intents.Insert.PHONE, c.phone)
        if (c.email.isNotBlank()) i.putExtra(android.provider.ContactsContract.Intents.Insert.EMAIL, c.email)
        return i
    }

    // ------------------------------------------------------------------ Wi-Fi join

    /** Best-effort join; returns a one-line status for the UI. The password is always copied too. */
    fun joinWifi(ctx: Context, c: WifiCreds): String {
        val wifi = ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        if (c.password.isNotBlank()) copy(ctx, "Wi-Fi password", c.password)
        if (Build.VERSION.SDK_INT >= 29) {
            var suggested = false
            try {
                val b = WifiNetworkSuggestion.Builder().setSsid(c.ssid)
                if (c.password.isNotBlank()) { if (c.security.contains("WPA3") || c.security == "SAE") b.setWpa3Passphrase(c.password) else b.setWpa2Passphrase(c.password) }
                if (c.hidden) b.setIsHiddenSsid(true)
                suggested = wifi.addNetworkSuggestions(listOf(b.build())) == WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS
            } catch (_: Exception) {}
            try { ctx.startActivity(Intent(Settings.Panel.ACTION_WIFI).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } catch (_: Exception) {}
            return if (suggested) "Handed “${c.ssid}” to Android — pick it in the Wi-Fi panel if it doesn't connect by itself. Password copied."
            else "Pick “${c.ssid}” in the Wi-Fi panel and paste the password (it's copied)."
        }
        @Suppress("DEPRECATION")
        try {
            val conf = android.net.wifi.WifiConfiguration()
            conf.SSID = "\"${c.ssid}\""
            if (c.password.isBlank()) conf.allowedKeyManagement.set(android.net.wifi.WifiConfiguration.KeyMgmt.NONE)
            else if (c.security == "WEP") { conf.wepKeys[0] = "\"${c.password}\""; conf.wepTxKeyIndex = 0; conf.allowedKeyManagement.set(android.net.wifi.WifiConfiguration.KeyMgmt.NONE); conf.allowedGroupCiphers.set(android.net.wifi.WifiConfiguration.GroupCipher.WEP40) }
            else conf.preSharedKey = "\"${c.password}\""
            if (c.hidden) conf.hiddenSSID = true
            val id = wifi.addNetwork(conf)
            if (id >= 0) { wifi.disconnect(); wifi.enableNetwork(id, true); wifi.reconnect(); return "Joining “${c.ssid}”…" }
        } catch (_: Exception) {}
        try { ctx.startActivity(Intent(Settings.ACTION_WIFI_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } catch (_: Exception) {}
        return "Couldn't add it automatically — pick “${c.ssid}” in Wi-Fi settings and paste the password (it's copied)."
    }

    // ------------------------------------------------------------------ network info

    fun netInfo(ctx: Context): NetInfo {
        val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val net = cm.activeNetwork
        val caps = net?.let { cm.getNetworkCapabilities(it) }
        val lp = net?.let { cm.getLinkProperties(it) }
        val wifi = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        val connected = caps != null && (wifi || caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) || caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET))
        val ip = lp?.linkAddresses?.firstOrNull { it.address is Inet4Address }?.address?.hostAddress
        val gateway = lp?.routes?.firstOrNull { it.isDefaultRoute && it.gateway is Inet4Address }?.gateway?.hostAddress
        val dns = lp?.dnsServers?.mapNotNull { it.hostAddress }?.take(2)?.joinToString(", ")?.ifBlank { null }
        var ssid: String? = null; var rssi: Int? = null; var link: Int? = null
        if (wifi) {
            try {
                val wm = ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION") val wi = wm.connectionInfo
                if (wi != null) {
                    val s = wi.ssid?.removeSurrounding("\"")
                    if (!s.isNullOrBlank() && s != "<unknown ssid>" && s != "0x") ssid = s
                    if (wi.rssi in -100..-1) rssi = wi.rssi
                    if (wi.linkSpeed > 0) link = wi.linkSpeed
                }
            } catch (_: Exception) {}
        }
        return NetInfo(connected, wifi, ssid, rssi, link, ip, gateway, dns)
    }

    fun signalLabel(rssi: Int): String = when {
        rssi >= -55 -> "Excellent"
        rssi >= -65 -> "Good"
        rssi >= -75 -> "Fair"
        else -> "Weak"
    }

    /** Same quick sample as Network Scout: an 8 MB download, reported as Mbps + first-byte latency. */
    fun speedTest(): String? = try {
        val conn = URL("https://speed.cloudflare.com/__down?bytes=8000000").openConnection() as HttpURLConnection
        conn.connectTimeout = 8000; conn.readTimeout = 15000
        val start = System.nanoTime()
        var ttfb = 0L; var total = 0L
        conn.inputStream.use { ins ->
            val buf = ByteArray(16 * 1024)
            var n = ins.read(buf)
            if (n >= 0) ttfb = System.nanoTime() - start
            while (n >= 0) { total += n; n = ins.read(buf) }
        }
        conn.disconnect()
        val secs = (System.nanoTime() - start) / 1e9
        val mbps = if (secs > 0) total * 8 / secs / 1e6 else 0.0
        "%.1f Mbps ↓ · %d ms".format(mbps, (ttfb / 1e6).toLong())
    } catch (_: Exception) { null }
}
