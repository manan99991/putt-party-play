package com.handytools.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.layout.Box
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Alarm
import androidx.compose.material.icons.outlined.AppShortcut
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Screenshot
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.TextFields
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import com.handytools.app.HandyApp
import com.handytools.app.ads.BannerAd

data class Tool(val route: String, val name: String, val blurb: String, val icon: ImageVector)

val TOOLS = listOf(
    Tool("clipboard", "Multi-Clipboard", "Copy 5 things, paste any of them", Icons.Outlined.ContentPaste),
    Tool("screenshot", "Screenshot+", "Floating button, full-page stitch", Icons.Outlined.Screenshot),
    Tool("quick", "Easy Buttons", "Light, hotspot, camera, video", Icons.Outlined.Bolt),
    Tool("shortcut", "Web → Home", "Paste a URL, get an icon", Icons.Outlined.AppShortcut),
    Tool("alarm", "Alarm Pro", "Own volume, own snooze, ramp-up", Icons.Outlined.Alarm),
    Tool("volume", "Volume Mixer", "Ring, media, alarm, notifications", Icons.Outlined.Tune),
    Tool("ocr", "Grab Screen Text", "OCR anything on screen", Icons.Outlined.TextFields),
    Tool("notifs", "Notification Log", "See what you swiped away", Icons.Outlined.Notifications),
    Tool("scratchpad", "Scratchpad Bubble", "Notes over any app", Icons.Outlined.EditNote),
    Tool("awake", "Keep Awake", "Screen stays on", Icons.Outlined.Visibility),
)

@Composable
fun HomeScreen(onOpen: (String) -> Unit) {
    val premium by HandyApp.instance.billing.isPremium.collectAsState()
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = HandyTokens.Gutter, vertical = HandyTokens.Space12),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text("HandyTools", style = MaterialTheme.typography.headlineMedium)
                Spacer(Modifier.height(HandyTokens.Space4))
                Text(if (premium) "Pro · no ads" else "10 tools your phone should've had",
                    style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
            }
            Row {
                if (!premium) IconButton(onClick = { onOpen("paywall") }) { Icon(Icons.Outlined.WorkspacePremium, "Go Pro", tint = HandyColors.Accent) }
                IconButton(onClick = { onOpen("settings") }) { Icon(Icons.Outlined.Settings, "Settings", tint = Handy.palette.textSecondary) }
            }
        }
        // Entrance: fade + 8dp slide, staggered 30ms, max 6 (crossfade under Reduce Motion).
        val reduceMotion = rememberReduceMotion()
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(start = HandyTokens.Gutter, end = HandyTokens.Gutter, top = HandyTokens.Space8, bottom = HandyTokens.Space16),
            horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space12),
            verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)
        ) {
            itemsIndexed(TOOLS, key = { _, t -> t.route }) { i, t ->
                Box(Modifier.handyListEnter(i, reduceMotion)) {
                    ToolCard(t.name, t.blurb, t.icon) { onOpen(t.route) }
                }
            }
        }
        BannerAd()
    }
}
