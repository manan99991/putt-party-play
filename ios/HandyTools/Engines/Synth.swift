import Foundation

/// Tenzy's own music and sound effects, made on the phone from plain waves and noise (26 Nov). Nothing is downloaded,
/// licensed or copied: every beat, chord and "boing" is synthesised here, so the reels, trailers and funny moments can
/// carry sound we own outright (rulebook: never ship songs or loops we don't have the rights to). Pure: the same
/// request always makes the same sound, so tests can check where the beats fall and that nothing clips.
enum Synth {
    static let rate = 44_100.0

    // MARK: styles

    struct Style: Identifiable, Equatable {
        let id: String, name: String, emoji: String
        let bpm: Double
        /// How many beats each clip lasts in a reel (faster music, quicker cuts).
        let beatsPerCut: Int
        /// The video look that goes with it.
        let look: String, light: String
    }
    static let styles: [Style] = [
        Style(id: "upbeat", name: "Upbeat", emoji: "☀️", bpm: 118, beatsPerCut: 2, look: "vivid", light: "leak"),
        Style(id: "party", name: "Party", emoji: "🪩", bpm: 126, beatsPerCut: 2, look: "neon", light: "flare"),
        Style(id: "chill", name: "Chill", emoji: "🌙", bpm: 88, beatsPerCut: 4, look: "dream", light: "glow"),
        Style(id: "epic", name: "Epic", emoji: "⚡️", bpm: 96, beatsPerCut: 4, look: "cinema", light: "vignette"),
    ]
    static func style(_ id: String) -> Style { styles.first { $0.id == id } ?? styles[0] }

    // MARK: building blocks

    static func hz(_ midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }

    /// Adds `sound` into `out` starting at `t` seconds, scaled by `gain`.
    static func mix(_ sound: [Float], into out: inout [Float], at t: Double, gain: Float = 1) {
        let start = Int(t * rate)
        guard start < out.count else { return }
        for i in sound.indices where start + i < out.count && start + i >= 0 { out[start + i] += sound[i] * gain }
    }

    private static func env(_ i: Int, attack: Double, decay: Double) -> Float {
        let t = Double(i) / rate
        return Float(t < attack ? t / attack : exp(-(t - attack) / decay))
    }

    private static func noise(_ n: Int, seed: UInt64) -> [Float] {
        var r = SeededRandom(seed: seed)
        return (0..<n).map { _ in Float(r.next(-1, 1)) }
    }

    /// A kick drum: a sine that drops in pitch, with a click on top.
    static func kick(punch: Double = 1) -> [Float] {
        let n = Int(0.42 * rate)
        var phase = 0.0
        return (0..<n).map { i in
            let t = Double(i) / rate
            phase += 2 * .pi * (48 + 120 * punch * exp(-t * 28)) / rate
            return Float(sin(phase) * exp(-t * 7.5)) * 0.95 + (i < 220 ? Float(sin(Double(i) * 0.9)) * 0.25 * Float(1 - Double(i) / 220) : 0)
        }
    }

    static func snare(soft: Bool = false) -> [Float] {
        let n = Int(0.25 * rate)
        let hiss = VoiceFX.filter(noise(n, seed: 5), "highpass", f: soft ? 900 : 1500, rate: rate)
        return (0..<n).map { i in
            let t = Double(i) / rate
            return (hiss[i] * Float(exp(-t * (soft ? 22 : 16))) * 0.7 + Float(sin(2 * .pi * 185 * t) * exp(-t * 30)) * 0.45) * (soft ? 0.6 : 1)
        }
    }

    static func clap() -> [Float] {
        let n = Int(0.22 * rate)
        let hiss = VoiceFX.filter(noise(n, seed: 9), "bandpass", f: 1400, q: 1.2, rate: rate)
        return (0..<n).map { i in
            let t = Double(i) / rate
            let bursts = t < 0.03 ? (0.6 + 0.4 * sin(t * 2 * .pi * 100)) : exp(-(t - 0.03) * 18)
            return hiss[i] * Float(bursts) * 1.4
        }
    }

