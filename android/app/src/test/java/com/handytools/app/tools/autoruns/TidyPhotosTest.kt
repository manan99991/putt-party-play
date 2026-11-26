package com.handytools.app.tools.autoruns

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Tidy up on Android: only screenshots over a week old, and the useful ones always stay. */
class TidyPhotosTest {
    @Test fun onlyScreenshotsOverAWeekOldAreOffered() {
        val now = 1_800_000_000_000L; val day = 24 * 3600_000L
        val shots = listOf(TidyPhotos.Shot("a", 1, now - 2 * day), TidyPhotos.Shot("b", 2, now - 8 * day), TidyPhotos.Shot("c", 3, now - 30 * day))
        assertEquals(listOf(3L, 2L), TidyPhotos.oldScreenshots(shots, now).map { it.bytes })
    }

    @Test fun ticketsCodesAndReceiptsStay() {
        assertTrue(TidyPhotos.worthKeeping("BOARDING PASS  Gate B12  Seat 14C"))
        assertTrue(TidyPhotos.worthKeeping("Your order #4412 — Total $23.40"))
        assertTrue(TidyPhotos.worthKeeping("Booking confirmation for 2 nights"))
        assertFalse(TidyPhotos.worthKeeping("lol look at this cat"))
        assertFalse(TidyPhotos.worthKeeping(""))
    }
}
