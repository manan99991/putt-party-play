import XCTest
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

    // MARK: - No tool silently under-delivers (the whole-catalog free sweep)

    /// Every text/photo block is run on ONE rich, real fixture and must either deliver non-empty output
    /// OR fail gracefully with a named reason — never succeed with nothing. A silent under-deliver is a
    /// test failure, not just a code bug (Manan's standing rule). Runs free in CI, no device/network.
    func testNoBlockSilentlyUnderDelivers() async {
        let richText = "Dinner at Luigi's on 14 Nov 2026. Pizza 12.50, Wine 8.00, Tip 4.00. Total 24.50. "
            + "Menu: https://example.com/menu — call +1 312 555 0100 or email jane@acme.com. "
            + "Jane Doe, Designer at Acme Inc. Meet Monday 3pm at 1585 N Barrington Rd, Hoffman Estates, IL. "
            + "Reply STOP to opt out. A longer paragraph so summarize and rewrite have something to work with."
        let photo = SampleAssets.receipt()
        for block in Block.allCases {
            let input: ChainPayload
            switch block.takes {
            case .text: input = .text(richText)
            case .image, .photoFile: input = .image(photo)
            default: continue   // video/audio/pdf blocks need media files — covered by their own fixtures
            }
            let r = await ChainRunner.apply(ChainStep(block: block), to: input)
            if case .success(let payload) = r {
                XCTAssertFalse(Self.isEmpty(payload), "block '\(block.rawValue)' returned an EMPTY success — a silent under-deliver")
            }
            // a graceful .failure with a named reason is acceptable (e.g. a block that needs a QR image)
        }
    }

    private static func isEmpty(_ p: ChainPayload) -> Bool {
        switch p {
        case .text(let s): return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image(let i): return i.size.width < 1 || i.size.height < 1
        case .file(let d, _): return d.isEmpty
        case .video(let u): return ((try? Data(contentsOf: u))?.isEmpty ?? true)
        }
    }
}
