import XCTest
import AVFoundation
@testable import HandyTools

/// 26 Nov: Tenzy's own music and sound effects, and funny moments. The beats fall where the reel will cut, nothing
/// clips, every effect is its own sound, and a funny moment really stops, zooms and plays its sound at the moment.
final class SynthTests: XCTestCase {
    private let rate = Synth.rate

    /// Energy just after a time against just before it: a drum hit there makes the first much bigger.
    private func onset(_ x: [Float], at t: Double) -> Double {
        let i = Int(t * rate), w = Int(0.03 * rate)
        func e(_ a: Int, _ b: Int) -> Double { (max(0, a)..<min(x.count, b)).reduce(0.0) { $0 + Double(x[$1] * x[$1]) } + 1e-9 }
        return e(i, i + w) / e(i - w, i)
    }

    func testEveryStyleHitsItsBarsAndNeverClips() {
        for st in Synth.styles {
            let (x, beats) = Synth.track(st.id, seconds: 12)
            XCTAssertGreaterThanOrEqual(Double(x.count) / rate, 12, st.id)
            XCTAssertEqual(beats.count % 4, 0, "\(st.id): whole bars")
            XCTAssertEqual(beats[1] - beats[0], 60 / st.bpm, accuracy: 0.001, st.id)
            let peak = x.map { abs($0) }.max() ?? 0
            XCTAssertLessThanOrEqual(peak, 1, "\(st.id) clips"); XCTAssertGreaterThan(peak, 0.5, "\(st.id) is quiet")
            // Every bar's first beat (after the first, lighter bar) is a hit.
            let downbeats = stride(from: 4, to: beats.count, by: 4).map { beats[$0] }
            let hits = downbeats.filter { onset(x, at: $0) > 1.6 }.count
            XCTAssertGreaterThanOrEqual(hits, downbeats.count - 1, "\(st.id): only \(hits) of \(downbeats.count) bars start on a hit")
        }
        // The same request makes the same sound (a re-made reel sounds the same).
        XCTAssertEqual(Synth.track("chill", seconds: 4).samples.prefix(5000), Synth.track("chill", seconds: 4).samples.prefix(5000))
    }

    func testEveryEffectIsItsOwnSound() {
        var lengths: [String: Int] = [:]
        for e in Synth.effects {
            let x = Synth.effect(e.id)
            XCTAssertGreaterThan(x.count, Int(0.05 * rate), e.id)
            XCTAssertLessThanOrEqual(x.map { abs($0) }.max() ?? 0, 1, "\(e.id) clips")
            XCTAssertGreaterThan(x.map { abs($0) }.max() ?? 0, 0.5, "\(e.id) is quiet")
            lengths[e.id] = x.count
        }
        // A sting has three notes; crickets chirp on and off; a whoosh is noise, a boing is a tone.
        let sting = Synth.effect("sting")
        XCTAssertGreaterThan(onset(sting, at: 0.5), 1.3); XCTAssertGreaterThan(onset(sting, at: 1.0), 1.3)
        XCTAssertGreaterThan(VoiceFX.brightness(Synth.effect("whoosh"), rate: rate), VoiceFX.brightness(Synth.effect("boing"), rate: rate))
        XCTAssertNotNil(Synth.file(Synth.effect("pop"), name: "pop"))
    }

    func testTheMomentIsTheLaughAndTheLooksArriveOnTime() {
        // A clip that's quiet except for a burst at 6 s: that's the moment.
        var loud = [Double](repeating: 0.02, count: 200)
        for i in 118...124 { loud[i] = 0.4 }
        XCTAssertEqual(FunnyMoment.moment(loudness: loud, hop: 0.05, duration: 10, kind: "scratch"), 6.0, accuracy: 0.2)
        XCTAssertEqual(FunnyMoment.moment(loudness: [], hop: 0.05, duration: 10, kind: "boing"), 6.0, accuracy: 0.01, "no sound: 60% in")
        XCTAssertEqual(FunnyMoment.moment(loudness: loud, hop: 0.05, duration: 10, kind: "rimshot"), 9.95, accuracy: 0.01, "ba-dum-tss is at the end")
        // Before the moment nothing happens.
        XCTAssertEqual(FunnyMoment.look("scratch", dt: -0.5, freeze: 2.6), FunnyMoment.Look())
        // The record scratch: a flash, then grey and the words, pushing in.
        let s = FunnyMoment.look("scratch", dt: 0.05, freeze: 2.6), s2 = FunnyMoment.look("scratch", dt: 1.5, freeze: 2.6)
        XCTAssertGreaterThan(s.flash, 0); XCTAssertGreaterThan(s2.grey, 0.8); XCTAssertEqual(s2.words, 1, accuracy: 0.01); XCTAssertGreaterThan(s2.zoom, 1)
        XCTAssertEqual(FunnyMoment.look("scratch", dt: 3, freeze: 2.6), FunnyMoment.Look(), "after the freeze it's back to normal")
        // The dramatic zoom steps in with each note.
        XCTAssertLessThan(FunnyMoment.look("dramatic", dt: 0.2, freeze: 0).zoom, FunnyMoment.look("dramatic", dt: 0.7, freeze: 0).zoom)
        XCTAssertLessThan(FunnyMoment.look("dramatic", dt: 0.7, freeze: 0).zoom, FunnyMoment.look("dramatic", dt: 1.2, freeze: 0).zoom)
        // Horns shake; a boing squashes.
        XCTAssertNotEqual(FunnyMoment.look("horn", dt: 0.3, freeze: 0).dx, 0)
        XCTAssertNotEqual(FunnyMoment.look("boing", dt: 0.05, freeze: 0).squash, 1)
    }

    /// Made for real on a generated clip: the freeze makes it longer by its length, and the effect's sound is in it.
    func testARecordScratchFreezeIsReallyMade() async throws {
        let made = await SampleAssets.movie(seconds: 4, withSound: true)
        let src = try XCTUnwrap(made, "no sample clip")
        let funny = await FunnyMoment.make(src, kind: "scratch", at: 2, words: nil)
        let out = try XCTUnwrap(funny, "the funny moment wasn't made")
        let a = AVURLAsset(url: out), b = AVURLAsset(url: src)
        let d = try await a.load(.duration).seconds, d0 = try await b.load(.duration).seconds
        XCTAssertEqual(d, d0 + FunnyMoment.kind("scratch").freeze, accuracy: 0.25, "the freeze should add its length")
        let sound = try await a.loadTracks(withMediaType: .audio)
        XCTAssertFalse(sound.isEmpty, "the sound is missing")
        // Before the moment the colourful clip is as filmed; inside the freeze it has gone grey.
        let gen = AVAssetImageGenerator(asset: a); gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
        let before = try await gen.image(at: CMTime(seconds: 1.0, preferredTimescale: 600)).image
        let frozen = try await gen.image(at: CMTime(seconds: 3.4, preferredTimescale: 600)).image
        XCTAssertLessThan(saturation(frozen), saturation(before) * 0.45, "the frozen frame should be grey")
    }

    /// Average colourfulness (max − min of R, G, B) of a picture, 0…255.
    private func saturation(_ cg: CGImage) -> Double {
        let w = 64, h = 64
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var s = 0.0
        for i in stride(from: 0, to: px.count, by: 4) {
            let r = Double(px[i]), g = Double(px[i + 1]), b = Double(px[i + 2])
            s += max(r, g, b) - min(r, g, b)
        }
        return s / Double(w * h)
    }
}
