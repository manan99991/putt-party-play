package com.handytools.app.tools.brief

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.TimePickerDialog
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.ContactsContract
import android.text.format.DateFormat
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.handytools.app.I18n
import com.handytools.app.MainActivity
import com.handytools.app.Permissions
import com.handytools.app.R
import com.handytools.app.tools.invoice.InvoiceStore
import com.handytools.app.tools.meds.MedLogic
import com.handytools.app.tools.meds.MedStore
import com.handytools.app.tools.meds.TimeOfDay
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.PowerToolPage
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Morning Summary on Android (the iPhone's Daily brief): one short notification each morning with what matters
 * today — your medicines, invoices a customer is late on, birthdays, your parked car, and one tidy-up nudge — written
 * the moment it goes out, so it's never stale. Built only from what's already in Tenzy; no new permission.
 */
object MorningSummary {
    data class Facts(
        val doses: List<Pair<String, Long>> = emptyList(),
        val lateInvoices: List<Pair<String, String>> = emptyList(),   // (customer, amount)
        val birthdays: List<Pair<String, Boolean>> = emptyList(),     // (name, today?)
        val freeGB: Double? = null,
        val parkedAt: Long? = null,
    )

    /** The brief in words: title, a short body for the notification, and every line for the screen. Pure. */
    fun compose(f: Facts, day: Long, is24: Boolean = false, now: Long = day): Triple<String, String, List<String>> {
        val lines = mutableListOf<String>()
        fun t(at: Long) = Calendar.getInstance().apply { timeInMillis = at }.let { TimeOfDay(it.get(Calendar.HOUR_OF_DAY), it.get(Calendar.MINUTE)).label(is24) }
        if (f.doses.isNotEmpty()) {
            val times = f.doses.sortedBy { it.second }.map { "${it.first} ${t(it.second)}" }
            lines += "💊 " + (if (f.doses.size == 1) "Medicine: " else "${f.doses.size} doses: ") + times.take(4).joinToString(", ") + if (times.size > 4) "…" else ""
        }
        f.lateInvoices.take(3).forEach { (who, amount) -> lines += "📄 $who hasn't paid $amount yet" }
        f.birthdays.take(3).forEach { (name, today) -> lines += "🎂 $name's birthday ${if (today) "is today" else "is tomorrow"}" }
        f.parkedAt?.takeIf { now - it < 48 * 3_600_000L }?.let { lines += "🚗 Your car's spot is saved" }
        f.freeGB?.takeIf { it < 5 }?.let { g -> lines += "🧹 Only ${if (g < 10) "%.1f".format(g) else g.toInt().toString()} GB free on your phone" }
        val title = "Your day · " + SimpleDateFormat("EEEE d MMM", Locale.getDefault()).format(Date(day))
        val body = if (lines.isEmpty()) "Nothing pressing today. Enjoy it." else lines.take(4).joinToString("\n")
        return Triple(title, body, lines)
    }

    fun nextFire(now: Long, hour: Int, minute: Int): Long {
        val c = Calendar.getInstance().apply { timeInMillis = now; set(Calendar.HOUR_OF_DAY, hour); set(Calendar.MINUTE, minute); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
        if (c.timeInMillis <= now) c.add(Calendar.DAY_OF_YEAR, 1)
        return c.timeInMillis
    }

    // ---- on the phone ----

    private fun prefs(ctx: Context) = ctx.getSharedPreferences("brief", 0)
    fun on(ctx: Context) = prefs(ctx).getBoolean("on", false)
    fun hour(ctx: Context) = prefs(ctx).getInt("hour", 7)
    fun minute(ctx: Context) = prefs(ctx).getInt("minute", 0)

    fun gather(ctx: Context, day: Long): Facts {
        val (meds, _) = MedStore.load(ctx)
        val doses = MedLogic.today(meds, day).map { it.first.name to it.second }
        val late = InvoiceStore.load(ctx).filter { it.overdue(day) }.map { it.who.ifEmpty { it.number } to "${it.currency}${"%,.2f".format(it.total)}" }
        val free = runCatching { StatFs(Environment.getDataDirectory().absolutePath).availableBytes / 1e9 }.getOrNull()
        val parked = ctx.getSharedPreferences("parked_spot", 0).getLong("at", 0L).takeIf { it > 0 }
        return Facts(doses, late, birthdays(ctx, day), free, parked)
    }

    /** Today's and tomorrow's birthdays from contacts — only when Contacts access was already given. */
    private fun birthdays(ctx: Context, day: Long): List<Pair<String, Boolean>> {
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) return emptyList()
        val today = Calendar.getInstance().apply { timeInMillis = day }
        val tomorrow = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }
        fun md(c: Calendar) = "%02d-%02d".format(c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))
        val out = mutableListOf<Pair<String, Boolean>>()
        runCatching {
            ctx.contentResolver.query(ContactsContract.Data.CONTENT_URI,
                arrayOf(ContactsContract.Contacts.DISPLAY_NAME, ContactsContract.CommonDataKinds.Event.START_DATE),
                "${ContactsContract.Data.MIMETYPE}=? AND ${ContactsContract.CommonDataKinds.Event.TYPE}=?",
                arrayOf(ContactsContract.CommonDataKinds.Event.CONTENT_ITEM_TYPE, ContactsContract.CommonDataKinds.Event.TYPE_BIRTHDAY.toString()), null
            )?.use { c ->
                while (c.moveToNext()) {
                    val name = c.getString(0) ?: continue; val date = c.getString(1) ?: continue   // "1980-11-23" or "--11-23"
                    val mmdd = date.takeLast(5)
                    if (mmdd == md(today)) out += name to true else if (mmdd == md(tomorrow)) out += name to false
                }
            }
        }
        return out
    }

    fun arm(ctx: Context) {
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        val pi = PendingIntent.getBroadcast(ctx, 7701, Intent(ctx, MorningSummaryReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        am.cancel(pi)
        if (on(ctx)) am.setWindow(AlarmManager.RTC_WAKEUP, nextFire(System.currentTimeMillis(), hour(ctx), minute(ctx)), 10 * 60_000L, pi)
    }

    fun post(ctx: Context, test: Boolean = false) {
        if (!Permissions.canPostNotifications(ctx)) return
        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
        nm.createNotificationChannel(NotificationChannel("brief", "Morning summary", NotificationManager.IMPORTANCE_DEFAULT))
        val now = System.currentTimeMillis()
        val (title, body, _) = compose(gather(ctx, now), now, DateFormat.is24HourFormat(ctx), now)
        val open = PendingIntent.getActivity(ctx, 7702, Intent(ctx, MainActivity::class.java).putExtra("route", "brief")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        runCatching { nm.notify(7703, NotificationCompat.Builder(ctx, "brief").setSmallIcon(R.drawable.ic_notif)
            .setContentTitle((if (test) "Test · " else "") + title).setContentText(body.lineSequence().first())
            .setStyle(NotificationCompat.BigTextStyle().bigText(body)).setContentIntent(open).setAutoCancel(true).build()) }
    }
}

/** Fires each morning: writes today's summary from fresh facts, then arms tomorrow's. Also re-arms after a restart. */
class MorningSummaryReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        runCatching {
            if (intent.action != Intent.ACTION_BOOT_COMPLETED && MorningSummary.on(ctx)) MorningSummary.post(ctx)
            MorningSummary.arm(ctx)
        }
    }
}

