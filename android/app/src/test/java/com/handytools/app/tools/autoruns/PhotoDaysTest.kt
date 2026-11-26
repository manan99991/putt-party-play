package com.handytools.app.tools.autoruns

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The day's collage on Android: justified rows that use every photo once, in order, edge to edge, never overlapping. */
class PhotoDaysTest {
    @Test fun rowsAreFullWidthAndEveryPhotoIsPlacedOnce() {
        val aspects = listOf(1.5, 0.75, 1.0, 1.78, 0.56, 1.33, 0.8, 2.4, 1.0)
        val boxes = PhotoDays.layout(aspects, width = 1080, gap = 8, rowHeight = 420)
        assertEquals(aspects.size, boxes.size)
        val rows = boxes.groupBy { it.top }
        rows.values.toList().dropLast(1).forEach { row -> assertEquals("a full row reaches the right edge", 1080 - 8, row.last().right) }
        boxes.forEach { b -> assertTrue(b.width > 0 && b.height > 0) }
        for (i in boxes.indices) for (j in i + 1 until boxes.size) {
            val a = boxes[i]; val b = boxes[j]
            assertTrue("tiles $i and $j overlap", a.right <= b.left || b.right <= a.left || a.bottom <= b.top || b.bottom <= a.top)
        }
        // Each tile keeps (about) its photo's shape in a full row.
        rows.values.first().forEach { b -> assertTrue(b.height in 200..700) }
        assertTrue(PhotoDays.layout(emptyList()).isEmpty())
        assertEquals(1080 - 8, PhotoDays.layout(listOf(3.5)).single().right)
    }
}
