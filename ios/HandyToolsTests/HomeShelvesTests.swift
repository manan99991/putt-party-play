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

    /// Audit decision 1 (23 Nov): every Home tile says the job, each one different, and fits two lines at one text size
    /// on the narrowest iPhone (375 points wide): 89 points of text in the roomy tile, 93 in the compact one.
    func testEveryTileHasAJobNameThatFitsTwoLines() {
        let tiled = HomeShelves.all.flatMap(\.tools)
        let missing = tiled.filter { HomeShelves.jobName($0) == nil }
        XCTAssertEqual(missing, [], "No job name: \(missing)")
        let names = tiled.compactMap { HomeShelves.jobName($0) }
        XCTAssertEqual(Set(names).count, names.count, "Two tiles say the same thing")
        func lines(_ text: String, size: CGFloat, width: CGFloat) -> Int {
            let font = UIFont.systemFont(ofSize: size, weight: .semibold)
            let r = (text as NSString).boundingRect(with: CGSize(width: width, height: 1000), options: [.usesLineFragmentOrigin],
                                                     attributes: [.font: font], context: nil)
            return Int((r.height / font.lineHeight).rounded())
        }
        for n in names {
            XCTAssertLessThanOrEqual(lines(n, size: 13, width: 89), 2, "\"\(n)\" needs more than two lines in a tile")
            XCTAssertLessThanOrEqual(lines(n, size: 12, width: 93), 2, "\"\(n)\" needs more than two lines in a compact tile")
        }
    }

    /// Audit decision 4: the welcome's optional choice only picks the first Home tab, and every choice names a real tab.
    func testWelcomeChoicesOpenARealTab() {
        let tabs = Set(HomeShelves.all.map(\.id))
        for c in WelcomeChoice.allCases { XCTAssertTrue(tabs.contains(c.homeTab), "\(c) opens a tab Home doesn't have") }
        XCTAssertNil(WelcomeChoice.homeTab(for: []))
        XCTAssertEqual(WelcomeChoice.homeTab(for: [.words, .documents]), "pdf", "the first one in the order shown wins")
    }
}
