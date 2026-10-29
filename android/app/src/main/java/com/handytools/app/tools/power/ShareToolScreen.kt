package com.handytools.app.tools.power

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.provider.OpenableColumns
import android.provider.Settings
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.OptIn
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.handytools.app.tools.Share
import com.handytools.app.tools.sendany.LocalFileServer
import com.handytools.app.tools.shield.ScamAnalyzer
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HCompactButton
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.Pill
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.PreviewBox
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.Executors

// ------------------------------------------------------------------------------------------------
// Share & Connect — Send a file / Make QR / Scan / Wi-Fi. State is hoisted so tabs keep their work.
// ------------------------------------------------------------------------------------------------

internal class SendState {
    var uri by mutableStateOf<Uri?>(null)
    var name by mutableStateOf("")
    var size by mutableLongStateOf(-1L)
    var mime by mutableStateOf("application/octet-stream")
    var thumb by mutableStateOf<Bitmap?>(null)
    var url by mutableStateOf<String?>(null)
    var qr by mutableStateOf<Bitmap?>(null)
    var phase by mutableIntStateOf(0)       // 0 idle · 1 waiting · 2 connected · 3 sending · 4 delivered
    var sent by mutableLongStateOf(0L)
    var busy by mutableStateOf(false)
    var status by mutableStateOf<String?>(null)
    val server = arrayOfNulls<LocalFileServer>(1)
}

internal class QrState {
    var kind by mutableIntStateOf(0)        // 0 text/link · 1 wifi · 2 contact
    var text by mutableStateOf("")
    var ssid by mutableStateOf("")
    var pass by mutableStateOf("")
    var security by mutableStateOf("WPA")
    var name by mutableStateOf("")
    var phone by mutableStateOf("")
    var email by mutableStateOf("")
    var bitmap by mutableStateOf<Bitmap?>(null)
    var status by mutableStateOf<String?>(null)
}

internal class ScanState2 {
    var scanning by mutableStateOf(false)
    var decoded by mutableStateOf<Decoded?>(null)
    var status by mutableStateOf<String?>(null)
    var busy by mutableStateOf(false)
}

internal class WifiState {
    var info by mutableStateOf<NetInfo?>(null)
    var speed by mutableStateOf<String?>(null)
    var testing by mutableStateOf(false)
}

@Composable
fun ShareToolScreen() {
    var tab by remember { mutableIntStateOf(0) }
    val send = remember { SendState() }
    val qr = remember { QrState() }
    val scan = remember { ScanState2() }
    val wifi = remember { WifiState() }
    DisposableEffect(Unit) { onDispose { send.server[0]?.stop(); send.server[0] = null } }
    PowerToolPage("share", listOf("Send a file", "Make QR", "Scan", "Wi-Fi"), tab, { tab = it }) {
        when (tab) {
            0 -> SendPanel(send)
            1 -> QrPanel(qr)
            2 -> ScanPanel2(scan)
            else -> WifiPanel(wifi) { ssid -> qr.kind = 1; qr.ssid = ssid; qr.bitmap = null; tab = 1 }
        }
    }
}

// ------------------------------------------------------------------------------------------------
// Send a file
// ------------------------------------------------------------------------------------------------

