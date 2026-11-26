package com.handytools.app.tools.studio

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.handytools.app.I18n
import com.handytools.app.tools.Share
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HTextButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.PowerToolPage
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.File

/**
 * Beat Reel (the iPhone's, on Android): pick or film a few clips and photos, pick the music's style and the length,
 * and Tenzy cuts a tall reel to the beat. Watch it, then share it.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun BeatReelScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val pieces = remember { mutableStateListOf<ClipPiece>() }
    var style by remember { mutableStateOf("upbeat") }
    var length by remember { mutableStateOf<Double?>(null) }
    var working by remember { mutableStateOf<Job?>(null) }
    var progress by remember { mutableStateOf(0.0) }
    var result by remember { mutableStateOf<File?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    fun make() {
        error = null; progress = 0.0
        val uris = pieces.map { it.uri }
        working = scope.launch {
            val out = Reels.make(ctx, uris, style, length) { p -> progress = p }
            working = null
            if (out == null) error = "Couldn't make the reel — try other clips." else result = out
        }
    }

    PowerToolPage("beatreel") {
        val done = result
        if (done != null) {
            ResultPlayer(done, "reel-result")
            Spacer(Modifier.height(HandyTokens.Space12))
            HPrimaryButton(I18n.t("Share"), Modifier.testTag("reel-share")) { Share.file(ctx, done, "video/mp4") }
            HTextButton(I18n.t("Change the music or length"), Modifier.fillMaxWidth()) { result = null }
            return@PowerToolPage
        }
        ClipPicker(pieces, "reel", enabled = working == null)
        if (pieces.isNotEmpty()) {
            Spacer(Modifier.height(HandyTokens.Space16))
            Text(I18n.t("The music"), style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(HandyTokens.Space8))
            FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Synth.styles.forEach { s ->
                    Box(Modifier.testTag("reel-style-${s.id}").semantics { selected = style == s.id }) {
                        HChip("${s.emoji} ${I18n.t(s.name)} · ${s.bpm.toInt()} BPM", selected = style == s.id) { style = s.id }
                    }
                }
            }
            Spacer(Modifier.height(HandyTokens.Space12))
            Text(I18n.t("Length"), style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.height(6.dp))
            FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("Auto" to null, "15 s" to 15.0, "30 s" to 30.0, "60 s" to 60.0).forEach { (label, s) ->
                    HChip(I18n.t(label), selected = length == s) { length = s }
                }
            }
            Spacer(Modifier.height(HandyTokens.Space16))
            HPrimaryButton(I18n.t("Make my reel"), Modifier.testTag("reel-make"), enabled = working == null) { make() }
            if (working != null) {
                Spacer(Modifier.height(HandyTokens.Space8))
                LinearProgressIndicator(progress = { progress.toFloat().coerceIn(0f, 1f) }, modifier = Modifier.fillMaxWidth())
                Text(I18n.t("Cutting to the beat…"), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                HTextButton(I18n.t("Stop"), Modifier.fillMaxWidth()) { working?.cancel(); working = null }
            }
        }
        error?.let { Spacer(Modifier.height(HandyTokens.Space8)); Text(I18n.t(it), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error) }
    }
}
