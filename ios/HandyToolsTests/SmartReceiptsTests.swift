import XCTest
@testable import HandyTools

/// Receipts autorun (25 Nov): every receipt becomes one exact row; the same receipt never lands twice; rows made with
/// either set of columns line up by name in any sheet; and a receipt that doesn't add up waits for a look.
final class SmartReceiptsTests: XCTestCase {
    private func day(_ d: Int) -> Date {
        var c = Calendar(identifier: .gregorian); c.timeZone = .current
        return c.date(from: DateComponents(year: 2026, month: 11, day: d, hour: 12))!
    }
    private func receipt(_ shop: String, _ total: Double?, tax: Double? = nil, d: Int = 25, lines: [(String, Double)] = [], pay: String = "") -> DataGrab.Receipt {
        var r = DataGrab.Receipt()
        r.merchant = shop; r.total = total; r.tax = tax; r.date = day(d); r.currency = "$"; r.payment = pay
        r.lines = lines.map { .init(name: $0.0, qty: nil, unit: nil, amount: $0.1) }
        return r
    }
    private func entry(_ id: String, _ r: DataGrab.Receipt, from: String = "Photo") -> SmartReceipts.Entry {
        SmartReceipts.Entry(id: id, from: from, taken: day(25), receipt: r)
    }

    func testEachReceiptIsOneExactRow() {
        let e = entry("a", receipt("Shell Oil 57442", 48.31, tax: 3.12, pay: "VISA 4821"))
        XCTAssertTrue(e.ready)
        XCTAssertEqual(e.category, "Fuel")
        let csv = SmartReceipts.rows([e], header: nil).components(separatedBy: "\n")
        XCTAssertEqual(csv[0], SmartReceipts.header)
        let cells = RunningList.fields(csv[1])
        XCTAssertEqual(cells.count, 9)
        XCTAssertEqual(Array(cells[1...4]), ["Shell Oil 57442", "48.31", "3.12", "$"])
        XCTAssertEqual(cells[5], "VISA 4821"); XCTAssertEqual(cells[6], "Fuel"); XCTAssertEqual(cells[8], "Photo")
        XCTAssertTrue(cells[0].hasPrefix("2026-11-2"))
    }

    func testAShopNameWithACommaStaysInOneCell() {
        let csv = SmartReceipts.rows([entry("a", receipt("Smith, Jones & Co", 12))], header: nil).components(separatedBy: "\n")
        XCTAssertEqual(RunningList.fields(csv[1])[1], "Smith, Jones & Co")
    }

    func testCategories() {
        XCTAssertEqual(SmartReceipts.category(receipt("Starbucks #1123", 6.4)), "Meals")
        XCTAssertEqual(SmartReceipts.category(receipt("Marriott Downtown", 210)), "Lodging")
        XCTAssertEqual(SmartReceipts.category(receipt("The Home Depot", 88)), "Supplies & hardware")
        XCTAssertEqual(SmartReceipts.category(receipt("Staples", 31)), "Office & shipping")
        XCTAssertEqual(SmartReceipts.category(receipt("Quiet Corner", 19)), "Other", "never a guess dressed up as a fact")
        XCTAssertEqual(SmartReceipts.category(receipt("Drinkwater Winner Supply", 19)), "Other", "whole words only: not 'ink', not 'inn'")
    }

    func testHeldBackWhenTheNumbersDontAddUp() {
        let e = entry("a", receipt("Corner Store", 12.50, lines: [("Milk", 4), ("Bread", 3)]))
        XCTAssertFalse(e.ready)
        XCTAssertTrue(e.unsure.contains("total"))
        let csv = SmartReceipts.rows([e], header: nil)
        XCTAssertEqual(RunningList.rowCount(RunningList.merged(existing: "", incoming: csv)), 1, "rows() writes what it's given…")
        var fixed = e; fixed.total = 7; fixed.recheck()
        XCTAssertTrue(fixed.ready, "a corrected total releases the hold")
    }

    func testTheSameReceiptTwiceCountsOnce() {
        let photo = entry("photo", receipt("Target", 42.17, d: 25))
        let pdf = entry("pdf", receipt("TARGET", 42.17, d: 25), from: "PDF: order.pdf")
        let other = entry("other", receipt("Target", 42.17, d: 24))
        XCTAssertEqual(SmartReceipts.deduped([photo, pdf, other]).map(\.id), ["photo", "other"], "same shop, total and day is one receipt")
    }

    func testOldAndNewSheetsTakeEachOthersRows() {
        // An older five-column sheet gets a fuller row: lined up by name, extras left out, nothing dropped.
        let old = "Date,Merchant,Total,Tax,Currency\n2026-11-02,Jewel,23.10,1.20,$"
        let full = SmartReceipts.rows([entry("a", receipt("Shell", 40, tax: 2))], header: nil)
        let m1 = RunningList.merged(existing: old, incoming: full)
        XCTAssertEqual(RunningList.rowCount(m1), 2)
        XCTAssertEqual(RunningList.fields(m1.components(separatedBy: "\n")[2]).count, 5)
        // A new nine-column sheet gets a five-column row from the receipt tool: padded, not dropped.
        let newSheet = full
        let m2 = RunningList.merged(existing: newSheet, incoming: DataGrab.expenseRow(receipt("Jewel", 23.1, tax: 1.2)))
        XCTAssertEqual(RunningList.rowCount(m2), 2)
        let row = RunningList.fields(m2.components(separatedBy: "\n")[2])
        XCTAssertEqual(row.count, 9); XCTAssertEqual(row[1], "Jewel"); XCTAssertEqual(row[2], "23.10")
    }

    func testAddingTheSameRunAgainAddsNothing() {
        let csv = SmartReceipts.rows([entry("a", receipt("Shell", 40, tax: 2)), entry("b", receipt("Jewel", 23.1))], header: nil)
        let once = RunningList.merged(existing: "", incoming: csv)
        let twice = RunningList.merged(existing: once, incoming: csv)
        XCTAssertEqual(RunningList.rowCount(twice), 2)
    }
}
