package com.handytools.app.tools.power

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.SwapHoriz
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
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
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HTextButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PermissionCard
import com.handytools.app.ui.Pill
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.PreviewBox
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

private const val QUOTA = "translate"
private val QUICK = listOf(
    "How much…" to "How much does this cost?", "Reservation" to "I have a reservation.",
    "Help" to "Can you help me?", "Thanks" to "Thank you very much."
)

private data class Turn(val who: String, val original: String, val translated: String)

@Composable
fun TranslateToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val saved = remember { TranslateEngine.savedPair(ctx) }
    var from by remember { mutableStateOf(saved.first) }
    var to by remember { mutableStateOf(saved.second) }
    var tab by remember { mutableStateOf(0) }
    var downloading by remember { mutableStateOf(false) }
    var packReady by remember { mutableStateOf<Boolean?>(null) }
    var ttsNote by remember { mutableStateOf<String?>(null) }

    // Text tab
    var input by remember { mutableStateOf("Where is the nearest pharmacy?") }
    var output by remember { mutableStateOf("") }
    var working by remember { mutableStateOf(false) }
    var textError by remember { mutableStateOf<String?>(null) }

    // Camera tab
    var camBitmap by remember { mutableStateOf<Bitmap?>(null) }
    val camLines = remember { mutableStateListOf<OverlayLine>() }
    var camBusy by remember { mutableStateOf(false) }
    var camStatus by remember { mutableStateOf<String?>(null) }
    var camDenied by remember { mutableStateOf(false) }
    var shotFile by remember { mutableStateOf<File?>(null) }

    // Conversation tab
    val log = remember { mutableStateListOf<Turn>() }
    var listeningLang by remember { mutableStateOf<String?>(null) }
    var convStatus by remember { mutableStateOf<String?>(null) }
    var micDenied by remember { mutableStateOf(false) }
    var pendingWho by remember { mutableStateOf<String?>(null) }

    val tts = remember { mutableStateOf<TextToSpeech?>(null) }
    val recognizer = remember { if (SpeechRecognizer.isRecognitionAvailable(ctx)) SpeechRecognizer.createSpeechRecognizer(ctx) else null }
    DisposableEffect(Unit) {
        val engine = TextToSpeech(ctx) { }
        tts.value = engine
        onDispose {
            engine.stop(); engine.shutdown()
            try { recognizer?.destroy() } catch (_: Exception) {}
        }
    }

    LaunchedEffect(from, to) {
        TranslateEngine.savePair(ctx, from, to)
        packReady = null
        packReady = TranslateEngine.bothDownloaded(from, to)
    }

    fun hasRoom() = Usage.hasRoom(ctx, QUOTA, Limits.FREE_TRANSLATE_PER_DAY)
    val quotaLine = "You've used today's ${Limits.FREE_TRANSLATE_PER_DAY} free translations. Go Pro for unlimited."

    fun speak(text: String, code: String) {
        val engine = tts.value ?: return
        val r = engine.setLanguage(TranslateEngine.locale(code))
        if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
            ttsNote = "This phone can't speak ${TranslateEngine.name(code)} yet — add a voice under Settings › Text-to-speech."
            return
        }
        ttsNote = null
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "translate")
    }

    fun copy(t: String) {
        (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("translation", t))
        Toast.makeText(ctx, "Copied", Toast.LENGTH_SHORT).show()
    }

    fun translateText() {
        val q = input.trim()
        if (q.isEmpty() || working) return
        if (from == to) { textError = "Pick two different languages to translate."; return }
        if (!hasRoom()) { textError = quotaLine; return }
        working = true; textError = null; output = ""
        scope.launch {
            try {
                val res = TranslateEngine.translate(from, to, q) { downloading = true }
                output = res
                Usage.use(ctx, QUOTA, Limits.FREE_TRANSLATE_PER_DAY) // only after success
                packReady = true
                HandyHaptics.light(ctx)
            } catch (e: Exception) {
                textError = if (packReady == true) "Couldn't translate that. Try shorter text."
                else "Couldn't download the ${TranslateEngine.name(if (to == "en") from else to)} pack. Connect once to fetch it, then it works offline."
            }
            downloading = false; working = false
        }
    }

    fun downloadPacks() {
        if (downloading) return
        downloading = true; textError = null
        scope.launch {
            try { TranslateEngine.download(from, to); packReady = true; HandyHaptics.success(ctx) }
            catch (e: Exception) { textError = "Couldn't download the pack. Check your connection and try again." }
            downloading = false
        }
    }

    fun runCamera(uri: Uri) {
        camBusy = true; camStatus = null; camLines.clear()
        scope.launch {
            val bmp = withContext(Dispatchers.IO) { TranslateEngine.loadBitmap(ctx, uri) }
            if (bmp == null) { camBusy = false; camStatus = "Couldn't open that photo. Try another one."; return@launch }
            camBitmap = bmp
            if (from == to) { camBusy = false; camStatus = "Pick two different languages to translate."; return@launch }
            if (!hasRoom()) { camBusy = false; camStatus = quotaLine; return@launch }
            try {
                val (painted, lines) = TranslateEngine.translateImage(bmp, from, to) { downloading = true }
                downloading = false
                if (lines.isEmpty()) { camStatus = "No readable text found — try a sharper, closer photo." }
                else {
                    camBitmap = painted
                    camLines.addAll(lines)
                    Usage.use(ctx, QUOTA, Limits.FREE_TRANSLATE_PER_DAY) // only after success
                    packReady = true
                    HandyHaptics.success(ctx)
                }
            } catch (e: Exception) {
                downloading = false
                camStatus = "Couldn't translate the photo. The language pack may still need a one-time download."
            }
            camBusy = false
        }
    }

    val takePicture = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val f = shotFile
        if (ok && f != null && f.exists()) runCamera(Uri.fromFile(f))
    }
    fun launchCamera() {
        val f = File(ctx.cacheDir, "translate_shot_${System.currentTimeMillis()}.jpg")
        shotFile = f
        val uri = FileProvider.getUriForFile(ctx, ctx.packageName + ".fileprovider", f)
        try { takePicture.launch(uri) } catch (e: Exception) { camStatus = "No camera app found — use Library instead." }
    }
    val camPerm = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        camDenied = !granted
        if (granted) launchCamera()
    }
    val library = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri != null) runCamera(uri)
    }

    fun finishTurn(text: String, who: String) {
        val src = if (who == "You") from else to
        val tgt = if (who == "You") to else from
        if (src == tgt) return   // same language both sides — nothing to translate, never charge
        scope.launch {
            try {
                val res = TranslateEngine.translate(src, tgt, text) { downloading = true }
                downloading = false
                log.add(Turn(who, text, res))
                Usage.use(ctx, QUOTA, Limits.FREE_TRANSLATE_PER_DAY) // only after success
                packReady = true
                speak(res, tgt)
            } catch (e: Exception) {
                downloading = false
                convStatus = "Couldn't translate that — the language pack may still need a one-time download."
            }
        }
    }

    fun listen(code: String, who: String, preferOffline: Boolean) {
        val rec = recognizer
        if (rec == null) { convStatus = "Speech recognition isn't available on this device — type it in the Text tab instead."; return }
        if (!hasRoom()) { convStatus = quotaLine; return }
        convStatus = null; pendingWho = who
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, TranslateEngine.locale(code).toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, preferOffline)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, ctx.packageName)
        }
        rec.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(p: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(r: Float) {}
            override fun onBufferReceived(b: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(t: Int, p: Bundle?) {}
            override fun onPartialResults(b: Bundle) {}
            override fun onError(err: Int) {
                listeningLang = null
                // 12 = ERROR_LANGUAGE_NOT_SUPPORTED, 13 = ERROR_LANGUAGE_UNAVAILABLE (API 31+): no offline pack — retry online once.
                if (preferOffline && (err == 12 || err == 13)) { listen(code, who, false); return }
                convStatus = if (err == SpeechRecognizer.ERROR_NO_MATCH || err == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) "Didn't catch that — tap the mic and try again."
                else "The phone can't listen in ${TranslateEngine.name(code)} right now — type it in the Text tab instead."
            }
            override fun onResults(b: Bundle) {
                listeningLang = null
                val text = b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                if (text.isNullOrBlank()) { convStatus = "Didn't catch that — tap the mic and try again."; return }
                finishTurn(text, who)
            }
        })
        try { rec.startListening(intent); listeningLang = code } catch (e: Exception) { convStatus = "Couldn't start listening. Try again." }
    }

    val micPerm = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        micDenied = !granted
        val who = pendingWho
        if (granted && who != null) listen(if (who == "You") from else to, who, true)
    }
    fun tapMic(who: String) {
        pendingWho = who
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) listen(if (who == "You") from else to, who, true)
        else micPerm.launch(Manifest.permission.RECORD_AUDIO)
    }

    val settingsIntent = remember { Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + ctx.packageName)) }
    val packName = TranslateEngine.name(if (to == "en") from else to)

    PowerToolPage(route = "translate", tabs = listOf("Text", "Camera", "Conversation"), selected = tab, onTab = { tab = it }) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            LangPicker("From", from, Modifier.weight(1f)) { from = it }
            IconButton(onClick = { val t = from; from = to; to = t; if (output.isNotEmpty()) { input = output; output = "" } }) {
                Icon(Icons.Outlined.SwapHoriz, "Swap languages", tint = HandyColors.Accent)
            }
            LangPicker("To", to, Modifier.weight(1f)) { to = it }
        }
        Spacer(Modifier.height(HandyTokens.Space12))
        if (downloading) {
            LinearProgressIndicator(Modifier.fillMaxWidth().clip(RoundedCornerShape(50)))
            Text("Downloading the $packName pack (one-time, about 30 MB) — after this it works offline.",
                style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 6.dp, bottom = 10.dp))
        }

        when (tab) {
            0 -> {
                OutlinedTextField(value = input, onValueChange = { input = it }, placeholder = { Text("Type or paste…") },
                    modifier = Modifier.fillMaxWidth(), minLines = 3)
                Spacer(Modifier.height(8.dp))
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    QUICK.forEach { (label, phrase) -> HChip(label, input == phrase) { input = phrase; translateText() } }
                }
                Spacer(Modifier.height(10.dp))
                HPrimaryButton(if (working) "Translating…" else "Translate", enabled = !working && input.isNotBlank() && from != to) { translateText() }
                if (from == to) { Text("Pick two different languages to translate.", color = HandyColors.Accent, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 6.dp)) }
                textError?.let { Text(it, color = HandyColors.Accent, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp)) }
                if (output.isNotEmpty()) {
                    Spacer(Modifier.height(10.dp))
                    HCard(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(14.dp)) {
                            Text(TranslateEngine.name(to), style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
                            Spacer(Modifier.height(4.dp))
                            Text(output, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Normal))
                        }
                    }
                    ttsNote?.let { Text(it, color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 6.dp)) }
                    Spacer(Modifier.height(8.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        HSecondaryButton("Speak", modifier = Modifier.weight(1f)) { speak(output, to) }
                        HSecondaryButton("Copy", modifier = Modifier.weight(1f)) { copy(output) }
                        HSecondaryButton("Share", modifier = Modifier.weight(1f)) { Share.text(ctx, output) }
                    }
                }
                Spacer(Modifier.height(HandyTokens.Space12))
                HCard(Modifier.fillMaxWidth()) {
                    Row(Modifier.padding(start = 14.dp, end = 6.dp, top = 6.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("$packName pack", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                            Text(
                                when (packReady) { true -> "Ready — translates offline"; false -> "Not on this phone yet — downloads on first use"; null -> "Checking…" },
                                style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary
                            )
                        }
                        if (packReady == false && !downloading) HTextButton("Download") { downloadPacks() }
                    }
                }
            }
            1 -> {
                val bmp = camBitmap
                if (bmp == null) PreviewBox(minHeight = 200.dp) { Text("Point at a menu, sign or label.", color = Handy.palette.textSecondary) }
                else Image(bmp.asImageBitmap(), "Photo with translation", Modifier.fillMaxWidth().heightIn(max = 440.dp).clip(RoundedCornerShape(16.dp)), contentScale = ContentScale.Fit)
                Spacer(Modifier.height(HandyTokens.Space12))
                PermissionCard("Camera", "Needed to photograph text to translate. Photos stay on your phone.", granted = !camDenied, intent = settingsIntent, buttonText = "Open settings")
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    HPrimaryButton(if (camBusy) "Reading…" else "Take photo", modifier = Modifier.weight(1f), enabled = !camBusy) {
                        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) launchCamera()
                        else camPerm.launch(Manifest.permission.CAMERA)
                    }
                    HSecondaryButton("Library", modifier = Modifier.weight(1f), enabled = !camBusy) {
                        library.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    }
                }
                camStatus?.let { Text(it, color = HandyColors.Accent, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp)) }
                if (camLines.isNotEmpty()) {
                    SectionLabel("Translated lines")
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        camLines.forEach { l ->
                            HCard(Modifier.fillMaxWidth()) {
                                Column(Modifier.padding(12.dp)) {
                                    Text(l.original, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                                    Text(l.translated, style = MaterialTheme.typography.bodyMedium)
                                }
                            }
                        }
                    }
                    Spacer(Modifier.height(10.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        HSecondaryButton("Copy all", modifier = Modifier.weight(1f)) { copy(camLines.joinToString("\n") { it.translated }) }
                        HSecondaryButton("Share image", modifier = Modifier.weight(1f)) {
                            val b = camBitmap ?: return@HSecondaryButton
                            scope.launch {
                                val f = withContext(Dispatchers.IO) {
                                    try {
                                        val o = File(ctx.cacheDir, "translated_${System.currentTimeMillis()}.jpg")
                                        FileOutputStream(o).use { b.compress(Bitmap.CompressFormat.JPEG, 90, it) }
                                        o
                                    } catch (e: Exception) { null }
                                }
                                if (f != null) Share.file(ctx, f, "image/jpeg") else camStatus = "Couldn't save the image."
                            }
                        }
                    }
                }
                Spacer(Modifier.height(8.dp))
                Pill("Runs natively")
                Text("Text is recognised and the translation is drawn over it in place, on the phone. Reads Latin-alphabet text (Spanish, French, German, Italian, Portuguese…).",
                    style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            }
            else -> {
                HCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.fillMaxWidth().heightIn(min = 140.dp).padding(14.dp)) {
                        if (log.isEmpty()) Text("Tap a mic, speak, and the other side hears it in their language.", color = Handy.palette.textSecondary)
                        log.forEach { t ->
                            Column(Modifier.padding(bottom = 10.dp)) {
                                Text(t.who, style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
                                Text(t.original, style = MaterialTheme.typography.bodyMedium)
                                Text(t.translated, style = MaterialTheme.typography.bodyMedium, color = HandyColors.Accent)
                            }
                        }
                        listeningLang?.let { Text("Listening (${TranslateEngine.name(it)})…", color = HandyColors.Accent, style = MaterialTheme.typography.bodySmall) }
                    }
                }
                Spacer(Modifier.height(HandyTokens.Space12))
                PermissionCard("Microphone", "Needed to hear each side of the conversation. Audio stays on your phone.", granted = !micDenied, intent = settingsIntent, buttonText = "Open settings")
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    HPrimaryButton(TranslateEngine.name(from), modifier = Modifier.weight(1f), enabled = listeningLang == null, icon = Icons.Outlined.Mic) { tapMic("You") }
                    HSecondaryButton(TranslateEngine.name(to), modifier = Modifier.weight(1f), enabled = listeningLang == null) { tapMic("Them") }
                }
                convStatus?.let { Text(it, color = HandyColors.Accent, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp)) }
                ttsNote?.let { Text(it, color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 6.dp)) }
                if (log.isNotEmpty()) {
                    Spacer(Modifier.height(8.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        val dump = log.joinToString("\n\n") { "${it.who}: ${it.original}\n${it.translated}" }
                        HSecondaryButton("Copy log", modifier = Modifier.weight(1f)) { copy(dump) }
                        HSecondaryButton("Share", modifier = Modifier.weight(1f)) { Share.text(ctx, dump) }
                        HSecondaryButton("Clear", modifier = Modifier.weight(1f)) { log.clear() }
                    }
                }
                Text("Each side speaks in their language; the phone translates and reads it aloud in the other one. Uses the phone's speech recogniser — offline when its language pack is installed.",
                    style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 10.dp))
            }
        }
        NoteText("Offline once a language pack is downloaded (ML Kit on-device). Nothing you translate leaves the phone.")
    }
}

/** From / To dropdown over the full ML Kit language list. */
@Composable
private fun LangPicker(label: String, code: String, modifier: Modifier, onPick: (String) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box(modifier) {
        HCard(Modifier.fillMaxWidth(), onClick = { open = true }) {
            Column(Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
                Text(label, style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
                Text(TranslateEngine.name(code), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
            }
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }, modifier = Modifier.heightIn(max = 380.dp)) {
            TranslateEngine.LANGS.forEach { l ->
                DropdownMenuItem(
                    text = { Text(l.name, color = if (l.code == code) HandyColors.Accent else MaterialTheme.colorScheme.onSurface) },
                    onClick = { onPick(l.code); open = false }
                )
            }
        }
    }
}
