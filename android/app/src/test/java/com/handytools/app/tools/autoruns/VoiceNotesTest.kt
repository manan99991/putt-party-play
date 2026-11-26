package com.handytools.app.tools.autoruns

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Voice memos on Android: a transcript written up as what it's about, the details and the to-dos. */
class VoiceNotesTest {
    @Test fun aMemoIsWrittenUp() {
        val n = VoiceNotes.writeUp(VoiceNotes.Memo("x", "Memo 1.m4a", 0),
            "Planning the launch party. We need to book the venue by Friday. The budget is $2,000. Remember to call Sam tomorrow at 3 pm.")
        assertEquals("Planning the launch party. We need to book the venue by Friday.", n.about)
        assertTrue(n.details.toString(), n.details.any { it.contains("2,000") } && n.details.any { it.equals("Friday", true) })
        assertEquals(listOf("We need to book the venue by Friday.", "Remember to call Sam tomorrow at 3 pm."), n.todos)
        assertTrue(n.text.startsWith("Memo 1.m4a") && n.text.contains("☐ Remember to call Sam"))
    }
}
