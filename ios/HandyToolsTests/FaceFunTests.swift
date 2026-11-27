import XCTest
import CoreImage
import UIKit
import Vision
@testable import HandyTools

/// 26 Nov: Face fun — heads, warps, stickers, skin, moods and body effects for video. Proved on pixels: every effect
/// changes the face it was given and (unless it's a whole-picture mood) leaves the far corner alone; each sticker lands
/// where it belongs (shades on the eyes, a crown above the brows, a moustache under the nose); and the same on real
/// photos of people. Each effect on a drawn face is also saved as a picture to look at (FACEFUN_OUT).
final class FaceFunTests: XCTestCase {
    private let ctx = CIContext(options: [.cacheIntermediates: false])
    private let size = CGSize(width: 720, height: 960)
    private var rect: CGRect { CGRect(origin: .zero, size: size) }
    /// The effects that are meant to change the whole picture (or, for the body ones, well beyond the face).
    private let wholePicture: Set<String> = ["cartoon", "glow", "beautiful", "sunny", "tacky", "wholesome", "longlegs", "tinybody"]

    private func pixels(_ img: CIImage) -> (bytes: [UInt8], w: Int, h: Int) {
        let w = Int(img.extent.width), h = Int(img.extent.height)
        var out = [UInt8](repeating: 0, count: w * h * 4)
        ctx.render(img, toBitmap: &out, rowBytes: w * 4, bounds: img.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return (out, w, h)
    }

    /// Mean absolute change between two same-size pictures inside `r` (Core Image points, y up).
    private func change(_ a: (bytes: [UInt8], w: Int, h: Int), _ b: (bytes: [UInt8], w: Int, h: Int), in r: CGRect) -> Double {
        var sum = 0.0, n = 0
        for y in Int(r.minY)..<Int(r.maxY) where y >= 0 && y < a.h {
            let row = a.h - 1 - y
            for x in Int(r.minX)..<Int(r.maxX) where x >= 0 && x < a.w {
                let i = (row * a.w + x) * 4
                for c in 0..<3 { sum += abs(Double(a.bytes[i + c]) - Double(b.bytes[i + c])) }
                n += 3
            }
        }
        return n == 0 ? 0 : sum / Double(n)
    }

    private func box(_ c: CGPoint, _ half: CGFloat) -> CGRect { CGRect(x: c.x - half, y: c.y - half, width: 2 * half, height: 2 * half) }

    // MARK: - A drawn face with known points

    /// A head-and-shoulders drawing on a patterned wall (so a warp shows everywhere), and where the person is.
    private func drawing() -> (picture: CIImage, person: CIImage) {
        func make(_ draw: (CGContext, Bool) -> Void, mask: Bool) -> CIImage {
            let c = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            draw(c, mask)
            return CIImage(cgImage: c.makeImage()!)
        }
        func scene(_ c: CGContext, _ mask: Bool) {
            func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { mask ? CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1) : CGColor(srgbRed: r, green: g, blue: b, alpha: 1) }
            if mask { c.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)); c.fill(rect) } else {
                c.setFillColor(CGColor(srgbRed: 0.62, green: 0.78, blue: 0.9, alpha: 1)); c.fill(rect)
                c.setStrokeColor(CGColor(srgbRed: 0.4, green: 0.58, blue: 0.75, alpha: 1)); c.setLineWidth(3)
                for x in stride(from: CGFloat(0), through: size.width, by: 60) { c.move(to: CGPoint(x: x, y: 0)); c.addLine(to: CGPoint(x: x, y: size.height)) }
                for y in stride(from: CGFloat(0), through: size.height, by: 60) { c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: size.width, y: y)) }
                c.strokePath()
            }
            // Shoulders and neck.
            c.setFillColor(col(0.2, 0.45, 0.35)); c.fillEllipse(in: CGRect(x: 110, y: -260, width: 500, height: 600))
            c.setFillColor(col(0.86, 0.66, 0.54)); c.fill(CGRect(x: 318, y: 300, width: 84, height: 130))
            // Hair behind, the head, then the fringe.
            c.setFillColor(col(0.22, 0.14, 0.1)); c.fillEllipse(in: CGRect(x: 236, y: 470, width: 248, height: 400))
            c.setFillColor(col(0.93, 0.74, 0.62)); c.fillEllipse(in: CGRect(x: 262, y: 400, width: 196, height: 440))
            c.setFillColor(col(0.22, 0.14, 0.1))
            c.saveGState(); c.clip(to: CGRect(x: 0, y: 742, width: size.width, height: 200)); c.fillEllipse(in: CGRect(x: 250, y: 420, width: 220, height: 436)); c.restoreGState()
            guard !mask else { return }
            // Brows, eyes, nose, mouth.
            c.setStrokeColor(CGColor(srgbRed: 0.2, green: 0.12, blue: 0.08, alpha: 1)); c.setLineWidth(7); c.setLineCap(.round)
            for x in [CGFloat(300), 420] { c.move(to: CGPoint(x: x - 26, y: 640)); c.addLine(to: CGPoint(x: x + 26, y: 644)) }
            c.strokePath()
            for x in [CGFloat(300), 420] {
                c.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)); c.fillEllipse(in: CGRect(x: x - 24, y: 588, width: 48, height: 24))
                c.setFillColor(CGColor(srgbRed: 0.2, green: 0.35, blue: 0.6, alpha: 1)); c.fillEllipse(in: CGRect(x: x - 10, y: 590, width: 20, height: 20))
            }
            c.setStrokeColor(CGColor(srgbRed: 0.7, green: 0.5, blue: 0.42, alpha: 1)); c.setLineWidth(5)
            c.move(to: CGPoint(x: 360, y: 600)); c.addLine(to: CGPoint(x: 350, y: 545)); c.addLine(to: CGPoint(x: 372, y: 540)); c.strokePath()
            c.setFillColor(CGColor(srgbRed: 0.78, green: 0.3, blue: 0.32, alpha: 1)); c.fillEllipse(in: CGRect(x: 310, y: 466, width: 100, height: 28))
        }
        return (make(scene, mask: false), make(scene, mask: true))
    }

    /// The drawn face's points, as Vision would give them.
    private func drawnFace() -> FaceFun.Face {
        let contour = (0...8).map { i -> CGPoint in
            let a = CGFloat.pi + CGFloat(i) * .pi / 8
            return CGPoint(x: 360 + cos(a) * 96, y: 600 + sin(a) * 200)
        }
        func eye(_ x: CGFloat) -> [CGPoint] { [CGPoint(x: x - 24, y: 600), CGPoint(x: x, y: 612), CGPoint(x: x + 24, y: 600), CGPoint(x: x, y: 588)] }
        let lips = [CGPoint(x: 310, y: 480), CGPoint(x: 360, y: 494), CGPoint(x: 410, y: 480), CGPoint(x: 360, y: 466)]
        return FaceFun.face(contour: contour, eyeA: eye(300), eyeB: eye(420), brows: [CGPoint(x: 300, y: 642), CGPoint(x: 420, y: 642)],
                            nose: [CGPoint(x: 360, y: 600), CGPoint(x: 350, y: 545), CGPoint(x: 372, y: 540)], lips: lips)!
    }

    // MARK: - The geometry

    func testAFaceIsReadFromItsPoints() {
        let f = drawnFace()
        XCTAssertEqual(f.roll, 0, accuracy: 0.01)
        XCTAssertEqual(f.up.dx, 0, accuracy: 0.01); XCTAssertEqual(f.up.dy, 1, accuracy: 0.01)
        XCTAssertEqual(f.eyeDistance, 120, accuracy: 0.5)
        XCTAssertEqual(f.chin.y, 400, accuracy: 1); XCTAssertEqual(f.chin.x, 360, accuracy: 1)
        XCTAssertEqual(f.width, 228, accuracy: 40, "cheek to cheek")
        XCTAssertEqual(f.height, 242, accuracy: 2, "brows to chin")
        XCTAssertEqual(f.mouthWidth, 100, accuracy: 1)
        XCTAssertLessThan(f.eyeA.x, f.eyeB.x)
        XCTAssertGreaterThan(f.top.y, 800, "the top of the head is well above the brows")
        XCTAssertNil(FaceFun.face(contour: [], eyeA: [], eyeB: [], brows: [], nose: [], lips: []))
    }

    /// The same face tilted a third of the way over: "up" follows the head, so a hat still sits on top of it.
    func testATiltedHeadKeepsItsOwnUp() {
        let straight = drawnFace(), turn = CGAffineTransform(translationX: 360, y: 560).rotated(by: .pi / 6).translatedBy(x: -360, y: -560)
        func t(_ p: [CGPoint]) -> [CGPoint] { p.map { $0.applying(turn) } }
        let f = FaceFun.face(contour: t(straight.contour), eyeA: t(straight.eyePtsA), eyeB: t(straight.eyePtsB), brows: t([CGPoint(x: 300, y: 642), CGPoint(x: 420, y: 642)]),
                             nose: t([CGPoint(x: 350, y: 545)]), lips: t(straight.lips))!
        XCTAssertEqual(f.roll, .pi / 6, accuracy: 0.02)
        XCTAssertEqual(f.up.dx, -sin(.pi / 6), accuracy: 0.02); XCTAssertEqual(f.up.dy, cos(.pi / 6), accuracy: 0.02)
        XCTAssertEqual(f.height, straight.height, accuracy: 3)
        let top = straight.top.applying(turn)
        XCTAssertEqual(f.top.x, top.x, accuracy: 4); XCTAssertEqual(f.top.y, top.y, accuracy: 4)
        // Upside down: up still runs from the mouth toward the eyes.
        let flip = CGAffineTransform(translationX: 360, y: 560).rotated(by: .pi).translatedBy(x: -360, y: -560)
        let u = FaceFun.face(contour: straight.contour.map { $0.applying(flip) }, eyeA: straight.eyePtsA.map { $0.applying(flip) }, eyeB: straight.eyePtsB.map { $0.applying(flip) },
                             brows: [], nose: [], lips: straight.lips.map { $0.applying(flip) })!
        XCTAssertEqual(u.up.dy, -1, accuracy: 0.02)
    }

    /// When the finder's points can't be trusted the face is laid out from its box: upright, it reads the right way up
    /// with the eyes above the mouth inside the box; tilted, "up" follows the tilt.
    func testAFaceFromItsBoxAlone() throws {
        let box = CGRect(x: 200, y: 300, width: 300, height: 300)
        let f = try XCTUnwrap(FaceFun.face(box: box, roll: 0))
        XCTAssertEqual(f.up.dy, 1, accuracy: 0.01)
        XCTAssertGreaterThan(f.eyeA.y, f.mouth.y); XCTAssertLessThan(f.eyeA.x, f.eyeB.x)
        XCTAssertTrue(box.insetBy(dx: -20, dy: -20).contains(f.chin) && box.contains(f.mouth) && box.contains(f.eyeA))
        XCTAssertEqual(f.eyeDistance, 120, accuracy: 2)
        XCTAssertEqual(f.width, 276, accuracy: 10)
        let t = try XCTUnwrap(FaceFun.face(box: box, roll: .pi / 4))
        XCTAssertEqual(abs(t.roll), .pi / 4, accuracy: 0.02)
        XCTAssertEqual(t.eyeDistance, 120, accuracy: 2)
        // Sensible landmarks pass; drifting ones don't.
        let c = (0...8).map { CGPoint(x: 0.5 + cos(.pi + CGFloat($0) * .pi / 8) * 0.45, y: 0.6 + sin(.pi + CGFloat($0) * .pi / 8) * 0.55) }
        let eyes = [CGPoint(x: 0.3, y: 0.62), CGPoint(x: 0.7, y: 0.62)]
        XCTAssertTrue(FaceFun.sensible(contour: c, eyes: eyes, lips: [CGPoint(x: 0.5, y: 0.25)]))
        XCTAssertFalse(FaceFun.sensible(contour: c.map { CGPoint(x: $0.x * 7.5 - 2, y: $0.y * 8 - 3) }, eyes: eyes, lips: []), "points thousands of faces wide")
        XCTAssertFalse(FaceFun.sensible(contour: c.map { CGPoint(x: 0.5 + ($0.x - 0.5) * 0.5, y: $0.y) }, eyes: eyes, lips: []), "a jaw half the box wide")
        XCTAssertFalse(FaceFun.sensible(contour: c.map { CGPoint(x: 0.5 + ($0.x - 0.5) * 1.2, y: $0.y) }, eyes: eyes, lips: []), "a jaw wider than the box")
    }

    func testAShakyFinderIsSteadied() {
        let f = drawnFace()
        var moved = f
        moved.eyeA.x += 6; moved.eyeB.x += 6; moved.mouth.x += 6; moved.brow.x += 6; moved.nose.x += 6; moved.width += 10
        let s = FaceFun.smoothed([moved], previous: [f])[0]
        XCTAssertEqual(s.eyeA.x - f.eyeA.x, 6 * 0.55, accuracy: 0.05, "a small jump is taken part of the way")
        XCTAssertEqual(s.width - f.width, 10 * 0.55, accuracy: 0.05)
        var far = f; far.eyeA.x += 300; far.eyeB.x += 300; far.mouth.x += 300
        XCTAssertEqual(FaceFun.smoothed([far], previous: [f])[0].eyeA.x, far.eyeA.x, "someone else's face isn't dragged toward the last one")
    }

    func testTheWarpKernelsAreInTheApp() {
        XCTAssertTrue(FaceFun.kernelsLoaded, "FaceWarps.ci.metal didn't build into the app's default.metallib")
    }

    func testTheListHasEveryGroupAndNoDoubles() {
        XCTAssertEqual(Set(FaceFun.effects.map(\.id)).count, FaceFun.effects.count)
        for g in FaceFun.Group.allCases { XCTAssertGreaterThanOrEqual(FaceFun.effects.filter { $0.group == g }.count, 2, g.rawValue) }
        XCTAssertGreaterThanOrEqual(FaceFun.effects.count, 35)
        for e in FaceFun.effects { XCTAssertLessThanOrEqual(e.name.count, 22, "\(e.id): the name must fit one line under its picture") }
    }

    // MARK: - Every effect on the drawn face

    func testEveryEffectChangesTheFaceAndStickersLandWhereTheyBelong() throws {
        let (pic, person) = drawing(), f = drawnFace()
        let before = pixels(pic)
        let corner = CGRect(x: 0, y: 0, width: 80, height: 80)
        let headAndRoom = CGRect(x: 180, y: 380, width: 360, height: 560)
        var shots: [(String, CIImage)] = [("As filmed", pic)]
        var at: [String: (eyes: Double, aboveHead: Double, underNose: Double, mouth: Double, nose: Double)] = [:]
        for e in FaceFun.effects {
            var scene = FaceFun.Scene(faces: [f], body: nil, person: FaceFun.needsPerson(e.id) ? person : nil)
            if e.id == "longlegs" { scene = FaceFun.Scene(faces: [f], body: FaceFun.Body(hips: CGPoint(x: 360, y: 300), neck: CGPoint(x: 360, y: 400), ankles: nil), person: nil) }
            let out = FaceFun.apply(e.id, to: pic, scene: scene, t: 0.8, amount: 0.7)
            XCTAssertEqual(out.extent, rect, "\(e.id) changed the picture's size")
            let after = pixels(out)
            let onHead = change(before, after, in: headAndRoom), far = change(before, after, in: corner)
            print("VIDEOFX|facefun-drawn|\(e.id)|head=\(String(format: "%.1f", onHead))|corner=\(String(format: "%.1f", far))")
            if e.id == "longlegs" {
                // With the head nearly at the top there's little room, so the legs grow a little and the head moves up with them.
                XCTAssertGreaterThan(change(before, after, in: CGRect(x: 110, y: 40, width: 500, height: 300)), 0.5, "long legs changed nothing")
            } else {
                XCTAssertGreaterThan(onHead, 0.8, "\(e.id) did nothing to the face")
            }
            if !wholePicture.contains(e.id) { XCTAssertLessThan(far, 0.6, "\(e.id) changed the far corner of the picture") }
            at[e.id] = (change(before, after, in: box(CGPoint(x: 360, y: 600), 40).insetBy(dx: -60, dy: 0)), change(before, after, in: CGRect(x: 280, y: 800, width: 160, height: 120)),
                        change(before, after, in: CGRect(x: 310, y: 496, width: 100, height: 36)), change(before, after, in: box(f.mouth, 30)), change(before, after, in: box(f.nose, 22)))
            shots.append((e.name, out))
        }
        // Stickers sit where they belong.
        for id in ["sunglasses", "heartglasses"] {
            let a = try XCTUnwrap(at[id])
            // Hearts cover less of the band across the eyes than square lenses do.
            XCTAssertGreaterThan(a.eyes, id == "sunglasses" ? 40 : 25, "\(id) isn't on the eyes"); XCTAssertLessThan(a.mouth, 3, "\(id) reaches the mouth")
        }
        for id in ["crown", "partyhat", "bunny", "halo"] {
            let a = try XCTUnwrap(at[id])
            XCTAssertGreaterThan(a.aboveHead, 15, "\(id) isn't on top of the head"); XCTAssertLessThan(a.eyes, 6, "\(id) covers the eyes")
        }
        let m = try XCTUnwrap(at["moustache"])
        XCTAssertGreaterThan(m.underNose, 40, "the moustache isn't under the nose"); XCTAssertLessThan(m.eyes, 2); XCTAssertLessThan(m.aboveHead, 1)
        XCTAssertGreaterThan(try XCTUnwrap(at["clown"]).nose, 40, "the clown nose isn't on the nose")
        XCTAssertLessThan(try XCTUnwrap(at["clown"]).eyes, 18, "the clown nose covers the eyes")
        XCTAssertGreaterThan(try XCTUnwrap(at["dog"]).nose, 30, "the puppy has no nose")
        // No face, nothing to do — and nothing breaks.
        for e in FaceFun.effects where !wholePicture.contains(e.id) {
            let out = FaceFun.apply(e.id, to: pic, scene: FaceFun.Scene(), t: 0.3, amount: 1)
            XCTAssertLessThan(change(before, pixels(out), in: rect), 0.01, "\(e.id) changed a picture with no face in it")
        }
        save(shots, name: "facefun")
    }

    /// A sticker turns with the head: on a face tilted a third of the way over, the shades still cover both eyes.
    func testStickersTurnWithTheHead() throws {
        let (pic, _) = drawing(), straight = drawnFace()
        let turn = CGAffineTransform(translationX: 360, y: 560).rotated(by: .pi / 6).translatedBy(x: -360, y: -560)
        let tilted = pic.transformed(by: turn).cropped(to: rect).composited(over: CIImage(color: CIColor(red: 0.62, green: 0.78, blue: 0.9)).cropped(to: rect))
        func t(_ p: [CGPoint]) -> [CGPoint] { p.map { $0.applying(turn) } }
        let f = try XCTUnwrap(FaceFun.face(contour: t(straight.contour), eyeA: t(straight.eyePtsA), eyeB: t(straight.eyePtsB), brows: t([CGPoint(x: 300, y: 642), CGPoint(x: 420, y: 642)]),
                                           nose: t([CGPoint(x: 350, y: 545)]), lips: t(straight.lips)))
        let before = pixels(tilted)
        var shots: [(String, CIImage)] = [("Tilted", tilted)]
        for id in ["sunglasses", "crown", "moustache", "bunny", "bald", "cone", "wholesome", "tacky"] {
            let out = FaceFun.apply(id, to: tilted, scene: FaceFun.Scene(faces: [f]), t: 0.8, amount: 0.7)
            shots.append((id, out))
            guard id == "sunglasses" else { continue }
            let after = pixels(out)
            for e in [f.eyeA, f.eyeB] { XCTAssertGreaterThan(change(before, after, in: box(e, 16)), 60, "the shades slid off a tilted eye") }
            XCTAssertLessThan(change(before, after, in: box(f.mouth, 24)), 3)
        }
        save(shots, name: "facefun-tilted")
    }

    // MARK: - Real photos of people

    func testEveryEffectOnRealFaces() throws {
        guard let root = ProcessInfo.processInfo.environment["REAL_PHOTOS"] else { throw XCTSkip("private photos not decrypted") }
        let files = (FileManager.default.enumerator(atPath: root)?.allObjects as? [String] ?? []).filter { ["jpg", "jpeg", "png", "heic"].contains(($0 as NSString).pathExtension.lowercased()) }.sorted()
        var tried = 0
        for file in files {
            guard tried < 4, let ui = UIImage(contentsOfFile: (root as NSString).appendingPathComponent(file))?.normalizedUp(), let cg = ui.cgImage else { continue }
            var src = CIImage(cgImage: cg)
            let k = min(1, 900 / max(src.extent.width, src.extent.height))
            src = src.transformed(by: CGAffineTransform(scaleX: k, y: k))
            src = src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY)).cropped(to: CGRect(x: 0, y: 0, width: floor(src.extent.width), height: floor(src.extent.height)))
            // The small picture itself, not a recipe that re-reads the full-size photo on every render (that ran the
            // build machine out of room: its renderer gave up part-way and left blank pictures).
            guard let small = ctx.createCGImage(src, from: src.extent) else { continue }
            src = CIImage(cgImage: small)
            let found = FaceFun.faces(in: src)
            guard let f = found.first, f.width > src.extent.width * 0.12 else { continue }
            print("VIDEOFX|facefun-real|photo\(tried + 1)|frame \(Int(src.extent.width))×\(Int(src.extent.height))|faces \(found.count)|width \(Int(f.width))|height \(Int(f.height))|eyes \(Int(f.eyeDistance))|roll \(String(format: "%.2f", f.roll))")
            tried += 1
            // The finder gives the same face every time it's asked about the same picture (round 13: it was handing over
            // a face that grew on every call, until stickers landed off-screen and warps tore the picture).
            var widths: [Int] = []
            for _ in 0..<6 {
                var box = CGRect.zero
                let w = FaceFun.faces(in: src, boxes: { box = $0 }).first.map { Int($0.width) } ?? -1
                widths.append(w)
                print("VIDEOFX|facefun-repeat|photo\(tried)|width \(w)|box \(Int(box.minX)),\(Int(box.minY)) \(Int(box.width))×\(Int(box.height))")
            }
            XCTAssertLessThanOrEqual((widths.max() ?? 0) - (widths.min() ?? 0), max(4, Int(f.width) / 20), "photo \(tried): the finder's face changes size when asked again: \(widths)")
            let frame = src.extent, before = pixels(src)
            XCTAssertGreaterThan(f.up.dy, 0.5, "photo \(tried): an upright face read as lying down")
            XCTAssertTrue(f.chin.y < f.mouth.y && f.mouth.y < f.nose.y + f.height * 0.1 && f.nose.y < f.brow.y, "photo \(tried): chin, mouth, nose and brows are out of order")
            XCTAssertLessThan(abs(f.eyeDistance / f.width - 0.45), 0.2, "photo \(tried): eyes \(f.eyeDistance) apart on a face \(f.width) wide")
            // The corner furthest from the face.
            let cx: CGFloat = f.center.x < frame.midX ? frame.maxX - 60 : 0, cy: CGFloat = f.center.y < frame.midY ? frame.maxY - 60 : 0
            let corner = CGRect(x: cx, y: cy, width: 60, height: 60)
            let clear = hypot(corner.midX - f.center.x, corner.midY - f.center.y) > f.width * 2.6
            let head = CGRect(x: f.center.x - f.width, y: f.chin.y - f.height * 0.3, width: f.width * 2, height: f.height * 2.4).intersection(frame)
            let memory = FaceFun.Memory()
            for e in FaceFun.effects {
                let started = Date()
                let scene = FaceFun.scene(src, for: e.id, t: 0.5, memory: memory, person: VideoFX.personMask(src))
                let out = FaceFun.apply(e.id, to: src, scene: scene, t: 0.5, amount: 0.7, memory: memory)
                let after = pixels(out)
                let ms = Int(Date().timeIntervalSince(started) * 1000)
                let onHead = change(before, after, in: head), far = change(before, after, in: corner)
                print("VIDEOFX|facefun-real|photo\(tried)|\(e.id)|faces=\(scene.faces.count)|head=\(String(format: "%.1f", onHead))|corner=\(String(format: "%.1f", far))|\(ms)ms")
                XCTAssertEqual(out.extent, frame, "\(e.id) changed the picture's size")
                if e.id == "longlegs" { continue }                 // needs a whole body in the shot; proved on the drawing
                XCTAssertGreaterThan(onHead, 0.6, "photo \(tried): \(e.id) did nothing to the face")
                if clear, !wholePicture.contains(e.id) { XCTAssertLessThan(far, 1.0, "photo \(tried): \(e.id) changed the far corner") }
                // Nothing may break the picture: no see-through holes, no black frame.
                var holes = 0, total = 0
                for i in stride(from: 3, to: after.bytes.count, by: 4 * 97) { total += 1; if after.bytes[i] < 250 { holes += 1 } }
                XCTAssertLessThan(Double(holes) / Double(max(1, total)), 0.001, "photo \(tried): \(e.id) left see-through holes")
            }
            // Their own photo behind them (a plain red one here): red where the person isn't, the person untouched.
            if let mask = VideoFX.personMask(src) {
                let red = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200)).image { c in UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 300, height: 200)) }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("facefun-backdrop.jpg")
                try XCTUnwrap(red.jpegData(compressionQuality: 0.95)).write(to: url)
                var r = VideoFX.Recipe(); r.background = "photo"; r.backdrop = url
                let out = VideoFX.frame(src, t: 0.5, duration: 4, size: frame.size, kit: VideoFX.Kit(r), beats: [], caption: nil)
                let m = pixels(mask.cropped(to: frame)), o = pixels(out)
                var behind = 0, isRed = 0, person = 0, same = 0
                for y in stride(from: 0, to: min(m.h, o.h), by: 6) {
                    for x in stride(from: 0, to: min(m.w, o.w), by: 6) {
                        let v = m.bytes[(y * m.w + x) * 4], i = (y * o.w + x) * 4
                        if v < 15 { behind += 1; if o.bytes[i] > 190, o.bytes[i + 1] < 80, o.bytes[i + 2] < 80 { isRed += 1 } }
                        if v > 240 { person += 1; if (0..<3).allSatisfy({ abs(Int(o.bytes[i + $0]) - Int(before.bytes[i + $0])) < 14 }) { same += 1 } }
                    }
                }
                print("VIDEOFX|studio-backdrop|photo\(tried)|behind=\(isRed)/\(behind)|person=\(same)/\(person)")
                if behind > 50 { XCTAssertGreaterThan(Double(isRed) / Double(behind), 0.95, "photo \(tried): their photo isn't behind the person") }
                if person > 50 { XCTAssertGreaterThan(Double(same) / Double(person), 0.9, "photo \(tried): the person was painted over") }
            }
        }
        if tried == 0 { throw XCTSkip("no real photo with a clear face") }
    }

    // MARK: - Pictures to look at

    /// Saves the shots as sheets of twelve (four across), each with its name, when FACEFUN_OUT is set.
    private func save(_ shots: [(String, CIImage)], name: String) {
        guard let dir = ProcessInfo.processInfo.environment["FACEFUN_OUT"] else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let cell = CGSize(width: 360, height: 480), label: CGFloat = 34, cols = 4, per = 12
        for (page, start) in stride(from: 0, to: shots.count, by: per).enumerated() {
            let part = Array(shots[start..<min(shots.count, start + per)])
            let rows = Int(ceil(Double(part.count) / Double(cols)))
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
            let sheet = UIGraphicsImageRenderer(size: CGSize(width: cell.width * CGFloat(cols), height: (cell.height + label) * CGFloat(rows)), format: fmt).image { r in
                UIColor.white.setFill(); r.fill(CGRect(x: 0, y: 0, width: cell.width * CGFloat(cols), height: (cell.height + label) * CGFloat(rows)))
                for (i, shot) in part.enumerated() {
                    let x = CGFloat(i % cols) * cell.width, y = CGFloat(i / cols) * (cell.height + label)
                    if let cg = ctx.createCGImage(shot.1, from: shot.1.extent) { UIImage(cgImage: cg).draw(in: CGRect(x: x, y: y, width: cell.width, height: cell.height)) }
                    (shot.0 as NSString).draw(at: CGPoint(x: x + 8, y: y + cell.height + 6), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: UIColor.black])
                }
            }
            try? sheet.jpegData(compressionQuality: 0.85)?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name)-\(page + 1).jpg"))
        }
    }
}
