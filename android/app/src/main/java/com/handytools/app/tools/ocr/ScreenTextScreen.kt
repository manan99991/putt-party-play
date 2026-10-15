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
fun ScreenTextScreen() {
    val ctx = LocalContext.current
    var overlay by remember { mutableStateOf(Permissions.canOverlay(ctx)) }
    LifecycleResumeEffect(Unit) { overlay = Permissions.canOverlay(ctx); onPauseOrDispose { } }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Grab Screen Text", "A floating button that copies every word on screen — from apps that don't let you select text.")
        PermissionCard("Draw over other apps", "Needed for the floating button.", overlay, Permissions.overlayIntent(ctx))
        // Hero: 3-line sample of "grabbed" text in a monospace block with a blinking caret.
        GrabbedSample()
        Spacer(Modifier.height(16.dp))
        HPrimaryButton("Start text grabber", enabled = overlay) { ProjectionPermissionActivity.launch(ctx, ScreenCaptureService.Mode.OCR) }
        Spacer(Modifier.height(8.dp))
        HSecondaryButton("Stop") { ctx.startService(Intent(ctx, ScreenCaptureService::class.java).setAction(ScreenCaptureService.ACTION_STOP)) }
        LimitNote("Grabbed text goes to the clipboard and into your Multi-Clipboard history. Works offline.")
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

/**
 * Hero: a 3-line sample of "grabbed" text in a monospace block with a blinking caret,
 * showing what the grabber pulls off the screen.
 */
@Composable
private fun GrabbedSample() {
    val reduceMotion = com.handytools.app.ui.rememberReduceMotion()
    var caretOn by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(true) }
    androidx.compose.runtime.LaunchedEffect(reduceMotion) {
        while (true) {
            kotlinx.coroutines.delay(530)
            if (!reduceMotion) caretOn = !caretOn
        }
    }
    com.handytools.app.ui.HCard(Modifier.fillMaxWidth()) {
        androidx.compose.foundation.layout.Column(Modifier.padding(16.dp)) {
            val mono = androidx.compose.ui.text.font.FontFamily.Monospace
            Text("Total: $42.50", style = MaterialTheme.typography.bodyMedium.copy(fontFamily = mono))
            Text("Arriving Thursday, 9:41 AM", style = MaterialTheme.typography.bodyMedium.copy(fontFamily = mono))
            androidx.compose.foundation.layout.Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                Text("Confirmation 8X2K-44QZ", style = MaterialTheme.typography.bodyMedium.copy(fontFamily = mono))
                if (caretOn || reduceMotion) {
                    androidx.compose.foundation.layout.Spacer(Modifier.width(4.dp))
                    androidx.compose.foundation.layout.Box(
                        Modifier.width(2.dp).height(18.dp)
                            .background(com.handytools.app.ui.HandyColors.Accent)
                    )
                }
            }
        }
    }
}
