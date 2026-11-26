package com.handytools.app.tools.autoruns

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.NotificationCompat
import com.handytools.app.I18n
import com.handytools.app.MainActivity
import com.handytools.app.Permissions
import com.handytools.app.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Smart autoruns on Android: which are on and when, when each last ran, and the phone's part — an ordinary (inexact)
 * alarm at each chosen time, a quick look for something to do, and a notification only when there is something
 * ("3 videos could be 410 MB smaller"). Tapping it opens the autorun, which does the work with a live progress bar and
 * shows everything before anything is saved, sent or deleted. The person's "Test run" does the same on demand.
 */
object Autoruns {
    private const val PREFS = "autoruns"
    private const val CHANNEL = "autoruns"

    /** The autoruns Android does so far, in the page's order; the others stay iPhone-only until they're built here. */
    val available: List<SmartRuns.Kind> = listOf(SmartRuns.Kind.RECEIPTS, SmartRuns.Kind.OVERDUE_INVOICES, SmartRuns.Kind.BUSINESS_CARDS, SmartRuns.Kind.DAY_COLLAGE, SmartRuns.Kind.WEEK_FILM, SmartRuns.Kind.READY_TO_POST,
        SmartRuns.Kind.HEAVY_VIDEOS, SmartRuns.Kind.TIDY_PHOTOS, SmartRuns.Kind.CONTACTS_BACKUP)

    /** Set when a notification is tapped; the page opens that autorun and clears it. */
    var pending by mutableStateOf<String?>(null)

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun plan(ctx: Context, k: SmartRuns.Kind): SmartRuns.Plan {
        val saved = prefs(ctx).getString("plan." + k.id, null) ?: return SmartRuns.Plan.start(k)
        return runCatching {
            val o = JSONObject(saved)
            SmartRuns.Plan(o.optBoolean("on"), o.optBoolean("twice"), o.optInt("hour", 20), o.optInt("minute", 0),
                if (o.has("weekday")) o.getInt("weekday") else null)
        }.getOrDefault(SmartRuns.Plan.start(k))
    }

    fun setPlan(ctx: Context, k: SmartRuns.Kind, p: SmartRuns.Plan) {
        val o = JSONObject().put("on", p.on).put("twice", p.twice).put("hour", p.hour).put("minute", p.minute)
        p.weekday?.let { o.put("weekday", it) }
        prefs(ctx).edit().putString("plan." + k.id, o.toString()).apply()
        sync(ctx)
    }

    fun lastRun(ctx: Context, k: SmartRuns.Kind): Long? = prefs(ctx).getLong("last." + k.id, 0L).takeIf { it > 0 }
    fun markRun(ctx: Context, k: SmartRuns.Kind, at: Long) { prefs(ctx).edit().putLong("last." + k.id, at).apply() }

    /** The autoruns that are on. */
    fun on(ctx: Context): Set<SmartRuns.Kind> = available.filter { plan(ctx, it).on }.toSet()

    // ---- habit offers (For you) ----

    fun offersOff(ctx: Context): Boolean = prefs(ctx).getBoolean("offers.off", false)
    fun setOffersOff(ctx: Context, off: Boolean) { prefs(ctx).edit().putBoolean("offers.off", off).apply() }
    fun hidden(ctx: Context): Set<SmartRuns.Kind> = prefs(ctx).getStringSet("offers.hidden", emptySet()).orEmpty().mapNotNull { SmartRuns.Kind.of(it) }.toSet()
    fun hide(ctx: Context, k: SmartRuns.Kind) { prefs(ctx).edit().putStringSet("offers.hidden", hidden(ctx).map { it.id }.toSet() + k.id).apply() }

    /** The one autorun worth offering on Home from the person's own habit, with on how many days lately they did it by hand. */
    fun offer(ctx: Context, now: Long = System.currentTimeMillis()): Pair<SmartRuns.Kind, Int>? {
        if (offersOff(ctx)) return null
        val days = ToolDays.all(ctx, now)
        val today = ToolDays.day(now)
        val recent = days.mapValues { (_, d) -> d.filter { it > today - 14 }.toSet() }
        val k = SmartRuns.suggested(recent, emptyMap(), on(ctx), hidden(ctx)).firstOrNull { it in available } ?: return null
        return k to k.habitTools.flatMap { recent[it].orEmpty() }.toSet().size
    }

    // ---- the phone's part ----

