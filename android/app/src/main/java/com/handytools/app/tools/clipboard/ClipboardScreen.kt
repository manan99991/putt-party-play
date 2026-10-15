package com.handytools.app.tools.clipboard

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.handytools.app.HandyApp
import com.handytools.app.Permissions
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.BigToggle
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
import com.handytools.app.ui.rememberReduceMotion
import com.handytools.app.ui.handyListEnter
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyTokens

@Composable
fun ClipboardScreen() {
    val ctx = LocalContext.current
    var a11y by remember { mutableStateOf(Permissions.accessibilityEnabled(ctx, ClipboardAccessibilityService::class.java)) }
    var overlay by remember { mutableStateOf(Permissions.canOverlay(ctx)) }
    var on by remember { mutableStateOf(ClipboardOverlay.isEnabled(ctx)) }
    LifecycleResumeEffect(Unit) {
        a11y = Permissions.accessibilityEnabled(ctx, ClipboardAccessibilityService::class.java)
        overlay = Permissions.canOverlay(ctx)
        onPauseOrDispose { }
    }
    val clips by HandyApp.instance.db.clips().all().collectAsState(initial = emptyList())

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Multi-Clipboard", "Turn it on, copy as many things as you want in any app, then tap the bubble to paste any of them.")
        PermissionCard("Accessibility access", "This is how HandyTools sees copies from other apps.", a11y, Permissions.accessibilityIntent(), "Open Accessibility settings", privacy = "Text stays on your phone. Nothing is uploaded.")
        PermissionCard("Draw over other apps", "Needed for the floating bubble.", overlay, Permissions.overlayIntent(ctx))
        BigToggle("Clipboard bubble", on && a11y && overlay) { v ->
            on = v; ClipboardOverlay.setEnabled(ctx, v)
        }
        Text("History", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp, bottom = 8.dp))
        val reduceMotion = rememberReduceMotion()
        if (clips.isEmpty()) {
            Column(Modifier.weight(1f)) { EmptyState(androidx.compose.material.icons.Icons.Outlined.ContentPaste, "Copy something in any app — it shows up here.") }
        } else LazyColumn(Modifier.weight(1f), verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp)) {
            itemsIndexed(clips, key = { _, c -> c.id }) { i, c ->
                HCard(Modifier.fillMaxWidth().handyListEnter(i, reduceMotion), onClick = {
                    (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
                        .setPrimaryClip(ClipData.newPlainText("HandyTools", c.text))
                    ClipboardOverlay.lastPastedText = c.text
                }) {
                    Text((if (c.pinned) "📌 " else "") + c.text, Modifier.padding(14.dp), maxLines = 3, style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
        BannerAd()
    }
}
