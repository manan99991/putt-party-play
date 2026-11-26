package com.handytools.app.tools.studio

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.I18n
import com.handytools.app.tools.Share
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HTextButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyTokens
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.rememberCamera
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.File

/**
 * Funny Moments (the iPhone's, on Android): pick or record a video, pick the joke, and Tenzy finds the moment (the
 * loudest laugh or shout) and puts it in with its sound. The moment can be moved; the freeze's words can be changed.
 */
@Composable
fun FunnyScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var source by remember { mutableStateOf<Uri?>(null) }
    var duration by remember { mutableStateOf(0.0) }
    var found by remember { mutableStateOf<Double?>(null) }
    var moment by remember { mutableStateOf<Double?>(null) }
    var kind by remember { mutableStateOf("scratch") }
    var words by remember { mutableStateOf(FunnyPlan.kind("scratch").words) }
    var loading by remember { mutableStateOf(false) }
    var working by remember { mutableStateOf<Job?>(null) }
    var progress by remember { mutableStateOf(0.0) }
    var result by remember { mutableStateOf<File?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val k = FunnyPlan.kind(kind)

    fun use(u: Uri) {
        loading = true; error = null; result = null; moment = null
        scope.launch {
            val m = FunnyMaker.findMoment(ctx, u, "scratch")
            loading = false
            if (m == null) { error = "That video didn't load — try another."; return@launch }
            source = u; found = m.first; duration = m.second
        }
    }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { it?.let { u -> use(u) } }
    val record = rememberCamera(video = true) { use(it) }

    fun make() {
        val u = source ?: return
        error = null; progress = 0.0
        val at = if (kind == "rimshot") null else (moment ?: found)
        working = scope.launch {
            val out = FunnyMaker.make(ctx, u, kind, at, words) { p -> progress = p }
            working = null
            if (out == null) error = "Couldn't make it — try another moment or video." else result = out
        }
    }

    PowerToolPage("funny") {
        val done = result
        when {
            done != null -> {
                ResultPlayer(done, "funny-result")
                Spacer(Modifier.height(HandyTokens.Space12))
                HPrimaryButton(I18n.t("Share"), Modifier.testTag("funny-share")) { Share.file(ctx, done, "video/mp4") }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                    HSecondaryButton(I18n.t("Try another joke"), Modifier.weight(1f)) { result = null }
                    HSecondaryButton(I18n.t("Another video"), Modifier.weight(1f)) { result = null; source = null }
                }
            }
            source == null -> {
                Text(I18n.t("Pick a video with a moment worth a laugh. Tenzy finds it for you."), style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
                Spacer(Modifier.height(HandyTokens.Space12))
                HPrimaryButton(I18n.t("Choose a video"), Modifier.testTag("funny-pick"), enabled = !loading) {
                    pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly))
                }
                Spacer(Modifier.height(HandyTokens.Space8))
                HSecondaryButton(I18n.t("Record one now"), Modifier.testTag("tool-record"), enabled = !loading) { record() }
                if (loading) { Spacer(Modifier.height(HandyTokens.Space8)); LinearProgressIndicator(Modifier.fillMaxWidth()); Text(I18n.t("Getting it ready…"), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary) }
            }
            else -> {
                Text(I18n.t("Which joke?"), style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(HandyTokens.Space8))
                FunnyPlan.kinds.chunked(2).forEach { row ->
                    Row(Modifier.fillMaxWidth().padding(bottom = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { c ->
                            val on = kind == c.id
                            HCard(Modifier.weight(1f).heightIn(min = 104.dp).clip(RoundedCornerShape(14.dp))
                                .border(if (on) 2.dp else 0.dp, if (on) Handy.palette.accent else androidx.compose.ui.graphics.Color.Transparent, RoundedCornerShape(14.dp))
                                .testTag("funny-kind-${c.id}").semantics { selected = on },
                                onClick = { kind = c.id; words = c.words; if (c.id == "rimshot") moment = null }) {
                                Column(Modifier.padding(10.dp)) {
                                    Text(c.emoji, fontSize = 26.sp)
                                    Text(I18n.t(c.name), style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                    Text(I18n.t(c.line), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, maxLines = 2)
                                }
                            }
                        }
                        repeat(2 - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
                if (kind != "rimshot" && duration > 1) {
                    val now = moment ?: found ?: duration * 0.6
                    HCard(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(HandyTokens.Space12)) {
                            Row(Modifier.fillMaxWidth()) {
                                Text(I18n.t("The moment"), Modifier.weight(1f), style = MaterialTheme.typography.titleSmall)
                                Text("%d:%04.1f".format((now / 60).toInt(), now % 60), style = MaterialTheme.typography.bodyMedium, color = Handy.palette.accent)
                            }
                            Slider(now.toFloat(), { moment = it.toDouble() }, Modifier.fillMaxWidth().testTag("funny-moment"), valueRange = 0f..(duration - 0.1).toFloat().coerceAtLeast(0.1f))
                            Text(I18n.t(if (moment == null) "Found for you: the loudest moment. Slide to move it." else "Your moment."), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                        }
                    }
                    Spacer(Modifier.height(HandyTokens.Space8))
                }
                if (k.freeze > 0 && kind != "rimshot") {
                    OutlinedTextField(words, { words = it }, Modifier.fillMaxWidth().testTag("funny-words"), singleLine = true,
                        label = { Text(I18n.t("Words on the freeze (optional)")) })
                    Spacer(Modifier.height(HandyTokens.Space8))
                }
                HPrimaryButton(I18n.t("Make it"), Modifier.testTag("funny-make"), enabled = working == null) { make() }
                if (working != null) {
                    Spacer(Modifier.height(HandyTokens.Space8))
                    LinearProgressIndicator(progress = { progress.toFloat().coerceIn(0f, 1f) }, modifier = Modifier.fillMaxWidth())
                    Text(I18n.t("Putting the joke in…"), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    HTextButton(I18n.t("Stop"), Modifier.fillMaxWidth()) { working?.cancel(); working = null }
                }
                HTextButton(I18n.t("Choose another video"), Modifier.fillMaxWidth()) { source = null; result = null }
            }
        }
        error?.let { Spacer(Modifier.height(HandyTokens.Space8)); Text(I18n.t(it), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error) }
    }
}
