package com.handytools.app.tools.screenshot

import android.content.Intent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
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
import com.handytools.app.tools.clipboard.ClipboardAccessibilityService
import com.handytools.app.ui.PermissionCard
import com.handytools.app.ui.ToolHeader

@Composable
fun ScreenshotScreen() {
    val ctx = LocalContext.current
    var overlay by remember { mutableStateOf(Permissions.canOverlay(ctx)) }
    var a11y by remember { mutableStateOf(Permissions.accessibilityEnabled(ctx, ClipboardAccessibilityService::class.java)) }
    var mode by remember { mutableStateOf(ScreenCaptureService.Mode.SINGLE) }
    LifecycleResumeEffect(Unit) {
        overlay = Permissions.canOverlay(ctx)
        a11y = Permissions.accessibilityEnabled(ctx, ClipboardAccessibilityService::class.java)
        onPauseOrDispose { }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Screenshot+", "A red button floats over every app. Tap it to capture. Apps that block screenshots are respected.")
        PermissionCard("Draw over other apps", "Needed for the floating capture button.", overlay, Permissions.overlayIntent(ctx))
        Text("Mode", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        androidx.compose.foundation.layout.Row {
            FilterChip(selected = mode == ScreenCaptureService.Mode.SINGLE, onClick = { mode = ScreenCaptureService.Mode.SINGLE }, label = { Text("Single") })
            Spacer(Modifier.padding(4.dp))
            FilterChip(selected = mode == ScreenCaptureService.Mode.FULL_PAGE, onClick = { mode = ScreenCaptureService.Mode.FULL_PAGE }, label = { Text("Full page") })
            Spacer(Modifier.padding(4.dp))
            FilterChip(selected = mode == ScreenCaptureService.Mode.BURST, onClick = { mode = ScreenCaptureService.Mode.BURST }, label = { Text("Burst ×3") })
        }
        if (mode == ScreenCaptureService.Mode.FULL_PAGE) {
            Spacer(Modifier.height(8.dp))
            PermissionCard("Accessibility access", "Full page needs HandyTools to scroll the page for you.", a11y, Permissions.accessibilityIntent(), "Open Accessibility settings")
        }
        Spacer(Modifier.height(24.dp))
        Button(onClick = { ProjectionPermissionActivity.launch(ctx, mode) }, enabled = overlay, modifier = Modifier.fillMaxWidth()) {
            Text("Start floating button")
        }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = {
            ctx.startService(Intent(ctx, ScreenCaptureService::class.java).setAction(ScreenCaptureService.ACTION_STOP))
        }, modifier = Modifier.fillMaxWidth()) { Text("Stop") }
        Spacer(Modifier.height(8.dp))
        Text("Saved to Pictures/HandyTools.", style = MaterialTheme.typography.bodySmall)
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}