    static func hat(open: Bool = false) -> [Float] {
        let n = Int((open ? 0.22 : 0.05) * rate)
        let hiss = VoiceFX.filter(VoiceFX.filter(noise(n, seed: 13), "highpass", f: 7000, rate: rate), "highpass", f: 7000, rate: rate)
        return (0..<n).map { i in hiss[i] * Float(exp(-Double(i) / rate * (open ? 12 : 60))) * 0.5 }
    }

    /// A deep drum with a boom (for the epic style and trailers).
    static func taiko() -> [Float] {
        let n = Int(0.9 * rate)
        let thud = VoiceFX.filter(noise(n, seed: 21), "lowpass", f: 300, rate: rate)
        var phase = 0.0
        return (0..<n).map { i in
            let t = Double(i) / rate
            phase += 2 * .pi * (62 + 40 * exp(-t * 18)) / rate
            return Float(sin(phase) * exp(-t * 4)) * 0.9 + thud[i] * Float(exp(-t * 12)) * 0.8
        }
    }

    /// A rounded bass note.
    static func bass(_ midi: Int, seconds: Double, bright: Double = 0.3) -> [Float] {
        let n = Int(seconds * rate), f = hz(midi)
        return (0..<n).map { i in
            let t = Double(i) / rate
            let w = sin(2 * .pi * f * t) + bright * sin(4 * .pi * f * t) * 0.5 + bright * 0.25 * sin(6 * .pi * f * t)
            return Float(w * min(1, t / 0.008) * exp(-t / (seconds * 1.6))) * 0.55
        }
    }

    /// A short bright note (arpeggios), or a soft electric-piano note when `soft`.
    static func pluck(_ midi: Int, seconds: Double, soft: Bool = false) -> [Float] {
        let n = Int(seconds * rate), f = hz(midi)
        return (0..<n).map { i in
            let t = Double(i) / rate
            let trem = soft ? 1 - 0.18 * (0.5 + 0.5 * sin(2 * .pi * 4.5 * t)) : 1
            let w = sin(2 * .pi * f * t) + (soft ? 0.35 : 0.5) * sin(4 * .pi * f * t) * exp(-t * 6) + (soft ? 0.1 : 0.25) * sin(6 * .pi * f * t) * exp(-t * 9)
            return Float(w * trem * min(1, t / 0.004) * exp(-t * (soft ? 2.2 : 5))) * 0.3
        }
    }

    /// A held chord of detuned saws, softened — the pad under everything.
    static func pad(_ notes: [Int], seconds: Double, brightness: Double = 1800) -> [Float] {
        let n = Int(seconds * rate)
        var out = [Float](repeating: 0, count: n)
        for (k, m) in notes.enumerated() {
            for d in [-0.11, 0.0, 0.13] {
                let f = hz(m) * pow(2, d / 12)
                var ph = Double(k) * 0.7
                for i in 0..<n {
                    ph += f / rate; if ph > 1 { ph -= 1 }
                    out[i] += Float(2 * ph - 1) * 0.06
                }
            }
        }
        out = VoiceFX.filter(out, "lowpass", f: brightness, rate: rate)
        let fade = 0.25 * rate
        for i in 0..<n {
            let a = min(1, Double(i) / fade), r = min(1, Double(n - i) / fade)
            out[i] *= Float(a * r)
        }
        return out
    }

    /// The low brass blast trailers use: a stack of saws that opens up, then dies away.
    static func braam(_ root: Int = 36, seconds: Double = 2.2) -> [Float] {
        let n = Int(seconds * rate)
        var out = [Float](repeating: 0, count: n)
        for m in [root, root + 7, root + 12] {
            for d in [-0.15, 0.0, 0.17] {
                let f = hz(m) * pow(2, d / 12)
                var ph = 0.0
                for i in 0..<n { ph += f / rate; if ph > 1 { ph -= 1 }; out[i] += Float(2 * ph - 1) * 0.12 }
            }
        }
        out = VoiceFX.drive(VoiceFX.filter(out, "lowpass", f: 900, rate: rate), amount: 2)
        for i in 0..<n {
            let t = Double(i) / rate
            out[i] *= Float(min(1, t / 0.05) * exp(-t / (seconds * 0.45)))
        }
        return out
    }