@Composable
private fun SendPanel(st: SendState) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()

    fun stop() {
        st.server[0]?.stop(); st.server[0] = null
        st.url = null; st.qr = null; st.phase = 0; st.sent = 0L
    }

    fun start(uri: Uri) {
        stop()
        st.busy = true; st.status = null; st.uri = uri; st.thumb = null
        scope.launch {
            val ok = withContext(Dispatchers.IO) {
                var name = "file"; var sizeB = -1L
                try {
                    ctx.contentResolver.query(uri, null, null, null, null)?.use { c ->
                        val ni = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        val si = c.getColumnIndex(OpenableColumns.SIZE)
                        if (c.moveToFirst()) {
                            if (ni >= 0 && !c.isNull(ni)) name = c.getString(ni) ?: name
                            if (si >= 0 && !c.isNull(si)) sizeB = c.getLong(si)
                        }
                    }
                } catch (_: Exception) {}
                val mime = ctx.contentResolver.getType(uri) ?: "application/octet-stream"
                st.name = name; st.size = sizeB; st.mime = mime
                if (mime.startsWith("image/")) st.thumb = DocEngine.loadBitmap(ctx, uri, 600)
                val ip = LocalFileServer.localIpv4() ?: return@withContext false
                val server = LocalFileServer(ctx.contentResolver, uri, name, mime, sizeB)
                server.onConnected = { if (st.phase < 2) st.phase = 2 }
                server.onProgress = { sent, _ -> st.sent = sent; if (st.phase < 4) st.phase = 3 }
                server.onDelivered = { st.phase = 4; HandyHaptics.success(ctx) }
                val port = server.start()
                st.server[0] = server
                val link = "http://$ip:$port/"
                st.url = link; st.qr = ShareEngine.qr(link, 640); st.phase = 1
                true
            }
            st.busy = false
            if (!ok) st.status = "Connect to Wi-Fi first — both devices need to be on the same network. Or send it another way below."
        }
    }

    val filePicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> if (uri != null) start(uri) }
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri -> if (uri != null) start(uri) }

    // Preview-first: the file being sent.
    val uri = st.uri
    if (uri == null) {
        PreviewBox(minHeight = 150.dp) {
            Text("Pick any file. The other device scans the code or opens the address — same Wi-Fi, no cable, no cloud.",
                color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(24.dp))
        }
    } else {
        HCard(Modifier.fillMaxWidth()) {
            Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                val t = st.thumb
                if (t != null) Image(t.asImageBitmap(), null, Modifier.size(64.dp).clip(RoundedCornerShape(10.dp)), contentScale = ContentScale.Crop)
                else Box(Modifier.size(64.dp).clip(RoundedCornerShape(10.dp)).background(Handy.palette.accentSoft), contentAlignment = Alignment.Center) {
                    Text(if (st.mime.startsWith("video/")) "🎬" else if (st.mime.startsWith("image/")) "🖼" else "📄", fontSize = 26.sp)
                }
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(st.name, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    Text(if (st.size > 0) LocalFileServer.prettySize(st.size) else st.mime, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                }
            }
        }
    }

    Spacer(Modifier.height(12.dp))
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        HPrimaryButton(if (st.busy) "Starting…" else "📎 Choose file", Modifier.weight(1f), enabled = !st.busy) { filePicker.launch(arrayOf("*/*")) }
        HSecondaryButton("🖼 Photo", Modifier.weight(1f), enabled = !st.busy) {
            photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo))
        }
    }

    val link = st.url
    if (link != null) {
        Spacer(Modifier.height(16.dp))
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            st.qr?.let { Box(Modifier.background(Color.White, RoundedCornerShape(12.dp)).padding(10.dp)) { Image(it.asImageBitmap(), "Scan to download", Modifier.size(190.dp)) } }
            Spacer(Modifier.height(10.dp))
            Text("Scan on the other device, or open", color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall)
            SelectionContainer { Text(link, fontFamily = FontFamily.Monospace, fontSize = 13.sp, fontWeight = FontWeight.SemiBold) }
            Spacer(Modifier.height(10.dp))
            val frac = if (st.size > 0) (st.sent.toFloat() / st.size).coerceIn(0f, 1f) else if (st.phase == 4) 1f else 0f
            LinearProgressIndicator(progress = { frac }, modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)), color = if (st.phase == 4) HandyColors.Success else HandyColors.Accent)
            Spacer(Modifier.height(6.dp))
            Text(
                when (st.phase) {
                    1 -> "Waiting for the other device…"
                    2 -> "Other device connected — tap Download there"
                    3 -> if (st.size > 0) "Sending… ${(frac * 100).toInt()}% · ${LocalFileServer.prettySize(st.sent)} of ${LocalFileServer.prettySize(st.size)}" else "Sending… ${LocalFileServer.prettySize(st.sent)}"
                    4 -> "✓ Delivered"
                    else -> ""
                },
                style = MaterialTheme.typography.bodyMedium, color = if (st.phase == 4) HandyColors.Success else MaterialTheme.colorScheme.onBackground
            )
        }
        Spacer(Modifier.height(12.dp))
        HSecondaryButton("Stop sharing") { stop() }
    } else if (uri != null && !st.busy) {
        Spacer(Modifier.height(10.dp))
        HSecondaryButton("Send another way (share sheet)") {
            try {
                val i = Intent(Intent.ACTION_SEND).setType(st.mime).putExtra(Intent.EXTRA_STREAM, uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                ctx.startActivity(Intent.createChooser(i, "Send").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            } catch (_: Exception) { Toast.makeText(ctx, "Nothing on this phone can take that file.", Toast.LENGTH_SHORT).show() }
        }
    }
    st.status?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = HandyColors.Amber, modifier = Modifier.padding(top = 10.dp)) }
    NoteText("The file is served straight from your phone and the mini server stops when you leave this screen or tap Stop. Some guest or public networks block device-to-device connections.")
}

