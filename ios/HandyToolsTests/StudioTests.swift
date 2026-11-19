import XCTest
import UIKit
@testable import HandyTools

/// Studio's jobs, checked on what they hand back.
final class StudioTests: XCTestCase {
    /// A red product on a see-through background, off-centre with lots of empty margin.
    private func product() -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 900, height: 600), format: fmt).image { _ in
            UIColor.red.setFill(); UIBezierPath(roundedRect: CGRect(x: 80, y: 120, width: 200, height: 300), cornerRadius: 20).fill()
        }
    }

    func testListingPhotoIsSquareWhiteAndFilledToTheMarketsRule() throws {
        for m in ImageStudio.markets {
            let out = try XCTUnwrap(ImageStudio.listing(product(), market: m, shadow: true), m.id)
            let cg = try XCTUnwrap(out.cgImage)
            XCTAssertEqual(cg.width, Int(m.side), m.id); XCTAssertEqual(cg.height, Int(m.side), m.id)
            // Corners pure white.
            let px = ToolOutputQualityTests.pixels(cg, at: [CGPoint(x: 3, y: 3), CGPoint(x: cg.width - 4, y: 3), CGPoint(x: 3, y: cg.height - 4)])
            XCTAssertTrue(px.allSatisfy { $0 > 250 }, "\(m.id): background must be pure white, got \(px)")
            // The product is centred and fills the market's share of the frame (its taller side).
            let red = redBox(cg)
            XCTAssertEqual(red.height / CGFloat(cg.height), m.fill, accuracy: 0.03, "\(m.id): product should fill \(m.fill) of the height")
            XCTAssertEqual(red.midX / CGFloat(cg.width), 0.5, accuracy: 0.02, "\(m.id): centred across")
            XCTAssertEqual(red.midY / CGFloat(cg.height), 0.5, accuracy: 0.02, "\(m.id): centred down")
        }
    }

    func testOpaqueBoundsFindsTheProduct() throws {
        let cg = try XCTUnwrap(product().cgImage)
        let b = try XCTUnwrap(ImageStudio.opaqueBounds(cg))
        XCTAssertEqual(b.minX, 80, accuracy: 3); XCTAssertEqual(b.minY, 120, accuracy: 3)
        XCTAssertEqual(b.width, 200, accuracy: 4); XCTAssertEqual(b.height, 300, accuracy: 4)
    }

    func testWhatChangedIsMeasured() throws {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        func flat(_ w: CGFloat) -> UIImage { UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100), format: fmt).image { c in
            UIColor(white: w, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            UIColor(white: w * 0.5, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 50, height: 100)) } }
        let words = ImageStudio.changes(from: flat(0.3), to: flat(0.6))
        XCTAssertTrue(words.contains { $0.contains("brighter") }, "\(words)")
        XCTAssertTrue(ImageStudio.changes(from: flat(0.5), to: flat(0.5)).isEmpty, "no change, no claims")
    }

    private func redBox(_ cg: CGImage) -> CGRect {
        let w = cg.width, h = cg.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        let c = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var minX = w, minY = h, maxX = 0, maxY = 0
        for y in stride(from: 0, to: h, by: 2) { for x in stride(from: 0, to: w, by: 2) {
            let o = (y * w + x) * 4
            if buf[o] > 200, buf[o + 1] < 60, buf[o + 2] < 60 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
        } }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
