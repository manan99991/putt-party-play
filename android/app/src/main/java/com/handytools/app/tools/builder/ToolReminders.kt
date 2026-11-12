package com.handytools.app.tools.builder

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.TimePickerDialog
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.text.format.DateFormat
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.core.app.NotificationCompat
import com.handytools.app.MainActivity
import com.handytools.app.Permissions
import com.handytools.app.R
import com.handytools.app.ui.HCard
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyTokens

/**
 * Tool reminders: "run my receipt tool every Friday at 6". At the chosen time the phone shows a reminder; tapping it
 * opens the tool ready to run. Uses ordinary (inexact) alarms, so it needs no special alarm permission and the reminder
 * can arrive a few minutes late when the phone is saving battery.
 */
object ToolReminders {
    private const val CHANNEL = "tool_reminders"
    private const val PREFS = "builder"
    private const val KEY = "reminders"

    /** Set when a reminder is tapped; the builder screen opens that tool and clears it. */
    var pending by mutableStateOf<String?>(null)
    /** With [pending]: the new photo to run that tool on, when the tap came from a "new photo" notification. */
    var pendingPhoto: android.net.Uri? = null

    /** Replace every armed reminder with what the saved tools now ask for. */
    fun sync(ctx: Context, chains: List<Chain>) {
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        (prefs.getStringSet(KEY, emptySet()) ?: emptySet()).forEach { am.cancel(alarm(ctx, it)) }
        val now = System.currentTimeMillis()
        val wanted = chains.filter { it.schedule != null }
        wanted.forEach { c -> c.schedule?.let { w -> am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, w.next(now), alarm(ctx, c.id)) } }
        prefs.edit().putStringSet(KEY, wanted.map { it.id }.toSet()).apply()
    }

    fun resync(ctx: Context) = sync(ctx, ChainStore.load(ctx))

    private fun alarm(ctx: Context, id: String): PendingIntent = PendingIntent.getBroadcast(
        ctx, id.hashCode(), Intent(ctx, ToolReminderReceiver::class.java).putExtra("tool", id),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

    /** Show the reminder for one tool. Does nothing if the tool is gone or notifications are off. */
    fun show(ctx: Context, id: String) {
        val c = ChainStore.load(ctx).firstOrNull { it.id == id && it.schedule != null } ?: return
        post(ctx, id.hashCode(), c.name, "Time to run this tool. Tap to open it.", id, null)
    }

    /** One notification that opens [toolId] in the builder, on [photo] when there is one. */
    fun post(ctx: Context, key: Int, title: String, text: String, toolId: String, photo: android.net.Uri?) {
        if (!Permissions.canPostNotifications(ctx)) return
        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "Tool reminders", NotificationManager.IMPORTANCE_DEFAULT))
        val intent = Intent(ctx, MainActivity::class.java).putExtra("route", "builder").putExtra("tool", toolId)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (photo != null) intent.putExtra("photo", photo.toString())
        val open = PendingIntent.getActivity(ctx, key, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_notif)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        runCatching { nm.notify(key, n) }
    }
}

/** Fires at a reminder's time (show it, then arm the next one) and after a restart (arm them all again). */
class ToolReminderReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        runCatching {
            intent.getStringExtra("tool")?.let { ToolReminders.show(ctx, it) }
            ToolReminders.resync(ctx)
            PhotoWatch.arm(ctx)
        }
    }
}

