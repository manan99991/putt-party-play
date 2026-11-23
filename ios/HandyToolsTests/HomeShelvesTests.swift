import XCTest
@testable import HandyTools

/// "From the home page, every tool is available" (user, Nov 22): every tool Tenzy has is reached from Home — a
/// shelf, its own tile, or the "start with what you have" tile for its kind of file — and no shelf repeats a tool.
@MainActor
final class HomeShelvesTests: XCTestCase {
    func testEveryToolIsReachableFromHome() {
        let reached = HomeShelves.reached(handoff: { ToolHandoff.tools(for: $0) }, homes: Tool.homes)
        let missing = TOOLS.map(\.id).filter { !reached.contains($0) }
        XCTAssertEqual(missing, [], "Not reachable from Home: \(missing)")
    }

    func testNoToolSitsOnTwoShelves() {
        let ids = HomeShelves.all.flatMap(\.tools)
        let twice = Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        XCTAssertEqual(twice, [], "On more than one shelf: \(twice)")
        XCTAssertTrue(Set(ids).isDisjoint(with: HomeShelves.ownTiles), "A tool with its own Home tile is also on a shelf")
    }

    func testEveryShelfToolExists() {
        let known = Set(TOOLS.map(\.id))
        for s in HomeShelves.all {
            XCTAssertFalse(s.tools.isEmpty, "\(s.title) is empty")
            for id in s.tools { XCTAssertTrue(known.contains(id), "\(s.title) lists \(id), which isn't a tool") }
        }
    }

    /// The flashlight — the one the user couldn't find — sits on a shelf, not only in All tools.
    func testFlashlightHasAShelf() {
        XCTAssertEqual(HomeShelves.shelf(of: "light")?.id, "phone")
    }

    /// One even grid, three across, four rows (Manan, 23 Nov: "3 grids on top and then 4 at the bottom" looked wrong):
    /// the six "start with what you have" tiles, the shelves and Think fill it exactly — no half-empty row.
    func testHomeGridIsWholeRowsOfThree() {
        XCTAssertEqual(6 + HomeShelves.all.count + HomeShelves.ownTiles.count, 12)
        XCTAssertEqual(HomeShelves.shelf(of: "contacts")?.id, "day", "Contacts lives on Daily life now")
    }
}
