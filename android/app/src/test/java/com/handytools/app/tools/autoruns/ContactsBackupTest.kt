package com.handytools.app.tools.autoruns

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The weekly contacts copy on Android: reading a .vcf and finding who's gone since the last copy. */
class ContactsBackupTest {
    private fun card(name: String, vararg tel: String) =
        "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:$name\r\nN:;$name;;;\r\n" + tel.joinToString("") { "TEL;TYPE=CELL:$it\r\n" } + "END:VCARD\r\n"

    @Test fun aCopyIsReadContactByContact() {
        val cards = ContactsBackup.parse(card("Priya Shah", "+1 (312) 555-0199") + card("Mum", "07700 900123", "020 7946 0018") + card("", "555 0100 22"))
        assertEquals(3, cards.size)
        assertEquals("Priya Shah", cards[0].name); assertEquals(listOf("3125550199"), cards[0].numbers)
        assertEquals(2, cards[1].numbers.size)
        assertTrue(cards[0].vcard.startsWith("BEGIN:VCARD") && cards[0].vcard.endsWith("END:VCARD"))
        // A folded line (a long name wrapped onto the next line) is read whole.
        assertEquals("Alexandra Montgomery", ContactsBackup.parse("BEGIN:VCARD\r\nFN:Alexandra Mont\r\n gomery\r\nEND:VCARD\r\n").single().name)
    }

    @Test fun whoIsGoneIsFoundByNameOrNumber() {
        val before = ContactsBackup.parse(card("Priya Shah", "3125550199") + card("Mum", "07700900123") + card("Dentist", "02079460018") + card("", "5550100222"))
        val now = ContactsBackup.parse(card("Priya Shah", "3125550199") + card("Mother", "07700900123") + card(""))
        val gone = ContactsBackup.disappeared(before, now)
        assertEquals("renamed (same number) isn't gone; the dentist and the nameless number are", listOf("Dentist", ""), gone.map { it.name })
        assertTrue(ContactsBackup.disappeared(now, now).isEmpty())
    }
}
