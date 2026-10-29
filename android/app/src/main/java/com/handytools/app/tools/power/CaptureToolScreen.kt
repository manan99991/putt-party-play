package com.handytools.app.tools.power

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.net.Uri
import android.provider.CalendarContract
import android.provider.ContactsContract
import android.speech.tts.TextToSpeech
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ExpandLess
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material3.Icon
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.tools.Share
import com.handytools.app.tools.receipts.Receipt
import com.handytools.app.tools.receipts.ReceiptStore
import com.handytools.app.ui.ChipRow
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
import java.io.File
import java.util.Date
import java.util.Locale

private val TRANSLATE_LANGS = listOf(
    "es" to "Spanish", "fr" to "French", "de" to "German", "hi" to "Hindi", "zh" to "Chinese",
    "ja" to "Japanese", "ar" to "Arabic", "pt" to "Portuguese", "ru" to "Russian", "it" to "Italian",
)

private fun toast(ctx: Context, msg: String) = Toast.makeText(ctx, msg, Toast.LENGTH_SHORT).show()

/** Starts the intent; on failure shows [fallback] and runs [onFail] (e.g. copy the data instead). */
private fun open(ctx: Context, intent: Intent, fallback: String = "No app on this phone can do that.", onFail: () -> Unit = {}) {
    try { ctx.startActivity(intent) } catch (_: Exception) { toast(ctx, fallback); onFail() }
}

