package com.handytools.app.tools.power

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.webkit.MimeTypeMap
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.Pause
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.Stop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RangeSlider
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PermissionCard
import com.handytools.app.ui.Pill
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

private const val BARS = 48
private const val USAGE_KEY = "audiotext"

/** Owns the MediaRecorder + live SpeechRecognizer for one take. Main thread only. */
private class LiveSession(private val ctx: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private var recorder: MediaRecorder? = null
    private var recognizer: SpeechRecognizer? = null
    private var intent: Intent? = null
    var active = false
        private set
    var file: File? = null
        private set
    var startedAt = 0L
        private set
    var onPartial: (String) -> Unit = {}
    var onFinal: (String) -> Unit = {}
    val canTranscribe: Boolean = SpeechRecognizer.isRecognitionAvailable(ctx)

    fun start(out: File): Boolean {
        val r = try { VoiceAudio.newRecorder(ctx, out).apply { prepare(); start() } } catch (e: Exception) { return false }
        recorder = r; file = out; startedAt = System.currentTimeMillis(); active = true
        if (canTranscribe) startRecognizer()
        return true
    }

    fun amplitude(): Float = try { (recorder?.maxAmplitude ?: 0).coerceAtLeast(0) / 32767f } catch (e: Exception) { 0f }

    private fun startRecognizer() {
        val rec = try { SpeechRecognizer.createSpeechRecognizer(ctx) } catch (e: Exception) { return }
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, ctx.packageName)
        }
        rec.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(p: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(r: Float) {}
            override fun onBufferReceived(b: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(t: Int, p: Bundle?) {}
            override fun onPartialResults(b: Bundle) {
                onPartial(b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: "")
            }
            override fun onError(code: Int) { onPartial(""); restart(400L) } // silence / pause: keep listening
            override fun onResults(b: Bundle) {
                val text = b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                if (!text.isNullOrBlank()) onFinal(text)
                onPartial("")
                restart(150L)
            }
        })
        recognizer = rec; intent = i
        try { rec.startListening(i) } catch (_: Exception) {}
    }

    private fun restart(delayMs: Long) {
        handler.postDelayed({
            if (!active) return@postDelayed
            val r = recognizer ?: return@postDelayed
            val i = intent ?: return@postDelayed
            try { r.startListening(i) } catch (_: Exception) {}
        }, delayMs)
    }

    /** Stops both. Returns elapsed ms, or -1 when the recording itself failed (e.g. too short). */
    fun stop(): Long {
        active = false
        handler.removeCallbacksAndMessages(null)
        try { recognizer?.stopListening() } catch (_: Exception) {}
        try { recognizer?.destroy() } catch (_: Exception) {}
        recognizer = null
        val elapsed = System.currentTimeMillis() - startedAt
        val ok = try { recorder?.stop(); true } catch (e: Exception) { false }
        try { recorder?.release() } catch (_: Exception) {}
        recorder = null
        return if (ok) elapsed else -1L
    }

    fun release() { if (active) stop() }
}

