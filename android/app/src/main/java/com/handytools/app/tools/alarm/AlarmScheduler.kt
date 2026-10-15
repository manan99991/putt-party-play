package com.handytools.app.tools.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.handytools.app.HandyApp
import com.handytools.app.data.Alarm
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.util.Calendar

class AlarmScheduler(private val ctx: Context) {
    private val am = ctx.getSystemService(AlarmManager::class.java)

    fun schedule(a: Alarm) {
        cancel(a.id)
        if (!a.enabled) return
        val at = a.snoozeUntil ?: nextTrigger(a)
        val show = PendingIntent.getActivity(ctx, (a.id * 10 + 1).toInt(),
            Intent(ctx, com.handytools.app.MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        // setAlarmClock: exact, survives Doze, shows the alarm icon in the status bar.
        am.setAlarmClock(AlarmManager.AlarmClockInfo(at, show), pending(a.id))
    }

    fun cancel(id: Long) = am.cancel(pending(id))

    fun rescheduleAll() = runBlocking {
        withContext(Dispatchers.IO) { HandyApp.instance.db.alarms().allOnce() }.forEach { schedule(it) }
    }

    private fun pending(id: Long) = PendingIntent.getBroadcast(
        ctx, id.toInt(),
        Intent(ctx, AlarmReceiver::class.java).putExtra("id", id),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )

    companion object {
        /** Next occurrence >= now, honoring repeatDays (Sun=1 … Sat=64). */
        fun nextTrigger(a: Alarm, from: Long = System.currentTimeMillis()): Long {
            val c = Calendar.getInstance().apply {
                timeInMillis = from
                set(Calendar.HOUR_OF_DAY, a.hour); set(Calendar.MINUTE, a.minute); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }
            if (c.timeInMillis <= from) c.add(Calendar.DAY_OF_YEAR, 1)
            if (a.repeatDays == 0) return c.timeInMillis
            repeat(7) {
                val bit = 1 shl (c.get(Calendar.DAY_OF_WEEK) - 1)
                if (a.repeatDays and bit != 0) return c.timeInMillis
                c.add(Calendar.DAY_OF_YEAR, 1)
            }
            return c.timeInMillis
        }
    }
}

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val id = intent.getLongExtra("id", -1)
        if (id < 0) return
        ContextCompat.startForegroundService(ctx, Intent(ctx, AlarmRingService::class.java).putExtra("id", id))
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        AlarmScheduler(ctx).rescheduleAll()
    }
}
