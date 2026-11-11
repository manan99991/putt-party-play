package com.handytools.app.tools.builder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Off-device checks for the chain model, Describe it and the text blocks. Mirrors the iOS tests. */
class BuilderLogicTest {
    // Tidy
    @Test fun tidyCollapsesSpacesGapsAndRepeats() =
        assertEquals("Milk 2\n\nEggs 12", TextTidy.clean("\n\n  Milk   2 \nmilk 2\n\n\n\nEggs\t12  \nEggs 12\n"))
    @Test fun tidyOfBlankIsEmpty() = assertEquals("", TextTidy.clean("  \n \n"))

    // Details
    @Test fun detailsFindsLinksEmailsPhonesOnce() {
        val d = TextTidy.details("Visit https://tenzy.app/help, or www.tenzy.app. Mail Priya@Studio.example or priya@studio.example. Call (312) 555-0147 or 312-555-0147.")
        assertEquals(listOf("https://tenzy.app/help", "www.tenzy.app"), d.links)
        assertEquals(listOf("Priya@Studio.example"), d.emails)
        assertEquals(2, d.phones.size)
    }
    @Test fun longDigitRunIsNotAPhone() = assertTrue(TextTidy.details("Card 4111111111111111 expires soon").phones.isEmpty())
    @Test fun detailsTextHasSectionsOnlyForWhatWasFound() {
        val t = TextTidy.details("Write to a@b.co or call 312 555 0147").text
        assertTrue(t.contains("Emails\na@b.co")); assertTrue(t.contains("Phones\n312 555 0147")); assertFalse(t.contains("Links"))
    }
    @Test fun noDetailsIsEmpty() = assertTrue(TextTidy.details("no details here").isEmpty())

    // Spreadsheet
    @Test fun tableCsvSplitsOnTwoSpaces() = assertEquals("Latte,4.50\nMuffin,3.25", TextTidy.tableCsv("Latte  4.50\nMuffin  3.25"))
    @Test fun tableCsvPadsShortRows() = assertEquals("a,b\nc,", TextTidy.tableCsv("a|b\nc"))
    @Test fun tableCsvQuotesCommasInCells() = assertEquals("\"x,y\"", TextTidy.csv("x,y"))
    @Test fun tableCsvOfBlankIsEmpty() = assertEquals("", TextTidy.tableCsv("  \n"))

    // Chain model
    @Test fun templatesAreValid() {
        for (t in ChainTemplates.all) assertNull(t.name, t.problem(t.steps.first().block.takes))
        assertTrue(ChainTemplates.all.size >= 11)
    }
    @Test fun newBlocksFitTogether() {
        assertNull(Chain("x", "x", listOf(Step(Block.CLEAN_TEXT), Step(Block.PULL_DETAILS))).problem(Kind.TEXT))
        assertNull(Chain("x", "x", listOf(Step(Block.READ_TEXT), Step(Block.MAKE_TABLE))).problem(Kind.IMAGE))
        assertNotNull(Chain("x", "x", listOf(Step(Block.MAKE_TABLE), Step(Block.SUMMARIZE))).problem(Kind.TEXT))   // a file can't be summarized
    }
    @Test fun blockIdsMatchIos() {
        val ids = Block.values().map { it.id }.toSet()
        assertTrue(ids.containsAll(listOf("readText", "pullReceipt", "summarize", "shrinkImage", "stripLocation", "convertImage", "businessCard", "calendarEvent", "actionItems", "hideSensitive", "cleanText", "pullDetails", "makeTable")))
    }

    // Describe it
    @Test fun plannerShrinkAndStrip() {
        val c = ChainPlanner.plan("shrink a photo under 3 mb and remove its location")!!
        assertEquals(listOf(Block.STRIP_LOCATION, Block.SHRINK), c.steps.map { it.block })
        assertEquals("3", c.steps.last().settings["mb"])
    }
    @Test fun plannerReceiptReadsThenPulls() =
        assertEquals(listOf(Block.READ_TEXT, Block.PULL_RECEIPT), ChainPlanner.plan("turn my receipt photo into an expense row")!!.steps.map { it.block })
    @Test fun plannerFindsDetails() =
        assertEquals(listOf(Block.PULL_DETAILS), ChainPlanner.plan("pull all the links and phone numbers out of some text")!!.steps.map { it.block })
    @Test fun plannerPhotoOfTableToSpreadsheet() =
        assertEquals(listOf(Block.READ_TEXT, Block.MAKE_TABLE), ChainPlanner.plan("turn a photo of a table into a spreadsheet")!!.steps.map { it.block })
    @Test fun plannerTidyThenSummarize() {
        val c = ChainPlanner.plan("tidy up my notes then summarize in 2 sentences")!!
        assertEquals(listOf(Block.CLEAN_TEXT, Block.SUMMARIZE), c.steps.map { it.block })
        assertEquals("2", c.steps[1].settings["sentences"])
    }
    @Test fun plannerTidyPhotoIsNotTextTidying() = assertTrue(ChainPlanner.plan("tidy up this photo and make it clearer")?.steps?.none { it.block == Block.CLEAN_TEXT } ?: true)
    @Test fun plannerNonsenseGivesNothing() = assertNull(ChainPlanner.plan("make me a sandwich"))

    // Share to Tenzy
    @Test fun photoShareOffersOnlyPhotoTools() {
        val offers = ChainOffers.forKind(Kind.IMAGE, emptyList(), null)
        assertTrue(offers.any { it.id == "safe-to-share" })
        assertTrue(offers.none { it.id == "short-summary" })
        for (c in offers) assertNull(c.name, c.problem(Kind.IMAGE))
    }
    @Test fun ownToolsFirstAndLastUsedOnTop() {
        val mine = Chain("mine-1", "My clean send", listOf(Step(Block.STRIP_LOCATION), Step(Block.SHRINK, mapOf("mb" to "1"))))
        assertEquals("mine-1", ChainOffers.forKind(Kind.IMAGE, listOf(mine), null).first().id)
        assertEquals("photo-under-2mb", ChainOffers.forKind(Kind.IMAGE, listOf(mine), "photo-under-2mb").first().id)
        assertEquals("mine-1", ChainOffers.forKind(Kind.IMAGE, listOf(mine), "no-such-tool").first().id)
    }
    @Test fun contactNeedsAWayToReachThePerson() {
        // Name-only text must not become a contact; the runner stops before building a vCard (checked in ChainRunner).
        assertTrue(TextTidy.details("New Year\nParty at the hall").let { it.emails.isEmpty() && it.phones.isEmpty() })
    }

    // Finish: where the result goes
    @Test fun finishSplitsRecipientsAndLabels() {
        val f = Finish("mail", "priya@studio.example, sam@studio.example ;")
        assertEquals(listOf("priya@studio.example", "sam@studio.example"), f.recipients)
        assertEquals("Email it to 2 people", f.label)
        assertEquals("Message it to 312 555 0147", Finish("message", "312 555 0147").label)
        assertEquals("Email it", Finish("mail", " ").label)
        assertEquals("Save or share", Finish().label)
        assertEquals("Send on WhatsApp", Finish("whatsapp").label)
    }
    @Test fun toolWithoutFinishStillBuilds() = assertNull(Chain("a", "Old", listOf(Step(Block.STRIP_LOCATION))).finish)
}
