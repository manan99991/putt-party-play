import XCTest
import AVFoundation
@testable import HandyTools

/// Every bug Manan found in the 15 Nov full-app review, pinned as a permanent regression test. Each of
/// these failed in a real build; if any starts passing-the-wrong-way again, this fails the CI build
/// before it can ship. Pure-logic checks (no camera/network/device), so they run off-device in CI.
final class ReviewRegressionTests: XCTestCase {

    // MARK: - Scam checker (false negative AND false positives found in review)

    /// The Amazon "hiring team / $200–500 a day / text a keyword to a 10-digit number" message read
    /// "low-risk", then only "Suspicious". It is a textbook job scam and must read "Likely a scam".
    func testAmazonJobScamIsLikelyScam() {
        let msg = """
        Hi! The Amazon hiring team is currently offering a part-time online position. Candidates in this
        role will assist Amazon sellers with straightforward product optimization activities while working
        remotely.
        • 60–90 minutes per day
        • 4 days per week
        • $200–$500 daily pay
        • $8,000 base monthly income
        • Training provided
        • 20 positions currently available
        For applicants aged 20+, text "Job Details" to 5415132474.
        """
        let r = ScamAnalyzer.analyze(msg)
        XCTAssertEqual(r.verdict, .likelyScam, "a blatant job scam must be flagged, not read as low-risk")
    }

    /// A genuine travel itinerary has prices and "per day" but no hiring phrase — it must NOT trip the
    /// job-scam heuristic (the itinerary false positive that forced the matcher to be tightened).
    func testTravelItineraryIsNotAScam() {
        let msg = """
        Day 1 — New York: ferry to the Statue of Liberty, then the museum. Hotel is $180 a night and
        dinner runs about $120 per day for two. Check in at the hotel by 3 PM; 20 positions by the window.
        """
        let r = ScamAnalyzer.analyze(msg)
        XCTAssertNotEqual(r.verdict, .likelyScam, "an itinerary with prices + 'per day' must not be called a scam")
    }

    /// fonts.googleapis.com is a real Google domain. It must never be flagged as a "google look-alike".
    func testLegitGoogleSubdomainIsNotALookAlike() {
        let r = ScamAnalyzer.analyze("Fonts load from https://fonts.googleapis.com/css2?family=Inter here.")
        let issues = r.links.flatMap(\.issues).joined(separator: " ").lowercased()
        XCTAssertFalse(issues.contains("look-alike"), "a legitimate Google subdomain must not be a look-alike")
    }

    /// Bare code-like tokens (e.g. a JS access "d.id") get an http scheme INFERRED by NSDataDetector.
    /// We must not report "Not encrypted" for a link the writer never actually wrote as http://.
    func testInferredSchemeIsNotReportedAsUnencrypted() {
        let r = ScamAnalyzer.analyze("In the code, sec.id and d.id and b.id are element accessors.")
        let issues = r.links.flatMap(\.issues).joined(separator: " ").lowercased()
        XCTAssertFalse(issues.contains("not encrypted"), "a bare token with an inferred scheme is not an unencrypted link")
    }

    /// Guard the other direction: a real gift-card/urgency scam must still be caught (we didn't dull it).
    func testRealGiftCardScamStillCaught() {
        let r = ScamAnalyzer.analyze("URGENT: your account is suspended. Pay a $500 fee with Apple gift cards immediately or face legal action.")
        XCTAssertEqual(r.verdict, .likelyScam, "a gift-card + urgency + threat scam must still be flagged")
    }

    // MARK: - Builder chooser dumped raw markup as "Some text"

    /// Picking an HTML file showed the literal "<!doctype html>…". We strip markup to readable words so
    /// the preview AND the tool get text, not tags/CSS/JS.
    func testHtmlFileIsStrippedToReadableText() {
        let html = "<!doctype html><html><head><title>T</title><style>body{color:red}</style></head>"
            + "<body><h1>Hello</h1><script>var x = 1;</script><p>World</p></body></html>"
        let out = Given.readable(html, ext: "html")
        XCTAssertTrue(out.contains("Hello") && out.contains("World"), "visible text must survive")
        XCTAssertFalse(out.contains("<"), "no tags may remain")
        XCTAssertFalse(out.lowercased().contains("color:red"), "style blocks must be dropped")
        XCTAssertFalse(out.contains("var x"), "script blocks must be dropped")
    }

