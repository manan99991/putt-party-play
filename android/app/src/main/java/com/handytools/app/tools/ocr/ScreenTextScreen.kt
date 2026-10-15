package com.handytools.app.tools.ocr

import android.content.Intent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.handytools.app.Permissions
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.screenshot.ProjectionPermissionActivity
import com.handytools.app.tools.screenshot.ScreenCaptureService
import com.handytools.app.ui.PermissionCard
import com.handytools.app.ui.ToolHeader

@Composable
fun ScreenTextScreen() {
    val ctx = LocalContext.current
    var overlay by remember { mutableStateOf(Permissions.canOverlay(ctx)) }
    LifecycleResumeEffect(Unit) { overlay = Permissions.canOverlay(ctx); onPauseOrDispose { } }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Grab Screen Text", "A floating button that copies every word on screen — from apps that don't let you select text.")
        PermissionCard("Draw over other apps", "Needed for the floating button.", overlay, Permissions.overlayIntent(ctx))
        Button(onClick = { ProjectionPermissionActivity.launch(ctx, ScreenCaptureService.Mode.OCR) }, enabled = overlay, modifier = Modifier.fillMaxWidth()) {
            Text("Start text grabber")
        }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = {
            ctx.startService(Intent(ctx, ScreenCaptureService::class.java).setAction(ScreenCaptureService.ACTION_STOP))
        }, modifier = Modifier.fillMaxWidth()) { Text("Stop") }
        Spacer(Modifier.height(12.dp))
        Text("Grabbed text goes to the clipboard and into your Multi-Clipboard history. Works offline.",
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}
