package com.handytools.app.tools.notifhistory

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.handytools.app.HandyApp
import com.handytools.app.data.NotifEntry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** Logs every notification as it arrives and marks when it's dismissed, so swipes aren't final. */
class NotifListenerService : NotificationListenerService() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        if (sbn.notification.flags and Notification.FLAG_ONGOING_EVENT != 0) return // skip media/FGS chatter
        val ex = sbn.notification.extras
        val title = ex.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = (ex.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: ex.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: ""
        if (title.isBlank() && text.isBlank()) return
        val appName = runCatching {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(sbn.packageName, 0)).toString()
        }.getOrDefault(sbn.packageName)
        scope.launch {
            val dao = HandyApp.instance.db.notifs()
            dao.insert(NotifEntry(pkg = sbn.packageName, appName = appName, title = title, text = text, postedAt = sbn.postTime))
            dao.prune(System.currentTimeMillis() - 7L * 24 * 3600 * 1000)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        val ex = sbn.notification.extras
        val title = ex.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = (ex.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: ex.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: ""
        scope.launch { HandyApp.instance.db.notifs().markDismissed(sbn.packageName, title, text, System.currentTimeMillis()) }
    }
}
