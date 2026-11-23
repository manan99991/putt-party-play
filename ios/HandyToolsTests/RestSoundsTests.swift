import XCTest
@testable import HandyTools

/// Sleep sounds: every sound is real stereo, levelled, never clips, and actually sounds like what it says —
/// a heart beats once a second, waves swell, a train clicks over the joints, crickets chirp from the first second.
final class RestSoundsTests: XCTestCase {

    private let fs = 22_050.0

    private func rms(_ x: ArraySlice<Float>) -> Float { sqrt(x.reduce(0) { $0 + $1 * $1 } / Float(max(1, x.count))) }

    /// Loudness every `hop` seconds.
    private func envelope(_ x: [Float], hop: Double) -> [Float] {
        let n = Int(fs * hop)
        return stride(from: 0, to: x.count - n, by: n).map { rms(x[$0..<($0 + n)]) }
    }

    /// The lag (in steps) where a curve best repeats itself, between `lo` and `hi`.
    private func period(_ e: [Float], lo: Int, hi: Int) -> (lag: Int, score: Float) {
        let m = e.reduce(0, +) / Float(e.count)
        let c = e.map { $0 - m }
        let zero = c.reduce(0) { $0 + $1 * $1 }
        var best = (lag: lo, score: -Float.infinity)
        for lag in lo...hi {
            var s: Float = 0
            for i in 0..<(c.count - lag) { s += c[i] * c[i + lag] }
            if s / zero > best.score { best = (lag, s / zero) }
        }
        return best
    }

    private func correlation(_ a: [Float], _ b: [Float]) -> Float {
        var ab: Float = 0, aa: Float = 0, bb: Float = 0
        for i in a.indices { ab += a[i] * b[i]; aa += a[i] * a[i]; bb += b[i] * b[i] }
        return ab / max(1e-9, sqrt(aa * bb))
    }

    /// Brightness: how much of the sound is fast wiggle rather than slow rumble, whatever its loudness.
    private func brightness(_ x: [Float]) -> Float {
        let wiggle = zip(x.dropFirst(), x).map { abs($0 - $1) }.reduce(0, +) / Float(x.count)
        return wiggle / max(1e-6, rms(x[...]))
    }

    func testEverySoundIsStereoLevelledAndNeverClips() {
        for k in NoiseSynth.Kind.allCases {
            let (l, r) = NoiseSynth.renderStereo(k, samples: Int(fs * 3), sampleRate: fs, seed: 7)
            XCTAssertFalse(l.contains { !$0.isFinite } || r.contains { !$0.isFinite }, "\(k.title) made NaN/Inf")
            XCTAssertLessThanOrEqual(max(l.map(abs).max() ?? 0, r.map(abs).max() ?? 0), 1, "\(k.title) clips")
            let level = (rms(l[...]) + rms(r[...])) / 2
            XCTAssertGreaterThan(level, 0.03, "\(k.title) is too quiet (\(level))")
            XCTAssertLessThan(level, 0.35, "\(k.title) is too loud (\(level))")
            // It starts at once: something is heard in the very first second.
            XCTAssertGreaterThan(rms(l[0..<Int(fs)]) + rms(r[0..<Int(fs)]), 0.03, "\(k.title) is silent when you tap it")
        }
    }

    func testAHeartBeatsOnceASecond() {
        let (l, _) = NoiseSynth.renderStereo(.heartbeat, samples: Int(fs * 12), sampleRate: fs, seed: 3)
        let p = period(envelope(l, hop: 0.02), lo: 20, hi: 150)
        XCTAssertEqual(Double(p.lag) * 0.02, 1.0, accuracy: 0.04, "heartbeat repeats every \(Double(p.lag) * 0.02) s")
        XCTAssertGreaterThan(p.score, 0.6)
    }

    func testWavesSwellAndDrawBack() {
        let (l, _) = NoiseSynth.renderStereo(.ocean, samples: Int(fs * 30), sampleRate: fs, seed: 5)
        let e = envelope(l, hop: 1)
        XCTAssertGreaterThan((e.max() ?? 0) / max(0.001, e.min() ?? 1), 2.5, "the sea should rise and fall, not hiss evenly")
    }

    func testTheTrainClicksOverTheJoints() {
        let (l, _) = NoiseSynth.renderStereo(.train, samples: Int(fs * 14), sampleRate: fs, seed: 11)
        // Listen to the clicks only (the rumble is all low): the fast part, then its rhythm.
        let hp = zip(l.dropFirst(), l).map { $0 - $1 }
        let p = period(envelope(Array(hp), hop: 0.01), lo: 50, hi: 250)
        XCTAssertEqual(Double(p.lag) * 0.01, 0.86, accuracy: 0.05, "carriage rhythm \(Double(p.lag) * 0.01) s")
    }

