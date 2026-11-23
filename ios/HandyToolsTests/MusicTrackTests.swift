import XCTest
import AVFoundation
@testable import HandyTools

/// Music under an Animate video: the beat is read right, the song starts at its liveliest part on a beat, the photos
/// change on the beat, and the finished video really carries the song for its whole length.
final class MusicTrackTests: XCTestCase {

    /// Clicks every `period` seconds (with a softer off-beat), as an onset curve at the analysis rate.
    private func clicks(period: Double, seconds: Double, offset: Double = 0) -> [Float] {
        let r = MusicTrack.hopRate
        var o = [Float](repeating: 0.02, count: Int(seconds * r))
        var t = offset
        while Int(t * r) < o.count { o[Int(t * r)] = 1; if Int((t + period / 2) * r) < o.count { o[Int((t + period / 2) * r)] = 0.3 }; t += period }
        return o
    }

    func testTempoIsReadAtTheRightSpeedAndPhase() throws {
        for bpm in [92.0, 100, 120, 128, 150] {
            let p = 60 / bpm
            let got = try XCTUnwrap(MusicTrack.tempo(onset: clicks(period: p, seconds: 30, offset: 0.2)), "\(bpm) bpm")
            XCTAssertEqual(got.period, p, accuracy: 0.02, "\(bpm) bpm read as \(60 / got.period)")
            // The first beat lines up with a click (modulo one beat).
            let off = (0.2 - got.phase).truncatingRemainder(dividingBy: p)
            XCTAssertLessThan(min(abs(off), abs(p - abs(off))), 0.03, "\(bpm) bpm phase \(got.phase)")
        }
        // Silence or noise with no beat: no tempo, so the photos keep their own pace.
        XCTAssertNil(MusicTrack.tempo(onset: [Float](repeating: 0.1, count: 2000)))
    }

    func testTheSongStartsAtItsLiveliestPartOnABeat() {
        // Quiet intro, loud chorus from 40 s to 70 s.
        let r = MusicTrack.hopRate
        var e = [Float](repeating: 0.01, count: Int(120 * r))
        for i in Int(40 * r)..<Int(70 * r) { e[i] = 0.5 }
        let start = MusicTrack.liveliest(energy: e, length: 20)
        XCTAssertGreaterThanOrEqual(start, 39.5); XCTAssertLessThanOrEqual(start, 50.5)
        XCTAssertEqual(MusicTrack.snap(41.37, period: 0.5, phase: 0.12), 41.12, accuracy: 0.001)
        XCTAssertEqual(MusicTrack.snap(0.05, period: 0.5, phase: 0.12), 0, accuracy: 0.001, "never before the song starts")
        XCTAssertEqual(MusicTrack.liveliest(energy: e, length: 500), 0, "a song shorter than the video starts at the top")
    }

    func testPhotosChangeOnTheBeat() {
        var s = Animate.Settings(); s.style = .crossfade; s.beat = 0.5
        let tl = Animate.timeline(count: 5, settings: s)
        let seg = tl.hold + tl.trans
        XCTAssertEqual(seg.truncatingRemainder(dividingBy: 0.5), 0, accuracy: 0.001, "each photo lasts whole beats")
        XCTAssertEqual(tl.seconds, 5 * seg, accuracy: 0.05, "the video ends on a beat")
        XCTAssertEqual(tl.beat, 0.5)
        // Without music the photos keep their usual pace.
        s.beat = nil
        XCTAssertNil(Animate.timeline(count: 5, settings: s).beat)
        // Every beat gives a small push; a new photo a bigger one; between beats it settles.
        s.beat = 0.5
        let onNew = Animate.push(at: seg + 0.001, timeline: tl), onBeat = Animate.push(at: seg + 0.5 + 0.001, timeline: tl)
        let between = Animate.push(at: seg + 0.5 + 0.3, timeline: tl)
        XCTAssertGreaterThan(onNew, onBeat); XCTAssertGreaterThan(onBeat, between); XCTAssertEqual(between, 1, accuracy: 0.002)
    }

