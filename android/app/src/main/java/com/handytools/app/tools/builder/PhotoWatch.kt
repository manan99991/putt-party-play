package com.handytools.app.tools.builder

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.ContentUris
import android.content.Context
import android.os.Build
import android.provider.MediaStore

/**
 * Lets a tool offer itself when a new photo or screenshot appears. The system wakes this job when the photo library
 * changes (no service running in between, nothing in the status bar). It only ever shows a notification: the tool runs
 * when the person taps it. Armed only while at least one saved tool asks for it.
 */
object PhotoWatch {
    private const val JOB = 7301
    private const val PREFS = "builder"
    private const val LAST = "autoLastId"

    fun arm(ctx: Context) {
        val js = ctx.getSystemService(JobScheduler::class.java) ?: return
        if (ChainStore.load(ctx).none { it.auto.isNotEmpty() }) { js.cancel(JOB); return }
        val job = JobInfo.Builder(JOB, ComponentName(ctx, PhotoWatchJob::class.java))
            .addTriggerContentUri(JobInfo.TriggerContentUri(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, JobInfo.TriggerContentUri.FLAG_NOTIFY_FOR_DESCENDANTS))
            .setTriggerContentUpdateDelay(1500)
            .setTriggerContentMaxDelay(8000)
            .build()
        runCatching { js.schedule(job) }
    }

    /** Look at the newest picture; if it is new, recent and not one Tenzy saved itself, let the matching tools offer themselves. */
    fun handle(ctx: Context) {
        val tools = ChainStore.load(ctx).filter { it.auto.isNotEmpty() }
        if (tools.isEmpty()) return
        val folderCol = if (Build.VERSION.SDK_INT >= 29) MediaStore.Images.Media.RELATIVE_PATH else MediaStore.Images.Media.DATA
        val cols = if (Build.VERSION.SDK_INT >= 29)
            arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.DISPLAY_NAME, MediaStore.Images.Media.DATE_ADDED, folderCol, MediaStore.Images.Media.OWNER_PACKAGE_NAME)
        else arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.DISPLAY_NAME, MediaStore.Images.Media.DATE_ADDED, folderCol)
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val last = prefs.getLong(LAST, -1L)
        ctx.contentResolver.query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, cols, null, null, MediaStore.Images.Media.DATE_ADDED + " DESC")?.use { c ->
            if (!c.moveToFirst()) return
            val id = c.getLong(0)
            val name = c.getString(1).orEmpty()
            val addedSec = c.getLong(2)
            val folder = c.getString(3).orEmpty()
            val owner = if (cols.size > 4) c.getString(4).orEmpty() else ""
            if (id == last) return                                                    // already offered
            prefs.edit().putLong(LAST, id).apply()
            if (System.currentTimeMillis() / 1000 - addedSec > 120) return            // an old picture changed, not a new one
            if (owner == ctx.packageName) return                                      // Tenzy's own saved result
            val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
            val shot = AutoRun.isScreenshot(folder, name)
            tools.filter { AutoRun.wants(it.auto, folder, name) }.take(3).forEach { t ->
                ToolReminders.post(ctx, ("auto-" + t.id).hashCode(), t.name, if (shot) "New screenshot. Tap to run this tool on it." else "New photo. Tap to run this tool on it.", t.id, uri)
            }
        }
    }
}

class PhotoWatchJob : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        val app = applicationContext
        Thread {
            runCatching { PhotoWatch.handle(app) }
            PhotoWatch.arm(app)                 // a content-trigger job fires once, so arm it again for the next photo
            jobFinished(params, false)
        }.start()
        return true
    }
    override fun onStopJob(params: JobParameters): Boolean = false
}
