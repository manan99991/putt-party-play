import XCTest
import AVFoundation
@testable import HandyTools

/// 26 Nov: the movie-trailer maker. The shape lands on whole bars with the cards, cuts and hits where they belong; the
/// score holds its breath before the title and hits hard on it; the narrator really speaks; and a trailer made for real
/// is tall, as long as its parts, has its sound, shows a black title card with words and then the colourful shots.
final class TrailerTests: XCTestCase {
    func testTheShapeIsWholeBarsWithItsCardsAndHits() {
        let ps = Trailer.parts()
        XCTAssertEqual(ps.first?.start, 0)
        for (a, b) in zip(ps, ps.dropFirst()) { XCTAssertEqual(a.end, b.start, accuracy: 0.0001, "parts must follow on with no gap") }
        for p in ps { XCTAssertEqual((p.start / Trailer.bar).rounded(), p.start / Trailer.bar, accuracy: 0.0001, "\(p.kind) starts off a bar") }
        XCTAssertEqual(ps.last?.end ?? 0, 12 * Trailer.bar + Trailer.ringOut, accuracy: 0.001, "about half a minute")
        XCTAssertEqual(ps.filter { $0.kind == .card }.compactMap(\.line), [0, 1, 2], "three narrator cards, in order")
        XCTAssertEqual(ps.filter(\.isCard).map(\.kind), [.card, .card, .card, .title, .end])
        // Every card hits; every montage cut hits; the title is a hit.
        let hits = Trailer.hits(ps)
        for p in ps where p.isCard { XCTAssertTrue(hits.contains(p.start), "\(p.kind) at \(p.start) doesn't hit") }
        let montage = ps.first { $0.kind == .montage }!
        XCTAssertEqual(hits.filter { $0 >= montage.start && $0 < montage.end }.count, 8, "a hit on every montage beat")
        // Each spoken line starts inside its own card.
        let cues = Trailer.cues(ps)
        XCTAssertEqual(cues.map(\.line), [0, 1, 2, 3, 4])
        for c in cues { XCTAssertTrue(ps.contains { $0.isCard && c.at > $0.start && c.at < $0.end }, "line \(c.line) at \(c.at) isn't on a card") }
    }

    func testTheCutsFillEveryMomentAndTheSlowShotsAreSlow() {
        let ps = Trailer.parts()
        let lengths = [6.0, 2.0, 11.0]
        let cuts = Trailer.cuts(ps, lengths: lengths)
        XCTAssertEqual(cuts.reduce(0) { $0 + $1.lasts }, ps.last!.end, accuracy: 0.01, "the cuts fill the trailer exactly")
        XCTAssertEqual(Set(cuts.filter { $0.length > 0.05 }.map(\.clip)), Set(0..<lengths.count), "every clip is used")
        for c in cuts { XCTAssertLessThanOrEqual(c.from + c.length, lengths[c.clip] + 0.001, "a cut runs past its clip's end") }
        // Walk the parts: cards are placeholders, slow shots use half as much clip (slow motion), the rest play as filmed.
        var i = 0
        for p in ps {
            if p.isCard { XCTAssertEqual(cuts[i].lasts, p.length, accuracy: 0.001); XCTAssertLessThan(cuts[i].length, 0.05); i += 1; continue }
            let n = Int((p.length / p.cut).rounded())
            for c in cuts[i..<i + n] {
                if p.kind == .slow, lengths[c.clip] >= c.lasts { XCTAssertEqual(c.length, c.lasts / 2, accuracy: 0.001, "slow motion runs at half speed") }
                if p.kind != .slow, lengths[c.clip] >= c.lasts { XCTAssertEqual(c.length, c.lasts, accuracy: 0.001) }
            }
            i += n
        }
        XCTAssertEqual(i, cuts.count)
        XCTAssertTrue(Trailer.cuts(ps, lengths: []).isEmpty)
    }

    func testTheScoreHoldsItsBreathThenHitsOnTheTitle() {
        let ps = Trailer.parts()
        let x = Trailer.score(ps), rate = Synth.rate
        XCTAssertGreaterThanOrEqual(Double(x.count) / rate, ps.last!.end)
        XCTAssertLessThanOrEqual(x.map { abs($0) }.max() ?? 0, 1, "the score clips")
        let title = ps.first { $0.kind == .title }!.start
        func energy(_ a: Double, _ b: Double) -> Double { (Int(a * rate)..<Int(b * rate)).reduce(0.0) { $0 + Double(x[$1] * x[$1]) } / ((b - a) * rate) }
        XCTAssertLessThan(energy(title - Trailer.beat / 2 + 0.01, title - 0.01), 1e-6, "half a beat of silence before the title")
        XCTAssertGreaterThan(energy(title, title + 0.3), 100 * energy(title - 0.3, title - 0.01) + 1e-4, "the title lands on a big hit")
        // The montage builds: its second bar is louder than the slow shots.
        let slow = ps.first { $0.kind == .slow }!, montage = ps.first { $0.kind == .montage }!
        XCTAssertGreaterThan(energy(montage.start + Trailer.bar, montage.end - Trailer.beat), energy(slow.start + 0.5, slow.end))
    }

