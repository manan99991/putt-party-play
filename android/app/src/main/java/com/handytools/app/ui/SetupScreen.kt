package com.handytools.app.ui

import android.Manifest
import android.content.Intent
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Accessibility
import androidx.compose.material.icons.outlined.Alarm
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.NotificationsActive
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.handytools.app.Permissions
import com.handytools.app.tools.clipboard.ClipboardAccessibilityService

private data class Perm(
    val icon: ImageVector, val title: String, val why: String, val unlocks: String,
    val granted: (android.content.Context) -> Boolean, val intent: (android.content.Context) -> Intent?, val runtime: String? = null
)

private val PERMS = listOf(
    Perm(Icons.Outlined.Layers, "Draw over other apps", "Puts the floating buttons on top of whatever you're using.",
        "Multi-Clipboard · Screenshot+ · Grab Screen Text · Scratchpad", { Permissions.canOverlay(it) }, { Permissions.overlayIntent(it) }),
    Perm(Icons.Outlined.Accessibility, "Accessibility", "How Tenzy sees what you copy in other apps and scrolls a page for a full-page capture. Never reads passwords; nothing leaves the phone.",
        "Multi-Clipboard · Screenshot+ full page", { Permissions.accessibilityEnabled(it, ClipboardAccessibilityService::class.java) }, { Permissions.accessibilityIntent() }),
    Perm(Icons.Outlined.Notifications, "Notification access", "Keeps a local copy of notifications so you can re-read the ones you swiped away.",
        "Notification Log", { Permissions.notifListenerEnabled(it) }, { Permissions.notifListenerIntent() }),
    Perm(Icons.Outlined.Alarm, "Exact alarms", "So alarms ring on the minute, even in battery saver.",
        "Alarm Pro", { Permissions.canExactAlarms(it) }, { if (Build.VERSION.SDK_INT >= 31) Permissions.exactAlarmIntent(it) else null }),
    Perm(Icons.Outlined.NotificationsActive, "Show notifications", "A small 'tool is on · Stop' notice while a floating tool runs, and the alarm itself.",
        "All running tools · Alarm Pro", { Permissions.canPostNotifications(it) }, { null }, runtime = Manifest.permission.POST_NOTIFICATIONS),
)

/**
 * One-time setup. Android can't grant these from a single dialog — each is a Settings toggle —
 * so this page lists them once, with one tap each, and shows a check as each lands. Every tool
 * still works without it; the tool's own page asks again only for what it needs.
 */
@Composable
fun SetupScreen(onDone: () -> Unit) {
    val ctx = LocalContext.current
    var tick by remember { mutableIntStateOf(0) }
    LifecycleResumeEffect(Unit) { tick++; onPauseOrDispose { } }
    val notifLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { tick++ }
    val granted = remember(tick) { PERMS.map { it.granted(ctx) } }
    val done = granted.count { it }

    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(horizontal = HandyTokens.Gutter)) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
            Spacer(Modifier.height(HandyTokens.Space16))
            Text("Set up once", style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.height(HandyTokens.Space4))
            Text("Five switches, one tap each. Android makes every app ask for these in Settings; after this page Tenzy won't ask again.",
                style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
            Spacer(Modifier.height(HandyTokens.Space8))
            Text("$done of ${PERMS.size} done", style = MaterialTheme.typography.labelMedium, color = HandyColors.Accent)
            Spacer(Modifier.height(HandyTokens.Space16))
            PERMS.forEachIndexed { i, p ->
                PermRow(p, granted[i]) {
                    if (p.runtime != null) { if (Build.VERSION.SDK_INT >= 33) notifLauncher.launch(p.runtime) }
                    else p.intent(ctx)?.let { ctx.startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                }
                Spacer(Modifier.height(HandyTokens.Space12))
            }
            Text("Everything stays on your phone. No account, no cloud. You can flip any of these off later in Android Settings.",
                style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            Spacer(Modifier.height(HandyTokens.Space16))
        }
        HPrimaryButton(if (done == PERMS.size) "All set — open Tenzy" else "Done for now") { onDone() }
        Spacer(Modifier.height(HandyTokens.Space16))
    }
}

@Composable
private fun PermRow(p: Perm, granted: Boolean, onAllow: () -> Unit) {
    val bg by animateColorAsState(if (granted) Handy.palette.accentSoft else MaterialTheme.colorScheme.surface, label = "bg")
    HCard(Modifier.fillMaxWidth()) {
        Row(Modifier.background(bg).padding(HandyTokens.Space16), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(40.dp).background(if (granted) HandyColors.Accent else Handy.palette.accentSoft, CircleShape), contentAlignment = Alignment.Center) {
                Icon(if (granted) Icons.Outlined.Check else p.icon, null, Modifier.size(22.dp), tint = if (granted) Color.White else HandyColors.Accent)
            }
            Spacer(Modifier.width(HandyTokens.Space12))
            Column(Modifier.weight(1f)) {
                Text(p.title, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold))
                Text(p.why, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                Text(p.unlocks, style = MaterialTheme.typography.labelSmall, color = HandyColors.Accent, modifier = Modifier.padding(top = 4.dp))
            }
            Spacer(Modifier.width(HandyTokens.Space8))
            if (!granted) HCompactButton("Allow", onAllow)
        }
    }
}
