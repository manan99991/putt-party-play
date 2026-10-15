package com.handytools.app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
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

    override fun onCreate() {
        super.onCreate()
        instance = this
        db = AppDb.get(this)
        billing = BillingManager(this)
        billing.start()
        MobileAds.initialize(this) {}
        createChannels()
        CoroutineScope(Dispatchers.IO).launch { AlarmScheduler(this@HandyApp).rescheduleAll() }
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
