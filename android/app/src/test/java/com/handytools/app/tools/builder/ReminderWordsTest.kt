package com.handytools.app.tools.builder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * "Remind me…" read exactly as the iPhone reads it (the same sentences and expectations as ReminderWordsTests), at
 * fixed times on Wednesday 25 Nov 2026 in Chicago — a wrong reminder is worse than none.
 */
class ReminderWordsTest {
    private val zone = ZoneId.of("America/Chicago")
    private fun wed(h: Int, m: Int = 0) = ZonedDateTime.of(2026, 11, 25, h, m, 0, 0, zone)
    private fun r(s: String, at: ZonedDateTime) = ReminderWords.parse(s, at)

    @Test fun theAnchorIsAWednesday() { assertEquals(4, ReminderWords.weekday(wed(10))) }

    @Test fun onlyRemindMeSentencesAreReminders() {
        assertNull(r("email today's screenshots to myself every evening", wed(10)))
        assertNull(r("make my voice sound like a robot", wed(10)))
        assertNotNull(r("Remind me to call Mum", wed(10)))
        assertNotNull(r("don't let me forget the passports", wed(10)))
        assertNotNull(r("set a reminder to water the plants", wed(10)))
    }

    @Test fun aOneOffAtATime() {
        val a = r("Remind me to call Mum at 6", wed(10))!!
        assertEquals("the person's own capitals are kept", "Call Mum", a.text)
        assertTrue(a.once)
        assertEquals(25, a.onceAt!!.dayOfMonth); assertEquals("a bare 6 is the evening", 18, a.onceAt!!.hour)
        val b = r("remind me to take the cake out at 7:45 pm.", wed(10))!!
        assertEquals("Take the cake out", b.text)
        assertEquals(19, b.onceAt!!.hour); assertEquals(45, b.onceAt!!.minute)
        // "at 9" said at 10 in the morning: 9 tonight, not tomorrow morning.
        val c = r("remind me at 9 to lock the back door", wed(10))!!
        assertEquals("Lock the back door", c.text)
        assertEquals(25, c.onceAt!!.dayOfMonth); assertEquals(21, c.onceAt!!.hour)
        // "at 9am" said at 10: tomorrow at 9.
        val d = r("remind me at 9am to call the bank", wed(10))!!
        assertEquals(26, d.onceAt!!.dayOfMonth); assertEquals(9, d.onceAt!!.hour)
        assertEquals(12, r("remind me to have lunch at noon", wed(9))!!.onceAt!!.hour)
    }

    @Test fun tomorrowTonightAndADay() {
        val a = r("tomorrow at 9 remind me to pay rent", wed(22))!!
        assertEquals("Pay rent", a.text)
        assertEquals(26, a.onceAt!!.dayOfMonth); assertEquals("tomorrow's 9 is the morning even late at night", 9, a.onceAt!!.hour)
        val b = r("remind me tonight to charge the car", wed(10))!!
        assertEquals("Charge the car", b.text)
        assertEquals(25, b.onceAt!!.dayOfMonth); assertEquals(21, b.onceAt!!.hour)
        assertEquals(20, r("remind me tonight at 8 to put the bins out", wed(10))!!.onceAt!!.hour)
        val d = r("remind me on Friday to send the invoice", wed(10))!!
        assertEquals("Send the invoice", d.text)
        assertEquals(27, d.onceAt!!.dayOfMonth); assertEquals(9, d.onceAt!!.hour)
        val e = r("remind me tomorrow morning about the dentist", wed(10))!!
        assertEquals("The dentist", e.text)
        assertEquals(26, e.onceAt!!.dayOfMonth); assertEquals(8, e.onceAt!!.hour)
        val f = r("remind me on friday evening to call bob", wed(10))!!
        assertEquals("Call bob", f.text)
        assertEquals(27, f.onceAt!!.dayOfMonth); assertEquals(19, f.onceAt!!.hour)
    }

    @Test fun inSomeMinutes() {
        val a = r("remind me in 20 minutes to check the oven", wed(10))!!
        assertEquals("Check the oven", a.text)
        assertEquals(10, a.onceAt!!.hour); assertEquals(20, a.onceAt!!.minute)
        val b = r("Remind me in an hour to move the car", wed(10, 30))!!
        assertEquals("Move the car", b.text)
        assertEquals(11, b.onceAt!!.hour); assertEquals(30, b.onceAt!!.minute)
        assertEquals(30, r("remind me in half an hour to take the laundry out", wed(10))!!.onceAt!!.minute)
    }

    @Test fun repeats() {
        val a = r("remind me every Monday to put the bins out", wed(10))!!
        assertEquals("Put the bins out", a.text)
        assertFalse(a.once); assertEquals(listOf(2), a.days); assertEquals(9, a.hour)
        val b = r("Remind me to take my vitamins every day at 8am", wed(10))!!
        assertEquals("Take my vitamins", b.text)
        assertFalse(b.once); assertEquals(emptyList<Int>(), b.days); assertEquals(8, b.hour)
        val c = r("remind me on weekdays at 7:30 to leave for school", wed(10))!!
        assertEquals("Leave for school", c.text)
        assertEquals(listOf(2, 3, 4, 5, 6), c.days); assertEquals(7, c.hour); assertEquals(30, c.minute)
        val d = r("every evening remind me to lock up", wed(10))!!
        assertEquals("Lock up", d.text)
        assertFalse(d.once); assertEquals(19, d.hour)
        val e = r("remind me every monday and thursday at 6 to go to the gym", wed(10))!!
        assertEquals("Go to the gym", e.text)
        assertEquals(listOf(2, 5), e.days.sorted()); assertEquals(18, e.hour)
        val f = r("remind me on saturdays to water the plants", wed(10))!!
        assertFalse(f.once); assertEquals(listOf(7), f.days)
    }

    @Test fun neverInThePastAndAlwaysSays() {
        for (s in listOf("remind me to call Mum at 6", "remind me at 7", "remind me tonight to stretch", "remind me today at 9 to read",
            "remind me to pay rent", "remind me on wednesday to call", "remind me in 5 minutes")) {
            for (h in listOf(0, 6, 9, 12, 17, 21, 23)) {
                val x = r(s, wed(h)) ?: run { fail("$s wasn't read as a reminder"); return }
                assertFalse(s, x.text.isEmpty())
                if (x.once) assertTrue("$s at $h:00 was set in the past", x.onceAt!!.isAfter(wed(h)))
            }
        }
        assertEquals("Reminder", r("remind me at 7", wed(10))!!.text)
    }
}
