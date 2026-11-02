package com.handytools.app.tools.power

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.ui.ChipRow
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.PreviewBox
import com.handytools.app.ui.SectionLabel
import kotlinx.coroutines.delay

// Index is the NoisePlayer type: 0 white, 1 pink, 2 brown, 3 rain, 4 ocean, 5 fan.
private val SOUNDS = listOf("White", "Pink", "Brown", "Rain", "Ocean", "Fan")
private val TIMERS = listOf("Off" to 0, "15 min" to 15, "30 min" to 30, "1 hr" to 60, "2 hr" to 120)

/**
 * Rest — soft, steady sleep and focus sound (white / pink / brown noise), generated on the phone so
 * it can run all night, with an optional sleep timer that fades it out. Nothing recorded or uploaded.
 */
@Composable
fun RestToolScreen() {
    val player = remember { NoisePlayer() }
    var playing by remember { mutableStateOf(false) }
    var sound by remember { mutableIntStateOf(1) }      // pink by default — easiest on the ear
    var volume by remember { mutableFloatStateOf(0.6f) }
    var timerMin by remember { mutableIntStateOf(0) }
    var remaining by remember { mutableStateOf<Int?>(null) }

    DisposableEffect(Unit) { onDispose { player.stop() } }

    fun startPlay() {
        player.setType(sound); player.setVolume(volume); player.start()
        playing = true
        remaining = if (timerMin > 0) timerMin * 60 else null
    }
    fun stopPlay() { player.stop(); playing = false; remaining = null }

    // Sleep timer countdown — stops playback when it runs out.
    LaunchedEffect(playing, timerMin) {
        if (playing && timerMin > 0) {
            var sec = remaining ?: timerMin * 60
            while (playing && sec > 0) { remaining = sec; delay(1000); sec-- }
            if (playing && timerMin > 0) stopPlay()
        } else remaining = null
    }

    PowerToolPage("rest") {
        PreviewBox(minHeight = 150.dp) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(if (playing) SOUNDS[sound] + (if (sound <= 2) " noise" else "") else "Ready", style = MaterialTheme.typography.titleMedium, color = if (playing) HandyColors.Accent else Handy.palette.textSecondary, fontWeight = FontWeight.Bold)
                if (remaining != null) {
                    Spacer(Modifier.height(6.dp))
                    val m = remaining!! / 60; val s = remaining!! % 60
                    Text("sleeps in %d:%02d".format(m, s), fontSize = 28.sp, fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.onSurface)
                } else if (playing) {
                    Spacer(Modifier.height(6.dp))
                    Text("playing", style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
                }
            }
        }

        SectionLabel("Sound")
        ChipRow { SOUNDS.forEachIndexed { i, label -> HChip(label, sound == i) { sound = i; if (playing) player.setType(i) } } }

        Spacer(Modifier.height(12.dp))
        SectionLabel("Volume")
        Slider(value = volume, onValueChange = { volume = it; player.setVolume(it) }, modifier = Modifier.fillMaxWidth())

        Spacer(Modifier.height(6.dp))
        SectionLabel("Sleep timer")
        ChipRow { TIMERS.forEachIndexed { i, (label, mins) -> HChip(label, timerMin == mins) { timerMin = mins; if (playing) remaining = if (mins > 0) mins * 60 else null } } }

        Spacer(Modifier.height(16.dp))
        HPrimaryButton(if (playing) "Stop" else "Play") { if (playing) stopPlay() else startPlay() }

        NoteText("The sound is generated on your phone in real time, so it never loops or repeats and can run as long as you like. The sleep timer stops it for you. Keep the volume gentle.")
    }
}
