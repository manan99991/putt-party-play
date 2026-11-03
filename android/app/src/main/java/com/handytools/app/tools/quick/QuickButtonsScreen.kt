package com.handytools.app.tools.quick

import android.app.Activity
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cameraswitch
import androidx.compose.material.icons.filled.FlashlightOn
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material.icons.filled.WifiTethering
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.handytools.app.ads.BannerAd
import com.handytools.app.ads.Interstitials
import com.handytools.app.ui.ToolHeader
import com.handytools.app.ui.PowerToolPage
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
fun QuickButtonsScreen() {
    val ctx = LocalContext.current
    var torch by remember { mutableStateOf(QuickActions.torchOn) }
    val maxLevel = remember { QuickActions.flashlightMaxLevel(ctx) }
    var level by remember { mutableFloatStateOf(maxLevel.toFloat()) }

    PowerToolPage("quick") {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Big(if (torch) "Light ON" else "Flashlight", Icons.Default.FlashlightOn, torch, Modifier.weight(1f)) { torch = QuickActions.toggleFlashlight(ctx) }
            Big("Hotspot", Icons.Default.WifiTethering, modifier = Modifier.weight(1f)) { QuickActions.openHotspot(ctx) }
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Big("Camera", Icons.Default.PhotoCamera, modifier = Modifier.weight(1f)) { QuickActions.openCamera(ctx); Interstitials.showIfReady(ctx as Activity) }
            Big("Video", Icons.Default.Videocam, modifier = Modifier.weight(1f)) { QuickActions.openVideo(ctx) }
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Big("Selfie", Icons.Default.Cameraswitch, modifier = Modifier.weight(1f)) { QuickActions.openSelfie(ctx) }
            Spacer(Modifier.weight(1f))
        }
        if (maxLevel > 1) {
            Spacer(Modifier.height(12.dp))
            SliderRow("Flashlight brightness", "${(level / maxLevel * 100).toInt()}%", level, { level = it }, 1f..maxLevel.toFloat(), maxOf(0, maxLevel - 2)) {
                QuickActions.setFlashlightLevel(ctx, level.toInt()); torch = true
            }
        }
        LimitNote("Hotspot: Android doesn't let apps flip it directly anymore, so this jumps straight to the toggle.")
    }
}

@Composable
private fun Big(label: String, icon: ImageVector, active: Boolean = false, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Card(
        modifier.fillMaxWidth().height(120.dp).clickable(onClick = onClick),
        shape = MaterialTheme.shapes.medium,
        colors = CardDefaults.cardColors(containerColor = if (active) HandyColors.Accent else MaterialTheme.colorScheme.surface),
        border = if (active) null else androidx.compose.foundation.BorderStroke(1.dp, Handy.palette.border),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.SpaceBetween) {
            Icon(icon, null, Modifier.height(32.dp), tint = if (active) androidx.compose.ui.graphics.Color.White else HandyColors.Accent)
            Text(label, style = MaterialTheme.typography.titleMedium, color = if (active) androidx.compose.ui.graphics.Color.White else MaterialTheme.colorScheme.onSurface)
        }
    }
}
