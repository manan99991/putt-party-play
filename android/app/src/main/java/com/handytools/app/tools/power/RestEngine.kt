package com.handytools.app.tools.power

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import kotlin.concurrent.thread
import kotlin.random.Random

/**
 * Procedural sleep-sound player. Generates white / pink / brown noise on the fly and streams it to an
 * AudioTrack, so there are no audio files to ship and it can play as long as you like. All maths,
 * nothing recorded or uploaded.
 */
class NoisePlayer {
    @Volatile private var running = false
    @Volatile private var type = 1          // 0 white, 1 pink, 2 brown
    @Volatile private var gain = 0.6f
    private var track: AudioTrack? = null
    private val rate = 44100

    val isPlaying: Boolean get() = running

    fun setType(t: Int) { type = t }
    fun setVolume(v: Float) { gain = v.coerceIn(0f, 1f) }

    fun start() {
        if (running) return
        running = true
        thread(isDaemon = true) {
            val minBuf = AudioTrack.getMinBufferSize(rate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
            val bufSamples = (minBuf / 2).coerceAtLeast(2048)
            val t = try {
                AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setSampleRate(rate)
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(bufSamples * 2)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()
            } catch (_: Throwable) { running = false; return@thread }
            track = t
            try { t.play() } catch (_: Throwable) { running = false; return@thread }

            val buf = ShortArray(bufSamples)
            // Pink-noise filter state (Paul Kellet's refined method).
            var b0 = 0f; var b1 = 0f; var b2 = 0f; var b3 = 0f; var b4 = 0f; var b5 = 0f; var b6 = 0f
            var brown = 0f
            // Extra state for the richer textures: rain hiss, ocean swell, fan blade.
            var prevWhite = 0f; var oceanPhase = 0f; var fanPhase = 0f
            val tau = 6.2831853f
            while (running) {
                val g = gain
                val ty = type
                for (i in buf.indices) {
                    val white = Random.nextFloat() * 2f - 1f
                    // Pink + brown are advanced every sample so every texture can draw on them (the type
                    // is fixed during playback, so this is just the same filters running continuously).
                    b0 = 0.99886f * b0 + white * 0.0555179f
                    b1 = 0.99332f * b1 + white * 0.0750759f
                    b2 = 0.96900f * b2 + white * 0.1538520f
                    b3 = 0.86650f * b3 + white * 0.3104856f
                    b4 = 0.55000f * b4 + white * 0.5329522f
                    b5 = -0.7616f * b5 - white * 0.0168980f
                    val pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362f) * 0.11f
                    b6 = white * 0.115926f
                    // Brown (red) noise as a LEAKY integrator: the 0.998 leak pulls it back toward zero
                    // so it never drifts to the ±1 rails and sticks (which clipped as harsh distortion).
                    // It settles at ~0.3 RMS, so it's output directly — no ×3 that slammed into the clamp.
                    brown = brown * 0.998f + white * 0.034f
                    val sample = when (ty) {
                        0 -> white * 0.6f                                   // white
                        2 -> brown                                          // brown
                        3 -> {                                              // rain: steady high hiss over pink
                            val hiss = white - prevWhite; prevWhite = white
                            pink * 0.65f + hiss * 0.4f
                        }
                        4 -> {                                              // ocean: brown surf swelling in/out
                            oceanPhase += tau * 0.08f / rate
                            if (oceanPhase > tau) oceanPhase -= tau
                            val swell = 0.4f + 0.6f * ((kotlin.math.sin(oceanPhase) + 1f) * 0.5f)
                            (brown * 0.9f + pink * 0.3f) * swell
                        }
                        5 -> {                                              // fan: brown rumble, gentle blade
                            fanPhase += tau * 6f / rate
                            if (fanPhase > tau) fanPhase -= tau
                            val blade = 0.88f + 0.12f * kotlin.math.sin(fanPhase)
                            (brown * 0.95f + pink * 0.25f) * blade
                        }
                        else -> pink                                        // 1 pink
                    }
                    buf[i] = (sample.coerceIn(-1f, 1f) * g * Short.MAX_VALUE).toInt().toShort()
                }
                try { if (running) t.write(buf, 0, buf.size) } catch (_: Throwable) { break }
            }
            try { t.stop() } catch (_: Throwable) {}
            try { t.release() } catch (_: Throwable) {}
            track = null
        }
    }

    fun stop() {
        running = false
    }
}
