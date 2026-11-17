package com.handytools.app.tools.shield

import com.handytools.app.tools.builder.Block
import com.handytools.app.tools.builder.Chain
import com.handytools.app.tools.builder.ChainOffers
import com.handytools.app.tools.builder.Step
import com.handytools.app.tools.builder.ThinkingActions
import com.handytools.app.tools.builder.ThinkingActions.Kind
import com.handytools.app.tools.power.CodesEngine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Android mirror of the iOS ReviewRegressionTests — the scam-checker bugs Manan found in the 15 Nov
 * full-app review, pinned so a future change can't quietly bring them back. Pure JVM logic (no device),
 * so these run in the free `testDebugUnitTest` gate.
 */
class ReviewRegressionTest {

    // The Amazon "hiring team / $200-500 a day / text a keyword to a 10-digit number" message read
    // "low-risk", then only "Suspicious". It is a textbook job scam and must read "Likely a scam".
    @Test fun amazonJobScamIsLikelyScam() {
        val msg = """
            Hi! The Amazon hiring team is currently offering a part-time online position. Candidates in this
            role will assist Amazon sellers with straightforward product optimization activities while working
            remotely.
            • 60–90 minutes per day
            • 4 days per week
            • ${'$'}200–${'$'}500 daily pay
            • ${'$'}8,000 base monthly income
            • Training provided
            • 20 positions currently available
            For applicants aged 20+, text "Job Details" to 5415132474.
        """.trimIndent()
        assertEquals(
            "a blatant job scam must be flagged, not read as low-risk",
            ScamAnalyzer.Verdict.LIKELY_SCAM, ScamAnalyzer.analyze(msg).verdict,
        )
    }

    // A genuine travel itinerary has prices and "per day" but no hiring phrase — it must NOT trip the
    // job-scam heuristic (the itinerary false positive that forced the matcher to be tightened).
    @Test fun travelItineraryIsNotAScam() {
        val msg = """
            Day 1 — New York: ferry to the Statue of Liberty, then the museum. Hotel is ${'$'}180 a night and
            dinner runs about ${'$'}120 per day for two. Check in at the hotel by 3 PM; 20 positions by the window.
        """.trimIndent()
        assertNotEquals(
            "an itinerary with prices + 'per day' must not be called a scam",
            ScamAnalyzer.Verdict.LIKELY_SCAM, ScamAnalyzer.analyze(msg).verdict,
        )
    }

    // fonts.googleapis.com is a real Google domain. It must never be flagged as a "google look-alike".
    @Test fun legitGoogleSubdomainIsNotALookAlike() {
        val r = ScamAnalyzer.analyze("Fonts load from https://fonts.googleapis.com/css2?family=Inter here.")
        val issues = r.links.flatMap { it.issues }.joinToString(" ").lowercase()
        assertFalse("a legitimate Google subdomain must not be a look-alike", issues.contains("look-alike"))
    }

    // A bare code-like token (a JS access "d.id") can read like a domain; we must not call it an
    // unencrypted link — the writer never typed "http://".
    @Test fun inferredSchemeIsNotReportedAsUnencrypted() {
        val r = ScamAnalyzer.analyze("In the code, sec.id and d.id and b.id are element accessors.")
        val issues = r.links.flatMap { it.issues }.joinToString(" ").lowercase()
        assertFalse("a bare token with an inferred scheme is not an unencrypted link", issues.contains("not encrypted"))
    }

    // A real apple look-alike sender domain must STILL be caught (we didn't dull the check).
    @Test fun realLookAlikeStillCaught() {
        val r = ScamAnalyzer.analyze("Sign in at https://apple-support.account-verify.com/login to keep your account.")
        val issues = r.links.flatMap { it.issues }.joinToString(" ").lowercase()
        assertTrueMsg("a genuine brand look-alike must still be flagged", issues.contains("look-alike"))
    }

