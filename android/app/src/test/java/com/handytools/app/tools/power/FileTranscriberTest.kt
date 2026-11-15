package com.handytools.app.tools.power

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Guards the whole-recording transcription behaviour on Android. The real on-device recogniser needs
 * a device (it's asserted by the mobileqa gate with a real audio sample), but the recognition timeout
 * budget is pure math — and getting it wrong is exactly what shipped: the old 3-minute cap silently
 * dropped the entire transcript of a long recording when recognition ran past it.
 */
class FileTranscriberTest {

    @Test fun longRecordingIsNotCutOffAtThreeMinutes() {
        val budget = FileTranscriber.budgetMs(22 * 60 * 1000L)   // a 22-minute memo
        assertTrue(
            "a long recording's recognition must not be cut off at the old 3-minute cap (was $budget ms)",
            budget >= 15 * 60 * 1000L
        )
    }

    @Test fun budgetFloorsAtTwentySecondsForTinyClips() {
        assertEquals(20_000L, FileTranscriber.budgetMs(0))
        assertEquals(20_000L, FileTranscriber.budgetMs(3_000))   // 3s clip: 2.5x is below the floor
    }

    @Test fun budgetScalesWithLengthThenCapsAtFifteenMinutes() {
        // ~2.5x the clip in the middle of the range.
        assertEquals(150_000L, FileTranscriber.budgetMs(60_000))        // 1 min → 2.5 min
        assertEquals(600_000L, FileTranscriber.budgetMs(4 * 60_000))    // 4 min → 10 min
        // Capped at 15 min no matter how long the clip.
        assertEquals(900_000L, FileTranscriber.budgetMs(60 * 60_000L))  // 1 hour → 15 min cap
    }
}
