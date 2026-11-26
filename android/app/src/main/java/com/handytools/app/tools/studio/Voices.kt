package com.handytools.app.tools.studio

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * "Change the voice" on Android: the iPhone's nineteen voices, same settings and same character chains. The iPhone
 * shifts pitch with Apple's time-pitch unit; here a grain shifter does it (pitch moves, speed doesn't), with a small
 * room reverb, so the words stay clear. Pure Kotlin on plain samples: every voice is unit-tested on the JVM.
 * Never voice cloning and never a real person's voice — speed, pitch and tone only (rulebook).
 */
object Voices {
    /** How a voice is made: pitch in cents, how fast it's spoken, and the room it's in (0…1 size, wet 0…1). */
    data class Character(val cents: Double, val rate: Double = 1.0, val room: Double = 0.0, val wet: Double = 0.0)
    data class Voice(val id: String, val name: String)

    val all = listOf(
        Voice("chipmunk", "Chipmunk"), Voice("helium", "Helium"), Voice("deep", "Deep"), Voice("giant", "Giant"),
        Voice("robot", "Robot"), Voice("alien", "Alien"), Voice("monster", "Monster"), Voice("walkie", "Walkie-talkie"),
        Voice("cave", "Echo cave"), Voice("ghost", "Ghost"), Voice("baby", "Baby"), Voice("oldman", "Old man"),
        Voice("underwater", "Underwater"), Voice("megaphone", "Megaphone"), Voice("villain", "Villain"),
        Voice("autotune", "Auto-tune singer"), Voice("announcer", "Stadium announcer"), Voice("radio", "Old radio"), Voice("whisper", "Whisper"),
    )

    // The iPhone's table (its reverb presets as room sizes): largeHall 0.85, mediumHall 0.7, cathedral 0.95,
    // largeHall2 0.9, mediumRoom 0.5.
    val characters = mapOf(
        "chipmunk" to Character(1100.0, 1.18), "helium" to Character(500.0), "deep" to Character(-500.0, 0.96),
        "giant" to Character(-1000.0, 0.86, 0.85, 0.20), "robot" to Character(-200.0), "alien" to Character(600.0, 1.02),
        "monster" to Character(-800.0, 0.93, 0.7, 0.12), "walkie" to Character(0.0), "cave" to Character(-100.0, 1.0, 0.95, 0.35),
        "ghost" to Character(300.0, 0.92, 0.9, 0.45), "baby" to Character(800.0, 1.08), "oldman" to Character(-250.0, 0.9),
        "underwater" to Character(-150.0, 0.97), "megaphone" to Character(0.0), "villain" to Character(-650.0, 0.95, 0.7, 0.15),
        "autotune" to Character(0.0, 1.0, 0.5, 0.14), "announcer" to Character(-180.0, 0.94, 0.85, 0.22),
        "radio" to Character(0.0), "whisper" to Character(0.0, 0.97),
    )

    /** [x] (mono, at [rate]) in voice [id]: pitch and speed, the room, then the character — levelled. */
    fun render(id: String, x: FloatArray, rate: Double): FloatArray {
        val c = characters[id] ?: return Dsp.level(x)
        val curve = if (id == "autotune") snapCurve(x, rate, 1024) else null
        var y = shift(x, rate, tempo = c.rate.coerceIn(0.5, 2.0)) { at -> c.cents + (curve?.let { it[min(it.size - 1, at / 1024)].toDouble() } ?: 0.0) }
        if (c.wet > 0) y = reverb(y, rate, c.room, c.wet)
        return apply(id, y, rate)
    }

    // MARK: pitch without speed

