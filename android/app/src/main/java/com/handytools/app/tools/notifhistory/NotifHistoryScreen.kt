package com.handytools.app.tools.notifhistory

import androidx.compose.ui.draw.alpha
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.text.format.DateUtils
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
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
import com.handytools.app.ui.handyListEnter
import com.handytools.app.ui.rememberReduceMotion
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun NotifHistoryScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var granted by remember { mutableStateOf(Permissions.notifListenerEnabled(ctx)) }
    LifecycleResumeEffect(Unit) { granted = Permissions.notifListenerEnabled(ctx); onPauseOrDispose { } }
    val reduceMotion = rememberReduceMotion()
    val items by HandyApp.instance.db.notifs().all().collectAsStateWithLifecycle(initialValue = emptyList())

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            ToolHeader("Notification Log", "Everything from the last 7 days, including what you swiped away.")
            HTextButton("Clear") { scope.launch { withContext(Dispatchers.IO) { HandyApp.instance.db.notifs().clear() } } }
        }
        PermissionCard("Notification access", "Lets Oddbox keep a copy of notifications so you can re-read them.", granted, Permissions.notifListenerIntent(), "Open settings", privacy = "Stored on your phone only. Nothing is uploaded.")
        if (items.isEmpty()) {
            Column(Modifier.weight(1f)) { EmptyState(androidx.compose.material.icons.Icons.Outlined.Notifications, "Nothing logged yet.", "Notifications appear here as they arrive.") }
        } else {
            // Hero: 32dp source-app icons, dismissed rows at 60% with a "swiped away" tag, grouped by day.
            val groups = remember(items) { items.groupBy { dayLabel(ctx, it.postedAt) } }
            LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                var rowIndex = 0
                groups.forEach { (day, rows) ->
                    item(key = "day-$day") {
                        Text(day, style = MaterialTheme.typography.titleMedium.copy(fontSize = 14.sp),
                            color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 8.dp, bottom = 4.dp))
                    }
                    items(rows, key = { it.id }) { n ->
                        val idx = rowIndex++
                        val icon = remember(n.pkg) {
                            runCatching { ctx.packageManager.getApplicationIcon(n.pkg) }.getOrNull()
                        }
                        HCard(Modifier.fillMaxWidth().alpha(if (n.dismissedAt != null) 0.6f else 1f).handyListEnter(idx, reduceMotion), onClick = {
                            ctx.packageManager.getLaunchIntentForPackage(n.pkg)?.let { ctx.startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                        }) {
                            Row(Modifier.padding(12.dp), verticalAlignment = Alignment.Top) {
                                AppIcon32(icon, n.appName)
                                Spacer(Modifier.width(12.dp))
                                Column(Modifier.weight(1f)) {
                                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                        Text(n.appName, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                                        Text(DateUtils.getRelativeTimeSpanString(n.postedAt).toString(), style = MaterialTheme.typography.labelSmall)
                                    }
                                    if (n.title.isNotBlank()) Text(n.title, fontWeight = FontWeight.SemiBold)
                                    if (n.text.isNotBlank()) Text(n.text, style = MaterialTheme.typography.bodyMedium, maxLines = 4)
                                    if (n.dismissedAt != null) {
                                        Spacer(Modifier.height(6.dp))
                                        Box(
                                            Modifier.background(Handy.palette.accentSoft, RoundedCornerShape(8.dp))
                                                .padding(horizontal = 8.dp, vertical = 2.dp)
                                        ) {
                                            Text("swiped away", style = MaterialTheme.typography.labelSmall, color = HandyColors.Accent)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        BannerAd()
    }
}

/** Day bucket label for grouping: Today / Yesterday / a date. */
private fun dayLabel(ctx: Context, postedAt: Long): String = when {
    DateUtils.isToday(postedAt) -> "Today"
    DateUtils.isToday(postedAt + DateUtils.DAY_IN_MILLIS) -> "Yesterday"
    else -> DateUtils.formatDateTime(ctx, postedAt, DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_SHOW_YEAR).toString()
}

/** 32dp source-app icon from PackageManager, with a letter tile fallback. */
@Composable
private fun AppIcon32(icon: Drawable?, appName: String) {
    if (icon != null) {
        val bmp = remember(icon) { icon.toBitmap32() }
        Image(bmp.asImageBitmap(), null, Modifier.size(32.dp).clip(RoundedCornerShape(8.dp)))
    } else {
        Box(
            Modifier.size(32.dp).background(Handy.palette.accentSoft, RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text(appName.take(1).uppercase(), style = MaterialTheme.typography.labelMedium, color = HandyColors.Accent)
        }
    }
}

private fun Drawable.toBitmap32(): Bitmap {
    val w = if (intrinsicWidth > 0) intrinsicWidth else 96
    val h = if (intrinsicHeight > 0) intrinsicHeight else 96
    return Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).also { bmp ->
        val c = Canvas(bmp); setBounds(0, 0, w, h); draw(c)
    }
}