private fun copy(ctx: Context, text: String, msg: String = "Copied") {
    (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Tenzy", text))
    toast(ctx, msg)
}

/**
 * Capture — point the camera at a receipt, card, flyer, sign or document. Text is read on the
 * phone (ML Kit), the capture is classified, and the next step is one tap away. Nothing is uploaded.
 */
@Composable
fun CaptureToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()

    var bitmap by remember { mutableStateOf<Bitmap?>(null) }
    var result by remember { mutableStateOf<CaptureResult?>(null) }
    var noText by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }
    var quotaNote by remember { mutableStateOf<String?>(null) }
    var pendingCamera by remember { mutableStateOf<Uri?>(null) }
    var cameraDenied by remember { mutableStateOf(false) }

    val recognizer = remember { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }
    val tts = remember { mutableStateOf<TextToSpeech?>(null) }
    var speaking by remember { mutableStateOf(false) }
    DisposableEffect(Unit) {
        val engine = TextToSpeech(ctx) { }
        tts.value = engine
        onDispose { engine.stop(); engine.shutdown(); recognizer.close() }
    }

    fun reset() { result = null; noText = false; status = null; quotaNote = null; speaking = false; tts.value?.stop() }

    fun analyse(bmp: Bitmap) {
        bitmap = bmp; reset(); busy = true
        if (!Usage.hasRoom(ctx, "ocr", Limits.FREE_OCR_PER_DAY)) {
            busy = false; noText = true
            quotaNote = "You've used today's ${Limits.FREE_OCR_PER_DAY} free scans — Go Pro for unlimited. The photo still saves as PDF and shares below."
            return
        }
        scope.launch {
            val text = withContext(Dispatchers.IO) {
                runCatching { recognizer.process(InputImage.fromBitmap(bmp, 0)).await().text }.getOrNull()
            }
            busy = false
            when {
                text == null -> { noText = true; status = "Couldn't read that photo — try more light or get closer." }
                text.isBlank() -> { noText = true; status = "No text found — try more light or get closer." }
                else -> {
                    Usage.use(ctx, "ocr", Limits.FREE_OCR_PER_DAY) // only after OCR succeeded
                    result = CaptureClassifier.classify(text)
                    HandyHaptics.success(ctx)
                }
            }
        }
    }

    fun onPicked(uri: Uri?) {
        if (uri == null) return
        busy = true; status = null
        scope.launch {
            val bmp = withContext(Dispatchers.IO) { CaptureImages.load(ctx, uri) }
            if (bmp == null) { busy = false; status = "Couldn't open that image. Try another one." }
            else analyse(bmp)
        }
    }

    val library = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? -> onPicked(uri) }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok: Boolean ->
        val uri = pendingCamera
        if (ok && uri != null) onPicked(uri)
    }
    fun shoot() {
        val file = File(ctx.cacheDir, "capture_${System.currentTimeMillis()}.jpg")
        val uri = FileProvider.getUriForFile(ctx, ctx.packageName + ".fileprovider", file)
        pendingCamera = uri
        try { camera.launch(uri) } catch (_: Exception) {
            cameraDenied = true
            library.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
    }
    val cameraPerm = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted: Boolean ->
        if (granted) shoot() else {
            cameraDenied = true
            library.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
    }

    fun speak(text: String) {
        val engine = tts.value ?: run { toast(ctx, "Read-aloud isn't available on this phone"); return }
        if (speaking) { engine.stop(); speaking = false; return }
        engine.setLanguage(Locale.getDefault())
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "capture")
        speaking = true
        toast(ctx, "Reading aloud")
    }

    fun savePdf() {
        val bmp = bitmap ?: return
        scope.launch {
            val f = withContext(Dispatchers.IO) {
                runCatching { CaptureImages.toPdf(bmp, File(ctx.cacheDir, (result?.let { CaptureClassifier.fileStem(it) } ?: "capture") + ".pdf")) }.getOrNull()
            }
            if (f == null) toast(ctx, "Couldn't make the PDF — try again.") else Share.file(ctx, f, "application/pdf")
        }
    }

    fun sharePhoto() {
        val bmp = bitmap ?: return
        scope.launch {
            val f = withContext(Dispatchers.IO) { runCatching { CaptureImages.saveJpeg(bmp, File(ctx.cacheDir, "capture_share.jpg")) }.getOrNull() }
            if (f == null) toast(ctx, "Couldn't share that photo.") else Share.file(ctx, f, "image/jpeg")
        }
    }

    PowerToolPage(route = "capture") {
        // Preview — the photo, big, at the top.
        val bmp = bitmap
        if (bmp == null) {
            PreviewBox(minHeight = 190.dp) {
                Column(Modifier.padding(HandyTokens.Space24), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Point the camera at a receipt, card, flyer, sign or document.", textAlign = TextAlign.Center, color = Handy.palette.textSecondary)
                    Spacer(Modifier.height(HandyTokens.Space8))
                    Text("Tenzy works out what it is and offers the next step.", style = MaterialTheme.typography.bodySmall, textAlign = TextAlign.Center, color = Handy.palette.textSecondary)
                }
            }
        } else {
            Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surface), contentAlignment = Alignment.Center) {
                Image(bmp.asImageBitmap(), null, Modifier.fillMaxWidth().heightIn(min = 160.dp, max = 400.dp), contentScale = ContentScale.Fit)
            }
        }
        Spacer(Modifier.height(HandyTokens.Space12))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
            HPrimaryButton(if (busy) "Reading…" else "📷 Take photo", modifier = Modifier.weight(1f), enabled = !busy) {
                if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) shoot()
                else cameraPerm.launch(Manifest.permission.CAMERA)
            }
            HSecondaryButton("🖼 Library", modifier = Modifier.weight(1f), enabled = !busy) {
                library.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            }
        }
        if (cameraDenied) NoteText("Camera isn't allowed for Tenzy — pick a photo from Library instead, or allow it in Settings › Apps › Tenzy.")

        if (bitmap == null && !busy) {
            SectionLabel("Or try a sample")
            ChipRow {
                CaptureSamples.all.forEach { s ->
                    HChip(s.chip, selected = false) {
                        bitmap = s.render(); reset()
                        result = CaptureClassifier.classify(s.text)
                    }
                }
            }
        }

        if (busy) Text("Reading the text…", color = Handy.palette.textSecondary, modifier = Modifier.padding(top = HandyTokens.Space12))
        status?.let { Spacer(Modifier.height(HandyTokens.Space12)); Pill(it, HandyColors.Amber) }
        quotaNote?.let { Spacer(Modifier.height(HandyTokens.Space12)); Text(it, style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent) }

        val r = result
        if (r != null) {
            Spacer(Modifier.height(HandyTokens.Space12))
            Pill("✓ Detected: ${r.kind.label}", HandyColors.Success)
            FieldGrid(r.fields)
            SectionLabel("What next?")
            CaptureActions(r, speaking, onSpeak = { speak(r.spoken()) }, onPdf = { savePdf() }, onShare = { sharePhoto() }, bitmap = bitmap)
            AllText(r.text)
        } else if (noText && bitmap != null) {
            Spacer(Modifier.height(HandyTokens.Space12))
            SectionLabel("Available for any photo")
            HPrimaryButton("📄 Save as PDF") { savePdf() }
            Spacer(Modifier.height(HandyTokens.Space8))
            HSecondaryButton("📤 Share photo") { sharePhoto() }
        }

        NoteText("Text recognition runs on the phone (ML Kit). Nothing is uploaded.")
    }
}

