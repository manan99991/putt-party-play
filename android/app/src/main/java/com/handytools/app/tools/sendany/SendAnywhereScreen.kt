package com.handytools.app.tools.sendany

import android.graphics.Bitmap
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Send Anywhere. Pick a file and it's served from your phone over the local Wi-Fi; the other device
 * scans the QR (or types the address) and downloads it in its browser — no account, no cloud, no
 * cable. The mini server runs only while this screen is open.
 */
@Composable
fun SendAnywhereScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val holder = remember { arrayOfNulls<LocalFileServer>(1) }
    var url by remember { mutableStateOf<String?>(null) }
    var qr by remember { mutableStateOf<Bitmap?>(null) }
    var fileLabel by remember { mutableStateOf<String?>(null) }
    var status by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }

    DisposableEffect(Unit) { onDispose { holder[0]?.stop() } }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        busy = true; status = null; url = null; qr = null; fileLabel = null
        holder[0]?.stop()
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                val ip = LocalFileServer.localIpv4() ?: return@withContext null
                var name = "file"; var sizeB = -1L
                try {
                    ctx.contentResolver.query(uri, null, null, null, null)?.use { c ->
                        val ni = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        val si = c.getColumnIndex(OpenableColumns.SIZE)
                        if (c.moveToFirst()) {
                            if (ni >= 0) name = c.getString(ni) ?: name
                            if (si >= 0 && !c.isNull(si)) sizeB = c.getLong(si)
                        }
                    }
                } catch (_: Exception) {}
                val mime = ctx.contentResolver.getType(uri) ?: "application/octet-stream"
                val server = LocalFileServer(ctx.contentResolver, uri, name, mime, sizeB)
                val port = server.start()
                holder[0] = server
                val link = "http://$ip:$port/"
                Triple(link, "$name${if (sizeB > 0) "  ·  ${LocalFileServer.prettySize(sizeB)}" else ""}", qrBitmap(link, 640))
            }
            busy = false
            if (result == null) status = "Connect to Wi-Fi first, then try again — both devices need to be on the same network."
            else { url = result.first; fileLabel = result.second; qr = result.third }
        }
    }

    fun stopSharing() {
        holder[0]?.stop(); holder[0] = null
        url = null; qr = null; fileLabel = null
    }

    Column(
        Modifier.fillMaxWidth().statusBarsPadding().padding(20.dp).verticalScroll(rememberScrollState())
    ) {
        ToolHeader("Send Anywhere", "Send a file to any nearby device over Wi-Fi — scan the code, download in the browser. No cloud, no cable.")
        Spacer(Modifier.size(16.dp))

        if (url == null) {
            HPrimaryButton(if (busy) "Starting…" else "Choose a file to send", modifier = Modifier.fillMaxWidth(), enabled = !busy) {
                picker.launch("*/*")
            }
            status?.let { Spacer(Modifier.size(10.dp)); Text(it, color = Handy.palette.textSecondary, fontSize = 13.sp) }
        } else {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                fileLabel?.let { Text(it, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground) }
                Spacer(Modifier.size(14.dp))
                qr?.let { Image(it.asImageBitmap(), contentDescription = "Scan to download", modifier = Modifier.size(240.dp)) }
                Spacer(Modifier.size(14.dp))
                Text("On the other device, scan the code or open:", color = Handy.palette.textSecondary, fontSize = 13.sp)
                Spacer(Modifier.size(4.dp))
                SelectionContainer { Text(url!!, fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.onBackground, fontSize = 15.sp) }
            }
            Spacer(Modifier.size(20.dp))
            HSecondaryButton("Stop sharing", modifier = Modifier.fillMaxWidth()) { stopSharing() }
        }

        Spacer(Modifier.size(16.dp))
        Text(
            "Both devices must be on the same Wi-Fi. The file is served straight from your phone and the mini server stops the moment you leave this screen or tap Stop. Some guest/public networks block device-to-device connections.",
            color = Handy.palette.textSecondary, fontSize = 12.sp,
        )
        Spacer(Modifier.size(16.dp))
        BannerAd()
    }
}

private fun qrBitmap(text: String, size: Int): Bitmap? = try {
    val m = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, size, size)
    val w = m.width; val h = m.height
    val px = IntArray(w * h)
    for (y in 0 until h) { val o = y * w; for (x in 0 until w) px[o + x] = if (m.get(x, y)) android.graphics.Color.BLACK else android.graphics.Color.WHITE }
    Bitmap.createBitmap(w, h, Bitmap.Config.RGB_565).apply { setPixels(px, 0, w, 0, 0, w, h) }
} catch (e: Exception) { null }
