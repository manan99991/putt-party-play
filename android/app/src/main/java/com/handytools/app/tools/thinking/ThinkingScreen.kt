package com.handytools.app.tools.thinking

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.handytools.app.tools.Share
import com.handytools.app.tools.builder.ThinkingActions
import com.handytools.app.tools.builder.ThinkingEngine
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.PowerToolPage
import java.io.File
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * The on-device thinking hub for Android. Two tools that need no language model and so work the same on
 * every phone: Clear My Head (a brain-dump → clean, deduped tasks) and My Day (the same tasks laid out by
 * time). Every task is already routed to the phone's own apps by [ThinkingActions] — Directions on Maps,
 * a one-tap Call, and a one-tap "Add dated steps to Calendar" that hands the whole plan to the calendar
 * as a single .ics. The five language-model tools (Untangle, Crossroads, Plain, Reword, Prep) run on
 * Apple's on-device model on iPhone; they arrive on Android when an on-device model path lands here, so
 * this screen never fakes them.
 */
private val TABS = listOf("Clear My Head", "My Day")

@Composable
fun ThinkingScreen() {
    val ctx = LocalContext.current
    var tab by remember { mutableIntStateOf(0) }
    var dump by remember { mutableStateOf("") }
    // The tasks of the last "Think it through" — kept so switching tabs re-lays the same dump without
    // asking the person to run it again.
    var tasks by remember { mutableStateOf<List<ThinkingEngine.Task>>(emptyList()) }

    fun recompute() {
        val now = System.currentTimeMillis()
        tasks = if (tab == 0) ThinkingEngine.clearMyHead(dump, now) else ThinkingEngine.myDay(dump, now)
    }

    PowerToolPage("thinking", tabs = TABS, selected = tab, onTab = { tab = it; if (dump.isNotBlank()) recompute() }) {
        OutlinedTextField(
            value = dump,
            onValueChange = { dump = it },
            label = { Text(if (tab == 0) "Everything on your mind" else "What's your day look like?") },
            placeholder = { Text("call the dentist, pick up a parcel from the post office at 3pm, email Sam, pay rent Friday") },
            minLines = 5,
            modifier = Modifier.fillMaxWidth().heightIn(min = 150.dp)
        )
        Spacer(Modifier.size(12.dp))
        HPrimaryButton(if (tab == 0) "Clear my head" else "Lay out my day", modifier = Modifier.fillMaxWidth(), enabled = dump.isNotBlank()) { recompute() }

        if (tasks.isNotEmpty()) {
            Spacer(Modifier.size(16.dp))
            // Adaptive summary: deadlines named plainly, soft tasks nudged, the trivial left quiet.
            val deadlines = tasks.count { ThinkingEngine.urgency(it) == ThinkingEngine.Urgency.DEADLINE }
            val nudges = tasks.count { ThinkingEngine.urgency(it) == ThinkingEngine.Urgency.NUDGE }
            val quiet = tasks.size - deadlines - nudges
            val parts = buildList {
                if (deadlines > 0) add("$deadlines with a deadline")
                if (nudges > 0) add("$nudges to get to")
                if (quiet > 0) add("$quiet can wait")
            }
            Text(
                parts.joinToString(" · ").ifEmpty { "${tasks.size} task${if (tasks.size == 1) "" else "s"}" },
                color = Handy.palette.textSecondary, style = MaterialTheme.typography.bodySmall
            )
            Spacer(Modifier.size(8.dp))
            for (t in tasks) TaskRow(ctx, t)

            val timed = tasks.count { it.due != null }
            if (timed > 0) {
                Spacer(Modifier.size(14.dp))
                HSecondaryButton("Add dated steps to Calendar", modifier = Modifier.fillMaxWidth()) {
                    addToCalendar(ctx, tasks)
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TaskRow(ctx: Context, t: ThinkingEngine.Task) {
    Column(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
        Text(t.text.replaceFirstChar { it.uppercase() }, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
        t.due?.let { due ->
            Text(
                SimpleDateFormat("EEE d MMM · h:mm a", Locale.getDefault()).format(java.util.Date(due)),
                style = MaterialTheme.typography.bodySmall, color = Handy.palette.accent, fontWeight = FontWeight.SemiBold
            )
        }
        val p = t.actions
        if (p.place != null || p.isCall) {
            Spacer(Modifier.size(4.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                p.place?.let { place ->
                    HChip("Directions", false) {
                        ThinkingActions.mapsURL(place)?.let { open(ctx, it) }
                    }
                }
                if (p.isCall) {
                    val tel = p.phone?.let { ThinkingActions.telURL(it) }
                    HChip(if (tel != null) "Call" else "Find number", false) {
                        if (tel != null) open(ctx, tel)
                        else Toast.makeText(ctx, "No number in this task — add one to call in a tap", Toast.LENGTH_SHORT).show()
                    }
                }
            }
        }
    }
}

/** Open a geo:/tel: hand-off, honestly reporting when no app can take it rather than failing silently. */
private fun open(ctx: Context, url: String) {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
    if (intent.resolveActivity(ctx.packageManager) != null) ctx.startActivity(intent)
    else Toast.makeText(ctx, "No app on this phone can open that", Toast.LENGTH_SHORT).show()
}

/** Build one .ics holding every dated task and hand it to the calendar — the whole plan in a tap. */
private fun addToCalendar(ctx: Context, tasks: List<ThinkingEngine.Task>) {
    val events = tasks.mapNotNull { t -> t.due?.let { Triple(t.text.replaceFirstChar { c -> c.uppercase() }, it, t.actions.place ?: "") } }
    if (events.isEmpty()) {
        Toast.makeText(ctx, "No dated steps to add", Toast.LENGTH_SHORT).show()
        return
    }
    val ics = ThinkingActions.icsCalendar(events)
    val file = File(ctx.cacheDir, "tenzy-plan.ics").apply { writeText(ics) }
    Share.file(ctx, file, "text/calendar")
}
