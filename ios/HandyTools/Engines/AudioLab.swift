import Foundation
import AVFoundation
import Accelerate

/// Pitch math + a tone generator + a live tuner — the engine under Audio Lab.
enum Pitch {
    static let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    /// Nearest note to a frequency (A4 = 440): name, octave, and cents off (−50…50).
    static func note(for hz: Double, a4: Double = 440) -> (name: String, octave: Int, cents: Double) {
        guard hz > 0 else { return ("—", 0, 0) }
        let n = 12 * log2(hz / a4) + 69        // MIDI number, fractional
        let midi = Int(n.rounded())
        let cents = (n - Double(midi)) * 100
        return (names[((midi % 12) + 12) % 12], midi / 12 - 1, cents)
    }

    static func frequency(midi: Int, a4: Double = 440) -> Double { a4 * pow(2, Double(midi - 69) / 12) }

    /// Fundamental frequency of a mono buffer via normalized autocorrelation (McLeod-style peak pick).
    /// Returns nil when the signal is too quiet or too noisy to trust (clarity < 0.85).
    static func detect(_ x: [Float], sampleRate: Double, minHz: Double = 50, maxHz: Double = 1500) -> (hz: Double, clarity: Double)? {
        let n = x.count
        guard n >= 1024 else { return nil }
        var rms: Float = 0
        vDSP_rmsqv(x, 1, &rms, vDSP_Length(n))
        guard rms > 0.005 else { return nil }
        let maxLag = min(n / 2, Int(sampleRate / minHz)), minLag = max(2, Int(sampleRate / maxHz))
        guard maxLag > minLag else { return nil }
        // normalized square difference function
        var nsdf = [Float](repeating: 0, count: maxLag + 1)
        x.withUnsafeBufferPointer { xp in
            for lag in minLag...maxLag {
                var acf: Float = 0, m: Float = 0
                vDSP_dotpr(xp.baseAddress!, 1, xp.baseAddress! + lag, 1, &acf, vDSP_Length(n - lag))
                var e0: Float = 0, e1: Float = 0
                vDSP_svesq(xp.baseAddress!, 1, &e0, vDSP_Length(n - lag))
                vDSP_svesq(xp.baseAddress! + lag, 1, &e1, vDSP_Length(n - lag))
                m = e0 + e1
                nsdf[lag] = m > 0 ? 2 * acf / m : 0
            }
        }
        // first positive-going zero crossing, then the highest peak after it; accept peaks ≥ 0.9 × global max
        var start = minLag
        while start < maxLag, nsdf[start] > 0 { start += 1 }
        var best = -1, bestV: Float = 0
        var i = start
        while i < maxLag {
            if nsdf[i] > 0 {
                var peak = i
                while i < maxLag, nsdf[i] > 0 { if nsdf[i] > nsdf[peak] { peak = i }; i += 1 }
                if nsdf[peak] > bestV { bestV = nsdf[peak]; best = peak }
            } else { i += 1 }
        }
        guard best > 0 else { return nil }
        // pick the *first* peak that is within 0.9 of the best (avoids octave errors)
        var chosen = best
        i = start
        while i < maxLag {
            if nsdf[i] > 0 {
                var peak = i
                while i < maxLag, nsdf[i] > 0 { if nsdf[i] > nsdf[peak] { peak = i }; i += 1 }
                if nsdf[peak] >= 0.9 * bestV { chosen = peak; break }
            } else { i += 1 }
        }
        let clarity = Double(nsdf[chosen])
        guard clarity >= 0.85 else { return nil }
        // parabolic interpolation around the chosen lag
        var lag = Double(chosen)
        if chosen > 0, chosen < maxLag {
            let a = Double(nsdf[chosen - 1]), b = Double(nsdf[chosen]), c = Double(nsdf[chosen + 1])
            let d = a - 2 * b + c
            if d != 0 { lag += 0.5 * (a - c) / d }
        }
        return (sampleRate / lag, clarity)
    }
}

/// Plays sine / square / triangle tones, pans, sweeps, and the 165 Hz water-eject pulse.
@MainActor final class ToneGenerator: ObservableObject {
    enum Wave: Int, CaseIterable { case sine, square, triangle; var title: String { ["Sine", "Square", "Triangle"][rawValue] } }
    @Published var playing = false
    @Published var frequency: Double = 440 { didSet { params.hz = frequency } }
    @Published var volume: Double = 0.5 { didSet { params.gain = Float(volume) } }
    @Published var wave: Wave = .sine { didSet { params.wave = wave.rawValue } }
    @Published var pan: Double = 0 { didSet { params.pan = Float(pan) } }   // −1 left … 1 right