    func testPlainTextPassesThroughUnchanged() {
        XCTAssertEqual(Given.readable("Just some words.", ext: "txt"), "Just some words.")
    }

    // MARK: - ZIP / unsupported file gives an honest, specific next step (not a vague dead-end)

    func testZipArchiveGetsASpecificMessage() {
        let note = Given.unsupportedNote(for: URL(fileURLWithPath: "/tmp/photos.zip"))
        XCTAssertTrue(note.contains("ZIP"), "a zip must be named as an archive")
        XCTAssertTrue(note.lowercased().contains("inside"), "the message must point at the files inside, the real next step")
    }

    func testUnknownFileStillGetsTheGenericMessage() {
        let note = Given.unsupportedNote(for: URL(fileURLWithPath: "/tmp/drawing.dwg"))
        XCTAssertFalse(note.contains("archive"), "a non-archive must not be mislabelled an archive")
    }

    // MARK: - Real coverage for rich documents (Word/RTF/OpenDocument) — read, not dead-ended

    // MARK: - Link/phone/page tools aren't offered for text that has no link or number (#283)

    func testLinkToolsNotOfferedForPlainText() {
        let plain = ChainStore.offers(for: .text, mine: [], last: nil, text: "Remember to review the launch checklist before noon.")
        XCTAssertFalse(plain.contains { $0.steps.first?.block == .cleanLinks }, "a link cleaner must not be offered for text with no link")
        XCTAssertFalse(plain.contains { $0.steps.first?.block == .chatLink }, "a WhatsApp-a-number tool must not be offered for text with no number")
        XCTAssertFalse(plain.contains { $0.steps.first?.block == .pageText }, "a read-the-page tool must not be offered for text with no URL")
    }

    func testLinkToolIsOfferedWhenTextHasALink() {
        let withLink = ChainStore.offers(for: .text, mine: [], last: nil, text: "Deal here https://shop.example.com/item?utm_source=x")
        XCTAssertTrue(withLink.contains { $0.steps.first?.block == .cleanLinks }, "the link cleaner must be offered when the text has a link")
    }

    func testOrdinaryTextToolsStillOfferedForPlainText() {
        let plain = ChainStore.offers(for: .text, mine: [], last: nil, text: "Remember to review the launch checklist before noon.")
        XCTAssertTrue(plain.contains { $0.steps.first?.block == .summarize || $0.steps.first?.block == .cleanText }, "normal text tools stay offered")
    }

    // MARK: - Read Aloud speed option (#278 per-tool options)

    func testReadAloudSpeedMapsToRate() {
        XCTAssertEqual(ChainMedia.ttsRate("normal"), AVSpeechUtteranceDefaultSpeechRate, accuracy: 0.001)
        XCTAssertEqual(ChainMedia.ttsRate(nil), AVSpeechUtteranceDefaultSpeechRate, accuracy: 0.001)
        XCTAssertLessThan(ChainMedia.ttsRate("slow"), AVSpeechUtteranceDefaultSpeechRate)
        XCTAssertGreaterThan(ChainMedia.ttsRate("fast"), AVSpeechUtteranceDefaultSpeechRate)
    }

    func testQrSturdinessMapsToCorrectionLevel() {
        XCTAssertEqual(ChainText.qrCorrection("high"), "H")
        XCTAssertEqual(ChainText.qrCorrection("normal"), "M")
        XCTAssertEqual(ChainText.qrCorrection(nil), "M")
    }

    // Tidy-text "Keep lines" vs "One paragraph" option (#278). Default keeps the writer's line breaks;
    // paragraph mode reflows wrapped lines into flowing paragraphs (the pasted-from-PDF case).
    func testCleanTextKeepsLinesByDefault() {
        let out = TextTidy.clean("First line\nSecond line")
        XCTAssertEqual(out, "First line\nSecond line", "the default must keep the line breaks")
        XCTAssertFalse(TextTidy.reflowsToParagraph(nil), "no setting means keep lines")
        XCTAssertFalse(TextTidy.reflowsToParagraph("lines"), "'lines' means keep lines")
        XCTAssertTrue(TextTidy.reflowsToParagraph("paragraph"), "'paragraph' means reflow")
    }

