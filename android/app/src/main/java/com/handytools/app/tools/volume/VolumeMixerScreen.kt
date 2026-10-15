package com.handytools.app.tools.volume

import android.content.Context
import android.media.AudioManager
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.handytools.app.Permissions
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.PermissionCard
import com.handytools.app.ui.ToolHeader

private data class Stream(val name: String, val id: Int)

private val STREAMS = listOf(
    Stream("Ringtone", AudioManager.STREAM_RING),
    Stream("Media", AudioManager.STREAM_MUSIC),
    Stream("Alarm", AudioManager.STREAM_ALARM),
    Stream("Notifications", AudioManager.STREAM_NOTIFICATION),
    Stream("Calls", AudioManager.STREAM_VOICE_CALL),
    Stream("System", AudioManager.STREAM_SYSTEM),
)

/** Every stream on one screen, plus one-tap presets. Changing Ring/Notif while in DND needs policy access. */
@Composable
fun VolumeMixerScreen() {
    val ctx = LocalContext.current
    val am = remember { ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager }
    var tick by remember { mutableIntStateOf(0) } // forces re-read after preset
    var ringerMode by remember { mutableIntStateOf(am.ringerMode) }

    fun preset(ring: Int, media: Int, notif: Int, alarm: Int) {
        fun set(s: Int, pct: Int) = am.setStreamVolume(s, am.getStreamMaxVolume(s) * pct / 100, 0)
        set(AudioManager.STREAM_RING, ring); set(AudioManager.STREAM_MUSIC, media)
        set(AudioManager.STREAM_NOTIFICATION, notif); set(AudioManager.STREAM_ALARM, alarm)
        tick++
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp).verticalScroll(rememberScrollState())) {
        ToolHeader("Volume Mixer", "Every volume in one place. No more hunting through Settings.")
        PermissionCard("Do Not Disturb access", "Only needed to change ringtone/notification volume while DND is on.",
            Permissions.hasNotifPolicy(ctx), Permissions.notifPolicyIntent())

        Text("Presets", style = MaterialTheme.typography.titleMedium)
        Row(Modifier.padding(vertical = 8.dp)) {
            FilterChip(false, { preset(0, 0, 0, 70); am.ringerMode = AudioManager.RINGER_MODE_VIBRATE; ringerMode = am.ringerMode }, { Text("Sleep") })
            Spacer(Modifier.padding(4.dp))
            FilterChip(false, { preset(30, 40, 30, 80); am.ringerMode = AudioManager.RINGER_MODE_NORMAL; ringerMode = am.ringerMode }, { Text("Work") })
            Spacer(Modifier.padding(4.dp))
            FilterChip(false, { preset(100, 100, 100, 100); am.ringerMode = AudioManager.RINGER_MODE_NORMAL; ringerMode = am.ringerMode }, { Text("Loud") })
            Spacer(Modifier.padding(4.dp))
            FilterChip(ringerMode == AudioManager.RINGER_MODE_SILENT, {
                am.ringerMode = if (am.ringerMode == AudioManager.RINGER_MODE_SILENT) AudioManager.RINGER_MODE_NORMAL else AudioManager.RINGER_MODE_SILENT
                ringerMode = am.ringerMode
            }, { Text("Silent") })
        }
        Spacer(Modifier.height(8.dp))

        STREAMS.forEach { s ->
            key(tick, s.id) {
                val max = am.getStreamMaxVolume(s.id)
                var v by remember(tick) { mutableStateOf(am.getStreamVolume(s.id).toFloat()) }
                Card(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
                    Column(Modifier.padding(16.dp)) {
                        Text("${s.name}  ${(v / max * 100).toInt()}%", style = MaterialTheme.typography.titleMedium)
                        Slider(v, { v = it; am.setStreamVolume(s.id, it.toInt(), 0) }, valueRange = 0f..max.toFloat(), steps = (max - 1).coerceAtLeast(0))
                    }
                }
            }
        }
        BannerAd()
    }
}
