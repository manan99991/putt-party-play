package com.handytools.app.tools.invoice

import com.handytools.app.ui.ForYouAndroid
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Invoices & Quotes on Android follow the iPhone's rules exactly (same numbers as InvoiceTests.swift). */
class InvoiceLogicTest {
    private val now = 1_795_460_400_000L
    private val day = 86_400_000L
    private fun doc(kind: InvoiceLogic.Kind = InvoiceLogic.Kind.INVOICE, number: String = "INV-0001", due: Long? = null,
                    tax: Double = 0.0, paid: Boolean = false, lines: List<InvoiceLogic.Line> = listOf(
                        InvoiceLogic.Line("Fix kitchen faucet", 1.0, 120.0), InvoiceLogic.Line("Replacement cartridge", 2.0, 18.5))) =
        InvoiceLogic.Doc(kind = kind, number = number, date = now, due = due, from = "Rivera Home Repair", to = "Jordan Lee\n14 Maple Ave",
            lines = lines, taxPercent = tax, notes = "", currency = "$", paid = paid)

    @Test fun totalsToTheCent() {
        val d = doc(tax = 8.25)
        assertEquals(157.0, d.subtotal, 0.0); assertEquals(12.95, d.tax, 0.0); assertEquals(169.95, d.total, 0.0)
        assertEquals(100.3, doc(lines = listOf(InvoiceLogic.Line("Hours", 2.5, 40.0), InvoiceLogic.Line("Parts", 3.0, 0.1))).subtotal, 0.0)
    }

    @Test fun numbersCountUpPerKind() {
        assertEquals("INV-0001", InvoiceLogic.nextNumber(InvoiceLogic.Kind.INVOICE, emptyList()))
        val docs = listOf(doc(number = "INV-0006"), doc(number = "INV-0002"), doc(InvoiceLogic.Kind.QUOTE, "Q-0009"))
        assertEquals("INV-0007", InvoiceLogic.nextNumber(InvoiceLogic.Kind.INVOICE, docs))
        assertEquals("Q-0010", InvoiceLogic.nextNumber(InvoiceLogic.Kind.QUOTE, docs))
    }

    @Test fun threeFreeAMonth() {
        assertEquals(3, InvoiceLogic.left(0, false)); assertEquals(1, InvoiceLogic.left(2, false))
        assertEquals(0, InvoiceLogic.left(5, false)); assertNull(InvoiceLogic.left(9, true))
    }

    @Test fun overdueOnlyForUnpaidInvoicesPastTheirDay() {
        assertTrue(doc(due = now - day).overdue(now))
        assertFalse(doc(due = now).overdue(now))
        assertFalse(doc(due = now - day, paid = true).overdue(now))
        assertFalse(doc(InvoiceLogic.Kind.QUOTE, due = now - day).overdue(now))
        assertEquals(listOf("INV-0001"), InvoiceLogic.unpaid(listOf(doc(due = now), doc(InvoiceLogic.Kind.QUOTE, "Q-0001"))).map { it.number })
    }

    @Test fun readsNumbersTheWayPeopleTypeThem() {
        assertEquals(1250.5, InvoiceLogic.number("1,250.50"), 0.0)
        assertEquals(1250.5, InvoiceLogic.number("1250,50"), 0.0)
        assertEquals(18.5, InvoiceLogic.number("$18.50"), 0.0)
        assertEquals("2.5", InvoiceLogic.qty(2.5)); assertEquals("3", InvoiceLogic.qty(3.0))
    }

    @Test fun homeSaysWhenACustomerHasntPaid() {
        val c = ForYouAndroid.cards(null, now, emptyMap(), listOf(doc(due = now - 3 * day)))
        assertEquals("Jordan Lee hasn't paid yet", c.single().title)
        assertEquals("invoice", c.single().route)
        assertEquals(emptyList<ForYouAndroid.Card>(), ForYouAndroid.cards(null, now, emptyMap(), listOf(doc(due = now - 3 * day, paid = true))))
    }
}