    func testCricketsChirpHighFromTheFirstSecond() {
        let (c, _) = NoiseSynth.renderStereo(.crickets, samples: Int(fs), sampleRate: fs, seed: 2)
        let (b, _) = NoiseSynth.renderStereo(.brown, samples: Int(fs), sampleRate: fs, seed: 2)
        XCTAssertGreaterThan(brightness(c), brightness(b) * 1.5, "crickets should be bright chirps, not a rumble")
    }

    func testNatureIsWideStereoAndTheHeartSitsInTheMiddle() {
        let rain = NoiseSynth.renderStereo(.rain, samples: Int(fs * 2), sampleRate: fs, seed: 1)
        XCTAssertLessThan(abs(correlation(rain.left, rain.right)), 0.2, "rain should come from all around")
        let heart = NoiseSynth.renderStereo(.heartbeat, samples: Int(fs * 2), sampleRate: fs, seed: 1)
        XCTAssertGreaterThan(correlation(heart.left, heart.right), 0.6, "a heartbeat sits in the middle")
    }

    func testTonesAreTonesAndNoiseIsNoise() {
        let white = brightness(NoiseSynth.render(.white, samples: Int(fs * 2), sampleRate: fs, seed: 4))
        for k in [NoiseSynth.Kind.bowl, .pad, .musicBox, .heartbeat] {
            XCTAssertLessThan(brightness(NoiseSynth.render(k, samples: Int(fs * 2), sampleRate: fs, seed: 4)), white * 0.35, "\(k.title) should be smooth tones")
        }
    }

    func testShelvesAreWholeRowsAndMixesAreSmall() {
        let shelved = NoiseSynth.Group.allCases.flatMap(\.kinds)
        XCTAssertEqual(Set(shelved), Set(NoiseSynth.Kind.allCases), "every sound is on a shelf")
        XCTAssertEqual(shelved.count, NoiseSynth.Kind.allCases.count, "no sound is on two shelves")
        for g in NoiseSynth.Group.allCases {
            XCTAssertEqual(g.kinds.count % 3, 0, "\(g.title) fills whole rows of three")
            for k in g.kinds { XCTAssertEqual(k.group, g) }
        }
        XCTAssertEqual(NoiseSynth.mixes.count % 3, 0)
        XCTAssertEqual(Set(NoiseSynth.mixes.map(\.id)).count, NoiseSynth.mixes.count)
        for m in NoiseSynth.mixes {
            XCTAssertTrue((2...NoiseSynth.maxLayers).contains(m.layers.count), m.title)
            XCTAssertEqual(Set(m.layers.map(\.kind)).count, m.layers.count, m.title)
            for l in m.layers { XCTAssertTrue(l.level > 0 && l.level <= 1, m.title) }
        }
        // The six original sounds keep their numbers, so older saved choices still work.
        XCTAssertEqual([NoiseSynth.Kind.white, .pink, .brown, .fan, .rain, .ocean].map(\.rawValue), Array(0...5))
    }

    /// A mix of three sounds at full level still never clips (each sound is levelled; the sum is softly limited).
    func testAFullMixStaysUnderControl() {
        var a = NoiseSynth.State(seed: 1), b = NoiseSynth.State(seed: 2), c = NoiseSynth.State(seed: 3)
        var peak: Float = 0
        for _ in 0..<Int(fs * 2) {
            let x = a.frame(.thunder, sampleRate: fs), y = b.frame(.campfire, sampleRate: fs), z = c.frame(.train, sampleRate: fs)
            peak = max(peak, abs(tanhf(x.0 + y.0 + z.0)), abs(tanhf(x.1 + y.1 + z.1)))
        }
        XCTAssertLessThan(peak, 1)
    }

    @MainActor func testTheLastMixIsRemembered() {
        let mix = [NoisePlayer.Layer(kind: .roofRain, level: 0.8), NoisePlayer.Layer(kind: .campfire, level: 0.55)]
        XCTAssertEqual(NoisePlayer.decode(NoisePlayer.encode(mix)), mix)
        // Junk, unknown sounds and repeats are ignored; never more than three; levels kept in range.
        XCTAssertEqual(NoisePlayer.decode("x,99:0.5,4:2.0,4:0.3,11:0.5,13:0.5,1:0.5").map(\.kind), [.rain, .campfire, .train])
        XCTAssertEqual(NoisePlayer.decode("4:2.0").first?.level, 1)
        XCTAssertTrue(NoisePlayer.decode("").isEmpty)
    }
}
