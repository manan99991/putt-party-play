import XCTest
import CoreGraphics
import ImageIO
@testable import HandyTools

final class BoomerangTests: XCTestCase {
    func testEveryStyleIsAValidLoop() {
        for st in Boomerang.styles {
            let beats = Boomerang.plan(st.id, count: 28)
            XCTAssertGreaterThan(beats.count, 20, st.id)
            XCTAssertTrue(beats.allSatisfy { (0..<28).contains($0.frame) }, st.id)
            XCTAssertTrue(beats.allSatisfy { $0.delay >= 0.02 }, "\(st.id): a frame faster than players show")
            XCTAssertTrue(beats.allSatisfy { $0.zoom >= 1 }, st.id)
            let seconds = beats.reduce(0) { $0 + $1.delay }
            XCTAssertTrue((0.6...6).contains(seconds), "\(st.id) lasts \(seconds) s")
        }
        XCTAssertEqual(Boomerang.plan("snap", count: 0), [])
        XCTAssertEqual(Boomerang.plan("dramatic", count: 2).count, 2)
    }

    func testStylesReallyDiffer() {
        let n = 28
        func seconds(_ b: [Boomerang.Beat]) -> Double { b.reduce(0) { $0 + $1.delay } }
        // Snap plays about twice as fast as filmed (18 frames a second).
        let snap = Boomerang.plan("snap", count: n)
        let filmed = Double(n) / Boomerang.framesPerSecond
        XCTAssertLessThan(seconds(Array(snap.prefix(n))), filmed * 0.7)
        XCTAssertTrue(snap.contains { $0.shake && $0.zoom > 1 }, "the turn has a punch")
        // Stutter repeats the same stretch several times.
        let stutter = Boomerang.plan("stutter", count: n).map(\.frame)
        let a = Int(Double(n) * 0.4)
        XCTAssertGreaterThanOrEqual(stutter.filter { $0 == a }.count, 4)
        // Slingshot goes out slowly and comes back far faster.
        let sling = Boomerang.plan("slingshot", count: n)
        let out = sling.prefix(n - 1).map(\.delay).reduce(0, +) / Double(n - 1)
        let back = sling.suffix(from: n).map(\.delay).reduce(0, +) / Double(sling.count - n)
        XCTAssertGreaterThan(out, back * 3)
        // Dramatic zoom ends up more than twice as close, held long enough to land.
        let drama = Boomerang.plan("dramatic", count: n)
        XCTAssertGreaterThan(drama.map(\.zoom).max() ?? 0, 2)
        XCTAssertTrue(drama.contains { $0.zoom > 1.3 && $0.delay > 0.3 })
        XCTAssertTrue(Boomerang.plan("echo", count: n).allSatisfy { $0.ghosts > 0 })
        XCTAssertEqual(Boomerang.plan("reverse", count: 4).map(\.frame), [3, 2, 1, 0])
        // Old chains saved "boomerang": that's Snap.
        XCTAssertEqual(Boomerang.style("boomerang").id, "snap")
        XCTAssertEqual(Boomerang.plan("boomerang", count: n), snap)
    }

    func testZoomNeverShowsAnEdge() {
        for f in [CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 1, y: 0.2), CGPoint(x: 0.9, y: 1)] {
            for z in [1.0, 1.4, 2.4] {
                let r = Boomerang.placement(w: 400, h: 300, zoom: z, focus: f)
                XCTAssertLessThanOrEqual(r.minX, 0.0001); XCTAssertLessThanOrEqual(r.minY, 0.0001)
                XCTAssertGreaterThanOrEqual(r.maxX, 399.999); XCTAssertGreaterThanOrEqual(r.maxY, 299.999)
            }
        }
        XCTAssertEqual(Boomerang.placement(w: 400, h: 300, zoom: 1, focus: CGPoint(x: 0.9, y: 0.1)), CGRect(x: 0, y: 0, width: 400, height: 300))
        // Zooming on the middle keeps the middle in the middle.
        let r = Boomerang.placement(w: 400, h: 300, zoom: 2, focus: CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(r.midX, 200, accuracy: 0.001); XCTAssertEqual(r.midY, 150, accuracy: 0.001)
    }

    func testMotionCenterFindsTheMovement() {
        let side = 10
        let a = [UInt8](repeating: 50, count: side * side)
        var b = a
        b[1 * side + 8] = 250   // top right (row 1 is near the top)
        let c = Boomerang.weightedCenter(a, b, side: side)
        XCTAssertGreaterThan(c.x, 0.8); XCTAssertGreaterThan(c.y, 0.8)
        XCTAssertEqual(Boomerang.weightedCenter(a, a, side: side), CGPoint(x: 0.5, y: 0.5))
    }

    /// A real GIF from drawn frames: one picture per beat, each with its own time on screen.
    func testEveryStyleMakesAGIF() throws {
        let frames: [CGImage] = (0..<12).compactMap { i in
            let ctx = CGContext(data: nil, width: 320, height: 240, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            ctx.setFillColor(CGColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 320, height: 240))
            ctx.setFillColor(CGColor(red: 1, green: 0.8, blue: 0.1, alpha: 1)); ctx.fillEllipse(in: CGRect(x: 20 + i * 20, y: 90, width: 60, height: 60))
            return ctx.makeImage()
        }
        let clip = Boomerang.Clip(frames: frames, focus: CGPoint(x: 0.6, y: 0.5))
        for st in Boomerang.styles {
            let url = try XCTUnwrap(Boomerang.gif(clip, style: st.id, side: 200), st.id)
            let src = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            let beats = Boomerang.plan(st.id, count: frames.count)
            XCTAssertEqual(CGImageSourceGetCount(src), beats.count, st.id)
            let first = try XCTUnwrap(CGImageSourceCreateImageAtIndex(src, 0, nil))
            XCTAssertEqual(max(first.width, first.height), 200, st.id)
            let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
            let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? 0
            XCTAssertEqual(delay, max(0.02, (beats[0].delay * 100).rounded() / 100), accuracy: 0.006, st.id)
        }
    }
}
