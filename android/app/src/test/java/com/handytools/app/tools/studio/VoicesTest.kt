package com.handytools.app.tools.studio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Android's nineteen voices, held to the iPhone's VoiceFXTests: every voice is its own sound and levelled, the radio
 * is a thin band, the giant is full of low end, the cave echoes, the whisper has no pitch left, the announcer's
 * stadium answers back, and auto-tune really lands on notes. Plus the shifter itself: pitch moves, length doesn't.
 */
class VoicesTest {
    private val rate = 44_100.0

    /** A stand-in for speech: a 140 Hz voice with harmonics, in syllables. */
    private fun speech(seconds: Double = 2.0) = FloatArray((seconds * rate).toInt()) { i ->
        val t = i / rate
        val syllable = max(0.0, sin(2 * PI * 3 * t))
        var v = 0.0
        for (h in 1..12) v += sin(2 * PI * 140 * h * t) / h
        (v * 0.25 * syllable).toFloat()
    }

    private fun tone(hz: Double, seconds: Double) = FloatArray((seconds * rate).toInt()) { i ->
        val t = i / rate; var v = 0.0
        for (h in 1..6) v += sin(2 * PI * hz * h * t) / h
        (v * 0.3).toFloat()
    }

    private fun peak(x: FloatArray) = x.maxOf { abs(it) }
    private fun diff(a: FloatArray, b: FloatArray): Double { val n = minOf(a.size, b.size); var s = 0.0; for (i in 0 until n) s += abs(a[i] - b[i]); return s / n }
    private fun pitchOf(x: FloatArray, at: Int) = Voices.detect(x.copyOfRange(at, at + 2048), rate)

    @Test fun theShifterMovesPitchNotLength() {
        val x = tone(220.0, 2.0)
        for ((cents, want) in listOf(700.0 to 220 * 1.4983, -1200.0 to 110.0, 1200.0 to 440.0)) {
            val y = Voices.shift(x, rate) { cents }
            assertEquals("same length", x.size, y.size)
            val p = assertNotNullPitch(pitchOf(y, y.size / 2), "no clear pitch after shifting by $cents")
            assertEquals("shifted by $cents", want, p, want * 0.03)
        }
        // Faster speech, same pitch.
        val fast = Voices.shift(x, rate, tempo = 1.25) { 0.0 }
        assertEquals((x.size / 1.25).roundToInt(), fast.size)
        assertEquals(220.0, assertNotNullPitch(pitchOf(fast, fast.size / 2), "no pitch at 1.25x"), 220 * 0.03)
    }

    private fun assertNotNullPitch(p: Pair<Double, Double>?, why: String): Double { assertNotNull(why, p); return p!!.first }

    @Test fun everyVoiceIsItsOwnSound() {
        val x = speech()
        assertTrue(Voices.all.size >= 19)
        val outs = HashMap<String, FloatArray>()
        for (v in Voices.all) {
            assertNotNull(v.id, Voices.characters[v.id])
            val y = Voices.apply(v.id, x, rate)
            assertFalse(v.id, y.isEmpty())
            assertTrue("${v.id} never clips", peak(y) <= 1f)
            assertTrue("${v.id} is levelled, not quiet", peak(y) > 0.5f)
            outs[v.id] = y
        }
        assertTrue("the walkie-talkie is a thin band", Voices.lowShare(outs["walkie"]!!, 300.0, rate) < 0.05)
        assertTrue(Voices.lowShare(outs["giant"]!!, 300.0, rate) > Voices.lowShare(outs["helium"]!!, 300.0, rate) * 3)
        assertTrue(Dsp.brightness(outs["underwater"]!!, rate) < Dsp.brightness(outs["megaphone"]!!, rate))
        assertTrue("the cave echoes on", outs["cave"]!!.size > x.size + (0.5 * rate).toInt())
        assertTrue("the walkie-talkie clicks on and off", outs["walkie"]!!.size > x.size)
        assertTrue(diff(outs["robot"]!!, Dsp.level(x)) > 0.1)
        assertTrue(diff(outs["alien"]!!, outs["robot"]!!) > 0.05)
        assertTrue(diff(outs["ghost"]!!, outs["oldman"]!!) > 0.03)
    }

