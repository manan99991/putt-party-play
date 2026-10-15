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
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
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
        PermissionCard("Accessibility access", "This is how HandyTools sees copies from other apps. Text stays on your phone.", a11y, Permissions.accessibilityIntent(), "Open Accessibility settings")
        PermissionCard("Draw over other apps", "Needed for the floating bubble.", overlay, Permissions.overlayIntent(ctx))
        BigToggle("Clipboard bubble", on && a11y && overlay) { v ->
            on = v; ClipboardOverlay.setEnabled(ctx, v)
        }
        Text("History", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp, bottom = 8.dp))
        LazyColumn(Modifier.weight(1f)) {
            items(clips, key = { it.id }) { c ->
                Card(Modifier.fillMaxWidth().padding(vertical = 4.dp).clickable {
                    (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
                        .setPrimaryClip(ClipData.newPlainText("HandyTools", c.text))
                    ClipboardOverlay.lastPastedText = c.text
                }) {
                    Text(c.text, Modifier.padding(12.dp), maxLines = 3)
                }
            }
        }
        BannerAd()
    }
}
