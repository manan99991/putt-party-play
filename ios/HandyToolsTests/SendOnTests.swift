import XCTest
@testable import HandyTools

final class SendOnTests: XCTestCase {
    private func place(_ id: String) -> SendOn.Place { SendOn.places.first { $0.id == id }! }

    func testStatusSplitsALongClipIntoEvenPiecesInOrder() {
        let p = SendOn.plan(duration: 75, bytes: 40_000_000, place: place("wastatus"))
        XCTAssertEqual(p.pieces.count, 3, "75 s → three 25 s pieces")
        XCTAssertEqual(p.pieces.first?.lowerBound, 0); XCTAssertEqual(p.pieces.last?.upperBound ?? 0, 75, accuracy: 0.01)
        XCTAssertTrue(p.pieces.allSatisfy { $0.upperBound - $0.lowerBound <= 30 }, "every piece fits a status")
        XCTAssertNil(p.targetBytes, "about 13 MB a piece is already under 16 MB — no shrinking, original quality")
        XCTAssertEqual(SendOn.plan(duration: 75, bytes: 90_000_000, place: place("wastatus")).targetBytes, 15_200_000, "30 MB pieces are shrunk under 16 MB")
    }

    func testAReelKeepsTheFirst90SecondsAndSaysSo() {
        let p = SendOn.plan(duration: 200, bytes: 100_000_000, place: place("igreel"))
        XCTAssertEqual(p.pieces, [0...90])
        XCTAssertNil(p.targetBytes, "Instagram has no file limit to shrink for")
        XCTAssertTrue(p.lines.contains { $0.contains("first") })
    }

    func testEmailShrinksOnlyWhenItHasTo() {
        XCTAssertEqual(SendOn.plan(duration: 30, bytes: 50_000_000, place: place("email")).targetBytes, 19_000_000)
        XCTAssertNil(SendOn.plan(duration: 30, bytes: 8_000_000, place: place("email")).targetBytes, "already small enough — original quality kept")
    }

    func testNoMoreThanEightPlacesAndEachHasALimit() {
        XCTAssertLessThanOrEqual(SendOn.places.count, 8)
        XCTAssertTrue(SendOn.places.allSatisfy { $0.maxBytes != nil || $0.maxSeconds != nil })
    }
}