// ------------------------------------------------------------------------------------------------
// Make QR
// ------------------------------------------------------------------------------------------------

@Composable
private fun QrPanel(st: QrState) {
    val ctx = LocalContext.current

    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
        HChip("Text / link", st.kind == 0) { st.kind = 0 }
        HChip("Wi-Fi login", st.kind == 1) { st.kind = 1 }
        HChip("Contact", st.kind == 2) { st.kind = 2 }
    }
    Spacer(Modifier.height(10.dp))
    when (st.kind) {
        0 -> OutlinedTextField(st.text, { st.text = it }, label = { Text("Text or URL") }, modifier = Modifier.fillMaxWidth())
        1 -> {
            OutlinedTextField(st.ssid, { st.ssid = it }, label = { Text("Network name") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(st.pass, { st.pass = it }, label = { Text("Password") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                HChip("WPA/WPA2", st.security == "WPA") { st.security = "WPA" }
                HChip("WEP", st.security == "WEP") { st.security = "WEP" }
                HChip("Open", st.security == "nopass") { st.security = "nopass" }
            }
        }
        else -> {
            OutlinedTextField(st.name, { st.name = it }, label = { Text("Name") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(st.phone, { st.phone = it }, label = { Text("Phone") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(st.email, { st.email = it }, label = { Text("Email") }, singleLine = true, modifier = Modifier.fillMaxWidth())
        }
    }
    Spacer(Modifier.height(12.dp))
    HPrimaryButton("Make QR") {
        val payload = when (st.kind) {
            0 -> st.text.trim()
            1 -> if (st.ssid.isBlank()) "" else ShareEngine.wifiString(st.ssid.trim(), if (st.security == "nopass") "" else st.pass, st.security)
            else -> if (st.name.isBlank() && st.phone.isBlank() && st.email.isBlank()) "" else ShareEngine.vcard(st.name, st.phone, st.email)
        }
        if (payload.isBlank()) {
            st.status = when (st.kind) { 0 -> "Type some text or a link first."; 1 -> "Enter the network name."; else -> "Add a name, phone or email." }
            st.bitmap = null
            return@HPrimaryButton
        }
        st.bitmap = ShareEngine.qr(payload, 720)
        st.status = if (st.bitmap == null) "That's too long for one QR code — shorten it a little." else null
        HandyHaptics.light(ctx)
    }
    st.status?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = HandyColors.Amber, modifier = Modifier.padding(top = 10.dp)) }
    st.bitmap?.let { bmp ->
        Spacer(Modifier.height(14.dp))
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Box(Modifier.background(Color.White, RoundedCornerShape(14.dp)).padding(12.dp)) { Image(bmp.asImageBitmap(), "QR code", Modifier.size(220.dp)) }
        }
        Spacer(Modifier.height(12.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            HSecondaryButton("Save image", Modifier.weight(1f)) {
                val ok = ShareEngine.savePng(ctx, bmp, "Tenzy-QR-${System.currentTimeMillis()}.png")
                Toast.makeText(ctx, if (ok) "Saved to Pictures/Tenzy" else "Couldn't save — sharing instead", Toast.LENGTH_SHORT).show()
                if (!ok) ShareEngine.pngFile(ctx, bmp, "Tenzy-QR")?.let { Share.file(ctx, it, "image/png") }
            }
            HSecondaryButton("Share", Modifier.weight(1f)) {
                val f = ShareEngine.pngFile(ctx, bmp, "Tenzy-QR")
                if (f != null) Share.file(ctx, f, "image/png") else Toast.makeText(ctx, "Couldn't write the image.", Toast.LENGTH_SHORT).show()
            }
        }
    }
    NoteText("Made on the phone. A Wi-Fi code lets guests join by scanning — the password never leaves the picture.")
}

// ------------------------------------------------------------------------------------------------
// Scan
// ------------------------------------------------------------------------------------------------

@Composable
private fun ScanPanel2(st: ScanState2) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var camGranted by remember { mutableStateOf(ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    val camPerm = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        camGranted = ok
        if (ok) st.scanning = true else st.status = "Camera is off for Tenzy — use From image, or allow the camera in Settings."
    }
    val imagePicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        st.busy = true; st.status = null; st.scanning = false
        scope.launch {
            val d = withContext(Dispatchers.IO) { ShareEngine.decodeImage(ctx, uri) }
            st.busy = false
            if (d == null) st.status = "No code found in that picture — try a clearer, closer shot." else { st.decoded = d; HandyHaptics.light(ctx) }
        }
    }

    // Preview-first: the live camera, or the decoded result.
    if (st.scanning && camGranted) {
        CameraScanner(onResult = { raw, isQr -> st.decoded = ShareEngine.classify(raw, isQr); st.scanning = false; st.status = null; HandyHaptics.medium(ctx) })
    } else {
        PreviewBox(minHeight = 150.dp) {
            Text(
                if (st.busy) "Reading…" else st.decoded?.let { "Scanned. Scan again or pick an image." } ?: "Scan any QR or barcode.",
                color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(24.dp)
            )
        }
    }
    Spacer(Modifier.height(12.dp))
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        HPrimaryButton(if (st.scanning) "Stop camera" else "📷 Scan", Modifier.weight(1f), enabled = !st.busy) {
            if (st.scanning) st.scanning = false
            else if (camGranted) { st.decoded = null; st.scanning = true }
            else camPerm.launch(Manifest.permission.CAMERA)
        }
        HSecondaryButton("🖼 From image", Modifier.weight(1f), enabled = !st.busy) {
            imagePicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
    }
    if (!camGranted) {
        Spacer(Modifier.height(10.dp))
        HCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(14.dp)) {
                Text("Camera", style = MaterialTheme.typography.titleMedium)
                Text("Needed only to point at a code. Nothing is recorded or uploaded.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 4.dp, bottom = 10.dp))
                HCompactButton("Allow camera") { camPerm.launch(Manifest.permission.CAMERA) }
            }
        }
    }
    st.status?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = HandyColors.Amber, modifier = Modifier.padding(top = 10.dp)) }

    st.decoded?.let { d -> Spacer(Modifier.height(14.dp)); ScanResult(d) }
    NoteText("Codes are read on the phone. Links get checked against Tenzy's scam rules before you open them.")
}

