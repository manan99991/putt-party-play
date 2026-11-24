import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import HandyTools

/// Animated stickers (Manan, 24 Nov: "static and animated… the highest quality"): every move loops with no seam, really
/// moves, never cuts the sticker off at the edge, keeps the corners see-through, and saves as files that play as loops.
final class StickerMotionTests: XCTestCase {
    /// A sticker-like picture: a coloured blob with a white edge, taller than wide, on see-through.
    private func sticker() -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 300, height: 360), format: fmt).image { c in
            UIColor.white.setFill()
            c.cgContext.fillEllipse(in: CGRect(x: 4, y: 4, width: 292, height: 352))
            UIColor.systemOrange.setFill()
            c.cgContext.fillEllipse(in: CGRect(x: 20, y: 20, width: 260, height: 320))
        }
    }

    /// Alpha of every pixel, row by row.
    private func alpha(_ img: UIImage) -> (w: Int, h: Int, a: [UInt8]) {
        let cg = img.cgImage!
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (w, h, stride(from: 3, to: px.count, by: 4).map { px[$0] })
    }

    func testEveryMoveLoopsWithNoSeam() {
        for m in StickerMotion.allCases {
            let a = StickerMotion.pose(m, 0), b = StickerMotion.pose(m, 1)
            let turn = (b.angle - a.angle).truncatingRemainder(dividingBy: .pi * 2)
            XCTAssertEqual(a.dx, b.dx, accuracy: 0.002, "\(m.title): sideways jump at the loop")
            XCTAssertEqual(a.lift, b.lift, accuracy: 0.002, "\(m.title): height jump at the loop")
            XCTAssertEqual(turn, 0, accuracy: 0.002, "\(m.title): turn jump at the loop")
            XCTAssertEqual(a.sx, b.sx, accuracy: 0.002, "\(m.title): width jump at the loop")
            XCTAssertEqual(a.sy, b.sy, accuracy: 0.002, "\(m.title): height jump at the loop")
            XCTAssertEqual(a.skew, b.skew, accuracy: 0.002, "\(m.title): lean jump at the loop")
        }
    }

    func testEveryMoveMovesStaysInsideAndKeepsCornersClear() {
        let s = sticker()
        for m in StickerMotion.allCases {
            let frames = StickerMotion.frames(s, motion: m, side: 256)
            XCTAssertEqual(frames.count, StickerMotion.frameCount, m.title)
            XCTAssertEqual(frames[0].size, CGSize(width: 256, height: 256), m.title)
            let maps = frames.map(alpha)
            // It moves: some frames differ from the first by more than a sliver.
            let changed = maps.dropFirst().map { f in zip(f.a, maps[0].a).filter { abs(Int($0) - Int($1)) > 40 }.count }.max() ?? 0
            XCTAssertGreaterThan(changed, 256 * 256 / 100, "\(m.title) barely moves")
            // The sticker is never cut off: nothing solid on the outermost pixels (confetti and hearts may drift out).
            if m != .party && m != .love {
                for (k, f) in maps.enumerated() {
                    var edge = 0
                    for x in 0..<f.w { edge += Int(f.a[x] > 128 ? 1 : 0) + Int(f.a[(f.h - 1) * f.w + x] > 128 ? 1 : 0) }
                    for y in 0..<f.h { edge += Int(f.a[y * f.w] > 128 ? 1 : 0) + Int(f.a[y * f.w + f.w - 1] > 128 ? 1 : 0) }
                    XCTAssertEqual(edge, 0, "\(m.title) frame \(k): the sticker runs off the edge")
                }
            }
            // A sticker, not a picture: the corners stay see-through. Confetti and hearts fly past the edges, so for those
            // the border must still be almost all see-through (no box behind the sticker).
            for (k, f) in maps.enumerated() {
                if m == .party || m == .love {
                    var solid = 0, total = 0
                    for x in 0..<f.w { total += 2; solid += Int(f.a[x] > 128 ? 1 : 0) + Int(f.a[(f.h - 1) * f.w + x] > 128 ? 1 : 0) }
                    for y in 0..<f.h { total += 2; solid += Int(f.a[y * f.w] > 128 ? 1 : 0) + Int(f.a[y * f.w + f.w - 1] > 128 ? 1 : 0) }
                    XCTAssertLessThan(Double(solid) / Double(total), 0.05, "\(m.title) frame \(k): the edge is filled in, like a box behind it")
                } else {
                    XCTAssertEqual(f.a[0], 0, "\(m.title) frame \(k): the top-left corner isn't see-through")
                }
            }
        }
    }

    func testFilesPlayAsLoops() throws {
        let frames = StickerMotion.frames(sticker(), motion: .bounce)
        let apng = try XCTUnwrap(StickerMotion.apng(frames))
        let gif = try XCTUnwrap(StickerMotion.gif(frames))
        for (name, data, type, dict, loopKey) in [("APNG", apng, UTType.png, kCGImagePropertyPNGDictionary, kCGImagePropertyAPNGLoopCount),
                                                  ("GIF", gif, UTType.gif, kCGImagePropertyGIFDictionary, kCGImagePropertyGIFLoopCount)] {
            let src = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            XCTAssertEqual(CGImageSourceGetType(src) as String?, type.identifier, name)
            XCTAssertEqual(CGImageSourceGetCount(src), StickerMotion.frameCount, "\(name) doesn't hold every frame")
            let props = CGImageSourceCopyProperties(src, nil) as? [String: Any]
            let loop = (props?[dict as String] as? [String: Any])?[loopKey as String] as? Int
            XCTAssertEqual(loop, 0, "\(name) doesn't loop forever")
            print("STICKER| \(name) \(data.count / 1024) KB for \(StickerMotion.frameCount) frames at \(Int(StickerMotion.canvas))px")
            XCTAssertLessThan(data.count, 4_000_000, "\(name) is too big to send")
        }
    }
}
