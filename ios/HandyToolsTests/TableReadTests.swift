import XCTest
@testable import HandyTools

/// "Turn a photo of a table into a spreadsheet" on a printed table: the header row is kept (27 Nov: "Role" and "Team"
/// sat near the top and were dropped as if they were a phone's status bar), and every row keeps its four cells.
final class TableReadTests: XCTestCase {
    func testPhotoOfATableKeepsItsHeaderAndRows() async throws {
        let c = try XCTUnwrap(ChainTemplates.all.first { $0.id == "table-to-sheet" })
        let img = SampleAssets.table()
        let d = try XCTUnwrap(img.jpegData(compressionQuality: 0.9))
        guard case .success(.file(let csv, let ext)) = await ChainRunner.run(c, input: .file(d, ext: "jpg")) else {
            return XCTFail("no table — read: \(ChainText.readDocument(img).map(\.text).joined(separator: " | "))")
        }
        XCTAssertEqual(ext, "csv")
        let rows = TableFinishCard.parse(csv)
        XCTAssertEqual(rows.first, ["Role", "Team", "Rate", "Openings"], "header: \(rows.prefix(3))")
        XCTAssertEqual(rows.count, 21, "rows: \(rows.count) — \(rows.prefix(4))")
        XCTAssertEqual(rows.last, ["Release Manager", "Analytics", "$64", "2"], "last row: \(rows.last ?? [])")
    }

    func testOnlyScreenShapedPicturesAreTreatedAsScreenshots() {
        func img(_ w: CGFloat, _ h: CGFloat) -> UIImage {
            let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
            return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: f).image { _ in }
        }
        XCTAssertTrue(ChainText.looksLikeScreenshot(img(1179, 2556)), "iPhone screenshot")
        XCTAssertTrue(ChainText.looksLikeScreenshot(img(1640, 2360)), "iPad screenshot")
        XCTAssertFalse(ChainText.looksLikeScreenshot(img(1400, 1424)), "a photo of a table")
        XCTAssertFalse(ChainText.looksLikeScreenshot(img(3024, 4032)), "a camera photo")
    }
}
