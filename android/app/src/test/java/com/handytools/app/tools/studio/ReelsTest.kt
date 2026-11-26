package com.handytools.app.tools.studio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.roundToInt

/** Beat Reel's plan on Android, held to the iPhone's BeatReelTests: cuts on beats in whole bars, every clip used,
 *  each clip's turns spread through it, one slow-motion moment, and the punch lands on the beat. */
class ReelsTest {
    @Test fun thePlanCutsOnTheBeat() {
        for (st in Synth.styles) {
            val lengths = listOf(8.0, 3.5, 20.0, 6.0)
            val (cuts, total) = Reels.plan(lengths, st)
            val beat = 60 / st.bpm; val bar = beat * 4
            assertTrue(st.id, cuts.isNotEmpty())
            assertEquals("${st.id}: whole bars", (total / bar).roundToInt().toDouble(), total / bar, 0.001)
            assertEquals("${st.id}: the cuts fill the reel exactly", total, cuts.sumOf { it.lasts }, 0.01)
            var at = 0.0
            for (c in cuts) {
                assertEquals("${st.id}: a cut at $at s is off the beat", (at / beat).roundToInt().toDouble(), at / beat, 0.001)
                assertTrue(c.from >= 0); assertTrue("${st.id}: a cut runs past its clip's end", c.from + c.length <= lengths[c.clip] + 0.001)
                at += c.lasts
            }
            assertEquals("${st.id}: every clip is used", lengths.indices.toSet(), cuts.map { it.clip }.toSet())
            assertEquals("${st.id}: one slow-motion moment", 1, cuts.count { it.slow })
            val longTurns = cuts.filter { it.clip == 2 }.map { it.from }
            assertEquals(longTurns.sorted(), longTurns); assertEquals(longTurns.size, longTurns.toSet().size)
        }
        assertEquals(30.0, Reels.plan(listOf(10.0), Synth.style("upbeat"), 30.0).second, 60.0 / 118 * 4)
        assertTrue(Reels.plan(emptyList(), Synth.style("upbeat")).first.isEmpty())
    }

    @Test fun thePunchLandsOnTheBeat() {
        val beats = listOf(1.0, 1.5)
        assertEquals(0.0, Reels.punch(0.9, beats), 1e-9)
        assertEquals(1.0, Reels.punch(1.0, beats), 1e-9)
        assertTrue(Reels.punch(1.05, beats) < 1 && Reels.punch(1.05, beats) > Reels.punch(1.3, beats))
        assertEquals(1.0, Reels.punch(1.5, beats), 1e-9)
    }
}
