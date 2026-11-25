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

    /// 25 Nov: the autorun read "TOTAL" and "12.37" as two lines (a wide gap on the receipt) and took the subtotal as the
    /// total. Every reader now goes through ChainText.documentText, which keeps a label and its amount together.
    func testALabelAndItsAmountAcrossAGapStayTogether() {
        func line(_ t: String, x: CGFloat, row: Int) -> DocEngine.OCRLine {
            DocEngine.OCRLine(text: t, box: CGRect(x: x, y: 0.1 + CGFloat(row) * 0.05, width: 0.2, height: 0.03))
        }
        let ocr = [line("CORNER MARKET", x: 0.1, row: 0), line("Milk 2%", x: 0.1, row: 2), line("4.29", x: 0.7, row: 2),
                   line("Sourdough Bread", x: 0.1, row: 3), line("5.49", x: 0.7, row: 3), line("Bananas", x: 0.1, row: 4), line("1.86", x: 0.7, row: 4),
                   line("SUBTOTAL", x: 0.1, row: 6), line("11.64", x: 0.7, row: 6), line("TAX", x: 0.1, row: 7), line("0.73", x: 0.7, row: 7),
                   line("TOTAL", x: 0.1, row: 8), line("12.37", x: 0.7, row: 8), line("VISA ****4821", x: 0.1, row: 10), line("12.37", x: 0.7, row: 10)]
        let r = DataGrab.receipt(ChainText.documentText(ocr))
        XCTAssertEqual(r.merchant, "CORNER MARKET")
        XCTAssertEqual(r.total, 12.37); XCTAssertEqual(r.subtotal, 11.64); XCTAssertEqual(r.tax, 0.73)
        XCTAssertEqual(r.lines.map(\.amount), [4.29, 5.49, 1.86])
        XCTAssertNil(DataGrab.entryProblems(r).block, "this receipt adds up")
    }

    func testAddingTheSameRunAgainAddsNothing() {
        let csv = SmartReceipts.rows([entry("a", receipt("Shell", 40, tax: 2)), entry("b", receipt("Jewel", 23.1))], header: nil)
        let once = RunningList.merged(existing: "", incoming: csv)
        let twice = RunningList.merged(existing: once, incoming: csv)
        XCTAssertEqual(RunningList.rowCount(twice), 2)
    }
}