/** "Remind me": a switch, a time, and the days. Lives at the bottom of the builder. */
@Composable
fun ScheduleCard(schedule: Schedule?, onChange: (Schedule?) -> Unit) {
    val ctx = LocalContext.current
    val uses24h = DateFormat.is24HourFormat(ctx)
    var allowed by remember { mutableStateOf(Permissions.canPostNotifications(ctx)) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> allowed = ok }
    val week = listOf(2, 3, 4, 5, 6, 7, 1)                                   // Monday first, Sunday last
    val letters = listOf("S", "M", "T", "W", "T", "F", "S")
    val names = listOf("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
    HCard(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(HandyTokens.Space12), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Remind me to run this", Modifier.weight(1f), style = MaterialTheme.typography.titleSmall)
                Switch(schedule != null, { on ->
                    onChange(if (on) Schedule() else null)
                    if (on && !allowed && Build.VERSION.SDK_INT >= 33) ask.launch(Manifest.permission.POST_NOTIFICATIONS)
                })
            }
            if (schedule != null) {
                TextButton({
                    TimePickerDialog(ctx, { _, h, m -> onChange(schedule.copy(hour = h, minute = m)) }, schedule.hour, schedule.minute, uses24h).show()
                }) { Text("Time: " + Schedule.clock(schedule.hour, schedule.minute, uses24h) + "  (change)") }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    week.forEach { d ->
                        val picked = schedule.days.isEmpty() || d in schedule.days
                        Box(
                            Modifier.weight(1f).heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp))
                                .background(if (picked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant)
                                .clickable {
                                    val days = (if (schedule.days.isEmpty()) (1..7).toList() else schedule.days).toMutableSet()
                                    if (d in days) { if (days.size > 1) days.remove(d) } else days.add(d)      // never zero days
                                    onChange(schedule.copy(days = if (days.size == 7) emptyList() else days.sorted()))
                                }
                                .semantics { contentDescription = names[d - 1]; selected = picked },
                            contentAlignment = Alignment.Center,
                        ) { Text(letters[d - 1], color = if (picked) MaterialTheme.colorScheme.onPrimary else Handy.palette.textSecondary) }
                    }
                }
                Text(schedule.label(uses24h), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
                Text(
                    if (allowed) "Your phone shows a reminder around that time. Tap it and this tool opens, ready to run."
                    else "Notifications are off for Tenzy. Turn them on in Settings to get this reminder.",
                    style = MaterialTheme.typography.bodySmall, color = if (allowed) Handy.palette.textSecondary else MaterialTheme.colorScheme.error)
            }
        }
    }
}

/** "Offer this tool when...": off, a new photo, or a new screenshot. Only for tools that start with a photo. */
@Composable
fun AutoRunCard(auto: String, onChange: (String) -> Unit) {
    val ctx = LocalContext.current
    val perm = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES else Manifest.permission.READ_EXTERNAL_STORAGE
    fun granted() = androidx.core.content.ContextCompat.checkSelfPermission(ctx, perm) == android.content.pm.PackageManager.PERMISSION_GRANTED
    var photosOk by remember { mutableStateOf(granted()) }
    var notifOk by remember { mutableStateOf(Permissions.canPostNotifications(ctx)) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { photosOk = granted(); notifOk = Permissions.canPostNotifications(ctx) }
    HCard(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(HandyTokens.Space12), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
            Text("Offer this tool by itself", style = MaterialTheme.typography.titleSmall)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                AutoRun.ALL.forEach { a ->
                    val picked = a == auto
                    Box(
                        Modifier.weight(1f).heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp))
                            .background(if (picked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant)
                            .clickable {
                                onChange(a)
                                if (a.isNotEmpty() && (!photosOk || !notifOk)) {
                                    ask.launch(if (Build.VERSION.SDK_INT >= 33) arrayOf(perm, Manifest.permission.POST_NOTIFICATIONS) else arrayOf(perm))
                                }
                            }
                            .semantics { selected = picked },
                        contentAlignment = Alignment.Center,
                    ) { Text(AutoRun.title(a), style = MaterialTheme.typography.bodySmall, color = if (picked) MaterialTheme.colorScheme.onPrimary else Handy.palette.textSecondary) }
                }
            }
            if (auto.isNotEmpty()) Text(
                if (photosOk && notifOk) (if (auto == AutoRun.SCREENSHOT) "When you take a screenshot" else "When you take a photo") + ", Tenzy shows a notification. Tap it and this tool runs on that picture. Nothing runs until you tap."
                else "Tenzy needs to see all your photos and to send notifications for this. Allow both in Settings, then save this tool again.",
                style = MaterialTheme.typography.bodySmall, color = if (photosOk && notifOk) Handy.palette.textSecondary else MaterialTheme.colorScheme.error)
        }
    }
}
