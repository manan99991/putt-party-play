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
