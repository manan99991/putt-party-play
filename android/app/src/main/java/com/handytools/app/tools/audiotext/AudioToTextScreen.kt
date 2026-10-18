package com.handytools.app.tools.audiotext

import android.Manifest
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.Stop
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import com.handytools.app.HandyApp
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.ToolHeader

/** Live voice-to-text via the device's on-device recognizer. */
@Composable
fun AudioToTextScreen() {
    val ctx = LocalContext.current
    val premium by HandyApp.instance.billing.isPremium.collectAsState()
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
                if (listening) rec.startListening(intent) // keep going through pauses
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

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Audio to Text", "Talk, and it writes it down — on your phone.")
        Spacer(Modifier.size(12.dp))
        Box(
            Modifier.fillMaxWidth().heightIn(min = 180.dp)
                .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(12.dp))
                .border(1.dp, Handy.palette.border, RoundedCornerShape(12.dp)).padding(12.dp)
        ) {
            val shown = (transcript + " " + partial).trim()
            if (shown.isEmpty()) Text(if (listening) "Listening…" else "Your transcript will appear here.", color = Handy.palette.textSecondary)
            else Text(shown, modifier = Modifier.verticalScroll(rememberScrollState()))
        }
        error?.let { Text(it, color = HandyColors.Danger, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp)) }
        if (recognizer == null) Text("Speech recognition isn't available on this device.", color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp))
        if (overQuota && !listening) Text("You've used today's ${Limits.FREE_AUDIO_PER_DAY} free recordings. Go Pro for unlimited.",
            style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))
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
            Spacer(Modifier.size(8.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                HSecondaryButton("Share", modifier = Modifier.weight(1f)) { Share.text(ctx, transcript) }
                HSecondaryButton("Clear", modifier = Modifier.weight(1f)) { transcript = "" }
            }
        }
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}
