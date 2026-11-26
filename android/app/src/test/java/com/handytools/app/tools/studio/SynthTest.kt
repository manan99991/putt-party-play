package com.handytools.app.tools.studio

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/**
 * Tenzy's own music and sound effects on Android, held to the same bar as the iPhone's SynthTests: the beats fall
 * where a reel will cut, every bar starts on a hit, nothing clips, the same request makes the same sound, and every
 * effect is its own sound.
 */
class SynthTest {
    private val rate = Synth.RATE

    /** Energy just after a time against just before it: a drum hit there makes the first much bigger. */
    private fun onset(x: FloatArray, t: Double): Double {
        val i = (t * rate).toInt(); val w = (0.03 * rate).toInt()
        fun e(a: Int, b: Int): Double { var s = 1e-9; for (j in maxOf(0, a) until minOf(x.size, b)) s += x[j].toDouble() * x[j]; return s }
        return e(i, i + w) / e(i - w, i)
    }

    private fun peak(x: FloatArray): Float = x.maxOf { abs(it) }

    @Test fun everyStyleHitsItsBarsAndNeverClips() {
        for (st in Synth.styles) {
            val track = Synth.track(st.id, 12.0)
            val x = track.samples; val beats = track.beats
            assertTrue(st.id, x.size / rate >= 12)
            assertEquals("${st.id}: whole bars", 0, beats.size % 4)
            assertEquals(st.id, 60 / st.bpm, beats[1] - beats[0], 0.001)
            assertTrue("${st.id} clips", peak(x) <= 1f); assertTrue("${st.id} is quiet", peak(x) > 0.5f)
            // Every bar's first beat (after the first, lighter bar) is a hit.
            val downbeats = (4 until beats.size step 4).map { beats[it] }
            val hits = downbeats.count { onset(x, it) > 1.6 }
            assertTrue("${st.id}: only $hits of ${downbeats.size} bars start on a hit", hits >= downbeats.size - 1)
        }
        // The same request makes the same sound (a re-made reel sounds the same).
        assertArrayEquals(Synth.track("chill", 4.0).samples.copyOf(5000), Synth.track("chill", 4.0).samples.copyOf(5000), 0f)
    }

    @Test fun everyEffectIsItsOwnSound() {
        for (e in Synth.effects) {
            val x = Synth.effect(e.id)
            assertTrue(e.id, x.size > (0.05 * rate).toInt())
            assertTrue("${e.id} clips", peak(x) <= 1f)
            assertTrue("${e.id} is quiet", peak(x) > 0.5f)
        }
        // A sting has three notes; a whoosh is noise, a boing is a tone.
        val sting = Synth.effect("sting")
        assertTrue(onset(sting, 0.5) > 1.3); assertTrue(onset(sting, 1.0) > 1.3)
        assertTrue(Dsp.brightness(Synth.effect("whoosh"), rate) > Dsp.brightness(Synth.effect("boing"), rate))
        assertTrue(Synth.effect("nothing").isEmpty())
    }

    @Test fun aWavFileIsWellFormed() {
        val x = Synth.effect("pop")
        val w = Synth.wav(x)
        assertEquals(44 + x.size * 2, w.size)
        assertEquals("RIFF", String(w, 0, 4)); assertEquals("WAVE", String(w, 8, 4)); assertEquals("data", String(w, 36, 4))
        val rateField = (w[24].toInt() and 0xFF) or ((w[25].toInt() and 0xFF) shl 8) or ((w[26].toInt() and 0xFF) shl 16)
        assertEquals(44_100, rateField)
    }

    @Test fun filtersShapeTheSoundTheWayTheySay() {
        // White noise through a low-pass is darker; through a high-pass brighter.
        val r = SeededRandom(7)
        val noise = FloatArray(44_100) { r.next(-1.0, 1.0).toFloat() }
        val low = Dsp.filter(noise, "lowpass", 500.0, rate = rate)
        val high = Dsp.filter(noise, "highpass", 5000.0, rate = rate)
        assertTrue(Dsp.brightness(low, rate) < Dsp.brightness(noise, rate))
        assertTrue(Dsp.brightness(high, rate) > Dsp.brightness(noise, rate))
        // Levelling lands just under full scale.
        assertEquals(0.97f * kotlin.math.tanh(0.89f * 1.15f) / kotlin.math.tanh(1.15f), peak(Dsp.level(FloatArray(10) { 0.2f })), 0.001f)
        // Echoes add a tail.
        assertEquals(1000 + (0.1 * rate).toInt() * 2, Dsp.echoes(FloatArray(1000), listOf(0.05, 0.1), 0.5f, rate).size)
    }
}
