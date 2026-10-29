package com.handytools.app.tools.power

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
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
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import com.handytools.app.tools.Share
import com.handytools.app.tools.shield.ScamAnalyzer
import com.handytools.app.ui.EmptyState
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
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
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

private val SAFETY_TABS = listOf("Message", "Link", "Phone", "QR code", "History")

private val MESSAGE_SAMPLES = listOf(
    "Family emergency" to "Hi grandma it's me, I lost my phone this is my new number. I'm in trouble and need \$800 for bail, please don't tell mom.",
    "Package" to "USPS: your package is held. Confirm your details to reschedule delivery: usps-redelivery.info/track",
    "Normal text" to "Hey, running 10 min late, order me a flat white? Thanks!",
)

private fun verdictColor(v: ScamAnalyzer.Verdict): Color = when (v) {
    ScamAnalyzer.Verdict.LIKELY_SCAM -> HandyColors.Danger
    ScamAnalyzer.Verdict.SUSPICIOUS -> HandyColors.Amber
    ScamAnalyzer.Verdict.LOW_RISK -> HandyColors.Success
}

private fun verdictGlyph(v: ScamAnalyzer.Verdict): String = when (v) {
    ScamAnalyzer.Verdict.LIKELY_SCAM -> "⚠️"
    ScamAnalyzer.Verdict.SUSPICIOUS -> "❓"
    ScamAnalyzer.Verdict.LOW_RISK -> "✓"
}

/**
 * Safety — paste a message, link or number, or scan a QR code, and see exactly why it is (or
 * isn't) a scam. Runs entirely on the phone; nothing is uploaded and no link is ever opened.
 */