// ---------------------------------------------------------------------------------------------

@Composable
private fun FieldGrid(fields: List<Pair<String, String>>) {
    HCard(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(horizontal = HandyTokens.Space16, vertical = HandyTokens.Space8)) {
            fields.forEach { (k, v) ->
                Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.Top) {
                    Text(k, style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary, modifier = Modifier.padding(end = HandyTokens.Space12))
                    SelectionContainer(Modifier.weight(1f)) {
                        Text(v, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.End, modifier = Modifier.fillMaxWidth())
                    }
                }
            }
        }
    }
}

@Composable
private fun ActionButton(label: String, primary: Boolean, onClick: () -> Unit) {
    Spacer(Modifier.height(HandyTokens.Space8))
    if (primary) HPrimaryButton(label, onClick = onClick) else HSecondaryButton(label, onClick = onClick)
}

@Composable
private fun CaptureActions(r: CaptureResult, speaking: Boolean, onSpeak: () -> Unit, onPdf: () -> Unit, onShare: () -> Unit, bitmap: Bitmap?) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var reminderOpen by remember(r) { mutableStateOf(false) }
    var reminderDays by remember(r) { mutableStateOf(30) }
    var translateOpen by remember(r) { mutableStateOf(false) }
    val readLabel = if (speaking) "⏹ Stop reading" else "🔊 Read aloud"

    when (r.kind) {
        CaptureKind.RECEIPT -> {
            ActionButton("🧾 Save receipt + total", true) {
                scope.launch {
                    val path = withContext(Dispatchers.IO) {
                        runCatching {
                            val f = File(ctx.filesDir, "receipt_${System.currentTimeMillis()}.jpg")
                            if (bitmap != null) CaptureImages.saveJpeg(bitmap, f).absolutePath else ""
                        }.getOrDefault("")
                    }
                    val list = ReceiptStore.load(ctx).toMutableList()
                    list.add(Receipt(System.currentTimeMillis(), r.merchant.ifBlank { "Receipt" }, r.total, r.purchaseMs ?: System.currentTimeMillis(), 12, path))
                    ReceiptStore.save(ctx, list)
                    HandyHaptics.success(ctx)
                    toast(ctx, "Saved to Receipts · ${r.total.ifBlank { "no total" }} · ${r.merchant.ifBlank { "Receipt" }}")
                }
            }
            ActionButton("📅 Set return / warranty reminder", false) { reminderOpen = !reminderOpen }
            if (reminderOpen) {
                val base = r.purchaseMs ?: System.currentTimeMillis()
                val whenMs = base + reminderDays * 24L * 3_600_000L
                SectionLabel("Remind me on")
                ChipRow {
                    HChip("30 days (return)", reminderDays == 30) { reminderDays = 30 }
                    HChip("1 year (warranty)", reminderDays == 365) { reminderDays = 365 }
                }
                Spacer(Modifier.height(HandyTokens.Space8))
                HPrimaryButton("Set reminder · ${CaptureClassifier.dayFmt.format(Date(whenMs))}") {
                    val title = (if (reminderDays == 30) "Return window ends: " else "Warranty ends: ") + r.merchant.ifBlank { "receipt" }
                    open(ctx, Intent(Intent.ACTION_INSERT).setData(CalendarContract.Events.CONTENT_URI)
                        .putExtra(CalendarContract.Events.TITLE, title)
                        .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, whenMs)
                        .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, whenMs + 3_600_000L)
                        .putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, true)
                        .putExtra(CalendarContract.Events.DESCRIPTION, "Total ${r.total.ifBlank { "—" }}. Scanned with Tenzy."), "No calendar app found — the date is ${CaptureClassifier.dayFmt.format(Date(whenMs))}.")
                    reminderOpen = false
                }
            }
            ActionButton("📊 Export items to spreadsheet (CSV)", false) {
                val f = File(ctx.cacheDir, CaptureClassifier.fileStem(r) + ".csv")
                runCatching { f.writeText(CaptureClassifier.csv(r)) }
                    .onSuccess { Share.file(ctx, f, "text/csv") }
                    .onFailure { toast(ctx, "Couldn't write the CSV — try again.") }
            }
            ActionButton(readLabel, false, onSpeak)
        }
        CaptureKind.CARD -> {
            ActionButton("👤 Save to Contacts", true) {
                open(ctx, Intent(ContactsContract.Intents.Insert.ACTION).apply {
                    type = ContactsContract.RawContacts.CONTENT_TYPE
                    if (r.name.isNotBlank()) putExtra(ContactsContract.Intents.Insert.NAME, r.name)
                    if (r.phone.isNotBlank()) putExtra(ContactsContract.Intents.Insert.PHONE, r.phone)
                    if (r.email.isNotBlank()) putExtra(ContactsContract.Intents.Insert.EMAIL, r.email)
                    if (r.company.isNotBlank()) putExtra(ContactsContract.Intents.Insert.COMPANY, r.company)
                    if (r.title.isNotBlank()) putExtra(ContactsContract.Intents.Insert.JOB_TITLE, r.title)
                    putExtra(ContactsContract.Intents.Insert.NOTES, "Scanned with Tenzy")
                }, "No contacts app found — the card text is copied instead.") { copy(ctx, r.text, "Copied the card text") }
            }
            if (r.phone.isNotBlank()) ActionButton("📞 Call ${r.phone}", false) {
                open(ctx, Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + r.phone.filter { it.isDigit() || it == '+' })), "This device can't make calls — number copied.") { copy(ctx, r.phone, "Copied ${r.phone}") }
            } else ActionButton("📞 No phone number found — copy card text", false) { copy(ctx, r.text, "Copied the card text") }
            if (r.email.isNotBlank()) ActionButton("✉️ Email ${r.email}", false) {
                open(ctx, Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:" + r.email)), "No email app found — address copied.") { copy(ctx, r.email, "Copied ${r.email}") }
            } else ActionButton("✉️ No email found — copy card text", false) { copy(ctx, r.text, "Copied the card text") }
            ActionButton(readLabel, false, onSpeak)
        }
        CaptureKind.FLYER -> {
            ActionButton("📅 Add to calendar", true) {
                val start = r.startMs ?: (System.currentTimeMillis() + 3_600_000L)
                val end = r.endMs ?: (start + 2 * 3_600_000L)
                open(ctx, Intent(Intent.ACTION_INSERT).setData(CalendarContract.Events.CONTENT_URI)
                    .putExtra(CalendarContract.Events.TITLE, r.event.ifBlank { "Event" })
                    .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, start)
                    .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, end)
                    .putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, r.startMs != null && r.endMs != null && r.endMs - r.startMs == 24 * 3_600_000L)
                    .putExtra(CalendarContract.Events.EVENT_LOCATION, r.venue)
                    .putExtra(CalendarContract.Events.DESCRIPTION, r.text), "No calendar app found — event text copied.") { copy(ctx, r.text, "Copied") }
            }
            if (r.venue.isNotBlank()) ActionButton("🗺️ Open in Maps · ${r.venue.take(28)}", false) {
                open(ctx, Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=" + Uri.encode(r.venue))), "No maps app found — venue copied.") { copy(ctx, r.venue, "Copied ${r.venue}") }
            } else ActionButton("🗺️ No venue found — search the flyer text in Maps", false) {
                open(ctx, Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=" + Uri.encode(r.event.ifBlank { r.text.take(60) }))))
            }
            ActionButton("📤 Share event", false) {
                Share.text(ctx, listOf(r.event, r.fields.firstOrNull { it.first == "When" }?.second.orEmpty(), r.venue).filter { it.isNotBlank() && it != "—" }.joinToString("\n") + "\n\n" + r.text)
            }
            ActionButton(readLabel, false, onSpeak)
        }
        CaptureKind.DOCUMENT, CaptureKind.SIGN -> {
            ActionButton("📋 Copy all text", true) { copy(ctx, r.text, "Copied ${r.words} words") }
            ActionButton("🌐 Translate this", false) { translateOpen = !translateOpen }
            if (translateOpen) InlineTranslate(r.text)
            ActionButton("📄 Save as PDF", false, onPdf)
            ActionButton(readLabel, false, onSpeak)
        }
    }
    Spacer(Modifier.height(HandyTokens.Space8))
    HSecondaryButton("📤 Share photo", onClick = onShare)
}

