package com.handytools.app.tools.clipboard

import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.handytools.app.HandyApp
import com.handytools.app.R

/**
 * Hosts the floating clipboard bubble + history panel over other apps. Replaces the old
 * AccessibilityService host: the bubble is a draw-over-apps overlay, nothing more.
 */
class ClipboardBubbleService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) { stopSelf(); return START_NOT_STICKY }
        startFg()
        ClipboardOverlay.show(this)
        return START_STICKY
    }

    private fun startFg() {
        val stop = PendingIntent.getService(this, 7, Intent(this, javaClass).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(this, HandyApp.CH_TOOLS)
            .setSmallIcon(R.drawable.ic_notif)
            .setContentTitle("Clipboard bubble is on")
            .setContentText("Tap the bubble in any app to grab or re-copy a clip.")
            .addAction(0, "Stop", stop)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(7001, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(7001, n)
    }

    override fun onDestroy() {
        ClipboardOverlay.hide()
        super.onDestroy()
    }

    companion object { const val ACTION_STOP = "stop" }
}
