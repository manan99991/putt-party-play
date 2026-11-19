import XCTest
@testable import HandyTools

final class SignSpotsTests: XCTestCase {
    private func l(_ t: String, _ x: CGFloat, _ y: CGFloat, w: CGFloat) -> DocEngine.OCRLine { DocEngine.OCRLine(text: t, box: CGRect(x: x, y: y, width: w, height: 0.02)) }

    func testSignatureAndDateLinesAreFoundAndTheSpotIsAfterTheLabel() {
        let spots = SignSpots.find(lines: [l("Tenant name: Jane Doe", 0.08, 0.70, w: 0.35), l("Signature:", 0.08, 0.80, w: 0.12), l("Date:", 0.62, 0.80, w: 0.06),
                                           l("Please return by Friday", 0.08, 0.9, w: 0.3)])
        let sig = spots.first { $0.kind == .signature }, date = spots.first { $0.kind == .date }
        XCTAssertNotNil(sig); XCTAssertNotNil(date)
        XCTAssertGreaterThan(sig!.center.x, 0.2, "after the label, not on top of it")
        XCTAssertEqual(sig!.center.y, 0.81, accuracy: 0.02)
        XCTAssertGreaterThan(date!.center.x, 0.68)
        XCTAssertEqual(spots.count, 2, "other lines ignored")
    }

    func testALabelUnderALineIsSignedAbove() {
        let s = SignSpots.find(lines: [l("Signature of applicant", 0.62, 0.85, w: 0.33)])
        XCTAssertEqual(s.count, 1); XCTAssertLessThan(s[0].center.y, 0.85, "written on the line above the label")
    }
}
