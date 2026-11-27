import XCTest
import CoreImage
import UIKit
import Vision
@testable import HandyTools

/// 26 Nov: background swap and funny faces on video. Proved on pixels — a big head changes the face and leaves the
/// rest alone; colour pop greys the background and keeps the person in colour, on real photos of people.
final class VideoFunTests: XCTestCase {
    private let ctx = CIContext(options: [.cacheIntermediates: false])

    /// RGBA bytes of an image (the whole extent).
    private func pixels(_ img: CIImage) -> (bytes: [UInt8], w: Int, h: Int) {
        let w = Int(img.extent.width), h = Int(img.extent.height)
        var out = [UInt8](repeating: 0, count: w * h * 4)
        ctx.render(img, toBitmap: &out, rowBytes: w * 4, bounds: img.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return (out, w, h)
    }

    /// Mean absolute change between two same-size images inside `r` (bitmap rows run top-down; `r` is in Core Image
    /// points, bottom-up).
    private func change(_ a: CIImage, _ b: CIImage, in r: CGRect) -> Double {
        let pa = pixels(a), pb = pixels(b)
        var sum = 0.0, n = 0
        for y in Int(r.minY)..<Int(r.maxY) where y >= 0 && y < pa.h {
            let row = pa.h - 1 - y
            for x in Int(r.minX)..<Int(r.maxX) where x >= 0 && x < pa.w {
                let i = (row * pa.w + x) * 4
                for c in 0..<3 { sum += abs(Double(pa.bytes[i + c]) - Double(pb.bytes[i + c])) }
                n += 3
            }
        }
        return n > 0 ? sum / Double(n) : 0
    }

    /// A busy test card: stripes and checks, so any warp shows.
    private func card(_ size: CGSize) -> CIImage {
        let stripes = CIFilter(name: "CIStripesGenerator", parameters: ["inputWidth": 9, "inputColor0": CIColor(red: 0.9, green: 0.2, blue: 0.2), "inputColor1": CIColor(red: 0.1, green: 0.3, blue: 0.9)])!.outputImage!
        let checks = CIFilter(name: "CICheckerboardGenerator", parameters: ["inputWidth": 23])!.outputImage!
        return stripes.applyingFilter("CIMultiplyBlendMode", parameters: [kCIInputBackgroundImageKey: checks.transformed(by: CGAffineTransform(rotationAngle: 0.4))])
            .cropped(to: CGRect(origin: .zero, size: size))
    }

    func testABigHeadChangesTheFaceAndNothingFarFromIt() {
        let size = CGSize(width: 720, height: 1280), rect = CGRect(origin: .zero, size: size)
        let img = card(size)
        let face = VideoFX.Face(box: CGRect(x: 260, y: 700, width: 200, height: 240), eyes: [CGPoint(x: 315, y: 840), CGPoint(x: 405, y: 840)])
        for id in ["bighead", "tinyhead", "bigeyes", "stretchy", "wobbly"] {
            let out = VideoFX.funnyFaces(id, img, faces: [face], t: 0.7, a: 0.7, rect: rect)
            XCTAssertEqual(out.extent.size, size, id)
            XCTAssertGreaterThan(change(img, out, in: face.box.insetBy(dx: 40, dy: 40)), 8, "\(id) didn't change the face")
            XCTAssertLessThan(change(img, out, in: CGRect(x: 0, y: 0, width: 200, height: 200)), 0.5, "\(id) changed the far corner")
        }
        // No face, no change: the effect never wanders onto the background.
        XCTAssertLessThan(change(img, VideoFX.funnyFaces("bighead", img, faces: [], t: 0, a: 1, rect: rect), in: rect), 0.01)
    }

    /// VHS keeps the picture's colours (27 Nov: it turned the whole video red — the green and blue channels were
    /// dropped). A grey card stays near grey: green and blue keep most of their brightness, red isn't far above them.
    func testVHSKeepsAllThreeColours() {
        let size = CGSize(width: 640, height: 360)
        let grey = CIImage(color: CIColor(red: 0.5, green: 0.55, blue: 0.6)).cropped(to: CGRect(origin: .zero, size: size))
        var r = VideoFX.Recipe(); r.texture = "vhs"
        let out = VideoFX.frame(grey, t: 0.5, duration: 4, size: size, kit: VideoFX.Kit(r), beats: [], caption: nil)
        let p = pixels(out)
        var sum = [0.0, 0.0, 0.0]
        for i in stride(from: 0, to: p.bytes.count, by: 4) { for c in 0..<3 { sum[c] += Double(p.bytes[i + c]) } }
        let n = Double(p.w * p.h), mean = sum.map { $0 / n }
        XCTAssertGreaterThan(mean[1], 90, "VHS lost the green: \(mean)")
        XCTAssertGreaterThan(mean[2], 95, "VHS lost the blue: \(mean)")
        XCTAssertLessThan(mean[0] - mean[2], 30, "VHS turned the picture red: \(mean)")
    }

    /// Real photos of people (private set): colour pop greys what's behind the person and keeps the person in colour;
    /// portrait blur softens the background, not the face; a big head changes the face region most.
    func testRealPeopleGetTheirBackgroundAndFunnyFace() throws {
        guard let root = ProcessInfo.processInfo.environment["REAL_PHOTOS"] else { throw XCTSkip("private photos not decrypted") }
        let files = (FileManager.default.enumerator(atPath: root)?.allObjects as? [String] ?? []).filter { ["jpg", "jpeg", "png", "heic"].contains(($0 as NSString).pathExtension.lowercased()) }.sorted()
        var tried = 0
        for f in files {
            guard tried < 4, let ui = UIImage(contentsOfFile: (root as NSString).appendingPathComponent(f))?.normalizedUp(), let cg = ui.cgImage else { continue }
            var src = CIImage(cgImage: cg)
            let k = min(1, 900 / max(src.extent.width, src.extent.height))
            src = src.transformed(by: CGAffineTransform(scaleX: k, y: k))
            src = src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY))
            let faces = VideoFX.faces(in: src)
            guard let face = faces.max(by: { $0.box.width < $1.box.width }), face.box.width > src.extent.width * 0.12,
                  let mask = VideoFX.personMask(src) else { continue }
            tried += 1
            let size = src.extent.size, rect = CGRect(origin: .zero, size: size)
            // Where the person is (mask strongly on) and isn't (strongly off), sampled on a grid.
            let m = pixels(mask.cropped(to: rect))
            func saturation(_ img: CIImage, person: Bool) -> Double {
                let p = pixels(img)
                var s = 0.0, n = 0
                for y in stride(from: 0, to: p.h, by: 8) {
                    for x in stride(from: 0, to: p.w, by: 8) {
                        let v = m.bytes[(y * m.w + min(x, m.w - 1)) * 4]
                        guard person ? v > 230 : v < 20 else { continue }
                        let i = (y * p.w + x) * 4
                        let r = Double(p.bytes[i]), g = Double(p.bytes[i + 1]), b = Double(p.bytes[i + 2])
                        s += max(r, g, b) - min(r, g, b); n += 1
                    }
                }
                return n > 20 ? s / Double(n) : -1
            }
            var r = VideoFX.Recipe(); r.background = "colorpop"; r.amount = 0.7
            let pop = VideoFX.frame(src, t: 0.5, duration: 4, size: size, kit: VideoFX.Kit(r), beats: [], caption: nil)
            let bgBefore = saturation(src, person: false), bgAfter = saturation(pop, person: false)
            let personBefore = saturation(src, person: true), personAfter = saturation(pop, person: true)
            guard bgBefore > 12, personBefore > 12 else { continue }   // a black-and-white photo proves nothing here
            XCTAssertLessThan(bgAfter, 3, "\(f): colour pop left colour behind the person (\(bgAfter))")
            XCTAssertGreaterThan(personAfter, personBefore * 0.7, "\(f): colour pop greyed the person too")
            var big = VideoFX.Recipe(); big.funny = "bighead"; big.amount = 0.8
            let head = VideoFX.frame(src, t: 0.5, duration: 4, size: size, kit: VideoFX.Kit(big), beats: [], caption: nil)
            let corner = CGRect(x: 0, y: 0, width: size.width * 0.15, height: size.height * 0.15)
            if !corner.intersects(face.box.insetBy(dx: -face.box.width, dy: -face.box.height)) {
                XCTAssertGreaterThan(change(src, head, in: face.box), change(src, head, in: corner) + 3, "\(f): the big head didn't change the face")
            }
        }
        if tried == 0 { throw XCTSkip("no real photo with a clear person") }
    }
}