@Composable
private fun ScanResult(d: Decoded) {
    val ctx = LocalContext.current
    var joinStatus by remember(d) { mutableStateOf<String?>(null) }
    HCard(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            Pill("✓ ${d.kind.label}", HandyColors.Success)
            SelectionContainer { Text(d.raw, style = MaterialTheme.typography.bodyMedium, maxLines = 8, overflow = TextOverflow.Ellipsis) }
            Spacer(Modifier.height(12.dp))
            when (d.kind) {
                CodeKind.LINK -> {
                    val report = remember(d) { ScamAnalyzer.analyze(d.raw) }
                    val tint = when (report.verdict) {
                        ScamAnalyzer.Verdict.LIKELY_SCAM -> HandyColors.Danger
                        ScamAnalyzer.Verdict.SUSPICIOUS -> HandyColors.Amber
                        ScamAnalyzer.Verdict.LOW_RISK -> HandyColors.Success
                    }
                    Pill("🛡 Safety check: ${report.verdict.label}", tint)
                    val why = report.links.flatMap { it.issues }.firstOrNull() ?: report.findings.firstOrNull()?.detail
                    Text(why ?: "No look-alike domain, shortener or login bait spotted. Still only open links you expected.",
                        style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(bottom = 10.dp))
                    val safe = report.verdict == ScamAnalyzer.Verdict.LOW_RISK
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        if (safe) HPrimaryButton("Open link", Modifier.weight(1f)) { openLink(ctx, d.raw) }
                        else HSecondaryButton("Open anyway", Modifier.weight(1f)) { openLink(ctx, d.raw) }
                        HSecondaryButton("Copy", Modifier.weight(1f)) { ShareEngine.copy(ctx, "Link", d.raw); Toast.makeText(ctx, "Copied", Toast.LENGTH_SHORT).show() }
                    }
                }
                CodeKind.WIFI -> {
                    val creds = ShareEngine.parseWifi(d.raw)
                    if (creds == null) {
                        Text("Couldn't read the network details from this code.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(bottom = 10.dp))
                        HSecondaryButton("Copy") { ShareEngine.copy(ctx, "Code", d.raw); Toast.makeText(ctx, "Copied", Toast.LENGTH_SHORT).show() }
                    } else {
                        Text("${creds.ssid}  ·  ${if (creds.password.isBlank()) "open network" else creds.security}", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(bottom = 10.dp))
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            HPrimaryButton("Join network", Modifier.weight(1f)) { joinStatus = ShareEngine.joinWifi(ctx, creds) }
                            HSecondaryButton("Copy password", Modifier.weight(1f), enabled = creds.password.isNotBlank()) {
                                ShareEngine.copy(ctx, "Wi-Fi password", creds.password); Toast.makeText(ctx, "Password copied", Toast.LENGTH_SHORT).show()
                            }
                        }
                        joinStatus?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 8.dp)) }
                    }
                }
                CodeKind.CONTACT -> {
                    val c = ShareEngine.parseContact(d.raw)
                    Text(listOf(c.name, c.phone, c.email).filter { it.isNotBlank() }.joinToString("  ·  ").ifBlank { "Contact card" },
                        style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(bottom = 10.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        HPrimaryButton("Insert contact", Modifier.weight(1f)) {
                            try { ctx.startActivity(ShareEngine.insertContactIntent(c).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                            catch (_: Exception) { Toast.makeText(ctx, "No contacts app found — details copied instead.", Toast.LENGTH_SHORT).show(); ShareEngine.copy(ctx, "Contact", d.raw) }
                        }
                        HSecondaryButton("Copy", Modifier.weight(1f)) { ShareEngine.copy(ctx, "Contact", d.raw); Toast.makeText(ctx, "Copied", Toast.LENGTH_SHORT).show() }
                    }
                }
                CodeKind.TEXT, CodeKind.BARCODE -> {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        HPrimaryButton("Copy", Modifier.weight(1f)) { ShareEngine.copy(ctx, "Code", d.raw); Toast.makeText(ctx, "Copied", Toast.LENGTH_SHORT).show() }
                        HSecondaryButton(if (d.kind == CodeKind.BARCODE) "Look it up" else "Share", Modifier.weight(1f)) {
                            if (d.kind == CodeKind.BARCODE) openLink(ctx, "https://www.google.com/search?q=" + Uri.encode(d.raw)) else Share.text(ctx, d.raw)
                        }
                    }
                }
            }
        }
    }
}