    private final class Params: @unchecked Sendable { var hz = 440.0; var gain: Float = 0.5; var wave = 0; var pan: Float = 0; var pulse = false; var phase = 0.0; var t = 0.0 }
    private let params = Params()
    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private var sweep: Task<Void, Never>?

    func start() {
        guard !playing else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        let hwRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let rate = hwRate > 0 ? hwRate : 44_100   // hardware can report 0 before the route is ready
        let p = params
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return }
        let n = AVAudioSourceNode(format: fmt) { _, _, frameCount, abl -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            guard buffers.count >= 2, let l = buffers[0].mData?.assumingMemoryBound(to: Float.self), let r = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let inc = p.hz / rate
            let lg = p.gain * min(1, 1 - p.pan), rg = p.gain * min(1, 1 + p.pan)
            for i in 0..<Int(frameCount) {
                p.phase += inc; if p.phase >= 1 { p.phase -= 1 }
                p.t += 1 / rate
                var s: Float
                switch p.wave {
                case 1: s = p.phase < 0.5 ? 1 : -1
                case 2: s = Float(4 * abs(p.phase - 0.5) - 1)
                default: s = Float(sin(2 * Double.pi * p.phase))
                }
                if p.pulse { let on = fmod(p.t, 0.5) < 0.3; s = on ? s : 0 }   // 165 Hz bursts, 300 ms on / 200 ms off
                s *= 0.6
                l[i] = s * lg; r[i] = s * rg
            }
            return noErr
        }
        engine.attach(n)
        engine.connect(n, to: engine.mainMixerNode, format: fmt)
        node = n
        try? engine.start()
        playing = engine.isRunning
    }

    func stop() {
        sweep?.cancel(); sweep = nil
        params.pulse = false
        engine.stop()
        if let n = node { engine.detach(n); node = nil }
        playing = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Water eject: the 165 Hz pulse Apple Watch uses, for ~12 s.
    func waterEject() {
        wave = .square; frequency = 165; volume = 1; pan = 0
        params.pulse = true
        start()
        sweep?.cancel()
        sweep = Task { try? await Task.sleep(for: .seconds(12)); if !Task.isCancelled { self.stop() } }
    }

    /// Glide from `from` to `to` Hz over `seconds` (speaker / hearing-range sweep).
    func sweep(from: Double, to: Double, seconds: Double) {
        start()
        sweep?.cancel()
        sweep = Task {
            let steps = Int(seconds * 30)
            for i in 0...steps {
                if Task.isCancelled { return }
                let f = from * pow(to / from, Double(i) / Double(steps))   // logarithmic glide
                self.frequency = f
                try? await Task.sleep(for: .milliseconds(Int(1000 / 30)))
            }
            self.stop()
        }
    }
}

/// Microphone → pitch, 20× a second.
@MainActor final class Tuner: ObservableObject {
    @Published var hz: Double = 0
    @Published var clarity: Double = 0
    @Published var note = "—"
    @Published var octave = 0
    @Published var cents = 0.0
    @Published var denied = false
    @Published var a4 = 440.0
    private let engine = AVAudioEngine()
    private var smooth = 0.0

    func start() {
        Permission.microphone { [weak self] ok in
            Task { @MainActor in
                guard let self else { return }
                if !ok { self.denied = true; return }
                self.begin()
            }
        }
    }
    private func begin() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
        try? session.setActive(true)
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0 else { return }
        let rate = fmt.sampleRate
        input.installSendableTap(bufferSize: 4096, format: fmt) { [weak self] buf, _ in
            guard let ch = buf.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: ch, count: Int(buf.frameLength)))
            let r = Pitch.detect(samples, sampleRate: rate)
            Task { @MainActor in self?.publish(r) }
        }
        try? engine.start()
    }
    private func publish(_ r: (hz: Double, clarity: Double)?) {
        guard let r else { clarity = max(0, clarity - 0.2); return }
        smooth = smooth == 0 ? r.hz : (abs(r.hz - smooth) / smooth > 0.06 ? r.hz : smooth * 0.6 + r.hz * 0.4)
        hz = smooth; clarity = r.clarity
        let n = Pitch.note(for: smooth, a4: a4)
        note = n.name; octave = n.octave; cents = n.cents
    }
    func stop() {
        engine.inputNode.removeTap(onBus: 0); engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