    /**
     * Grain pitch shifter: overlapping windowed grains, each read from the input at its own pitch ([cents] of the
     * input position, so it can change as it goes — auto-tune), placed where [tempo] says (1 = same length). Each
     * grain starts where it lines up best with the last, so voices don't flutter.
     */
    fun shift(x: FloatArray, rate: Double, tempo: Double = 1.0, cents: (Int) -> Double): FloatArray {
        if (x.isEmpty()) return x
        val n = (0.046 * rate).roundToInt().let { it - it % 2 }.coerceAtLeast(64)
        val hop = n / 2
        val outLen = max(1, (x.size / tempo).roundToInt())
        val out = FloatArray(outLen + n); val norm = FloatArray(outLen + n)
        val win = FloatArray(n) { (0.5 - 0.5 * cos(2 * PI * it / n)).toFloat() }
        val tol = (0.01 * rate).roundToInt()
        var lastStart = -1.0; var lastRatio = 1.0
        var k = 0
        while (k * hop < outLen) {
            val outPos = k * hop
            val inPos = (outPos * tempo).roundToInt().coerceIn(0, x.size - 1)
            val ratio = 2.0.pow(cents(inPos) / 1200)
            var start = inPos.toDouble()
            if (lastStart >= 0) {
                // Where the last grain's sound naturally carries on, and the nearby start that matches it best.
                val natural = lastStart + hop * lastRatio
                var best = 0; var bestScore = Double.NEGATIVE_INFINITY
                var d = -tol
                while (d <= tol) {
                    var s = 0.0
                    var j = 0
                    while (j < hop) {
                        s += read(x, inPos + d + j * ratio) * read(x, natural + j * lastRatio)
                        j += 4
                    }
                    if (s > bestScore) { bestScore = s; best = d }
                    d += 2
                }
                start = inPos + best.toDouble()
            }
            for (j in 0 until n) {
                val v = read(x, start + j * ratio)
                out[outPos + j] += v * win[j]; norm[outPos + j] += win[j]
            }
            lastStart = start; lastRatio = ratio
            k++
        }
        return FloatArray(outLen) { if (norm[it] > 0.05f) out[it] / norm[it] else out[it] }
    }

    private fun read(x: FloatArray, p: Double): Float {
        if (p < 0 || p >= x.size - 1) return 0f
        val i = p.toInt(); val f = (p - i).toFloat()
        return x[i] * (1 - f) + x[i + 1] * f
    }

    // MARK: rooms

    /** A small Schroeder room: four combs and two all-passes, [size] 0…1 sets how long it rings, [wet] how much. */
    fun reverb(x: FloatArray, rate: Double, size: Double, wet: Double): FloatArray {
        val tail = (rate * (0.4 + 1.4 * size)).toInt()
        val dry = x.copyOf(x.size + tail)
        val k = rate / 44_100.0
        val combs = listOf(1557, 1617, 1491, 1422).map { (it * k * (0.7 + 0.5 * size)).toInt().coerceAtLeast(8) }
        val fb = (0.7 + 0.25 * size).toFloat()
        val sum = FloatArray(dry.size)
        for (d in combs) {
            val buf = FloatArray(d); var p = 0; var lp = 0f
            for (i in dry.indices) {
                val y = buf[p]
                lp = y * 0.6f + lp * 0.4f                      // the walls soak up the highs
                buf[p] = dry[i] + lp * fb
                sum[i] += y
                p = (p + 1) % d
            }
        }
        var y = sum.map { it * 0.25f }.toFloatArray()
        for (d in listOf(556, 225).map { (it * k).toInt().coerceAtLeast(4) }) {
            val buf = FloatArray(d); var p = 0; val out = FloatArray(y.size)
            for (i in y.indices) { val b = buf[p]; val v = -0.5f * y[i] + b; buf[p] = y[i] + 0.5f * b; out[i] = v; p = (p + 1) % d }
            y = out
        }
        val w = wet.toFloat()
        return FloatArray(dry.size) { dry[it] * (1 - w * 0.5f) + y[it] * w }
    }

    // MARK: pitch, for auto-tune

