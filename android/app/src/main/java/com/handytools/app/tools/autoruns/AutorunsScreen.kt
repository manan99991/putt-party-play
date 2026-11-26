package com.handytools.app.tools.autoruns

import android.Manifest
import android.app.TimePickerDialog
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.MediaStore
import android.text.format.DateFormat
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.handytools.app.I18n
import com.handytools.app.Permissions
import com.handytools.app.ui.BackArrow
import com.handytools.app.ui.ChipRow
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HTextButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyTokens
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Autoruns (the iPhone's My stuff › Set an autorun): each autorun Android does, in the iPhone's sections — a switch, when
 * it comes back, and Test run. A notification (or Test run) opens its run, which shows everything it made before
 * anything is saved or deleted.
 */
@Composable
fun AutorunsScreen() {
    val ctx = LocalContext.current
    var open by remember { mutableStateOf<SmartRuns.Kind?>(null) }
    var running by remember { mutableStateOf<SmartRuns.Kind?>(null) }
    val tapped = Autoruns.pending
    LaunchedEffect(tapped) { tapped?.let { id -> SmartRuns.Kind.of(id)?.let { running = it }; Autoruns.pending = null } }
    val r = running
    if (r != null) { AutorunRun(r) { running = null }; return }

    Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = HandyTokens.Gutter)) {
        BackArrow(Modifier.padding(top = HandyTokens.Space4))
        Text(I18n.t("Smart autoruns"), style = MaterialTheme.typography.headlineMedium)
        Text(I18n.t("Jobs Tenzy does for you at the end of the day"),
            style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
        Spacer(Modifier.height(HandyTokens.Space12))
        SmartRuns.Section.entries.forEach { section ->
            val kinds = Autoruns.available.filter { it.section == section }
            if (kinds.isEmpty()) return@forEach
            Text(I18n.t(section.title), Modifier.padding(top = HandyTokens.Space12, bottom = HandyTokens.Space8),
                style = MaterialTheme.typography.titleSmall, color = Handy.palette.textSecondary)
            kinds.forEach { k ->
                AutorunCard(k, expanded = open == k, onToggle = { open = if (open == k) null else k }, onTest = { running = k })
                Spacer(Modifier.height(HandyTokens.Space8))
            }
        }
        Spacer(Modifier.height(HandyTokens.Space24))
    }
}

private fun timeLabel(ctx: Context, h: Int, m: Int): String =
    LocalTime.of(h, m).format(DateTimeFormatter.ofPattern(if (DateFormat.is24HourFormat(ctx)) "HH:mm" else "h:mm a", Locale.getDefault()))

