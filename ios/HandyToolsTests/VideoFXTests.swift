import XCTest
import CoreImage
import AVFoundation
@testable import HandyTools

final class VideoFXTests: XCTestCase {
    /// Nothing at "how much" zero; more and more the further it goes; every look really changes colour.
    func testLooksGrowWithHowMuch() {
        func diff(_ a: Data, _ b: Data) -> Double {
            let x = a.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }, y = b.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
            return zip(x, y).reduce(0) { $0 + Double(abs($1.0 - $1.1)) } / Double(x.count)
        }
        let plain = VideoFX.cube("none", amount: 1, size: 8)
        for look in VideoFX.looks.map(\.id) where look != "none" {
            XCTAssertEqual(diff(VideoFX.cube(look, amount: 0, size: 8), plain), 0, accuracy: 1e-6, look)
            let some = diff(VideoFX.cube(look, amount: 0.3, size: 8), plain), all = diff(VideoFX.cube(look, amount: 1, size: 8), plain)
            XCTAssertGreaterThan(all, 0.015, "\(look) barely changes anything")
            XCTAssertGreaterThan(all, some * 2, look)
        }
        XCTAssertEqual(VideoFX.cube("cinema", amount: 1, size: 8).count, 8 * 8 * 8 * 4 * 4)
        // Black and white really is.
        let g = VideoFX.grade("noir", (0.9, 0.2, 0.1))
        XCTAssertEqual(g.r, g.g, accuracy: 0.04); XCTAssertEqual(g.g, g.b, accuracy: 0.06)
        // Golden is warmer, moonlight cooler.
        let gold = VideoFX.grade("golden", (0.5, 0.5, 0.5)), moon = VideoFX.grade("moon", (0.5, 0.5, 0.5))
        XCTAssertGreaterThan(gold.r, gold.b + 0.1); XCTAssertGreaterThan(moon.b, moon.r + 0.05)
    }

    /// Every motion keeps the frame covered (no black edges) at any moment and any amount.
    func testMotionNeverShowsAnEdge() {
        let size = CGSize(width: 720, height: 1280)
        for m in VideoFX.motions.map(\.id) {
            for a in [0.0, 0.5, 1.0] {
                for t in stride(from: 0.0, through: 6, by: 0.37) {
                    let tr = VideoFX.motion(m, t: t, duration: 6, size: size, amount: a, beats: [1, 2, 3])
                    for corner in [CGPoint.zero, CGPoint(x: 720, y: 0), CGPoint(x: 0, y: 1280), CGPoint(x: 720, y: 1280)] {
                        // The frame's corner, moved back through the motion, must land inside the picture.
                        let back = corner.applying(tr.inverted())
                        XCTAssertTrue(back.x > -1 && back.x < 721 && back.y > -1 && back.y < 1281, "\(m) at \(t)s, \(a): edge shows at \(corner)")
                    }
                }
            }
        }
        XCTAssertEqual(VideoFX.motion("none", t: 2, duration: 6, size: size, amount: 1, beats: []), .identity)
        // The beat punch is biggest right on a beat.
        let on = VideoFX.motion("pulse", t: 2, duration: 6, size: size, amount: 1, beats: [2]).a
        let off = VideoFX.motion("pulse", t: 2.5, duration: 6, size: size, amount: 1, beats: [2]).a
        XCTAssertGreaterThan(on, off + 0.05)
    }

    func testBeatsComeFromTheSound() {
        // Quiet, with a loud hit every 0.5 s (10 steps of 0.05 s).
        let e = (0..<120).map { $0 % 10 == 0 ? 0.9 : 0.05 }
        let b = VideoFX.beats(loudness: e, hop: 0.05)
        XCTAssertGreaterThanOrEqual(b.count, 10)
        XCTAssertEqual(b.first ?? 0, 0.5, accuracy: 0.06)
        XCTAssertTrue(zip(b, b.dropFirst()).allSatisfy { $1 - $0 >= 0.22 })
        XCTAssertEqual(VideoFX.beats(loudness: Array(repeating: 0.3, count: 50), hop: 0.05), [])
        XCTAssertEqual(VideoFX.steady(2.1), [0.25, 0.75, 1.25, 1.75])
    }

    func testWordsArriveAndSettle() {
        for s in VideoFX.wordStyles.map(\.id) {
            XCTAssertEqual(VideoFX.wordsMotion(s, t: 0).alpha, 0, accuracy: 0.001, s)
            let late = VideoFX.wordsMotion(s, t: 3)
            XCTAssertEqual(late.alpha, 1, accuracy: 0.001, s)
            XCTAssertEqual(late.scale, 1, accuracy: 0.02, s)
            XCTAssertEqual(late.lift, 0, accuracy: 0.01, s)
        }
        XCTAssertGreaterThan((0...30).map { VideoFX.wordsMotion("pop", t: Double($0) / 50).scale }.max() ?? 0, 1.02, "pop overshoots")
    }

    /// A real frame: the plain recipe leaves it alone; a vibe changes it, more at Dramatic than at Subtle.
    func testFramesChangeWithTheRecipe() throws {
        let ctx = CGContext(data: nil, width: 96, height: 160, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        for y in 0..<16 { ctx.setFillColor(CGColor(red: CGFloat(y) / 16, green: 0.5, blue: 1 - CGFloat(y) / 16, alpha: 1)); ctx.fill(CGRect(x: 0, y: y * 10, width: 96, height: 10)) }
        let poster = try XCTUnwrap(ctx.makeImage())
        func pixels(_ img: UIImage?) throws -> [UInt8] {
            let cg = try XCTUnwrap(img?.cgImage)
            var px = [UInt8](repeating: 0, count: 96 * 160 * 4)
            let c = CGContext(data: &px, width: 96, height: 160, bitsPerComponent: 8, bytesPerRow: 96 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            c.draw(cg, in: CGRect(x: 0, y: 0, width: 96, height: 160))
            return px
        }
        func change(_ a: [UInt8], _ b: [UInt8]) -> Double { Double(zip(a, b).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }) / Double(a.count) }
        let original = try pixels(UIImage(cgImage: poster))
        let plain = try pixels(VideoFX.still(poster, recipe: VideoFX.Recipe()))
        XCTAssertLessThan(change(original, plain), 2, "the plain recipe changed the picture")
        for v in VideoFX.vibes where v.id != "original" {
            var subtle = v.recipe; subtle.amount = 0.1
            var wild = v.recipe; wild.amount = 1
            let s = change(original, try pixels(VideoFX.still(poster, recipe: subtle)))
            let w = change(original, try pixels(VideoFX.still(poster, recipe: wild)))
            XCTAssertGreaterThan(w, 3, "\(v.id) at Wild barely shows")
            XCTAssertGreaterThan(w, s, "\(v.id): Dramatic should change more than Subtle")
        }
    }

    /// A real video made with a vibe and words: same length, every frame there.
    func testAVibeMakesARealVideo() async throws {
        let made = await SampleAssets.movie(seconds: 2, size: CGSize(width: 360, height: 640))
        let src = try XCTUnwrap(made)
        var r = VideoFX.vibes.first { $0.id == "party" }!.recipe; r.amount = 0.8
        let exported = await VideoFX.export(src, recipe: r, caption: Celebrate.Caption(text: "Best day ever"))
        let out = try XCTUnwrap(exported)
        let asset = AVURLAsset(url: out)
        let d = try await asset.load(.duration).seconds
        XCTAssertEqual(d, 2, accuracy: 0.3)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertFalse(tracks.isEmpty)
    }

    func testEveryVibeIsDistinctAndNamed() {
        let mixes = VideoFX.vibes.map { "\($0.recipe.look)|\($0.recipe.light)|\($0.recipe.motion)|\($0.recipe.texture)|\($0.recipe.sparkle)" }
        XCTAssertEqual(Set(mixes).count, mixes.count)
        for v in VideoFX.vibes { XCTAssertEqual(VideoFX.vibe(of: v.recipe)?.id, v.id) }
        for s in VideoFX.sparkles where s.id != "none" { XCTAssertNotNil(VideoFX.sparkleTheme(s.id), s.id) }
        XCTAssertNotNil(VideoFX.sparkleTheme("fest:christmas"))
        XCTAssertEqual(CelebrateView.strength(0.05), "Barely there"); XCTAssertEqual(CelebrateView.strength(1), "Wild")
    }
}
