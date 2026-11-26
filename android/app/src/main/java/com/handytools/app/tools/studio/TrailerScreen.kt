package com.handytools.app.tools.studio

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import com.handytools.app.I18n
import com.handytools.app.tools.Share
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HTextButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.PowerToolPage
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.File

/**
 * Movie Trailer (the iPhone's, on Android): pick or film a few clips and photos, name the film, change the narrator's
 * three lines if you like, and Tenzy makes a half-minute trailer. Watch it, then share it.
 */
@Composable
fun TrailerScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val pieces = remember { mutableStateListOf<ClipPiece>() }
    val defaults = remember { TrailerMaker.defaultLines() }
    var title by remember { mutableStateOf("") }
    val lines = remember { mutableStateListOf(*defaults.toTypedArray()) }
    var working by remember { mutableStateOf<Job?>(null) }
    var progress by remember { mutableStateOf(0.0) }
    var result by remember { mutableStateOf<File?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    fun make() {
        error = null; progress = 0.0
        val uris = pieces.map { it.uri }; val name = title; val said = lines.toList()
        working = scope.launch {
            val out = TrailerMaker.make(ctx, uris, name, said) { p -> progress = p }
            working = null
            if (out == null) error = "Couldn't make the trailer — try other clips." else result = out
        }
    }

    PowerToolPage("trailer") {
        val done = result
        if (done != null) {
            ResultPlayer(done, "trailer-result")
            Spacer(Modifier.height(HandyTokens.Space12))
            HPrimaryButton(I18n.t("Share"), Modifier.testTag("trailer-share")) { Share.file(ctx, done, "video/mp4") }
            HTextButton(I18n.t("Change the title or lines"), Modifier.fillMaxWidth()) { result = null }
            return@PowerToolPage
        }
        ClipPicker(pieces, "trailer", enabled = working == null)
        if (pieces.isNotEmpty()) {
            Spacer(Modifier.height(HandyTokens.Space16))
            Text(I18n.t("The film's name"), style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(HandyTokens.Space8))
            OutlinedTextField(title, { title = it }, Modifier.fillMaxWidth().testTag("trailer-title"), singleLine = true,
                placeholder = { Text(I18n.t("The Adventure")) })
            Spacer(Modifier.height(HandyTokens.Space16))
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(I18n.t("What the narrator says"), Modifier.weight(1f), style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (lines.toList() != defaults) HTextButton(I18n.t("Reset")) { lines.clear(); lines.addAll(defaults) }
            }
            Spacer(Modifier.height(HandyTokens.Space8))
            Column(verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                lines.indices.forEach { i ->
                    OutlinedTextField(lines[i], { lines[i] = it }, Modifier.fillMaxWidth().testTag("trailer-line-${i + 1}"), singleLine = true,
                        placeholder = { Text(defaults[i]) })
                }
            }
            Spacer(Modifier.height(HandyTokens.Space16))
            HPrimaryButton(I18n.t("Make my trailer"), Modifier.testTag("trailer-make"), enabled = working == null) { make() }
            if (working != null) {
                Spacer(Modifier.height(HandyTokens.Space8))
                LinearProgressIndicator(progress = { progress.toFloat().coerceIn(0f, 1f) }, modifier = Modifier.fillMaxWidth())
                Text(I18n.t("Making your trailer…"), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                HTextButton(I18n.t("Stop"), Modifier.fillMaxWidth()) { working?.cancel(); working = null }
            }
        }
        error?.let { Spacer(Modifier.height(HandyTokens.Space8)); Text(I18n.t(it), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error) }
    }
}