    // Guard the other direction: a real gift-card/urgency scam must still be caught.
    @Test fun realGiftCardScamStillCaught() {
        val r = ScamAnalyzer.analyze("URGENT: your account is suspended. Pay a ${'$'}500 fee with Apple gift cards immediately or face legal action.")
        assertEquals(
            "a gift-card + urgency + threat scam must still be flagged",
            ScamAnalyzer.Verdict.LIKELY_SCAM, r.verdict,
        )
    }

    // QR content classification parity with the iOS QRPreviewContent cases.
    @Test fun qrWifiClassified() =
        assertEquals(CodesEngine.Kind.WIFI, CodesEngine.classify("WIFI:T:WPA;S:HomeNet;P:secret123;;", true).kind)

    @Test fun qrContactClassified() =
        assertEquals(CodesEngine.Kind.CONTACT, CodesEngine.classify("BEGIN:VCARD\nVERSION:3.0\nFN:Jane Doe\nTEL:+15551234567\nEND:VCARD", true).kind)

    @Test fun qrPhoneClassified() =
        assertEquals(CodesEngine.Kind.PHONE, CodesEngine.classify("tel:+15551234567", true).kind)

    @Test fun qrLinkClassified() =
        assertEquals(CodesEngine.Kind.URL, CodesEngine.classify("https://example.com/path", true).kind)

    @Test fun qrPlainTextIsNotALink() =
        assertEquals(CodesEngine.Kind.TEXT, CodesEngine.classify("just some notes to myself", true).kind)

    // A ZIP (or other archive) gets a specific, honest next step — not a vague "no tool for that file".
    @Test fun zipArchiveGetsASpecificMessage() {
        val note = com.handytools.app.tools.builder.unsupportedNote("application/zip", "photos.zip")
        assertTrueMsg("a zip must be named as an archive", note.contains("ZIP"))
        assertTrueMsg("the message must point at the files inside", note.lowercase().contains("inside"))
    }

    // PowerPoint .pptx coverage (#294), lockstep with the iOS twin.
    @Test fun pptxSlideReadsItsText() {
        val xml = "<a:p><a:r><a:t>Hello</a:t></a:r><a:r><a:t>World</a:t></a:r></a:p><a:p><a:r><a:t>Second &amp; line</a:t></a:r></a:p>"
        val out = com.handytools.app.tools.builder.BuilderInputs.slideText(xml)
        assertTrueMsg("runs on a paragraph join with a space", out.contains("Hello World"))
        assertTrueMsg("next paragraph survives, entity decoded", out.contains("Second & line"))
        assertFalse("no tags remain", out.contains("<"))
    }

    @Test fun unknownFileStillGetsTheGenericMessage() {
        val note = com.handytools.app.tools.builder.unsupportedNote("application/acad", "drawing.dwg")
        assertFalse("a non-archive must not be mislabelled an archive", note.contains("archive"))
    }

    // A Word/OpenDocument body XML is stripped to its real words (real file coverage, not a dead-end).
    @Test fun docBodyXmlStripsToReadableText() {
        val xml = "<w:document><w:body><w:p><w:r><w:t>Hello</w:t></w:r></w:p>" +
            "<w:p><w:r><w:t>World &amp; more</w:t></w:r></w:p></w:body></w:document>"
        val out = com.handytools.app.tools.builder.BuilderInputs.stripDocXml(xml)
        assertTrueMsg("first paragraph survives", out.contains("Hello"))
        assertTrueMsg("second paragraph survives, entity decoded", out.contains("World & more"))
        assertFalse("no XML tags remain", out.contains("<"))
    }

    // Excel .xlsx coverage (#294), parity with the iOS twin: a worksheet's rows read into tab/newline
    // text, text cells resolved through the shared-strings table.
    @Test fun xlsxSheetReadsItsCells() {
        val sst = "<sst><si><t>Name</t></si><si><t>Widget</t></si></sst>"
        val sheet = "<worksheet><sheetData>" +
            "<row><c r=\"A1\" t=\"s\"><v>0</v></c><c r=\"B1\"><v>10</v></c></row>" +
            "<row><c r=\"A2\" t=\"s\"><v>1</v></c><c r=\"B2\"><v>25</v></c></row>" +
            "</sheetData></worksheet>"
        assertEquals("Name\t10\nWidget\t25", com.handytools.app.tools.builder.BuilderInputs.sheetText(sst, sheet))
    }

