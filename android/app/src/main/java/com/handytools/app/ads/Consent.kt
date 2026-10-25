package com.handytools.app.ads

import android.app.Activity
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform

/**
 * Google UMP (User Messaging Platform) consent. Required before serving ads to users in the
 * EEA / UK / Switzerland; everywhere else `canRequestAds` is already true and [onReady] fires
 * immediately. The consent form (when one is required) is shown on [activity]; nothing here
 * blocks the UI. [onReady] is invoked at most once, only when ads may actually be requested.
 */
object Consent {
    fun gather(activity: Activity, onReady: () -> Unit) {
        var fired = false
        val once = { if (!fired) { fired = true; onReady() } }

        val info = UserMessagingPlatform.getConsentInformation(activity)
        val params = ConsentRequestParameters.Builder().build()
        info.requestConsentInfoUpdate(
            activity, params,
            {
                // Info updated — present the form if the user's region/status needs it, then
                // start ads if consent allows.
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) {
                    if (info.canRequestAds()) once()
                }
            },
            {
                // Update failed (offline, etc.): fall back to whatever consent state we have.
                if (info.canRequestAds()) once()
            },
        )
        // Returning users who already consented can serve ads without waiting for the update.
        if (info.canRequestAds()) once()
    }
}
