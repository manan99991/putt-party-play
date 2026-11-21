import XCTest
import PDFKit
@testable import HandyTools

/// "One PDF or 12": several PDFs from one run join into one file with every page, in order; a locked PDF is never
/// offered for joining.
final class PDFMergeTests: XCTestCase {
    private func write(_ d: Data, _ name: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("merge-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let u = dir.appendingPathComponent(name); try d.write(to: u); return u
    }

    func testTwoPDFsJoinIntoOneWithEveryPageInOrder() throws {
        let a = try write(SampleAssets.pdf(), "a.pdf")
        let b = a.deletingLastPathComponent().appendingPathComponent("b.pdf")
        try SampleAssets.pdf().write(to: b)
        XCTAssertTrue(PDFMerge.canMerge([a, b]))
        let m = try XCTUnwrap(PDFMerge.merge([a, b], name: "Scans"))
        let doc = try XCTUnwrap(PDFDocument(url: m))
        XCTAssertEqual(doc.pageCount, 4)
        XCTAssertTrue(doc.page(at: 0)?.string?.contains("INVOICE") == true)
        XCTAssertTrue(doc.page(at: 3)?.string?.contains("TERMS") == true)
        XCTAssertEqual(m.lastPathComponent, "Scans.pdf")
    }

    func testOneFileOrALockedPDFIsNotOfferedForJoining() throws {
        let a = try write(SampleAssets.pdf(), "a.pdf")
        XCTAssertFalse(PDFMerge.canMerge([a]))
        let doc = try XCTUnwrap(PDFDocument(url: a))
        let locked = a.deletingLastPathComponent().appendingPathComponent("locked.pdf")
        XCTAssertTrue(doc.write(to: locked, withOptions: [.userPasswordOption: "1234", .ownerPasswordOption: "1234"]))
        XCTAssertFalse(PDFMerge.canMerge([a, locked]))
    }
}
