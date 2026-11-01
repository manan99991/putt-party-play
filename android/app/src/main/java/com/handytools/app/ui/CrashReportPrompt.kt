package com.handytools.app.ui

import android.content.Intent
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.handytools.app.CrashReporter

/**
 * Shown once over the home screen when a crash report from a previous run is waiting. One tap sends
 * the saved stack trace (via the share sheet) so it reaches the dev instead of being screenshotted.
 */
@Composable
fun CrashReportPrompt() {
    val ctx = LocalContext.current
    var show by remember { mutableStateOf(CrashReporter.hasPending(ctx)) }
    if (!show) return
    AlertDialog(
        onDismissRequest = { show = false },
        title = { Text("Tenzy hit a snag last time") },
        text = { Text("A crash report was saved on this phone. Send it so the bug can be fixed? Nothing is uploaded unless you tap Send.") },
        confirmButton = {
            TextButton(onClick = {
                runCatching { ctx.startActivity(Intent.createChooser(CrashReporter.shareIntent(ctx), "Send crash report")) }
                CrashReporter.clear(ctx)
                show = false
            }) { Text("Send report") }
        },
        dismissButton = {
            TextButton(onClick = { CrashReporter.clear(ctx); show = false }) { Text("Dismiss") }
        }
    )
}
