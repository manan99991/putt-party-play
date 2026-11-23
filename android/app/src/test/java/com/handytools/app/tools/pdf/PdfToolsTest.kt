package com.handytools.app.tools.pdf

import com.handytools.app.tools.zip.Zipper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PdfToolsTest {
    @Test fun movingAndTurningPages() {
        val start = PdfPages.start(3)
        assertEquals(listOf(1, 0, 2), PdfPages.move(start, 1, -1).map { it.page })
        assertEquals(start, PdfPages.move(start, 0, -1))
        assertEquals(listOf(0, 2, 1), PdfPages.move(start, 1, 1).map { it.page })
        assertEquals(90, PdfPages.turn(start, 2)[2].turn)
        assertEquals(0, (1..4).fold(start) { s, _ -> PdfPages.turn(s, 0) }[0].turn)
        assertEquals(listOf(1, 1), PdfPages.start(2, source = 1).map { it.source })
    }

    @Test fun blankPagesAreSpotted() {
        assertTrue(PdfCore.isBlank(IntArray(1000) { 0xFFFFFFFF.toInt() }))
        assertFalse(PdfCore.isBlank(IntArray(1000) { if (it % 50 == 0) 0xFF000000.toInt() else 0xFFFFFFFF.toInt() }))
    }

    @Test fun passwordStrengthInWords() {
        assertTrue(PdfProtect.strength("abc").startsWith("Too short"))
        assertTrue(PdfProtect.strength("abcdefg").startsWith("Weak"))
        assertEquals("Good", PdfProtect.strength("abcdef12"))
        assertEquals("Strong", PdfProtect.strength("Tenzy-2026-safe"))
    }

    @Test fun zipNamesNeverClash() {
        assertEquals(listOf("a.pdf", "a (2).pdf", "b", "b (2)", "A (3).pdf"), Zipper.uniqueNames(listOf("a.pdf", "a.pdf", "b", "b", "A.pdf")))
    }
}
