import XCTest
import UIKit
@testable import HandyTools

/// What each photo tool actually hands the user, checked on real photos (runs in the QA lab; skipped elsewhere).
/// Every check measures the OUTPUT again, independently of what the tool says about itself.
///  • Passport: the head and eye line in the finished photo, re-measured, must sit inside each country's limits,
///    the background must be plain, and the file the right size — on a close selfie and on bad versions of it.
///  • Fit It: every real photo lands under the size asked for, still opens, and keeps a usable size.
///  • Cut-out (stickers): a person is lifted cleanly — background see-through, the person solid.
final class ToolOutputQualityTests: XCTestCase {
    private var root: URL? { ProcessInfo.processInfo.environment["REAL_PHOTOS"].map { URL(fileURLWithPath: $0) } }
    private var reportURL: URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["ACCURACY_REPORT"] ?? NSTemporaryDirectory() + "accuracy.txt") }
    private func report(_ lines: [String]) { RealPhotoAccuracyTests.append(lines, to: reportURL); lines.forEach { print("ACC| " + $0) } }

    private func privatePhotos(_ prefix: String? = nil) throws -> [(String, UIImage)] {
        guard let root else { throw XCTSkip("runs in the QA lab") }
        let dir = root.appendingPathComponent("private")
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).sorted()
            .filter { prefix == nil || $0.hasPrefix(prefix!) }
        let out = names.compactMap { n in UIImage(contentsOfFile: dir.appendingPathComponent(n).path).map { (n, $0) } }
        guard !out.isEmpty else { throw XCTSkip("private photos not decrypted") }
        return out
    }

    /// A smaller head in a bigger, busier frame — the usual phone selfie taken at arm's length.
    static func farther(_ img: UIImage) -> UIImage {
        let s = img.size
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: s.width * 1.8, height: s.height * 1.8), format: fmt).image { ctx in
            UIColor(red: 0.55, green: 0.6, blue: 0.5, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: CGSize(width: s.width * 1.8, height: s.height * 1.8)))
            UIColor(red: 0.35, green: 0.3, blue: 0.25, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: s.height * 1.1, width: s.width * 1.8, height: s.height * 0.7))
            img.draw(in: CGRect(x: s.width * 0.4, y: s.height * 0.35, width: s.width, height: s.height))
        }
    }

    // MARK: passport

    func testPassportPhotosMeetEachCountrysRules() throws {
        let faces = try privatePhotos("face-")
        var lines = ["PASSPORT\tphoto\tcountry\tvariant\thead mm (limits)\teyes mm (limits)\tbackground\tsize\tscore\t| what failed"]
        var good = 0.0, n = 0.0
        for (name, face) in faces {
            let variants: [(String, UIImage)] = [("as taken", face), ("tilted", ToughPhotoTests.trouble(face, .tilt)), ("dim", ToughPhotoTests.trouble(face, .dim)),
                                                 ("low-res", ToughPhotoTests.trouble(face, .lowres)), ("farther away", Self.farther(face))]
            for spec in PassportPhoto.specs {
                for (v, img) in variants {
                    n += 1
                    guard let made = PassportPhoto.make(img, spec: spec), let cg = made.image.cgImage else {
                        lines.append("\(name)\t\(spec.id)\t\(v)\t—\t—\t—\t—\t—\t| no photo made"); continue
                    }
                    // Re-measure the finished photo ourselves.
                    var fails: [String] = []
                    let sizeOK = abs(CGFloat(cg.width) - spec.px.width) <= 1 && abs(CGFloat(cg.height) - spec.px.height) <= 1
                    if !sizeOK { fails.append("file is \(cg.width)×\(cg.height), should be \(Int(spec.px.width))×\(Int(spec.px.height))") }
                    var headText = "—", eyeText = "—"
                    if let f = PassportPhoto.analyze(cg) {
                        let head = Double(f.chin.y - f.crown.y) / spec.pxPerMM
                        headText = String(format: "%.1f (%@–%@)", head, PassportPhoto.fmt(spec.head.lowerBound), PassportPhoto.fmt(spec.head.upperBound))
                        // Allow 1 mm for the measuring itself.
                        if head < spec.head.lowerBound - 1 || head > spec.head.upperBound + 1 { fails.append("head \(String(format: "%.1f", head)) mm") }
                        if let eyes = spec.eyes {
                            let e = Double(spec.px.height - f.eyeY) / spec.pxPerMM
                            eyeText = String(format: "%.1f (%@–%@)", e, PassportPhoto.fmt(eyes.lowerBound), PassportPhoto.fmt(eyes.upperBound))
                            if e < eyes.lowerBound - 1 || e > eyes.upperBound + 1 { fails.append("eyes \(String(format: "%.1f", e)) mm") }
                        }
                        if abs(f.roll) > 3 { fails.append("head still tilted \(Int(f.roll))°") }
                    } else { fails.append("no face found in the finished photo") }
                    // Background: the top corners must be plain and close to the country's colour (unless the
                    // country asks for unaltered photos, where the background is left as it was).
                    var bgText = "kept"
                    if made.options.background {
                        let px = Self.pixels(cg, at: [CGPoint(x: 6, y: 6), CGPoint(x: cg.width - 7, y: 6)])
                        let want = spec.background == .white ? 255.0 : 235.0
                        let off = px.map { abs($0 - want) }.max() ?? 255
                        bgText = off < 18 ? "plain" : "off by \(Int(off))"
                        if off >= 18 { fails.append("background not plain") }
                    }
                    if fails.isEmpty { good += 1 }
                    lines.append("\(name)\t\(spec.id)\t\(v)\t\(headText)\t\(eyeText)\t\(bgText)\t\(sizeOK ? "ok" : "wrong")\t\(made.score)\t| \(fails.joined(separator: "; "))")
                }
            }
        }
        lines.insert(String(format: "SCORE passport n=%.0f %.3f", n, good / max(1, n)), at: 0)
        report(lines)
    }

    /// Mean of R, G, B at each point (top-left origin).
    static func pixels(_ cg: CGImage, at points: [CGPoint]) -> [Double] {
        let w = cg.width, h = cg.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return points.map { p in
            let x = min(max(Int(p.x), 0), w - 1), y = min(max(Int(p.y), 0), h - 1)
            let o = (y * w + x) * 4
            return (Double(buf[o]) + Double(buf[o + 1]) + Double(buf[o + 2])) / 3
        }
    }

    static func alpha(_ cg: CGImage, at points: [CGPoint]) -> [Int] {
        let w = cg.width, h = cg.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return points.map { p in Int(buf[(min(max(Int(p.y), 0), h - 1) * w + min(max(Int(p.x), 0), w - 1)) * 4 + 3]) }
    }

    // MARK: Fit It

    func testFitItLandsUnderTheLimitAndKeepsThePhotoUsable() async throws {
        let photos = try privatePhotos()
        var lines = ["FIT IT\tphoto\ttarget\tgot\tlong side\t| problem"]
        var good = 0.0, n = 0.0
        for (name, img) in photos {
            for (target, minSide) in [(100_000, 600), (500_000, 1000)] {
                n += 1
                let d = await SizeTarget.image(img, targetBytes: target)
                var fails: [String] = []
                let out = d.flatMap { UIImage(data: $0) }
                if d == nil { fails.append("nothing made") }
                if let d, d.count > target { fails.append("over the limit") }
                if d != nil, out == nil { fails.append("won't open") }
                let side = out.map { Int(max($0.size.width * $0.scale, $0.size.height * $0.scale)) } ?? 0
                let original = Int(max(img.size.width * img.scale, img.size.height * img.scale))
                if out != nil, side < min(minSide, original) { fails.append("shrunk to \(side) px — too small to read") }
                if fails.isEmpty { good += 1 }
                lines.append("\(name)\t\(target / 1000) KB\t\(d.map { "\($0.count / 1000) KB" } ?? "—")\t\(side)\t| \(fails.joined(separator: "; "))")
            }
        }
        lines.insert(String(format: "SCORE fitit n=%.0f %.3f", n, good / max(1, n)), at: 0)
        report(lines)
    }

    // MARK: cut-out (stickers, Studio)

    func testCutoutLiftsAPersonCleanly() throws {
        let faces = try privatePhotos("face-")
        var lines = ["CUT-OUT\tphoto\tvariant\tbackground clear\tperson solid\t| problem"]
        var good = 0.0, n = 0.0
        for (name, face) in faces {
            for (v, img) in [("as taken", face), ("farther away", Self.farther(face)), ("dim", ToughPhotoTests.trouble(face, .dim))] {
                n += 1
                guard let cut = ImageStudio.cutout(img), let cg = cut.cgImage else {
                    lines.append("\(name)\t\(v)\t—\t—\t| no cut-out (subject lifting may not run in the simulator)"); continue
                }
                let w = CGFloat(cg.width), h = CGFloat(cg.height)
                let corners = Self.alpha(cg, at: [CGPoint(x: 3, y: 3), CGPoint(x: w - 4, y: 3)])
                let centre = Self.alpha(cg, at: [CGPoint(x: w / 2, y: h * 0.45)])
                let clear = (corners.max() ?? 255) < 30, solid = (centre.first ?? 0) > 230
                if clear && solid { good += 1 }
                lines.append("\(name)\t\(v)\t\(clear ? 1 : 0)\t\(solid ? 1 : 0)\t| \(clear ? "" : "background left in the corners ") \(solid ? "" : "holes in the person")")
            }
        }
        lines.insert(String(format: "SCORE cutout n=%.0f %.3f", n, good / max(1, n)), at: 0)
        report(lines)
    }
}