    @Test fun xlsxInlineStringAndEntitiesDecode() {
        val sheet = "<sheetData><row><c t=\"inlineStr\"><is><t>A &amp; B</t></is></c><c><v>3</v></c></row></sheetData>"
        assertEquals("A & B\t3", com.handytools.app.tools.builder.BuilderInputs.sheetText(null, sheet))
    }

    // Thinking tools "Act on it" spine (#285), in lockstep with the iOS twin: a task line is read into
    // the built-in apps it belongs to.
    @Test fun thinkingActionsRoutesTasksToTheRightApps() {
        val plan = ThinkingActions::plan

        val dated = plan("Email Ana the budget by Thursday")
        assertEquals(listOf(Kind.CALENDAR, Kind.REMINDER), dated.kinds)
        assertTrueMsg("a deadline is dated", dated.isDated)

        val call = plan("Call the dentist")
        assertEquals(listOf(Kind.REMINDER, Kind.CALL), call.kinds)
        assertTrueMsg("call cue", call.isCall)

        val errand = plan("Pick up Deeyan from Oak Street Clinic at 3pm")
        assertEquals(listOf(Kind.CALENDAR, Kind.REMINDER, Kind.MAPS), errand.kinds)
        assertEquals("Oak Street Clinic", errand.place)

        assertEquals(listOf(Kind.REMINDER), plan("Buy milk").kinds)

        val withNumber = plan("call 555-123-4567")
        assertEquals("555-123-4567", withNumber.phone)
        assertTrueMsg("has call", withNumber.kinds.contains(Kind.CALL))
    }

    // Due-date parser (#285), lockstep with the iOS twin: pinned to Mon 16 Nov 2026 08:00 UTC.
    @Test fun dueDateParser() {
        val utc = java.util.TimeZone.getTimeZone("UTC")
        val now = java.util.Calendar.getInstance(utc).apply { clear(); set(2026, 10, 16, 8, 0, 0) }.timeInMillis // Nov = month 10
        val TA = com.handytools.app.tools.builder.ThinkingActions
        fun f(s: String, field: Int): Int? {
            val ms = TA.dueDateMs(s, now, utc) ?: return null
            return java.util.Calendar.getInstance(utc).apply { timeInMillis = ms }.get(field)
        }
        assertEquals(19, f("Email Ana by Thursday", java.util.Calendar.DAY_OF_MONTH))
        assertEquals(9, f("Email Ana by Thursday", java.util.Calendar.HOUR_OF_DAY))
        assertEquals(16, f("Call dentist at 2pm", java.util.Calendar.DAY_OF_MONTH))
        assertEquals(14, f("Call dentist at 2pm", java.util.Calendar.HOUR_OF_DAY))
        assertEquals(17, f("Groceries tomorrow", java.util.Calendar.DAY_OF_MONTH))
        assertEquals(20, f("Finish deck tonight", java.util.Calendar.HOUR_OF_DAY))
        assertEquals(19, f("Pay rent in 3 days", java.util.Calendar.DAY_OF_MONTH))
        assertNull("no date → no due time", TA.dueDateMs("Buy milk", now, utc))
        assertEquals("tel:5551234567", TA.telURL("555-123-4567"))
        assertNull(TA.telURL("call me"))
    }

