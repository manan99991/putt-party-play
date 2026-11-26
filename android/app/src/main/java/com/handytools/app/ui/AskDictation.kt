package com.handytools.app.ui

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * The Home ask box's mic (the iPhone's): say what you want instead of typing it — the words fill the box as they're
 * heard, Stop keeps them. Only where the phone recognises speech on its own (Android 12+ with an on-device
 * recogniser), so no audio ever leaves it; elsewhere the mic isn't shown. Main thread only.
 */
class AskDictation(private val ctx: Context, private val onText: (String) -> Unit) {
    var running by mutableStateOf(false)
        private set
    private var rec: SpeechRecognizer? = null
    private val main = Handler(Looper.getMainLooper())

    val available: Boolean get() = Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(ctx)

    fun start() {
        if (Build.VERSION.SDK_INT < 31 || running) return
        val r = runCatching { SpeechRecognizer.createOnDeviceSpeechRecognizer(ctx) }.getOrNull() ?: return
        r.setRecognitionListener(object : RecognitionListener {
            private fun words(b: Bundle?) = b?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.takeIf { it.isNotBlank() }
            override fun onPartialResults(b: Bundle?) { words(b)?.let(onText) }
            override fun onResults(b: Bundle?) { words(b)?.let(onText); main.post { stop() } }
            override fun onError(error: Int) { main.post { stop() } }
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        rec = r; running = true
        runCatching { r.startListening(intent) }.onFailure { stop() }
    }

    fun stop() {
        val r = rec ?: run { running = false; return }
        rec = null; running = false
        runCatching { r.stopListening() }; runCatching { r.destroy() }
    }
}
