import XCTest
@testable import HandyTools

/// "What is this?" on writing: the kind is named the way a person would, from the words and their layout.
final class PaperTests: XCTestCase {
    private func lines(_ rows: [(String, CGFloat, CGFloat)]) -> [DocEngine.OCRLine] {
        rows.map { DocEngine.OCRLine(text: $0.0, box: CGRect(x: $0.1, y: $0.2, width: 0.08, height: 0.025)) }
    }

    func testWhiteboardRotaIsAWeeklyScheduleWithItsPeople() throws {
        var r: [(String, CGFloat, CGFloat)] = [("NAME", 0.05, 0.10)]
        let days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        for (i, d) in days.enumerated() { r.append((d, 0.2 + CGFloat(i) * 0.1, 0.10)) }
        let names = ["ANGIE ALSTON", "AL CANTOR", "ADAM CARRAWAY", "LUIS CASTELLANO", "KEN DARLINGTON", "JIM DOWLING", "JANET DUSSELDORF"]
        for (i, n) in names.enumerated() {
            let y = 0.2 + CGFloat(i) * 0.05
            r.append((n, 0.02, y))
            r.append((i == 2 ? "Vacation" : "Shifter Line", 0.2, y))
        }
        let p = try XCTUnwrap(Paper.classify(lines(r)))
        XCTAssertEqual(p.kind, .schedule)
        XCTAssertTrue(p.gist.hasPrefix("7 people, Mon – Sun"), p.gist)
        XCTAssertTrue(p.gist.contains("Shifter Line"), p.gist)
        XCTAssertTrue(p.gist.contains("Away: Adam Carraway"), p.gist)
    }

    func testReceiptIsNamedWithShopAndTotal() throws {
        let text = ["TESCO EXPRESS", "12/03/2026", "MILK 2L 1.45", "BREAD 1.10", "EGGS 6 2.30", "BANANAS 0.95", "SUBTOTAL 5.80", "TOTAL 5.80", "VISA 5.80", "THANK YOU"]
        let p = try XCTUnwrap(Paper.classify(lines(text.enumerated().map { ($0.element, 0.1, 0.05 + CGFloat($0.offset) * 0.06) })))
        XCTAssertEqual(p.kind, .receipt)
        XCTAssertTrue(p.gist.contains("5.80"), p.gist)
    }

    func testAMugWithAWordIsNotPaper() {
        XCTAssertNil(Paper.classify(lines([("STARBUCKS", 0.3, 0.4), ("COFFEE", 0.3, 0.5)])))
    }

    func testResultTextRoundTrips() throws {
        let r = Paper.Read(kind: .menu, name: "A menu", gist: "12 dishes", text: "Soup 4.50\n---\nTea 2.00")
        XCTAssertEqual(Paper.decode(Paper.encode(r)), r)
        XCTAssertNil(Paper.decode("Most likely: Lamp — 40%"))
    }
}

/// Scan: a photo of a page is flattened to the page only when a page clearly sits inside the photo.
final class PageFlattenTests: XCTestCase {
    func testOnlyARealPageInsideThePhotoIsCropped() {
        // A sheet covering the middle of a desk photo: crop to it.
        XCTAssertNotNil(PageFlatten.accept(CGPoint(x: 0.15, y: 0.9), CGPoint(x: 0.85, y: 0.92), CGPoint(x: 0.12, y: 0.08), CGPoint(x: 0.88, y: 0.1)))
        // Already the whole frame (a scanner page): leave it.
        XCTAssertNil(PageFlatten.accept(CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0)))
        // A small label in the corner is not the page.
        XCTAssertNil(PageFlatten.accept(CGPoint(x: 0.1, y: 0.3), CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.3, y: 0.1)))
    }

    func testAPhotographedPageComesOutFlatAndWhite() throws {
        // A white sheet with lines of "text", photographed on a dark wooden desk, slightly askew.
        let size = CGSize(width: 1200, height: 1600)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let photo = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let page = UIBezierPath(); page.move(to: CGPoint(x: 220, y: 180)); page.addLine(to: CGPoint(x: 1010, y: 230))
            page.addLine(to: CGPoint(x: 960, y: 1420)); page.addLine(to: CGPoint(x: 180, y: 1380)); page.close()
            UIColor(white: 0.82, alpha: 1).setFill(); page.fill()
            UIColor(white: 0.3, alpha: 1).setFill()
            for i in 0..<18 { ctx.fill(CGRect(x: 300, y: 320 + i * 55, width: 520, height: 14)) }
        }
        let r = PageFlatten.scan(photo)
        XCTAssertTrue(r.whitened)
        if r.flattened {
            // The desk is gone: the corners of the result are paper, not wood.
            let cg = try XCTUnwrap(r.image.cgImage)
            let w = CGFloat(cg.width), h = CGFloat(cg.height)
            let v = ToolOutputQualityTests.pixels(cg, at: [CGPoint(x: 12, y: 12), CGPoint(x: w - 12, y: 12), CGPoint(x: 12, y: h - 12), CGPoint(x: w - 12, y: h - 12)])
            let corner = v.reduce(0, +) / Double(max(1, v.count)) / 255
            XCTAssertGreaterThan(corner, 0.6, "corner brightness \(corner)")
        }
    }
}

/// The shared way in for audio: names people can read, voice notes recognised even without a file ending.
final class AudioIntakeTests: XCTestCase {
    func testDoubleEncodedNamesAreMadeReadable() {
        XCTAssertEqual(AudioIntake.cleanName("DON%25E2%2580%2599T"), "DON’T")
        XCTAssertEqual(AudioIntake.cleanName("Kya%2520Meri%2520Life"), "Kya Meri Life")
        XCTAssertEqual(AudioIntake.cleanName("Voice_memo_12"), "Voice memo 12")
    }
    func testAVoiceNoteIsSpottedByItsBytesNotItsName() throws {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("note-\(UUID().uuidString).m4a")
        try (Data("OggS".utf8) + Data(repeating: 0, count: 60)).write(to: u)
        XCTAssertTrue(AudioIntake.isOggOpus(u))
        let v = FileManager.default.temporaryDirectory.appendingPathComponent("song-\(UUID().uuidString).m4a")
        try Data(repeating: 1, count: 60).write(to: v)
        XCTAssertFalse(AudioIntake.isOggOpus(v))
    }
}

extension AudioIntakeTests {
    /// Your "DON'T GIVE UP" .mp3 was a 34-byte failed download: {"message":"Attachment not found"}.
    func testAFailedDownloadSavedAsMp3IsCalledWhatItIs() throws {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("song-\(UUID().uuidString).mp3")
        try Data(#"{"message":"Attachment not found"}"#.utf8).write(to: u)
        XCTAssertEqual(AudioIntake.textInstead(u), #"{"message":"Attachment not found"}"#)
        let real = FileManager.default.temporaryDirectory.appendingPathComponent("real-\(UUID().uuidString).mp3")
        try (Data([0x49, 0x44, 0x33, 0x04, 0, 0]) + Data(repeating: 0xFF, count: 200)).write(to: real)
        XCTAssertNil(AudioIntake.textInstead(real))
    }
}
