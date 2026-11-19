import XCTest
@testable import HandyTools

/// Cleaner's decisions: which burst frame is kept (and why), and the plan's order.
final class CleanerPlanTests: XCTestCase {
    func testBurstKeepsYourPickThenFavouriteThenIPhonesPickThenCover() {
        typealias F = (id: String, user: Bool, auto: Bool, cover: Bool, fav: Bool)
        let frames: [F] = [("a", false, false, true, false), ("b", false, true, false, false), ("c", false, false, false, false)]
        XCTAssertEqual(PhotoCleaner.best(frames).id, "b", "iPhone's own pick beats the cover")
        XCTAssertTrue(PhotoCleaner.best(frames).why.contains("iPhone"))
        var withFav = frames; withFav[2].fav = true
        XCTAssertEqual(PhotoCleaner.best(withFav).id, "c", "a favourite is kept over iPhone's pick")
        var withUser = withFav; withUser[0].user = true
        XCTAssertEqual(PhotoCleaner.best(withUser).id, "a", "the one you picked always wins")
        XCTAssertEqual(PhotoCleaner.best([("x", false, false, false, false), ("y", false, false, false, false)]).id, "x")
    }

    func testPlanDropsEmptyRowsAndPutsTheBiggestFirst() {
        let rows = [PhotoCleaner.PlanRow(id: "small", title: "", why: "", items: []),
                    PhotoCleaner.PlanRow(id: "empty", title: "", why: "", items: [])]
        XCTAssertTrue(PhotoCleaner.plan(rows).isEmpty, "rows with nothing in them aren't shown")
        XCTAssertNotNil(PhotoCleaner.freeBytes(), "free space is readable")
    }
}