@Composable
fun VoiceToolScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val session = remember { LiveSession(ctx) }

    var recording by remember { mutableStateOf(false) }
    var micDenied by remember { mutableStateOf(false) }
    val liveAmps = remember { mutableStateListOf<Float>() }
    val history = remember { ArrayList<Float>() }
    var staticAmps by remember { mutableStateOf<List<Float>>(emptyList()) }
    var elapsed by remember { mutableStateOf(0L) }
    var finalText by remember { mutableStateOf("") }
    var partial by remember { mutableStateOf("") }

    var current by remember { mutableStateOf<File?>(null) }
    var currentDur by remember { mutableStateOf(0L) }
    var transcript by remember { mutableStateOf("") }
    var transcriptNote by remember { mutableStateOf<String?>(null) }
    var savedId by remember { mutableStateOf<String?>(null) }
    var tab by remember { mutableStateOf(0) }
    val checked = remember { mutableStateListOf<Int>() }
    var range by remember { mutableStateOf(0f..1f) }
    var status by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    var notes by remember { mutableStateOf(VoiceNotes.load(ctx)) }
    var query by remember { mutableStateOf("") }
    var confirmDelete by remember { mutableStateOf<VoiceNote?>(null) }

    val player = remember { MediaPlayer() }
    var playerReady by remember { mutableStateOf(false) }
    var playing by remember { mutableStateOf(false) }
    var pos by remember { mutableStateOf(0L) }
    var seeking by remember { mutableStateOf(false) }

    session.onPartial = { partial = it }
    session.onFinal = { t -> finalText = (finalText + " " + t).trim() }

    DisposableEffect(Unit) {
        onDispose {
            session.release()
            try { player.release() } catch (_: Exception) {}
        }
    }

    fun stopPlayback() {
        if (playing) { try { player.pause() } catch (_: Exception) {} }
        playing = false
    }

    fun loadPlayer(f: File) {
        stopPlayback()
        playerReady = try {
            player.reset()
            player.setDataSource(f.absolutePath)
            player.prepare()
            player.setOnCompletionListener { playing = false; pos = 0L }
            true
        } catch (e: Exception) { false }
        pos = 0L
    }

    fun togglePlay() {
        if (!playerReady) return
        if (playing) stopPlayback() else { try { player.start(); playing = true } catch (_: Exception) {} }
    }

    LaunchedEffect(playing) {
        while (playing && isActive) {
            if (!seeking) pos = try { player.currentPosition.toLong() } catch (e: Exception) { 0L }
            delay(200L)
        }
    }

    LaunchedEffect(recording) {
        while (recording && isActive) {
            val a = session.amplitude()
            history.add(a)
            liveAmps.add(a)
            if (liveAmps.size > BARS) liveAmps.removeAt(0)
            elapsed = System.currentTimeMillis() - session.startedAt
            delay(80L)
        }
    }

    fun openTake(f: File, dur: Long, text: String, note: String?, amps: List<Float>, id: String?) {
        current = f; currentDur = dur; transcript = text; transcriptNote = note; savedId = id
        staticAmps = amps; range = 0f..1f; tab = 0; checked.clear()
        loadPlayer(f)
    }

    fun beginTake() {
        if (!Usage.hasRoom(ctx, USAGE_KEY, Limits.FREE_AUDIO_PER_DAY)) {
            status = "You've used today's ${Limits.FREE_AUDIO_PER_DAY} free recordings. Go Pro for unlimited."; return
        }
        stopPlayback()
        val f = File(ctx.cacheDir, "take_${System.currentTimeMillis()}.m4a")
        history.clear(); liveAmps.clear(); finalText = ""; partial = ""; elapsed = 0L; status = null
        if (!session.start(f)) { status = "Couldn't start the microphone. Close other apps using it and try again."; return }
        recording = true
        HandyHaptics.light(ctx)
    }

    fun endTake() {
        val dur = session.stop()
        recording = false
        val f = session.file
        val text = (finalText + " " + partial).trim()
        partial = ""
        if (dur < 0L || f == null || !f.exists() || f.length() < 1000L) {
            status = "That was too short — hold Record a little longer."; return
        }
        Usage.use(ctx, USAGE_KEY, Limits.FREE_AUDIO_PER_DAY) // success path only
        val real = VoiceAudio.durationMs(f).takeIf { it > 0L } ?: dur
        val note = when {
            !session.canTranscribe -> "Live transcription isn't available on this device — the recording still saves."
            text.isEmpty() -> "No speech recognised — try speaking a little closer to the phone."
            else -> null
        }
        openTake(f, real, text, note, VoiceAudio.downsample(history, BARS), null)
        HandyHaptics.success(ctx)
    }

    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        micDenied = !granted
        if (granted) beginTake()
    }

    val importer = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        busy = true; status = null
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                try {
                    val mime = ctx.contentResolver.getType(uri) ?: "audio/mp4"
                    val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "m4a"
                    val f = File(ctx.cacheDir, "import_${System.currentTimeMillis()}.$ext")
                    ctx.contentResolver.openInputStream(uri)?.use { input -> f.outputStream().use { input.copyTo(it) } }
                    val d = VoiceAudio.durationMs(f)
                    if (d <= 0L) null else f to d
                } catch (e: Exception) { null }
            }
            busy = false
            if (result == null) { status = "Couldn't open that file. Try an MP3, M4A or a voice recording."; return@launch }
            openTake(result.first, result.second, "", "Transcription of imported files isn't available on this device yet — recording live is.", List(BARS) { 0.12f }, null)
        }
    }

    fun saveCurrent() {
        val f = current ?: return
        if (savedId != null) return
        val n = VoiceNotes.add(ctx, f, transcript, currentDur)
        notes = VoiceNotes.load(ctx)
        savedId = n.id; current = n.file
        loadPlayer(n.file)
        status = "Saved"; HandyHaptics.success(ctx)
    }

    fun trimAndSave() {
        val f = current ?: return
        val startMs = (range.start * currentDur).toLong()
        val endMs = (range.endInclusive * currentDur).toLong()
        if (endMs - startMs < 500L) { status = "Keep at least half a second."; return }
        busy = true; status = null
        scope.launch {
            val out = withContext(Dispatchers.IO) {
                try {
                    val o = File(ctx.cacheDir, "trim_${System.currentTimeMillis()}.m4a")
                    VoiceAudio.trim(ctx, Uri.fromFile(f), startMs, endMs, o)
                    if (o.length() < 500L) null else o
                } catch (e: Exception) { null }
            }
            busy = false
            if (out == null) { status = "Couldn't trim that file. Trimming works on recordings and M4A/AAC audio — the original still plays and saves."; return@launch }
            val title = VoiceNotes.titleFrom(transcript, "Voice note") + " (trimmed)"
            VoiceNotes.add(ctx, out, transcript, endMs - startMs, title)
            notes = VoiceNotes.load(ctx)
            status = "Trimmed copy saved"; HandyHaptics.success(ctx)
        }
    }

    fun copyText(t: String) {
        (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("note", t))
        Toast.makeText(ctx, "Copied", Toast.LENGTH_SHORT).show()
    }

    fun shareAudio(f: File) {
        val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(f.extension) ?: "audio/*"
        Share.file(ctx, f, mime)
    }

    val settingsIntent = remember { Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + ctx.packageName)) }
    val liveText = (finalText + " " + partial).trim()

    PowerToolPage(route = "voice") {
        // Preview: waveform + timer + live transcript / player
        HCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(14.dp)) {
                val shown = if (recording) {
                    if (liveAmps.size < BARS) List(BARS - liveAmps.size) { 0f } + liveAmps.toList() else liveAmps.toList()
                } else staticAmps
                Waveform(shown, if (!recording && current != null && tab == 3) range else null)
                Spacer(Modifier.height(6.dp))
                val timer = when {
                    recording -> VoiceNotes.fmt(elapsed) + " · recording"
                    current != null -> VoiceNotes.fmt(pos) + " / " + VoiceNotes.fmt(currentDur)
                    else -> "0:00"
                }
                Text(timer, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary,
                    modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
                if (recording) {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        if (liveText.isEmpty()) (if (session.canTranscribe) "Listening…" else "Recording…") else liveText,
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (liveText.isEmpty()) Handy.palette.textSecondary else MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.fillMaxWidth().heightIn(min = 40.dp)
                    )
                } else if (current == null) {
                    Spacer(Modifier.height(8.dp))
                    Text("Tap Record and start talking — the transcript appears as you speak.",
                        style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                } else {
                    Spacer(Modifier.height(4.dp))
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        IconButton(onClick = { togglePlay() }, enabled = playerReady) {
                            Icon(if (playing) Icons.Outlined.Pause else Icons.Outlined.PlayArrow, if (playing) "Pause" else "Play", tint = HandyColors.Accent)
                        }
                        Slider(
                            value = pos.toFloat().coerceIn(0f, currentDur.toFloat().coerceAtLeast(1f)),
                            onValueChange = { seeking = true; pos = it.toLong() },
                            onValueChangeFinished = { try { player.seekTo(pos.toInt()) } catch (_: Exception) {}; seeking = false },
                            valueRange = 0f..currentDur.toFloat().coerceAtLeast(1f),
                            enabled = playerReady,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }
        Spacer(Modifier.height(HandyTokens.Space12))

        PermissionCard("Microphone", "Needed to record and transcribe. Audio stays on your phone.", granted = !micDenied, intent = settingsIntent, buttonText = "Open settings")

        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            HPrimaryButton(
                if (recording) "Stop" else "Record", modifier = Modifier.weight(1f), enabled = !busy,
                icon = if (recording) Icons.Outlined.Stop else Icons.Outlined.Mic
            ) {
                if (recording) endTake()
                else if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) beginTake()
                else permLauncher.launch(Manifest.permission.RECORD_AUDIO)
            }
            HSecondaryButton(if (busy) "Working…" else "Import", modifier = Modifier.weight(1f), enabled = !recording && !busy) { importer.launch("audio/*") }
        }
        status?.let { Text(it, color = HandyColors.Accent, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp)) }

        val take = current
        if (take != null && !recording) {
            Spacer(Modifier.height(HandyTokens.Space12))
            val todos = remember(transcript) { VoiceText.todos(transcript) }
            val summary = remember(transcript) { VoiceText.summary(transcript) }
            val details = remember(transcript) { VoiceText.keyDetails(transcript) }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                HChip("Transcript", tab == 0) { tab = 0 }
                HChip("Summary", tab == 1) { tab = 1 }
                HChip("To-dos (${todos.size})", tab == 2) { tab = 2 }
                HChip("Trim", tab == 3) { tab = 3 }
            }
            Spacer(Modifier.height(HandyTokens.Space8))
            when (tab) {
                0 -> HCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp)) {
                        if (transcript.isEmpty()) Text(transcriptNote ?: "(no speech recognised)", color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium)
                        else {
                            Text(transcript, style = MaterialTheme.typography.bodyMedium)
                            transcriptNote?.let { Spacer(Modifier.height(6.dp)); Text(it, color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall) }
                        }
                    }
                }
                1 -> HCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp)) {
                        if (summary.isEmpty()) Text(transcriptNote ?: "Nothing to summarise yet.", color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodyMedium)
                        else Text(summary, style = MaterialTheme.typography.bodyMedium)
                        if (details.isNotEmpty()) {
                            Spacer(Modifier.height(10.dp))
                            Text("Key details", style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
                            Spacer(Modifier.height(4.dp))
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                details.take(4).forEach { Pill(it) }
                            }
                            if (details.size > 4) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                details.drop(4).forEach { Pill(it) }
                            }
                        }
                    }
                }
                2 -> if (todos.isEmpty()) {
                    HCard(Modifier.fillMaxWidth()) { Text("No action items found.", color = Handy.palette.textSecondary, modifier = Modifier.padding(14.dp)) }
                } else Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    todos.forEachIndexed { i, t ->
                        HCard(Modifier.fillMaxWidth(), onClick = { if (checked.contains(i)) checked.remove(i) else checked.add(i) }) {
                            Row(Modifier.padding(horizontal = 6.dp, vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                                Checkbox(checked = checked.contains(i), onCheckedChange = { if (it) checked.add(i) else checked.remove(i) })
                                Text(t, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f).padding(end = 8.dp),
                                    color = if (checked.contains(i)) Handy.palette.textSecondary else MaterialTheme.colorScheme.onSurface)
                            }
                        }
                    }
                }
                else -> HCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp)) {
                        Text("Keep from · to", style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(VoiceNotes.fmt((range.start * currentDur).toLong()), fontWeight = FontWeight.Medium)
                            Text(VoiceNotes.fmt((range.endInclusive * currentDur).toLong()), fontWeight = FontWeight.Medium)
                        }
                        RangeSlider(value = range, onValueChange = { range = it }, valueRange = 0f..1f)
                        Text("Clip length  " + VoiceNotes.fmt(((range.endInclusive - range.start) * currentDur).toLong()),
                            style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                        Spacer(Modifier.height(10.dp))
                        HSecondaryButton(if (busy) "Trimming…" else "Trim & save copy", enabled = !busy) { trimAndSave() }
                    }
                }
            }
            Spacer(Modifier.height(HandyTokens.Space12))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                HPrimaryButton(if (savedId != null) "Saved" else "Save note", modifier = Modifier.weight(1f), enabled = savedId == null && !busy) { saveCurrent() }
                HSecondaryButton("Copy text", modifier = Modifier.weight(1f), enabled = transcript.isNotEmpty()) { copyText(transcript) }
            }
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                HSecondaryButton("Share audio", modifier = Modifier.weight(1f)) { shareAudio(take) }
                HSecondaryButton("Share text", modifier = Modifier.weight(1f), enabled = transcript.isNotEmpty()) { Share.text(ctx, transcript) }
            }
        }

        SectionLabel("Saved notes")
        if (notes.isNotEmpty()) {
            OutlinedTextField(
                value = query, onValueChange = { query = it }, singleLine = true,
                placeholder = { Text("Search transcripts") }, modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)
            )
        }
        val visible = if (query.isBlank()) notes else notes.filter { it.title.contains(query, true) || it.transcript.contains(query, true) }
        if (notes.isEmpty()) Text("No notes yet.", color = Handy.palette.textSecondary, modifier = Modifier.padding(10.dp))
        else if (visible.isEmpty()) Text("No notes match \"$query\".", color = Handy.palette.textSecondary, modifier = Modifier.padding(10.dp))
        else Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            visible.forEach { n ->
                val isCurrent = savedId == n.id
                HCard(Modifier.fillMaxWidth()) {
                    Row(Modifier.padding(start = 12.dp, top = 4.dp, bottom = 4.dp, end = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f).clickable { if (!recording) openTake(n.file, n.durationMs, n.transcript, null, List(BARS) { 0.12f }, n.id) }) {
                            Text(n.title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis,
                                color = if (isCurrent) HandyColors.Accent else MaterialTheme.colorScheme.onSurface)
                            Text(VoiceNotes.fmt(n.durationMs) + " · " + VoiceNotes.dateLabel(n.createdAt), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                        }
                        IconButton(onClick = {
                            if (recording) return@IconButton
                            if (isCurrent) togglePlay() else {
                                openTake(n.file, n.durationMs, n.transcript, null, List(BARS) { 0.12f }, n.id)
                                togglePlay()
                            }
                        }) { Icon(if (isCurrent && playing) Icons.Outlined.Pause else Icons.Outlined.PlayArrow, "Play", tint = HandyColors.Accent) }
                        IconButton(onClick = { shareAudio(n.file) }) { Icon(Icons.Outlined.Share, "Share", tint = Handy.palette.textSecondary) }
                        IconButton(onClick = { confirmDelete = n }) { Icon(Icons.Outlined.Delete, "Delete", tint = Handy.palette.textSecondary) }
                    }
                }
            }
        }
        NoteText("Transcription runs on the phone. Nothing is uploaded.")
    }

    confirmDelete?.let { n ->
        AlertDialog(
            onDismissRequest = { confirmDelete = null },
            title = { Text("Delete this note?") },
            text = { Text("\"${n.title}\" and its audio will be removed from your phone.") },
            confirmButton = {
                TextButton(onClick = {
                    if (savedId == n.id) { stopPlayback(); current = null; savedId = null }
                    VoiceNotes.delete(ctx, n)
                    notes = VoiceNotes.load(ctx)
                    confirmDelete = null
                }) { Text("Delete", color = HandyColors.Danger) }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = null }) { Text("Keep") } }
        )
    }
}

/** 48 rounded bars; the live view scrolls in from the right, the static view shows the whole take. */
@Composable
private fun Waveform(amps: List<Float>, range: ClosedFloatingPointRange<Float>?) {
    val accent = HandyColors.Accent
    val dim = Handy.palette.textSecondary.copy(alpha = 0.35f)
    Canvas(Modifier.fillMaxWidth().height(64.dp)) {
        val gap = 2.dp.toPx()
        val minH = 4.dp.toPx()
        val w = (size.width - gap * (BARS - 1)) / BARS
        for (i in 0 until BARS) {
            val a = amps.getOrElse(i) { 0f }.coerceIn(0f, 1f)
            val h = minH + a * (size.height - minH)
            val x = i * (w + gap)
            val frac = (i + 0.5f) / BARS
            val inRange = range == null || (frac >= range.start && frac <= range.endInclusive)
            drawRoundRect(
                color = if (inRange) accent else dim,
                topLeft = Offset(x, (size.height - h) / 2f),
                size = Size(w, h),
                cornerRadius = CornerRadius(w / 2f, w / 2f)
            )
        }
    }
}
