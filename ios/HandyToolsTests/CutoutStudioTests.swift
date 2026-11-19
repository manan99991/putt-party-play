import XCTest
@testable import HandyTools

/// The cut-out's finishing: shapes, backdrops, shadow, and the "runs off the edge" note.
final class CutoutStudioTests: XCTestCase {
    /// A see-through picture with an opaque blob where `box` says.
    private func cut(_ size: CGSize, _ box: CGRect) -> UIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1; f.opaque = false
        return UIGraphicsImageRenderer(size: size, format: f).image { _ in UIColor.systemPink.setFill(); UIBezierPath(ovalIn: box).fill() }
    }

    func testShapesComeOutTheRightProportions() throws {
        let c = cut(CGSize(width: 1000, height: 1200), CGRect(x: 300, y: 200, width: 400, height: 800))
        let sq = try XCTUnwrap(CutoutStudio.render(c, original: nil, backdrop: .white, shadow: true, fit: .square))
        XCTAssertEqual(sq.size.width, sq.size.height, accuracy: 1)
        let st = try XCTUnwrap(CutoutStudio.render(c, original: nil, backdrop: .clear, shadow: false, fit: .story))
        XCTAssertEqual(st.size.width / st.size.height, 9.0 / 16.0, accuracy: 0.01)
        let tight = try XCTUnwrap(CutoutStudio.render(c, original: nil, backdrop: .clear, shadow: false, fit: .tight))
        XCTAssertLessThan(tight.size.width, 500); XCTAssertLessThan(tight.size.height, 900)
    }

    func testRunsOffTheEdgeIsSaidOnlyWhenItDoes() {
        XCTAssertNil(CutoutStudio.edgeNote(CutoutStudio.cutOffEdges(cut(CGSize(width: 800, height: 800), CGRect(x: 200, y: 200, width: 300, height: 300)))))
        // An arm running off the right side (your photo): said plainly.
        XCTAssertNotNil(CutoutStudio.edgeNote(CutoutStudio.cutOffEdges(cut(CGSize(width: 800, height: 800), CGRect(x: 300, y: 200, width: 600, height: 300)))))
        // Running off the bottom only is a normal portrait: not flagged.
        XCTAssertNil(CutoutStudio.edgeNote(CutoutStudio.cutOffEdges(cut(CGSize(width: 800, height: 800), CGRect(x: 200, y: 300, width: 300, height: 600)))))
    }
}