    /// Noise and a tone rising for `seconds`, ending on the drop.
    static func riser(seconds: Double = 2) -> [Float] {
        let n = Int(seconds * rate)
        let hiss = noise(n, seed: 31)
        var ph = 0.0
        return (0..<n).map { i in
            let p = Double(i) / Double(n)
            ph += (200 + 1600 * p * p) / rate; if ph > 1 { ph -= 1 }
            return (hiss[i] * Float(0.25 * p) + Float(2 * ph - 1) * Float(0.12 * p)) * Float(p)
        }
    }

    // MARK: music

    /// Chords for four bars, as MIDI notes, and the bass root of each.
    private static let progression: [(chord: [Int], root: Int)] = [([60, 64, 67], 36), ([55, 59, 62], 43), ([57, 60, 64], 45), ([53, 57, 60], 41)]   // C G Am F
    private static let minorProgression: [(chord: [Int], root: Int)] = [([57, 60, 64], 33), ([53, 57, 60], 41), ([48, 52, 55], 36), ([55, 59, 62], 43)]   // Am F C G

    /// A track in `style` lasting `seconds` (whole bars, ending on a hit), and the time of every beat in it.
    static func track(_ styleID: String, seconds: Double) -> (samples: [Float], beats: [Double]) {
        let st = style(styleID)
        let beat = 60 / st.bpm, bar = beat * 4
        let bars = max(2, Int((seconds / bar).rounded(.up)))
        let total = Double(bars) * bar + 1.5
        var out = [Float](repeating: 0, count: Int(total * rate))
        let k = kick(punch: st.id == "chill" ? 0.6 : 1), sn = snare(soft: st.id == "chill"), cl = clap(), ch = hat(), oh = hat(open: true), tk = taiko()
        let prog = st.id == "epic" || st.id == "chill" ? minorProgression : progression
        var beats: [Double] = []
        for b in 0..<bars {
            let t0 = Double(b) * bar
            let p = prog[b % 4]
            // The first bar is lighter, so the second lands like a drop.
            let intro = b == 0 && bars > 2
            switch st.id {
            case "party":
                for q in 0..<4 { mix(k, into: &out, at: t0 + Double(q) * beat, gain: intro ? 0.6 : 1) }
                for q in [1, 3] { mix(cl, into: &out, at: t0 + Double(q) * beat, gain: 0.7) }
                for q in 0..<4 { mix(oh, into: &out, at: t0 + (Double(q) + 0.5) * beat, gain: 0.55) }
                if !intro { for q in 0..<4 { mix(bass(p.root + 12, seconds: beat * 0.45, bright: 0.6), into: &out, at: t0 + (Double(q) + 0.5) * beat) } }
                mix(pad(p.chord.map { $0 + 12 }, seconds: bar, brightness: intro ? 900 : 3200), into: &out, at: t0, gain: 0.8)
            case "chill":
                mix(k, into: &out, at: t0, gain: 0.8); mix(k, into: &out, at: t0 + 2.5 * beat, gain: 0.6)
                for q in [1, 3] { mix(sn, into: &out, at: t0 + Double(q) * beat, gain: 0.7) }
                for e in 0..<8 { mix(ch, into: &out, at: t0 + Double(e) * beat / 2 + (e % 2 == 1 ? beat * 0.08 : 0), gain: 0.35) }   // a lazy swing
                mix(bass(p.root, seconds: bar * 0.95, bright: 0.1), into: &out, at: t0, gain: 0.9)
                for (j, m) in p.chord.enumerated() { mix(pluck(m, seconds: bar, soft: true), into: &out, at: t0 + Double(j) * 0.02) }
            case "epic":
                mix(tk, into: &out, at: t0); mix(tk, into: &out, at: t0 + 1.5 * beat, gain: 0.7); mix(tk, into: &out, at: t0 + 2 * beat, gain: 0.85)
                mix(k, into: &out, at: t0 + 3 * beat, gain: 0.8)
                if b % 2 == 0 { mix(braam(p.root, seconds: bar * 1.1), into: &out, at: t0, gain: intro ? 0.5 : 0.85) }
                mix(pad(p.chord.map { $0 - 12 }, seconds: bar, brightness: 1400), into: &out, at: t0, gain: 0.9)
                if b == bars - 2 { mix(riser(seconds: bar), into: &out, at: t0, gain: 0.8) }
            default:   // upbeat
                for q in 0..<4 { mix(k, into: &out, at: t0 + Double(q) * beat, gain: intro ? 0.6 : 0.95) }
                for q in [1, 3] { mix(sn, into: &out, at: t0 + Double(q) * beat, gain: 0.8) }
                for e in 0..<8 { mix(ch, into: &out, at: t0 + Double(e) * beat / 2, gain: 0.4) }
                if !intro { for e in 0..<8 { mix(bass(p.root, seconds: beat * 0.4), into: &out, at: t0 + Double(e) * beat / 2, gain: 0.75) } }
                let arp = p.chord + [p.chord[0] + 12]
                for s in 0..<16 { mix(pluck(arp[s % arp.count] + 12, seconds: beat * 0.5), into: &out, at: t0 + Double(s) * beat / 4, gain: 0.55) }
                mix(pad(p.chord, seconds: bar, brightness: 1500), into: &out, at: t0, gain: 0.6)
            }
            for q in 0..<4 { beats.append(t0 + Double(q) * beat) }
        }
        // The ending: one big hit on the last downbeat, ringing out.
        let end = Double(bars) * bar
        mix(st.id == "epic" ? braam(prog[0].root, seconds: 1.5) : k, into: &out, at: end, gain: 1)
        mix(pad(prog[0].chord, seconds: 1.5, brightness: 2200), into: &out, at: end, gain: 0.8)
        return (VoiceFX.level(out), beats)
    }

