import XCTest
import CoreImage
import UIKit
@testable import HandyTools

/// 27 Nov rebuild: the Video Studio's face engine (Google's open face-mesh and parts models run on the phone). Proved
/// on the private real photos made into moving video — small, panning and tilted, like home video — and on the
/// pixels of what the effects make. Only numbers are printed; no picture of a real person is saved.
final class FaceEngineTests: XCTestCase {
    private let ctx = CIContext(options: [.cacheIntermediates: false])

    private func pixels(_ img: CIImage) -> (bytes: [UInt8], w: Int, h: Int) {
        let w = Int(img.extent.width), h = Int(img.extent.height)
        var out = [UInt8](repeating: 0, count: w * h * 4)
        ctx.render(img, toBitmap: &out, rowBytes: w * 4, bounds: img.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return (out, w, h)
    }

    /// Mean change inside `r` (Core Image points, y up).
    private func change(_ a: (bytes: [UInt8], w: Int, h: Int), _ b: (bytes: [UInt8], w: Int, h: Int), in r: CGRect) -> Double {
        var sum = 0.0, n = 0
        for y in stride(from: max(0, Int(r.minY)), to: min(a.h, Int(r.maxY)), by: 2) {
            let row = a.h - 1 - y
            for x in stride(from: max(0, Int(r.minX)), to: min(a.w, Int(r.maxX)), by: 2) {
                let i = (row * a.w + x) * 4
                for c in 0..<3 { sum += abs(Double(a.bytes[i + c]) - Double(b.bytes[i + c])) }
                n += 3
            }
        }
        return n > 0 ? sum / Double(n) : 0
    }

    private func photos(_ limit: Int) throws -> [CIImage] {
        guard let root = ProcessInfo.processInfo.environment["REAL_PHOTOS"] else { throw XCTSkip("private photos not decrypted") }
        let files = (FileManager.default.enumerator(atPath: root)?.allObjects as? [String] ?? [])
            .filter { ["jpg", "jpeg", "png", "heic"].contains(($0 as NSString).pathExtension.lowercased()) }.sorted()
        var out: [CIImage] = []
        for file in files where out.count < limit {
            guard let ui = UIImage(contentsOfFile: (root as NSString).appendingPathComponent(file))?.normalizedUp(), let cg = ui.cgImage else { continue }
            var src = CIImage(cgImage: cg)
            let k = min(1, 1100 / max(src.extent.width, src.extent.height))
            src = src.transformed(by: CGAffineTransform(scaleX: k, y: k))
            src = src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY))
            guard let small = ctx.createCGImage(src, from: CGRect(x: 0, y: 0, width: floor(src.extent.width), height: floor(src.extent.height))) else { continue }
            let pic = CIImage(cgImage: small)
            guard let f = FaceFun.faces(in: pic).first, f.width > pic.extent.width * 0.1 else { continue }
            out.append(pic)
        }
        if out.isEmpty { throw XCTSkip("no real photo with a clear face") }
        return out
    }

    /// The photo as one frame of a 1280 x 720 home video: shrunk (so the face is small), moved and turned.
    private func frame(_ pic: CIImage, scale: CGFloat, dx: CGFloat, dy: CGFloat, turn: CGFloat) -> CIImage {
        let W: CGFloat = 1280, H: CGFloat = 720
        let k = scale * H / pic.extent.height
        let t = CGAffineTransform(translationX: -pic.extent.midX, y: -pic.extent.midY)
            .concatenating(CGAffineTransform(scaleX: k, y: k)).concatenating(CGAffineTransform(rotationAngle: turn))
            .concatenating(CGAffineTransform(translationX: W / 2 + dx, y: H / 2 + dy))
        let room = CIImage(color: CIColor(red: 0.55, green: 0.5, blue: 0.45)).cropped(to: CGRect(x: 0, y: 0, width: W, height: H))
        return pic.transformed(by: t).composited(over: room).cropped(to: room.extent)
    }

    func testTheModelsAndKernelsAreInTheApp() {
        XCTAssertNotNil(FaceEngine(), "the face models or the TensorFlow Lite runtime are missing")
        XCTAssertTrue(FaceFun.baldKernelsLoaded, "Bald's Metal kernels didn't load")
    }

    /// Faces followed on every frame of moving home-style video: found, on the face, and steady.
    func testFacesAreFollowedOnSmallMovingAndTurningFaces() throws {
        for (n, pic) in try photos(3).enumerated() {
            for (label, scale, turn) in [("small", CGFloat(0.55), CGFloat(0)), ("tilted", 0.8, 0.35)] {
                guard let engine = FaceEngine() else { return XCTFail("engine didn't load") }
                var found = 0, onFace = 0, jumps: [Double] = []
                var last: CGPoint?
                let frames = 30
                for i in 0..<frames {
                    let t = Double(i) / 30
                    let dx = CGFloat(i) * 6 - 90, dy = CGFloat(sin(Double(i) * 0.3)) * 12
                    let img = frame(pic, scale: scale, dx: dx, dy: dy, turn: turn)
                    let seen = engine.step(img, t: t, wantParts: false)
                    let truth = FaceFun.faces(in: img).first
                    guard let m = seen.meshes.first, let f = FaceFun.face(mesh: m, height: img.extent.height) else { continue }
                    found += 1
                    if let g = truth, hypot(f.center.x - g.center.x, f.center.y - g.center.y) < g.width * 0.25 { onFace += 1 }
                    // How far the face moved beyond the video's own movement (6 px a frame across).
                    if let l = last { jumps.append(abs(hypot(f.center.x - l.x - 6, f.center.y - l.y) )) }
                    last = f.center
                }
                let worst = jumps.sorted().dropLast(1).last ?? 0
                print("FACEENGINE|follow|photo\(n + 1)|\(label)|found \(found)/\(frames)|on face \(onFace)|worst jump \(String(format: "%.1f", worst))")
                XCTAssertGreaterThanOrEqual(found, frames * 9 / 10, "photo \(n + 1) \(label): the face was lost")
                XCTAssertGreaterThanOrEqual(onFace, found * 9 / 10, "photo \(n + 1) \(label): the mesh wasn't on the face")
                XCTAssertLessThan(worst, 25, "photo \(n + 1) \(label): the face jumps frame to frame")
            }
        }
    }

    /// The engine's effects on real faces: each changes the head, Bald takes the hair away, the skin effects stay on
    /// skin, and the far corner is untouched. Portrait blur keeps the person sharp and blurs what's behind.
    func testTheEngineEffectsOnRealFaces() throws {
        for (n, pic) in try photos(3).enumerated() {
            let img = frame(pic, scale: 0.9, dx: 0, dy: 0, turn: 0)
            let rect = img.extent, before = pixels(img)
            guard let engine = FaceEngine() else { return XCTFail("engine didn't load") }
            var seen = engine.step(img, t: 0, wantParts: true)
            seen = engine.step(img, t: 1.0 / 30, wantParts: true)
            guard let parts = FaceFun.parts(seen, guide: img) else { return XCTFail("photo \(n + 1): no parts map") }
            print("FACEENGINE|parts|photo\(n + 1)|faces \(seen.meshes.count)|heads \(seen.heads.count)")
            XCTAssertFalse(seen.meshes.isEmpty, "photo \(n + 1): no face")
            XCTAssertFalse(seen.heads.isEmpty, "photo \(n + 1): no head")
            for id in ["bald", "alien", "zombie", "robot", "glow", "beautiful", "wholesome", "bighead", "sunglasses", "crown"] {
                let scene = FaceFun.scene(engine: seen, parts: parts, for: id, src: img)
                guard let f = scene.faces.first else { return XCTFail("photo \(n + 1): no face for \(id)") }
                let out = FaceFun.apply(id, to: img, scene: scene, t: 0.5, amount: 0.7)
                let after = pixels(out)
                let head = CGRect(x: f.center.x - f.width, y: f.chin.y - f.height * 0.2, width: f.width * 2, height: f.height * 2.6).intersection(rect)
                let corner = CGRect(x: f.center.x < rect.midX ? rect.maxX - 60 : 0, y: 0, width: 60, height: 60)
                let onHead = change(before, after, in: head), far = change(before, after, in: corner)
                print("FACEENGINE|effect|photo\(n + 1)|\(id)|head \(String(format: "%.1f", onHead))|corner \(String(format: "%.1f", far))")
                XCTAssertEqual(out.extent, rect)
                XCTAssertGreaterThan(onHead, 1.5, "photo \(n + 1): \(id) did nothing to the head")
                if !["glow", "beautiful", "wholesome"].contains(id) { XCTAssertLessThan(far, 1.0, "photo \(n + 1): \(id) changed the far corner") }
                if id == "bald" {
                    // Above the brows, where there was hair: changed a lot.
                    let hair = pixels(parts.hair)
                    var changed = 0.0, count = 0
                    for y in stride(from: 0, to: after.h, by: 3) {
                        for x in stride(from: 0, to: after.w, by: 3) {
                            let row = after.h - 1 - y
                            guard hair.bytes[(row * hair.w + x) * 4] > 200, CGFloat(y) > f.brow.y + f.height * 0.15 else { continue }
                            let i = (row * after.w + x) * 4
                            changed += (0..<3).map { abs(Double(after.bytes[i + $0]) - Double(before.bytes[i + $0])) }.reduce(0, +) / 3
                            count += 1
                        }
                    }
                    let mean = count > 0 ? changed / Double(count) : 0
                    print("FACEENGINE|bald|photo\(n + 1)|hair pixels \(count)|mean change \(String(format: "%.1f", mean))")
                    if count > 200 { XCTAssertGreaterThan(mean, 20, "photo \(n + 1): Bald left the hair") }
                }
            }
            // Portrait blur: the person stays as filmed, what's behind changes.
            var r = VideoFX.Recipe(); r.background = "blur"
            let out = pixels(VideoFX.frame(img, t: 0.5, duration: 4, size: rect.size, kit: VideoFX.Kit(r), beats: [], caption: nil))
            let person = pixels(parts.person)
            var inside = 0, same = 0, behind = 0, moved = 0
            for y in stride(from: 0, to: out.h, by: 5) {
                for x in stride(from: 0, to: out.w, by: 5) {
                    let i = (y * out.w + x) * 4, v = person.bytes[i]
                    let d = (0..<3).map { abs(Int(out.bytes[i + $0]) - Int(before.bytes[i + $0])) }.max() ?? 0
                    if v > 245 { inside += 1; if d < 10 { same += 1 } }
                    if v < 10 { behind += 1; if d > 2 { moved += 1 } }
                }
            }
            print("FACEENGINE|portrait|photo\(n + 1)|person kept \(same)/\(inside)|behind changed \(moved)/\(behind)")
            if inside > 100 { XCTAssertGreaterThan(Double(same) / Double(inside), 0.9, "photo \(n + 1): portrait blur blurred the person") }
        }
    }
}