@Composable
fun MorningSummaryScreen(onOpen: (String) -> Unit = {}) {
    val ctx = LocalContext.current
    val prefs = remember { ctx.getSharedPreferences("brief", 0) }
    val is24 = DateFormat.is24HourFormat(ctx)
    var on by remember { mutableStateOf(MorningSummary.on(ctx)) }
    var hour by remember { mutableStateOf(MorningSummary.hour(ctx)) }
    var minute by remember { mutableStateOf(MorningSummary.minute(ctx)) }
    var note by remember { mutableStateOf<String?>(null) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        if (!ok) note = I18n.t("Notifications are off for Tenzy, so the summary can't arrive. Turn them on in Settings › Apps › Tenzy.")
    }
    val now = System.currentTimeMillis()
    val lines = remember { MorningSummary.compose(MorningSummary.gather(ctx, now), now, is24, now).third }

    PowerToolPage("brief") {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(I18n.t("Send me a morning summary"), fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground, modifier = Modifier.weight(1f))
            Switch(checked = on, modifier = Modifier.testTag("brief-on"), onCheckedChange = { v ->
                on = v; prefs.edit().putBoolean("on", v).apply(); MorningSummary.arm(ctx)
                if (v && !Permissions.canPostNotifications(ctx) && Build.VERSION.SDK_INT >= 33) ask.launch(Manifest.permission.POST_NOTIFICATIONS)
            })
        }
        if (on) {
            Text(I18n.t("Every morning at") + " " + TimeOfDay(hour, minute).label(is24), color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.clickable {
                    TimePickerDialog(ctx, { _, h, m -> hour = h; minute = m; prefs.edit().putInt("hour", h).putInt("minute", m).apply(); MorningSummary.arm(ctx) }, hour, minute, is24).show()
                }.padding(vertical = 10.dp))
            HSecondaryButton("Test run", modifier = Modifier.testTag("brief-test")) {
                MorningSummary.post(ctx, test = true); note = I18n.t("Test sent — check your notifications. That's what each morning looks like.")
            }
        }
        note?.let { Text(it, fontSize = 13.sp, color = MaterialTheme.colorScheme.primary) }
        Text(I18n.t("It's built from what's already in Tenzy — Medicine Reminders, Invoices, your contacts' birthdays, your parked car and free space. Add things there and they show up here."),
            fontSize = 12.sp, color = Handy.palette.textSecondary)

        Spacer(Modifier.size(16.dp))
        Text(I18n.t("Today"), fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = MaterialTheme.colorScheme.onBackground)
        if (lines.isEmpty()) Text(I18n.t("Nothing pressing today. Enjoy it."), color = Handy.palette.textSecondary)
        lines.forEach { Text(it, color = MaterialTheme.colorScheme.onBackground, modifier = Modifier.padding(vertical = 4.dp)) }

        Spacer(Modifier.size(16.dp))
        Text(I18n.t("Where it comes from"), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Handy.palette.textSecondary)
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            HSecondaryButton("Medicines") { onOpen("medreminder") }
            HSecondaryButton("Invoices") { onOpen("invoice") }
            HSecondaryButton("Where I Parked") { onOpen("parked") }
        }
    }
}
