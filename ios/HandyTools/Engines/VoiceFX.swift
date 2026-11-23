import Foundation

/// The character in a changed voice — what makes a robot sound like a robot and a walkie-talkie like a radio, not
/// just "higher" or "lower". Runs on the samples after the pitch shift, on the phone, offline. Each character is a
/// small chain of real effects: ring modulation (robot), a wobbling pitch (alien, ghost, old man), a radio band with
/// static and a squelch at each end (walkie-talkie), distinct echoes (cave), a growl (monster), muffled water and
/// bubbles (underwater)… then levelled so every voice is equally loud. Pure, so the differences are unit-tested.
enum VoiceFX {
    // MARK: building blocks

    /// A second-order filter (the standard audio cookbook).
    struct Biquad {
        var b0: Float, b1: Float, b2: Float, a1: Float, a2: Float
        var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0
        mutating func run(_ x: Float) -> Float {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x; y2 = y1; y1 = y
            return y
        }
        static func make(_ kind: String, f: Double, q: Double = 0.707, gainDB: Double = 0, rate: Double) -> Biquad {
            let w = 2 * Double.pi * min(f, rate * 0.45) / rate, cw = cos(w), sw = sin(w), alpha = sw / (2 * q)
            let A = pow(10, gainDB / 40)
            var b0 = 1.0, b1 = 0.0, b2 = 0.0, a0 = 1.0, a1 = 0.0, a2 = 0.0
            switch kind {
            case "lowpass": b0 = (1 - cw) / 2; b1 = 1 - cw; b2 = (1 - cw) / 2; a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha
            case "highpass": b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = (1 + cw) / 2; a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha
            case "bandpass": b0 = alpha; b1 = 0; b2 = -alpha; a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha
            case "peak": b0 = 1 + alpha * A; b1 = -2 * cw; b2 = 1 - alpha * A; a0 = 1 + alpha / A; a1 = -2 * cw; a2 = 1 - alpha / A
            case "lowshelf":
                let s = 2 * sqrt(A) * alpha
                b0 = A * ((A + 1) - (A - 1) * cw + s); b1 = 2 * A * ((A - 1) - (A + 1) * cw); b2 = A * ((A + 1) - (A - 1) * cw - s)
                a0 = (A + 1) + (A - 1) * cw + s; a1 = -2 * ((A - 1) + (A + 1) * cw); a2 = (A + 1) + (A - 1) * cw - s
            case "highshelf":
                let s = 2 * sqrt(A) * alpha
                b0 = A * ((A + 1) + (A - 1) * cw + s); b1 = -2 * A * ((A - 1) + (A + 1) * cw); b2 = A * ((A + 1) + (A - 1) * cw - s)
                a0 = (A + 1) - (A - 1) * cw + s; a1 = 2 * ((A - 1) - (A + 1) * cw); a2 = (A + 1) - (A - 1) * cw - s
            default: break
            }
            return Biquad(b0: Float(b0 / a0), b1: Float(b1 / a0), b2: Float(b2 / a0), a1: Float(a1 / a0), a2: Float(a2 / a0))
        }
    }

    static func filter(_ x: [Float], _ kind: String, f: Double, q: Double = 0.707, gainDB: Double = 0, rate: Double) -> [Float] {
        var bq = Biquad.make(kind, f: f, q: q, gainDB: gainDB, rate: rate)
        return x.map { bq.run($0) }
    }

    /// Multiply by a tone: the metallic, Dalek-like robot.
    static func ringMod(_ x: [Float], hz: Double, mix: Float, rate: Double) -> [Float] {
        let k = 2 * Double.pi * hz / rate
        return x.enumerated().map { i, v in v * (1 - mix) + v * Float(sin(k * Double(i))) * mix }
    }

    /// The pitch wobbling up and down (a delay line whose length swings): alien warble, ghostly float, old man's quaver.
    static func vibrato(_ x: [Float], hz: Double, depthMs: Double, rate: Double) -> [Float] {
        let depth = depthMs / 1000 * rate, base = depth + 2
        var out = [Float](repeating: 0, count: x.count)
        for i in x.indices {
            let d = base + depth * sin(2 * Double.pi * hz * Double(i) / rate)
            let p = Double(i) - d
            guard p >= 0 else { continue }
            let j = Int(p), f = Float(p - Double(j))
            let a = x[j], b = j + 1 < x.count ? x[j + 1] : a
            out[i] = a + (b - a) * f
        }
        return out
    }