    func testCleanTextParagraphReflowsWrappedLines() {
        // Two wrapped lines, a blank gap, then another paragraph — becomes two space-joined paragraphs.
        let out = TextTidy.clean("The quick brown\nfox jumps over\n\nthe lazy dog\nand runs away", oneParagraph: true)
        XCTAssertEqual(out, "The quick brown fox jumps over\n\nthe lazy dog and runs away")
        XCTAssertFalse(out.contains("brown\nfox"), "wrapped lines inside a paragraph must join with a space")
    }

    func testSummaryFormatBulletsVsParagraph() {
        let s = ["First point.", "Second point."]
        XCTAssertEqual(ChainText.summaryText(s, bullets: false), "First point. Second point.")
        let b = ChainText.summaryText(s, bullets: true)
        XCTAssertTrue(b.contains("• First point."), "bullets mode prefixes each sentence")
        XCTAssertTrue(b.contains("\n• Second point."), "each bullet is on its own line")
    }

    func testRichDocumentReadsItsWords() {
        let rtf = "{\\rtf1\\ansi\\ansicpg1252 Hello from a rich document.}"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("review-\(UUID().uuidString).rtf")
        try? rtf.data(using: .utf8)?.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let words = Given.richDocumentText(url, ext: "rtf")
        XCTAssertNotNil(words, "a rich document must open into real text, not nil")
        XCTAssertTrue(words?.contains("Hello from a rich document") == true, "the document's words must survive")
    }

    // Excel .xlsx coverage (#294): a worksheet's rows read into tab/newline text, with text cells resolved
    // through the shared-strings table — so a picked spreadsheet opens into real rows, not a dead-end.
    func testXlsxSheetReadsItsCells() {
        let sst = "<sst><si><t>Name</t></si><si><t>Widget</t></si></sst>"
        let sheet = "<worksheet><sheetData>"
            + "<row><c r=\"A1\" t=\"s\"><v>0</v></c><c r=\"B1\"><v>10</v></c></row>"
            + "<row><c r=\"A2\" t=\"s\"><v>1</v></c><c r=\"B2\"><v>25</v></c></row>"
            + "</sheetData></worksheet>"
        XCTAssertEqual(Given.sheetText(sharedStrings: sst, sheet: sheet), "Name\t10\nWidget\t25")
    }

    func testXlsxInlineStringAndEntitiesDecode() {
        let sheet = "<sheetData><row><c t=\"inlineStr\"><is><t>A &amp; B</t></is></c><c><v>3</v></c></row></sheetData>"
        XCTAssertEqual(Given.sheetText(sharedStrings: nil, sheet: sheet), "A & B\t3")
    }

    // Thinking tools "Act on it" spine (#285): a task line is read into the built-in apps it belongs to.
    // Kept in lockstep with the Android twin so both platforms route the same task the same way.
    func testThinkingActionsRoutesTasksToTheRightApps() {
        let dated = ThinkingActions.plan(for: "Email Ana the budget by Thursday")
        XCTAssertEqual(dated.kinds, [.calendar, .reminder], "a deadline → Calendar + a reminder, nothing else")
        XCTAssertTrue(dated.isDated)

        let call = ThinkingActions.plan(for: "Call the dentist")
        XCTAssertEqual(call.kinds, [.reminder, .call], "a call cue with no number → reminder + call")
        XCTAssertTrue(call.isCall); XCTAssertNil(call.phone)

        let errand = ThinkingActions.plan(for: "Pick up Deeyan from Oak Street Clinic at 3pm")
        XCTAssertEqual(errand.kinds, [.calendar, .reminder, .maps], "a timed task with a place → Calendar + reminder + Maps")
        XCTAssertEqual(errand.place, "Oak Street Clinic")

        let plain = ThinkingActions.plan(for: "Buy milk")
        XCTAssertEqual(plain.kinds, [.reminder], "a plain task never dead-ends — it is at least a reminder")

        let withNumber = ThinkingActions.plan(for: "call 555-123-4567")
        XCTAssertEqual(withNumber.phone, "555-123-4567", "a real number is pulled out for a one-tap dial")
        XCTAssertTrue(withNumber.kinds.contains(.call))
    }

