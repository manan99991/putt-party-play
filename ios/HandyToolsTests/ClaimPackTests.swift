import XCTest
import PDFKit
@testable import HandyTools

final class ClaimPackTests: XCTestCase {
    func testClaimPackHasTheDetailsTheReceiptAndTheProblem() throws {
        let cal = Calendar.current
        let bought = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 19))!
        var r = Receipt(imageFile: "x.jpg", store: "Best Buy", purchaseDate: bought, total: "$499.99", rawText: "")
        r.items = ["Samsung 55\\" TV"]; r.warrantyMonths = 12
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        let img = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 500), format: f).image { c in UIColor.gray.setFill(); c.fill(CGRect(x: 0, y: 0, width: 300, height: 500)) }
        let doc = try XCTUnwrap(PDFDocument(data: ClaimPack.pdf(r, receiptImage: img, problem: img, note: "Screen flickers", now: now)))
        XCTAssertEqual(doc.pageCount, 3, "details, receipt, the problem")
        let first = doc.page(at: 0)?.string ?? ""
        for want in ["Best Buy", "$499.99", "12 months", "days left", "Screen flickers"] { XCTAssertTrue(first.contains(want), "\(want) missing") }
        XCTAssertEqual(PDFDocument(data: ClaimPack.pdf(r, receiptImage: nil, problem: nil, note: "", now: now))?.pageCount, 1)
    }
}
