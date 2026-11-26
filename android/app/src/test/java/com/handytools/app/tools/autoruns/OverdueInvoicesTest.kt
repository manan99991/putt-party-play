package com.handytools.app.tools.autoruns

import com.handytools.app.I18n
import com.handytools.app.tools.invoice.InvoiceLogic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Locale

/** Overdue invoices on Android: how late, the tone, the client's email, and every translated sentence filling its blanks. */
class OverdueInvoicesTest {
    private val zone = ZoneId.of("America/Chicago")
    private fun ms(d: Int, h: Int = 12) = ZonedDateTime.of(2026, 11, d, h, 0, 0, 0, zone).toInstant().toEpochMilli()
    private fun doc(due: Long?, paid: Boolean = false) = InvoiceLogic.Doc(kind = InvoiceLogic.Kind.INVOICE, number = "INV-0042", date = ms(1), due = due,
        from = "Manan Studio\nmanan@example.com", to = "Priya Shah\npriya@shah.co", lines = listOf(InvoiceLogic.Line("Design", 2.0, 250.0)),
        taxPercent = 0.0, notes = "", currency = "$", paid = paid)

    @Test fun lateCountsWholeDaysAndTheToneFollows() {
        assertEquals(0, OverdueInvoices.daysLate(doc(ms(26)), ms(26, 23), zone))
        assertEquals(5, OverdueInvoices.daysLate(doc(ms(21, 23)), ms(26, 1), zone))
        assertEquals(OverdueInvoices.Tone.FRIENDLY, OverdueInvoices.tone(7))
        assertEquals(OverdueInvoices.Tone.FIRM, OverdueInvoices.tone(8)); assertEquals(OverdueInvoices.Tone.FIRM, OverdueInvoices.tone(30))
        assertEquals(OverdueInvoices.Tone.FINAL, OverdueInvoices.tone(31))
    }

    @Test fun onlyUnpaidInvoicesPastTheirDayMostLateFirst() {
        val a = doc(ms(20)); val b = doc(ms(10)); val paid = doc(ms(5), paid = true); val notYet = doc(ms(28)); val none = doc(null)
        assertEquals(listOf(b.id, a.id), OverdueInvoices.overdue(listOf(a, b, paid, notYet, none), ms(26)).map { it.id })
    }

    @Test fun theClientsEmailIsFoundInTheirDetails() {
        assertEquals("priya@shah.co", OverdueInvoices.email("Priya Shah\npriya@shah.co\n12 High St"))
        assertNull(OverdueInvoices.email("Priya Shah\n12 High St"))
    }

    @Test fun theReminderHasTheNumberAmountAndRightTone() {
        val (s1, b1) = OverdueInvoices.reminder(doc(ms(22)), ms(26), zone, Locale.US)
        assertTrue(s1, s1.startsWith("Friendly reminder") && s1.contains("INV-0042"))
        assertTrue(b1, b1.startsWith("Hi Priya,") && b1.contains("$500.00") && b1.contains("November 22, 2026") && b1.endsWith("Manan Studio"))
        val (s2, b2) = OverdueInvoices.reminder(doc(ms(6)), ms(26), zone, Locale.US)
        assertEquals("Invoice INV-0042 is 20 days overdue", s2); assertTrue(b2.contains("20 days overdue"))
        val (s3, _) = OverdueInvoices.reminder(doc(ms(6)), ms(26).plusDays(30), zone, Locale.US)
        assertTrue(s3.startsWith("Final notice"))
    }

    private fun Long.plusDays(n: Int) = this + n * 86_400_000L

    /** Every language's sentences fill their blanks (a wrong blank would crash or show "%@"). */
    @Test fun everyTranslatedSentenceFillsItsBlanks() {
        val json = File("src/main/assets/translations.json").readText()
        val keys = listOf("Hi %@," to arrayOf<Any>("Priya"), "Friendly reminder: invoice %@" to arrayOf<Any>("INV-1"),
            "Invoice %@ is %d days overdue" to arrayOf<Any>("INV-1", 12), "Final notice: invoice %@" to arrayOf<Any>("INV-1"),
            "Just a quick reminder that invoice %@ for %@ was due on %@. I've attached it again for convenience." to arrayOf<Any>("INV-1", "$5", "1 Nov"),
            "Invoice %@ for %@ was due on %@ and is now %d days overdue. Could you let me know when I can expect payment?" to arrayOf<Any>("INV-1", "$5", "1 Nov", 12),
            "This is a final reminder that invoice %@ for %@, due on %@, is still unpaid after %d days. Please arrange payment this week, or reply to let me know if there's a problem." to arrayOf<Any>("INV-1", "$5", "1 Nov", 40),
            "%d invoices are overdue — reminders are ready to send." to arrayOf<Any>(3),
            "You did this by hand on %d days lately. Tenzy can do it for you." to arrayOf<Any>(4),
            "%d videos (%s) could be smaller and look the same." to arrayOf<Any>(3, "410 MB"),
            "1 video (%s) could be smaller and look the same." to arrayOf<Any>("410 MB"),
            "%d contacts have disappeared since last week's copy — tap to bring them back." to arrayOf<Any>(3),
            "%d contacts copied, kept on this phone." to arrayOf<Any>(214),
            "%d photos from today — tap to see the best of them as one collage." to arrayOf<Any>(14),
            "%d photos this week — tap to make them into one short film." to arrayOf<Any>(52),
            "%d clips from today can be made ready to post." to arrayOf<Any>(3),
            "%d photos, the best of each moment." to arrayOf<Any>(9),
            "%d photos could go to the bin and free %@ — you choose." to arrayOf<Any>(40, "1.2 GB"),
            "Move %d to the bin · frees %@" to arrayOf<Any>(40, "1.2 GB"),
            "%d screenshots are over a week old — tap to tidy them up." to arrayOf<Any>(25),
            "%d old screenshots" to arrayOf<Any>(25), "Met on %@" to arrayOf<Any>("26 Nov 2026"), "Added to %@." to arrayOf<Any>("Expenses 2026-11"),
            "Add %d to my expense sheet" to arrayOf<Any>(3), "Save %d to Contacts" to arrayOf<Any>(2), "%d saved to Contacts, each with the day you met." to arrayOf<Any>(2), "%d look-alikes" to arrayOf<Any>(3), "%d copies of the same photo" to arrayOf<Any>(2))
        for ((key, args) in keys) {
            val at = json.indexOf("\n \"" + key.replace("\"", "\\\"") + "\": {")
            assertTrue("missing translations for: $key", at >= 0)
            val block = json.substring(at, json.indexOf("}", at))
            val values = Regex("\"([a-z]{2})\": \"((?:[^\"\\\\]|\\\\.)*)\"").findAll(block).map { it.groupValues[1] to it.groupValues[2].replace("\\\"", "\"") }.toList()
            assertEquals("8 languages for: $key", 8, values.size)
            for ((lang, v) in values) {
                val out = String.format(Locale.ROOT, I18n.javaPlaceholders(v), *args)
                assertTrue("$lang left a blank in: $out", !out.contains("%@") && !out.contains("%d") && !out.contains("%s"))
                args.forEach { a -> assertTrue("$lang dropped $a in: $out", out.contains(a.toString())) }
            }
        }
    }
}
