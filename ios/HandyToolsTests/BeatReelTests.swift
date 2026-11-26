import XCTest
import AVFoundation
@testable import HandyTools

/// 26 Nov: Beat Reel — clips cut to the beat of Tenzy's own music. The plan cuts on beats in whole bars, uses every
/// clip, spreads each clip's turns through it and has one slow-motion moment where the music drops; made for real,
/// the reel is tall, as long as the music says, and has its sound.
final class BeatReelTests: XCTestCase {
    func testThePlanCutsOnTheBeat() {
        for st in Synth.styles {
            let lengths = [8.0, 3.5, 20.0, 6.0]
            let (cuts, total) = BeatReel.plan(lengths: lengths, style: st)
            let beat = 60 / st.bpm, bar = beat * 4
            XCTAssertFalse(cuts.isEmpty, st.id)
            XCTAssertEqual((total / bar).rounded(), total / bar, accuracy: 0.001, "\(st.id): whole bars")
            XCTAssertEqual(cuts.reduce(0) { $0 + $1.lasts }, total, accuracy: 0.01, "\(st.id): the cuts fill the reel exactly")
            var at = 0.0
            for c in cuts {
                XCTAssertEqual((at / beat).rounded(), at / beat, accuracy: 0.001, "\(st.id): a cut at \(at) s is off the beat")
                XCTAssertGreaterThanOrEqual(c.from, 0); XCTAssertLessThanOrEqual(c.from + c.length, lengths[c.clip] + 0.001, "\(st.id): a cut runs past its clip's end")
                at += c.lasts
            }
            XCTAssertEqual(Set(cuts.map(\.clip)), Set(0..<lengths.count), "\(st.id): every clip is used")
            XCTAssertEqual(cuts.filter(\.slow).count, 1, "\(st.id): one slow-motion moment")
            // The long clip's turns come from different parts of it, in order.
            let longTurns = cuts.filter { $0.clip == 2 }.map(\.from)
            XCTAssertEqual(longTurns, longTurns.sorted()); XCTAssertEqual(Set(longTurns).count, longTurns.count)
        }
        XCTAssertEqual(BeatReel.plan(lengths: [10], style: Synth.style("upbeat"), seconds: 30).total, 30, accuracy: 60 / 118 * 4)
        XCTAssertTrue(BeatReel.plan(lengths: [], style: Synth.style("upbeat")).cuts.isEmpty)
    }

    func testAPortraitAndALandscapeClipBothFillTheTallFrame() {
        for (natural, tr) in [(CGSize(width: 1920, height: 1080), CGAffineTransform.identity),
                              (CGSize(width: 1920, height: 1080), CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0))] {
            let r = CGRect(origin: .zero, size: natural).applying(BeatReel.fill(natural: natural, transform: tr))
            XCTAssertLessThanOrEqual(r.minX, 0.5); XCTAssertLessThanOrEqual(r.minY, 0.5)
            XCTAssertGreaterThanOrEqual(r.maxX, BeatReel.size.width - 0.5); XCTAssertGreaterThanOrEqual(r.maxY, BeatReel.size.height - 0.5)
            XCTAssertEqual(r.midX, BeatReel.size.width / 2, accuracy: 1); XCTAssertEqual(r.midY, BeatReel.size.height / 2, accuracy: 1)
        }
    }

    func testAReelIsReallyMade() async throws {
        let a = await SampleAssets.movie(seconds: 4, size: CGSize(width: 640, height: 360))
        let b = await SampleAssets.movie(seconds: 3, size: CGSize(width: 360, height: 640))
        let clips = [a, b].compactMap { $0 }
        XCTAssertEqual(clips.count, 2, "no sample clips")
        let made = await BeatReel.make(clips, style: "party", seconds: 8)
        let out = try XCTUnwrap(made, "the reel wasn't made")
        let asset = AVURLAsset(url: out)
        let v = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(v.first)
        let n = try await track.load(.naturalSize), t = try await track.load(.preferredTransform)
        let shown = CGRect(origin: .zero, size: n).applying(t)
        XCTAssertEqual(abs(shown.width), 1080, accuracy: 2); XCTAssertEqual(abs(shown.height), 1920, accuracy: 2)
        let d = try await asset.load(.duration).seconds
        let planned = BeatReel.plan(lengths: [4, 3], style: Synth.style("party"), seconds: 8).total
        XCTAssertEqual(d, planned + BeatReel.ringOut, accuracy: 0.5, "the reel is its bars plus the last ring")
        let sound = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertFalse(sound.isEmpty, "the reel has no music")
    }
}