    /// Volume swinging up and down.
    static func tremolo(_ x: [Float], hz: Double, depth: Float, rate: Double) -> [Float] {
        let k = 2 * Double.pi * hz / rate
        return x.enumerated().map { i, v in v * (1 - depth * Float(0.5 + 0.5 * sin(k * Double(i)))) }
    }

    /// Overdrive: rounds off the peaks so it growls and crackles.
    static func drive(_ x: [Float], amount: Float) -> [Float] { x.map { tanh($0 * amount) / tanh(amount) } }

    /// Fewer bits and a lower sample rate: cheap electronics.
    static func crush(_ x: [Float], bits: Int, hold: Int) -> [Float] {
        let levels = Float(1 << max(2, bits - 1))
        var out = x, held: Float = 0
        for i in x.indices {
            if i % max(1, hold) == 0 { held = (x[i] * levels).rounded() / levels }
            out[i] = held
        }
        return out
    }

    /// Distinct repeats, each quieter: "hello… hello… hello".
    static func echoes(_ x: [Float], delays: [Double], decay: Float, rate: Double) -> [Float] {
        let tail = Int((delays.max() ?? 0) * rate * Double(delays.count))
        var out = x + [Float](repeating: 0, count: tail)
        for (n, d) in delays.enumerated() {
            let off = Int(d * rate), g = pow(decay, Float(n + 1))
            for i in x.indices where i + off < out.count { out[i + off] += x[i] * g }
        }
        return out
    }

    /// A short swirl (flanger): spacey, jet-like.
    static func flanger(_ x: [Float], hz: Double, mix: Float, rate: Double) -> [Float] {
        let swept = vibrato(x, hz: hz, depthMs: 2.5, rate: rate)
        return zip(x, swept).map { $0 * (1 - mix) + $1 * mix }
    }

    /// Steady noise under the voice (radio static), following it a little so it never drowns the words.
    static func noiseBed(_ x: [Float], level: Float, seed: UInt64 = 7) -> [Float] {
        var r = SeededRandom(seed: seed)
        return x.map { $0 + Float(r.next(-1, 1)) * level }
    }

    /// A burst of static at the start and end, like pressing and letting go of a walkie-talkie's button.
    static func squelch(_ x: [Float], rate: Double) -> [Float] {
        let n = Int(0.12 * rate)
        var r = SeededRandom(seed: 99)
        let burst = (0..<n).map { i in Float(r.next(-1, 1)) * 0.35 * Float(1 - Double(i) / Double(n)) }
        let beep = (0..<Int(0.09 * rate)).map { i in Float(sin(2 * Double.pi * 1400 * Double(i) / rate)) * 0.25 }
        return burst + x + burst + beep
    }

    /// Bubbles rising: short rising chirps scattered under the voice.
    static func bubbles(_ x: [Float], rate: Double) -> [Float] {
        var out = x
        var r = SeededRandom(seed: 21)
        let every = Int(0.35 * rate), len = Int(0.04 * rate)
        var i = Int(r.next(0, 1) * Double(every))
        while i + len < out.count {
            let f0 = r.next(300, 700)
            for k in 0..<len {
                let t = Double(k) / rate, f = f0 + 6000 * t
                out[i + k] += Float(sin(2 * Double.pi * f * t) * 0.12 * (1 - Double(k) / Double(len)))
            }
            i += Int(Double(every) * r.next(0.4, 1.6))
        }
        return out
    }

    /// Every voice ends up equally loud (peak just under full scale), with a soft limiter for the loud bits.
    static func level(_ x: [Float]) -> [Float] {
        let peak = x.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > 1e-5 else { return x }
        let g = 0.89 / peak
        return x.map { tanh($0 * g * 1.15) / tanh(1.15) * 0.97 }
    }

    // MARK: the characters

