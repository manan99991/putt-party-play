package com.handytools.app.tools.clipboard

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
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
import com.handytools.app.ui.EmptyState
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.PermissionCard
import com.handytools.app.ui.ToolHeader
import com.handytools.app.ui.handyListEnter
import com.handytools.app.ui.rememberReduceMotion

@Composable
fun ClipboardScreen() {
    val ctx = LocalContext.current
    var overlay by remember { mutableStateOf(Permissions.canOverlay(ctx)) }
    var on by remember { mutableStateOf(ClipboardOverlay.isEnabled(ctx)) }
    LifecycleResumeEffect(Unit) {
        overlay = Permissions.canOverlay(ctx)
        onPauseOrDispose { }
    }
    val clips by HandyApp.instance.db.clips().all().collectAsState(initial = emptyList())

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Multi-Clipboard", "Save as many clips as you like and paste any of them later. Three one-tap ways to capture — pick whatever's handy.")

        Text("3 ways to save a clip", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 8.dp, bottom = 4.dp))
        Text(
            "1.  In any app, select text → Share → “Save to Tenzy”.\n" +
            "2.  Add the Tenzy “Save clip” tile to Quick Settings — one tap from the shade.\n" +
            "3.  Copy something, then tap the button below (or “+ Grab copy” on the bubble).",
            style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary
        )
        Spacer(Modifier.height(12.dp))
        HPrimaryButton("Save what I just copied") {
            ctx.startActivity(SaveClipActivity.grabIntent(ctx))
        }
        Spacer(Modifier.height(16.dp))

        PermissionCard(
            "Floating bubble (optional)",
            "Draw-over-apps lets a bubble follow you into other apps so your clips are one tap away anywhere. Not required — the tool works without it.",
            overlay, Permissions.overlayIntent(ctx)
        )
        BigToggle("Clipboard bubble", on && overlay) { v ->
            on = v; ClipboardOverlay.setEnabled(ctx, v)
        }

        Text("History", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp, bottom = 8.dp))
        val reduceMotion = rememberReduceMotion()
        if (clips.isEmpty()) {
            Column(Modifier.weight(1f)) { EmptyState(Icons.Outlined.ContentPaste, "No clips yet — save one with any of the three ways above.") }
        } else LazyColumn(Modifier.weight(1f), verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp)) {
            itemsIndexed(clips, key = { _, c -> c.id }) { i, c ->
                HCard(Modifier.fillMaxWidth().handyListEnter(i, reduceMotion), onClick = {
                    (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
                        .setPrimaryClip(ClipData.newPlainText("Tenzy", c.text))
                    android.widget.Toast.makeText(ctx, "Copied — paste it anywhere", android.widget.Toast.LENGTH_SHORT).show()
                }) {
                    Text((if (c.pinned) "📌 " else "") + c.text, Modifier.padding(14.dp), maxLines = 3, style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
        BannerAd()
    }
}
