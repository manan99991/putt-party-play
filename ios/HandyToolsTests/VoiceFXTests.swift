import XCTest
@testable import HandyTools

/// Manan, 22 Nov: "they sound very similar and have 0 wow effect". Each voice now has its own character chain, and
/// these tests prove the voices are measurably different, not just a little higher or lower.
final class VoiceFXTests: XCTestCase {
    let rate = 44_100.0

    /// A stand-in for speech: a 140 Hz voice with harmonics, in syllables.
    private func speech(seconds: Double = 2) -> [Float] {
        (0..<Int(seconds * rate)).map { i in
            let t = Double(i) / rate
            let syllable = max(0, sin(2 * .pi * 3 * t))
            var v = 0.0
            for h in 1...12 { v += sin(2 * .pi * 140 * Double(h) * t) / Double(h) }
            return Float(v * 0.25 * syllable)
        }
    }

    func testEveryVoiceIsItsOwnSound() {
        let x = speech()
        let ids = ChainText.voices.map(\.id)
        XCTAssertGreaterThanOrEqual(ids.count, 19)
        var outs: [String: [Float]] = [:]
        for id in ids {
            let y = VoiceFX.apply(id, x, rate: rate)
            XCTAssertFalse(y.isEmpty, id)
            XCTAssertLessThanOrEqual(y.map { abs($0) }.max() ?? 0, 1.0, "\(id) never clips")
            XCTAssertGreaterThan(y.map { abs($0) }.max() ?? 0, 0.5, "\(id) is levelled, not quiet")
            outs[id] = y
        }
        // The radio is a thin band; the giant and the villain are full of low end.
        XCTAssertLessThan(VoiceFX.lowShare(outs["walkie"]!, below: 300, rate: rate), 0.05)
        XCTAssertGreaterThan(VoiceFX.lowShare(outs["giant"]!, below: 300, rate: rate), VoiceFX.lowShare(outs["helium"]!, below: 300, rate: rate) * 3)
        // Underwater is muffled; the megaphone is bright.
        XCTAssertLessThan(VoiceFX.brightness(outs["underwater"]!, rate: rate), VoiceFX.brightness(outs["megaphone"]!, rate: rate))
        // The cave really echoes: the sound goes on after the voice stops.
        XCTAssertGreaterThan(outs["cave"]!.count, x.count + Int(0.5 * rate))
        // The walkie-talkie clicks on and off (squelch + beep around the voice).
        XCTAssertGreaterThan(outs["walkie"]!.count, x.count)
        // The robot is not just the voice again: ring modulation changes it sample by sample.
        func diff(_ a: [Float], _ b: [Float]) -> Double {
            let n = min(a.count, b.count)
            return (0..<n).reduce(0.0) { $0 + Double(abs(a[$1] - b[$1])) } / Double(n)
        }
        XCTAssertGreaterThan(diff(outs["robot"]!, VoiceFX.level(x)), 0.1)
        XCTAssertGreaterThan(diff(outs["alien"]!, outs["robot"]!), 0.05)
        XCTAssertGreaterThan(diff(outs["ghost"]!, outs["oldman"]!), 0.03)
        // Every voice has a picture and a line in the picker.
        for id in ids { XCTAssertNotNil(ChainText.voiceLooks[id], id); XCTAssertNotNil(ChainMedia.characters[id], id) }
    }