private fun openLink(ctx: android.content.Context, url: String) {
    val u = if (url.startsWith("http", ignoreCase = true)) url else "https://$url"
    try { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(u)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    catch (_: Exception) { Toast.makeText(ctx, "No browser found — link copied.", Toast.LENGTH_SHORT).show(); ShareEngine.copy(ctx, "Link", u) }
}

/** CameraX preview + ML Kit barcode analysis (same recipe as the QR tool). Unbinds when it leaves the screen. */
@OptIn(ExperimentalGetImage::class)
@Composable
private fun CameraScanner(onResult: (String, Boolean) -> Unit) {
    val lifecycle = LocalLifecycleOwner.current
    val holder = remember { arrayOfNulls<ProcessCameraProvider>(1) }
    val done = remember { booleanArrayOf(false) }
    DisposableEffect(Unit) { onDispose { try { holder[0]?.unbindAll() } catch (_: Exception) {} } }
    AndroidView(
        factory = { context ->
            val pv = PreviewView(context)
            val future = ProcessCameraProvider.getInstance(context)
            val scanner = BarcodeScanning.getClient()
            val exec = Executors.newSingleThreadExecutor()
            future.addListener({
                val provider = future.get()
                holder[0] = provider
                val preview = Preview.Builder().build().also { it.surfaceProvider = pv.surfaceProvider }
                val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                analysis.setAnalyzer(exec) { proxy ->
                    val mediaImage = proxy.image
                    if (mediaImage != null && !done[0]) {
                        scanner.process(InputImage.fromMediaImage(mediaImage, proxy.imageInfo.rotationDegrees))
                            .addOnSuccessListener { codes ->
                                val b = codes.firstOrNull { !it.rawValue.isNullOrBlank() }
                                if (b != null && !done[0]) { done[0] = true; onResult(b.rawValue ?: "", b.format == Barcode.FORMAT_QR_CODE) }
                            }
                            .addOnCompleteListener { proxy.close() }
                    } else proxy.close()
                }
                try {
                    provider.unbindAll()
                    provider.bindToLifecycle(lifecycle, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
                } catch (_: Exception) {}
            }, ContextCompat.getMainExecutor(context))
            pv
        },
        modifier = Modifier.fillMaxWidth().aspectRatio(3f / 4f).clip(RoundedCornerShape(16.dp))
    )
}

// ------------------------------------------------------------------------------------------------
// Wi-Fi
// ------------------------------------------------------------------------------------------------

@Composable
private fun WifiPanel(st: WifiState, onShareQr: (String) -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var locGranted by remember { mutableStateOf(ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) }
    fun refresh() { st.info = ShareEngine.netInfo(ctx) }
    val locPerm = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> locGranted = ok; refresh() }
    LaunchedEffect(Unit) { refresh() }

    Pill("Runs natively · reads the current network")
    val info = st.info
    if (info == null) {
        PreviewBox(minHeight = 120.dp) { Text("Reading your connection…", color = Handy.palette.textSecondary) }
    } else if (!info.connected) {
        HCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text("Not connected", style = MaterialTheme.typography.titleMedium)
                Text("Join a Wi-Fi network and this page fills in by itself.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 4.dp, bottom = 10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    HCompactButton("Open Wi-Fi settings") {
                        try { ctx.startActivity(Intent(Settings.ACTION_WIFI_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } catch (_: Exception) {}
                    }
                    HCompactButton("Refresh") { refresh() }
                }
            }
        }
    } else {
        val rows = ArrayList<Pair<String, String>>()
        rows += "Network" to (info.ssid ?: if (info.wifi) "Connected · name hidden" else "Mobile data")
        info.rssi?.let { rows += "Signal" to "$it dBm · ${ShareEngine.signalLabel(it)}" }
        info.linkSpeed?.let { rows += "Link speed" to "$it Mbps" }
        rows += "Your IP" to (info.ip ?: "—")
        rows += "Router" to (info.gateway ?: "—")
        rows += "DNS" to (info.dns ?: "—")
        rows += "Speed" to (st.speed ?: "—")
        HCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(horizontal = 14.dp, vertical = 6.dp)) {
                rows.forEach { (k, v) ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 7.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text(k, color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium)
                        Spacer(Modifier.width(12.dp))
                        Text(v, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
        }
        if (info.wifi && info.ssid == null) {
            Spacer(Modifier.height(10.dp))
            HCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(14.dp)) {
                    Text("Network name hidden", style = MaterialTheme.typography.titleMedium)
                    Text(
                        if (locGranted) "Android also needs Location switched on to show the Wi-Fi name. Everything else above is live."
                        else "Android only shows the Wi-Fi name to apps with location access. Tenzy never stores or sends your location.",
                        style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 4.dp, bottom = 10.dp)
                    )
                    if (locGranted) HCompactButton("Open location settings") {
                        try { ctx.startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } catch (_: Exception) {}
                    } else HCompactButton("Allow location") { locPerm.launch(Manifest.permission.ACCESS_FINE_LOCATION) }
                }
            }
        }
    }

    Spacer(Modifier.height(12.dp))
    HPrimaryButton(if (st.testing) "Testing…" else if (st.speed == null) "⚡ Speed test" else "⚡ Speed test again", enabled = !st.testing) {
        st.testing = true; st.speed = "Testing…"
        scope.launch {
            val r = withContext(Dispatchers.IO) { ShareEngine.speedTest() }
            st.testing = false
            st.speed = r ?: "Couldn't reach the test server — check your connection."
            refresh()
        }
    }
    Spacer(Modifier.height(10.dp))
    HSecondaryButton("Share this Wi-Fi as QR") { onShareQr(info?.ssid ?: "") }
    Spacer(Modifier.height(10.dp))
    HSecondaryButton("Refresh") { refresh() }
    NoteText("Read from the phone's own connection info. The speed test downloads a short sample (about 8 MB) and nothing else goes anywhere.")
}