    // Clear My Head / My Day structuring engine (#285), lockstep with the iOS twin.
    @Test fun thinkingEngineStructuresADump() {
        val utc = java.util.TimeZone.getTimeZone("UTC")
        val now = java.util.Calendar.getInstance(utc).apply { clear(); set(2026, 10, 16, 8, 0, 0) }.timeInMillis
        val TE = com.handytools.app.tools.builder.ThinkingEngine

        val cleared = TE.clearMyHead("call vendor, buy milk, finish deck, email Ana by Thursday, buy milk", now, utc)
        assertEquals(4, cleared.size)
        val ana = cleared.first { it.text.contains("Ana") }
        assertTrueMsg("a dated task gets a due time", ana.due != null)
        assertTrueMsg("and routes to the calendar", ana.actions.kinds.contains(Kind.CALENDAR))

        val day = TE.myDay("groceries tomorrow, call dentist at 2pm, buy milk", now, utc)
        assertTrueMsg("earliest timed task leads", day.first().text.contains("dentist"))
        assertTrueMsg("untimed tasks fall to the end", day.last().text.contains("milk"))
    }

    // Adaptive urgency (#285), parity with the iOS twin: deadline flagged, soft task nudged, fragment quiet.
    @Test fun thinkingUrgencyAdaptsToTheTask() {
        val utc = java.util.TimeZone.getTimeZone("UTC")
        val now = java.util.Calendar.getInstance(utc).apply { clear(); set(2026, 10, 16, 8, 0, 0) }.timeInMillis
        val TE = com.handytools.app.tools.builder.ThinkingEngine
        fun urg(line: String) = TE.urgency(TE.tasks(line, now, utc).first())
        assertEquals(com.handytools.app.tools.builder.ThinkingEngine.Urgency.DEADLINE, urg("pay rent Friday"))
        assertEquals(com.handytools.app.tools.builder.ThinkingEngine.Urgency.NUDGE, urg("call the dentist"))
        assertEquals(com.handytools.app.tools.builder.ThinkingEngine.Urgency.NUDGE, urg("email Sam"))
        assertEquals(com.handytools.app.tools.builder.ThinkingEngine.Urgency.QUIET, urg("milk"))
    }

    // Action payloads (#285): a dated task → a valid .ics event; a place → a Maps URL.
    @Test fun thinkingActionPayloads() {
        val ics = ThinkingActions.icsEvent("Email Ana", 1_800_000_000_000L, "Office")
        assertTrueMsg("has event", ics.contains("BEGIN:VEVENT"))
        assertTrueMsg("has summary", ics.contains("SUMMARY:Email Ana"))
        assertTrueMsg("has start", ics.contains("DTSTART:"))
        assertTrueMsg("has location", ics.contains("LOCATION:Office"))
        val maps = ThinkingActions.mapsURL("Oak Street Clinic")
        assertTrueMsg("geo url", maps != null && maps.startsWith("geo:0,0?q="))
        assertNull(ThinkingActions.mapsURL("   "))
    }

    // "Act on it" Add-to-Calendar bundle (#285), parity with the iOS twin.
    @Test fun thinkingActionsCalendarBundle() {
        val ics = ThinkingActions.icsCalendar(listOf(
            Triple("Email Ana", 1_800_000_000_000L, ""), Triple("Dentist", 1_800_100_000_000L, "Oak Street Clinic")))
        assertEquals(2, ics.split("BEGIN:VEVENT").size - 1)          // one event per dated task
        assertEquals(1, ics.split("BEGIN:VCALENDAR").size - 1)        // one calendar wrapper
        assertTrueMsg("both summaries", ics.contains("SUMMARY:Email Ana") && ics.contains("SUMMARY:Dentist"))
        assertTrueMsg("location", ics.contains("LOCATION:Oak Street Clinic"))
    }

    // Any common audio format a user might send must be recognised as audio, lockstep with the iOS twin.
    @Test fun commonAudioFormatsAreRecognised() {
        for (e in listOf("mp3", "m4a", "wav", "aac", "caf", "ogg", "flac", "aiff", "aif", "amr", "wma", "opus", "m4b", "MP3")) {
            assertTrueMsg("$e must be recognised as audio", com.handytools.app.tools.builder.TextTidy.isAudio(e))
        }
        assertFalse("pdf is not audio", com.handytools.app.tools.builder.TextTidy.isAudio("pdf"))
        assertFalse("jpg is not audio", com.handytools.app.tools.builder.TextTidy.isAudio("jpg"))
    }

