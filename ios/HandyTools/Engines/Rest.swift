import Foundation
import AVFoundation

/// Noise synthesis (no bundled audio — generated live, so it never loops audibly) and the
/// sound-triggered night recorder's decision logic, kept pure so it can be unit-tested.
enum NoiseSynth {
    enum Kind: Int, CaseIterable { case white, pink, brown, fan, rain, ocean
        var title: String { ["White", "Pink", "Brown", "Fan", "Rain", "Ocean"][rawValue] }
        var icon: String { ["waveform", "waveform.path", "wind", "fanblades", "cloud.rain", "water.waves"][rawValue] } }

    /// Per-channel filter state. Pink = Paul Kellet's 3-pole approximation; brown = leaky integrator.
    struct State {
        var b0 = 0.0, b1 = 0.0, b2 = 0.0, brown = 0.0, lp = 0.0
        var dropletEnv = 0.0, dropletHz = 0.0, dropletPhase = 0.0
        var t = 0.0
        var rng = SystemRandomNumberGenerator()

        mutating func next(_ kind: Kind, sampleRate: Double) -> Float {
            let white = Double.random(in: -1...1, using: &rng)
            t += 1 / sampleRate
            switch kind {
            case .white: return Float(white * 0.35)
            case .pink: return Float(pink(white) * 0.5)
            case .brown: return Float(brownStep(white) * 2.2)
            case .fan:
                // brown noise with a gentle 3 Hz blade wobble and a soft low-pass
                let w = 1 + 0.12 * sin(2 * .pi * 3.1 * t)
                lp += 0.08 * (brownStep(white) * 2.2 * w - lp)
                return Float(lp * 1.6)
            case .rain:
                // pink bed plus random droplet "ticks" with a short decaying envelope
                if dropletEnv < 0.01, Double.random(in: 0...1, using: &rng) < 60 / sampleRate { dropletEnv = Double.random(in: 0.3...1, using: &rng); dropletHz = Double.random(in: 1800...5200, using: &rng) }
                dropletEnv *= 0.9985
                dropletPhase += dropletHz / sampleRate
                let drop = sin(2 * .pi * dropletPhase) * dropletEnv * 0.25
                return Float(pink(white) * 0.35 + drop)
            case .ocean:
                // brown noise swelling on a ~9-second wave cycle
                let swell = 0.35 + 0.65 * pow(max(0, sin(2 * .pi * t / 9)), 2)
                lp += 0.05 * (brownStep(white) * 2.2 - lp)
                return Float(lp * swell * 1.8)
            }
        }
        private mutating func pink(_ w: Double) -> Double {
            b0 = 0.99765 * b0 + w * 0.0990460
            b1 = 0.96300 * b1 + w * 0.2965164
            b2 = 0.57000 * b2 + w * 1.0526913
            return (b0 + b1 + b2 + w * 0.1848) * 0.18
        }
        private mutating func brownStep(_ w: Double) -> Double {
            brown = (brown + 0.02 * w) / 1.02
            return brown
        }
    }

    /// Render `n` samples (for tests / previews).
    static func render(_ kind: Kind, samples n: Int, sampleRate: Double = 44100) -> [Float] {
        var s = State(); return (0..<n).map { _ in s.next(kind, sampleRate: sampleRate) }
    }
}

/// Decides when the night recorder should capture: sound must rise well above the room's own
/// baseline for a moment, and a clip ends after things have been quiet for a while.
struct SoundEventDetector {
    var baselineDB: Double = 35
    var riseDB: Double = 12          // how far above baseline counts as an event
    var armSeconds: Double = 0.4     // must stay loud this long to start
    var holdSeconds: Double = 8      // keep recording this long after the last loud moment
    var maxSeconds: Double = 60

    private(set) var recording = false
    private var loudSince: Double?
    private var lastLoud: Double = 0
    private var startedAt: Double = 0
    private(set) var events: [(start: Double, end: Double, peakDB: Double)] = []
    private var peak = 0.0

    init(baselineDB: Double = 35, riseDB: Double = 12, armSeconds: Double = 0.4, holdSeconds: Double = 8, maxSeconds: Double = 60) {
        self.baselineDB = baselineDB; self.riseDB = riseDB; self.armSeconds = armSeconds; self.holdSeconds = holdSeconds; self.maxSeconds = maxSeconds
    }

    /// Feed a level at time `t` (seconds). Returns .start / .stop when the recording state changes.
    enum Change { case none, start, stop }
    mutating func feed(db: Double, at t: Double) -> Change {
        let loud = db > baselineDB + riseDB
        if !recording {
            // slowly learn the room while idle so a fan or a snoring partner's hum becomes "normal"
            if !loud { baselineDB = baselineDB * 0.995 + db * 0.005 }
            if loud { if loudSince == nil { loudSince = t } } else { loudSince = nil }
            if let s = loudSince, t - s >= armSeconds {
                recording = true; startedAt = s; lastLoud = t; peak = db; loudSince = nil
                return .start
            }
            return .none
        }
        if loud { lastLoud = t }
        peak = max(peak, db)
        if t - lastLoud >= holdSeconds || t - startedAt >= maxSeconds {
            recording = false
            events.append((startedAt, t, peak))
            return .stop
        }
        return .none
    }
}
