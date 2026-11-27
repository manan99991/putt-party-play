package com.handytools.app.tools.studio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.hypot

/** Bald's fill (27 Nov rebuild): hair standing out beyond the skull is filled from what's beside it; nothing else moves. */
class BaldFillTest {
    @Test fun hairBeyondTheSkullIsFilledFromBesideIt() {
        val n = FaceEngine.SIDE
        // Skull: centre on the brow line at (128, 140), 40 wide and 60 tall, head upright (up is -y in the picture).
        val skull = FaceEngine.Skull(128f, 140f, 0f, -1f, 128f, 140f, 40f, 60f, floatArrayOf(0.8f, 0.6f, 0.5f), -1)
        val parts = FloatArray(n * n * 6)
        val rgb = IntArray(n * n) { i -> if (i % n < 128) 0xFFC81E1E.toInt() else 0xFF1E1EC8.toInt() }
        // Hair: a band 10 px thick round the skull's top, beyond it.
        for (i in 0 until n * n) {
            val x = i % n + 0.5f; val y = i / n + 0.5f
            val e = hypot((x - 128f) / 40f, (y - 140f) / 60f)
            if (y < 140 && e > 1.02f && e < 1.3f) { parts[i * 6 + 1] = 1f; rgb[i] = 0xFF202020.toInt() } else parts[i * 6] = 1f
        }
        val look = FaceEngine.Look(n, n, emptyList(), parts, rgb, listOf(skull))
        val out = BaldFill.filled(look, n, n)!!
        var holes = 0; var darkLeft = 0
        for (i in 0 until n * n) {
            if (parts[i * 6 + 1] < 0.5f) continue
            holes++
            val r = (out[i] shr 16) and 255; val b = out[i] and 255
            if (r < 80 && b < 80) darkLeft++
            if (i % n < 110) assertTrue("left of the head should fill red, got r=$r b=$b", r > b)
            if (i % n > 146) assertTrue("right of the head should fill blue, got r=$r b=$b", b > r)
        }
        assertTrue(holes > 100)
        assertEquals("hair left behind", 0, darkLeft)
        // Far from the head: untouched.
        assertEquals(rgb[5 * n + 5], out[5 * n + 5]); assertEquals(rgb[250 * n + 250], out[250 * n + 250])
        // Below the brow line nothing counts as beyond (beards stay).
        assertEquals(0f, BaldFill.beyond(skull, 1f, 128f, 200f), 1e-6f)
    }
}
