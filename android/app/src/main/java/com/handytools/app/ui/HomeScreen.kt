package com.handytools.app.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.AppShortcut
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.ContentPaste
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Screenshot
import androidx.compose.material.icons.filled.TextFields
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Card
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
import androidx.compose.ui.unit.dp
import com.handytools.app.HandyApp
import com.handytools.app.ads.BannerAd

data class Tool(val route: String, val name: String, val blurb: String, val icon: ImageVector)

val TOOLS = listOf(
    Tool("clipboard", "Multi-Clipboard", "Copy 5 things, paste any of them", Icons.Default.ContentPaste),
    Tool("screenshot", "Screenshot+", "Floating button, full-page stitch", Icons.Default.Screenshot),
    Tool("quick", "Easy Buttons", "Light, hotspot, camera, video", Icons.Default.Bolt),
    Tool("shortcut", "Web → Home", "Paste a URL, get an icon", Icons.Default.AppShortcut),
    Tool("alarm", "Alarm Pro", "Own volume, own snooze, ramp-up", Icons.Default.Alarm),
    Tool("volume", "Volume Mixer", "Ring, media, alarm, notifications", Icons.Default.Tune),
    Tool("ocr", "Grab Screen Text", "OCR anything on screen", Icons.Default.TextFields),
    Tool("notifs", "Notification Log", "See what you swiped away", Icons.Default.Notifications),
    Tool("scratchpad", "Scratchpad Bubble", "Notes over any app", Icons.Default.EditNote),
    Tool("awake", "Keep Awake", "Screen stays on", Icons.Default.Visibility),
)

@Composable
fun HomeScreen(onOpen: (String) -> Unit) {
    val premium by HandyApp.instance.billing.isPremium.collectAsState()
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text("HandyTools", style = MaterialTheme.typography.headlineMedium)
                Text(if (premium) "Pro · no ads" else "10 tools your phone should've had",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (!premium) IconButton(onClick = { onOpen("paywall") }) {
                Icon(Icons.Default.WorkspacePremium, "Go Pro", tint = MaterialTheme.colorScheme.primary)
            }
        }
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(TOOLS) { t ->
                Card(Modifier.fillMaxWidth().height(132.dp).clickable { onOpen(t.route) }) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.SpaceBetween) {
                        Icon(t.icon, null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.weight(1f))
                        Text(t.name, style = MaterialTheme.typography.titleMedium)
                        Text(t.blurb, style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2)
                    }
                }
            }
        }
        Box(Modifier.fillMaxWidth()) { BannerAd() }
    }
}
