package com.handytools.app.tools.alarm

import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import com.handytools.app.HandyApp
import com.handytools.app.R
import com.handytools.app.data.Alarm
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Plays the alarm on the ALARM stream with its OWN volume (per-alarm, ignores system alarm
 * slider), ramps up if asked, vibrates, auto-times-out, and shows a full-screen ring activity.
 */
class AlarmRingService : Service() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var player: MediaPlayer? = null
    private var vib: Vibrator? = null
    private var wake: PowerManager.WakeLock? = null
    private var timeoutJob: Job? = null
    private var rampJob: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getLongExtra("id", -1) ?: -1
        when (intent?.action) {
            ACTION_SNOOZE -> { scope.launch { snooze(id) }; return START_NOT_STICKY }
            ACTION_DISMISS -> { scope.launch { dismiss(id) }; return START_NOT_STICKY }
        }
        scope.launch {
            val a = withContext(Dispatchers.IO) { HandyApp.instance.db.alarms().byId(id) } ?: run { stopSelf(); return@launch }
            current = a
            startFg(a)
            acquireWake()
            play(a)
            if (a.vibrate) vibrate()
            startActivity(Intent(this@AlarmRingService, AlarmRingActivity::class.java)
                .putExtra("id", id).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP))
            timeoutJob = launch { delay(a.timeoutMinutes * 60_000L); snooze(id) }
        }
        return START_NOT_STICKY
    }

    private fun startFg(a: Alarm) {
        val full = PendingIntent.getActivity(this, 0,
            Intent(this, AlarmRingActivity::class.java).putExtra("id", a.id), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val snooze = PendingIntent.getService(this, 1, Intent(this, javaClass).setAction(ACTION_SNOOZE).putExtra("id", a.id), PendingIntent.FLAG_IMMUTABLE)
        val dismiss = PendingIntent.getService(this, 2, Intent(this, javaClass).setAction(ACTION_DISMISS).putExtra("id", a.id), PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(this, HandyApp.CH_ALARM)
            .setSmallIcon(R.drawable.ic_notif)
            .setContentTitle(a.label.ifBlank { "Alarm" })
            .setContentText(String.format("%02d:%02d", a.hour, a.minute))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(full, true)
            .addAction(0, "Snooze ${a.snoozeMinutes}m", snooze)
            .addAction(0, "Dismiss", dismiss)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(NOTIF_ID, n)
    }

    private fun play(a: Alarm) {
        val uri: Uri = a.soundUri?.let { Uri.parse(it) } ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        val target = a.volume / 100f
        player = MediaPlayer().apply {
            setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            setDataSource(this@AlarmRingService, uri)
            isLooping = true
            setVolume(if (a.gradualSeconds > 0) 0.05f else target, if (a.gradualSeconds > 0) 0.05f else target)
            prepare(); start()
        }
        if (a.gradualSeconds > 0) rampJob = scope.launch {
            val steps = 20
            repeat(steps) { i ->
                delay(a.gradualSeconds * 1000L / steps)
                val v = 0.05f + (target - 0.05f) * (i + 1) / steps
                player?.setVolume(v, v)
            }
        }
    }

    private fun vibrate() {
        vib = if (Build.VERSION.SDK_INT >= 31) (getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        else @Suppress("DEPRECATION") getSystemService(VIBRATOR_SERVICE) as Vibrator
        vib?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 600, 400), 0),
            AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
    }

    private fun acquireWake() {
        wake = (getSystemService(POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "handytools:alarm").apply { acquire(15 * 60_000L) }
    }

    suspend fun snooze(id: Long) {
        val a = withContext(Dispatchers.IO) { HandyApp.instance.db.alarms().byId(id) } ?: return stopSelf()
        if (a.maxSnoozes > 0 && a.snoozedCount >= a.maxSnoozes) return dismiss(id)
        val until = System.currentTimeMillis() + a.snoozeMinutes * 60_000L
        val updated = a.copy(snoozeUntil = until, snoozedCount = a.snoozedCount + 1)
        withContext(Dispatchers.IO) { HandyApp.instance.db.alarms().upsert(updated) }
        AlarmScheduler(this).schedule(updated)
        finishRing()
    }

    suspend fun dismiss(id: Long) {
        val a = withContext(Dispatchers.IO) { HandyApp.instance.db.alarms().byId(id) } ?: return stopSelf()
        val updated = a.copy(snoozeUntil = null, snoozedCount = 0, enabled = a.repeatDays != 0)
        withContext(Dispatchers.IO) { HandyApp.instance.db.alarms().upsert(updated) }
        AlarmScheduler(this).schedule(updated)
        finishRing()
    }

    private fun finishRing() {
        current = null
        sendBroadcast(Intent(ACTION_FINISHED).setPackage(packageName))
        stopSelf()
    }

    override fun onDestroy() {
        rampJob?.cancel(); timeoutJob?.cancel()
        player?.stop(); player?.release(); player = null
        vib?.cancel()
        wake?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }

    companion object {
        const val ACTION_SNOOZE = "snooze"
        const val ACTION_DISMISS = "dismiss"
        const val ACTION_FINISHED = "com.handytools.app.ALARM_FINISHED"
        const val NOTIF_ID = 2001
        @Volatile var current: Alarm? = null
    }
}