    /// A real song file (clicks at 100 bpm) → beat found → under a real Animate video, for its whole length.
    func testTheFinishedVideoCarriesTheSong() async throws {
        let song = try Self.clickTrack(bpm: 100, seconds: 24)
        let (title, _, secs) = await MusicTrack.describe(song)
        XCTAssertEqual(secs, 24, accuracy: 0.2); XCTAssertFalse(title.isEmpty)
        let prepared = await MusicTrack.prepare(MusicTrack.Song(id: "t", title: title, artist: "", seconds: secs, url: song), videoLength: 6)
        let pick = try XCTUnwrap(prepared)
        let beat = try XCTUnwrap(pick.beat, "a steady click has a beat")
        XCTAssertEqual(60 / beat, 100, accuracy: 4)

        var s = Animate.Settings(); s.style = .kenBurns; s.beat = pick.beat
        let photos = [EngineTests.solid(.systemRed, mark: "1"), EngineTests.solid(.systemBlue, mark: "2"), EngineTests.solid(.systemGreen, mark: "3")]
        let rendered = await Animate.render(photos, settings: s, scale: 0.2, fps: 15)
        let video = try XCTUnwrap(rendered)
        let mixed = await MusicTrack.addMusic(pick, to: video)
        let out = try XCTUnwrap(mixed)
        let asset = AVURLAsset(url: out)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(audio.count, 1, "the song is in the video")
        let vLen = try await asset.load(.duration).seconds
        let aLen = try await audio[0].load(.timeRange).duration.seconds
        XCTAssertEqual(aLen, vLen, accuracy: 0.25, "the song runs the whole video")
        XCTAssertEqual(vLen, Animate.timeline(count: 3, settings: s, fps: 15).seconds, accuracy: 0.2)
        // A song shorter than the video goes round again instead of stopping.
        var short = pick; short.start = 20
        let looped = try XCTUnwrap(MusicTrack.soundtrack(short, length: 10))
        let lLen = try await AVURLAsset(url: looped).load(.duration).seconds
        XCTAssertEqual(lLen, 10, accuracy: 0.2)
    }

    /// Every platform has a real canvas, and each feed post is 4:5.
    func testEveryPlatformHasItsShape() {
        for p in SocialPost.platforms {
            let c = p.canvasSize
            XCTAssertTrue(c.width >= 1080 && c.height >= 1080, p.id)
            XCTAssertEqual(VideoFormat.spec(for: p).size, c)
        }
        XCTAssertEqual(SocialPost.platform("igpost")?.ratio, "4:5")
        XCTAssertEqual(SocialPost.platform("fbpost")?.ratio, "4:5")
        XCTAssertEqual(SocialPost.platform("youtube")?.ratio, "16:9")
        XCTAssertEqual(SocialPost.platform("tiktok")?.ratio, "9:16")
        XCTAssertEqual(SocialPost.platform("pinterest")?.ratio, "9:16")
        for id in ["tiktok", "reels", "stories", "igpost", "shorts", "youtube", "facebook", "fbpost", "snapchat", "whatsapp", "x", "threads", "linkedin", "pinterest"] {
            XCTAssertNotNil(SocialPost.platform(id), "\(id) is offered")
        }
        XCTAssertEqual(SocialPost.openURL(SocialPost.platform("igpost")!, assetID: "A/1")?.absoluteString, "instagram://library?LocalIdentifier=A/1")
    }

    /// A WAV of clicks (a short noise burst on each beat) — a stand-in for a song with a clear beat.
    static func clickTrack(bpm: Double, seconds: Double) throws -> URL {
        let rate = 44_100.0
        let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clicks-\(Int(bpm)).wav")
        try? FileManager.default.removeItem(at: url)
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        let frames = AVAudioFrameCount(seconds * rate)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames)!
        buf.frameLength = frames
        let period = Int(rate * 60 / bpm)
        var rng = SeededRandom(seed: 42)
        for i in 0..<Int(frames) {
            let inBeat = i % period
            // A loud, fast-decaying burst on each beat, a quiet hum in between.
            let v = inBeat < 900 ? Float(rng.next(-1, 1)) * Float(exp(-Double(inBeat) / 220)) : Float(sin(Double(i) * 0.02) * 0.02)
            buf.floatChannelData![0][i] = v; buf.floatChannelData![1][i] = v
        }
        try file.write(from: buf)
        return url
    }
}
