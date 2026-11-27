package com.handytools.app.tools.studio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Behind the person and funny faces on Android: how the people found a few times a second are followed frame by frame. */
class PeopleTest {
    @Test fun looksAreSpacedSoAMinuteIsAtMost240() {
        assertEquals(0.125, People.stepFor(10.0), 1e-9)
        assertEquals(60.0 / 240, People.stepFor(60.0), 1e-9)
        assertEquals(Triple(0, 1, 0.5f), People.around(0.0625, 0.125, 10))
        assertEquals(Triple(9, 9, 0f), People.around(99.0, 0.125, 10))
        assertEquals(Triple(0, 0, 0f), People.around(3.0, 0.125, 1))
    }

    @Test fun facesGlideToWhereTheyAreNext() {
        val a = listOf(FaceSpot(0.4f, 0.4f, 0.2f, listOf(Spot(0.35f, 0.38f), Spot(0.45f, 0.38f))))
        val b = listOf(FaceSpot(0.5f, 0.4f, 0.3f, listOf(Spot(0.45f, 0.38f), Spot(0.55f, 0.38f))))
        val mid = People.glide(a, b, 0.5f).single()
        assertEquals(0.45f, mid.x, 1e-6f); assertEquals(0.25f, mid.size, 1e-6f); assertEquals(0.40f, mid.eyes[0].x, 1e-6f)
        // A face far away isn't the same face: it doesn't fly across the frame.
        val far = listOf(FaceSpot(0.9f, 0.9f, 0.2f))
        assertEquals(a, People.glide(a, far, 0.5f))
        // A face that appears shows from halfway.
        assertTrue(People.glide(emptyList(), b, 0.4f).isEmpty()); assertEquals(b, People.glide(emptyList(), b, 0.6f))
    }

    @Test fun aMissedLookKeepsTheLastFacesBriefly() {
        val f = listOf(FaceSpot(0.5f, 0.5f, 0.2f))
        val filled = People.fillGaps(listOf(f, emptyList(), emptyList(), emptyList(), emptyList(), emptyList(), emptyList()), 0.125)
        assertEquals(f, filled[1]); assertEquals(f, filled[4])     // 0.5 s later: still there
        assertTrue(filled[6].isEmpty())                            // 0.75 s later: gone
        assertTrue(People.fillGaps(listOf(emptyList(), f), 0.125)[0].isEmpty())
    }

    @Test fun theShaderGetsFacesUpright() {
        val (face, eyes) = PeopleEffect.uniforms(FaceSpot(0.5f, 0.3f, 0.25f, listOf(Spot(0.45f, 0.28f), Spot(0.55f, 0.28f))), 1080, 1920)
        assertEquals(0.5f, face[0], 1e-6f)
        assertTrue("y turns over (GL counts from the bottom) and the centre moves up a little", face[1] > 0.7f && face[1] < 0.73f)
        assertEquals(1f, face[3], 0f); assertEquals(0.72f, eyes[1], 1e-6f)
        val (none, noEyes) = PeopleEffect.uniforms(null, 1080, 1920)
        assertEquals(0f, none[3], 0f); assertTrue(noEyes.all { it < -1 })
    }

    @Test fun everyChoiceHasItsShaderCode() {
        for (c in VideoEffects.backgrounds) assertTrue(c.id, PeopleEffect.backgroundCodes.containsKey(c.id))
        for (c in VideoEffects.funnies) assertTrue(c.id, c.id == "none" || FaceFun.effect(c.id) != null)
        assertTrue(!VideoEffects.Recipe(background = "blur").isPlain && !VideoEffects.Recipe(funny = "bighead").isPlain)
    }

    @Test fun maskValuesAreReadTopDown() {
        val w = 4; val h = 4
        val m = ByteArray(w * h) { i -> if (i / w < 2) 0 else (-1).toByte() }   // bottom half is person
        assertEquals(0, People.valueAt(m, w, h, 0.5f, 0.1f)); assertEquals(255, People.valueAt(m, w, h, 0.5f, 0.9f))
        assertEquals(0.5, People.share(m), 1e-9)
    }
}
