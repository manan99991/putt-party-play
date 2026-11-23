package com.handytools.app.tools.meds

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Base64
import androidx.core.app.NotificationCompat
import com.handytools.app.MainActivity
import com.handytools.app.Permissions
import com.handytools.app.R
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** The medicines and the dose log, kept in the app's private files. Nothing leaves the phone. */
object MedStore {
    private fun file(ctx: Context) = File(ctx.filesDir, "tenzy-meds.json")

    fun load(ctx: Context): Pair<List<Med>, List<DoseLog>> = runCatching {
        val o = JSONObject(file(ctx).readText())
        val meds = MedCodec.meds(o.getJSONArray("meds"))
        val log = o.getJSONArray("log").let { a -> (0 until a.length()).map { i -> a.getJSONObject(i).let {
            DoseLog(it.getString("med"), it.getLong("at"), if (it.has("taken")) it.getLong("taken") else null) } } }
        meds to log
    }.getOrDefault(emptyList<Med>() to emptyList())

    fun save(ctx: Context, meds: List<Med>, log: List<DoseLog>) {
        val cutoff = System.currentTimeMillis() - 60 * MedLogic.DAY
        val o = JSONObject().put("meds", MedCodec.toJson(meds, keepIds = true)).put("log", JSONArray().apply {
            log.filter { it.scheduled >= cutoff }.forEach { put(JSONObject().put("med", it.medId).put("at", it.scheduled).apply { it.taken?.let { t -> put("taken", t) } }) }
        })
        file(ctx).writeText(o.toString())
        MedAlarms.sync(ctx)
    }

    fun isTaken(log: List<DoseLog>, m: Med, at: Long) = log.any { it.medId == m.id && Math.abs(it.scheduled - at) < 60_000 && it.taken != null }

    /** Log or un-log a dose; counts pills only when the state really changes, and posts the refill alert once. */
    fun setTaken(ctx: Context, medId: String, at: Long, taken: Boolean) {
        var (meds, log) = load(ctx)
        val m = meds.firstOrNull { it.id == medId } ?: return
        if (isTaken(log, m, at) != taken && m.supply != null) {
            val after = MedLogic.counted(m, taken)
            meds = meds.map { if (it.id == medId) after else it }
            if (MedLogic.crossedRefill(m, after)) MedAlarms.postRefill(ctx, after)
        }
        log = log.filterNot { it.medId == medId && Math.abs(it.scheduled - at) < 60_000 } +
            (if (taken) listOf(DoseLog(medId, at, System.currentTimeMillis())) else emptyList())
        save(ctx, meds, log)
        if (taken) MedAlarms.dismiss(ctx, medId, at)
    }

    /** Doses taken vs due over the last 7 days, and the ones missed ("Metformin Tue 8 PM"). */
    fun week(meds: List<Med>, log: List<DoseLog>, now: Long = System.currentTimeMillis()): Triple<Int, Int, List<String>> {
        var due = 0; var taken = 0; val missed = mutableListOf<String>()
        val fmt = java.text.SimpleDateFormat("EEE h a", java.util.Locale.getDefault())
        for (back in 6 downTo 0) {
            val day = now - back * MedLogic.DAY
            meds.forEach { m -> MedLogic.doses(m, day).filter { it <= now }.forEach { at ->
                due++
                if (isTaken(log, m, at)) taken++ else if (at <= now - 3_600_000) missed += "${m.name} ${fmt.format(java.util.Date(at))}"
            } }
        }
        return Triple(taken, due, missed)
    }
}

/** The list as text for another phone: the same "tenzy-meds:" code the iPhone sends and reads, so lists move
 *  between an iPhone and an Android phone either way. Dates are Apple's reference seconds, as Swift encodes them. */
object MedCodec {
    const val PREFIX = "tenzy-meds:"
    private const val APPLE_EPOCH = 978_307_200L   // 2001-01-01 in Unix seconds

    private fun toApple(ms: Long) = ms / 1000.0 - APPLE_EPOCH
    private fun fromApple(s: Double) = ((s + APPLE_EPOCH) * 1000).toLong()

    fun toJson(meds: List<Med>, keepIds: Boolean): JSONArray = JSONArray().apply {
        meds.forEach { m ->
            put(JSONObject().apply {
                put("id", if (keepIds) m.id else java.util.UUID.randomUUID().toString().uppercase())
                put("name", m.name); put("dose", m.dose); put("note", m.note); put("pattern", m.pattern.key)
                put("times", JSONArray().apply { m.times.forEach { put(JSONObject().put("hour", it.hour).put("minute", it.minute)) } })
                put("weekdays", JSONArray(m.weekdays.sorted())); put("everyHours", m.everyHours)
                put("firstHour", m.firstHour); put("lastHour", m.lastHour); put("start", toApple(m.start))
                m.end?.let { put("end", toApple(it)) }; m.followUp?.let { put("followUp", toApple(it)) }
                put("followUpNote", m.followUpNote); put("paused", if (keepIds) m.paused else false)
                m.supply?.let { put("supply", it) }; m.perDose?.let { put("perDose", it) }; m.refillAt?.let { put("refillAt", it) }
            })
        }
    }

