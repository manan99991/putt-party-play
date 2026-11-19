import Foundation

/// Guided tuning: one string at a time, measured against THAT string (not just the nearest note), with which way to
/// turn the peg. Pure and unit-tested.
enum TuneGuide {
    enum Move: Equatable { case wrongString(heard: Double), up(cents: Double), down(cents: Double), inTune }

    /// How far `hz` is from the string's own pitch, and what to do about it.
    static func advice(hz: Double, target: Double) -> Move {
        guard hz > 0, target > 0 else { return .wrongString(heard: hz) }
        let cents = 1200 * log2(hz / target)
        if abs(cents) > 450 { return .wrongString(heard: hz) }     // more than ~a fourth away: another string
        if abs(cents) <= 5 { return .inTune }
        return cents < 0 ? .up(cents: -cents) : .down(cents: cents)
    }

    static func words(_ m: Move) -> String {
        switch m {
        case .wrongString: return "That's a different string — play the one shown"
        case .up(let c): return c > 30 ? "Tune up — tighten the peg" : "Nearly — tighten a touch"
        case .down(let c): return c > 30 ? "Tune down — loosen the peg" : "Nearly — loosen a touch"
        case .inTune: return "In tune — hold it…"
        }
    }
}
