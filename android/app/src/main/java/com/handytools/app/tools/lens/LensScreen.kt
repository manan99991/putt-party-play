package com.handytools.app.tools.lens

import android.graphics.BitmapFactory
import android.net.Uri
import android.speech.tts.TextToSpeech
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.ToolHeader
import java.util.Locale

/** Lens — grab text from a photo or paste it, then listen to it read aloud or boil it down to the
 *  gist. Merges the old OCR + read-aloud idea into one. OCR + TTS + gist run on every phone. */
@Composable
fun LensScreen() {
    val ctx = LocalContext.current
    var text by remember { mutableStateOf(TextFieldValue("")) }
    var working by remember { mutableStateOf(false) }
    var gist by remember { mutableStateOf("") }
    var speaking by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    val tts = remember { mutableStateOf<TextToSpeech?>(null) }
    DisposableEffect(Unit) {
        val engine = TextToSpeech(ctx) { }
        tts.value = engine
        onDispose { engine.stop(); engine.shutdown() }
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        val bmp = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) } ?: return@rememberLauncherForActivityResult
        working = true; gist = ""; error = null
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS).process(InputImage.fromBitmap(bmp, 0))
            .addOnSuccessListener { working = false; text = TextFieldValue(it.text); if (it.text.isBlank()) error = "No readable text found in that image." }
            .addOnFailureListener { working = false; error = "Couldn't read text from that image. Try another photo." }
    }

    fun speak() {
        val engine = tts.value ?: return
        engine.setLanguage(Locale.getDefault())
        if (speaking) { engine.stop(); speaking = false }
        else { engine.speak(text.text, TextToSpeech.QUEUE_FLUSH, null, "lens"); speaking = true }
    }

    val hasText = text.text.trim().length >= 2

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Lens", "Grab text from a photo or paste it — then listen to it, or boil it down to the gist.")
        Spacer(Modifier.size(16.dp))

        HCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                BasicTextField(value = text, onValueChange = { text = it }, modifier = Modifier.fillMaxWidth(),
                    textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
                    decorationBox = { inner ->
                        if (text.text.isBlank()) Text("Paste text, or snap a photo below…", color = Handy.palette.textSecondary)
                        inner()
                    })
            }
        }
        Spacer(Modifier.size(8.dp))
        Row(Modifier.fillMaxWidth()) {
            HSecondaryButton("Photo", modifier = Modifier.fillMaxWidth()) {
                picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            }
        }
        if (working) { Spacer(Modifier.size(12.dp)); Text("Reading the text…", color = Handy.palette.textSecondary) }
        error?.let { Spacer(Modifier.size(12.dp)); Text(it, color = com.handytools.app.ui.HandyColors.Danger, style = MaterialTheme.typography.bodySmall) }

        if (hasText) {
            Spacer(Modifier.size(12.dp))
            Row(Modifier.fillMaxWidth()) {
                HPrimaryButton(if (speaking) "Stop" else "Listen", modifier = Modifier.fillMaxWidth()) { speak() }
            }
            Spacer(Modifier.size(8.dp))
            Row(Modifier.fillMaxWidth()) {
                HSecondaryButton("Gist", modifier = Modifier.fillMaxWidth()) { gist = LensEngine.gist(text.text) }
            }
            if (gist.isNotEmpty()) {
                Spacer(Modifier.size(12.dp))
                Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState())) {
                    HCard(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp)) {
                            Text(gist, style = MaterialTheme.typography.bodyLarge)
                            Spacer(Modifier.size(8.dp))
                            HSecondaryButton("Share") { Share.text(ctx, gist) }
                        }
                    }
                }
            } else {
                Spacer(Modifier.weight(1f))
            }
        } else {
            Spacer(Modifier.weight(1f))
        }
        Text("Plain-English rewriting needs on-device Gemini Nano (Pixel 9, Galaxy S24+). Listen and Gist work on every phone.",
            style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 8.dp))
        BannerAd()
    }
}
