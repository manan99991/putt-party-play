import XCTest
@testable import HandyTools

/// Organize Pages → "Fix upside-down pages" had no test. An upright letter must be left alone; the same letter
/// turned round must be caught; a nearly blank page must be left alone.
final class UpsideDownPageTests: XCTestCase {
    private func turned(_ img: UIImage) -> UIImage {
        UIGraphicsImageRenderer(size: img.size).image { c in
            c.cgContext.translateBy(x: img.size.width, y: img.size.height)
            c.cgContext.rotate(by: .pi)
            img.draw(at: .zero)
        }
    }

    func testUpsideDownLetterIsCaughtAndUprightOneIsLeftAlone() {
        let letter = SampleAssets.document()
        XCTAssertFalse(PDFPages.looksUpsideDown(letter), "an upright letter was called upside down")
        XCTAssertTrue(PDFPages.looksUpsideDown(turned(letter)), "an upside-down letter wasn't caught")
    }

    func testBlankPageIsLeftAlone() {
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 1240, height: 1754)).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 1240, height: 1754))
        }
        XCTAssertFalse(PDFPages.looksUpsideDown(blank))
        XCTAssertFalse(PDFPages.looksUpsideDown(turned(blank)))
    }
}
