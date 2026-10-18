package com.handytools.app.tools.flashlight

import android.content.Context
import android.hardware.camera2.CameraManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/** One-tap flashlight patterns — tap a pattern to start it, tap again to turn off. */
@Composable
fun FlashlightScreen() {
    val ctx = LocalContext.current
    val torch = remember { Torch(ctx) }
    val scope = rememberCoroutineScope()
    var active by remember { mutableStateOf<String?>(null) }
    var job by remember { mutableStateOf<Job?>(null) }

    DisposableEffect(Unit) { onDispose { job?.cancel(); torch.set(false) } }

    fun run(name: String, pattern: List<Long>?) {
        job?.cancel(); torch.set(false)
        if (active == name) { active = null; return }
        active = name
        HandyHaptics.light(ctx)
        if (pattern == null) { torch.set(true); return }
        job = scope.launch {
            while (isActive) {
                var on = true
                for (d in pattern) { torch.set(on); on = !on; delay(d) }
            }
        }
    }

    val patterns: List<Pair<String, List<Long>?>> = listOf(
        "Steady" to null,
        "Strobe" to listOf(60L, 60L),
        "Slow blink" to listOf(500L, 500L),
        "SOS" to listOf(200, 200, 200, 200, 200, 600, 600, 200, 600, 200, 600, 600, 200, 200, 200, 200, 200, 1400),
        "Beacon" to listOf(120L, 1200L),
        "Pulse" to listOf(90L, 90L, 90L, 600L),
    )

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Flashlight", "Tap a pattern to start. Tap it again to turn off.")
        Spacer(Modifier.size(16.dp))
        LazyVerticalGrid(
            columns = GridCells.Fixed(2), modifier = Modifier.weight(1f).fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(patterns) { (name, pat) ->
                HChip(name, active == name) { run(name, pat) }
            }
        }
        Spacer(Modifier.size(12.dp))
        BannerAd()
    }
}

/** Thin wrapper over the camera torch. */
private class Torch(ctx: Context) {
    private val cm = ctx.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val id: String? = runCatching {
        cm.cameraIdList.firstOrNull { c ->
            cm.getCameraCharacteristics(c).get(android.hardware.camera2.CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        }
    }.getOrNull()
    fun set(on: Boolean) { id?.let { runCatching { cm.setTorchMode(it, on) } } }
}
