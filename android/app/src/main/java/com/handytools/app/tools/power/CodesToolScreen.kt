package com.handytools.app.tools.power

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.nfc.NfcAdapter
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Nfc
import androidx.compose.material.icons.outlined.Save
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.PreviewBox
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.Executors

/**
 * QR / Barcode / NFC studio. SCAN reads any QR/1D/2D code from the live camera or a picked image and
 * acts on it (open a link, surface Wi-Fi creds, read a contact, dial, email, copy), and reads NDEF
 * records off an NFC tag when the phone has NFC. CREATE builds a QR for text, a link, Wi-Fi, a phone
 * number, an email or a contact, then saves or shares it. All on-device.
 */
@Composable
fun CodesToolScreen() {
    var tab by remember { mutableIntStateOf(0) }
    PowerToolPage("codes", tabs = listOf("Scan", "Create"), selected = tab, onTab = { tab = it }) {
        if (tab == 0) ScanTab() else CreateTab()
    }
}

/* ------------------------------------------------------------------ SCAN ------------------------------------------------------------------ */

@OptIn(ExperimentalGetImage::class)
@Composable
private fun ScanTab() {
    val ctx = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current
    var granted by remember { mutableStateOf(ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    var decoded by remember { mutableStateOf<CodesEngine.Decoded?>(null) }
    var pickedUri by remember { mutableStateOf<Uri?>(null) }
    var imageError by remember { mutableStateOf(false) }

    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted = it }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { u ->
        if (u != null) { pickedUri = u; imageError = false; decoded = null }
    }

    LaunchedEffect(pickedUri) {
        val u = pickedUri ?: return@LaunchedEffect
        val r = withContext(Dispatchers.IO) { CodesEngine.decodeUri(ctx, u) }
        if (r != null) decoded = r else imageError = true
    }

    if (granted) {
        Spacer(Modifier.height(HandyTokens.Space12))
        Box(Modifier.fillMaxWidth().aspectRatio(3f / 4f).clip(RoundedCornerShape(16.dp)).background(HandyColors.SurfaceDark)) {
            AndroidView(
                factory = { context ->
                    val pv = PreviewView(context)
                    val future = ProcessCameraProvider.getInstance(context)
                    val scanner = BarcodeScanning.getClient()
                    val exec = Executors.newSingleThreadExecutor()
                    future.addListener({
                        val provider = future.get()
                        val preview = Preview.Builder().build().also { it.surfaceProvider = pv.surfaceProvider }
                        val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                        analysis.setAnalyzer(exec) { proxy ->
                            val mediaImage = proxy.image
                            if (mediaImage != null && decoded == null) {
                                scanner.process(InputImage.fromMediaImage(mediaImage, proxy.imageInfo.rotationDegrees))
                                    .addOnSuccessListener { codes ->
                                        val hit = codes.firstOrNull { !it.rawValue.isNullOrBlank() }
                                        if (hit != null && decoded == null) decoded = CodesEngine.classify(hit.rawValue ?: "", hit.format == com.google.mlkit.vision.barcode.common.Barcode.FORMAT_QR_CODE)
                                    }
                                    .addOnCompleteListener { proxy.close() }
                            } else proxy.close()
                        }
                        provider.unbindAll()
                        provider.bindToLifecycle(lifecycle, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
                    }, ContextCompat.getMainExecutor(context))
                    pv
                },
                modifier = Modifier.fillMaxWidth().aspectRatio(3f / 4f)
            )
        }
        NoteText("Point the camera at any QR or barcode. It reads on your phone — nothing is uploaded.")
    } else {
        Spacer(Modifier.height(HandyTokens.Space12))
        HPrimaryButton("Allow camera") { permLauncher.launch(Manifest.permission.CAMERA) }
        NoteText("Camera access lets you scan live. You can also scan a picture from your gallery without it.")
    }

    Spacer(Modifier.height(HandyTokens.Space8))
    HSecondaryButton("Scan from image") { picker.launch(arrayOf("image/*")) }
    if (imageError && decoded == null) NoteText("No code found in that image — try another picture, or point the camera at it.")

    decoded?.let { d ->
        Spacer(Modifier.height(HandyTokens.Space12))
        ResultCard(d) { decoded = null; pickedUri = null; imageError = false }
    }

    NfcSection()
}

@Composable
private fun ResultCard(d: CodesEngine.Decoded, onAgain: () -> Unit) {
    val ctx = LocalContext.current
    SectionLabel("Result · " + kindLabel(d.kind))
    HCard(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            when (d.kind) {
                CodesEngine.Kind.WIFI -> {
                    val w = CodesEngine.parseWifi(d.raw)
                    if (w != null) {
                        Field("Network", w.ssid)
                        Field("Security", if (w.security.equals("nopass", true)) "Open" else w.security)
                        if (w.password.isNotBlank()) Field("Password", w.password)
                        Spacer(Modifier.height(10.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            if (w.password.isNotBlank()) HChip("Copy password", false) { CodesEngine.copy(ctx, "Wi-Fi password", w.password); toast(ctx, "Password copied") }
                            HChip("Wi-Fi settings", false) { runCatching { ctx.startActivity(Intent(android.provider.Settings.Panel.ACTION_WIFI).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } }
                        }
                    } else PayloadText(d.raw)
                }
                CodesEngine.Kind.CONTACT -> {
                    val c = CodesEngine.parseContact(d.raw)
                    if (c.name.isNotBlank()) Field("Name", c.name)
                    if (c.org.isNotBlank()) Field("Company", c.org)
                    if (c.phone.isNotBlank()) Field("Phone", c.phone)
                    if (c.email.isNotBlank()) Field("Email", c.email)
                    Spacer(Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        HChip("Add contact", false) { runCatching { ctx.startActivity(CodesEngine.insertContactIntent(c).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } }
                        HChip("Copy", false) { CodesEngine.copy(ctx, "Contact", d.raw); toast(ctx, "Copied") }
                    }
                }
                else -> {
                    PayloadText(d.raw)
                    Spacer(Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        when (d.kind) {
                            CodesEngine.Kind.URL -> HChip("Open link", false) { openUrl(ctx, if (d.raw.startsWith("www", true)) "https://${d.raw}" else d.raw) }
                            CodesEngine.Kind.EMAIL -> HChip("Email", false) { val to = d.raw.removePrefix("mailto:").removePrefix("MAILTO:"); runCatching { ctx.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$to")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } }
                            CodesEngine.Kind.PHONE -> HChip("Call", false) { runCatching { ctx.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse(if (d.raw.startsWith("tel:")) d.raw else "tel:${d.raw}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } }
                            CodesEngine.Kind.GEO -> HChip("Open map", false) { runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(d.raw)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } }
                            CodesEngine.Kind.SMS -> HChip("Message", false) { runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(d.raw)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } }
                            else -> {}
                        }
                        HChip("Copy", false) { CodesEngine.copy(ctx, "Code", d.raw); toast(ctx, "Copied") }
                    }
                }
            }
        }
    }
    Spacer(Modifier.height(HandyTokens.Space8))
    HSecondaryButton("Scan again", onClick = onAgain)
}

/* ------------------------------------------------------------------ NFC ------------------------------------------------------------------ */

@Composable
private fun NfcSection() {
    val ctx = LocalContext.current
    val adapter = remember { NfcAdapter.getDefaultAdapter(ctx) }
    if (adapter == null) return // no NFC hardware — hide entirely
    val activity = remember { DocEngine.findActivity(ctx) }
    var tagInfo by remember { mutableStateOf<CodesEngine.NfcTagInfo?>(null) }
    var enabled by remember { mutableStateOf(false) }

    DisposableEffect(adapter, activity) {
        val callback = NfcAdapter.ReaderCallback { tag ->
            val info = CodesEngine.readTag(tag)
            activity?.runOnUiThread { tagInfo = info }
        }
        if (activity != null) {
            val flags = NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_NFC_F or NfcAdapter.FLAG_READER_NFC_V or
                NfcAdapter.FLAG_READER_NFC_BARCODE or NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS
            enabled = runCatching { adapter.enableReaderMode(activity, callback, flags, null); true }.getOrDefault(false)
        }
        onDispose { if (activity != null) runCatching { adapter.disableReaderMode(activity) } }
    }

    SectionLabel("NFC")
    if (!adapter.isEnabled) {
        NoteText("NFC is switched off. Turn it on in Settings, then hold a tag to the back of your phone.")
        return
    }
    if (!enabled) { NoteText("NFC reading isn't available right now."); return }
    val info = tagInfo
    if (info == null) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Outlined.Nfc, null, Modifier.size(22.dp), tint = HandyColors.Accent)
            Spacer(Modifier.size(8.dp))
            Text("Hold an NFC tag to the back of your phone.", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
        }
    } else {
        HCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(14.dp)) {
                Field("Tag ID", info.id)
                if (info.tech.isNotEmpty()) Field("Type", info.tech.joinToString(", "))
                info.records.forEachIndexed { i, rec -> Field(if (info.records.size == 1) rec.label else "${rec.label} ${i + 1}", rec.value) }
                Spacer(Modifier.height(10.dp))
                val joined = info.records.joinToString("\n") { it.value }
                HChip("Copy", false) { CodesEngine.copy(ctx, "NFC tag", joined); toast(ctx, "Copied") }
            }
        }
        Spacer(Modifier.height(HandyTokens.Space8))
        HSecondaryButton("Read another tag") { tagInfo = null }
    }
}

/* ------------------------------------------------------------------ CREATE ------------------------------------------------------------------ */

private enum class MakeType(val label: String) { TEXT("Text"), URL("Link"), WIFI("Wi-Fi"), PHONE("Phone"), EMAIL("Email"), CONTACT("Contact") }

@Composable
private fun CreateTab() {
    val ctx = LocalContext.current
    var type by remember { mutableStateOf(MakeType.TEXT) }

    // One field set, reused across types.
    var a by remember { mutableStateOf("") } // text / url / ssid / phone / email / name
    var b by remember { mutableStateOf("") } // wifi password / email subject / contact phone
    var c by remember { mutableStateOf("") } // email body / contact email
    var secWpa by remember { mutableStateOf(true) }

    Spacer(Modifier.height(HandyTokens.Space12))
    SectionLabel("What to encode")
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        MakeType.values().forEach { t -> HChip(t.label, type == t) { type = t; a = ""; b = ""; c = "" } }
    }
    Spacer(Modifier.height(HandyTokens.Space12))

    when (type) {
        MakeType.TEXT -> OutField(a, { a = it }, "Text")
        MakeType.URL -> OutField(a, { a = it }, "https://example.com")
        MakeType.WIFI -> {
            OutField(a, { a = it }, "Network name (SSID)")
            Spacer(Modifier.height(HandyTokens.Space8))
            OutField(b, { b = it }, "Password (leave blank for open)")
            Spacer(Modifier.height(HandyTokens.Space8))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                HChip("WPA/WPA2", secWpa) { secWpa = true }
                HChip("WEP", !secWpa) { secWpa = false }
            }
        }
        MakeType.PHONE -> OutField(a, { a = it }, "Phone number")
        MakeType.EMAIL -> {
            OutField(a, { a = it }, "Email address")
            Spacer(Modifier.height(HandyTokens.Space8))
            OutField(b, { b = it }, "Subject (optional)")
            Spacer(Modifier.height(HandyTokens.Space8))
            OutField(c, { c = it }, "Message (optional)")
        }
        MakeType.CONTACT -> {
            OutField(a, { a = it }, "Full name")
            Spacer(Modifier.height(HandyTokens.Space8))
            OutField(b, { b = it }, "Phone (optional)")
            Spacer(Modifier.height(HandyTokens.Space8))
            OutField(c, { c = it }, "Email (optional)")
        }
    }

    val payload = remember(type, a, b, c, secWpa) {
        when (type) {
            MakeType.TEXT, MakeType.URL -> a.trim()
            MakeType.WIFI -> if (a.isBlank()) "" else CodesEngine.wifiPayload(a.trim(), b, if (secWpa) "WPA" else "WEP", false)
            MakeType.PHONE -> if (a.isBlank()) "" else CodesEngine.telPayload(a)
            MakeType.EMAIL -> if (a.isBlank()) "" else CodesEngine.mailtoPayload(a, b, c)
            MakeType.CONTACT -> if (a.isBlank() && b.isBlank() && c.isBlank()) "" else CodesEngine.vcardPayload(a, b, c, "")
        }
    }
    val bmp = remember(payload) { if (payload.isBlank()) null else CodesEngine.qr(payload) }

    Spacer(Modifier.height(HandyTokens.Space16))
    PreviewBox(minHeight = 260.dp) {
        if (bmp != null) {
            Box(Modifier.background(Color.White).padding(12.dp)) {
                Image(bmp.asImageBitmap(), "QR code", Modifier.size(220.dp))
            }
        } else {
            Text("Fill in the field above to build a QR code.", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary, modifier = Modifier.padding(24.dp))
        }
    }

    Spacer(Modifier.height(HandyTokens.Space12))
    HPrimaryButton("Save to gallery", enabled = bmp != null, icon = Icons.Outlined.Save) {
        val b2 = bmp ?: return@HPrimaryButton
        val ok = CodesEngine.savePngToGallery(ctx, b2, "Tenzy_QR_${System.currentTimeMillis()}.png")
        toast(ctx, if (ok) "Saved to Pictures/Tenzy" else "Couldn't save — try Share instead")
    }
    Spacer(Modifier.height(HandyTokens.Space8))
    HSecondaryButton("Share") {
        val b2 = bmp ?: return@HSecondaryButton
        val f = CodesEngine.cachePng(ctx, b2, "tenzy-qr")
        if (f != null) Share.file(ctx, f, "image/png") else toast(ctx, "Couldn't prepare the image")
    }
    NoteText("The code is generated on your phone. Wi-Fi codes carry the password in plain text — share them only with people you'd give the password to.")
}

/* ------------------------------------------------------------------ small shared bits ------------------------------------------------------------------ */

@Composable
private fun OutField(value: String, onChange: (String) -> Unit, label: String) {
    OutlinedTextField(value, onChange, label = { Text(label) }, modifier = Modifier.fillMaxWidth(), singleLine = label != "Text" && label != "Message (optional)")
}

@Composable
private fun Field(label: String, value: String) {
    Column(Modifier.padding(vertical = 4.dp)) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
        Text(value, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
    }
}

@Composable
private fun PayloadText(raw: String) {
    Text(raw, style = MaterialTheme.typography.bodyMedium, fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.onSurface, maxLines = 8, overflow = TextOverflow.Ellipsis)
}

private fun kindLabel(k: CodesEngine.Kind) = when (k) {
    CodesEngine.Kind.URL -> "Link"
    CodesEngine.Kind.WIFI -> "Wi-Fi"
    CodesEngine.Kind.CONTACT -> "Contact"
    CodesEngine.Kind.EMAIL -> "Email"
    CodesEngine.Kind.PHONE -> "Phone"
    CodesEngine.Kind.SMS -> "Message"
    CodesEngine.Kind.GEO -> "Location"
    CodesEngine.Kind.TEXT -> "Text"
}

private fun openUrl(ctx: android.content.Context, url: String) {
    runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
}

private fun toast(ctx: android.content.Context, msg: String) {
    Toast.makeText(ctx, msg, Toast.LENGTH_SHORT).show()
}
