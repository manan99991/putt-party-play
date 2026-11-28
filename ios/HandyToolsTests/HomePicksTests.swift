import XCTest
@testable import HandyTools

/// Home's twelve (28 Nov): the starters on a first visit, then the tools this person really opens move in — never a
/// duplicate, never more or fewer than twelve, and every one opens something real.
@MainActor
final class HomePicksTests: XCTestCase {
    private func known(_ id: String) -> (title: String, icon: String, hex: UInt32)? {
        TOOLS.first { $0.id == id }.map { ($0.name, $0.icon, 0x3B82F6) }
    }

    func testFirstVisitShowsTheTwelveStarters() {
        let p = HomePicks.current(uses: [:], known: known)
        XCTAssertEqual(p.map(\.id), HomePicks.starters.map(\.id))
        XCTAssertEqual(p.count, 12)
    }

    func testEveryStarterOpensARealToolOrTheReminders() {
        for p in HomePicks.starters where p.id != "myreminders" {
            XCTAssertNotNil(TOOLS.first { $0.id == p.id }, "\(p.id) isn't a tool")
        }
        XCTAssertEqual(Set(HomePicks.starters.map(\.id)).count, 12, "a job is on Home twice")
    }

    func testAToolUsedOftenMovesInAndKeepsTheRestInPlace() {
        let uses = ["rest": 5, "scan": 9, "cleaner": 3, "contacts": 2, "myreminders": 4, "post": 6, "translate": 7,
                    "gpsdash": 8, "sticker": 2, "collage": 1, "pdfsign": 3, "fileviewer": 2, "vault": 2]
        let p = HomePicks.current(uses: uses, known: known)
        XCTAssertEqual(p.count, 12)
        XCTAssertTrue(p.contains { $0.id == "rest" }, "Sleep sounds, used 5 times, should be on Home")
        XCTAssertFalse(p.contains { $0.id == "collage" }, "the least-used starter (Collage, once) gives way")
        XCTAssertEqual(p.firstIndex { $0.id == "rest" }, HomePicks.starters.firstIndex { $0.id == "collage" }, "it takes that tile's place")
        XCTAssertEqual(p.first { $0.id == "rest" }?.title, "Sleep sounds")
        XCTAssertEqual(Set(p.map(\.id)).count, 12)
    }

    func testOneUseIsNotEnoughToMoveIn() {
        let p = HomePicks.current(uses: ["rest": 1], known: known)
        XCTAssertEqual(p.map(\.id), HomePicks.starters.map(\.id))
    }

    func testAToolUsedLessThanEveryStarterStaysOut() {
        var uses = Dictionary(uniqueKeysWithValues: HomePicks.starters.map { ($0.id, 10) })
        uses["rest"] = 4
        XCTAssertFalse(HomePicks.current(uses: uses, known: known).contains { $0.id == "rest" })
    }

    func testEveryNameFitsOneLine() {
        for t in HomePicks.starters.map(\.title) + Array(HomePicks.shortNames.values) {
            XCTAssertLessThanOrEqual(t.count, 13, "\"\(t)\" is too long for a quarter-width tile")
        }
    }
}