    /** Fundamental of a mono buffer (normalised autocorrelation, McLeod-style), with its clarity; null when unclear. */
    fun detect(x: FloatArray, rate: Double, minHz: Double = 50.0, maxHz: Double = 1500.0): Pair<Double, Double>? {
        val n = x.size
        if (n < 256) return null
        var e = 0.0; for (v in x) e += v.toDouble() * v
        if (kotlin.math.sqrt(e / n) <= 0.005) return null
        val maxLag = min(n / 2, (rate / minHz).toInt()); val minLag = max(2, (rate / maxHz).toInt())
        if (maxLag <= minLag) return null
        val nsdf = FloatArray(maxLag + 2)
        for (lag in minLag..maxLag) {
            var acf = 0.0; var m = 0.0
            for (i in 0 until n - lag) { val a = x[i].toDouble(); val b = x[i + lag].toDouble(); acf += a * b; m += a * a + b * b }
            nsdf[lag] = if (m > 0) (2 * acf / m).toFloat() else 0f
        }
        var start = minLag
        while (start < maxLag && nsdf[start] > 0) start++
        var best = -1; var bestV = 0f
        var i = start
        while (i < maxLag) {
            if (nsdf[i] > 0) {
                var peak = i
                while (i < maxLag && nsdf[i] > 0) { if (nsdf[i] > nsdf[peak]) peak = i; i++ }
                if (nsdf[peak] > bestV) { bestV = nsdf[peak]; best = peak }
            } else i++
        }
        if (best <= 0) return null
        var chosen = best
        i = start
        while (i < maxLag) {   // the first peak within 0.9 of the best (no octave slips)
            if (nsdf[i] > 0) {
                var peak = i
                while (i < maxLag && nsdf[i] > 0) { if (nsdf[i] > nsdf[peak]) peak = i; i++ }
                if (nsdf[peak] >= 0.9f * bestV) { chosen = peak; break }
            } else i++
        }
        val clarity = nsdf[chosen].toDouble()
        if (clarity < 0.85) return null
        var lag = chosen.toDouble()
        if (chosen in 1 until maxLag) {
            val a = nsdf[chosen - 1].toDouble(); val b = nsdf[chosen].toDouble(); val c = nsdf[chosen + 1].toDouble()
            val d = a - 2 * b + c
            if (d != 0.0) lag += 0.5 * (a - c) / d
        }
        return rate / lag to clarity
    }

    /**
     * Auto-tune's target, in cents, every [step] samples: from the voice's pitch there to the nearest note of C major.
     * Where there's no clear pitch (a breath, an "s") the last correction holds. Pitch is found on a quarter-rate copy
     * (same answer, a sixteenth of the work).
     */
    fun snapCurve(x: FloatArray, rate: Double, step: Int): FloatArray {
        val major = setOf(0, 2, 4, 5, 7, 9, 11)
        val low = Dsp.filter(x, "lowpass", min(2400.0, rate * 0.11), rate = rate)
        val q = FloatArray(low.size / 4) { low[it * 4] }
        val qr = rate / 4; val win = 512
        val curve = ArrayList<Float>(); var last = 0f
        var i = 0
        while (i < x.size) {
            val a = ((i + step / 2) / 4 - win / 2).coerceIn(0, max(0, q.size - win))
            if (q.size >= win) detect(q.copyOfRange(a, a + win), qr, 70.0, 1000.0)?.let { (hz, clarity) ->
                if (clarity > 0.8) {
                    val midi = 12 * ln(hz / 440) / ln(2.0) + 69
                    var best = midi.roundToInt(); var bestD = Double.MAX_VALUE
                    for (nn in (midi.toInt() - 2)..(midi.toInt() + 2)) if (((nn % 12) + 12) % 12 in major) {
                        val d = abs(nn - midi); if (d < bestD) { bestD = d; best = nn }
                    }
                    last = ((best - midi) * 100).toFloat()
                }
            }
            curve += last
            i += step
        }
        return curve.toFloatArray()
    }

    // MARK: the characters (the iPhone's VoiceFX, same chains)

    fun ringMod(x: FloatArray, hz: Double, mix: Float, rate: Double): FloatArray { val k = 2 * PI * hz / rate; return FloatArray(x.size) { x[it] * (1 - mix) + x[it] * sin(k * it).toFloat() * mix } }

    fun vibrato(x: FloatArray, hz: Double, depthMs: Double, rate: Double): FloatArray {
        val depth = depthMs / 1000 * rate; val base = depth + 2
        return FloatArray(x.size) { i ->
            val p = i - (base + depth * sin(2 * PI * hz * i / rate))
            if (p < 0) 0f else { val j = p.toInt(); val f = (p - j).toFloat(); val a = x[j]; val b = if (j + 1 < x.size) x[j + 1] else a; a + (b - a) * f }
        }
    }

    fun tremolo(x: FloatArray, hz: Double, depth: Float, rate: Double): FloatArray { val k = 2 * PI * hz / rate; return FloatArray(x.size) { x[it] * (1 - depth * (0.5 + 0.5 * sin(k * it)).toFloat()) } }

    fun crush(x: FloatArray, bits: Int, hold: Int): FloatArray {
        val levels = (1 shl max(2, bits - 1)).toFloat(); var held = 0f
        return FloatArray(x.size) { i -> if (i % max(1, hold) == 0) held = (x[i] * levels).roundToInt() / levels; held }
    }

    fun flanger(x: FloatArray, hz: Double, mix: Float, rate: Double): FloatArray { val s = vibrato(x, hz, 2.5, rate); return FloatArray(x.size) { x[it] * (1 - mix) + s[it] * mix } }

