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
        XCTAssertGreaterThanOrEqual(ids.count, 15)
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
}
