package com.handytools.app.tools.meds

import com.handytools.app.ui.ForYouAndroid
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

/** Medicine Reminders on Android follow the iPhone's rules (schedules, pill count, refill alert, follow-ups). */
class MedLogicTest {
    /** Wednesday 18 Nov 2026, 9:30 in the test machine's time zone. */
    private val now = Calendar.getInstance().apply { set(2026, Calendar.NOVEMBER, 18, 9, 30, 0); set(Calendar.MILLISECOND, 0) }.timeInMillis
    private fun at(h: Int, m: Int = 0, dayOffset: Int = 0) = Calendar.getInstance().apply {
        timeInMillis = now; add(Calendar.DAY_OF_YEAR, dayOffset); set(Calendar.HOUR_OF_DAY, h); set(Calendar.MINUTE, m) }.timeInMillis
    private fun med(vararg times: Pair<Int, Int>, pattern: Pattern = Pattern.DAILY) =
        Med(name = "Vitamin D", times = times.map { TimeOfDay(it.first, it.second) }, pattern = pattern, start = MedLogic.startOfDay(now) - 30 * MedLogic.DAY)

    @Test fun dailyTimesAreSortedAndDeduplicated() {
        val m = med(20 to 0, 8 to 0, 8 to 0)
        assertEquals(listOf(TimeOfDay(8, 0), TimeOfDay(20, 0)), MedLogic.clockTimes(m))
        assertEquals(listOf(at(8), at(20)), MedLogic.doses(m, now))
    }

    @Test fun everyFewHoursStaysInWakingHours() {
        val m = Med(name = "A", pattern = Pattern.EVERY_HOURS, everyHours = 6, firstHour = 8, lastHour = 22)
        assertEquals(listOf(8, 14, 20), MedLogic.clockTimes(m).map { it.hour })
    }

    @Test fun someDaysOnlyOnThoseDays() {
        val m = med(8 to 0, pattern = Pattern.WEEKDAYS).copy(weekdays = setOf(Calendar.WEDNESDAY))
        assertTrue(MedLogic.isDue(m, now))
        assertFalse(MedLogic.isDue(m, now + MedLogic.DAY))
        assertEquals(7, MedLogic.dosesPerWeek(med(8 to 0)))
        assertEquals(1, MedLogic.dosesPerWeek(m))
    }

    @Test fun pausedEndedOrNotStartedIsNotDue() {
        assertFalse(MedLogic.isDue(med(8 to 0).copy(paused = true), now))
        assertFalse(MedLogic.isDue(med(8 to 0).copy(end = now - 2 * MedLogic.DAY), now))
        assertFalse(MedLogic.isDue(med(8 to 0).copy(start = now + 2 * MedLogic.DAY), now))
    }

    @Test fun upcomingIsSoonestFirstAndOnlyFuture() {
        val up = MedLogic.upcoming(listOf(med(8 to 0, 20 to 0)), now, days = 2)
        assertEquals(listOf(at(20), at(8, 0, 1), at(20, 0, 1)), up.map { it.second })
    }

    @Test fun pillCountAndRefillAlertComeOnce() {
        val m = med(8 to 0, 20 to 0).copy(supply = 9, perDose = 1, refillAt = 7)
        assertEquals(4, MedLogic.daysLeft(m))
        val a = MedLogic.counted(m, true); val b = MedLogic.counted(a, true); val c = MedLogic.counted(b, true)
        assertFalse(MedLogic.crossedRefill(m, a)); assertTrue(MedLogic.crossedRefill(a, b)); assertFalse(MedLogic.crossedRefill(b, c))
        assertEquals(9, MedLogic.counted(a, false).supply)
        assertEquals(0, MedLogic.counted(m.copy(supply = 0), true).supply)
        assertNull(MedLogic.daysLeft(med(8 to 0)))
    }

    @Test fun followUpsOnlyForUntakenDosesAhead() {
        val m = med(9 to 15, 20 to 0)
        val f = MedLogic.followUps(listOf(m), { _, _ -> false }, 30, now)
        assertEquals(at(9, 45), f.first().third)
        assertEquals(emptyList<Any>(), MedLogic.followUps(listOf(m), { _, _ -> false }, 0, now))
        assertFalse(MedLogic.followUps(listOf(m), { _, d -> d == at(9, 15) }, 30, now).any { it.second == at(9, 15) })
    }

    @Test fun weekSummaryInPlainWords() {
        assertEquals("This week: 13 of 14 doses taken (93%). Missed: Metformin Tue 8 PM.", MedLogic.weekSummary(13, 14, listOf("Metformin Tue 8 PM")))
        assertTrue(MedLogic.weekSummary(0, 0, emptyList()).startsWith("Reminders are set up"))
    }

    @Test fun homeOffersTheNextDoseFirst() {
        val c = ForYouAndroid.cards(now - 60_000L, now, emptyMap(), doses = listOf(Triple("Vitamin D", at(9, 0), false)))
        assertEquals("Vitamin D: did you take it?", c.single().title)
        assertEquals("medreminder", c.single().route)
        assertEquals("car", ForYouAndroid.cards(now - 60_000L, now, emptyMap(), doses = listOf(Triple("Vitamin D", at(9, 0), true))).single().kind)
    }
}