@Composable
fun SafetyToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var tab by remember { mutableIntStateOf(0) }

    var message by remember { mutableStateOf("URGENT: Your account will be suspended within 24 hours. Verify at http://paypal.secure-login.top/verify and pay the fee in Apple gift cards. Do not tell anyone.") }
    var link by remember { mutableStateOf("http://chase-secure-verify.xyz/login") }
    var phone by remember { mutableStateOf("+1 900 555 0123") }

    var current by remember { mutableStateOf<SafetyEngine.Check?>(null) }
    var label by remember { mutableStateOf<String?>(null) }
    var history by remember { mutableStateOf(SafetyEngine.loadHistory(ctx)) }
    var blockHint by remember { mutableStateOf<String?>(null) }

    // QR state
    var scanning by remember { mutableStateOf(false) }
    var qrImage by remember { mutableStateOf<Bitmap?>(null) }
    var qrStatus by remember { mutableStateOf<String?>(null) }
    var qrBusy by remember { mutableStateOf(false) }
    var cameraDenied by remember { mutableStateOf(false) }

    fun show(c: SafetyEngine.Check, lbl: String? = null) {
        current = c; label = lbl; blockHint = null
        history = SafetyEngine.remember(ctx, c)
        HandyHaptics.light(ctx)
    }

    fun onQrPayload(v: String) {
        scanning = false
        show(SafetyEngine.checkQr(v), "QR: " + v.take(40))
    }

    val library = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        qrBusy = true; qrStatus = null; scanning = false
        scope.launch {
            val pair = withContext(Dispatchers.IO) {
                val bmp = CaptureImages.load(ctx, uri, 1600) ?: return@withContext null
                val code = runCatching {
                    BarcodeScanning.getClient().process(InputImage.fromBitmap(bmp, 0)).await().firstOrNull()?.rawValue
                }.getOrNull()
                bmp to code
            }
            qrBusy = false
            if (pair == null) { qrStatus = "Couldn't open that image. Try another one."; return@launch }
            qrImage = pair.first
            val code = pair.second
            if (code.isNullOrBlank()) qrStatus = "No QR code found in that image — try a clearer, closer shot."
            else onQrPayload(code)
        }
    }
    val cameraPerm = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok: Boolean ->
        if (ok) { scanning = true; qrImage = null; qrStatus = null } else cameraDenied = true
    }

    PowerToolPage(route = "safety", tabs = SAFETY_TABS, selected = tab, onTab = { tab = it; if (it != 3) scanning = false }) {
        when (tab) {
            0 -> {
                OutlinedTextField(
                    value = message, onValueChange = { message = it }, modifier = Modifier.fillMaxWidth(), minLines = 5,
                    placeholder = { Text("Paste a suspicious text, email, link or number…") },
                )
                Spacer(Modifier.height(HandyTokens.Space8))
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                    MESSAGE_SAMPLES.forEach { (name, text) -> HChip(name, selected = false) { message = text; show(SafetyEngine.checkMessage(text)) } }
                }
                Spacer(Modifier.height(HandyTokens.Space12))
                HPrimaryButton("Check it", enabled = message.isNotBlank()) { show(SafetyEngine.checkMessage(message)) }
            }
            1 -> {
                OutlinedTextField(value = link, onValueChange = { link = it }, modifier = Modifier.fillMaxWidth(), singleLine = true, placeholder = { Text("Paste a link…") })
                Spacer(Modifier.height(HandyTokens.Space12))
                HPrimaryButton("Check link", enabled = link.isNotBlank()) { show(SafetyEngine.checkLink(link), "link") }
                NoteText("Checks the address itself — look-alike brands, risky endings, shorteners, raw IPs. Nothing is opened.")
            }
            2 -> {
                OutlinedTextField(value = phone, onValueChange = { phone = it }, modifier = Modifier.fillMaxWidth(), singleLine = true, placeholder = { Text("Phone number…") })
                Spacer(Modifier.height(HandyTokens.Space12))
                HPrimaryButton("Check number", enabled = phone.any { it.isDigit() }) { show(SafetyEngine.checkPhone(phone), "phone") }
                NoteText("Spots premium-rate and spoof-pattern numbers; your phone's dialer also checks its own spam list.")
            }
            3 -> {
                val img = qrImage
                when {
                    scanning -> QrScanner(onCode = { onQrPayload(it) })
                    img != null -> Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surface), contentAlignment = Alignment.Center) {
                        Image(img.asImageBitmap(), null, Modifier.fillMaxWidth().heightIn(min = 160.dp, max = 360.dp), contentScale = ContentScale.Fit)
                    }
                    else -> PreviewBox(minHeight = 170.dp) {
                        Text("Scan a QR code before you open it — the link inside is checked first.", textAlign = TextAlign.Center, color = Handy.palette.textSecondary, modifier = Modifier.padding(HandyTokens.Space24))
                    }
                }
                Spacer(Modifier.height(HandyTokens.Space12))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                    HPrimaryButton(if (scanning) "Stop scanning" else "📷 Scan QR", modifier = Modifier.weight(1f), enabled = !qrBusy) {
                        if (scanning) scanning = false
                        else if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) { scanning = true; qrImage = null; qrStatus = null }
                        else cameraPerm.launch(Manifest.permission.CAMERA)
                    }
                    HSecondaryButton(if (qrBusy) "Reading…" else "🖼 From image", modifier = Modifier.weight(1f), enabled = !qrBusy) {
                        library.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    }
                }
                if (cameraDenied) NoteText("Camera isn't allowed for Tenzy — use From image instead, or allow it in Settings › Apps › Tenzy.")
                qrStatus?.let { Spacer(Modifier.height(HandyTokens.Space12)); Pill(it, HandyColors.Amber) }
            }
            else -> {
                if (history.isEmpty()) EmptyState(Icons.Outlined.Shield, "Checks you run appear here.", "Message, link, phone and QR checks — last 20 are kept on this phone.")
                else {
                    history.forEach { h ->
                        HistoryRow(h) { show(SafetyEngine.rerun(h), h.kind.label.lowercase()) }
                    }
                    Spacer(Modifier.height(HandyTokens.Space12))
                    HSecondaryButton("Clear history") { SafetyEngine.clearHistory(ctx); history = emptyList() }
                }
            }
        }

        current?.let { c ->
            Spacer(Modifier.height(HandyTokens.Space16))
            ResultCard(
                c, label,
                onReport = { Share.text(ctx, SafetyEngine.shareText(c)) },
                onBlock = {
                    val opened = SafetyEngine.block(ctx, c.phone)
                    blockHint = when {
                        opened -> "Number copied — tap “Add a number” in the blocked list and paste it."
                        c.phone != null -> "Number copied. Open Phone › ⋮ › Settings › Blocked numbers and paste it."
                        else -> "No number in this one. In your messaging app, long-press the conversation › Block. For email, use Report spam."
                    }
                    Toast.makeText(ctx, if (c.phone != null) "Copied ${c.phone}" else "See how to block below", Toast.LENGTH_SHORT).show()
                },
            )
            blockHint?.let { NoteText(it) }
        }

        NoteText("Runs entirely on the phone — nothing is uploaded, and links are never opened. A clean result isn't a guarantee: when money or codes are involved, verify through an official channel.")
    }
}

// ---------------------------------------------------------------------------------------------

