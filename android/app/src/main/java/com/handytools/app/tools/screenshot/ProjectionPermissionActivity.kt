package com.handytools.app.tools.screenshot

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import androidx.core.content.ContextCompat

/**
 * Invisible activity: asks Android for screen-capture consent, then hands the token to the
 * service. Android requires this consent every time a projection is started.
 */
class ProjectionPermissionActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(mpm.createScreenCaptureIntent(), REQ)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQ && resultCode == RESULT_OK && data != null) {
            val mode = intent.getStringExtra("mode") ?: ScreenCaptureService.Mode.SINGLE.name
            val i = Intent(this, ScreenCaptureService::class.java)
                .setAction(ScreenCaptureService.ACTION_START)
                .putExtra("code", resultCode)
                .putExtra("data", data)
                .putExtra("mode", mode)
            ContextCompat.startForegroundService(this, i)
        }
        finish()
    }

    companion object {
        private const val REQ = 42
        fun launch(ctx: Context, mode: ScreenCaptureService.Mode) {
            ctx.startActivity(
                Intent(ctx, ProjectionPermissionActivity::class.java)
                    .putExtra("mode", mode.name)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }
}
