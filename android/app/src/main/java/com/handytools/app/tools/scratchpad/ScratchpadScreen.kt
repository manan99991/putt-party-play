package com.handytools.app.tools.scratchpad

import androidx.compose.foundation.background
import android.content.Intent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.handytools.app.HandyApp
import com.handytools.app.Permissions
import com.handytools.app.ads.BannerAd
import com.handytools.app.data.Note
import com.handytools.app.ui.BigToggle
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
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun ScratchpadScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var overlay by remember { mutableStateOf(Permissions.canOverlay(ctx)) }
    var on by remember { mutableStateOf(ServiceState.scratchpad) }
    var text by remember { mutableStateOf("") }
    LifecycleResumeEffect(Unit) { overlay = Permissions.canOverlay(ctx); onPauseOrDispose { } }
    LaunchedEffect(Unit) { text = withContext(Dispatchers.IO) { HandyApp.instance.db.notes().getOnce()?.text ?: "" } }
    LaunchedEffect(text) { delay(600); withContext(Dispatchers.IO) { HandyApp.instance.db.notes().save(Note(text = text)) } }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Scratchpad Bubble", "A note that floats over every app. Same note here and in the bubble.")
        PermissionCard("Draw over other apps", "Needed for the bubble.", overlay, Permissions.overlayIntent(ctx))
        BigToggle("Bubble", on && overlay) { v ->
            on = v; ServiceState.scratchpad = v
            val i = Intent(ctx, ScratchpadBubbleService::class.java)
            if (v) ContextCompat.startForegroundService(ctx, i) else ctx.startService(i.setAction(ScratchpadBubbleService.ACTION_STOP))
        }
        androidx.compose.foundation.layout.Box(
            Modifier.fillMaxWidth().weight(1f).padding(vertical = 12.dp)
                .background(Handy.palette.sticky, MaterialTheme.shapes.medium)
        ) {
            androidx.compose.foundation.text.BasicTextField(
                text, { text = it }, modifier = Modifier.fillMaxSize().padding(20.dp),
                textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
                cursorBrush = androidx.compose.ui.graphics.SolidColor(HandyColors.Accent),
                decorationBox = { inner -> if (text.isEmpty()) Text("Jot anything…", style = MaterialTheme.typography.bodyLarge, color = Handy.palette.textSecondary); inner() }
            )
        }
        BannerAd()
    }
}

/** Simple process-local flags so toggles reflect running services. */
object ServiceState {
    @Volatile var scratchpad = false
    @Volatile var awake = false
}
