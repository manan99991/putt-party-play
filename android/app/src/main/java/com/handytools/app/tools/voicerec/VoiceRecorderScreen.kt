package com.handytools.app.tools.voicerec

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.Stop
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RangeSlider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.nio.ByteBuffer

/**
 * Voice Recorder — the audio hub. Record and transcribe your voice on-device, tidy the text up
 * (case, spacing, line breaks), then share or copy it; or import a recording or video and trim it
 * down to a clip or ringtone. Everything runs on the phone; nothing is uploaded.
 */
@Composable
fun VoiceRecorderScreen() {
    val ctx = LocalContext.current
    var mode by remember { mutableStateOf(0) } // 0 = record & transcribe, 1 = trim

    Column(
        Modifier.fillMaxWidth().statusBarsPadding().padding(20.dp).verticalScroll(rememberScrollState())
    ) {
        ToolHeader("Voice Recorder", "Record and transcribe your voice, clean up the text, or trim a recording into a clip.")
        Spacer(Modifier.size(14.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            HChip("Record & transcribe", mode == 0) { mode = 0 }
            HChip("Trim a clip", mode == 1) { mode = 1 }
        }
        Spacer(Modifier.size(16.dp))

        if (mode == 0) RecordPane(ctx) else TrimPane(ctx)

        Spacer(Modifier.size(16.dp))
        BannerAd()
    }
}

@Composable
private fun RecordPane(ctx: Context) {
    var transcript by remember { mutableStateOf("") }
    var partial by remember { mutableStateOf("") }
    var listening by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val overQuota = !Usage.hasRoom(ctx, "audiotext", Limits.FREE_AUDIO_PER_DAY)

    val recognizer = remember { if (SpeechRecognizer.isRecognitionAvailable(ctx)) SpeechRecognizer.createSpeechRecognizer(ctx) else null }
    DisposableEffect(Unit) { onDispose { recognizer?.destroy() } }

    fun start() {
        val rec = recognizer ?: return
        error = null; partial = ""
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }
        rec.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(p: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(r: Float) {}
            override fun onBufferReceived(b: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(b: Bundle) {
                partial = b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
            }
            override fun onEvent(t: Int, p: Bundle?) {}
            override fun onError(code: Int) {
                partial = ""
                if (listening) rec.startListening(intent)
            }
            override fun onResults(b: Bundle) {
                val text = b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                if (!text.isNullOrBlank()) transcript = (transcript + " " + text).trim()
                partial = ""
                if (listening) rec.startListening(intent)
            }
        })
        rec.startListening(intent)
        listening = true
    }
    fun stop() { listening = false; recognizer?.stopListening() }

    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) start() else error = "Allow microphone access to transcribe."
    }

    OutlinedTextField(
        value = if (listening && partial.isNotEmpty()) (transcript + " " + partial).trim() else transcript,
        onValueChange = { if (!listening) transcript = it },
        label = { Text("Transcript") },
        placeholder = { Text(if (listening) "Listening…" else "Record, or type/paste text to tidy up.") },
        modifier = Modifier.fillMaxWidth().heightIn(min = 160.dp),
        readOnly = listening,
    )
    error?.let { Text(it, color = HandyColors.Danger, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp)) }
    if (recognizer == null) Text("Speech recognition isn't available on this device — you can still paste and tidy text.", color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp))
    if (overQuota && !listening) Text("You've used today's ${Limits.FREE_AUDIO_PER_DAY} free recordings. Go Pro for unlimited.", style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))

    Spacer(Modifier.size(12.dp))
    HPrimaryButton(if (listening) "Stop" else "Record", enabled = recognizer != null && (!overQuota || listening), icon = if (listening) Icons.Outlined.Stop else Icons.Outlined.Mic, modifier = Modifier.fillMaxWidth()) {
        if (listening) stop()
        else {
            if (!Usage.use(ctx, "audiotext", Limits.FREE_AUDIO_PER_DAY)) return@HPrimaryButton
            if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) start()
            else permLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    if (transcript.isNotEmpty()) {
        Spacer(Modifier.size(12.dp))
        val chars = transcript.length
        val words = transcript.trim().split(Regex("\\s+")).count { it.isNotEmpty() }
        Text("$words words · $chars characters", color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall)
        Spacer(Modifier.size(8.dp))
        Text("Tidy up", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground, fontSize = 13.sp)
        Spacer(Modifier.size(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            HChip("UPPER", false) { transcript = transcript.uppercase() }
            HChip("lower", false) { transcript = transcript.lowercase() }
            HChip("Title Case", false) { transcript = titleCase(transcript) }
            HChip("Sentence", false) { transcript = sentenceCase(transcript) }
        }
        Spacer(Modifier.size(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            HChip("Trim spaces", false) { transcript = transcript.replace(Regex("[ \\t]+"), " ").replace(Regex(" *\\n *"), "\n").trim() }
            HChip("No line breaks", false) { transcript = transcript.replace(Regex("\\s*\\n\\s*"), " ").trim() }
        }
        Spacer(Modifier.size(12.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            HSecondaryButton("Copy", modifier = Modifier.weight(1f)) {
                (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("transcript", transcript))
                Toast.makeText(ctx, "Copied", Toast.LENGTH_SHORT).show()
            }
            HSecondaryButton("Share", modifier = Modifier.weight(1f)) { Share.text(ctx, transcript) }
            HSecondaryButton("Clear", modifier = Modifier.weight(1f)) { transcript = "" }
        }
    }
}

@Composable
private fun TrimPane(ctx: Context) {
    val scope = rememberCoroutineScope()
    var uri by remember { mutableStateOf<Uri?>(null) }
    var durationMs by remember { mutableStateOf(0L) }
    var range by remember { mutableStateOf(0f..0f) }
    var busy by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { u ->
        if (u == null) return@rememberLauncherForActivityResult
        uri = u; status = null
        val dur = audioDurationMs(ctx, u)
        durationMs = dur
        range = 0f..(dur.toFloat())
        if (dur <= 0L) status = "Couldn't read that file. Try an MP3, M4A, recording or video."
    }

    fun export() {
        val u = uri ?: return
        if (range.endInclusive - range.start < 500f) { status = "Pick at least half a second."; return }
        busy = true; status = null
        scope.launch {
            val out = withContext(Dispatchers.IO) {
                try {
                    val f = File(ctx.cacheDir, "clip_${System.currentTimeMillis()}.m4a")
                    trimAudio(ctx, u, (range.start * 1000).toLong(), (range.endInclusive * 1000).toLong(), f)
                    f
                } catch (e: Exception) { null }
            }
            busy = false
            if (out != null) { Share.file(ctx, out, "audio/mp4"); HandyHaptics.success(ctx) }
            else status = "Couldn't trim that file. Try an MP3, M4A, recording or video."
        }
    }

    Text("Import a recording or a video, then drag the handles to the part you want. The audio is copied losslessly — great for a ringtone or a shareable snippet.", color = Handy.palette.textSecondary, fontSize = 13.sp)
    Spacer(Modifier.size(14.dp))
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        HSecondaryButton("Choose audio", modifier = Modifier.weight(1f)) { picker.launch("audio/*") }
        HSecondaryButton("Choose video", modifier = Modifier.weight(1f)) { picker.launch("video/*") }
    }

    if (uri != null && durationMs > 0L) {
        Spacer(Modifier.size(16.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(fmt(range.start.toLong()), fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onBackground)
            Text(fmt(range.endInclusive.toLong()), fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onBackground)
        }
        RangeSlider(value = range, onValueChange = { range = it }, valueRange = 0f..durationMs.toFloat())
        Text("Clip length  ${fmt((range.endInclusive - range.start).toLong())}", color = Handy.palette.textSecondary, fontSize = 13.sp)
        Spacer(Modifier.size(18.dp))
        HPrimaryButton(if (busy) "Trimming…" else "Export clip", modifier = Modifier.fillMaxWidth(), enabled = !busy) { export() }
    }
    status?.let { Spacer(Modifier.size(10.dp)); Text(it, color = HandyColors.Accent) }
}

// --- text helpers (from Text Tools) ---

private fun titleCase(s: String): String =
    s.split(" ").joinToString(" ") { w -> w.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() } }

private fun sentenceCase(s: String): String {
    val lower = s.lowercase()
    val sb = StringBuilder(lower.length)
    var capNext = true
    for (c in lower) {
        if (capNext && c.isLetter()) { sb.append(c.uppercaseChar()); capNext = false }
        else { sb.append(c); if (c == '.' || c == '!' || c == '?' || c == '\n') capNext = true }
    }
    return sb.toString()
}

// --- audio trim helpers (from Audio Cutter; works on audio containers and the audio track of video) ---

private fun fmt(ms: Long): String { val s = ms / 1000; return "%d:%02d".format(s / 60, s % 60) }

private fun audioDurationMs(ctx: Context, uri: Uri): Long {
    val mmr = MediaMetadataRetriever()
    return try {
        mmr.setDataSource(ctx, uri)
        mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
    } catch (e: Exception) { 0L } finally {
        try { mmr.release() } catch (_: Exception) {}
    }
}

private fun trimAudio(ctx: Context, uri: Uri, startMs: Long, endMs: Long, out: File) {
    val startUs = startMs * 1000
    val endUs = endMs * 1000
    val extractor = MediaExtractor()
    extractor.setDataSource(ctx, uri, null)
    var audioTrack = -1
    var format: MediaFormat? = null
    for (i in 0 until extractor.trackCount) {
        val f = extractor.getTrackFormat(i)
        if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) { audioTrack = i; format = f; break }
    }
    if (audioTrack < 0 || format == null) { extractor.release(); throw IllegalStateException("no audio track") }
    extractor.selectTrack(audioTrack)

    val muxer = MediaMuxer(out.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    val outTrack = muxer.addTrack(format)
    muxer.start()

    val buffer = ByteBuffer.allocate(256 * 1024)
    val bufferInfo = android.media.MediaCodec.BufferInfo()
    extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
    try {
        while (true) {
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) break
            val ptUs = extractor.sampleTime
            if (ptUs > endUs) break
            if (ptUs >= startUs) {
                bufferInfo.offset = 0
                bufferInfo.size = sampleSize
                bufferInfo.presentationTimeUs = ptUs - startUs
                bufferInfo.flags = extractor.sampleFlags
                muxer.writeSampleData(outTrack, buffer, bufferInfo)
            }
            if (!extractor.advance()) break
        }
    } finally {
        try { muxer.stop() } catch (_: Exception) {}
        muxer.release()
        extractor.release()
    }
}