    func testCardsFadeInGrowAndTheTitleFlashesHardest() {
        let a = Trailer.cardLook(dt: 0, length: 2.5, style: .line), b = Trailer.cardLook(dt: 1.2, length: 2.5, style: .line), c = Trailer.cardLook(dt: 2.49, length: 2.5, style: .line)
        XCTAssertEqual(a.alpha, 0, accuracy: 0.001); XCTAssertEqual(b.alpha, 1, accuracy: 0.001); XCTAssertLessThan(c.alpha, 0.1)
        XCTAssertGreaterThan(b.scale, a.scale)
        XCTAssertNotNil(Trailer.card("In a world", style: .line, width: 1080))
        XCTAssertNotNil(Trailer.card("The Adventure", style: .title, width: 1080))
        let hits = [0.0, 5.0], title = 5.0
        XCTAssertGreaterThan(Trailer.flash(5.01, hits: hits, title: title), Trailer.flash(0.01, hits: hits, title: title))
        XCTAssertEqual(Trailer.flash(0.5, hits: hits, title: title), 0)
    }

    /// The narrator is the phone's own voice, spoken for real.
    func testTheNarratorSpeaks() async throws {
        let line = "In a world where anything can happen"
        guard Trailer.voice(for: line) != nil else { throw XCTSkip("no speech voice on this device") }
        let voice = await Trailer.narrate(line)
        XCTAssertGreaterThan(Double(voice.count) / Synth.rate, 1.0, "the narrator said nothing (\(voice.count) samples)")
        XCTAssertGreaterThan(voice.map { abs($0) }.max() ?? 0, 0.5)
        // Mixed in, the music dips under the voice.
        var music = [Float](repeating: 0.5, count: 6000)
        let pulses: [Float] = (0..<5000).map { $0 % 100 == 0 ? 0.8 : 0 }
        Trailer.mixVoice(pulses, into: &music, at: 0)
        XCTAssertLessThan(music[150], 0.45, "the music should dip under the voice")
    }

    /// Made for real from two generated clips.
    func testATrailerIsReallyMade() async throws {
        let a = await SampleAssets.movie(seconds: 4, size: CGSize(width: 640, height: 360))
        let b = await SampleAssets.movie(seconds: 3, size: CGSize(width: 360, height: 640))
        let clips = [a, b].compactMap { $0 }
        XCTAssertEqual(clips.count, 2, "no sample clips")
        let made = await Trailer.make(clips, title: "The Test", lines: [])
        let out = try XCTUnwrap(made, "the trailer wasn't made")
        let asset = AVURLAsset(url: out)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let n = try await track.load(.naturalSize), t = try await track.load(.preferredTransform)
        let shown = CGRect(origin: .zero, size: n).applying(t)
        XCTAssertEqual(abs(shown.width), 1080, accuracy: 2); XCTAssertEqual(abs(shown.height), 1920, accuracy: 2)
        let d = try await asset.load(.duration).seconds
        XCTAssertEqual(d, Trailer.parts().last!.end, accuracy: 0.5)
        let sound = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertFalse(sound.isEmpty, "the trailer has no sound")
        // The first card is black with bright words; the slow shots after it are the colourful clips.
        let gen = AVAssetImageGenerator(asset: asset); gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
        let card = try await gen.image(at: CMTime(seconds: 1.2, preferredTimescale: 600)).image
        let shot = try await gen.image(at: CMTime(seconds: Trailer.bar + 1.0, preferredTimescale: 600)).image
        let c = stats(card), s = stats(shot)
        XCTAssertLessThan(c.mean, 60, "the card should be black"); XCTAssertGreaterThan(c.max, 150, "the card has no words")
        XCTAssertGreaterThan(s.colour, c.colour + 10, "the shot after the card should be the clip, in colour")
    }

    /// Mean and brightest luminance (0…255) and average colourfulness of a picture.
    private func stats(_ cg: CGImage) -> (mean: Double, max: Double, colour: Double) {
        let w = 270, h = 480
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var sum = 0.0, top = 0.0, col = 0.0
        for i in stride(from: 0, to: px.count, by: 4) {
            let r = Double(px[i]), g = Double(px[i + 1]), b = Double(px[i + 2])
            let l = 0.2126 * r + 0.7152 * g + 0.0722 * b
            sum += l; top = max(top, l); col += max(r, g, b) - min(r, g, b)
        }
        return (sum / Double(w * h), top, col / Double(w * h))
    }
}
