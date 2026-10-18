package com.handytools.app.tools.translate

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions
import com.handytools.app.HandyApp
import com.handytools.app.Limits
import com.handytools.app.Usage
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.ToolHeader

private val LANGS = listOf(
    "es" to "Spanish", "fr" to "French", "de" to "German", "hi" to "Hindi", "zh" to "Chinese",
    "ja" to "Japanese", "ar" to "Arabic", "pt" to "Portuguese", "ru" to "Russian", "it" to "Italian"
)

/** On-device translation via ML Kit — downloads a small language pack once, then works offline. */
@Composable
fun TranslateScreen() {
    val ctx = LocalContext.current
    val premium by HandyApp.instance.billing.isPremium.collectAsState()
    var input by remember { mutableStateOf("") }
    var other by remember { mutableStateOf("es") }
    var enToX by remember { mutableStateOf(true) }
    var output by remember { mutableStateOf("") }
    var working by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val overQuota = !Usage.hasRoom(ctx, "translate", Limits.FREE_TRANSLATE_PER_DAY)

    fun translate() {
        if (input.isBlank()) return
        if (!Usage.use(ctx, "translate", Limits.FREE_TRANSLATE_PER_DAY)) return
        working = true; error = null; output = ""
        val src = if (enToX) "en" else other
        val tgt = if (enToX) other else "en"
        val opts = TranslatorOptions.Builder()
            .setSourceLanguage(TranslateLanguage.fromLanguageTag(src) ?: TranslateLanguage.ENGLISH)
            .setTargetLanguage(TranslateLanguage.fromLanguageTag(tgt) ?: TranslateLanguage.SPANISH)
            .build()
        val translator = Translation.getClient(opts)
        translator.downloadModelIfNeeded()
            .addOnSuccessListener {
                translator.translate(input)
                    .addOnSuccessListener { output = it; working = false; translator.close() }
                    .addOnFailureListener { error = "Couldn't translate that."; working = false; translator.close() }
            }
            .addOnFailureListener { error = "Couldn't download the language pack. Check your connection."; working = false; translator.close() }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Translate", "Any language, on your phone — works offline once downloaded.")
        Spacer(Modifier.size(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            HChip(if (enToX) "English → " + name(other) else name(other) + " → English", true) { enToX = !enToX }
        }
        Spacer(Modifier.size(8.dp))
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            LANGS.forEach { (code, nm) -> HChip(nm, other == code) { other = code } }
        }
        Spacer(Modifier.size(12.dp))
        OutlinedTextField(input, { input = it }, label = { Text("Text to translate") }, modifier = Modifier.fillMaxWidth(), minLines = 3)
        if (overQuota) Text("You've used today's ${Limits.FREE_TRANSLATE_PER_DAY} free translations. Go Pro for unlimited.",
            style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 8.dp))
        Spacer(Modifier.size(12.dp))
        HPrimaryButton(if (working) "Translating…" else "Translate", enabled = !working && !overQuota && input.isNotBlank(), modifier = Modifier.fillMaxWidth()) { translate() }
        error?.let { Text(it, color = HandyColors.Danger, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp)) }
        if (output.isNotEmpty()) {
            Spacer(Modifier.size(12.dp))
            Text(output, style = MaterialTheme.typography.bodyLarge, modifier = Modifier
                .fillMaxWidth().padding(4.dp))
        }
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

private fun name(code: String) = LANGS.firstOrNull { it.first == code }?.second ?: code
