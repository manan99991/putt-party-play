package com.handytools.app.tools.texttools

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.ToolHeader

@Composable
fun TextToolsScreen() {
    val ctx = LocalContext.current
    var text by remember { mutableStateOf("") }

    val chars = text.length
    val words = text.trim().split(Regex("\\s+")).count { it.isNotEmpty() }
    val lines = if (text.isEmpty()) 0 else text.split("\n").size

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Text Tools", "Paste messy text and tidy it up — fix the case, strip extra spaces, or flatten broken line breaks into one clean paragraph.")
        Spacer(Modifier.size(12.dp))

        OutlinedTextField(
            value = text,
            onValueChange = { text = it },
            label = { Text("Your text") },
            modifier = Modifier.fillMaxWidth().weight(1f)
        )
        Spacer(Modifier.size(8.dp))
        Text("$words words · $chars characters · $lines lines", color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall)
        Spacer(Modifier.size(12.dp))

        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState())) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                HChip("UPPERCASE", false) { text = text.uppercase() }
                HChip("lowercase", false) { text = text.lowercase() }
                HChip("Title Case", false) { text = titleCase(text) }
            }
            Spacer(Modifier.size(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                HChip("Sentence case", false) { text = sentenceCase(text) }
                HChip("Trim spaces", false) { text = text.replace(Regex("[ \\t]+"), " ").replace(Regex(" *\\n *"), "\n").trim() }
            }
            Spacer(Modifier.size(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                HChip("No line breaks", false) { text = text.replace(Regex("\\s*\\n\\s*"), " ").trim() }
                HChip("Reverse", false) { text = text.reversed() }
                HChip("Clear", false) { text = "" }
            }
        }

        Spacer(Modifier.size(10.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            HSecondaryButton("Copy", modifier = Modifier.weight(1f)) {
                val cb = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                cb.setPrimaryClip(ClipData.newPlainText("text", text))
                Toast.makeText(ctx, "Copied", Toast.LENGTH_SHORT).show()
            }
            HSecondaryButton("Share", modifier = Modifier.weight(1f)) { Share.text(ctx, text) }
        }
        BannerAd()
    }
}

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