    // Due-date parser (#285): a task → the concrete moment to set the calendar event / reminder for.
    // Pinned to Mon 16 Nov 2026 08:00 UTC so it is deterministic; kept in lockstep with the Android twin.
    func testDueDateParser() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 8, minute: 0))!   // a Monday
        func f(_ s: String, _ c: Calendar.Component) -> Int? {
            ThinkingActions.dueDate(from: s, now: now, calendar: cal).map { cal.component(c, from: $0) }
        }
        XCTAssertEqual(f("Email Ana by Thursday", .day), 19); XCTAssertEqual(f("Email Ana by Thursday", .hour), 9)
        XCTAssertEqual(f("Call dentist at 2pm", .day), 16);   XCTAssertEqual(f("Call dentist at 2pm", .hour), 14)
        XCTAssertEqual(f("Groceries tomorrow", .day), 17)
        XCTAssertEqual(f("Finish deck tonight", .hour), 20)
        XCTAssertEqual(f("Pay rent in 3 days", .day), 19)
        XCTAssertNil(ThinkingActions.dueDate(from: "Buy milk", now: now, calendar: cal), "no date → no due time")
        XCTAssertEqual(ThinkingActions.telURL("555-123-4567"), "tel:5551234567")
        XCTAssertNil(ThinkingActions.telURL("call me"))
    }

    // Clear My Head / My Day structuring engine (#285): a brain-dump → deduped, routed, time-ordered tasks.
    // Needs no language model, so it runs the same on both platforms (kept in lockstep with the Android twin).
    func testThinkingEngineStructuresADump() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 8, minute: 0))!

        let cleared = ThinkingEngine.clearMyHead("call vendor, buy milk, finish deck, email Ana by Thursday, buy milk", now: now, calendar: cal)
        XCTAssertEqual(cleared.count, 4, "exact duplicates are merged")
        let ana = cleared.first { $0.text.contains("Ana") }!
        XCTAssertNotNil(ana.due, "a dated task gets a concrete due time")
        XCTAssertTrue(ana.actions.kinds.contains(.calendar), "and routes to the calendar")

        let day = ThinkingEngine.myDay("groceries tomorrow, call dentist at 2pm, buy milk", now: now, calendar: cal)
        XCTAssertTrue(day.first!.text.contains("dentist"), "the earliest timed task leads the day")
        XCTAssertTrue(day.last!.text.contains("milk"), "untimed tasks fall to the end")
    }

    // Action payloads (#285): a dated task → a valid .ics event; a place → a Maps URL.
    func testThinkingActionPayloads() {
        let ics = ThinkingActions.icsEvent(title: "Email Ana", due: Date(timeIntervalSince1970: 1_800_000_000), place: "Office")
        XCTAssertTrue(ics.contains("BEGIN:VEVENT"))
        XCTAssertTrue(ics.contains("SUMMARY:Email Ana"))
        XCTAssertTrue(ics.contains("DTSTART:"))
        XCTAssertTrue(ics.contains("LOCATION:Office"))
        let maps = ThinkingActions.mapsURL("Oak Street Clinic")
        XCTAssertNotNil(maps); XCTAssertTrue(maps?.contains("maps.apple.com") == true)
    }

    // MARK: - QR long-press preview classification

    func testQRWifiParsed() {
        let c = QRPreviewContent.parse("WIFI:T:WPA;S:HomeNet;P:secret123;;")
        XCTAssertEqual(c.kind, .wifi)
        XCTAssertEqual(c.detail, "HomeNet")
        XCTAssertTrue(c.extra.contains { $0.contains("secret123") }, "password should surface in the preview")
    }

    func testQRLinkParsedAndOpenable() {
        let c = QRPreviewContent.parse("https://example.com/path")
        XCTAssertEqual(c.kind, .link)
        XCTAssertNotNil(c.url, "a real link must be openable")
    }

    func testQRContactParsed() {
        let c = QRPreviewContent.parse("BEGIN:VCARD\nVERSION:3.0\nFN:Jane Doe\nTEL:+15551234567\nEND:VCARD")
        XCTAssertEqual(c.kind, .contact)
        XCTAssertEqual(c.detail, "Jane Doe")
    }

    func testQRPhoneParsed() {
        XCTAssertEqual(QRPreviewContent.parse("tel:+15551234567").kind, .phone)
    }

    /// Plain text must NOT be treated as an openable link (no accidental "open" of arbitrary text).
    func testQRPlainTextIsNotALink() {
        let c = QRPreviewContent.parse("just some notes to myself")
        XCTAssertEqual(c.kind, .text)
        XCTAssertNil(c.url, "plain text must not be openable as a URL")
    }
}