/** On-device ML Kit translation of the recognised text, right here — no screen hop. */
@Composable
private fun InlineTranslate(text: String) {
    val ctx = LocalContext.current
    var other by remember { mutableStateOf("es") }
    var enToX by remember { mutableStateOf(true) }
    var output by remember { mutableStateOf("") }
    var working by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val overQuota = !Usage.hasRoom(ctx, "translate", Limits.FREE_TRANSLATE_PER_DAY)
    val otherName = TRANSLATE_LANGS.firstOrNull { it.first == other }?.second ?: other

    SectionLabel("Translate")
    ChipRow { HChip(if (enToX) "English → $otherName" else "$otherName → English", true) { enToX = !enToX } }
    Spacer(Modifier.height(HandyTokens.Space8))
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
        TRANSLATE_LANGS.forEach { (code, nm) -> HChip(nm, other == code) { other = code; output = "" } }
    }
    if (overQuota) Text("You've used today's ${Limits.FREE_TRANSLATE_PER_DAY} free translations. Go Pro for unlimited — or copy the text into any translator.",
        style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = HandyTokens.Space8))
    Spacer(Modifier.height(HandyTokens.Space8))
    HPrimaryButton(if (working) "Translating…" else "Translate", enabled = !working && !overQuota) {
        working = true; error = null; output = ""
        val src = if (enToX) "en" else other
        val tgt = if (enToX) other else "en"
        val translator = Translation.getClient(
            TranslatorOptions.Builder()
                .setSourceLanguage(TranslateLanguage.fromLanguageTag(src) ?: TranslateLanguage.ENGLISH)
                .setTargetLanguage(TranslateLanguage.fromLanguageTag(tgt) ?: TranslateLanguage.SPANISH)
                .build()
        )
        translator.downloadModelIfNeeded()
            .addOnSuccessListener {
                translator.translate(text)
                    .addOnSuccessListener { out -> output = out; working = false; translator.close(); Usage.use(ctx, "translate", Limits.FREE_TRANSLATE_PER_DAY) }
                    .addOnFailureListener { error = "Couldn't translate that — text is copied so you can paste it anywhere."; working = false; translator.close(); copy(ctx, text) }
            }
            .addOnFailureListener { error = "Couldn't download the $otherName pack (needs a connection once). Text copied for any translator."; working = false; translator.close(); copy(ctx, text) }
    }
    error?.let { Text(it, color = HandyColors.Danger, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = HandyTokens.Space8)) }
    if (output.isNotEmpty()) {
        Spacer(Modifier.height(HandyTokens.Space8))
        HCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(HandyTokens.Space16)) {
                SelectionContainer { Text(output, style = MaterialTheme.typography.bodyLarge) }
                Spacer(Modifier.height(HandyTokens.Space8))
                HSecondaryButton("Copy translation") { copy(ctx, output) }
            }
        }
    }
}

