package com.handytools.app.tools.studio

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tanh

/**
 * The sound building blocks the studio tools share (the iPhone's VoiceFX, same maths): the audio-cookbook filters,
 * a warm overdrive, distinct echoes, and levelling so everything ends up equally loud. Pure Kotlin, no Android, so
 * every piece is unit-tested on the JVM.
 */
object Dsp {
    /** A second-order filter (the standard audio cookbook). */
    class Biquad(private val b0: Float, private val b1: Float, private val b2: Float, private val a1: Float, private val a2: Float) {
        private var x1 = 0f; private var x2 = 0f; private var y1 = 0f; private var y2 = 0f
        fun run(x: Float): Float {
            val y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x; y2 = y1; y1 = y
            return y
        }

        companion object {
            fun make(kind: String, f: Double, q: Double = 0.707, gainDB: Double = 0.0, rate: Double): Biquad {
                val w = 2 * PI * minOf(f, rate * 0.45) / rate
                val cw = cos(w); val sw = sin(w); val alpha = sw / (2 * q)
                val a = 10.0.pow(gainDB / 40)
                var b0 = 1.0; var b1 = 0.0; var b2 = 0.0; var a0 = 1.0; var a1 = 0.0; var a2 = 0.0
                when (kind) {
                    "lowpass" -> { b0 = (1 - cw) / 2; b1 = 1 - cw; b2 = (1 - cw) / 2; a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha }
                    "highpass" -> { b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = (1 + cw) / 2; a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha }
                    "bandpass" -> { b0 = alpha; b1 = 0.0; b2 = -alpha; a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha }
                    "peak" -> { b0 = 1 + alpha * a; b1 = -2 * cw; b2 = 1 - alpha * a; a0 = 1 + alpha / a; a1 = -2 * cw; a2 = 1 - alpha / a }
                    "lowshelf" -> {
                        val s = 2 * sqrt(a) * alpha
                        b0 = a * ((a + 1) - (a - 1) * cw + s); b1 = 2 * a * ((a - 1) - (a + 1) * cw); b2 = a * ((a + 1) - (a - 1) * cw - s)
                        a0 = (a + 1) + (a - 1) * cw + s; a1 = -2 * ((a - 1) + (a + 1) * cw); a2 = (a + 1) + (a - 1) * cw - s
                    }
                    "highshelf" -> {
                        val s = 2 * sqrt(a) * alpha
                        b0 = a * ((a + 1) + (a - 1) * cw + s); b1 = -2 * a * ((a - 1) + (a + 1) * cw); b2 = a * ((a + 1) + (a - 1) * cw - s)
                        a0 = (a + 1) - (a - 1) * cw + s; a1 = 2 * ((a - 1) - (a + 1) * cw); a2 = (a + 1) - (a - 1) * cw - s
                    }
                }
                return Biquad((b0 / a0).toFloat(), (b1 / a0).toFloat(), (b2 / a0).toFloat(), (a1 / a0).toFloat(), (a2 / a0).toFloat())
            }
        }
    }

    fun filter(x: FloatArray, kind: String, f: Double, q: Double = 0.707, gainDB: Double = 0.0, rate: Double): FloatArray {
        val bq = Biquad.make(kind, f, q, gainDB, rate)
        return FloatArray(x.size) { bq.run(x[it]) }
    }

    /** Overdrive: rounds off the peaks so it growls. */
    fun drive(x: FloatArray, amount: Float): FloatArray { val d = tanh(amount); return FloatArray(x.size) { tanh(x[it] * amount) / d } }

    /** Distinct repeats, each quieter. */
    fun echoes(x: FloatArray, delays: List<Double>, decay: Float, rate: Double): FloatArray {
        val tail = ((delays.maxOrNull() ?: 0.0) * rate * delays.size).toInt()
        val out = x.copyOf(x.size + tail)
        delays.forEachIndexed { n, d ->
            val off = (d * rate).toInt(); val g = decay.pow(n + 1)
            for (i in x.indices) if (i + off < out.size) out[i + off] += x[i] * g
        }
        return out
    }

    /** Peak just under full scale, with a soft limiter for the loud bits. */
    fun level(x: FloatArray): FloatArray {
        var peak = 0f
        for (v in x) peak = maxOf(peak, abs(v))
        if (peak <= 1e-5f) return x
        val g = 0.89f / peak; val k = tanh(1.15f)
        return FloatArray(x.size) { tanh(x[it] * g * 1.15f) / k * 0.97f }
    }

    /** Zero crossings per second, halved — a cheap, steady stand-in for how bright a sound is. */
    fun brightness(x: FloatArray, rate: Double): Double {
        var z = 0
        for (i in 1 until x.size) if ((x[i - 1] < 0) != (x[i] < 0)) z++
        return z / 2.0 / (x.size / rate)
    }

    /** 16-bit mono WAV of [x] at [rate]. */
    fun wav(x: FloatArray, rate: Int): ByteArray {
        val data = x.size * 2
        val out = java.io.ByteArrayOutputStream(44 + data)
        fun i32(v: Int) { out.write(v and 0xFF); out.write((v shr 8) and 0xFF); out.write((v shr 16) and 0xFF); out.write((v shr 24) and 0xFF) }
        fun i16(v: Int) { out.write(v and 0xFF); out.write((v shr 8) and 0xFF) }
        out.write("RIFF".toByteArray()); i32(36 + data); out.write("WAVE".toByteArray())
        out.write("fmt ".toByteArray()); i32(16); i16(1); i16(1); i32(rate); i32(rate * 2); i16(2); i16(16)
        out.write("data".toByteArray()); i32(data)
        for (v in x) i16((v.coerceIn(-1f, 1f) * 32767).toInt())
        return out.toByteArray()
    }
}

/** The same small xorshift as the iPhone's, so the same seed makes the same noise. */
class SeededRandom(seed: Long) {
    private var state: ULong = if (seed == 0L) 0x9E3779B97F4A7C15uL else seed.toULong()
    fun next(): Double {
        state = state xor (state shl 13); state = state xor (state shr 7); state = state xor (state shl 17)
        return (state % 1_000_000uL).toDouble() / 1_000_000
    }
    fun next(lo: Double, hi: Double): Double = lo + (hi - lo) * next()
}
