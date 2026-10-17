package com.handytools.app.tools.clipboard

import android.app.PendingIntent
import android.os.Build
import android.service.quicksettings.TileService

/**
 * Quick-Settings tile: pull down the shade, tap "Save clip", and whatever you just copied lands
 * in Tenzy — from any app, one tap, no Accessibility. The tile launches [SaveClipActivity], which
 * reads the clipboard while briefly foreground (the compliant way to read it).
 */
class ClipSaveTileService : TileService() {
    override fun onClick() {
        super.onClick()
        val i = SaveClipActivity.grabIntent(this)
        if (Build.VERSION.SDK_INT >= 34) {
            val pi = PendingIntent.getActivity(this, 0, i, PendingIntent.FLAG_IMMUTABLE)
            startActivityAndCollapse(pi)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(i)
        }
    }
}
