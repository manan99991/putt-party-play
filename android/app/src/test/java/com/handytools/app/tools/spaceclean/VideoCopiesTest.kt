package com.handytools.app.tools.spaceclean

import org.junit.Assert.assertEquals
import org.junit.Test

/** Copies of a video are found wherever they sit in the library (26 Nov): same size to the byte is the first check. */
class VideoCopiesTest {
    @Test fun onlyClipsTheSameSizeAreCompared() {
        val sizes = (0 until 3000).map { 1_000_000L + it * 7_919L }.toMutableList()
        sizes[2900] = sizes[3]                      // an old copy, far down the list
        assertEquals(listOf(listOf(3, 2900)), SpaceCleanerEngine.sameSizeSets(sizes))
        assertEquals(emptyList<List<Int>>(), SpaceCleanerEngine.sameSizeSets(listOf(31_100_000L, 31_100_001L)))
    }
}
