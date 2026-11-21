import XCTest
import PDFKit
@testable import HandyTools

/// PDF Convert → "Tables as a spreadsheet" was never run on a real PDF table. The sample invoice has one (item,
/// quantity, price); it must come out as rows with the columns kept apart and the money as numbers.
final class PDFTablesTests: XCTestCase {
    func testInvoiceTableComesOutAsRowsAndColumns() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tables-\(UUID().uuidString).pdf")
        try SampleAssets.pdf().write(to: url)
        let pages = DocEngine.importPDF(url)
        XCTAssertEqual(pages.count, 2)
        let rows = PDFTables.rows(pages, pages: [0])
        let flat = rows.map { $0.joined(separator: " | ") }.joined(separator: "\n")
        XCTAssertGreaterThanOrEqual(rows.count, 4, flat)
        let logo = rows.first { $0.contains { $0.localizedCaseInsensitiveContains("Logo design") } }
        XCTAssertNotNil(logo, "no row for Logo design:\n\(flat)")
        XCTAssertTrue(logo?.contains { $0.contains("450") } == true, "price not in the Logo design row:\n\(flat)")
        XCTAssertFalse(logo?.contains { $0.localizedCaseInsensitiveContains("Logo design") && $0.contains("450") } == true,
                       "name and price ran into one cell:\n\(flat)")
        XCTAssertNotNil(XLSXWriter.workbook(rows: rows, sheetName: "Tables"), "workbook not made")
    }
}
