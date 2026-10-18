package com.handytools.app.tools.timers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.ToolHeader
import kotlinx.coroutines.delay

/** Countdown timer + stopwatch, without digging through the clock app. */
@Composable
fun TimersScreen() {
    var mode by remember { mutableIntStateOf(0) }
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        ToolHeader("Timers", "A countdown and a stopwatch in one.")
        Spacer(Modifier.size(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.align(Alignment.Start)) {
            HChip("Timer", mode == 0) { mode = 0 }
            HChip("Stopwatch", mode == 1) { mode = 1 }
        }
        Spacer(Modifier.size(20.dp))
        if (mode == 0) Countdown() else Stopwatch()
        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

@Composable
private fun Countdown() {
    var total by remember { mutableIntStateOf(300) }
    var remaining by remember { mutableIntStateOf(300) }
    var running by remember { mutableStateOf(false) }
    var endAt by remember { mutableLongStateOf(0L) }

    LaunchedEffect(running) {
        while (running) {
            remaining = ((endAt - System.currentTimeMillis()) / 1000L).toInt().coerceAtLeast(0)
            if (remaining <= 0) { running = false; break }
            delay(200)
        }
    }

    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        Text("%02d:%02d".format(remaining / 60, remaining % 60),
            fontSize = 56.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.size(20.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(60 to "1m", 180 to "3m", 300 to "5m", 600 to "10m", 1500 to "25m").forEach { (s, l) ->
                HChip(l, false) { if (!running) { total = s; remaining = s } }
            }
        }
        Spacer(Modifier.size(20.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            HPrimaryButton(if (running) "Pause" else "Start", modifier = Modifier.weight(1f)) {
                if (running) { running = false }
                else if (remaining > 0) { endAt = System.currentTimeMillis() + remaining * 1000L; running = true }
            }
            HSecondaryButton("Reset", modifier = Modifier.weight(1f)) { running = false; remaining = total }
        }
    }
}

@Composable
private fun Stopwatch() {
    var elapsed by remember { mutableLongStateOf(0L) }
    var running by remember { mutableStateOf(false) }
    var startAt by remember { mutableLongStateOf(0L) }
    var base by remember { mutableLongStateOf(0L) }

    LaunchedEffect(running) {
        while (running) { elapsed = base + (System.currentTimeMillis() - startAt); delay(30) }
    }

    val cs = (elapsed / 10) % 100; val s = (elapsed / 1000) % 60; val m = elapsed / 60000
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        Text("%02d:%02d.%02d".format(m, s, cs), fontSize = 52.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.size(20.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            HPrimaryButton(if (running) "Stop" else "Start", modifier = Modifier.weight(1f)) {
                if (running) { base = elapsed; running = false }
                else { startAt = System.currentTimeMillis(); running = true }
            }
            HSecondaryButton("Reset", modifier = Modifier.weight(1f)) { running = false; elapsed = 0; base = 0 }
        }
    }
}
