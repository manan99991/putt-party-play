import XCTest
import PDFKit
@testable import HandyTools

final class ShotGuideTests: XCTestCase {
    private func photo(_ c: UIColor) -> UIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600), format: f).image { x in c.setFill(); x.fill(CGRect(x: 0, y: 0, width: 800, height: 600)) }
    }

    func testJobsAreGuidedAndNamed() {
        XCTAssertLessThanOrEqual(ShotGuide.jobs.count, 6, "no more than 6 choices")
        for j in ShotGuide.jobs { XCTAssertGreaterThanOrEqual(j.shots.count, 5, j.id); XCTAssertTrue(j.shots.allSatisfy { !$0.tip.isEmpty }, "every shot says how to frame it") }
        XCTAssertGreaterThanOrEqual(ShotGuide.jobs.first { $0.id == "rental" }!.shots.count, 8, "the rental check goes all the way round the car")
    }

    func testStampAddsTheLineWithoutCroppingThePhoto() throws {
        let s = ShotGuide.stamp(photo(.red), text: "Driver side · 19 Nov 2026 · Main St")
        let cg = try XCTUnwrap(s.cgImage)
        XCTAssertEqual(cg.width, 800); XCTAssertGreaterThan(cg.height, 600, "the strip goes below the photo")
    }

    func testReportHasACoverAndTwoPhotosAPage() throws {
        let job = ShotGuide.jobs[0]
        let taken = (0..<5).map { ShotGuide.Taken(shot: job.shots[$0], image: photo(.blue), at: Date()) }
        let data = ShotGuide.report(job, taken: taken, place: "12 Main St, Naperville", started: Date())
        let doc = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(doc.pageCount, 1 + 3, "cover + 5 photos two to a page")
        let cover = doc.page(at: 0)?.string ?? ""
        XCTAssertTrue(cover.contains(job.title)); XCTAssertTrue(cover.contains("Naperville")); XCTAssertTrue(cover.contains("5 photos"))
        XCTAssertTrue(cover.contains("Driver side"), "every shot listed on the cover")
    }
}
