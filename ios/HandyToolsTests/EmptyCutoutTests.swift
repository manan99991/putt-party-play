import XCTest
@testable import HandyTools

/// "Cut the subject out" showed a blank checkerboard as its result (21 Nov audit). A cut-out that is (almost) all
/// see-through is never handed back; the measure behind that rule is checked here.
final class EmptyCutoutTests: XCTestCase {
    private func image(_ fill: UIColor?, size: CGFloat = 200) -> UIImage {
        let f = UIGraphicsImageRendererFormat.default(); f.opaque = false; f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: f).image { c in
            if let fill { fill.setFill(); c.fill(CGRect(x: 50, y: 50, width: 100, height: 100)) }
        }
    }

    func testAnEmptyCutoutCountsAsNothing() {
        XCTAssertLessThan(ImageStudio.visibleShare(image(nil)), 0.01)
    }

    func testASubjectCountsAsThere() {
        XCTAssertEqual(ImageStudio.visibleShare(image(.red)), 0.25, accuracy: 0.03)
    }
}
