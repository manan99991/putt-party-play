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
        assertEquals(listOf("Paperwork", "Read what's in it", "Understand it", "Clean it up", "Turn it into something", "Money"), BlockGoals.grouped(BlockGoals.starting(Kind.TEXT)).map { it.first })

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
        val video = BuilderIntro.starters(Kind.VIDEO)
        assertTrue(video.isNotEmpty() && video.all { it.start == Kind.VIDEO })
        val sound = BuilderIntro.starters(Kind.AUDIO); val pdf = BuilderIntro.starters(Kind.PDF)
        assertTrue(sound.isNotEmpty() && pdf.isNotEmpty())
        assertEquals(ChainTemplates.all.size, photo.size + text.size + video.size + sound.size + pdf.size)
        assertEquals(ChainTemplates.all, BuilderIntro.starters(null))
        assertNotNull(ChainTemplates.all.firstOrNull { it.id == BuilderIntro.DEMO_ID })
        assertEquals(3, BuilderIntro.PAGES.size)
    }
    @Test fun wifiDetailsAndCode() {
        assertEquals("CafeGuest" to "latte1234", TextTidy.wifi("Welcome!\nNetwork: CafeGuest\nPassword: latte1234\nEnjoy"))
        assertEquals("Home 5G" to "p@ss:word;1", TextTidy.wifi("WiFi = Home 5G / PW: p@ss:word;1"))
        assertEquals("Lobby" to "", TextTidy.wifi("SSID: Lobby"))
        assertEquals("MyNet" to "secret99", TextTidy.wifi("MyNet\nsecret99"))
        assertNull(TextTidy.wifi("Password: only")); assertNull(TextTidy.wifi("Network problems today, sorry")); assertNull(TextTidy.wifi(""))
        assertEquals("WIFI:T:WPA;S:CafeGuest;P:latte1234;;", TextTidy.wifiCode("Network: CafeGuest\nPassword: latte1234"))
        assertEquals("WIFI:T:WPA;S:Home 5G;P:p@ss\\:word\\;1;;", TextTidy.wifiCode("WiFi = Home 5G / PW: p@ss:word;1"))
        assertEquals("WIFI:T:nopass;S:Lobby;;", TextTidy.wifiCode("SSID: Lobby"))
        assertNull(ChainTemplates.all.first { it.id == "wifi-sign" }.problem(Kind.IMAGE))
    }
    @Test fun identifyWording() {
        assertEquals("Barcode 0123456789012\nMug (87% sure)\nCup (61% sure)", TextTidy.identifyLines("0123456789012", listOf("Mug" to 0.87f, "Cup" to 0.612f)))
        assertEquals("Plant (50% sure)", TextTidy.identifyLines(" ", listOf("Plant" to 0.5f)))
        assertEquals("", TextTidy.identifyLines(null, emptyList()))
        assertEquals("Read what's in it", Block.IDENTIFY.goal); assertEquals("Make it look better", Block.CUTOUT.goal)
    }
    @Test fun returnByDeadline() {
        val utc = java.util.TimeZone.getTimeZone("UTC")
        fun at(y: Int, mo: Int, d: Int, h: Int, mi: Int) = java.util.Calendar.getInstance(utc).apply { clear(); set(y, mo - 1, d, h, mi) }.timeInMillis
        assertEquals(at(2026, 12, 12, 9, 0), TextTidy.returnDeadline(at(2026, 11, 12, 17, 40), 30, 0L, utc))
        assertEquals(at(2026, 2, 14, 9, 0), TextTidy.returnDeadline(null, 14, at(2026, 1, 31, 8, 0), utc))
        assertEquals("Last day to return: Corner Hardware", TextTidy.returnTitle(" Corner Hardware ")); assertEquals("Last day to return", TextTidy.returnTitle(""))
        assertEquals(30, TextTidy.returnDays(null)); assertEquals(60, TextTidy.returnDays("60")); assertEquals(1, TextTidy.returnDays("0"))
        assertEquals(365, TextTidy.returnDays("9999")); assertEquals(30, TextTidy.returnDays("soon"))
        assertNull(ChainTemplates.all.first { it.id == "return-by" }.problem(Kind.IMAGE)); assertEquals("Money", Block.RETURN_BY.goal)
    }
    @Test fun bestDealRanksByUnitPrice() {
        val us = java.util.Locale.US
        val out = PriceDeal.bestDeal("Oats 500 g\n\$3.20\nOats 1 kg\n\$5.00", us)!!
        assertEquals("Best deal: Oats, \$0.50 per 100 g\nOats, \$0.64 per 100 g", out)
        assertNull(PriceDeal.bestDeal("Just one thing 500 g\n\$3.20", us))
        assertNull(PriceDeal.bestDeal("no prices here", us))
        val each = PriceDeal.bestDeal("Soap 3 pack \$6.00\nSoap 8 ct \$12.00", us)!!
        assertEquals("Best deal: Soap, \$1.50 each\nSoap, \$2.00 each", each)
    }
    @Test fun sizesReduceToOneUnit() {
        assertEquals(PriceDeal.Size(1500.0, PriceDeal.Base.VOLUME), PriceDeal.parseSize("1.5 L"))
        assertEquals(PriceDeal.Size(400.0, PriceDeal.Base.VOLUME), PriceDeal.parseSize("2 x 200 ml"))
        assertEquals(453.592, PriceDeal.parseSize("16 oz")!!.qty, 0.01)
        assertEquals(PriceDeal.Base.VOLUME, PriceDeal.parseSize("12 fl oz")!!.base)
        assertEquals(PriceDeal.Size(24.0, PriceDeal.Base.COUNT), PriceDeal.parseSize("24 ct"))
        assertNull(PriceDeal.parseSize("large"))
    }
    @Test fun describingAPhotoFromWhatWasDetected() {
        assertEquals("This looks like dog, grass and ball. There is one person in it.", PriceDeal.describe(listOf("Dog", "Grass", "dog", "Ball"), 1, ""))
        assertEquals("This looks like poster. It has writing that starts: \"Summer fair Saturday 2 pm\"", PriceDeal.describe(listOf("Poster"), 0, "Summer fair\nSaturday  2 pm"))
        assertEquals("There are 3 people in it.", PriceDeal.describe(emptyList(), 3, ""))
        assertEquals("", PriceDeal.describe(emptyList(), 0, "  "))
    }
    @Test fun levelsFindTheRealRangeOfAFlatPhoto() {
        val flat = IntArray(256); for (i in 60..180) flat[i] = 100; flat[0] = 3; flat[255] = 2
        assertEquals(61 to 179, PriceDeal.levels(flat))   // the outer 1% at each end is ignored
        assertEquals(0 to 255, PriceDeal.levels(IntArray(256)))
        val blank = IntArray(256); blank[250] = 5000
        assertEquals(0 to 255, PriceDeal.levels(blank))
        assertEquals(600 to 600, PriceDeal.passportSize(null)); assertEquals(413 to 531, PriceDeal.passportSize("in")); assertEquals(591 to 827, PriceDeal.passportSize("ca"))
    }
    @Test fun androidNowHasEveryStepTheIphoneHas() {
        val ios = listOf("readText", "pullReceipt", "summarize", "shrinkImage", "stripLocation", "cutout", "enhance", "convertImage", "businessCard", "calendarEvent", "actionItems",
            "hideSensitive", "passportPhoto", "cleanText", "pullDetails", "makeTable", "scamCheck", "cleanLinks", "priceCompare", "makeQr", "describe", "identify", "photoPdf",
            "watermark", "resizePhoto", "stamp", "expenseRow", "addToList", "chatLink", "contactQr", "wifiQr", "returnBy", "videoShrink", "videoStill", "videoMute", "videoAudio",
            "videoTrim", "videoGif", "videoRotate", "videoVertical", "videoCaptions", "speechText", "readAloud", "translate", "rewrite", "readCode", "pageText", "textPdf",
            "pdfShrink", "pdfLock", "pdfPages", "pdfText", "sticker", "emojiFaces", "meme", "emojiMosaic", "videoSpeed", "videoLoop", "artFilter", "voiceChange")
        assertEquals(emptyList<String>(), ios.filter { Block.byId(it) == null })
        assertEquals("both phones have exactly the same steps", ios.size, Block.values().size)
    }
    @Test fun videoStepsOnlyFitAVideo() {
        val v = listOf(Block.VIDEO_SHRINK, Block.VIDEO_STILL, Block.VIDEO_MUTE, Block.VIDEO_AUDIO, Block.VIDEO_TRIM, Block.VIDEO_GIF, Block.VIDEO_ROTATE, Block.VIDEO_VERTICAL, Block.VIDEO_CAPTIONS, Block.VIDEO_SPEED, Block.VIDEO_LOOP)
        assertTrue(v.all { it.takes == Kind.VIDEO })
        assertEquals(v.toSet(), BlockGoals.starting(Kind.VIDEO).toSet())
        assertFalse(Block.VIDEO_SHRINK in BlockGoals.starting(Kind.IMAGE)); assertFalse(Block.VIDEO_STILL in BlockGoals.starting(Kind.TEXT))
        assertNull(Chain("a", "A", listOf(Step(Block.VIDEO_MUTE), Step(Block.VIDEO_SHRINK))).problem(Kind.VIDEO))
        assertNotNull(Chain("a", "A", listOf(Step(Block.VIDEO_MUTE), Step(Block.VIDEO_SHRINK))).problem(Kind.IMAGE))
        assertNull(Chain("b", "B", listOf(Step(Block.VIDEO_STILL), Step(Block.READ_TEXT), Step(Block.SUMMARIZE))).problem(Kind.VIDEO))
        assertNotNull(Chain("c", "C", listOf(Step(Block.VIDEO_AUDIO), Step(Block.VIDEO_SHRINK))).problem(Kind.VIDEO))
        for (id in listOf("video-email", "video-chat", "video-still", "video-quiet")) {
            val c = ChainTemplates.all.first { it.id == id }
            assertNull(id, c.problem(Kind.VIDEO))   // (copy and paste uses org.json, which plain unit tests can't run; the iOS twin covers it)
        }
        assertEquals("mail", ChainTemplates.all.first { it.id == "video-email" }.finish?.kind)
    }
    @Test fun videoSizeMaths() {
        assertEquals(25, TextTidy.videoLimit(null)); assertEquals(16, TextTidy.videoLimit("16")); assertEquals(16, TextTidy.videoLimit("16.0"))
        assertEquals(1, TextTidy.videoLimit("0")); assertEquals(25, TextTidy.videoLimit("junk"))
        // One minute into 25 MB: about 2.9 million bits a second for the picture once sound and overhead are set aside.
        assertEquals(2_947_822, TextTidy.videoBitrate(25L * 1_048_576L, 60_000L))
        assertEquals(200_000, TextTidy.videoBitrate(10L * 1_048_576L, 3_600_000L))          // an hour into 10 MB: the floor
        assertEquals(12_000_000, TextTidy.videoBitrate(100L * 1_048_576L, 5_000L))          // five seconds: the ceiling
        assertEquals(2_000_000, TextTidy.videoBitrate(25L * 1_048_576L, 0L))                // unknown length
        assertEquals(360, TextTidy.videoHeight(500_000)); assertEquals(480, TextTidy.videoHeight(1_000_000))
        assertEquals(720, TextTidy.videoHeight(2_947_822)); assertEquals(1080, TextTidy.videoHeight(8_000_000))
    }
    @Test fun describeItUnderstandsVideoJobs() {
        fun blocks(ask: String) = ChainPlanner.plan(ask)?.steps?.map { it.block } ?: emptyList()
        assertEquals(listOf(Block.VIDEO_SHRINK), blocks("make this video small enough to email"))
        assertEquals("16", ChainPlanner.plan("shrink a video for whatsapp")?.steps?.first()?.settings?.get("mb"))
        assertEquals("50", ChainPlanner.plan("get my video under 50 mb")?.steps?.first()?.settings?.get("mb"))
        assertEquals(listOf(Block.VIDEO_MUTE), blocks("video without sound"))
        assertEquals(listOf(Block.VIDEO_MUTE, Block.VIDEO_SHRINK), blocks("mute the video and shrink it"))
        assertEquals(listOf(Block.VIDEO_STILL), blocks("grab a still from a video"))
        assertEquals(listOf(Block.VIDEO_AUDIO), blocks("just the audio from this video"))
        assertEquals(Block.SHRINK, blocks("shrink a photo under 1 mb").last())
    }

    // Recordings, PDFs, links, codes, translating, collages and the extra video steps
    private fun chain(vararg b: Block) = Chain("t", "T", b.map { Step(it) })

    @Test fun newKindsHaveTheirOwnSteps() {
        assertEquals(listOf(Block.SPEECH_TEXT, Block.VOICE_CHANGE), BlockGoals.starting(Kind.AUDIO))
        assertEquals(setOf(Block.PDF_SHRINK, Block.PDF_LOCK, Block.PDF_PAGES, Block.PDF_TEXT), BlockGoals.starting(Kind.PDF).toSet())
        assertTrue(Block.READ_CODE in BlockGoals.starting(Kind.IMAGE)); assertTrue(Block.TRANSLATE in BlockGoals.starting(Kind.TEXT))
        assertEquals(Kind.PDF, Block.PHOTO_PDF.gives); assertEquals(Kind.PDF, Block.TEXT_PDF.gives); assertEquals(Kind.AUDIO, Block.READ_ALOUD.gives)
        assertEquals(Kind.AUDIO, Block.VIDEO_AUDIO.gives); assertEquals(Kind.FILE, Block.VIDEO_GIF.gives)
        assertEquals("a recording", Kind.AUDIO.label); assertEquals("a PDF", Kind.PDF.label)
        assertFalse(Kind.PDF.feeds(Kind.IMAGE)); assertFalse(Kind.AUDIO.feeds(Kind.VIDEO))
        assertTrue(TextTidy.isAudio("M4A")); assertTrue(TextTidy.isAudio("wav")); assertFalse(TextTidy.isAudio("pdf")); assertFalse(TextTidy.isAudio("mp4"))
    }
    @Test fun stepsChainAcrossTheNewKinds() {
        assertNull(chain(Block.VIDEO_AUDIO, Block.SPEECH_TEXT, Block.ACTION_ITEMS).problem(Kind.VIDEO))
        assertNull(chain(Block.PHOTO_PDF, Block.PDF_LOCK).problem(Kind.IMAGE))
        assertNull(chain(Block.PAGE_TEXT, Block.TEXT_PDF, Block.PDF_SHRINK).problem(Kind.TEXT))
        assertNull(chain(Block.READ_CODE, Block.CLEAN_LINKS, Block.MAKE_QR).problem(Kind.IMAGE))
        assertNull(chain(Block.PDF_TEXT, Block.TRANSLATE, Block.READ_ALOUD).problem(Kind.PDF))
        assertNotNull(chain(Block.SPEECH_TEXT).problem(Kind.PDF))
        assertNotNull(chain(Block.PDF_LOCK).problem(Kind.IMAGE))
        assertNotNull(chain(Block.VIDEO_GIF, Block.VIDEO_SHRINK).problem(Kind.VIDEO))   // a GIF is a finished file, not a video
    }
    @Test fun pageListReadsRangesAndIgnoresJunk() {
        assertEquals(listOf(0, 1, 2, 4), TextTidy.pageList("1-3, 5", 10))
        assertEquals(listOf(0, 1, 2), TextTidy.pageList("", 3))
        assertEquals(listOf(0, 1), TextTidy.pageList("abc", 2))
        assertEquals(listOf(0, 1, 2), TextTidy.pageList("3-1", 5))
        assertEquals(listOf(1), TextTidy.pageList("2,2;2", 5))
        assertEquals(listOf(4, 0), TextTidy.pageList("5, 1", 5))
        assertEquals(listOf(0, 1, 2, 3), TextTidy.pageList("1-999999999", 4))
        assertEquals(listOf(0, 1, 2), TextTidy.pageList("7-9", 3))
        assertEquals(listOf(0, 1), TextTidy.pageList("1\u20132", 5))
        assertEquals(emptyList<Int>(), TextTidy.pageList("1", 0))
        assertEquals(5, TextTidy.pdfLimit(null)); assertEquals(2, TextTidy.pdfLimit("2")); assertEquals(1, TextTidy.pdfLimit("0"))
    }
    @Test fun trimKeepsTheStartOrTheEnd() {
        assertEquals(0L to 30_000L, TextTidy.trimWindow("first", "30", 100_000L))
        assertEquals(70_000L to 100_000L, TextTidy.trimWindow("last", "30", 100_000L))
        assertEquals(0L to 12_000L, TextTidy.trimWindow("last", "30", 12_000L))      // a short video is kept whole
        assertEquals(0L to 30_000L, TextTidy.trimWindow(null, null, 100_000L))
        assertEquals(0L to 1_000L, TextTidy.trimWindow("first", "0", 100_000L))
        assertEquals(270, TextTidy.turnDegrees("left")); assertEquals(180, TextTidy.turnDegrees("flip")); assertEquals(90, TextTidy.turnDegrees(null))
    }
    @Test fun aWebPageBecomesItsWords() {
        val html = "<html><head><title>Big &amp; Small</title><style>p{}</style></head><body><nav>Menu</nav><article><h1>Big &amp; Small</h1><p>First\n para.</p><ul><li>One</li><li>Two</li></ul><script>x()</script></article><footer>Foot</footer></body></html>"
        assertEquals("Big & Small\nFirst para.\n\u2022 One\n\u2022 Two", TextTidy.article(html))
        assertEquals("only", TextTidy.article("<p>only</p>"))
        assertEquals("T\nA\nB", TextTidy.article("<title>T</title><div>A<br>B</div>"))
        assertEquals("", TextTidy.article(""))
        assertEquals("", TextTidy.article("<script>var a = 1</script>"))
        assertEquals("https://example.com/x", TextTidy.pageLink("https://example.com/x"))
        assertEquals("https://www.example.com/a", TextTidy.pageLink("read www.example.com/a tonight"))
        assertNull(TextTidy.pageLink("no links here"))
    }
    @Test fun languagesStylesGridAndLocation() {
        assertEquals(19, TextTidy.LANGUAGES.size); assertEquals(19, TextTidy.LANGUAGES.map { it.first }.toSet().size)
        assertEquals("en", TextTidy.languageCode("xx")); assertEquals("es", TextTidy.languageCode("es")); assertEquals("Spanish", TextTidy.languageName("es"))
        assertEquals("clear", TextTidy.rewriteStyle("nope")); assertEquals("formal", TextTidy.rewriteStyle("formal"))
        for ((n, c, r) in listOf(Triple(0, 0, 0), Triple(1, 1, 1), Triple(2, 2, 1), Triple(3, 2, 2), Triple(4, 2, 2), Triple(5, 3, 2), Triple(9, 3, 3), Triple(10, 4, 3))) {
            assertEquals("$n", c to r, TextTidy.collageGrid(n))
        }
        assertEquals("I'm here: Main St\nhttps://maps.google.com/?q=41.87811,-87.62980", TextTidy.locationText(41.87811, -87.6298, "Main St"))
        assertEquals("I'm here:\nhttps://maps.google.com/?q=1.00000,2.00000", TextTidy.locationText(1.0, 2.0, " "))
    }
    @Test fun aStepThisPhoneCannotRunSaysWhy() {
        // An older phone, or one with no speech recogniser, can't write out a recording; a newer one can.
        assertNotNull(TextTidy.unavailable(Block.SPEECH_TEXT, 30, true)); assertNotNull(TextTidy.unavailable(Block.SPEECH_TEXT, 34, false))
        assertNull(TextTidy.unavailable(Block.SPEECH_TEXT, 33, true))
        assertNotNull(TextTidy.unavailable(Block.VIDEO_CAPTIONS, 35, true)); assertNotNull(TextTidy.unavailable(Block.REWRITE, 35, true))
        // Everything else is always there, whatever the phone.
        val gated = setOf(Block.SPEECH_TEXT, Block.VIDEO_CAPTIONS, Block.REWRITE)
        for (b in Block.values()) if (b !in gated) assertNull(b.id, TextTidy.unavailable(b, 26, false))
    }
    @Test fun newStartersAreSetUpAsDescribed() {
        assertTrue(ChainTemplates.all.first { it.id == "photo-collage" }.collage)
        assertTrue(ChainTemplates.all.first { it.id == "pdf-join" }.combine)
        assertEquals(listOf(Block.VIDEO_AUDIO, Block.SPEECH_TEXT), ChainTemplates.all.first { it.id == "video-words" }.steps.map { it.block })
        assertFalse(chain(Block.CLEAN_TEXT).collage)
        assertEquals(63, ChainTemplates.all.size); assertEquals(63, ChainTemplates.all.map { it.id }.toSet().size)
    }
    @Test fun describeItUnderstandsTheNewKinds() {
        fun blocks(ask: String) = ChainPlanner.plan(ask)?.steps?.map { it.block } ?: emptyList()
        assertEquals(listOf(Block.SPEECH_TEXT), blocks("transcribe my voice memo"))
        assertEquals(listOf(Block.VIDEO_AUDIO, Block.SPEECH_TEXT, Block.ACTION_ITEMS), blocks("write out what was said in a video and find the tasks"))
        assertEquals(listOf(Block.VIDEO_CAPTIONS), blocks("add captions to my video"))
        assertEquals(listOf(Block.VIDEO_GIF), blocks("turn a video into a gif"))
        val story = ChainPlanner.plan("keep the first 15 seconds of a video and make it vertical")
        assertEquals(listOf(Block.VIDEO_TRIM, Block.VIDEO_VERTICAL), story?.steps?.map { it.block }); assertEquals("15", story?.steps?.first()?.settings?.get("secs"))
        val join = ChainPlanner.plan("merge pdfs into one")
        assertEquals(listOf(Block.PDF_PAGES), join?.steps?.map { it.block }); assertEquals(true, join?.combine)
        assertEquals(listOf(Block.PDF_SHRINK), blocks("shrink a pdf under 2 mb")); assertEquals("2", ChainPlanner.plan("shrink a pdf under 2 mb")?.steps?.first()?.settings?.get("mb"))
        assertEquals(listOf(Block.PDF_LOCK), blocks("lock a pdf with a password"))
        val menu = ChainPlanner.plan("translate a photo of a menu into spanish")
        assertEquals(listOf(Block.READ_TEXT, Block.TRANSLATE), menu?.steps?.map { it.block }); assertEquals("es", menu?.steps?.last()?.settings?.get("to"))
        assertEquals("en", ChainPlanner.plan("translate this text")?.steps?.last()?.settings?.get("to"))
        assertEquals(listOf(Block.PAGE_TEXT, Block.TEXT_PDF), blocks("save a web page as a pdf"))
        assertEquals(listOf(Block.READ_ALOUD), blocks("read this text aloud"))
        assertEquals(listOf(Block.READ_CODE, Block.SCAM_CHECK), blocks("is this qr code safe"))
        assertEquals(listOf(Block.MAKE_QR), blocks("turn a link into a qr code"))      // making a code is still making a code
        assertEquals("formal", ChainPlanner.plan("rewrite this to be more formal")?.steps?.first()?.settings?.get("style"))
    }

    // "Describe it" reading what people actually type: misspelt, cut short, or only half said
    private fun planned(ask: String) = ChainPlanner.plan(ask)?.steps?.map { it.block } ?: emptyList()

    @Test fun misspeltWordsAreReadAsMeant() {
        assertEquals("shrink my photo and remove the location", PlannerWords.tidy("Shrnk my foto and remve the loction"))
        assertEquals("video", PlannerWords.tidy("vidoe"))
        assertEquals("compress a receipt", PlannerWords.tidy("comprssing a recipt"))
        assertEquals("translate to spanish", PlannerWords.tidy("trnslate to spansh"))
        assertEquals("watermark password summarize", PlannerWords.tidy("watermak pasword sumarize"))
    }
    @Test fun whatIsAlreadyRightIsLeftAlone() {
        assertEquals("under 50 kb, 9:16 & to-do, tl;dr", PlannerWords.tidy("under 50 kb, 9:16 & to-do, tl;dr"))
        assertEquals("the store phone price", PlannerWords.tidy("the store phone price"))
        assertEquals("make it clear and formal", PlannerWords.tidy("make it clear and formal"))
        assertEquals("xyzzy qwrtp", PlannerWords.tidy("xyzzy qwrtp"))
        assertEquals("", PlannerWords.tidy(""))
        assertEquals(1, PlannerWords.distance("photo", "phto", 2)); assertEquals(1, PlannerWords.distance("video", "vidoe", 2))
        assertEquals(3, PlannerWords.distance("photo", "banana", 2))
    }
    @Test fun typosStillBuildTheRightTool() {
        assertEquals(listOf(Block.STRIP_LOCATION, Block.SHRINK), planned("shrnk my foto and remve the loction"))
        assertEquals(listOf(Block.VIDEO_SHRINK), planned("compres my vidoe for watsapp"))
        assertEquals("16", ChainPlanner.plan("compres my vidoe for watsapp")?.steps?.first()?.settings?.get("mb"))
        assertEquals(listOf(Block.READ_TEXT, Block.TRANSLATE), planned("trnslate a pic of a menu to spansh"))
        assertEquals("es", ChainPlanner.plan("trnslate a pic of a menu to spansh")?.steps?.last()?.settings?.get("to"))
        assertEquals(listOf(Block.SPEECH_TEXT), planned("voice memmo to notes"))
        assertEquals(listOf(Block.PAGE_TEXT, Block.SUMMARIZE), planned("sumarize this artcle"))
        assertEquals(listOf(Block.SCAM_CHECK), planned("is this mesage a scm"))
        assertEquals(listOf(Block.SCAM_CHECK), planned("is this mesage a scam"))
    }
    @Test fun halfARequestStillGetsTheWholeJob() {
        assertEquals(listOf(Block.HIDE_SENSITIVE, Block.STRIP_LOCATION, Block.SHRINK), planned("I want to post a photo online stripping all the personal data"))
        assertEquals(listOf(Block.HIDE_SENSITIVE, Block.STRIP_LOCATION), planned("remove personal info from my picture"))
        assertEquals(listOf(Block.STRIP_LOCATION, Block.SHRINK), planned("post this pic on instagram"))
        assertEquals(listOf(Block.STRIP_LOCATION, Block.SHRINK), planned("my photo"))
        assertEquals(listOf(Block.CLEAN_TEXT), planned("some notes"))
        assertEquals(listOf(Block.STRIP_LOCATION), planned("collage")); assertEquals(true, ChainPlanner.plan("collage")?.collage)
        assertEquals("Photos into one collage", ChainPlanner.plan("colage")?.name)
        assertEquals(listOf(Block.PASSPORT_PHOTO), planned("pasport"))
        assertNull(ChainPlanner.plan("make me a sandwich")); assertNull(ChainPlanner.plan("   "))
    }
    @Test fun itSaysWhenItIsOnlyAGuess() {
        assertEquals(true, ChainPlanner.guess("shrink a photo under 1 mb")?.second)
        assertEquals(false, ChainPlanner.guess("my photo")?.second)
        assertEquals(false, ChainPlanner.guess("collage")?.second)
        assertFalse(ChainPlanner.guess("collage")?.first?.id == "photo-collage")
    }
    @Test fun theEndingIsReadFromTheRequest() {
        assertEquals("mail", ChainPlanner.plan("shrink a photo and email it")?.finish?.kind)
        assertEquals("message", ChainPlanner.plan("scan a receipt and text it to my accountant")?.finish?.kind)
        assertNull(ChainPlanner.plan("find the email address in some text")?.finish)
        assertNull(ChainPlanner.plan("shrink a photo under 1 mb")?.finish)
    }
    @Test fun toolsGetNamesPeopleCanRead() {
        assertEquals("Shrink video for whatsapp", ChainPlanner.plan("shrink video for whatsapp")?.name)
        assertEquals("Privacy share shield", ChainPlanner.plan("I want to post a photo online stripping all the personal data")?.name)
        val c = Chain("x", "My tool", listOf(Step(Block.READ_TEXT), Step(Block.TRANSLATE), Step(Block.READ_ALOUD)))
        assertEquals("Read text + 2 more", ChainPlanner.autoName(c))
        assertEquals("Enhance + Add a watermark", ChainPlanner.autoName(Chain("x", "", listOf(Step(Block.ENHANCE), Step(Block.WATERMARK)))))
        assertEquals("Make a calendar event", ChainPlanner.autoName(Chain("x", "", listOf(Step(Block.CALENDAR_EVENT)))))
        assertEquals("My tool", ChainPlanner.autoName(Chain("x", "", emptyList())))
        assertEquals("Read text + 2 more", ChainPlanner.savedName(c))
        assertEquals("Menu helper", ChainPlanner.savedName(c.copy(name = "  Menu helper ")))
    }
    @Test fun androidDescribeItKnowsThePhotoJobsTheIphoneDoes() {
        assertEquals(listOf(Block.IDENTIFY), planned("what plant is this"))
        assertEquals(listOf(Block.DESCRIBE), planned("describe this photo for me"))
        assertEquals(listOf(Block.WATERMARK, Block.STRIP_LOCATION), planned("add a watermark to my licence copy and strip the location"))
        assertEquals("0.05", ChainPlanner.plan("shrink my photo under 50 kb for the visa upload")?.steps?.last()?.settings?.get("mb"))
        assertEquals(listOf(Block.STRIP_LOCATION, Block.PHOTO_PDF), planned("strip the location and make a pdf"))
    }

    @Test fun aSharedThingIsSortedByItsType() {
        assertEquals(Kind.IMAGE, kindOf("image/jpeg", false)); assertEquals(Kind.VIDEO, kindOf("video/mp4", false))
        assertEquals(Kind.AUDIO, kindOf("audio/mpeg", false)); assertEquals(Kind.PDF, kindOf("application/pdf", false))
        assertEquals(Kind.TEXT, kindOf(null, true)); assertEquals(Kind.TEXT, kindOf("text/plain", true))
        assertNull(kindOf("application/zip", false)); assertNull(kindOf(null, false))
        // Every kind something can arrive as has at least one starter ready for it.
        for (k in listOf(Kind.IMAGE, Kind.VIDEO, Kind.AUDIO, Kind.PDF, Kind.TEXT)) assertTrue(k.label, ChainOffers.forKind(k, emptyList(), null).isNotEmpty())
    }

    @Test fun funStepsFitWhereTheyShould() {
        for (b in listOf(Block.STICKER, Block.EMOJI_FACES, Block.MEME, Block.EMOJI_MOSAIC)) { assertEquals(b.id, Kind.IMAGE, b.takes); assertEquals("Just for fun", b.goal) }
        for (b in listOf(Block.VIDEO_SPEED, Block.VIDEO_LOOP)) { assertEquals(b.id, Kind.VIDEO, b.takes); assertEquals("Just for fun", b.goal) }
        assertTrue("Just for fun" in BlockGoals.ORDER)
        assertNull(chain(Block.EMOJI_FACES, Block.MEME, Block.STRIP_LOCATION).problem(Kind.IMAGE))
        assertNull(chain(Block.STICKER, Block.SHRINK).problem(Kind.IMAGE))
        assertNull(chain(Block.VIDEO_TRIM, Block.VIDEO_SPEED, Block.VIDEO_SHRINK).problem(Kind.VIDEO))
        assertNotNull(chain(Block.VIDEO_LOOP, Block.VIDEO_SHRINK).problem(Kind.VIDEO))
        assertNotNull(chain(Block.MEME).problem(Kind.TEXT))
    }
    @Test fun funHelpersDoWhatTheySay() {
        assertEquals(TextTidy.FACE_EMOJIS[0], TextTidy.faceEmoji(null)); assertEquals(TextTidy.FACE_EMOJIS[0], TextTidy.faceEmoji("x")); assertEquals("🤖", TextTidy.faceEmoji("🤖"))
        assertEquals("WHEN IT WORKS FIRST TIME", TextTidy.memeText("  when it\nworks   first time "))
        assertEquals("", TextTidy.memeText("   ")); assertEquals(120, TextTidy.memeText("ab ".repeat(100)).length)
        assertEquals(0.5, TextTidy.speedRate("slow"), 0.0); assertEquals(2.0, TextTidy.speedRate("fast"), 0.0); assertEquals(4.0, TextTidy.speedRate("faster"), 0.0); assertEquals(0.5, TextTidy.speedRate(null), 0.0)
        assertEquals(listOf(0, 1, 2, 3, 2, 1), TextTidy.loopOrder(4, "boomerang")); assertEquals(listOf(0, 1, 2, 3, 2, 1), TextTidy.loopOrder(4, null))
        assertEquals(listOf(3, 2, 1, 0), TextTidy.loopOrder(4, "reverse"))
        assertEquals(listOf(0, 1), TextTidy.loopOrder(2, "boomerang")); assertEquals(listOf(0), TextTidy.loopOrder(1, "boomerang")); assertEquals(emptyList<Int>(), TextTidy.loopOrder(0, "reverse"))
        assertEquals(56 to 42, TextTidy.mosaicGrid(4000.0, 3000.0)); assertEquals(42 to 56, TextTidy.mosaicGrid(3000.0, 4000.0)); assertEquals(56 to 56, TextTidy.mosaicGrid(10.0, 10.0))
        assertEquals(56 to 1, TextTidy.mosaicGrid(5000.0, 10.0)); assertEquals(0 to 0, TextTidy.mosaicGrid(0.0, 10.0))
        val palette = listOf(intArrayOf(255, 0, 0), intArrayOf(0, 255, 0), intArrayOf(250, 250, 250))
        assertEquals(0, TextTidy.nearestColor(200, 30, 20, palette)); assertEquals(2, TextTidy.nearestColor(255, 255, 255, palette)); assertEquals(-1, TextTidy.nearestColor(1, 2, 3, emptyList()))
        assertEquals(TextTidy.MOSAIC_EMOJIS.size, TextTidy.MOSAIC_EMOJIS.toSet().size); assertTrue(TextTidy.MOSAIC_EMOJIS.size >= 48)
    }
    @Test fun describeItUnderstandsTheFunRequests() {
        assertEquals(listOf(Block.MEME), planned("make a meme")); assertEquals(listOf(Block.MEME), planned("make a meme from my foto"))
        assertEquals(listOf(Block.STICKER), planned("turn my dog into a sticker")); assertEquals(listOf(Block.STICKER), planned("whatsapp stikcer of my cat"))
        assertEquals(listOf(Block.CUTOUT), planned("remove the background"))
        assertEquals(listOf(Block.EMOJI_FACES), planned("put an emoji on my kids faces")); assertEquals(listOf(Block.EMOJI_FACES), planned("hide faces with emojis"))
        assertEquals(listOf(Block.EMOJI_MOSAIC), planned("emoji mosaic of my selfie")); assertEquals(listOf(Block.EMOJI_MOSAIC), planned("photo made of emojis"))
        assertEquals(listOf(Block.VIDEO_LOOP), planned("boomerang")); assertEquals("boomerang", ChainPlanner.plan("bomerang of my video")?.steps?.first()?.settings?.get("style"))
        assertEquals("reverse", ChainPlanner.plan("play my video backwards")?.steps?.first()?.settings?.get("style"))
        assertEquals("slow", ChainPlanner.plan("slow motion video")?.steps?.first()?.settings?.get("speed")); assertEquals(listOf(Block.VIDEO_SPEED), planned("slow mo"))
        assertEquals("fast", ChainPlanner.plan("speed up my video")?.steps?.first()?.settings?.get("speed")); assertEquals("faster", ChainPlanner.plan("make a timelapse")?.steps?.first()?.settings?.get("speed"))
        val gif = ChainPlanner.plan("make a gif from my photos")
        assertEquals(true, gif?.gif); assertEquals(Kind.IMAGE, gif?.start)
        assertEquals(listOf(Block.VIDEO_GIF), planned("turn my video into a gif")); assertEquals(false, ChainPlanner.plan("turn my video into a gif")?.gif)
        assertEquals(listOf(Block.VIDEO_SHRINK), planned("shrink video for whatsapp"))
        assertNull(ChainPlanner.plan("what I spend on a faster phone")?.steps?.firstOrNull { it.block == Block.VIDEO_SPEED })
    }
    @Test fun theGifOptionTravelsWithTheTool() {
        val t = ChainTemplates.all.first { it.id == "photos-gif" }
        assertTrue(t.gif); assertFalse(t.collage)
        assertFalse(chain(Block.CLEAN_TEXT).gif)       // (copy and paste uses org.json, which plain unit tests can't run; the iOS twin covers the round trip)
        assertEquals("Photo to a sticker", ChainPlanner.autoName(Chain("x", "", listOf(Step(Block.STICKER)))))
    }

    @Test fun picturesAreRedrawnInEachStyle() {
        // A 6 by 4 picture: left half black, right half white.
        val w = 6; val h = 4
        val px = IntArray(w * h) { if (it % w < 3) 0x000000 else 0xFFFFFF }
        assertEquals(listOf(0, 255), PixelArt.gray(px).toList().distinct())
        val flat = IntArray(w * h) { 100 }
        assertTrue(PixelArt.blur(flat, w, h, 2).all { it == 100 })
        assertEquals(flat.toList(), PixelArt.blur(flat, w, h, 0).toList())
        val soft = PixelArt.blur(PixelArt.gray(px), w, h, 1)
        assertTrue(soft[2] in 1..254); assertEquals(0, soft[0]); assertEquals(255, soft[5])
        val noir = PixelArt.apply(px, w, h, "noir"); assertEquals(0x000000, noir[0]); assertEquals(0xFFFFFF, noir[5])
        val pop = PixelArt.apply(px, w, h, "pop"); assertEquals(2, pop.toList().distinct().size); assertEquals(0x1B1464, pop[0]); assertEquals(0xFFF8E7, pop[5])
        val sketch = PixelArt.apply(IntArray(w * h) { 0x808080 }, w, h, "sketch")
        assertTrue("an even grey wall is blank paper", sketch.all { it == 0xFFFFFF })
        assertEquals(sketch.toList(), PixelArt.apply(IntArray(w * h) { 0x808080 }, w, h, "nonsense").toList())
        val comic = PixelArt.apply(IntArray(w * h) { 0x2060E0 }, w, h, "comic")
        assertTrue(comic.all { it == 0x4080FF })
        assertEquals(px.toList(), PixelArt.apply(px, 5, 5, "noir").toList())
        assertEquals("sketch", PixelArt.style(null)); assertEquals("comic", PixelArt.style("comic")); assertEquals("sketch", PixelArt.style("x"))
    }
    @Test fun voicesAndWavFiles() {
        assertEquals(1.5, TextTidy.voiceRate("chipmunk"), 0.0); assertEquals(0.75, TextTidy.voiceRate("deep"), 0.0); assertEquals(1.5, TextTidy.voiceRate(null), 0.0)
        val head = TextTidy.wavHeader(44100, 1, 1000)
        assertEquals(44, head.size); assertEquals("RIFF", String(head, 0, 4)); assertEquals("WAVEfmt ", String(head, 8, 8)); assertEquals("data", String(head, 36, 4))
        fun int(at: Int) = (head[at].toInt() and 0xFF) or ((head[at + 1].toInt() and 0xFF) shl 8) or ((head[at + 2].toInt() and 0xFF) shl 16) or ((head[at + 3].toInt() and 0xFF) shl 24)
        assertEquals(1036, int(4)); assertEquals(44100, int(24)); assertEquals(88200, int(28)); assertEquals(1000, int(40))
        assertEquals(Kind.AUDIO, Block.VOICE_CHANGE.takes); assertEquals(Kind.AUDIO, Block.VOICE_CHANGE.gives)
        assertNull(chain(Block.VIDEO_AUDIO, Block.VOICE_CHANGE).problem(Kind.VIDEO)); assertNull(chain(Block.VOICE_CHANGE, Block.SPEECH_TEXT).problem(Kind.AUDIO))
    }
    @Test fun onlyAToolLinkIsReadAsATool() {
        // (Making a link uses org.json, which plain unit tests can't run; the iOS twin covers the round trip.)
        assertNull(ToolLink.chain("https://example.com/t.html#abc")); assertNull(ToolLink.chain("")); assertNull(ToolLink.chain("tenzy://run/abc"))
        assertNull(ToolLink.chain(ToolLink.PAGE + "#***")); assertFalse(ToolLink.LIVE)
    }
    @Test fun describeItUnderstandsTheNewestRequests() {
        assertEquals("sketch", ChainPlanner.plan("pencil sketch of my photo")?.steps?.first()?.settings?.get("style"))
        assertEquals("comic", ChainPlanner.plan("turn me into a cartoon")?.steps?.first()?.settings?.get("style"))
        assertEquals("pop", ChainPlanner.plan("pop art selfie")?.steps?.first()?.settings?.get("style"))
        assertEquals("noir", ChainPlanner.plan("make it black and white")?.steps?.first()?.settings?.get("style"))
        assertEquals(listOf(Block.VOICE_CHANGE), planned("chipmunk voice")); assertEquals("deep", ChainPlanner.plan("give me a deep voice")?.steps?.first()?.settings?.get("voice"))
        assertEquals(listOf(Block.VIDEO_AUDIO, Block.VOICE_CHANGE), planned("funny voice from my video"))
        assertEquals(true, ChainPlanner.plan("before and after photo of my kitchen")?.versus); assertEquals(false, ChainPlanner.plan("shrink a photo")?.versus)
        assertTrue(ChainTemplates.all.first { it.id == "before-after" }.versus)
        assertEquals(listOf(Block.PRICE_COMPARE), planned("which is the cheapest per unit").takeLast(1))
    }
}
