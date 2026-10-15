package com.handytools.app.tools.volume

import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.layout.layout
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
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.width
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

private data class Stream(val name: String, val short: String, val id: Int)

private val STREAMS = listOf(
    Stream("Ringtone", "Ring", AudioManager.STREAM_RING),
    Stream("Media", "Media", AudioManager.STREAM_MUSIC),
    Stream("Alarm", "Alarm", AudioManager.STREAM_ALARM),
    Stream("Notifications", "Notif", AudioManager.STREAM_NOTIFICATION),
    Stream("Calls", "Call", AudioManager.STREAM_VOICE_CALL),
    Stream("System", "System", AudioManager.STREAM_SYSTEM),
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
        Row(Modifier.padding(vertical = 8.dp), horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp)) {
            HChip("Sleep", false) { preset(0, 0, 0, 70); am.ringerMode = AudioManager.RINGER_MODE_VIBRATE; ringerMode = am.ringerMode }
            HChip("Work", false) { preset(30, 40, 30, 80); am.ringerMode = AudioManager.RINGER_MODE_NORMAL; ringerMode = am.ringerMode }
            HChip("Loud", false) { preset(100, 100, 100, 100); am.ringerMode = AudioManager.RINGER_MODE_NORMAL; ringerMode = am.ringerMode }
            HChip("Silent", ringerMode == AudioManager.RINGER_MODE_SILENT) {
                am.ringerMode = if (am.ringerMode == AudioManager.RINGER_MODE_SILENT) AudioManager.RINGER_MODE_NORMAL else AudioManager.RINGER_MODE_SILENT
                ringerMode = am.ringerMode
            }
        }
        Spacer(Modifier.height(8.dp))

        HCard(Modifier.fillMaxWidth()) {
            Row(Modifier.fillMaxWidth().padding(vertical = 20.dp, horizontal = 8.dp), horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceEvenly) {
                STREAMS.forEach { s ->
                    key(tick, s.id) {
                        val max = am.getStreamMaxVolume(s.id)
                        var v by remember(tick) { mutableStateOf(am.getStreamVolume(s.id).toFloat()) }
                        Column(horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally) {
                            Text("${(v / max * 100).toInt()}%", style = MaterialTheme.typography.labelMedium, color = Handy.palette.textSecondary)
                            Spacer(Modifier.height(8.dp))
                            Box(Modifier.height(220.dp).width(40.dp)) {
                                Slider(
                                    v, { v = it; am.setStreamVolume(s.id, it.toInt(), 0) }, valueRange = 0f..max.toFloat(), steps = (max - 1).coerceAtLeast(0),
                                    modifier = Modifier.graphicsLayer { rotationZ = -90f; transformOrigin = TransformOrigin(0f, 0f) }
                                        .layout { m, c ->
                                            val p = m.measure(androidx.compose.ui.unit.Constraints(minWidth = c.minHeight, maxWidth = c.maxHeight, minHeight = c.minWidth, maxHeight = c.maxWidth))
                                            layout(p.height, p.width) { p.place(-p.width, 0) }
                                        }
                                )
                            }
                            Spacer(Modifier.height(8.dp))
                            Text(s.short, style = MaterialTheme.typography.labelMedium)
                        }
                    }
                }
            }
        }
        BannerAd()
    }
}
