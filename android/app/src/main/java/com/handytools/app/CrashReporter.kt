package com.handytools.app

import android.content.Context
import android.content.Intent
import android.os.Build
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Dependency-free crash capture. On an uncaught exception (any thread) it writes a plain-text
 * report — app + device info plus the full stack trace — into filesDir/crashes/, then hands off to
 * the platform's own handler so Android still shows its dialog. Nothing is uploaded anywhere; the
 * report sits on the device until the user taps "Send" in the on-launch prompt (a share sheet) or
 * clears it. This is what turns "the app has a bug" into an actual stack trace the dev can act on.
 */
object CrashReporter {

    private const val DIR = "crashes"
    private const val MAX_FILES = 20

    fun install(app: Context) {
        val prev = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try { write(app, thread, throwable) } catch (_: Throwable) { /* never mask the real crash */ }
            prev?.uncaughtException(thread, throwable)
        }
    }

    private fun dir(ctx: Context): File = File(ctx.filesDir, DIR).apply { mkdirs() }

    private fun write(ctx: Context, thread: Thread, t: Throwable) {
        val ts = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
        val stack = StringWriter().also { t.printStackTrace(PrintWriter(it)) }.toString()
        val report = buildString {
            appendLine("Tenzy crash report")
            appendLine("When:     $ts")
            appendLine("App:      ${BuildConfig.VERSION_NAME} (build ${BuildConfig.VERSION_CODE})")
            appendLine("Android:  ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
            appendLine("Device:   ${Build.MANUFACTURER} ${Build.MODEL}")
            appendLine("Thread:   ${thread.name}")
            appendLine("Message:  ${t.message ?: t.javaClass.simpleName}")
            appendLine()
            append(stack)
        }
        File(dir(ctx), "crash_${System.currentTimeMillis()}.txt").writeText(report)
        prune(ctx)
    }

    private fun prune(ctx: Context) {
        val files = dir(ctx).listFiles()?.sortedByDescending { it.lastModified() } ?: return
        files.drop(MAX_FILES).forEach { runCatching { it.delete() } }
    }

    /** Most recent crash reports, newest first. */
    fun reports(ctx: Context): List<File> =
        dir(ctx).listFiles()?.sortedByDescending { it.lastModified() } ?: emptyList()

    fun hasPending(ctx: Context): Boolean = reports(ctx).isNotEmpty()

    /** Combined text of the most recent reports (capped), for sharing. */
    fun latestText(ctx: Context, limit: Int = 3): String =
        reports(ctx).take(limit).joinToString("\n\n— — — — —\n\n") { it.readText() }

    fun clear(ctx: Context) {
        dir(ctx).listFiles()?.forEach { runCatching { it.delete() } }
    }

    /** A plain-text share intent carrying the latest reports — no FileProvider needed. */
    fun shareIntent(ctx: Context): Intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, "Tenzy crash report — build ${BuildConfig.VERSION_CODE}")
        putExtra(Intent.EXTRA_TEXT, latestText(ctx))
    }
}
