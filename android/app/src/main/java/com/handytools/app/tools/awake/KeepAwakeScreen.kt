package com.handytools.app.tools.awake

import android.content.Intent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PowerSettingsNew
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.scratchpad.ServiceState
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.HandyMotion
import com.handytools.app.ui.ToolHeader
import com.handytools.app.ui.HChip
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors

@Composable
fun KeepAwakeScreen() {
    val ctx = LocalContext.current
    var on by remember { mutableStateOf(ServiceState.awake) }
    var minutes by remember { mutableIntStateOf(0) }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        ToolHeader("Keep Awake", "Screen stays on until you say otherwise. Recipes, maps, video calls.")
        Spacer(Modifier.size(12.dp))
        // Hero: 160dp circular power toggle; accent ring fills clockwise while on,
        // auto-off countdown inside when set.
        KeepAwakeDial(on = on, minutes = minutes) {
            val v = !on
            on = v
            HandyHaptics.light(ctx)
            val i = Intent(ctx, KeepAwakeService::class.java)
            if (v) ContextCompat.startForegroundService(ctx, i.putExtra("minutes", minutes))
            else ctx.startService(i.setAction(KeepAwakeService.ACTION_STOP))
        }
        Spacer(Modifier.size(20.dp))
        Text("Auto-off", style = MaterialTheme.typography.titleMedium, modifier = Modifier.align(Alignment.Start))
        Row(Modifier.padding(vertical = 8.dp).align(Alignment.Start), horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp)) {
            listOf(0 to "Never", 15 to "15m", 30 to "30m", 60 to "1h", 120 to "2h").forEach { (m, l) -> HChip(l, minutes == m) { minutes = m } }
        }
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

/** Hero: big circular power toggle. Accent ring fills clockwise while on; countdown inside when auto-off is set. */
@Composable
private fun KeepAwakeDial(on: Boolean, minutes: Int, onToggle: () -> Unit) {
    val sweep by animateFloatAsState(
        targetValue = if (on) 360f else 0f,
        animationSpec = tween(HandyMotion.SLOW_MS, easing = HandyMotion.EnterEasing),
        label = "awakeRing"
    )
    val src = remember { MutableInteractionSource() }
    Box(
        Modifier.size(160.dp).clip(CircleShape)
            .clickable(interactionSource = src, indication = ripple(bounded = true), onClick = onToggle)
            // The ring's only child is a decorative icon (and the minutes text shows only when set), so
            // name the toggle itself and announce its state for screen readers.
            .semantics { contentDescription = if (on) "Keep screen awake, on" else "Keep screen awake, off" },
        contentAlignment = Alignment.Center
    ) {
        val track = Handy.palette.border
        Canvas(Modifier.fillMaxSize()) {
            drawArc(track, -90f, 360f, false, style = Stroke(12.dp.toPx(), cap = StrokeCap.Round))
            if (sweep > 0.5f) drawArc(HandyColors.Accent, -90f, sweep, false, style = Stroke(12.dp.toPx(), cap = StrokeCap.Round))
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Outlined.PowerSettingsNew, null, Modifier.size(40.dp),
                tint = if (on) HandyColors.Accent else Handy.palette.textSecondary)
            if (minutes > 0) {
                val label = when {
                    minutes >= 60 -> "${minutes / 60}h${if (minutes % 60 > 0) " ${minutes % 60}m" else ""}"
                    else -> "${minutes} min"
                }
                Text(label, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            }
        }
    }
}
