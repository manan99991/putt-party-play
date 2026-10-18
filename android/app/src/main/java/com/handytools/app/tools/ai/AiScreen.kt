package com.handytools.app.tools.ai

import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.ToolHeader

private enum class Kind { OCR, LABEL, GEN }
private data class Spec(val title: String, val subtitle: String, val kind: Kind, val action: String)

private fun spec(route: String): Spec = when (route) {
    "ai_extract" -> Spec("Extract to Data", "Receipt, card, poster → the text, pulled out.", Kind.OCR, "Pick a photo")
    "ai_ask" -> Spec("Ask a Screenshot", "Read the words off a confusing screen.", Kind.OCR, "Pick a screenshot")
    "ai_handwriting" -> Spec("Handwriting → Text", "Turn a photo of notes into text.", Kind.OCR, "Pick a photo")
    "ai_identify" -> Spec("Identify", "Point it at a plant, object, or landmark.", Kind.LABEL, "Pick a photo")
    "ai_describe" -> Spec("Describe Image", "A caption / alt-text for any photo.", Kind.LABEL, "Pick a photo")
    "ai_summarize" -> Spec("Summarize", "Long text in, the gist out.", Kind.GEN, "")
    "ai_rewrite" -> Spec("Rewrite & Tone", "Say it clearer, shorter, nicer.", Kind.GEN, "")
    "ai_proofread" -> Spec("Proofread", "Catch typos before you send.", Kind.GEN, "")
    "ai_reply" -> Spec("Draft a Reply", "Paste a message, get a reply.", Kind.GEN, "")
    else -> Spec("Make a Sticker", "Describe it, your phone draws it.", Kind.GEN, "")
}

/** One screen drives all 10 AI tools. Vision tools (OCR / labeling) run on-device on every phone;
 *  the generative writing tools need on-device Gemini Nano and show a graceful fallback elsewhere. */
@Composable
fun AiScreen(route: String) {
    val s = spec(route)
    val ctx = LocalContext.current
    var output by remember { mutableStateOf("") }
    var working by remember { mutableStateOf(false) }
    val overQuota = !Usage.hasRoom(ctx, "ai", Limits.FREE_AI_PER_DAY)

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        if (!Usage.use(ctx, "ai", Limits.FREE_AI_PER_DAY)) return@rememberLauncherForActivityResult
        val bmp = ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) } ?: return@rememberLauncherForActivityResult
        working = true; output = ""
        val image = InputImage.fromBitmap(bmp, 0)
        if (s.kind == Kind.OCR) {
            TextRecognition.getClient(TextRecognizerOptions.DEFAULT).process(image)
                .addOnSuccessListener { working = false; output = it.text.ifBlank { "No text found in that image." } }
                .addOnFailureListener { working = false; output = "Couldn't read that image." }
        } else {
            ImageLabeling.getClient(ImageLabelerOptions.DEFAULT).process(image)
                .addOnSuccessListener { labels ->
                    working = false
                    val top = labels.sortedByDescending { it.confidence }.take(5).map { it.text }
                    output = if (top.isEmpty()) "Couldn't recognize what's in that image."
                    else if (route == "ai_describe") "A photo of ${top.joinToString(", ")}."
                    else top.joinToString(", ")
                }
                .addOnFailureListener { working = false; output = "Couldn't recognize that image." }
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader(s.title, s.subtitle)
        Spacer(Modifier.size(16.dp))
        when (s.kind) {
            Kind.OCR, Kind.LABEL -> {
                HPrimaryButton(s.action, enabled = !working && !overQuota, modifier = Modifier.fillMaxWidth()) {
                    picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                }
                if (overQuota) Text("You've used today's ${Limits.FREE_AI_PER_DAY} free AI actions. Go Pro for unlimited.",
                    style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))
            }
            Kind.GEN -> {
                HCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text("Needs on-device Gemini", style = MaterialTheme.typography.titleMedium)
                        Spacer(Modifier.size(6.dp))
                        Text("This writing tool runs on phones with on-device Gemini Nano (Pixel 9, Galaxy S24+ and newer). On this phone it isn't available yet — it stays free and private when it is. ${s.subtitle}",
                            style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
                    }
                }
            }
        }
        if (working) { Spacer(Modifier.size(12.dp)); Text("Working…", color = Handy.palette.textSecondary) }
        if (output.isNotEmpty()) {
            Spacer(Modifier.size(12.dp))
            Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState())) {
                Text(output, modifier = Modifier.fillMaxWidth())
            }
            Spacer(Modifier.size(8.dp))
            HSecondaryButton("Share", modifier = Modifier.fillMaxWidth()) { Share.text(ctx, output) }
        } else {
            Spacer(Modifier.weight(1f))
        }
        BannerAd()
    }
}
