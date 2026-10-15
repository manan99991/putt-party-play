package com.handytools.app.tools.notifhistory

import androidx.compose.ui.draw.alpha
import android.content.Intent
import android.text.format.DateUtils
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.handytools.app.HandyApp
import com.handytools.app.Permissions
import com.handytools.app.ads.BannerAd
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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun NotifHistoryScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var granted by remember { mutableStateOf(Permissions.notifListenerEnabled(ctx)) }
    LifecycleResumeEffect(Unit) { granted = Permissions.notifListenerEnabled(ctx); onPauseOrDispose { } }
    val items by HandyApp.instance.db.notifs().all().collectAsState(initial = emptyList())

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            ToolHeader("Notification Log", "Everything from the last 7 days, including what you swiped away.")
            HTextButton("Clear") { scope.launch { withContext(Dispatchers.IO) { HandyApp.instance.db.notifs().clear() } } }
        }
        PermissionCard("Notification access", "Lets HandyTools keep a copy of notifications so you can re-read them.", granted, Permissions.notifListenerIntent(), "Open settings", privacy = "Stored on your phone only. Nothing is uploaded.")
        if (items.isEmpty()) {
            Column(Modifier.weight(1f)) { EmptyState(androidx.compose.material.icons.Icons.Outlined.Notifications, "Nothing logged yet.", "Notifications appear here as they arrive.") }
        } else LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(items, key = { it.id }) { n ->
                HCard(Modifier.fillMaxWidth().alpha(if (n.dismissedAt != null) 0.6f else 1f), onClick = {
                    ctx.packageManager.getLaunchIntentForPackage(n.pkg)?.let { ctx.startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                }) {
                    Column(Modifier.padding(12.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(n.appName, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                            Text(DateUtils.getRelativeTimeSpanString(n.postedAt).toString() + if (n.dismissedAt != null) " · dismissed" else "",
                                style = MaterialTheme.typography.labelSmall)
                        }
                        if (n.title.isNotBlank()) Text(n.title, fontWeight = FontWeight.SemiBold)
                        if (n.text.isNotBlank()) Text(n.text, style = MaterialTheme.typography.bodyMedium, maxLines = 4)
                    }
                }
            }
        }
        BannerAd()
    }
}
