package com.handytools.app.tools.screenshot

import android.content.Intent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.handytools.app.Permissions
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.clipboard.ClipboardAccessibilityService
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.PermissionCard
import com.handytools.app.ui.ToolHeader
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HTextButton
import com.handytools.app.ui.LimitNote
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

    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
            ToolHeader("Screenshot+", "A red button floats over every app. Tap it to capture. Apps that block screenshots are respected.")
            PermissionCard("Draw over other apps", "Needed for the floating capture button.", overlay, Permissions.overlayIntent(ctx))
            Text("Mode", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(8.dp))
            // Hero: mode chips as three 72dp mini-illustrations (one frame / three stacked / one tall frame).
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                ModeChip("Single", mode == ScreenCaptureService.Mode.SINGLE, ScreenCaptureService.Mode.SINGLE) { mode = it }
                ModeChip("Full page", mode == ScreenCaptureService.Mode.FULL_PAGE, ScreenCaptureService.Mode.FULL_PAGE) { mode = it }
                ModeChip("Burst (3 shots)", mode == ScreenCaptureService.Mode.BURST, ScreenCaptureService.Mode.BURST) { mode = it }
            }
            if (mode == ScreenCaptureService.Mode.FULL_PAGE) {
                Spacer(Modifier.height(8.dp))
                PermissionCard("Accessibility access", "Full page needs Oddbox to scroll the page for you.", a11y, Permissions.accessibilityIntent(), "Open Accessibility settings")
            }
            Spacer(Modifier.height(24.dp))
            HPrimaryButton("Start floating button", enabled = overlay) { ProjectionPermissionActivity.launch(ctx, mode) }
            Spacer(Modifier.height(8.dp))
            HSecondaryButton("Stop") { ctx.startService(Intent(ctx, ScreenCaptureService::class.java).setAction(ScreenCaptureService.ACTION_STOP)) }
            LimitNote("Saved to Pictures/Oddbox.")
            Spacer(Modifier.weight(1f))
            BannerAd()
        }
        // Hero: realistic 56dp red capture-button preview floating at the right edge.
        Box(
            Modifier.align(Alignment.CenterEnd).size(56.dp).clip(CircleShape)
                .background(HandyColors.Danger),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Outlined.PhotoCamera, null, Modifier.size(28.dp), tint = Color.White)
        }
    }
}

/**
 * 72dp mode illustration chip. Selected = accent border; unselected = hairline border.
 * Drawings: SINGLE = one frame, FULL_PAGE = three stacked frames, BURST = one tall frame.
 */
@Composable
private fun ModeChip(label: String, selected: Boolean, mode: ScreenCaptureService.Mode, onSelect: (ScreenCaptureService.Mode) -> Unit) {
    val ctx = LocalContext.current
    val src = remember { MutableInteractionSource() }
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.clickable(
        interactionSource = src, indication = ripple(bounded = false)
    ) {
        HandyHaptics.light(ctx)
        onSelect(mode)
    }) {
        Box(
            Modifier.size(72.dp)
                .border(
                    width = if (selected) 2.dp else 1.dp,
                    color = if (selected) HandyColors.Accent else Handy.palette.border,
                    shape = RoundedCornerShape(12.dp)
                ),
            contentAlignment = Alignment.Center
        ) {
            val ink = if (selected) HandyColors.Accent else Handy.palette.textSecondary
            Canvas(Modifier.size(48.dp)) {
                val stroke = Stroke(width = 4f)
                val r = CornerRadius(6f, 6f)
                when (mode) {
                    ScreenCaptureService.Mode.SINGLE ->
                        drawRoundRect(ink, topLeft = androidx.compose.ui.geometry.Offset(8f, 12f),
                            size = androidx.compose.ui.geometry.Size(size.width - 16f, size.height - 24f), cornerRadius = r, style = stroke)
                    ScreenCaptureService.Mode.FULL_PAGE -> {
                        for (i in 0..2) drawRoundRect(ink,
                            topLeft = androidx.compose.ui.geometry.Offset(12f + i * 6f, 6f + i * 12f),
                            size = androidx.compose.ui.geometry.Size(size.width - 24f - i * 12f, 18f),
                            cornerRadius = r, style = stroke)
                    }
                    ScreenCaptureService.Mode.OCR -> Unit
                ScreenCaptureService.Mode.BURST ->
                        drawRoundRect(ink, topLeft = androidx.compose.ui.geometry.Offset(14f, 2f),
                            size = androidx.compose.ui.geometry.Size(size.width - 28f, size.height - 4f), cornerRadius = r, style = stroke)
                }
            }
        }
        Spacer(Modifier.height(4.dp))
        Text(label, style = MaterialTheme.typography.labelSmall,
            color = if (selected) HandyColors.Accent else Handy.palette.textSecondary)
    }
}
