package com.handytools.app.tools.alarm

import android.app.TimePickerDialog
import android.content.Intent
import android.media.RingtoneManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.HandyApp
import com.handytools.app.Permissions
import com.handytools.app.ads.BannerAd
import com.handytools.app.data.Alarm
import com.handytools.app.ui.PermissionCard
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private val DAYS = listOf("S", "M", "T", "W", "T", "F", "S")

@Composable
fun AlarmListScreen(onUpgrade: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val alarms by HandyApp.instance.db.alarms().all().collectAsState(initial = emptyList())
    val premium by HandyApp.instance.billing.isPremium.collectAsState()
    var editing by remember { mutableStateOf<Alarm?>(null) }

    fun save(a: Alarm) {
        scope.launch {
            val id = withContext(Dispatchers.IO) { HandyApp.instance.db.alarms().upsert(a) }
            AlarmScheduler(ctx).schedule(a.copy(id = if (a.id == 0L) id else a.id))
            editing = null
        }
    }
    fun delete(a: Alarm) {
        scope.launch {
            withContext(Dispatchers.IO) { HandyApp.instance.db.alarms().delete(a) }
            AlarmScheduler(ctx).cancel(a.id); editing = null
        }
    }

    Scaffold(floatingActionButton = {
        FloatingActionButton(onClick = {
            if (!premium && alarms.size >= 3) onUpgrade() else editing = Alarm(hour = 7, minute = 0)
        }) { Text("+", fontSize = 28.sp) }
    }) { pad ->
        Column(Modifier.fillMaxSize().padding(pad).statusBarsPadding().padding(horizontal = 20.dp)) {
            ToolHeader("Alarm Pro", "Each alarm has its own volume, snooze length, ramp-up and limits.")
            PermissionCard("Exact alarms", "Android needs this so alarms ring on the minute.", Permissions.canExactAlarms(ctx), Permissions.exactAlarmIntent(ctx))
            LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(alarms, key = { it.id }) { a ->
                    Card(Modifier.fillMaxWidth().clickable { editing = a }) {
                        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(String.format("%02d:%02d", a.hour, a.minute), fontSize = 32.sp)
                                Text(buildString {
                                    append(a.label.ifBlank { if (a.repeatDays == 0) "Once" else "Repeats" })
                                    append(" · vol ${a.volume}% · snooze ${a.snoozeMinutes}m")
                                    if (a.repeatDays != 0) append(" · " + DAYS.filterIndexed { i, _ -> a.repeatDays and (1 shl i) != 0 }.joinToString(""))
                                }, style = MaterialTheme.typography.bodySmall)
                            }
                            Switch(a.enabled, { save(a.copy(enabled = it, snoozeUntil = null, snoozedCount = 0)) })
                        }
                    }
                }
            }
            if (!premium) Text("Free: 3 alarms. Pro: unlimited.", style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(vertical = 4.dp))
            BannerAd()
        }
    }
    editing?.let { AlarmEditor(it, onSave = ::save, onDelete = ::delete, onCancel = { editing = null }) }
}

@Composable
private fun AlarmEditor(initial: Alarm, onSave: (Alarm) -> Unit, onDelete: (Alarm) -> Unit, onCancel: () -> Unit) {
    val ctx = LocalContext.current
    var a by remember { mutableStateOf(initial) }
    val ringtonePicker = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { r ->
        @Suppress("DEPRECATION")
        val uri = r.data?.getParcelableExtra<android.net.Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        a = a.copy(soundUri = uri?.toString())
    }

    AlertDialog(
        onDismissRequest = onCancel,
        confirmButton = { Button(onClick = { onSave(a) }) { Text("Save") } },
        dismissButton = {
            Row {
                if (initial.id != 0L) TextButton(onClick = { onDelete(initial) }) { Text("Delete") }
                TextButton(onClick = onCancel) { Text("Cancel") }
            }
        },
        title = { Text(if (initial.id == 0L) "New alarm" else "Edit alarm") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                OutlinedButton(onClick = {
                    TimePickerDialog(ctx, { _, h, m -> a = a.copy(hour = h, minute = m) }, a.hour, a.minute, false).show()
                }, modifier = Modifier.fillMaxWidth()) { Text(String.format("%02d:%02d", a.hour, a.minute), fontSize = 28.sp) }
                OutlinedTextField(a.label, { a = a.copy(label = it) }, label = { Text("Label") }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))

                Text("Repeat", style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(top = 12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    DAYS.forEachIndexed { i, d ->
                        val bit = 1 shl i
                        FilterChip(selected = a.repeatDays and bit != 0, onClick = { a = a.copy(repeatDays = a.repeatDays xor bit) }, label = { Text(d) })
                    }
                }

                Text("Volume: ${a.volume}%", style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(top = 12.dp))
                Slider(a.volume.toFloat(), { a = a.copy(volume = it.toInt()) }, valueRange = 10f..100f)

                Text("Snooze length: ${a.snoozeMinutes} min", style = MaterialTheme.typography.labelLarge)
                Slider(a.snoozeMinutes.toFloat(), { a = a.copy(snoozeMinutes = it.toInt()) }, valueRange = 1f..30f, steps = 28)

                Text("Max snoozes: ${if (a.maxSnoozes == 0) "unlimited" else a.maxSnoozes}", style = MaterialTheme.typography.labelLarge)
                Slider(a.maxSnoozes.toFloat(), { a = a.copy(maxSnoozes = it.toInt()) }, valueRange = 0f..5f, steps = 4)

                Text("Ramp up over: ${if (a.gradualSeconds == 0) "off" else "${a.gradualSeconds}s"}", style = MaterialTheme.typography.labelLarge)
                Slider(a.gradualSeconds.toFloat(), { a = a.copy(gradualSeconds = it.toInt()) }, valueRange = 0f..120f, steps = 11)

                Text("Auto-stop after: ${a.timeoutMinutes} min", style = MaterialTheme.typography.labelLarge)
                Slider(a.timeoutMinutes.toFloat(), { a = a.copy(timeoutMinutes = it.toInt()) }, valueRange = 1f..30f, steps = 28)

                RowToggle("Vibrate", a.vibrate) { a = a.copy(vibrate = it) }
                RowToggle("Math problem to dismiss", a.mathToDismiss) { a = a.copy(mathToDismiss = it) }

                OutlinedButton(onClick = {
                    ringtonePicker.launch(Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Alarm sound")
                        putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, a.soundUri?.let { android.net.Uri.parse(it) })
                    })
                }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) { Text(if (a.soundUri == null) "Sound: default" else "Sound: custom") }
                Spacer(Modifier.height(8.dp))
            }
        }
    )
}

@Composable
private fun RowToggle(label: String, on: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        Text(label); Switch(on, onChange)
    }
}
