package com.handytools.app.tools.brief

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class MorningSummaryTest {
    private val now = Calendar.getInstance().apply { set(2026, Calendar.NOVEMBER, 24, 7, 0, 0); set(Calendar.MILLISECOND, 0) }.timeInMillis
    private fun at(h: Int) = Calendar.getInstance().apply { timeInMillis = now; set(Calendar.HOUR_OF_DAY, h) }.timeInMillis

    @Test fun aQuietDaySaysSo() {
        val (_, body, lines) = MorningSummary.compose(MorningSummary.Facts(freeGB = 40.0), now)
        assertEquals(emptyList<String>(), lines)
        assertEquals("Nothing pressing today. Enjoy it.", body)
    }

    @Test fun medicinesLateInvoicesBirthdaysCarAndSpace() {
        val f = MorningSummary.Facts(
            doses = listOf("Magnesium" to at(21), "Vitamin D" to at(8)),
            lateInvoices = listOf("Jordan Lee" to "$157.00"),
            birthdays = listOf("Asha" to true),
            freeGB = 3.2, parkedAt = now - 3_600_000L)
        val lines = MorningSummary.compose(f, now).third
        assertEquals("💊 2 doses: Vitamin D 8:00 AM, Magnesium 9:00 PM", lines[0])
        assertEquals("📄 Jordan Lee hasn't paid $157.00 yet", lines[1])
        assertEquals("🎂 Asha's birthday is today", lines[2])
        assertTrue(lines.any { it.startsWith("🚗") })
        assertEquals("🧹 Only 3.2 GB free on your phone", lines.last())
    }

    @Test fun nextFireIsTodayIfStillAheadElseTomorrow() {
        assertEquals(at(8), MorningSummary.nextFire(now, 8, 0))
        assertEquals(at(7) + 86_400_000L, MorningSummary.nextFire(now, 7, 0))
    }
}
