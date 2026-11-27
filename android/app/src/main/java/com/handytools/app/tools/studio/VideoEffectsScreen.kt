package com.handytools.app.tools.studio

import android.content.Intent
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
import androidx.compose.material3.Slider
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
import com.handytools.app.tools.autoruns.ReadyToPost
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
 * Video Studio (the iPhone's, on Android; it was Video Effects): pick or film a video, then faces and bodies made funny
 * or beautiful, what's behind the person (or their own photo), the music under it (Tenzy's own, or their own song),
 * a look, light, motion and words — watch a preview of the first seconds, save the whole video, and share it or make
 * it tall for TikTok, Reels and Shorts.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun VideoEffectsScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var source by remember { mutableStateOf<Uri?>(null) }
    var recipe by remember { mutableStateOf(VideoEffects.Recipe()) }
    var tab by remember { mutableStateOf("faces") }
    var preview by remember { mutableStateOf<Pair<VideoEffects.Recipe, File>?>(null) }
    var saved by remember { mutableStateOf<File?>(null) }
    var tall by remember { mutableStateOf<File?>(null) }
    var keptAt by remember { mutableStateOf<Uri?>(null) }
    var working by remember { mutableStateOf<Job?>(null) }
    var progress by remember { mutableStateOf(0.0) }
    var error by remember { mutableStateOf<String?>(null) }
    var songName by remember { mutableStateOf<String?>(null) }

    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { it?.let { u -> source = u; preview = null; saved = null } }
    val record = rememberCamera(video = true) { source = it; preview = null; saved = null }
    val pickPhoto = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) {
        it?.let { u -> recipe = recipe.copy(background = "photo", backdrop = u.toString()) }
    }
    val pickSong = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { u ->
        if (u != null) {
            runCatching { ctx.contentResolver.takePersistableUriPermission(u, Intent.FLAG_GRANT_READ_URI_PERMISSION) }
            songName = u.lastPathSegment?.substringAfterLast('/')?.substringBeforeLast('.')
            recipe = recipe.copy(music = "file", song = u.toString())
        }
    }

    fun run(full: Boolean) {
        val u = source ?: return
        error = null; progress = 0.0
        val r = recipe
        working = scope.launch {
            val out = VideoEffects.make(ctx, u, r, preview = !full, progress = { p -> progress = p })
            working = null
            VideoEffects.lastSoundProblem?.let { error = it }
            when {
                out == null -> error = "Couldn't put the effects on this video — try another."
                full -> { saved = out; tall = null; keptAt = null }
                else -> preview = r to out
            }
        }
    }

    PowerToolPage("videofx") {
        val u = source
        if (u == null) {
            Text(I18n.t("Funny faces, a new background, music, looks and words — then save it or post it anywhere."),
                style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
            Spacer(Modifier.height(HandyTokens.Space12))
            HPrimaryButton(I18n.t("Choose a video"), Modifier.testTag("fx-pick")) { pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly)) }
            Spacer(Modifier.height(HandyTokens.Space8))
            HSecondaryButton(I18n.t("Record one now"), Modifier.testTag("tool-record")) { record() }
            return@PowerToolPage
        }
        val done = saved
        if (done != null) {
            ResultPlayer(tall ?: done, "fx-result")
            Spacer(Modifier.height(HandyTokens.Space12))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                HPrimaryButton(I18n.t("Share"), Modifier.weight(1f).testTag("fx-share")) { Share.file(ctx, tall ?: done, "video/mp4") }
                HSecondaryButton(I18n.t(if (keptAt == null) "Save to videos" else "Saved to your videos"), Modifier.weight(1f).testTag("fx-keep"), enabled = keptAt == null) {
                    keptAt = ReadyToPost.saveVideo(ctx, tall ?: done, "Tenzy video ${System.currentTimeMillis()}.mp4", System.currentTimeMillis())
                    if (keptAt == null) error = "Couldn't save it to your videos — try Share instead."
                }
            }
            Spacer(Modifier.height(HandyTokens.Space12))
            Text(I18n.t("Post it"), style = MaterialTheme.typography.titleMedium)
            if (tall == null) {
                Text(I18n.t("TikTok, Reels and Shorts want it tall: Tenzy fits the whole video in 9:16, then you share it straight to the app."),
                    style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                Spacer(Modifier.height(HandyTokens.Space8))
                HSecondaryButton(I18n.t("Make it tall for TikTok, Reels, Shorts"), Modifier.fillMaxWidth().testTag("fx-tall"), enabled = working == null) {
                    error = null; progress = 0.0
                    working = scope.launch {
                        val out = ReadyToPost.make(ctx, Uri.fromFile(done), look = "none") { p -> progress = p }
                        working = null
                        if (out == null) error = "Couldn't make it tall — share it as it is." else { tall = out; keptAt = null }
                    }
                }
            } else {
                Text(I18n.t("Tall 9:16 — tap Share and pick TikTok, Instagram or YouTube."), style = MaterialTheme.typography.bodySmall,
                    color = Handy.palette.textSecondary, modifier = Modifier.testTag("fx-tall-ready"))
            }
            if (working != null) {
                LinearProgressIndicator(progress = { progress.toFloat().coerceIn(0f, 1f) }, modifier = Modifier.fillMaxWidth())
            }
            HTextButton(I18n.t("Change the video"), Modifier.fillMaxWidth()) { saved = null; tall = null; keptAt = null }
            error?.let { Text(I18n.t(it), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error) }
            return@PowerToolPage
        }

        // The preview of the first seconds, once made for exactly these choices.
        preview?.takeIf { it.first == recipe }?.let { (_, f) -> ResultPlayer(f, "fx-preview"); Spacer(Modifier.height(HandyTokens.Space8)) }

        Text("${I18n.t("How much")}: ${I18n.t(strength(recipe.amount))}", style = MaterialTheme.typography.bodyMedium)
        Slider(recipe.amount, { recipe = recipe.copy(amount = it) }, Modifier.fillMaxWidth().testTag("fx-amount"))

        val tabs = listOf("faces" to "Faces", "background" to "Background", "music" to "Music", "look" to "Look", "light" to "Light",
            "motion" to "Motion", "texture" to "Texture", "words" to "Words")
        FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            tabs.forEach { (id, name) -> Box(Modifier.testTag("fx-tab-$id").semantics { selected = tab == id }) { HChip(I18n.t(name), selected = tab == id) { tab = id } } }
        }
        Spacer(Modifier.height(HandyTokens.Space12))
        when (tab) {
            "faces" -> {
                FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(Modifier.testTag("fx-funny-none")) { HChip("⚪️ ${I18n.t("Off")}", selected = recipe.funny == "none") { recipe = recipe.copy(funny = "none") } }
                }
                FaceFun.Group.values().forEach { g ->
                    Spacer(Modifier.height(HandyTokens.Space8))
                    Text(I18n.t(g.title), style = MaterialTheme.typography.titleSmall)
                    FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        FaceFun.effects.filter { it.group == g }.forEach { e ->
                            Box(Modifier.testTag("fx-funny-${e.id}")) { HChip("${e.emoji} ${I18n.t(e.name)}", selected = recipe.funny == e.id) { recipe = recipe.copy(funny = e.id) } }
                        }
                    }
                }
                Spacer(Modifier.height(HandyTokens.Space8))
                Text(I18n.t("Tenzy finds every face on every frame, right on your phone. \"How much\" takes each one from gentle to wild."),
                    style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            }
            "background" -> {
                FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    VideoEffects.backgrounds.forEach { c ->
                        Box(Modifier.testTag("fx-background-${c.id}")) {
                            HChip("${c.emoji} ${I18n.t(c.name)}", selected = recipe.background == c.id) {
                                if (c.id == "photo") pickPhoto.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                                else recipe = recipe.copy(background = c.id)
                            }
                        }
                    }
                }
                Spacer(Modifier.height(HandyTokens.Space8))
                Text(I18n.t("Tenzy finds the person on every frame and changes only what's behind them."), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            }
            "music" -> {
                FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    VideoSound.choices.forEach { c ->
                        Box(Modifier.testTag("fx-music-${c.id.replace(':', '-')}")) { HChip("${c.emoji} ${I18n.t(c.name)}", selected = recipe.music == c.id) { recipe = recipe.copy(music = c.id) } }
                    }
                    Box(Modifier.testTag("fx-music-file")) {
                        HChip("🎵 ${songName ?: I18n.t("Your song")}", selected = recipe.music == "file") { pickSong.launch(arrayOf("audio/*")) }
                    }
                }
                if (recipe.music.startsWith("synth:") || recipe.music == "file") {
                    Spacer(Modifier.height(HandyTokens.Space8))
                    Text(I18n.t("Music and the video's own sound"), style = MaterialTheme.typography.bodyMedium)
                    Row(Modifier.fillMaxWidth()) {
                        Text(I18n.t("Music"), style = MaterialTheme.typography.bodySmall)
                        Slider(recipe.keep.toFloat(), { recipe = recipe.copy(keep = it.toDouble()) }, Modifier.weight(1f).testTag("fx-music-mix"))
                        Text(I18n.t("Video"), style = MaterialTheme.typography.bodySmall)
                    }
                }
                Spacer(Modifier.height(HandyTokens.Space8))
                Text(I18n.t(if (recipe.music == "file") "Your own song, from Files. Post it only where you have the right to use that music — apps can mute videos with music they recognise."
                            else "Tenzy makes this music on your phone. It's yours to post anywhere."),
                    style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            }
            "words" -> {
                OutlinedTextField(recipe.words, { recipe = recipe.copy(words = it) }, Modifier.fillMaxWidth().testTag("fx-words"), singleLine = true,
                    label = { Text(I18n.t("Words on the video (optional)")) })
                Spacer(Modifier.height(HandyTokens.Space8))
                FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    VideoEffects.wordStyles.forEach { c -> HChip("${c.emoji} ${I18n.t(c.name)}", selected = recipe.wordStyle == c.id) { recipe = recipe.copy(wordStyle = c.id) } }
                }
            }
            else -> {
                val (choices, now) = when (tab) {
                    "light" -> VideoEffects.lights to recipe.light
                    "motion" -> VideoEffects.motions to recipe.motion
                    "texture" -> VideoEffects.textures to recipe.texture
                    else -> VideoEffects.looks to recipe.look
                }
                FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    choices.forEach { c ->
                        Box(Modifier.testTag("fx-$tab-${c.id}")) {
                            HChip("${c.emoji} ${I18n.t(c.name)}", selected = now == c.id) {
                                recipe = when (tab) {
                                    "light" -> recipe.copy(light = c.id); "motion" -> recipe.copy(motion = c.id)
                                    "texture" -> recipe.copy(texture = c.id); else -> recipe.copy(look = c.id)
                                }
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

/** "How much" in words (the iPhone's). */
fun strength(a: Float): String = when {
    a < 0.15f -> "Barely there"; a < 0.4f -> "Subtle"; a < 0.7f -> "Just right"; a < 0.9f -> "Bold"; else -> "Wild"
}