    fun noiseBed(x: FloatArray, level: Float, seed: Long = 7): FloatArray { val r = SeededRandom(seed); return FloatArray(x.size) { x[it] + r.next(-1.0, 1.0).toFloat() * level } }

    fun squelch(x: FloatArray, rate: Double): FloatArray {
        val n = (0.12 * rate).toInt(); val r = SeededRandom(99)
        val burst = FloatArray(n) { r.next(-1.0, 1.0).toFloat() * 0.35f * (1 - it.toFloat() / n) }
        val beep = FloatArray((0.09 * rate).toInt()) { (sin(2 * PI * 1400 * it / rate) * 0.25).toFloat() }
        return burst + x + burst + beep
    }

    fun bubbles(x: FloatArray, rate: Double): FloatArray {
        val out = x.copyOf(); val r = SeededRandom(21)
        val every = (0.35 * rate).toInt(); val len = (0.04 * rate).toInt()
        var i = (r.next(0.0, 1.0) * every).toInt()
        while (i + len < out.size) {
            val f0 = r.next(300.0, 700.0)
            for (k in 0 until len) { val t = k / rate; out[i + k] += (sin(2 * PI * (f0 + 6000 * t) * t) * 0.12 * (1 - k.toDouble() / len)).toFloat() }
            i += (every * r.next(0.4, 1.6)).toInt()
        }
        return out
    }

    /** Whisper: the voice's shape in 16 bands carried by breath (noise) — the words stay, the pitch goes. */
    fun whisper(x: FloatArray, rate: Double): FloatArray {
        val lo = 180.0; val hi = min(9000.0, rate * 0.45); val bands = 16
        val r = SeededRandom(11)
        val noise = FloatArray(x.size) { r.next(-1.0, 1.0).toFloat() }
        val out = FloatArray(x.size)
        for (b in 0 until bands) {
            val f = lo * (hi / lo).pow((b + 0.5) / bands)
            val voice = Dsp.filter(x, "bandpass", f, q = 4.0, rate = rate)
            val env = Dsp.filter(FloatArray(voice.size) { abs(voice[it]) }, "lowpass", 35.0, rate = rate)
            val carrier = Dsp.filter(noise, "bandpass", f, q = 4.0, rate = rate)
            val tilt = (0.6 + 0.8 * b / bands).toFloat()
            for (i in x.indices) out[i] += carrier[i] * max(0f, env[i]) * tilt
        }
        return Dsp.filter(out, "highpass", 250.0, rate = rate)
    }

    fun crackle(x: FloatArray, rate: Double, hum: Float = 0.012f): FloatArray {
        val r = SeededRandom(41); val out = x.copyOf(); val k = 2 * PI / rate
        for (i in out.indices) out[i] += hum * (sin(k * 60 * i) + 0.5 * sin(k * 120 * i)).toFloat()
        var i = (r.next(0.0, 0.2) * rate).toInt()
        while (i < out.size) {
            val len = max(1, (r.next(0.001, 0.004) * rate).toInt()); val amp = r.next(0.08, 0.3).toFloat()
            for (j in 0 until len) if (i + j < out.size) out[i + j] += r.next(-1.0, 1.0).toFloat() * amp * (1 - j.toFloat() / len)
            i += (r.next(0.05, 0.4) * rate).toInt()
        }
        return out
    }

    private fun f(x: FloatArray, kind: String, hz: Double, rate: Double, q: Double = 0.707, gain: Double = 0.0) = Dsp.filter(x, kind, hz, q, gain, rate)

