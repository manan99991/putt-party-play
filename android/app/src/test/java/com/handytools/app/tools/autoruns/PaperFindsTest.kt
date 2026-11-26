package com.handytools.app.tools.autoruns

import org.junit.Assert.assertEquals
import org.junit.Test

/** Business cards on Android: the same card photographed twice counts once, keeping what each shot read. */
class PaperFindsTest {
    @Test fun theSameCardTwiceCountsOnce() {
        val a = PaperFinds.dedupedCards(listOf(
            PaperFinds.Card("1", "Priya Shah", "", "", "+1 (312) 555-0199", "", 0),
            PaperFinds.Card("2", "", "Head of Design", "Shah & Co", "312.555.0199", "priya@shah.co", 0),
            PaperFinds.Card("3", "Sam Lee", "", "", "", "sam@lee.io", 0),
            PaperFinds.Card("4", "Samuel Lee", "CTO", "", "", "SAM@lee.io", 0),
        ))
        assertEquals(2, a.size)
        assertEquals("Priya Shah", a[0].name); assertEquals("Shah & Co", a[0].company); assertEquals("priya@shah.co", a[0].email)
        assertEquals("Head of Design", a[0].title)
        assertEquals("Sam Lee", a[1].name); assertEquals("CTO", a[1].title)
    }
}
