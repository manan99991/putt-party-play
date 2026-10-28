package com.handytools.app.tools.hearing

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.ToolHeader
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Hearing Boost. Live-amplifies the microphone into wired or Bluetooth earbuds so you can hear a
 * quiet talker or a distant TV — plus a level meter. Best with earbuds in (speaker output will
 * feed back). Audio is passed straight through on-device; nothing is recorded or uploaded.
 */
@Composable
fun HearingBoostScreen() {
    val ctx = LocalContext.current
    var granted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        )
    }
    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted = it }

    val engine = remember { HearingEngine() }
    var running by remember { mutableStateOf(false) }
    var gain by remember { mutableStateOf(4f) }
    var level by remember { mutableStateOf(0f) }

    DisposableEffect(Unit) {
        engine.onLevel = { level = it }
        onDispose { engine.stop() }
    }
    // Keep the live gain in sync with the slider.
    engine.gain = gain

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Hearing Boost", "Turn up the world into your earbuds. Pop your earbuds in first — on the speaker it will whistle with feedback.")
        Spacer(Modifier.size(20.dp))

        if (!granted) {
            Text("Microphone access is needed to pick up and amplify sound around you. It's processed live on your phone and never recorded.", color = Handy.palette.textSecondary)
            Spacer(Modifier.size(16.dp))
            HSecondaryButton("Allow microphone", modifier = Modifier.fillMaxWidth()) {
                permLauncher.launch(Manifest.permission.RECORD_AUDIO)
            }
        } else {
            val fill by animateFloatAsState(min(1f, level), label = "lvl")
            Box(
                Modifier.fillMaxWidth().height(160.dp).clip(RoundedCornerShape(18.dp)).background(Handy.palette.surfaceRaised),
                contentAlignment = Alignment.BottomCenter
            ) {
                Box(Modifier.fillMaxWidth().fillMaxHeight(fill).clip(RoundedCornerShape(18.dp)).background(HandyColors.Accent.copy(alpha = 0.6f)))
                Text(if (running) "Listening" else "Paused", color = Handy.palette.textSecondary, modifier = Modifier.padding(12.dp))
            }

            Spacer(Modifier.size(20.dp))
            Text("Boost  ${gain.toInt()}×", fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onBackground)
            Slider(value = gain, onValueChange = { gain = it }, valueRange = 1f..12f)

            Spacer(Modifier.size(16.dp))
            HPrimaryButton(if (running) "Stop" else "Start listening") {
                if (running) { engine.stop(); running = false }
                else { running = engine.start() }
            }
            if (running) {
                Spacer(Modifier.size(8.dp))
                Text("Keep earbuds in to avoid feedback.", color = Handy.palette.textSecondary, fontSize = 13.sp)
            }
        }

        Spacer(Modifier.weight(1f))
        BannerAd()
    }
}

/** Reads the mic and writes it straight to the audio output on a worker thread, applying gain. */
private class HearingEngine {
    @Volatile var gain: Float = 4f
    @Volatile private var running = false
    private var thread: Thread? = null
    var onLevel: (Float) -> Unit = {}

    fun start(): Boolean {
        if (running) return true
        val rate = 44100
        val inBuf = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        val outBuf = AudioTrack.getMinBufferSize(rate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (inBuf <= 0 || outBuf <= 0) return false
        val record = try {
            AudioRecord(MediaRecorder.AudioSource.MIC, rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, inBuf * 2)
        } catch (e: Exception) { return false }
        if (record.state != AudioRecord.STATE_INITIALIZED) { record.release(); return false }
        val track = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            .setAudioFormat(AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(rate).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
            .setBufferSizeInBytes(outBuf * 2)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        running = true
        thread = Thread {
            val buf = ShortArray(inBuf)
            try {
                record.startRecording(); track.play()
                while (running) {
                    val n = record.read(buf, 0, buf.size)
                    if (n <= 0) continue
                    var sum = 0.0
                    for (i in 0 until n) {
                        var v = (buf[i] * gain).toInt()
                        if (v > Short.MAX_VALUE) v = Short.MAX_VALUE.toInt()
                        if (v < Short.MIN_VALUE) v = Short.MIN_VALUE.toInt()
                        buf[i] = v.toShort()
                        sum += (v.toDouble() * v.toDouble())
                    }
                    val rms = sqrt(sum / n) / 32767.0
                    onLevel(rms.toFloat())
                    track.write(buf, 0, n)
                }
            } catch (_: Exception) {
            } finally {
                try { record.stop() } catch (_: Exception) {}
                try { track.stop() } catch (_: Exception) {}
                record.release(); track.release()
            }
        }.also { it.start() }
        return true
    }

    fun stop() {
        running = false
        thread?.join(300)
        thread = null
        onLevel(0f)
    }
}
