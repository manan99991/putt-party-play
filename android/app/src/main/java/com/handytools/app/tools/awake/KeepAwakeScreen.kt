package com.handytools.app.tools.awake

import android.content.Intent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.scratchpad.ServiceState
import com.handytools.app.ui.BigToggle
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
fun KeepAwakeScreen() {
    val ctx = LocalContext.current
    var on by remember { mutableStateOf(ServiceState.awake) }
    var minutes by remember { mutableIntStateOf(0) }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Keep Awake", "Screen stays on until you say otherwise. Recipes, maps, video calls.")
        Text("Auto-off", style = MaterialTheme.typography.titleMedium)
        Row(Modifier.padding(vertical = 8.dp), horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp)) {
            listOf(0 to "Never", 15 to "15m", 30 to "30m", 60 to "1h", 120 to "2h").forEach { (m, l) -> HChip(l, minutes == m) { minutes = m } }
        }
        BigToggle("Keep screen on", on) { v ->
            on = v
            val i = Intent(ctx, KeepAwakeService::class.java)
            if (v) ContextCompat.startForegroundService(ctx, i.putExtra("minutes", minutes))
            else ctx.startService(i.setAction(KeepAwakeService.ACTION_STOP))
        }
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}