    /// The character chain for one voice, applied after its pitch shift.
    static func apply(_ voice: String, _ x: [Float], rate: Double) -> [Float] {
        var y = x
        switch voice {
        case "chipmunk":
            y = filter(y, "highshelf", f: 3000, gainDB: 4, rate: rate)
            y = vibrato(y, hz: 7, depthMs: 0.25, rate: rate)
        case "helium":
            // Thin and squeezed: the low body gone, the top bright, a slight wobble.
            y = filter(y, "highpass", f: 380, rate: rate)
            y = filter(y, "peak", f: 2800, q: 1.2, gainDB: 6, rate: rate)
            y = vibrato(y, hz: 5, depthMs: 0.4, rate: rate)
        case "deep":
            y = filter(y, "lowshelf", f: 180, gainDB: 6, rate: rate)
            y = filter(y, "highshelf", f: 5000, gainDB: -4, rate: rate)
        case "giant":
            y = filter(y, "lowshelf", f: 140, gainDB: 9, rate: rate)
            y = drive(y, amount: 1.6)
            y = echoes(y, delays: [0.09], decay: 0.35, rate: rate)
        case "robot":
            // The classic: ring modulated, metallic comb, a few bits short.
            y = ringMod(y, hz: 55, mix: 0.85, rate: rate)
            y = echoes(y, delays: [0.012], decay: 0.6, rate: rate)
            y = crush(y, bits: 9, hold: 2)
            y = filter(y, "peak", f: 1800, q: 2, gainDB: 5, rate: rate)
        case "alien":
            y = vibrato(y, hz: 6.5, depthMs: 1.8, rate: rate)
            y = ringMod(y, hz: 420, mix: 0.3, rate: rate)
            y = flanger(y, hz: 0.4, mix: 0.5, rate: rate)
        case "monster":
            y = filter(y, "lowshelf", f: 160, gainDB: 8, rate: rate)
            y = drive(y, amount: 4)
            y = tremolo(y, hz: 28, depth: 0.35, rate: rate)     // the growl
            y = filter(y, "lowpass", f: 4500, rate: rate)
        case "walkie":
            y = filter(y, "highpass", f: 450, rate: rate)
            y = filter(y, "lowpass", f: 2600, rate: rate)
            y = drive(y, amount: 3)
            y = crush(y, bits: 8, hold: 3)
            // The radio's tiny speaker: the band again after the crackle, so no boom sneaks back in.
            y = filter(y, "highpass", f: 500, rate: rate)
            y = filter(y, "highpass", f: 500, rate: rate)
            y = filter(y, "lowpass", f: 3000, rate: rate)
            y = noiseBed(y, level: 0.025)
            y = squelch(y, rate: rate)
        case "cave":
            y = echoes(y, delays: [0.32, 0.32, 0.32], decay: 0.5, rate: rate)
            y = filter(y, "lowpass", f: 6000, rate: rate)
        case "ghost":
            y = vibrato(y, hz: 0.9, depthMs: 2.5, rate: rate)
            y = tremolo(y, hz: 3, depth: 0.25, rate: rate)
            y = filter(y, "highpass", f: 250, rate: rate)
            y = noiseBed(y, level: 0.008, seed: 3)               // breathy
        case "baby":
            y = vibrato(y, hz: 6, depthMs: 0.6, rate: rate)
            y = filter(y, "highpass", f: 300, rate: rate)
        case "oldman":
            y = vibrato(y, hz: 5.5, depthMs: 0.9, rate: rate)
            y = tremolo(y, hz: 5.5, depth: 0.3, rate: rate)
            y = filter(y, "highshelf", f: 4000, gainDB: -6, rate: rate)
        case "underwater":
            y = filter(y, "lowpass", f: 650, q: 1.4, rate: rate)
            y = vibrato(y, hz: 1.6, depthMs: 1.5, rate: rate)
            y = bubbles(y, rate: rate)
        case "megaphone":
            y = filter(y, "highpass", f: 700, rate: rate)
            y = filter(y, "lowpass", f: 3800, rate: rate)
            y = filter(y, "peak", f: 1600, q: 1.5, gainDB: 8, rate: rate)
            y = drive(y, amount: 5)
        case "villain":
            y = filter(y, "lowshelf", f: 120, gainDB: 7, rate: rate)
            y = drive(y, amount: 1.8)
            y = echoes(y, delays: [0.06, 0.06], decay: 0.3, rate: rate)
        default: break
        }
        return level(y)
    }

    // MARK: measuring (for tests: proof the voices really differ)

    /// Where the sound's energy sits, in Hz (higher = brighter).
    static func brightness(_ x: [Float], rate: Double) -> Double {
        // Zero crossings per second, halved — a cheap, steady stand-in for the spectral centre.
        var z = 0
        for i in 1..<x.count where (x[i - 1] < 0) != (x[i] < 0) { z += 1 }
        return Double(z) / 2 / (Double(x.count) / rate)
    }

    /// Share of energy below `hz`.
    static func lowShare(_ x: [Float], below hz: Double, rate: Double) -> Double {
        let low = filter(x, "lowpass", f: hz, rate: rate)
        let e = x.reduce(0.0) { $0 + Double($1 * $1) }, l = low.reduce(0.0) { $0 + Double($1 * $1) }
        return e > 0 ? l / e : 0
    }
}