@Composable
private fun ResultCard(c: SafetyEngine.Check, label: String?, onReport: () -> Unit, onBlock: () -> Unit) {
    val color = verdictColor(c.verdict)
    HCard(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(HandyTokens.Space16)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(progress = { c.score / 100f }, modifier = Modifier.size(64.dp), color = color, trackColor = Handy.palette.border, strokeWidth = 6.dp)
                    Text("${c.score}", fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
                }
                Spacer(Modifier.width(14.dp))
                Column {
                    Text(c.verdict.label, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp, color = color)
                    Text(
                        "${c.findings.size} warning sign${if (c.findings.size == 1) "" else "s"}" + (label?.let { " · $it" } ?: ""),
                        color = Handy.palette.textSecondary, fontSize = 12.sp,
                    )
                }
            }
            if (c.details.isNotEmpty()) {
                Spacer(Modifier.height(HandyTokens.Space12))
                c.details.forEach { (k, v) ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 2.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(k, color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall)
                        SelectionContainer { Text(v, fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall, textAlign = TextAlign.End) }
                    }
                }
            }
            if (c.kind == SafetyEngine.Kind.QR_TEXT || c.kind == SafetyEngine.Kind.QR_WIFI) {
                Spacer(Modifier.height(HandyTokens.Space8))
                SelectionContainer { Text(c.input, style = MaterialTheme.typography.bodyMedium) }
            }
            c.findings.forEach { f ->
                Spacer(Modifier.height(HandyTokens.Space12))
                Row {
                    Text(if (f.weight >= 3) "⚠️" else "•", fontSize = 15.sp, modifier = Modifier.padding(end = 10.dp), color = if (f.weight >= 3) HandyColors.Danger else Handy.palette.textSecondary)
                    Column {
                        Text(f.title, fontWeight = FontWeight.SemiBold)
                        Text(f.why, color = Handy.palette.textSecondary, fontSize = 13.sp)
                    }
                }
            }
            Spacer(Modifier.height(HandyTokens.Space12))
            Row {
                Text("✅", fontSize = 15.sp, modifier = Modifier.padding(end = 10.dp))
                Column {
                    Text("What to do", fontWeight = FontWeight.SemiBold)
                    c.advice.forEach { Text(it, color = Handy.palette.textSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 2.dp)) }
                }
            }
            Spacer(Modifier.height(HandyTokens.Space12))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                HSecondaryButton("🚩 Report", modifier = Modifier.weight(1f), onClick = onReport)
                HSecondaryButton("⛔ Block", modifier = Modifier.weight(1f), onClick = onBlock)
            }
        }
    }
}

@Composable
private fun HistoryRow(h: SafetyEngine.HistoryItem, onClick: () -> Unit) {
    val color = verdictColor(h.verdict)
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable(onClick = onClick).padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(40.dp).background(color, CircleShape), contentAlignment = Alignment.Center) {
            Text(verdictGlyph(h.verdict), color = Color.White, fontSize = 16.sp)
        }
        Spacer(Modifier.width(HandyTokens.Space12))
        Column(Modifier.weight(1f)) {
            Text(h.input.take(60).replace('\n', ' '), maxLines = 1, overflow = TextOverflow.Ellipsis, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyMedium)
            Text("${h.verdict.label} · ${h.kind.label}", color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall)
        }
    }
}

/** Live camera QR scanner (CameraX + ML Kit barcodes). Stops itself as soon as a code is read. */
@OptIn(ExperimentalGetImage::class)
@Composable
private fun QrScanner(onCode: (String) -> Unit) {
    val lifecycle = LocalLifecycleOwner.current
    val holder = remember { CameraHolder() }
    DisposableEffect(Unit) {
        onDispose { holder.release() }
    }
    AndroidView(
        factory = { context ->
            val pv = PreviewView(context)
            val future = ProcessCameraProvider.getInstance(context)
            val scanner = BarcodeScanning.getClient()
            val exec = Executors.newSingleThreadExecutor()
            holder.exec = exec
            future.addListener({
                val provider = future.get()
                holder.provider = provider
                val preview = Preview.Builder().build().also { it.surfaceProvider = pv.surfaceProvider }
                val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                analysis.setAnalyzer(exec) { proxy ->
                    val mediaImage = proxy.image
                    if (mediaImage != null && !holder.done) {
                        scanner.process(InputImage.fromMediaImage(mediaImage, proxy.imageInfo.rotationDegrees))
                            .addOnSuccessListener { codes ->
                                val v = codes.firstOrNull()?.rawValue
                                if (v != null && !holder.done) { holder.done = true; pv.post { onCode(v) } }
                            }
                            .addOnCompleteListener { proxy.close() }
                    } else proxy.close()
                }
                try {
                    provider.unbindAll()
                    provider.bindToLifecycle(lifecycle, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
                } catch (_: Exception) { }
            }, ContextCompat.getMainExecutor(context))
            pv
        },
        modifier = Modifier.fillMaxWidth().aspectRatio(3f / 4f).clip(RoundedCornerShape(16.dp)),
    )
    SectionLabel("Point at the code")
}

private class CameraHolder {
    @Volatile var done: Boolean = false
    var provider: ProcessCameraProvider? = null
    var exec: ExecutorService? = null
    fun release() {
        runCatching { provider?.unbindAll() }
        runCatching { exec?.shutdown() }
        provider = null; exec = null
    }
}
