package com.handytools.app.tools.awake

import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import com.handytools.app.HandyApp
import com.handytools.app.R
import com.handytools.app.tools.scratchpad.ServiceState

/**
 * Holds a SCREEN_BRIGHT_WAKE_LOCK so the screen never dims or locks (recipes, video calls on
 * speaker, following a map). Optional auto-off after N minutes so a forgotten toggle doesn't
 * drain the battery overnight.
 */
class KeepAwakeService : Service() {

    private var lock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) { stopSelf(); return START_NOT_STICKY }
        val minutes = intent?.getIntExtra("minutes", 0) ?: 0
        val stop = PendingIntent.getService(this, 4, Intent(this, javaClass).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(this, HandyApp.CH_TOOLS)
            .setSmallIcon(R.drawable.ic_notif)
            .setContentTitle("Screen will stay on" + if (minutes > 0) " for $minutes min" else "")
            .addAction(0, "Turn off", stop).setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(4001, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE) else startForeground(4001, n)

        @Suppress("DEPRECATION")
        lock = (getSystemService(POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ON_AFTER_RELEASE, "handytools:awake").apply {
                if (minutes > 0) acquire(minutes * 60_000L) else acquire()
            }
        ServiceState.awake = true
        return START_STICKY
    }

    override fun onDestroy() {
        lock?.let { if (it.isHeld) it.release() }
        ServiceState.awake = false
        super.onDestroy()
    }

    companion object { const val ACTION_STOP = "stop" }
}
