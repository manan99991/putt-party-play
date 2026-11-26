package com.handytools.app.tools.builder

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.text.format.DateFormat
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.core.app.NotificationCompat
import com.handytools.app.I18n
import com.handytools.app.MainActivity
import com.handytools.app.Permissions
import com.handytools.app.R
import com.handytools.app.ui.HCard
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyTokens
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID

/**
 * Your own reminders, said in a sentence ("remind me to call Mum at 6"): kept on the phone, shown as a notification at
 * their time. One-offs go away once shown; repeating ones arm the next time. Ordinary (inexact) alarms, so no special
 * alarm permission is needed and a reminder can arrive a few minutes late when the phone is saving battery.
 */
object OwnReminders {
    data class Reminder(val id: String, val text: String, val once: Boolean, val onceAtMs: Long?, val schedule: Schedule) {
        /** "Fri 27 Nov, 9:00 AM" for a one-off; "Weekdays at 7:30 AM" for a repeat. */
        fun label(uses24h: Boolean, zone: ZoneId = ZoneId.systemDefault()): String =
            if (once && onceAtMs != null) {
                val t = Instant.ofEpochMilli(onceAtMs).atZone(zone)
                t.format(DateTimeFormatter.ofPattern("EEE d MMM")) + ", " + Schedule.clock(t.hour, t.minute, uses24h)
            } else schedule.label(uses24h)

        /** When it's next due after [now], or null once a one-off has passed. */
        fun next(now: Long): Long? = if (once) onceAtMs?.takeIf { it > now } else schedule.next(now)
    }

    private const val PREFS = "own_reminders"
    private const val KEY = "list"
    private const val ARMED = "armed"
    private const val CHANNEL = "own_reminders"
    /** Room for plenty, without letting a runaway list hold hundreds of alarms. */
    const val LIMIT = 30

    fun from(said: ReminderWords.Said): Reminder = Reminder(
        UUID.randomUUID().toString(), said.text, said.once, said.onceAt?.toInstant()?.toEpochMilli(),
        Schedule(said.hour, said.minute, said.days))

    fun load(ctx: Context): List<Reminder> {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return emptyList()
        return runCatching {
            val a = JSONArray(raw)
            (0 until a.length()).map { i ->
                val o = a.getJSONObject(i)
                val days = o.optJSONArray("days")?.let { d -> (0 until d.length()).map { d.getInt(it) } } ?: emptyList()
                Reminder(o.getString("id"), o.getString("text"), o.optBoolean("once"), if (o.has("at")) o.getLong("at") else null,
                    Schedule(o.optInt("hour", 9), o.optInt("minute", 0), days))
            }
        }.getOrDefault(emptyList())
    }

    private fun save(ctx: Context, all: List<Reminder>) {
        val a = JSONArray()
        all.forEach { r ->
            a.put(JSONObject().apply {
                put("id", r.id); put("text", r.text); put("once", r.once); r.onceAtMs?.let { put("at", it) }
                put("hour", r.schedule.hour); put("minute", r.schedule.minute); put("days", JSONArray(r.schedule.days))
            })
        }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, a.toString()).apply()
    }

    fun add(ctx: Context, r: Reminder) { save(ctx, (load(ctx) + r).takeLast(LIMIT)); sync(ctx) }
    fun remove(ctx: Context, id: String) { save(ctx, load(ctx).filter { it.id != id }); sync(ctx) }

    /** Arm every reminder's next time; one-offs that have passed are dropped. */
    fun sync(ctx: Context) {
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        (prefs.getStringSet(ARMED, emptySet()) ?: emptySet()).forEach { am.cancel(alarm(ctx, it)) }
        val now = System.currentTimeMillis()
        val keep = load(ctx).filter { it.next(now) != null }
        if (keep.size != load(ctx).size) save(ctx, keep)
        keep.forEach { r -> r.next(now)?.let { am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, it, alarm(ctx, r.id)) } }
        prefs.edit().putStringSet(ARMED, keep.map { it.id }.toSet()).apply()
    }

    private fun alarm(ctx: Context, id: String): PendingIntent = PendingIntent.getBroadcast(
        ctx, ("own-$id").hashCode(), Intent(ctx, OwnReminderReceiver::class.java).putExtra("id", id),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

    /** Shows one reminder now (also what "Test it" does). */
    fun show(ctx: Context, r: Reminder) {
        if (!Permissions.canPostNotifications(ctx)) return
        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
        nm.createNotificationChannel(NotificationChannel(CHANNEL, I18n.t("Your reminders"), NotificationManager.IMPORTANCE_HIGH))
        val open = PendingIntent.getActivity(ctx, ("own-${r.id}").hashCode(),
            Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_notif)
            .setContentTitle(r.text)
            .setContentText(I18n.t("Your reminder from Tenzy"))
            .setContentIntent(open)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        runCatching { nm.notify(("own-${r.id}").hashCode(), n) }
    }
}

/** Fires at a reminder's time: show it, then arm what's next (a repeat's next time; a one-off is done). */
class OwnReminderReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        runCatching {
            val id = intent.getStringExtra("id")
            OwnReminders.load(ctx).firstOrNull { it.id == id }?.let { OwnReminders.show(ctx, it) }
            OwnReminders.sync(ctx)
        }
    }
}

/** The card shown once "remind me…" is set: what, when, Test it, Undo — and a nudge when notifications are off. */
@Composable
fun ReminderSetCard(r: OwnReminders.Reminder, onUndo: () -> Unit) {
    val ctx = LocalContext.current
    val uses24h = DateFormat.is24HourFormat(ctx)
    var allowed by remember { mutableStateOf(Permissions.canPostNotifications(ctx)) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> allowed = ok }
    LaunchedEffect(r.id) { if (!allowed && Build.VERSION.SDK_INT >= 33) ask.launch(Manifest.permission.POST_NOTIFICATIONS) }
    HCard(Modifier.fillMaxWidth().testTag("reminder-set")) {
        Column(Modifier.padding(HandyTokens.Space12), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space4)) {
            Text(I18n.t("Reminder set"), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
            Text(r.text, Modifier.testTag("reminder-set-text"), style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(r.label(uses24h), Modifier.testTag("reminder-set-when"), style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary, maxLines = 1)
            if (!allowed) Text(I18n.t("Notifications are off for Tenzy — turn them on to get it."), style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.error, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Row(horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space8)) {
                TextButton({ OwnReminders.show(ctx, r) }, Modifier.testTag("reminder-set-test"), enabled = allowed) { Text(I18n.t("Test it")) }
                TextButton({ OwnReminders.remove(ctx, r.id); onUndo() }, Modifier.testTag("reminder-set-undo")) { Text(I18n.t("Undo")) }
            }
        }
    }
}
