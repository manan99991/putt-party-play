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

    // Links, scam report, new blocks
    @Test fun cleanLinkStripsTrackingAndKeepsTheRest() {
        assertEquals("https://shop.example/item?id=7", TextTidy.cleanLink("https://shop.example/item?id=7&utm_source=mail&fbclid=abc"))
        assertEquals("https://shop.example/item", TextTidy.cleanLink("https://shop.example/item?utm_source=mail"))
        assertEquals("https://shop.example/item?id=7#reviews", TextTidy.cleanLink("https://shop.example/item?id=7&gclid=x#reviews"))
        assertEquals("https://shop.example/plain", TextTidy.cleanLink("https://shop.example/plain"))
    }
    @Test fun cleanLinksInsideText() {
        assertEquals("Look: https://shop.example/item?id=7 thanks", TextTidy.cleanLinks("Look: https://shop.example/item?id=7&utm_source=mail thanks"))
        assertEquals("https://shop.example/item?id=7", TextTidy.cleanLinks("https://shop.example/item?id=7&utm_source=mail"))
        assertNull(TextTidy.cleanLinks("no link here"))
    }
    @Test fun scamReportReadsAsVerdictReasonsAdvice() =
        assertEquals("Likely a scam.\n• Asks for gift cards\n• Link pay.example: looks like a login page\n\nStop before paying.",
            TextTidy.scamReport("Likely a scam", listOf("Asks for gift cards"), listOf("Link pay.example: looks like a login page"), "Stop before paying."))
    @Test fun newBlocksChain() {
        assertNull(Chain("x", "x", listOf(Step(Block.STRIP_LOCATION), Step(Block.PHOTO_PDF))).problem(Kind.IMAGE))
        assertNotNull(Chain("x", "x", listOf(Step(Block.PHOTO_PDF), Step(Block.SHRINK))).problem(Kind.IMAGE))
        assertNull(Chain("x", "x", listOf(Step(Block.MAKE_QR), Step(Block.CONVERT))).problem(Kind.TEXT))
    }
    @Test fun plannerScamAndQr() {
        assertEquals(listOf(Block.SCAM_CHECK), ChainPlanner.plan("is this message a scam")!!.steps.map { it.block })
        assertEquals(listOf(Block.MAKE_QR), ChainPlanner.plan("turn a link into a qr code")!!.steps.map { it.block })
    }

    // Start from what you have, then steps grouped by what you want
    @Test fun everyBlockHasAKnownGoal() { for (b in Block.values()) assertTrue(b.id, b.goal in BlockGoals.ORDER) }
    @Test fun photoStartOffersOnlyPhotoStepsGrouped() {
        val photo = BlockGoals.starting(Kind.IMAGE)
        assertTrue(Block.STRIP_LOCATION in photo); assertFalse(Block.SUMMARIZE in photo)
        val groups = BlockGoals.grouped(photo)
        assertEquals("Paperwork", groups.first().first)
        assertEquals(photo.size, groups.sumOf { it.second.size })
        assertTrue(groups.none { it.first == "Understand it" })
    }
    @Test fun textStartGoalsInOrder() =
        assertEquals(listOf("Understand it", "Clean it up", "Turn it into something", "Money"), BlockGoals.grouped(BlockGoals.starting(Kind.TEXT)).map { it.first })

    // Watermark, exact pixel size, small size limits
    @Test fun pixelsParsesAndRejects() {
        assertEquals(413 to 531, TextTidy.pixels("413x531")); assertEquals(600 to 600, TextTidy.pixels("600 × 600"))
        assertNull(TextTidy.pixels("big")); assertNull(TextTidy.pixels("0x100")); assertNull(TextTidy.pixels("99999x10"))
    }
    @Test fun limitLabels() {
        assertEquals("50 KB", TextTidy.limitLabel(0.05)); assertEquals("20 KB", TextTidy.limitLabel(0.02)); assertEquals("2 MB", TextTidy.limitLabel(2.0))
    }
    @Test fun watermarkLineHasWordsAndDay() {
        val day = java.util.Date(1_794_441_600_000L)
        assertTrue(TextTidy.watermarkLine("For Acme Bank only", day).startsWith("For Acme Bank only · "))
        assertTrue(TextTidy.watermarkLine(" ", day).startsWith("For verification only · "))
        assertTrue(TextTidy.watermarkLine("", day).endsWith("2026"))
    }
    @Test fun portalTemplateIsValidAndUsesFiftyKb() {
        val c = ChainTemplates.all.first { it.id == "portal-photo" }
        assertNull(c.problem(Kind.IMAGE)); assertEquals("0.05", c.steps.last().settings["mb"])
    }

    // One PDF for all pages
    @Test fun onePdfToolKeepsPicturesPerPageAndJoinsAtTheEnd() {
        val c = ChainTemplates.all.first { it.id == "scan-to-pdf" }
        assertTrue(c.combine); assertTrue(c.stepsPerPage.isEmpty())
        val longer = Chain("x", "x", listOf(Step(Block.STRIP_LOCATION), Step(Block.PHOTO_PDF)), combine = true)
        assertEquals(listOf(Block.STRIP_LOCATION), longer.stepsPerPage.map { it.block })
        assertEquals(2, longer.copy(combine = false).stepsPerPage.size)
    }

    // File names
    @Test fun fileNames() {
        val day = java.util.Date(1_794_484_800_000L)
        val ymd = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(day)
        assertEquals("Signed form $ymd.pdf", TextTidy.fileName("Signed form {date}", "x", day, ext = "pdf"))
        assertEquals("Rent receipt $ymd-2.jpg", TextTidy.fileName("{tool} {date}", "Rent receipt", day, 2, "jpg"))
        assertEquals("Tenzy-result.pdf", TextTidy.fileName(null, "x", ext = "pdf"))
        assertEquals("Tenzy-3.jpg", TextTidy.fileName("  ", "x", index = 3, ext = "jpg"))
        assertEquals("abcdefghij.pdf", TextTidy.fileName("a/b\\c:d*e?f\"g<h>i|j", "x", ext = "pdf"))
        assertEquals("hidden.pdf", TextTidy.fileName("..hidden.", "x", ext = "pdf"))
        assertEquals(84, TextTidy.fileName("n".repeat(200), "x", ext = "pdf").length)
    }

    // Running expense sheet
    @Test fun listKeepsHeaderOnceAndBothIdenticalRows() {
        val first = TextTidy.mergedList("", "Date,Merchant,Total\n2026-11-10,Blue Door Cafe,7.75")
        assertEquals("Date,Merchant,Total\n2026-11-10,Blue Door Cafe,7.75", first)
        assertEquals("Date,Merchant,Total\n2026-11-10,Blue Door Cafe,7.75\n2026-11-11,Hardware Hut,23.10", TextTidy.mergedList(first, "Date,Merchant,Total\n2026-11-11,Hardware Hut,23.10\n"))
        assertEquals("H\na,1\na,1", TextTidy.mergedList("H\na,1", "H\na,1"))
        assertEquals("H\na,1\nb,2", TextTidy.mergedList("H\n\n a,1 \n", "\n\nb,2"))
        assertEquals("", TextTidy.mergedList("", ""))
    }
    @Test fun expenseRowAndMonthToken() {
        assertEquals("Date,Merchant,Total,Tax,Currency\n,\"Cafe, The\",7.75,,", TextTidy.expenseRow(null, "Cafe, The", "$7.75"))
        val day = java.util.Date(1_794_484_800_000L)
        val ym = java.text.SimpleDateFormat("yyyy-MM", java.util.Locale.US).format(day)
        assertEquals("Expenses $ym.csv", TextTidy.fileName("Expenses {month}", "List", day, ext = "csv"))
    }
    @Test fun receiptRunStarterAndPlanner() {
        val c = ChainTemplates.all.first { it.id == "receipt-run" }
        assertEquals(listOf(Block.READ_TEXT, Block.EXPENSE_ROW, Block.ADD_TO_LIST), c.steps.map { it.block }); assertNull(c.problem(Kind.IMAGE))
        assertEquals(listOf(Block.READ_TEXT, Block.EXPENSE_ROW, Block.ADD_TO_LIST), ChainPlanner.plan("add every receipt to my expense sheet")!!.steps.map { it.block })
    }

    // WhatsApp without saving, contact QR, ID on one page
    @Test fun chatLinkAddsCountryCodeOnlyWhenMissing() {
        assertEquals("https://wa.me/13125550147", TextTidy.chatLink("(312) 555-0147", "1"))
        assertEquals("https://wa.me/442079460958", TextTidy.chatLink("+44 20 7946 0958", "1"))
        assertEquals("https://wa.me/442079460958", TextTidy.chatLink("0044 20 7946 0958", "1"))
        assertEquals("https://wa.me/447911123456", TextTidy.chatLink("07911 123456", "44"))
        assertEquals("https://wa.me/919876543210", TextTidy.chatLink("919876543210", "1"))
        assertEquals("https://wa.me/13125550147", TextTidy.chatLink("Courier: call 312 555 0147 at the gate", "+1"))
        assertEquals("https://wa.me/919876543210", TextTidy.chatLink("98765 43210", "91"))
        assertNull(TextTidy.chatLink("call me later", "1")); assertNull(TextTidy.chatLink("12345", "1"))
    }
    @Test fun callingCodes() {
        assertEquals("91", TextTidy.callingCode("IN")); assertEquals("1", TextTidy.callingCode("us")); assertEquals("1", TextTidy.callingCode(null)); assertEquals("1", TextTidy.callingCode("ZZ"))
    }
    @Test fun slotsStackDownThePage() {
        val s = TextTidy.slots(2, 1000f, 1400f, 100f)
        assertEquals(2, s.size)
        assertTrue(s[0].contentEquals(floatArrayOf(100f, 100f, 900f, 650f))); assertTrue(s[1].contentEquals(floatArrayOf(100f, 750f, 900f, 1300f)))
        assertTrue(TextTidy.slots(0, 10f, 10f, 1f).isEmpty())
    }
    @Test fun startersForPeopleAndId() {
        val w = ChainTemplates.all.first { it.id == "whatsapp-no-save" }
        assertEquals("open", w.finish?.kind); assertEquals("Open it", w.finish?.label); assertNull(w.problem(Kind.TEXT))
        val id = ChainTemplates.all.first { it.id == "id-both-sides" }
        assertTrue(id.combine && id.onePage); assertNull(id.problem(Kind.IMAGE))
        assertNull(ChainTemplates.all.first { it.id == "contact-qr" }.problem(Kind.TEXT))
    }
    @Test fun reminderLabels() {
        assertEquals("Every day at 9:00 AM", Schedule().label())
        assertEquals("Weekdays at 6:30 PM", Schedule(18, 30, listOf(2, 3, 4, 5, 6)).label())
        assertEquals("Weekdays at 18:30", Schedule(18, 30, listOf(2, 3, 4, 5, 6)).label(uses24h = true))
        assertEquals("Weekends at 12:05 AM", Schedule(0, 5, listOf(7, 1)).label())
        assertEquals("Mon, Thu, Sun at 12:00 PM", Schedule(12, 0, listOf(1, 5, 2)).label())
        assertEquals("Every day at 8:00 AM", Schedule(8, 0, listOf(1, 2, 3, 4, 5, 6, 7)).label())
        assertEquals(listOf(2, 6), Schedule(7, 15, listOf(6, 2, 2, 9)).cleanDays)
    }
    @Test fun nextReminderIsAlwaysLaterAndOnAChosenDay() {
        val utc = java.util.TimeZone.getTimeZone("UTC")
        fun at(y: Int, mo: Int, d: Int, h: Int, mi: Int) = java.util.Calendar.getInstance(utc).apply { clear(); set(y, mo - 1, d, h, mi) }.timeInMillis
        val thu = at(2026, 11, 12, 10, 0)                                   // Thursday 12 Nov 2026, 10:00
        assertEquals(at(2026, 11, 12, 18, 0), Schedule(18, 0).next(thu, utc))          // later today
        assertEquals(at(2026, 11, 13, 9, 0), Schedule(9, 0).next(thu, utc))            // already passed: tomorrow
        assertEquals(at(2026, 11, 13, 10, 0), Schedule(10, 0).next(thu, utc))          // exactly now is not "next"
        assertEquals(at(2026, 11, 16, 9, 0), Schedule(9, 0, listOf(2)).next(thu, utc)) // Mondays only
        assertEquals(at(2026, 11, 19, 9, 0), Schedule(9, 0, listOf(5)).next(thu, utc)) // Thursdays, 9:00 has passed: next week
        assertEquals(at(2026, 11, 14, 8, 0), Schedule(8, 0, listOf(1, 7)).next(thu, utc))
    }
    @Test fun aCopiedToolKeepsNoReminder() {
        val c = Chain("a", "Friday receipts", listOf(Step(Block.READ_TEXT, emptyMap())), schedule = Schedule(18, 0, listOf(6)))
        assertEquals(Schedule(18, 0, listOf(6)), c.schedule)
        assertNull(c.copy(schedule = null).schedule)
    }
    @Test fun newPhotoAndScreenshotToolsNeverCrossOver() {
        assertTrue(AutoRun.isScreenshot("Pictures/Screenshots/", "Screenshot_20261112-101500.png"))
        assertTrue(AutoRun.isScreenshot("DCIM/", "screenshot_1.jpg"))
        assertFalse(AutoRun.isScreenshot("DCIM/Camera/", "PXL_20261112_101500.jpg"))
        assertTrue(AutoRun.wants(AutoRun.PHOTO, "DCIM/Camera/", "IMG_0001.jpg"))
        assertFalse(AutoRun.wants(AutoRun.PHOTO, "Pictures/Screenshots/", "Screenshot_1.png"))
        assertTrue(AutoRun.wants(AutoRun.SCREENSHOT, "Pictures/Screenshots/", "Screenshot_1.png"))
        assertFalse(AutoRun.wants(AutoRun.SCREENSHOT, "DCIM/Camera/", "IMG_0001.jpg"))
        assertFalse(AutoRun.wants(AutoRun.OFF, "DCIM/Camera/", "IMG_0001.jpg"))
        assertEquals("Off", AutoRun.title(AutoRun.OFF)); assertEquals("", AutoRun.label(AutoRun.OFF))
    }
    @Test fun sheetCountsAndUndo() {
        assertEquals(0, TextTidy.sheetRows("")); assertEquals(0, TextTidy.sheetRows("Date,Merchant,Total"))
        assertEquals(2, TextTidy.sheetRows("Date,Merchant,Total\n2026-11-01,Cafe,4.50\n\n2026-11-02,Fuel,40\n"))
        assertEquals("Date,Merchant,Total\n2026-11-01,Cafe,4.50", TextTidy.withoutLastRow("Date,Merchant,Total\n2026-11-01,Cafe,4.50\n2026-11-02,Fuel,40"))
        assertNull(TextTidy.withoutLastRow("Date,Merchant,Total")); assertNull(TextTidy.withoutLastRow(""))
        assertEquals("No entries yet · changed today", TextTidy.sheetSummary(0, 0))
        assertEquals("1 entry · changed yesterday", TextTidy.sheetSummary(1, 1))
        assertEquals("12 entries · changed 5 days ago", TextTidy.sheetSummary(12, 5))
    }
    @Test fun stampPlanReadsWritesAndStaysOnThePage() {
        val p = StampPlan.parse(StampPlan.STANDARD)
        assertEquals(listOf(StampPlan.SIG, StampPlan.DATE), p.map { it.mark })
        assertEquals(StampPlan.STANDARD, StampPlan.text(p))
        val odd = StampPlan.parse("sig@2,-1,5; junk@1,1,1; date@0.5,0.5; sig@0.1,0.1,0.1; name@0.25,0.82,0.3")
        assertEquals(listOf(StampSpot("sig", 1.0, 0.0, 0.9), StampSpot("name", 0.25, 0.82, 0.3)), odd)
        assertTrue(StampPlan.parse("").isEmpty())
        val withName = StampPlan.set(p, StampPlan.NAME, true)
        assertEquals(3, withName.size); assertEquals(withName, StampPlan.set(withName, StampPlan.NAME, true))
        assertEquals(listOf(StampPlan.DATE), StampPlan.set(p, StampPlan.SIG, false).map { it.mark })
        val m = StampPlan.moved(p, StampPlan.SIG, 0.5, -0.08).first()
        assertEquals(1.0, m.x, 1e-9); assertEquals(0.80, m.y, 1e-9)
    }
    @Test fun signStarterIsWired() {
        val c = ChainTemplates.all.first { it.id == "sign-and-send" }
        assertNull(c.problem(Kind.IMAGE)); assertTrue(c.combine); assertEquals("mail", c.finish?.kind); assertEquals("Paperwork", Block.STAMP.goal)
    }
    @Test fun otherWaysIn() {
        assertEquals("hello", TextTidy.joined("", " hello \n"))
        assertEquals("one\ntwo", TextTidy.joined("one\n\n", "\ntwo"))
        assertEquals("one", TextTidy.joined("one", "  "))
        val t = TextTidy.contactLines("Priya Shah", "", listOf("+1 415 555 0134"), listOf("priya@studio.example"))
        assertEquals("Priya Shah\n+1 415 555 0134\npriya@studio.example", t)
        assertEquals("https://wa.me/14155550134", TextTidy.chatLink(t, "1"))
    }
    @Test fun startersCanBeNarrowedToWhatYouHave() {
        val photo = BuilderIntro.starters(Kind.IMAGE); val text = BuilderIntro.starters(Kind.TEXT)
        assertTrue(photo.isNotEmpty() && text.isNotEmpty())
        assertTrue(photo.all { it.start == Kind.IMAGE }); assertTrue(text.all { it.start == Kind.TEXT })
        assertEquals(ChainTemplates.all.size, photo.size + text.size)
        assertEquals(ChainTemplates.all, BuilderIntro.starters(null))
        assertNotNull(ChainTemplates.all.firstOrNull { it.id == BuilderIntro.DEMO_ID })
        assertEquals(3, BuilderIntro.PAGES.size)
    }
}
