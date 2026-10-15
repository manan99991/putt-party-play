package com.handytools.app

import android.app.Activity
import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Bundle
import androidx.core.view.doOnPreDraw
import com.google.android.gms.ads.MobileAds
import com.handytools.app.billing.BillingManager
import com.handytools.app.data.AppDb
import com.handytools.app.tools.alarm.AlarmScheduler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class HandyApp : Application() {

    lateinit var db: AppDb; private set
    lateinit var billing: BillingManager; private set
    private var deferredInitDone = false

    override fun onCreate() {
        super.onCreate()
        instance = this
        db = AppDb.get(this)
        // Pre-warm Room off the main thread so the first DB read never blocks UI.
        CoroutineScope(Dispatchers.IO).launch { db.openHelper.writableDatabase.close() }
        billing = BillingManager(this)
        createChannels()
        CoroutineScope(Dispatchers.IO).launch { AlarmScheduler(this@HandyApp).rescheduleAll() }
        scheduleDeferredInit()
    }

    /**
     * AdMob init + billing connection are deferred until after the first frame so cold start
     * stays under 800ms. No network on the main thread before first draw.
     */
    private fun scheduleDeferredInit() {
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                if (deferredInitDone) return
                activity.window.decorView.doOnPreDraw {
                    if (!deferredInitDone) {
                        deferredInitDone = true
                        // MEASURE: cold-start timing ends here (first frame drawn). CI fills in
                        // Macrobenchmark StartupTimingMetric before/after numbers.
                        MobileAds.initialize(this@HandyApp) {}
                        billing.start()
                    }
                }
            }
            override fun onActivityStarted(activity: Activity) {}
            override fun onActivityResumed(activity: Activity) {}
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivityStopped(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })
    }

    private fun createChannels() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CH_TOOLS, getString(R.string.channel_tools), NotificationManager.IMPORTANCE_LOW)
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_ALARM, getString(R.string.channel_alarm), NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(null, null) // we play audio ourselves on the ALARM stream
                enableVibration(true)
            }
        )
    }

    companion object {
        const val CH_TOOLS = "tools"
        const val CH_ALARM = "alarm"
        lateinit var instance: HandyApp; private set
    }
}