    /// 26 Nov: the four new voices, each proved on its output.
    func testTheNewVoicesDoWhatTheySay() {
        let x = speech()
        // Whisper: the words' shape is there, but no pitch is left — a breath, not a voice.
        let w = VoiceFX.apply("whisper", x, rate: rate)
        var pitched = 0, frames = 0
        for a in stride(from: 0, to: w.count - 2048, by: 4096) {
            frames += 1
            if let p = Pitch.detect(Array(w[a..<(a + 2048)]), sampleRate: rate), p.clarity > 0.85 { pitched += 1 }
        }
        var voiced = 0
        for a in stride(from: 0, to: x.count - 2048, by: 4096) {
            if let p = Pitch.detect(Array(x[a..<(a + 2048)]), sampleRate: rate), p.clarity > 0.85 { voiced += 1 }
        }
        XCTAssertGreaterThan(voiced, frames / 3, "the stand-in speech should have pitch to lose")
        XCTAssertLessThanOrEqual(pitched, frames / 10, "the whisper still has a pitch in \(pitched) of \(frames) stretches")
        // Old radio: a narrow band — almost nothing deep (bar the hum) and nothing bright.
        let r = VoiceFX.apply("radio", x, rate: rate)
        XCTAssertLessThan(VoiceFX.lowShare(r, below: 200, rate: rate), 0.08)
        XCTAssertLessThan(1 - VoiceFX.lowShare(r, below: 4500, rate: rate), 0.06, "an old radio's speaker has no top")
        // Announcer: the stadium answers back after the voice stops.
        let a = VoiceFX.apply("announcer", x, rate: rate)
        XCTAssertGreaterThan(a.count, x.count + Int(0.4 * rate))
        // Auto-tune's target: a voice gliding between notes is pulled onto the nearest note of the scale.
        let glide: [Float] = (0..<Int(2 * rate)).map { i in
            let t = Double(i) / rate, hz = 200 + 30 * t   // 200 → 260 Hz, never resting on a note
            var v = 0.0
            for h in 1...6 { v += sin(2 * .pi * hz * Double(h) * t + 0) / Double(h) }
            return Float(v * 0.3)
        }
        let curve = VoiceFX.snapCurve(glide, rate: rate, step: 1024)
        XCTAssertFalse(curve.isEmpty)
        XCTAssertTrue(curve.allSatisfy { abs($0) <= 200 }, "a correction is never more than two semitones")
        XCTAssertGreaterThan(curve.filter { abs($0) > 10 }.count, curve.count / 2, "most of a glide needs pulling onto a note")
    }

    /// Auto-tune through the real render (the pitch unit moved note by note while it renders): the sung result sits on
    /// notes far more than the glide it came from.
    func testAutoTuneLandsOnNotes() throws {
        let glide: [Float] = (0..<Int(3 * rate)).map { i in
            let t = Double(i) / rate, hz = 200 + 25 * t
            var v = 0.0
            for h in 1...6 { v += sin(2 * .pi * hz * Double(h) * t) / Double(h) }
            return Float(v * 0.3)
        }
        var pcm = [UInt8]()
        for v in glide { let s16 = Int16(max(-1, min(1, v)) * 32767); pcm.append(UInt8(truncatingIfNeeded: s16)); pcm.append(UInt8(truncatingIfNeeded: s16 >> 8)) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("glide-\(UUID().uuidString).wav")
        try (Data(ChainText.wavHeader(sampleRate: Int(rate), channels: 1, dataBytes: pcm.count)) + Data(pcm)).write(to: url)
        let out = try XCTUnwrap(ChainMedia.revoiceDSP(url, ChainMedia.characters["autotune"]!, voice: "autotune"), "auto-tune didn't render")
        let samples: [Float] = stride(from: 44, to: out.count - 1, by: 2).map { i in
            Float(Int16(bitPattern: UInt16(out[i]) | UInt16(out[i + 1]) << 8)) / 32767
        }
        func offNote(_ y: [Float]) -> Double {
            var total = 0.0, n = 0
            for a in stride(from: 8192, to: y.count - 2048 - 8192, by: 2048) {
                guard let p = Pitch.detect(Array(y[a..<(a + 2048)]), sampleRate: rate, minHz: 100, maxHz: 600), p.clarity > 0.8 else { continue }
                total += abs(Pitch.note(for: p.hz).cents); n += 1
            }
            return n > 0 ? total / Double(n) : 99
        }
        let before = offNote(glide), after = offNote(samples)
        XCTAssertGreaterThan(before, 15, "the glide should start off the notes")
        XCTAssertLessThan(after, before * 0.6, "auto-tune moved it from \(before) to only \(after) cents off a note")
    }
}