    /** The character chain for one voice, applied after its pitch shift, then levelled. */
    fun apply(voice: String, x: FloatArray, rate: Double): FloatArray {
        var y = x
        when (voice) {
            "chipmunk" -> { y = f(y, "highshelf", 3000.0, rate, gain = 4.0); y = vibrato(y, 7.0, 0.25, rate) }
            "helium" -> { y = f(y, "highpass", 380.0, rate); y = f(y, "peak", 2800.0, rate, 1.2, 6.0); y = vibrato(y, 5.0, 0.4, rate) }
            "deep" -> { y = f(y, "lowshelf", 180.0, rate, gain = 6.0); y = f(y, "highshelf", 5000.0, rate, gain = -4.0) }
            "giant" -> { y = f(y, "lowshelf", 140.0, rate, gain = 9.0); y = Dsp.drive(y, 1.6f); y = Dsp.echoes(y, listOf(0.09), 0.35f, rate) }
            "robot" -> { y = ringMod(y, 55.0, 0.85f, rate); y = Dsp.echoes(y, listOf(0.012), 0.6f, rate); y = crush(y, 9, 2); y = f(y, "peak", 1800.0, rate, 2.0, 5.0) }
            "alien" -> { y = vibrato(y, 6.5, 1.8, rate); y = ringMod(y, 420.0, 0.3f, rate); y = flanger(y, 0.4, 0.5f, rate) }
            "monster" -> { y = f(y, "lowshelf", 160.0, rate, gain = 8.0); y = Dsp.drive(y, 4f); y = tremolo(y, 28.0, 0.35f, rate); y = f(y, "lowpass", 4500.0, rate) }
            "walkie" -> {
                y = f(y, "highpass", 450.0, rate); y = f(y, "lowpass", 2600.0, rate); y = Dsp.drive(y, 3f); y = crush(y, 8, 3)
                y = f(y, "highpass", 500.0, rate); y = f(y, "highpass", 500.0, rate); y = f(y, "lowpass", 3000.0, rate)
                y = noiseBed(y, 0.025f); y = squelch(y, rate)
            }
            "cave" -> { y = Dsp.echoes(y, listOf(0.32, 0.32, 0.32), 0.5f, rate); y = f(y, "lowpass", 6000.0, rate) }
            "ghost" -> { y = vibrato(y, 0.9, 2.5, rate); y = tremolo(y, 3.0, 0.25f, rate); y = f(y, "highpass", 250.0, rate); y = noiseBed(y, 0.008f, 3) }
            "baby" -> { y = vibrato(y, 6.0, 0.6, rate); y = f(y, "highpass", 300.0, rate) }
            "oldman" -> { y = vibrato(y, 5.5, 0.9, rate); y = tremolo(y, 5.5, 0.3f, rate); y = f(y, "highshelf", 4000.0, rate, gain = -6.0) }
            "underwater" -> { y = f(y, "lowpass", 650.0, rate, 1.4); y = vibrato(y, 1.6, 1.5, rate); y = bubbles(y, rate) }
            "megaphone" -> { y = f(y, "highpass", 700.0, rate); y = f(y, "lowpass", 3800.0, rate); y = f(y, "peak", 1600.0, rate, 1.5, 8.0); y = Dsp.drive(y, 5f) }
            "villain" -> { y = f(y, "lowshelf", 120.0, rate, gain = 7.0); y = Dsp.drive(y, 1.8f); y = Dsp.echoes(y, listOf(0.06, 0.06), 0.3f, rate) }
            "autotune" -> {
                // The pitch is already snapped; a tight double and some sparkle make it a vocal.
                val double = vibrato(y, 0.25, 6.0, rate); val base = y
                y = FloatArray(base.size) { base[it] * 0.75f + double[it] * 0.35f }
                y = f(y, "highshelf", 6000.0, rate, gain = 3.0); y = f(y, "peak", 220.0, rate, 1.0, -2.0)
            }
            "announcer" -> { y = f(y, "lowshelf", 160.0, rate, gain = 5.0); y = f(y, "peak", 2600.0, rate, 1.0, 6.0); y = Dsp.drive(y, 1.7f); y = Dsp.echoes(y, listOf(0.24, 0.24), 0.32f, rate) }
            "radio" -> {
                // The valve's warmth first, then the little speaker, which lets nothing deep or bright through.
                y = Dsp.drive(y, 2.2f)
                y = f(y, "highpass", 320.0, rate); y = f(y, "highpass", 320.0, rate); y = f(y, "lowpass", 3400.0, rate); y = f(y, "lowpass", 3400.0, rate)
                y = f(y, "peak", 1100.0, rate, 1.2, 5.0); y = vibrato(y, 0.6, 0.5, rate); y = crackle(y, rate)
            }
            "whisper" -> y = whisper(y, rate)
        }
        return Dsp.level(y)
    }

    /** Share of energy below [hz] (for tests: proof a voice really is deep, thin or narrow). */
    fun lowShare(x: FloatArray, hz: Double, rate: Double): Double {
        val low = Dsp.filter(x, "lowpass", hz, rate = rate)
        var e = 0.0; var l = 0.0
        for (i in x.indices) { e += x[i].toDouble() * x[i]; l += low[i].toDouble() * low[i] }
        return if (e > 0) l / e else 0.0
    }

}
