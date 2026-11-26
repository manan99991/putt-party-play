package com.handytools.app.tools.autoruns

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Paper into PDFs on Android: the iPhone's rules for which pages go together and what a document is called. */
class PaperPdfsTest {
    @Test fun aPagesOwnWordsNameIt() {
        assertEquals("Residential Lease Agreement", PaperPdfs.title("123 Main Street, Springfield\nRESIDENTIAL LEASE AGREEMENT\nThis agreement is made on 1 March 2026"))
        assertEquals("Notice of Rent Increase", PaperPdfs.title("Dear Priya,\nNotice of Rent Increase\nYour rent will change"))
        assertEquals("never a phone, an email or a greeting", "Quarterly Report", PaperPdfs.title("Call (312) 555-0199\npriya@shah.co\nDear Sam\nQuarterly Report\nSales were up"))
        assertEquals("Form W-2 Wage Statement", PaperPdfs.title("FORM W-2 WAGE STATEMENT"))
    }

    @Test fun pagesTakenTogetherAreOneDocumentUnlessOneSaysPage1() {
        val m = 60_000L
        val pages = listOf(PaperPdfs.Page("a1", 0, "Lease page one"), PaperPdfs.Page("a2", 2 * m, "terms"), PaperPdfs.Page("b1", 4 * m, "Page 1 of 2\nInvoice"),
            PaperPdfs.Page("b2", 5 * m, "Page 2 of 2"), PaperPdfs.Page("c1", 30 * m, "A letter"))
        assertEquals(listOf(listOf("a1", "a2"), listOf("b1", "b2"), listOf("c1")), PaperPdfs.group(pages))
        assertTrue(PaperPdfs.startsADocument("page 1 of 3")); assertTrue(PaperPdfs.startsADocument("Total\n1/4\n")); assertFalse(PaperPdfs.startsADocument("page 2 of 3"))
    }

    @Test fun fileNamesAreSafe() {
        val name = PaperPdfs.fileName("Lease: Agreement", 1_795_700_000_000L)
        assertTrue(name, Regex("Lease Agreement \\d{4}-\\d{2}-\\d{2}\\.pdf").matches(name))
        assertFalse(PaperPdfs.fileName("a/b\\\\c", 0).contains("/"))
    }
}
