import XCTest
@testable import HandyTools

final class TableCheckTests: XCTestCase {
    func testNumbersAddUpToThePrintedTotal() {
        let rows = [["Item", "Qty", "Price"], ["Apples", "2", "3.50"], ["Bread", "1", "2.25"], ["Milk", "1", "1.25"], ["Total", "", "7.00"]]
        let c = DataGrab.tableCheck(rows, header: true)
        XCTAssertEqual(c.numberColumns, [1, 2])
        XCTAssertEqual(c.sums[2] ?? 0, 7.0, accuracy: 0.001)
        XCTAssertEqual(c.totals.count, 1); XCTAssertTrue(c.addsUp)
    }

    func testAMisreadCellIsFlaggedAndTheTotalDisagrees() {
        let rows = [["Item", "Price"], ["Apples", "3.50"], ["Bread", "2.2S"], ["Milk", "1.25"], ["Total", "7.00"]]
        let c = DataGrab.tableCheck(rows, header: true)
        XCTAssertTrue(c.suspect.contains([2, 1]), "2.2S is a misread number")
        XCTAssertFalse(c.addsUp, "rows add to 4.75, the total says 7.00")
    }

    func testTextColumnsAreLeftAlone() {
        let c = DataGrab.tableCheck([["Name", "City"], ["Ann", "Paris"], ["Bob", "Rome"]], header: true)
        XCTAssertTrue(c.numberColumns.isEmpty); XCTAssertTrue(c.suspect.isEmpty)
    }
}
