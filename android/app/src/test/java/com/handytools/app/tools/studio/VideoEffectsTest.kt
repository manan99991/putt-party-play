package com.handytools.app.tools.studio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/** Video Effects on Android: the iPhone's beat finding, word arrivals and motions, held to the same rules. */
class VideoEffectsTest {
    @Test fun beatsAreFoundWhereTheSoundJumps() {
        val e = MutableList(100) { 0.05 }
        for (k in listOf(10, 30, 50, 70)) { e[k] = 0.6; e[k + 1] = 0.5 }
        val b = VideoEffects.beats(e, 0.05)
        assertEquals(listOf(0.5, 1.5, 2.5, 3.5), b.map { (it * 100).toInt() / 100.0 })
        assertTrue(VideoEffects.beats(List(100) { 0.1 }, 0.05).isEmpty())
        assertEquals(0.25, VideoEffects.steady(3.0).first(), 1e-9); assertEquals(6, VideoEffects.steady(3.0).size)
    }

    @Test fun wordsArriveTheWayTheirStyleSays() {
        for (s in VideoEffects.wordStyles.map { it.id }) {
            val before = VideoEffects.wordsMotion(s, 0.1); val after = VideoEffects.wordsMotion(s, 2.0)
            assertEquals("$s isn't there yet", 0.0, before.first, 1e-9)
            assertEquals("$s has arrived", 1.0, after.first, 1e-6)
            assertEquals("$s settles at full size", 1.0, after.second, 0.01)
        }
        assertTrue("slide starts low", VideoEffects.wordsMotion("slide", 0.3).third < 0)
        assertTrue("pop grows past full size", (0..40).map { VideoEffects.wordsMotion("pop", 0.2 + it * 0.01).second }.any { it > 1.0 })
    }

    @Test fun motionsNeverShowAnEdge() {
        for (m in VideoEffects.motions.map { it.id }) for (k in 0..50) {
            val (s, dx, dy) = VideoEffects.motion(m, k * 0.2, 10.0, listOf(1.0, 2.0, 3.0))
            assertTrue("$m zooms out", s >= 1.0)
            assertTrue("$m shows an edge", abs(dx) <= (s - 1) / 2 + 1e-9 && abs(dy) <= (s - 1) / 2 + 1e-9)
        }
        assertTrue(VideoEffects.motion("pulse", 1.0, 10.0, listOf(1.0)).first > VideoEffects.motion("pulse", 1.5, 10.0, listOf(1.0)).first)
        assertTrue(VideoEffects.motion("zoom", 9.0, 10.0, emptyList()).first > VideoEffects.motion("zoom", 1.0, 10.0, emptyList()).first)
    }

    @Test fun aPlainRecipeIsPlain() {
        assertTrue(VideoEffects.Recipe().isPlain)
        assertTrue(!VideoEffects.Recipe(words = "Happy birthday").isPlain)
        assertTrue(!VideoEffects.Recipe(look = "noir").isPlain)
    }
}
