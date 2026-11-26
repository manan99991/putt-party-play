package com.handytools.app.tools.studio

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
 * Video Effects (the iPhone's, on Android): pick or film a video, choose its look, light, motion, texture and words,
 * watch a preview of the first seconds, then save the whole video and share it.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun VideoEffectsScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var source by remember { mutableStateOf<Uri?>(null) }
    var recipe by remember { mutableStateOf(VideoEffects.Recipe()) }
    var tab by remember { mutableStateOf("look") }
    var preview by remember { mutableStateOf<Pair<VideoEffects.Recipe, File>?>(null) }
    var saved by remember { mutableStateOf<File?>(null) }
    var working by remember { mutableStateOf<Job?>(null) }
    var progress by remember { mutableStateOf(0.0) }
    var error by remember { mutableStateOf<String?>(null) }

    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { it?.let { u -> source = u; preview = null; saved = null } }
    val record = rememberCamera(video = true) { source = it; preview = null; saved = null }

    fun run(full: Boolean) {
        val u = source ?: return
        error = null; progress = 0.0
        val r = recipe
        working = scope.launch {
            val out = VideoEffects.make(ctx, u, r, preview = !full) { p -> progress = p }
            working = null
            when {
                out == null -> error = "Couldn't put the effects on this video — try another."
                full -> saved = out
                else -> preview = r to out
            }
        }
    }

    PowerToolPage("videofx") {
        val u = source
        if (u == null) {
            Text(I18n.t("Pick a video and give it a look, light, motion and words."), style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
            Spacer(Modifier.height(HandyTokens.Space12))
            HPrimaryButton(I18n.t("Choose a video"), Modifier.testTag("fx-pick")) { pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly)) }
            Spacer(Modifier.height(HandyTokens.Space8))
            HSecondaryButton(I18n.t("Record one now"), Modifier.testTag("tool-record")) { record() }
            return@PowerToolPage
        }
        val done = saved
        if (done != null) {
            ResultPlayer(done, "fx-result")
            Spacer(Modifier.height(HandyTokens.Space12))
            HPrimaryButton(I18n.t("Share"), Modifier.testTag("fx-share")) { Share.file(ctx, done, "video/mp4") }
            HTextButton(I18n.t("Change the effects"), Modifier.fillMaxWidth()) { saved = null }
            return@PowerToolPage
        }

        // The preview of the first seconds, once made for exactly these choices.
        preview?.takeIf { it.first == recipe }?.let { (_, f) -> ResultPlayer(f, "fx-preview"); Spacer(Modifier.height(HandyTokens.Space8)) }

        FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf("look" to "Look", "light" to "Light", "motion" to "Motion", "texture" to "Texture", "background" to "Background", "funny" to "Funny", "words" to "Words").forEach { (id, name) ->
                Box(Modifier.testTag("fx-tab-$id").semantics { selected = tab == id }) { HChip(I18n.t(name), selected = tab == id) { tab = id } }
            }
        }
        Spacer(Modifier.height(HandyTokens.Space12))
        if (tab == "words") {
            OutlinedTextField(recipe.words, { recipe = recipe.copy(words = it) }, Modifier.fillMaxWidth().testTag("fx-words"), singleLine = true,
                label = { Text(I18n.t("Words on the video (optional)")) })
            Spacer(Modifier.height(HandyTokens.Space8))
            FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                VideoEffects.wordStyles.forEach { c -> HChip("${c.emoji} ${I18n.t(c.name)}", selected = recipe.wordStyle == c.id) { recipe = recipe.copy(wordStyle = c.id) } }
            }
        } else {
            val (choices, now) = when (tab) {
                "light" -> VideoEffects.lights to recipe.light
                "motion" -> VideoEffects.motions to recipe.motion
                "texture" -> VideoEffects.textures to recipe.texture
                "background" -> VideoEffects.backgrounds to recipe.background
                "funny" -> VideoEffects.funnies to recipe.funny
                else -> VideoEffects.looks to recipe.look
            }
            FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                choices.forEach { c ->
                    Box(Modifier.testTag("fx-$tab-${c.id}")) {
                        HChip("${c.emoji} ${I18n.t(c.name)}", selected = now == c.id) {
                            recipe = when (tab) {
                                "light" -> recipe.copy(light = c.id); "motion" -> recipe.copy(motion = c.id)
                                "texture" -> recipe.copy(texture = c.id); "background" -> recipe.copy(background = c.id)
                                "funny" -> recipe.copy(funny = c.id); else -> recipe.copy(look = c.id)
                            }
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(HandyTokens.Space16))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
            HSecondaryButton(I18n.t("Preview"), Modifier.weight(1f).testTag("fx-preview-make"), enabled = working == null && !recipe.isPlain && preview?.first != recipe) { run(false) }
            HPrimaryButton(I18n.t("Save the video"), Modifier.weight(1f).testTag("fx-save"), enabled = working == null && !recipe.isPlain) { run(true) }
        }
        if (working != null) {
            Spacer(Modifier.height(HandyTokens.Space8))
            LinearProgressIndicator(progress = { progress.toFloat().coerceIn(0f, 1f) }, modifier = Modifier.fillMaxWidth())
            Text(I18n.t("Putting the effects on…"), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            HTextButton(I18n.t("Stop"), Modifier.fillMaxWidth()) { working?.cancel(); working = null }
        }
        HTextButton(I18n.t("Choose another video"), Modifier.fillMaxWidth()) { source = null; preview = null }
        error?.let { Spacer(Modifier.height(HandyTokens.Space8)); Text(I18n.t(it), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error) }
    }
}