    @Test fun theNewVoicesDoWhatTheySay() {
        val x = speech()
        // Whisper: the words' shape is there, but no pitch is left.
        val w = Voices.apply("whisper", x, rate)
        var pitched = 0; var frames = 0
        for (a in 0 until w.size - 2048 step 4096) { frames++; if ((Voices.detect(w.copyOfRange(a, a + 2048), rate)?.second ?: 0.0) > 0.85) pitched++ }
        var voiced = 0
        for (a in 0 until x.size - 2048 step 4096) if ((Voices.detect(x.copyOfRange(a, a + 2048), rate)?.second ?: 0.0) > 0.85) voiced++
        assertTrue("the stand-in speech should have pitch to lose", voiced > frames / 3)
        assertTrue("the whisper still has a pitch in $pitched of $frames stretches", pitched <= frames / 10)
        // Old radio: a narrow band.
        val r = Voices.apply("radio", x, rate)
        assertTrue(Voices.lowShare(r, 200.0, rate) < 0.08)
        assertTrue("an old radio's speaker has no top", 1 - Voices.lowShare(r, 4500.0, rate) < 0.06)
        // Announcer: the stadium answers back after the voice stops.
        assertTrue(Voices.apply("announcer", x, rate).size > x.size + (0.4 * rate).toInt())
        // Auto-tune's target: a glide is pulled onto the nearest note of the scale.
        val glide = FloatArray((2 * rate).toInt()) { i ->
            val t = i / rate; val hz = 200 + 30 * t; var v = 0.0
            for (h in 1..6) v += sin(2 * PI * hz * h * t) / h
            (v * 0.3).toFloat()
        }
        val curve = Voices.snapCurve(glide, rate, 1024)
        assertTrue(curve.isNotEmpty())
        assertTrue("a correction is never more than two semitones", curve.all { abs(it) <= 200 })
        assertTrue("most of a glide needs pulling onto a note", curve.count { abs(it) > 10 } > curve.size / 2)
    }

    /** Auto-tune through the whole render: the sung result sits on notes far more than the glide it came from. */
    @Test fun autoTuneLandsOnNotes() {
        val glide = FloatArray((3 * rate).toInt()) { i ->
            val t = i / rate; val hz = 200 + 25 * t; var v = 0.0
            for (h in 1..6) v += sin(2 * PI * hz * h * t) / h
            (v * 0.3).toFloat()
        }
        fun offNote(y: FloatArray): Double {
            var total = 0.0; var n = 0
            var a = 8192
            while (a < y.size - 2048 - 8192) {
                Voices.detect(y.copyOfRange(a, a + 2048), rate, 100.0, 600.0)?.let { (hz, clarity) ->
                    if (clarity > 0.8) { val midi = 12 * ln(hz / 440) / ln(2.0) + 69; total += abs(midi - midi.roundToInt()) * 100; n++ }
                }
                a += 2048
            }
            return if (n > 0) total / n else 99.0
        }
        val sung = Voices.render("autotune", glide, rate)
        val before = offNote(glide); val after = offNote(sung)
        assertTrue("the glide should start off the notes ($before)", before > 15)
        assertTrue("auto-tune moved it from $before to only $after cents off a note", after < before * 0.6)
    }

    @Test fun everyVoiceRendersWholeWithItsSpeed() {
        val x = speech(1.0)
        for (v in Voices.all) {
            val c = Voices.characters[v.id]!!
            val y = Voices.render(v.id, x, rate)
            assertTrue("${v.id} is at least as long as its speed says", y.size >= (x.size / c.rate * 0.98).toInt())
            assertTrue("${v.id} clips", peak(y) <= 1f)
        }
    }
}
