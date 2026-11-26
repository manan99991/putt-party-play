package com.handytools.app.billing

import com.handytools.app.I18n
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Tenzy Pro on Android matches the iPhone (26 Nov): monthly or yearly, each with a 7-day free trial, prices from Play. */
class PricingTest {
    @Test fun bothPlansAreSold() {
        assertEquals("tenzy_pro_yearly", BillingManager.YEARLY_ID)
        assertEquals("tenzy_pro_month", BillingManager.MONTHLY_ID)
    }

    @Test fun trialLengthsReadAsDays() {
        assertEquals(7, trialDays("P7D"))
        assertEquals(7, trialDays("P1W"))
        assertEquals(30, trialDays("P1M"))
        assertNull(trialDays("a week"))
    }

    @Test fun phrasesFillLikeTheIphone() {
        assertEquals("7 days free, then $29.99 a year", I18n.f("%@ free, then %@ a year", "7 days", "$29.99"))
        assertEquals("Save 16%", I18n.f("Save %d%%", 16))
    }
}