@Composable
private fun AutorunCard(k: SmartRuns.Kind, expanded: Boolean, onToggle: () -> Unit, onTest: () -> Unit) {
    val ctx = LocalContext.current
    var plan by remember { mutableStateOf(Autoruns.plan(ctx, k)) }
    fun set(p: SmartRuns.Plan) { plan = p; Autoruns.setPlan(ctx, k, p) }
    val notify = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { }
    HCard(Modifier.fillMaxWidth().testTag("autorun-${k.id}"), onClick = onToggle) {
        Column(Modifier.padding(HandyTokens.Space12), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(12.dp).background(Color(k.color), CircleShape))
                Spacer(Modifier.width(HandyTokens.Space8))
                Column(Modifier.weight(1f)) {
                    Text(I18n.t(k.title), style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    val times = plan.times.joinToString(" · ") { (h, m) -> timeLabel(ctx, h, m) }
                    Text(if (plan.on) times else I18n.t("Off"), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, maxLines = 1)
                }
                Switch(plan.on, { on ->
                    set(plan.copy(on = on))
                    if (on && !Permissions.canPostNotifications(ctx) && Build.VERSION.SDK_INT >= 33) notify.launch(Manifest.permission.POST_NOTIFICATIONS)
                }, Modifier.testTag("autorun-${k.id}-switch"))
            }
            if (expanded) {
                Text(I18n.t(k.line), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                ChipRow {
                    HChip(timeLabel(ctx, plan.hour, plan.minute), false) {
                        TimePickerDialog(ctx, { _, h, m -> set(plan.copy(hour = h, minute = m)) }, plan.hour, plan.minute, DateFormat.is24HourFormat(ctx)).show()
                    }
                    if (!k.weekly) {
                        HChip(I18n.t("Once a day"), !plan.twice) { set(plan.copy(twice = false)) }
                        HChip(I18n.t("Twice a day"), plan.twice) { set(plan.copy(twice = true)) }
                    }
                }
                if (k.weekly) {
                    val names = listOf("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
                    ChipRow { (1..7).forEach { d -> HChip(I18n.t(names[d - 1]), plan.weekday == d) { set(plan.copy(weekday = d)) } } }
                }
                HSecondaryButton(I18n.t("Test run"), Modifier.fillMaxWidth().testTag("autorun-${k.id}-test")) { onTest() }
            }
        }
    }
}

/** One autorun's run: does the work with a live progress bar, then shows what it made. */
@Composable
fun AutorunRun(k: SmartRuns.Kind, onClose: () -> Unit) {
    when (k) {
        SmartRuns.Kind.HEAVY_VIDEOS -> HeavyVideosRun(onClose)
        else -> LaunchedEffect(k) { onClose() }
    }
}

private fun canReadVideos(ctx: Context): Boolean = ContextCompat.checkSelfPermission(ctx,
    if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_VIDEO else Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED

@Composable
private fun HeavyVideosRun(onClose: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val k = SmartRuns.Kind.HEAVY_VIDEOS
    var allowed by remember { mutableStateOf(canReadVideos(ctx)) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> allowed = ok }
    var stage by remember { mutableStateOf("") }
    var progress by remember { mutableStateOf(0.0) }
    var finished by remember { mutableStateOf(false) }
    val ready = remember { mutableStateListOf<HeavyVideos.Smaller>() }
    val left = remember { mutableStateListOf<Pair<HeavyVideos.Item, String>>() }
    val savedUris = remember { mutableStateListOf<android.net.Uri>() }
    var done by remember { mutableStateOf<String?>(null) }
    var job by remember { mutableStateOf<Job?>(null) }
    val delete = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { res ->
        done = if (res.resultCode == android.app.Activity.RESULT_OK) I18n.t("Originals deleted.") else I18n.t("The originals were kept.")
    }

    LaunchedEffect(allowed) {
        if (!allowed) { ask.launch(if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_VIDEO else Manifest.permission.READ_EXTERNAL_STORAGE); return@LaunchedEffect }
        job = scope.launch {
            val now = System.currentTimeMillis()
            val window = Autoruns.windowFor(ctx, k, now)
            stage = I18n.t("Looking at today's videos…")
            val found = HeavyVideos.find(ctx, window)
            found.forEachIndexed { i, item ->
                stage = "${I18n.t("Making it smaller")} · ${i + 1} / ${found.size}"
                var why = ""
                val s = HeavyVideos.prepare(ctx, item, { p -> progress = (i + p) / found.size }) { why = it }
                if (s != null) ready += s else left += item to why
            }
            Autoruns.markRun(ctx, k, now); Autoruns.clearReady(ctx, k)
            finished = true
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = HandyTokens.Gutter),
        verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)) {
        HTextButton(I18n.t("‹ Back")) { job?.cancel(); onClose() }
        Text(I18n.t("Smaller videos"), style = MaterialTheme.typography.headlineMedium)
        if (!allowed) { Text(I18n.t("Tenzy needs to see your videos to find the heavy ones."), color = Handy.palette.textSecondary); return@Column }
        if (!finished) {
            Text(stage, style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
            LinearProgressIndicator(progress = { progress.toFloat().coerceIn(0f, 1f) }, modifier = Modifier.fillMaxWidth().testTag("autorun-progress"))
            return@Column
        }
        if (ready.isNotEmpty()) {
            Text("${I18n.t("Saves")} ${HeavyVideos.human(ready.sumOf { it.saving })} — ${I18n.t("same size picture, same frame rate, checked frame by frame.")}",
                style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.testTag("smartvideos-total"))
        }
        done?.let { Text(it, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary) }
        if (ready.isEmpty() && left.isEmpty()) Text(I18n.t("Nothing heavy today — every video is already a sensible size."), color = Handy.palette.textSecondary)
        ready.forEach { s ->
            HCard(Modifier.fillMaxWidth().testTag("smartvideo-row")) {
                Column(Modifier.padding(HandyTokens.Space12), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(s.item.name, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text("${HeavyVideos.human(s.item.bytes)} → ${HeavyVideos.human(s.bytes)}", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(I18n.t("Looks the same — 7 frames checked"), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        left.forEach { (item, why) ->
            Text("${item.name}: ${I18n.t(why)}", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
        if (ready.isNotEmpty() && savedUris.isEmpty()) {
            HPrimaryButton("${I18n.t("Save")} ${ready.size} ${I18n.t(if (ready.size == 1) "smaller copy" else "smaller copies")}", Modifier.fillMaxWidth().testTag("smartvideos-save")) {
                ready.forEach { s -> HeavyVideos.save(ctx, s)?.let { savedUris += it } }
                done = "${savedUris.size} ${I18n.t(if (savedUris.size == 1) "smaller copy saved to your videos, with its original date." else "smaller copies saved to your videos, with their original dates.")}"
            }
        }
        if (savedUris.isNotEmpty() && Build.VERSION.SDK_INT >= 30) {
            HSecondaryButton("${I18n.t("Delete the")} ${ready.size} ${I18n.t(if (ready.size == 1) "original" else "originals")} · ${I18n.t("frees")} ${HeavyVideos.human(ready.sumOf { it.saving })}",
                Modifier.fillMaxWidth().testTag("smartvideos-delete")) {
                runCatching { MediaStore.createDeleteRequest(ctx.contentResolver, ready.map { it.item.uri }) }.getOrNull()?.let { pi ->
                    delete.launch(IntentSenderRequest.Builder(pi.intentSender).build())
                }
            }
            Text(I18n.t("Your phone asks before anything is deleted."), style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
        }
        Spacer(Modifier.height(HandyTokens.Space24))
    }
}
