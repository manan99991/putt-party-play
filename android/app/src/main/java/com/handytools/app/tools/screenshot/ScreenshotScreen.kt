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
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HTextButton
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.ChipRow
import com.handytools.app.ui.SliderRow
import com.handytools.app.ui.LimitNote
import com.handytools.app.ui.EmptyState
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyTokens

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
        ChipRow {
            HChip("Single", mode == ScreenCaptureService.Mode.SINGLE) { mode = ScreenCaptureService.Mode.SINGLE }
            HChip("Full page", mode == ScreenCaptureService.Mode.FULL_PAGE) { mode = ScreenCaptureService.Mode.FULL_PAGE }
            HChip("Burst (3 shots)", mode == ScreenCaptureService.Mode.BURST) { mode = ScreenCaptureService.Mode.BURST }
        }
        if (mode == ScreenCaptureService.Mode.FULL_PAGE) {
            Spacer(Modifier.height(8.dp))
            PermissionCard("Accessibility access", "Full page needs HandyTools to scroll the page for you.", a11y, Permissions.accessibilityIntent(), "Open Accessibility settings")
        }
        Spacer(Modifier.height(24.dp))
        HPrimaryButton("Start floating button", enabled = overlay) { ProjectionPermissionActivity.launch(ctx, mode) }
        Spacer(Modifier.height(8.dp))
        HSecondaryButton("Stop") { ctx.startService(Intent(ctx, ScreenCaptureService::class.java).setAction(ScreenCaptureService.ACTION_STOP)) }
        LimitNote("Saved to Pictures/HandyTools.")
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}
