package com.handytools.app.tools.studio

import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Tenzy's own music and sound effects, made on the phone from plain waves and noise — the iPhone's Synth, note for
 * note. Nothing is downloaded, licensed or copied, so reels, trailers and funny moments carry sound we own outright
 * (rulebook: never ship songs or loops we don't have the rights to). Pure: the same request makes the same sound.
 */
object Synth {
    const val RATE = 44_100.0

    data class Style(val id: String, val name: String, val emoji: String, val bpm: Double, val beatsPerCut: Int, val look: String, val light: String)

    val styles = listOf(
        Style("upbeat", "Upbeat", "☀️", 118.0, 2, "vivid", "leak"),
        Style("party", "Party", "🪩", 126.0, 2, "neon", "flare"),
        Style("chill", "Chill", "🌙", 88.0, 4, "dream", "glow"),
        Style("epic", "Epic", "⚡️", 96.0, 4, "cinema", "vignette"),
    )
    fun style(id: String): Style = styles.firstOrNull { it.id == id } ?: styles[0]

    // MARK: building blocks

    fun hz(midi: Int): Double = 440 * 2.0.pow((midi - 69) / 12.0)

    /** Adds [sound] into [out] starting at [t] seconds, scaled by [gain]. */
    fun mix(sound: FloatArray, out: FloatArray, t: Double, gain: Float = 1f) {
        val start = (t * RATE).toInt()
        if (start >= out.size) return
        for (i in sound.indices) { val j = start + i; if (j in out.indices) out[j] += sound[i] * gain }
    }

    private fun n(seconds: Double) = (seconds * RATE).toInt()

    private fun noise(n: Int, seed: Long): FloatArray { val r = SeededRandom(seed); return FloatArray(n) { r.next(-1.0, 1.0).toFloat() } }

    /** A kick drum: a sine that drops in pitch, with a click on top. */
    fun kick(punch: Double = 1.0): FloatArray {
        var phase = 0.0
        return FloatArray(n(0.42)) { i ->
            val t = i / RATE
            phase += 2 * PI * (48 + 120 * punch * exp(-t * 28)) / RATE
            (sin(phase) * exp(-t * 7.5)).toFloat() * 0.95f + if (i < 220) sin(i * 0.9).toFloat() * 0.25f * (1 - i / 220f) else 0f
        }
    }

    fun snare(soft: Boolean = false): FloatArray {
        val hiss = Dsp.filter(noise(n(0.25), 5), "highpass", if (soft) 900.0 else 1500.0, rate = RATE)
        return FloatArray(hiss.size) { i ->
            val t = i / RATE
            (hiss[i] * exp(-t * (if (soft) 22 else 16)).toFloat() * 0.7f + (sin(2 * PI * 185 * t) * exp(-t * 30)).toFloat() * 0.45f) * (if (soft) 0.6f else 1f)
        }
    }

    fun clap(): FloatArray {
        val hiss = Dsp.filter(noise(n(0.22), 9), "bandpass", 1400.0, q = 1.2, rate = RATE)
        return FloatArray(hiss.size) { i ->
            val t = i / RATE
            val bursts = if (t < 0.03) 0.6 + 0.4 * sin(t * 2 * PI * 100) else exp(-(t - 0.03) * 18)
            hiss[i] * bursts.toFloat() * 1.4f
        }
    }

    fun hat(open: Boolean = false): FloatArray {
        val hiss = Dsp.filter(Dsp.filter(noise(n(if (open) 0.22 else 0.05), 13), "highpass", 7000.0, rate = RATE), "highpass", 7000.0, rate = RATE)
        return FloatArray(hiss.size) { i -> hiss[i] * exp(-i / RATE * (if (open) 12 else 60)).toFloat() * 0.5f }
    }

    /** A deep drum with a boom (the epic style and trailers). */
    fun taiko(): FloatArray {
        val thud = Dsp.filter(noise(n(0.9), 21), "lowpass", 300.0, rate = RATE)
        var phase = 0.0
        return FloatArray(thud.size) { i ->
            val t = i / RATE
            phase += 2 * PI * (62 + 40 * exp(-t * 18)) / RATE
            (sin(phase) * exp(-t * 4)).toFloat() * 0.9f + thud[i] * exp(-t * 12).toFloat() * 0.8f
        }
    }

    /** A rounded bass note. */
    fun bass(midi: Int, seconds: Double, bright: Double = 0.3): FloatArray {
        val f = hz(midi)
        return FloatArray(n(seconds)) { i ->
            val t = i / RATE
            val w = sin(2 * PI * f * t) + bright * sin(4 * PI * f * t) * 0.5 + bright * 0.25 * sin(6 * PI * f * t)
            (w * min(1.0, t / 0.008) * exp(-t / (seconds * 1.6))).toFloat() * 0.55f
        }
    }

    /** A short bright note (arpeggios), or a soft electric-piano note when [soft]. */
    fun pluck(midi: Int, seconds: Double, soft: Boolean = false): FloatArray {
        val f = hz(midi)
        return FloatArray(n(seconds)) { i ->
            val t = i / RATE
            val trem = if (soft) 1 - 0.18 * (0.5 + 0.5 * sin(2 * PI * 4.5 * t)) else 1.0
            val w = sin(2 * PI * f * t) + (if (soft) 0.35 else 0.5) * sin(4 * PI * f * t) * exp(-t * 6) + (if (soft) 0.1 else 0.25) * sin(6 * PI * f * t) * exp(-t * 9)
            (w * trem * min(1.0, t / 0.004) * exp(-t * (if (soft) 2.2 else 5.0))).toFloat() * 0.3f
        }
    }

    /** A held chord of detuned saws, softened — the pad under everything. */
    fun pad(notes: List<Int>, seconds: Double, brightness: Double = 1800.0): FloatArray {
        val count = n(seconds)
        var out = FloatArray(count)
        notes.forEachIndexed { k, m ->
            for (d in listOf(-0.11, 0.0, 0.13)) {
                val f = hz(m) * 2.0.pow(d / 12)
                var ph = k * 0.7
                for (i in 0 until count) { ph += f / RATE; if (ph > 1) ph -= 1; out[i] += (2 * ph - 1).toFloat() * 0.06f }
            }
        }
        out = Dsp.filter(out, "lowpass", brightness, rate = RATE)
        val fade = 0.25 * RATE
        for (i in 0 until count) out[i] *= (min(1.0, i / fade) * min(1.0, (count - i) / fade)).toFloat()
        return out
    }

    /** The low brass blast trailers use: a stack of saws that opens up, then dies away. */
    fun braam(root: Int = 36, seconds: Double = 2.2): FloatArray {
        val count = n(seconds)
        var out = FloatArray(count)
        for (m in listOf(root, root + 7, root + 12)) for (d in listOf(-0.15, 0.0, 0.17)) {
            val f = hz(m) * 2.0.pow(d / 12)
            var ph = 0.0
            for (i in 0 until count) { ph += f / RATE; if (ph > 1) ph -= 1; out[i] += (2 * ph - 1).toFloat() * 0.12f }
        }
        out = Dsp.drive(Dsp.filter(out, "lowpass", 900.0, rate = RATE), 2f)
        for (i in 0 until count) { val t = i / RATE; out[i] *= (min(1.0, t / 0.05) * exp(-t / (seconds * 0.45))).toFloat() }
        return out
    }

    /** Noise and a tone rising for [seconds], ending on the drop. */
    fun riser(seconds: Double = 2.0): FloatArray {
        val count = n(seconds)
        val hiss = noise(count, 31)
        var ph = 0.0
        return FloatArray(count) { i ->
            val p = i.toDouble() / count
            ph += (200 + 1600 * p * p) / RATE; if (ph > 1) ph -= 1
            (hiss[i] * (0.25 * p).toFloat() + (2 * ph - 1).toFloat() * (0.12 * p).toFloat()) * p.toFloat()
        }
    }

    // MARK: music

    private data class Chord(val notes: List<Int>, val root: Int)
    private val progression = listOf(Chord(listOf(60, 64, 67), 36), Chord(listOf(55, 59, 62), 43), Chord(listOf(57, 60, 64), 45), Chord(listOf(53, 57, 60), 41))      // C G Am F
    private val minorProgression = listOf(Chord(listOf(57, 60, 64), 33), Chord(listOf(53, 57, 60), 41), Chord(listOf(48, 52, 55), 36), Chord(listOf(55, 59, 62), 43)) // Am F C G

    class Track(val samples: FloatArray, val beats: List<Double>)

    /** A track in [styleId] lasting [seconds] (whole bars, ending on a hit), and the time of every beat in it. */
    fun track(styleId: String, seconds: Double): Track {
        val st = style(styleId)
        val beat = 60 / st.bpm; val bar = beat * 4
        val bars = max(2, kotlin.math.ceil(seconds / bar).toInt())
        val total = bars * bar + 1.5
        val out = FloatArray(n(total))
        val k = kick(if (st.id == "chill") 0.6 else 1.0); val sn = snare(st.id == "chill"); val cl = clap(); val ch = hat(); val oh = hat(true); val tk = taiko()
        val prog = if (st.id == "epic" || st.id == "chill") minorProgression else progression
        val beats = mutableListOf<Double>()
        for (b in 0 until bars) {
            val t0 = b * bar
            val p = prog[b % 4]
            val intro = b == 0 && bars > 2   // the first bar is lighter, so the second lands like a drop
            when (st.id) {
                "party" -> {
                    for (q in 0 until 4) mix(k, out, t0 + q * beat, if (intro) 0.6f else 1f)
                    for (q in listOf(1, 3)) mix(cl, out, t0 + q * beat, 0.7f)
                    for (q in 0 until 4) mix(oh, out, t0 + (q + 0.5) * beat, 0.55f)
                    if (!intro) for (q in 0 until 4) mix(bass(p.root + 12, beat * 0.45, 0.6), out, t0 + (q + 0.5) * beat)
                    mix(pad(p.notes.map { it + 12 }, bar, if (intro) 900.0 else 3200.0), out, t0, 0.8f)
                }
                "chill" -> {
                    mix(k, out, t0, 0.8f); mix(k, out, t0 + 2.5 * beat, 0.6f)
                    for (q in listOf(1, 3)) mix(sn, out, t0 + q * beat, 0.7f)
                    for (e in 0 until 8) mix(ch, out, t0 + e * beat / 2 + (if (e % 2 == 1) beat * 0.08 else 0.0), 0.35f)   // a lazy swing
                    mix(bass(p.root, bar * 0.95, 0.1), out, t0, 0.9f)
                    p.notes.forEachIndexed { j, m -> mix(pluck(m, bar, soft = true), out, t0 + j * 0.02) }
                }
                "epic" -> {
                    mix(tk, out, t0); mix(tk, out, t0 + 1.5 * beat, 0.7f); mix(tk, out, t0 + 2 * beat, 0.85f)
                    mix(k, out, t0 + 3 * beat, 0.8f)
                    if (b % 2 == 0) mix(braam(p.root, bar * 1.1), out, t0, if (intro) 0.5f else 0.85f)
                    mix(pad(p.notes.map { it - 12 }, bar, 1400.0), out, t0, 0.9f)
                    if (b == bars - 2) mix(riser(bar), out, t0, 0.8f)
                }
                else -> {   // upbeat
                    for (q in 0 until 4) mix(k, out, t0 + q * beat, if (intro) 0.6f else 0.95f)
                    for (q in listOf(1, 3)) mix(sn, out, t0 + q * beat, 0.8f)
                    for (e in 0 until 8) mix(ch, out, t0 + e * beat / 2, 0.4f)
                    if (!intro) for (e in 0 until 8) mix(bass(p.root, beat * 0.4), out, t0 + e * beat / 2, 0.75f)
                    val arp = p.notes + (p.notes[0] + 12)
                    for (s in 0 until 16) mix(pluck(arp[s % arp.size] + 12, beat * 0.5), out, t0 + s * beat / 4, 0.55f)
                    mix(pad(p.notes, bar, 1500.0), out, t0, 0.6f)
                }
            }
            for (q in 0 until 4) beats += t0 + q * beat
        }
        // The ending: one big hit on the last downbeat, ringing out.
        val end = bars * bar
        mix(if (st.id == "epic") braam(prog[0].root, 1.5) else k, out, end, 1f)
        mix(pad(prog[0].notes, 1.5, 2200.0), out, end, 0.8f)
        return Track(Dsp.level(out), beats)
    }

    // MARK: sound effects

    data class Effect(val id: String, val name: String, val emoji: String)
    val effects = listOf(
        Effect("scratch", "Record scratch", "💿"), Effect("boing", "Boing", "🪀"),
        Effect("sting", "Dun dun dun", "😱"), Effect("rimshot", "Ba-dum-tss", "🥁"),
        Effect("crickets", "Crickets", "🦗"), Effect("horn", "Air horn", "📯"),
        Effect("whoosh", "Whoosh", "💨"), Effect("pop", "Pop", "🫧"),
    )

    fun effect(id: String): FloatArray {
        val out: FloatArray = when (id) {
            "boing" -> {
                var ph = 0.0
                FloatArray(n(0.75)) { i ->
                    val t = i / RATE
                    ph += 2 * PI * (230 + 150 * sin(2 * PI * 11 * t) * exp(-t * 3.5) + 120 * exp(-t * 9)) / RATE
                    ((sin(ph) + 0.3 * sin(2 * ph)) * exp(-t * 4.2)).toFloat() * 0.8f
                }
            }
            "scratch" -> {
                // Two quick drags of a record: filtered noise and a tone, sweeping down and back up.
                val hiss = noise(n(0.45), 3)
                var ph = 0.0
                val raw = FloatArray(hiss.size) { i ->
                    val t = i / RATE
                    val sweep = if (t < 0.18) 1 - t / 0.18 else (t - 0.18) / 0.27
                    ph += (180 + 1100 * sweep) / RATE; if (ph > 1) ph -= 1
                    (hiss[i] * (0.45 * sweep).toFloat() + (2 * ph - 1).toFloat() * 0.35f) * (min(1.0, t / 0.005) * (if (t < 0.4) 1.0 else (0.45 - t) / 0.05)).toFloat()
                }
                Dsp.filter(raw, "bandpass", 1200.0, q = 0.7, rate = RATE)
            }
            "sting" -> FloatArray(n(2.6)).also {
                mix(braam(50, 0.45), it, 0.0, 0.8f); mix(braam(53, 0.45), it, 0.5, 0.8f); mix(braam(49, 1.8), it, 1.0, 1f)
            }
            "rimshot" -> FloatArray(n(1.6)).also {
                fun tom(f: Double) = FloatArray(n(0.3)) { i -> val t = i / RATE; (sin(2 * PI * (f + 60 * exp(-t * 20)) * t) * exp(-t * 11)).toFloat() * 0.8f }
                mix(tom(190.0), it, 0.0); mix(tom(150.0), it, 0.16)
                val crash = Dsp.filter(noise(n(1.3), 17), "highpass", 4500.0, rate = RATE)
                mix(FloatArray(crash.size) { i -> crash[i] * exp(-i / RATE * 2.2).toFloat() * 0.6f }, it, 0.32)
                mix(kick(0.5), it, 0.32, 0.5f)
            }
            "crickets" -> FloatArray(n(2.4)).also {
                val chirp = FloatArray(n(0.035)) { i -> val t = i / RATE; (sin(2 * PI * 4600 * t) * sin(PI * t / 0.035)).toFloat() * 0.35f }
                for (c in 0 until 6) for (k in 0 until 3) mix(chirp, it, c * 0.4 + k * 0.055)
            }
            "horn" -> FloatArray(n(1.6)).also {
                for ((start, len) in listOf(0.0 to 0.18, 0.24 to 0.18, 0.48 to 0.9)) {
                    val blast = FloatArray(n(len))
                    for (f in listOf(440.0, 466.0, 554.0)) {
                        var ph = 0.0
                        for (i in blast.indices) {
                            val t = i / RATE
                            ph += f * (1 + 0.006 * sin(2 * PI * 6 * t)) / RATE; if (ph > 1) ph -= 1
                            blast[i] += (2 * ph - 1).toFloat() * 0.22f * (min(1.0, t / 0.01) * min(1.0, (len - t) / 0.03)).toFloat()
                        }
                    }
                    mix(Dsp.drive(blast, 2.5f), it, start)
                }
            }
            "whoosh" -> {
                val count = n(0.7)
                val hiss = noise(count, 23)
                var bq = Dsp.Biquad.make("bandpass", 400.0, 1.5, rate = RATE)
                FloatArray(count) { i ->
                    val p = i.toDouble() / count
                    if (i % 64 == 0) bq = Dsp.Biquad.make("bandpass", 300 + 3500 * p, 1.5, rate = RATE)
                    bq.run(hiss[i]) * sin(PI * p).toFloat() * 2.2f
                }
            }
            "pop" -> FloatArray(n(0.08)) { i -> val t = i / RATE; (sin(2 * PI * (600 + 9000 * t) * t) * exp(-t * 45)).toFloat() * 0.9f }
            else -> FloatArray(0)
        }
        return if (out.isEmpty()) out else Dsp.level(out)
    }

    fun wav(x: FloatArray): ByteArray = Dsp.wav(x, RATE.roundToInt())
}