    /** Arms one alarm per autorun that's on, at its next chosen time. */
    fun sync(ctx: Context) {
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        val now = ZonedDateTime.now()
        for (k in available) {
            val pi = alarm(ctx, k)
            am.cancel(pi)
            val next = SmartRuns.nextDue(plan(ctx, k), now) ?: continue
            runCatching { am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.toInstant().toEpochMilli(), pi) }
        }
    }

    private fun alarm(ctx: Context, k: SmartRuns.Kind): PendingIntent = PendingIntent.getBroadcast(
        ctx, ("autorun." + k.id).hashCode(), Intent(ctx, AutorunReceiver::class.java).putExtra("autorun", k.id),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

    /** At an autorun's time: look quickly for something to do and say so only when there is something. */
    suspend fun due(ctx: Context, k: SmartRuns.Kind) {
        val now = System.currentTimeMillis()
        val last = lastRun(ctx, k)
        val zone = ZoneId.systemDefault()
        if (!SmartRuns.isDue(plan(ctx, k), last?.let { ZonedDateTime.ofInstant(Instant.ofEpochMilli(it), zone) }, ZonedDateTime.now(zone))) return
        val window = SmartRuns.window(last, now)
        val news = when (k) {
            SmartRuns.Kind.HEAVY_VIDEOS -> HeavyVideos.find(ctx, window).let { found ->
                if (found.isEmpty()) null else HeavyVideos.notice(found)
            }
            SmartRuns.Kind.READY_TO_POST -> ReadyToPost.find(ctx, window).size.let { n ->
                if (n == 0) null else if (n == 1) I18n.t("1 clip from today can be made ready to post.") else I18n.fmt("%d clips from today can be made ready to post.", n)
            }
            SmartRuns.Kind.DAY_COLLAGE -> PhotoDays.find(ctx, window).count { !it.screenshot }.let { n ->
                if (n < 4) null else I18n.fmt("%d photos from today — tap to see the best of them as one collage.", n)
            }
            SmartRuns.Kind.WEEK_FILM -> PhotoDays.find(ctx, weekWindow(now)).count { !it.screenshot }.let { n ->
                if (n < 8) null else I18n.fmt("%d photos this week — tap to make them into one short film.", n)
            }
            // Receipts and cards need each photo read, so the quick look only counts today's photos; the reading happens when it's opened.
            SmartRuns.Kind.RECEIPTS, SmartRuns.Kind.BUSINESS_CARDS -> PhotoDays.find(ctx, window).count { !it.screenshot }.let { n ->
                if (n == 0) null else I18n.fmt("%d photos from today — tap to find the receipts and business cards in them.", n)
            }
            // A quick count of old screenshots; the full look (copies, look-alikes) happens when it's opened.
            SmartRuns.Kind.TIDY_PHOTOS -> TidyPhotos.oldScreenshotCount(ctx, now).let { n ->
                if (n < 20) null else I18n.fmt("%d screenshots are over a week old — tap to tidy them up.", n)
            }
            // The week's copy is made right here; a word only when someone has disappeared since the last one.
            SmartRuns.Kind.CONTACTS_BACKUP -> ContactsBackup.make(ctx, now)?.gone?.size?.let { n ->
                if (n == 0) null else ContactsBackup.notice(n)
            }
            // Only when something is overdue (as on the iPhone).
            SmartRuns.Kind.OVERDUE_INVOICES -> OverdueInvoices.overdue(com.handytools.app.tools.invoice.InvoiceStore.load(ctx), now).size.let { n ->
                if (n == 0) null else OverdueInvoices.notice(n)
            }
            else -> null
        }
        // The window is kept for the run the notification opens; nothing found still counts as a run.
        prefs(ctx).edit().putLong("ready.from." + k.id, window.first).putLong("ready.to." + k.id, window.last).apply()
        markRun(ctx, k, now)
        if (news != null) notify(ctx, k, news)
    }

    /** The week's film looks at the last seven days. */
    fun weekWindow(now: Long): LongRange = (now - 7L * 24 * 3600_000)..now

    /** The window the next opened run looks at: the one its notification found, else since the last run. */
    fun windowFor(ctx: Context, k: SmartRuns.Kind, now: Long = System.currentTimeMillis()): LongRange {
        val p = prefs(ctx)
        val from = p.getLong("ready.from." + k.id, 0L); val to = p.getLong("ready.to." + k.id, 0L)
        return if (from in 1 until to) from..to else SmartRuns.window(lastRun(ctx, k), now)
    }

    fun clearReady(ctx: Context, k: SmartRuns.Kind) { prefs(ctx).edit().remove("ready.from." + k.id).remove("ready.to." + k.id).apply() }

    private fun notify(ctx: Context, k: SmartRuns.Kind, text: String) {
        if (!Permissions.canPostNotifications(ctx)) return
        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
        nm.createNotificationChannel(NotificationChannel(CHANNEL, I18n.t("Smart autoruns"), NotificationManager.IMPORTANCE_DEFAULT))
        val intent = Intent(ctx, MainActivity::class.java).putExtra("route", "autoruns").putExtra("autorun", k.id)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val open = PendingIntent.getActivity(ctx, ("autorun." + k.id).hashCode(), intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(ctx, CHANNEL).setSmallIcon(R.drawable.ic_notif)
            .setContentTitle(I18n.t(k.title)).setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(open).setAutoCancel(true).build()
        runCatching { nm.notify(("autorun." + k.id).hashCode(), n) }
    }
}

/** Fires at an autorun's time (look, maybe say so, arm the next) and after a restart (arm them all again). */
class AutorunReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val k = intent.getStringExtra("autorun")?.let { SmartRuns.Kind.of(it) }
        val done = goAsync()
        CoroutineScope(Dispatchers.Default).launch {
            try {
                if (k != null) runCatching { Autoruns.due(ctx.applicationContext, k) }
                Autoruns.sync(ctx.applicationContext)
            } finally { done.finish() }
        }
    }
}