    // A link/phone/page tool fits a piece of text only when the text actually has a link/number (#283).
    @Test fun linkToolFitsTextOnlyWhenTextHasLink() {
        val linkChain = Chain("x", "Clean link", listOf(Step(Block.CLEAN_LINKS)))
        assertFalse("link tool must not fit plain prose", ChainOffers.fitsText(linkChain, "Review the checklist before noon."))
        assertTrueMsg("link tool fits text with a link", ChainOffers.fitsText(linkChain, "See https://shop.example.com/i?utm_source=x"))
        val summarize = Chain("y", "Summary", listOf(Step(Block.SUMMARIZE, mapOf("sentences" to "3"))))
        assertTrueMsg("an ordinary text tool always fits", ChainOffers.fitsText(summarize, "Review the checklist before noon."))
    }

    // Read-it-aloud speed option maps to a TextToSpeech rate (#278 per-tool options).
    @Test fun readAloudSpeedMapsToRate() {
        assertEquals(1f, com.handytools.app.tools.builder.ExtraSteps.ttsRate("normal"), 0.001f)
        assertEquals(1f, com.handytools.app.tools.builder.ExtraSteps.ttsRate(null), 0.001f)
        assertTrueMsg("slow < normal", com.handytools.app.tools.builder.ExtraSteps.ttsRate("slow") < 1f)
        assertTrueMsg("fast > normal", com.handytools.app.tools.builder.ExtraSteps.ttsRate("fast") > 1f)
    }

    // Summarize paragraph-vs-bullets option (#278).
    @Test fun summaryFormatBulletsVsParagraph() {
        val s = listOf("First point.", "Second point.")
        assertEquals("First point. Second point.", com.handytools.app.tools.builder.TextTidy.summaryText(s, false))
        val b = com.handytools.app.tools.builder.TextTidy.summaryText(s, true)
        assertTrueMsg("bullets mode prefixes each sentence", b.contains("• First point."))
        assertTrueMsg("each bullet on its own line", b.contains("\n• Second point."))
    }

    // QR sturdiness option → error-correction level (#278).
    @Test fun qrSturdinessMapsToCorrectionLevel() {
        assertEquals("H", com.handytools.app.tools.builder.TextTidy.qrCorrection("high"))
        assertEquals("M", com.handytools.app.tools.builder.TextTidy.qrCorrection("normal"))
        assertEquals("M", com.handytools.app.tools.builder.TextTidy.qrCorrection(null))
    }

    // Tidy-text "Keep lines" vs "One paragraph" option (#278), parity with the iOS twin.
    @Test fun cleanTextKeepsLinesByDefault() {
        assertEquals(
            "the default must keep the line breaks",
            "First line\nSecond line",
            com.handytools.app.tools.builder.TextTidy.clean("First line\nSecond line"),
        )
        assertFalse("no setting means keep lines", com.handytools.app.tools.builder.TextTidy.reflowsToParagraph(null))
        assertFalse("'lines' means keep lines", com.handytools.app.tools.builder.TextTidy.reflowsToParagraph("lines"))
        assertTrueMsg("'paragraph' means reflow", com.handytools.app.tools.builder.TextTidy.reflowsToParagraph("paragraph"))
    }

    @Test fun cleanTextParagraphReflowsWrappedLines() {
        val out = com.handytools.app.tools.builder.TextTidy.clean(
            "The quick brown\nfox jumps over\n\nthe lazy dog\nand runs away", oneParagraph = true,
        )
        assertEquals("The quick brown fox jumps over\n\nthe lazy dog and runs away", out)
        assertFalse("wrapped lines inside a paragraph must join with a space", out.contains("brown\nfox"))
    }

    private fun assertTrueMsg(msg: String, cond: Boolean) = org.junit.Assert.assertTrue(msg, cond)
}