    fun meds(a: JSONArray): List<Med> = (0 until a.length()).map { i ->
        val o = a.getJSONObject(i)
        val t = o.optJSONArray("times") ?: JSONArray()
        val w = o.optJSONArray("weekdays") ?: JSONArray()
        Med(
            id = o.optString("id", java.util.UUID.randomUUID().toString()), name = o.optString("name"), dose = o.optString("dose"),
            note = o.optString("note"), pattern = Pattern.of(o.optString("pattern", "daily")),
            times = (0 until t.length()).map { j -> t.getJSONObject(j).let { TimeOfDay(it.getInt("hour"), it.getInt("minute")) } },
            weekdays = (0 until w.length()).map { w.getInt(it) }.toSet(), everyHours = o.optInt("everyHours", 8),
            firstHour = o.optInt("firstHour", 8), lastHour = o.optInt("lastHour", 22),
            start = if (o.has("start")) fromApple(o.getDouble("start")) else MedLogic.startOfDay(System.currentTimeMillis()),
            end = if (o.has("end")) fromApple(o.getDouble("end")) else null,
            followUp = if (o.has("followUp")) fromApple(o.getDouble("followUp")) else null,
            followUpNote = o.optString("followUpNote", "Refill or check in with your doctor"), paused = o.optBoolean("paused"),
            supply = if (o.has("supply")) o.getInt("supply") else null, perDose = if (o.has("perDose")) o.getInt("perDose") else null,
            refillAt = if (o.has("refillAt")) o.getInt("refillAt") else null,
        )
    }

    fun shareText(meds: List<Med>): String =
        PREFIX + Base64.encodeToString(toJson(meds, keepIds = false).toString().toByteArray(), Base64.NO_WRAP)

    fun shareMessage(meds: List<Med>): String =
        "Your medicine reminders:\n" + meds.joinToString("\n") { "• ${it.name} — ${MedLogic.summary(it)}" } +
            "\n\nTo set them up: open Tenzy → Medicine Reminders → Family & caregiver → Paste a list, after copying this whole message.\n\n" + shareText(meds)

    /** Medicines from a message someone sent, or null if it isn't a Tenzy medicine list. */
    fun imported(text: String): List<Med>? = runCatching {
        val i = text.indexOf(PREFIX); if (i < 0) return null
        val b64 = text.substring(i + PREFIX.length).trim().takeWhile { !it.isWhitespace() }
        val list = meds(JSONArray(String(Base64.decode(b64, Base64.DEFAULT))))
        if (list.isEmpty() || list.size > 40) null else list.map { it.copy(id = java.util.UUID.randomUUID().toString()) }
    }.getOrNull()
}

/**
 * The dose alerts. Android lets only alarm-clock apps ring at the exact minute, so these use the battery-friendly
 * window alarms Android gives every app: each arrives within a few minutes of its time, even when the phone is idle.
 * The next three days are armed and topped up whenever an alert fires, the app opens, or the phone restarts.
 */
object MedAlarms {
    const val CHANNEL = "medicine"
    private const val PREFS = "medalarms"
    const val ACTION_DOSE = "com.tenzy.med.DOSE"
    const val ACTION_TAKEN = "com.tenzy.med.TAKEN"
    const val ACTION_SNOOZE = "com.tenzy.med.SNOOZE"
    const val ACTION_FOLLOW = "com.tenzy.med.FOLLOW"

    fun followUpMinutes(ctx: Context) = ctx.getSharedPreferences("medcare", 0).getInt("followup", 0)

    fun sync(ctx: Context) {
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        val prefs = ctx.getSharedPreferences(PREFS, 0)
        (prefs.getStringSet("armed", emptySet()) ?: emptySet()).forEach { key ->
            val (kind, med, at) = key.split("|").let { Triple(it[0], it[1], it[2].toLong()) }
            am.cancel(pending(ctx, kind, med, at))
        }
        val (meds, log) = MedStore.load(ctx)
        val now = System.currentTimeMillis()
        val armed = mutableSetOf<String>()
        MedLogic.upcoming(meds, now).forEach { (m, at) ->
            am.setWindow(AlarmManager.RTC_WAKEUP, at, 5 * 60_000L, pending(ctx, ACTION_DOSE, m.id, at)); armed += "$ACTION_DOSE|${m.id}|$at"
        }
        MedLogic.followUps(meds, { m, at -> MedStore.isTaken(log, m, at) }, followUpMinutes(ctx), now).forEach { (m, dose, at) ->
            am.setWindow(AlarmManager.RTC_WAKEUP, at, 5 * 60_000L, pending(ctx, ACTION_FOLLOW, m.id, dose)); armed += "$ACTION_FOLLOW|${m.id}|$dose"
        }
        prefs.edit().putStringSet("armed", armed).apply()
    }