@Composable
private fun AllText(text: String) {
    val ctx = LocalContext.current
    var expanded by remember(text) { mutableStateOf(false) }
    Spacer(Modifier.height(HandyTokens.Space12))
    HCard(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(HandyTokens.Space16)) {
            Row(Modifier.fillMaxWidth().clickable { expanded = !expanded }, horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("All text", style = MaterialTheme.typography.titleMedium)
                Icon(if (expanded) Icons.Outlined.ExpandLess else Icons.Outlined.ExpandMore, null, tint = Handy.palette.textSecondary)
            }
            if (expanded) {
                Spacer(Modifier.height(HandyTokens.Space8))
                SelectionContainer { Text(text, style = MaterialTheme.typography.bodyMedium) }
                Spacer(Modifier.height(HandyTokens.Space12))
                HSecondaryButton("Copy") { copy(ctx, text) }
            } else {
                Text(text.lineSequence().firstOrNull { it.isNotBlank() }?.trim().orEmpty() + " …", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 4.dp))
            }
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Samples — the prototype's canvas placeholders, drawn the same way so the full flow can be tried
// without a photo. They don't touch OCR, so they never cost a scan.

private class CaptureSample(val chip: String, val lines: List<String>, private val bg: Int, private val fg: Int, private val h: Int) {
    val text: String get() = lines.joinToString("\n")
    fun render(): Bitmap {
        val bmp = Bitmap.createBitmap(600, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        c.drawColor(bg)
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = fg; textSize = 26f; isFakeBoldText = true }
        lines.forEachIndexed { i, l -> c.drawText(l, 30f, 50f + i * 32f, p) }
        return bmp
    }
}

private object CaptureSamples {
    val all = listOf(
        CaptureSample("Receipt", listOf("WHOLE FOODS MARKET", "", "Organic bananas      3.49", "Oat milk             4.99", "Sourdough            6.50", "Coffee beans        14.99", "Greens               5.21", "", "TOTAL              $42.18", "VISA ****4821", "14 JUN 2026 10:42"), 0xFFF4F1EA.toInt(), 0xFF222222.toInt(), 460),
        CaptureSample("Business card", listOf("", "  Priya Natarajan", "  Head of Partnerships", "  Northwind Labs", "", "  priya@northwind.io", "  +1 (312) 555-0148", "  northwind.io"), 0xFF1F2A44.toInt(), 0xFFFFFFFF.toInt(), 360),
        CaptureSample("Event flyer", listOf("", "   SUMMER BLOCK PARTY", "", "   Sat 18 Jul 2026 · 4–9 PM", "   Riverside Park, Naperville", "", "   Live music · Food trucks", "   Free entry"), 0xFF7A2CFF.toInt(), 0xFFFFFFFF.toInt(), 460),
        CaptureSample("Document", listOf("SERVICE AGREEMENT", "", "This agreement is made between", "Northwind Labs (\"Provider\") and", "the Client, effective 1 Aug 2026.", "", "1. Scope. Provider will deliver…", "2. Term. Twelve (12) months.", "3. Fees. As set out in Schedule A."), 0xFFFFFFFF.toInt(), 0xFF222222.toInt(), 460),
    )
}
