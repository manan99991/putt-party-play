import XCTest
@testable import HandyTools

/// "From the home page, every tool is available" (user, Nov 22): every tool Tenzy has is reached from Home — a
/// shelf, its own tile, or the "start with what you have" tile for its kind of file — and no shelf repeats a tool.
@MainActor
final class HomeShelvesTests: XCTestCase {
    /// "Contacts and other tabs are missing — make sure nothing is missing from the home page" (Manan, 23 Nov): every
    /// tool has its own tile in one of Home's tabs. Only tools that live inside another tool are left out, and that
    /// tool must be in a tab. (Until 23 Nov this test also counted "pick a file first" as reachable, which let ten
    /// tools — Sign, Redact and the other PDF tools among them — pass with no tile anywhere on Home.)
    func testEveryToolHasItsOwnTileInATab() {
        let tiled = Set(HomeShelves.all.flatMap(\.tools))
        let missing = TOOLS.map(\.id).filter { !tiled.contains($0) && Tool.homes[$0] == nil }
        XCTAssertEqual(missing, [], "No tile on Home: \(missing)")
        for (child, parent) in Tool.homes { XCTAssertTrue(tiled.contains(parent), "\(child) lives in \(parent), which has no Home tile") }
        let inside = HomeShelves.all.flatMap(\.tools).filter { Tool.homes[$0] != nil }
        XCTAssertEqual(inside, [], "These live inside another tool, so a tile would repeat it: \(inside)")
    }

    /// A tab fits the screen: never more than three rows of three.
    func testEveryTabFitsWithoutScrolling() {
        for s in HomeShelves.all {
            XCTAssertLessThanOrEqual(s.tools.count, HomeShelves.maxPerTab, "\(s.title) has \(s.tools.count) tools")
        }
        XCTAssertEqual(HomeShelves.all.count, 8, "eight tabs: four across, two rows")
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

    /// The flashlight — the one the user couldn't find — and Contacts each have a tile, in a tab that says so.
    func testFlashlightAndContactsHaveTiles() {
        XCTAssertEqual(HomeShelves.shelf(of: "light")?.id, "phone")
        XCTAssertEqual(HomeShelves.shelf(of: "contacts")?.title, "Contacts & phone")
        XCTAssertEqual(HomeShelves.shelf(of: "pdfsign")?.id, "pdf")
    }
}
