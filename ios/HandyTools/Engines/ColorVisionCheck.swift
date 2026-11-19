import Foundation
import simd

/// Two helpers for Color Vision, both pure and unit-tested:
/// - A quick "which type am I?" check made of colour pairs that one kind of colour-blind eye can't tell apart
///   (built from the same simulation the app uses, not copied test plates). A helper, not a diagnosis.
/// - "Do these match?": how far apart two colours are, in words, for socks, paint and cables.
enum ColorVisionCheck {

    // MARK: - The check

    /// The colour direction a deficiency can't see: the one its simulation squashes to (almost) nothing.
    static func confusionDirection(_ d: ColorVision.Deficiency) -> SIMD3<Float> {
        let m = ColorVision.simulationMatrix(d, severity: 1)
        let t = m.transpose
        let rows = [t.columns.0, t.columns.1, t.columns.2]
        var best = SIMD3<Float>(0, 0, 0)
        for (i, j) in [(0, 1), (0, 2), (1, 2)] {
            let c = simd_cross(rows[i], rows[j])
            if simd_length(c) > simd_length(best) { best = c }
        }
        return simd_normalize(best)
    }

    /// One round: a grid of tiles of one colour with one odd tile that only that deficiency confuses.
    struct Round: Equatable {
        let deficiency: ColorVision.Deficiency
        let base: SIMD3<Float>
        let odd: SIMD3<Float>
        let oddIndex: Int
        let tiles: [SIMD3<Float>]      // every tile, with a little brightness jitter so lightness gives nothing away
    }

    /// Mid-tone bases that keep both colours of a pair inside what a screen can show.
    static let bases: [SIMD3<Float>] = [[0.55, 0.5, 0.35], [0.45, 0.55, 0.5], [0.6, 0.45, 0.5], [0.5, 0.5, 0.55]]

    /// Two screen colours (sRGB) that differ only along `d`'s blind direction. The simulation works in
    /// linear light, so the pair is built there and converted back for the screen.
    static func pair(_ d: ColorVision.Deficiency, base: SIMD3<Float>, step: Float = 0.3) -> (SIMD3<Float>, SIMD3<Float>) {
        let v = confusionDirection(d)
        let b = linear(base)
        var k = step
        func inGamut(_ c: SIMD3<Float>) -> Bool { c.min() >= 0.02 && c.max() <= 0.95 }
        while k > 0.05, !(inGamut(b + v * (k / 2)) && inGamut(b - v * (k / 2))) { k -= 0.02 }
        return (srgb(b - v * (k / 2)), srgb(b + v * (k / 2)))
    }

    static func linear(_ c: SIMD3<Float>) -> SIMD3<Float> {
        func f(_ v: Float) -> Float { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return [f(c.x), f(c.y), f(c.z)]
    }
    static func srgb(_ c: SIMD3<Float>) -> SIMD3<Float> {
        func f(_ v: Float) -> Float { let x = max(0, min(1, v)); return x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055 }
        return [f(c.x), f(c.y), f(c.z)]
    }

    static func rounds(tiles: Int = 9, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) -> [Round] {
        var rng = SeededRNG(seed)
        var out: [Round] = []
        // Two rounds per type, shuffled, so the order gives nothing away.
        var plan: [ColorVision.Deficiency] = ColorVision.Deficiency.allCases + ColorVision.Deficiency.allCases
        plan.shuffle(using: &rng)
        for (n, d) in plan.enumerated() {
            let (a, b) = pair(d, base: bases[n % bases.count])
            let oddIndex = Int.random(in: 0..<tiles, using: &rng)
            let list: [SIMD3<Float>] = (0..<tiles).map { i in
                let j = Float.random(in: -0.035...0.035, using: &rng)
                let c = i == oddIndex ? b : a
                return simd_clamp(c + SIMD3(repeating: j), SIMD3(repeating: 0), SIMD3(repeating: 1))
            }
            out.append(Round(deficiency: d, base: a, odd: b, oddIndex: oddIndex, tiles: list))
        }
        return out
    }

    /// The answer, from which rounds were missed. Nil = nothing stood out (typical colour vision on this check).
    static func result(missed: [ColorVision.Deficiency]) -> (type: ColorVision.Deficiency?, line: String) {
        guard !missed.isEmpty else {
            return (nil, "You spotted every odd one out — your colour vision looks typical on this check.")
        }
        var count: [ColorVision.Deficiency: Int] = [:]
        for d in missed { count[d, default: 0] += 1 }
        let top = count.max { a, b in a.value == b.value ? a.key.rawValue > b.key.rawValue : a.value < b.value }!
        let tied = count.values.filter { $0 == top.value }.count > 1
        if tied || missed.count >= 5 {
            return (top.key, "Several colours were hard to tell apart. Try \(top.key.short) first, and compare with the others.")
        }
        return (top.key, "The pairs you missed are the ones \(top.key.short.lowercased()) eyes mix up. Tap Use this to set Color Vision to \(top.key.short).")
    }

    // MARK: - Do these match?

    static func lab(_ c: SIMD3<Float>) -> SIMD3<Float> {
        let l = linear(c)
        let r = l.x, g = l.y, b = l.z
        let x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
        let y = (0.2126 * r + 0.7152 * g + 0.0722 * b)
        let z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
        func f(_ t: Float) -> Float { t > 0.008856 ? cbrt(t) : 7.787 * t + 16 / 116 }
        return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))]
    }

    static func difference(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float { simd_distance(lab(a), lab(b)) }

    static func matchWords(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> String {
        let d = difference(a, b)
        switch d {
        case ..<5: return "Same colour"
        case ..<12: return "Very close — most people would call them the same"
        case ..<25: return "Similar, but you can see the difference side by side"
        default: return "Different colours"
        }
    }
}

/// A small repeatable random source so a check can be replayed in tests.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
