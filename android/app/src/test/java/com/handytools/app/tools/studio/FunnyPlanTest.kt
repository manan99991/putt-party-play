package com.handytools.app.tools.studio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Funny moments on Android, held to the iPhone's SynthTests timings: the moment is the laugh, and every look arrives on time. */
class FunnyPlanTest {
    @Test fun theMomentIsTheLaughAndTheLooksArriveOnTime() {
        val loud = MutableList(200) { 0.02 }
        for (i in 118..124) loud[i] = 0.4
        assertEquals(6.0, FunnyPlan.moment(loud, 0.05, 10.0, "scratch"), 0.2)
        assertEquals("no sound: 60% in", 6.0, FunnyPlan.moment(emptyList(), 0.05, 10.0, "boing"), 0.01)
        assertEquals("ba-dum-tss is at the end", 9.95, FunnyPlan.moment(loud, 0.05, 10.0, "rimshot"), 0.01)
        assertEquals(FunnyPlan.Look(), FunnyPlan.look("scratch", -0.5, 2.6))
        val s = FunnyPlan.look("scratch", 0.05, 2.6); val s2 = FunnyPlan.look("scratch", 1.5, 2.6)
        assertTrue(s.flash > 0); assertTrue(s2.grey > 0.8); assertEquals(1.0, s2.words, 0.01); assertTrue(s2.zoom > 1)
        assertEquals("after the freeze it's back to normal", FunnyPlan.Look(), FunnyPlan.look("scratch", 3.0, 2.6))
        assertTrue(FunnyPlan.look("dramatic", 0.2, 0.0).zoom < FunnyPlan.look("dramatic", 0.7, 0.0).zoom)
        assertTrue(FunnyPlan.look("dramatic", 0.7, 0.0).zoom < FunnyPlan.look("dramatic", 1.2, 0.0).zoom)
        assertNotEquals(0.0, FunnyPlan.look("horn", 0.3, 0.0).dx)
        assertNotEquals(1.0, FunnyPlan.look("boing", 0.05, 0.0).squash)
    }

    @Test fun loudnessFollowsTheSound() {
        val rate = 16_000
        val x = FloatArray(rate * 2) { i -> if (i in rate until rate + rate / 4) 0.5f else 0.01f }
        val l = FunnyPlan.loudness(x, rate, 0.05)
        assertEquals(40, l.size)
        assertTrue(l[21] > l[5] * 10)
        assertEquals(1.0, FunnyPlan.moment(l, 0.05, 2.0, "scratch"), 0.15)
    }

    @Test fun everyJokeHasItsOwnSound() {
        for (k in FunnyPlan.kinds) assertTrue(k.id, Synth.effect(k.sound).isNotEmpty())
        assertEquals(6, FunnyPlan.kinds.size)
    }
}