    private fun pending(ctx: Context, action: String, medId: String, at: Long): PendingIntent = PendingIntent.getBroadcast(
        ctx, "$action$medId$at".hashCode(),
        Intent(ctx, MedReceiver::class.java).setAction(action).putExtra("med", medId).putExtra("at", at),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

    private fun channel(ctx: Context): NotificationManager? {
        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return null
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "Medicine reminders", NotificationManager.IMPORTANCE_HIGH))
        return nm
    }

    fun notifId(medId: String, at: Long) = "$medId$at".hashCode()

    /** One dose alert with Taken and Snooze 10 min, opening Medicine Reminders when tapped. */
    fun postDose(ctx: Context, m: Med, at: Long, followUp: Boolean = false) {
        if (!Permissions.canPostNotifications(ctx)) return
        val nm = channel(ctx) ?: return
        val open = PendingIntent.getActivity(ctx, notifId(m.id, at),
            Intent(ctx, MainActivity::class.java).putExtra("route", "medreminder").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val whenText = java.text.DateFormat.getTimeInstance(java.text.DateFormat.SHORT).format(java.util.Date(at))
        val title = if (followUp) "Did you take your ${m.name}?" else "Time for ${m.name}"
        val body = if (followUp) "It was due at $whenText. Tap Taken if you have."
            else listOf(m.dose, m.note).filter { it.isNotBlank() }.joinToString(" · ").ifEmpty { "Due at $whenText" }
        val n = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_notif).setContentTitle(title).setContentText(body)
            .setContentIntent(open).setAutoCancel(true).setCategory(NotificationCompat.CATEGORY_REMINDER)
            .addAction(0, "Taken ✓", pending(ctx, ACTION_TAKEN, m.id, at))
            .addAction(0, "Snooze 10 min", pending(ctx, ACTION_SNOOZE, m.id, at))
            .build()
        runCatching { nm.notify(notifId(m.id, at), n) }
    }

    fun postRefill(ctx: Context, m: Med) {
        if (!Permissions.canPostNotifications(ctx)) return
        val nm = channel(ctx) ?: return
        val (t, b) = MedLogic.refillMessage(m)
        val open = PendingIntent.getActivity(ctx, "refill${m.id}".hashCode(),
            Intent(ctx, MainActivity::class.java).putExtra("route", "medreminder").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        runCatching { nm.notify("refill${m.id}".hashCode(), NotificationCompat.Builder(ctx, CHANNEL).setSmallIcon(R.drawable.ic_notif)
            .setContentTitle(t).setContentText(b).setStyle(NotificationCompat.BigTextStyle().bigText(b)).setContentIntent(open).setAutoCancel(true).build()) }
    }

    fun dismiss(ctx: Context, medId: String, at: Long) {
        ctx.getSystemService(NotificationManager::class.java)?.cancel(notifId(medId, at))
    }

    fun snooze(ctx: Context, medId: String, at: Long, minutes: Int = 10) {
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        dismiss(ctx, medId, at)
        am.setWindow(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + minutes * 60_000L, 60_000L, pending(ctx, ACTION_DOSE, medId, at))
    }
}

/** Fires for a dose, a follow-up, or the Taken / Snooze buttons on an alert. */
class MedReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        runCatching {
            val medId = intent.getStringExtra("med") ?: return
            val at = intent.getLongExtra("at", 0L)
            val (meds, log) = MedStore.load(ctx)
            val m = meds.firstOrNull { it.id == medId } ?: return
            // Top up first, so a snooze armed below isn't cancelled by the top-up.
            MedAlarms.sync(ctx)
            when (intent.action) {
                MedAlarms.ACTION_DOSE -> if (!MedStore.isTaken(log, m, at)) MedAlarms.postDose(ctx, m, at)
                MedAlarms.ACTION_FOLLOW -> if (!MedStore.isTaken(log, m, at)) MedAlarms.postDose(ctx, m, at, followUp = true)
                MedAlarms.ACTION_TAKEN -> MedStore.setTaken(ctx, medId, at, true)
                MedAlarms.ACTION_SNOOZE -> MedAlarms.snooze(ctx, medId, at)
            }
        }
    }
}