    // MARK: sound effects

    struct Effect: Identifiable, Equatable { let id: String, name: String, emoji: String }
    static let effects: [Effect] = [
        Effect(id: "scratch", name: "Record scratch", emoji: "💿"), Effect(id: "boing", name: "Boing", emoji: "🪀"),
        Effect(id: "sting", name: "Dun dun dun", emoji: "😱"), Effect(id: "rimshot", name: "Ba-dum-tss", emoji: "🥁"),
        Effect(id: "crickets", name: "Crickets", emoji: "🦗"), Effect(id: "horn", name: "Air horn", emoji: "📯"),
        Effect(id: "whoosh", name: "Whoosh", emoji: "💨"), Effect(id: "pop", name: "Pop", emoji: "🫧"),
    ]

    static func effect(_ id: String) -> [Float] {
        var out: [Float]
        switch id {
        case "boing":
            let n = Int(0.75 * rate)
            var ph = 0.0
            out = (0..<n).map { i in
                let t = Double(i) / rate
                ph += 2 * .pi * (230 + 150 * sin(2 * .pi * 11 * t) * exp(-t * 3.5) + 120 * exp(-t * 9)) / rate
                return Float((sin(ph) + 0.3 * sin(2 * ph)) * exp(-t * 4.2)) * 0.8
            }
        case "scratch":
            // Two quick drags of a record: filtered noise and a tone, sweeping down and back up.
            let n = Int(0.45 * rate)
            let hiss = noise(n, seed: 3)
            var ph = 0.0
            out = (0..<n).map { i in
                let t = Double(i) / rate
                let sweep = t < 0.18 ? 1 - t / 0.18 : (t - 0.18) / 0.27
                let f = 180 + 1100 * sweep
                ph += f / rate; if ph > 1 { ph -= 1 }
                return (hiss[i] * Float(0.45 * sweep) + Float(2 * ph - 1) * 0.35) * Float(min(1, t / 0.005) * (t < 0.4 ? 1 : (0.45 - t) / 0.05))
            }
            out = VoiceFX.filter(out, "bandpass", f: 1200, q: 0.7, rate: rate)
        case "sting":
            out = [Float](repeating: 0, count: Int(2.6 * rate))
            mix(braam(50, seconds: 0.45), into: &out, at: 0, gain: 0.8)
            mix(braam(53, seconds: 0.45), into: &out, at: 0.5, gain: 0.8)
            mix(braam(49, seconds: 1.8), into: &out, at: 1.0, gain: 1)
        case "rimshot":
            out = [Float](repeating: 0, count: Int(1.6 * rate))
            func tom(_ f: Double) -> [Float] {
                (0..<Int(0.3 * rate)).map { i in let t = Double(i) / rate; return Float(sin(2 * .pi * (f + 60 * exp(-t * 20)) * t) * exp(-t * 11)) * 0.8 }
            }
            mix(tom(190), into: &out, at: 0); mix(tom(150), into: &out, at: 0.16)
            let crash = VoiceFX.filter(noise(Int(1.3 * rate), seed: 17), "highpass", f: 4500, rate: rate)
            mix(crash.enumerated().map { i, v in v * Float(exp(-Double(i) / rate * 2.2)) * 0.6 }, into: &out, at: 0.32)
            mix(kick(punch: 0.5), into: &out, at: 0.32, gain: 0.5)
        case "crickets":
            out = [Float](repeating: 0, count: Int(2.4 * rate))
            for c in 0..<6 {
                for k in 0..<3 {
                    let chirp: [Float] = (0..<Int(0.035 * rate)).map { i in
                        let t = Double(i) / rate
                        return Float(sin(2 * .pi * 4600 * t) * sin(.pi * t / 0.035)) * 0.35
                    }
                    mix(chirp, into: &out, at: Double(c) * 0.4 + Double(k) * 0.055)
                }
            }
        case "horn":
            out = [Float](repeating: 0, count: Int(1.6 * rate))
            for (start, len) in [(0.0, 0.18), (0.24, 0.18), (0.48, 0.9)] {
                let n = Int(len * rate)
                var blast = [Float](repeating: 0, count: n)
                for f in [440.0, 466.0, 554.0] {
                    var ph = 0.0
                    for i in 0..<n {
                        let t = Double(i) / rate
                        ph += f * (1 + 0.006 * sin(2 * .pi * 6 * t)) / rate; if ph > 1 { ph -= 1 }
                        blast[i] += Float(2 * ph - 1) * 0.22 * Float(min(1, t / 0.01) * min(1, (len - t) / 0.03))
                    }
                }
                mix(VoiceFX.drive(blast, amount: 2.5), into: &out, at: start)
            }
        case "whoosh":
            let n = Int(0.7 * rate)
            let hiss = noise(n, seed: 23)
            var bq = VoiceFX.Biquad.make("bandpass", f: 400, q: 1.5, rate: rate)
            out = (0..<n).map { i in
                let p = Double(i) / Double(n)
                if i % 64 == 0 { bq = VoiceFX.Biquad.make("bandpass", f: 300 + 3500 * p, q: 1.5, rate: rate) }
                return bq.run(hiss[i]) * Float(sin(.pi * p)) * 2.2
            }
        case "pop":
            let n = Int(0.08 * rate)
            out = (0..<n).map { i in let t = Double(i) / rate; return Float(sin(2 * .pi * (600 + 9000 * t) * t) * exp(-t * 45)) * 0.9 }
        default:
            out = []
        }
        return out.isEmpty ? out : VoiceFX.level(out)
    }

    // MARK: files

    /// 16-bit mono WAV of `x`.
    static func wav(_ x: [Float]) -> Data {
        var pcm = [UInt8](); pcm.reserveCapacity(x.count * 2)
        for v in x {
            let s16 = Int16(max(-1, min(1, v)) * 32767)
            pcm.append(UInt8(truncatingIfNeeded: s16)); pcm.append(UInt8(truncatingIfNeeded: s16 >> 8))
        }
        return Data(ChainText.wavHeader(sampleRate: Int(rate), channels: 1, dataBytes: pcm.count)) + Data(pcm)
    }

    /// Writes `x` as a WAV in the temporary folder.
    static func file(_ x: [Float], name: String) -> URL? {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString.prefix(8)).wav")
        return (try? wav(x).write(to: u)) != nil ? u : nil
    }
}
