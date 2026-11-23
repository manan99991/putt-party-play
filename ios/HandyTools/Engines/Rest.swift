import Foundation
import AVFoundation

/// Sleep sounds, all synthesised live on the phone (no audio files, so nothing ever loops audibly): noise colours,
/// nature (rain, rain on a roof, a storm, waves, a stream, wind, birdsong, crickets, a campfire), steady rumbles (a
/// fan, a plane cabin, a train) and calm tones (a singing bowl, a slow warm pad, wind chimes, a music box, a heartbeat,
/// the womb). Every sound is stereo and levelled to about the same loudness, so a mix of two or three stays balanced.
enum NoiseSynth {
    enum Kind: Int, CaseIterable {
        // The first six keep their numbers: saved mixes and older builds refer to them.
        case white, pink, brown, fan, rain, ocean
        case thunder, stream, wind, forest, crickets, campfire, cabin, train
        case bowl, pad, chimes, musicBox, heartbeat, womb, roofRain

        var title: String {
            switch self {
            case .white: return "White"; case .pink: return "Pink"; case .brown: return "Brown"; case .fan: return "Fan"
            case .rain: return "Rain"; case .ocean: return "Ocean"; case .thunder: return "Thunderstorm"; case .stream: return "Stream"
            case .wind: return "Wind"; case .forest: return "Forest"; case .crickets: return "Crickets"; case .campfire: return "Campfire"
            case .cabin: return "Plane cabin"; case .train: return "Train"; case .bowl: return "Singing bowl"; case .pad: return "Deep calm"
            case .chimes: return "Wind chimes"; case .musicBox: return "Music box"; case .heartbeat: return "Heartbeat"; case .womb: return "Womb"
            case .roofRain: return "Roof rain"
            }
        }
        var icon: String {
            switch self {
            case .white: return "waveform"; case .pink: return "waveform.path"; case .brown: return "waveform.circle"; case .fan: return "fanblades"
            case .rain: return "cloud.rain"; case .ocean: return "water.waves"; case .thunder: return "cloud.bolt.rain"; case .stream: return "drop"
            case .wind: return "wind"; case .forest: return "tree"; case .crickets: return "moon.stars"; case .campfire: return "flame"
            case .cabin: return "airplane"; case .train: return "tram.fill"; case .bowl: return "circle.circle"; case .pad: return "sparkles"
            case .chimes: return "bell"; case .musicBox: return "music.note"; case .heartbeat: return "heart"; case .womb: return "moon.zzz"
            case .roofRain: return "house"
            }
        }
        var group: Group { Group.allCases.first { $0.kinds.contains(self) } ?? .noise }
        /// Loudness trim, measured so every sound plays at about the same level (rms ≈ 0.15 for the beds, a little
        /// lower for the tones, which sound louder than noise at the same level).
        fileprivate var gain: Double {
            switch self {
            case .white: return 0.76; case .pink: return 0.99; case .brown: return 1.2; case .fan: return 0.84
            case .rain: return 2.11; case .ocean: return 0.79; case .thunder: return 1.01; case .stream: return 0.9
            case .wind: return 1.09; case .forest: return 3.06; case .crickets: return 5.62; case .campfire: return 1.03
            case .cabin: return 0.51; case .train: return 1.06; case .bowl: return 1.91; case .pad: return 1.89
            case .chimes: return 1.25; case .musicBox: return 3.0; case .heartbeat: return 1.25; case .womb: return 0.93
            case .roofRain: return 0.9
            }
        }
    }

    /// The three shelves on the Sounds page — always whole rows of three.
    enum Group: Int, CaseIterable, Identifiable {
        case nature, noise, calm
        var id: Int { rawValue }
        var title: String { ["Nature", "Noise", "Calm"][rawValue] }
        var kinds: [Kind] {
            switch self {
            case .nature: return [.rain, .roofRain, .thunder, .ocean, .stream, .wind, .forest, .crickets, .campfire]
            case .noise: return [.white, .pink, .brown, .fan, .cabin, .train]
            case .calm: return [.bowl, .pad, .chimes, .musicBox, .heartbeat, .womb]
            }
        }
    }

    /// Ready-made mixes: one tap plays two or three sounds that belong together.
    struct Mix: Identifiable {
        let id: String, title: String, icon: String
        let layers: [(kind: Kind, level: Double)]
    }
    static let maxLayers = 3
    static let mixes: [Mix] = [
        Mix(id: "cabin", title: "Cosy cabin", icon: "house.fill", layers: [(.roofRain, 0.8), (.campfire, 0.6)]),
        Mix(id: "summer", title: "Summer night", icon: "moon.stars.fill", layers: [(.crickets, 0.7), (.stream, 0.45), (.wind, 0.25)]),
        Mix(id: "beach", title: "Ocean breeze", icon: "water.waves", layers: [(.ocean, 0.85), (.wind, 0.3)]),
        Mix(id: "deep", title: "Deep sleep", icon: "bed.double.fill", layers: [(.brown, 0.7), (.pad, 0.35)]),
        Mix(id: "meditate", title: "Meditate", icon: "sparkles", layers: [(.bowl, 0.7), (.stream, 0.35), (.chimes, 0.3)]),
        Mix(id: "baby", title: "Baby sleep", icon: "moon.zzz.fill", layers: [(.womb, 0.8), (.musicBox, 0.35)]),
    ]

    private struct Voice { var f = 0.0, ph = 0.0, a = 0.0, dec = 0.0, glide = 1.0, pan = 0.5 }
    private struct SVF { var low = 0.0, band = 0.0 }
    private struct Pink { var b0 = 0.0, b1 = 0.0, b2 = 0.0 }
    private struct Drift { var v = 0.5, target = 0.5 }
    private struct Bird { var next = 0.0, start = 0.0, dur = 0.0, f0 = 0.0, f1 = 0.0, amp = 0.0, pan = 0.5, ph = 0.0, notes = 0, species = 0 }
    /// Filter coefficients, worked out once per sample rate instead of every sample.
    private struct Consts {
        let fs: Double
        let c140, c260, c300, c600, c700, c900, c1500, c7000: Double
        let d3, d4, d5, d7, d12, d22: Double
        init(fs: Double) {
            self.fs = fs
            func c(_ hz: Double) -> Double { fs > 0 ? 1 - exp(-2 * .pi * hz / fs) : 0 }
            func d(_ ms: Double) -> Double { fs > 0 ? exp(-1 / (ms * 0.001 * fs)) : 0 }
            c140 = c(140); c260 = c(260); c300 = c(300); c600 = c(600); c700 = c(700); c900 = c(900); c1500 = c(1500); c7000 = c(7000)
            d3 = d(3); d4 = d(4); d5 = d(5); d7 = d(7); d12 = d(12); d22 = d(22)
        }
    }

    private static let streamBands: [Double] = [550, 1300, 3000]
    private static let cricketHz: [Double] = [4300, 4800, 3900], cricketEvery: [Double] = [0.52, 0.41, 0.66]
    private static let cricketOffset: [Double] = [0, 0.17, 0.31], cricketPan: [Double] = [0.2, 0.8, 0.5], cricketAmp: [Double] = [0.16, 0.12, 0.09]
    private static let trainPattern: [Double] = [0, 0.13, 0.86, 0.99]   // two wheels over a joint, then the next car's two
    private static let bowlNotes: [Double] = [174.6, 196.0, 220.0, 261.6]
    private static let bowlRatio: [Double] = [1, 2.71, 5.15, 8.4], bowlGain: [Double] = [1, 0.45, 0.22, 0.08], bowlDecay: [Double] = [16, 10, 5, 3]
    private static let padChords: [Double] = [110, 164.8, 246.9, 261.6, 87.3, 130.8, 164.8, 220.0, 130.8, 196.0, 293.7, 329.6, 98.0, 146.8, 246.9, 293.7]
    private static let chimeNotes: [Double] = [1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0]
    private static let chimeRatio: [Double] = [1, 2.76, 5.4], chimeGain: [Double] = [1, 0.4, 0.18], chimeDecay: [Double] = [4, 2.5, 1.2]
    private static let pentatonic: [Int] = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]
    private static let melodySteps: [Int] = [-2, -1, 1, 2]
    private static let boxRatio: [Double] = [1, 2, 3, 4.2], boxGain: [Double] = [1, 0.32, 0.1, 0.07], boxDecay: [Double] = [1.8, 1.0, 0.6, 0.35]

    /// One sound's running state: filters, a pool of ringing tones, and its own random numbers. `frame` gives one
    /// stereo sample. Everything lives in fixed-size storage that `reset` clears in place, so the audio thread never
    /// allocates.
    struct State {
        private var rng: UInt64
        private(set) var t = 0.0
        private var k = Consts(fs: 0)
        private var pk = [Pink](repeating: Pink(), count: 2)
        private var br = [Double](repeating: 0, count: 4)
        private var p = [Double](repeating: 0, count: 8)          // one-pole filter memories
        private var env = [Double](repeating: 0, count: 2)
        private var aux = [Double](repeating: 0, count: 8)
        private var sv = [SVF](repeating: SVF(), count: 6)
        private var v = [Voice](repeating: Voice(), count: 32)
        private var d = [Drift](repeating: Drift(), count: 4)
        private var bird = [Bird](repeating: Bird(), count: 2)
        private var ph = [Double](repeating: 0, count: 8), pf = [Double](repeating: 0, count: 4)
        private var nextEv = 0.0, t0 = 0.0, step = 0, idx = 0

        init(seed: UInt64? = nil) {
            var g = SystemRandomNumberGenerator()
            rng = (seed ?? g.next()) | 1
        }

        /// Start the sound over without allocating (called on the audio thread when a mix slot changes sound).
        mutating func reset() {
            t = 0; nextEv = 0; t0 = 0; step = 0; idx = 0
            for i in pk.indices { pk[i] = Pink() }
            for i in br.indices { br[i] = 0 }
            for i in p.indices { p[i] = 0 }
            for i in env.indices { env[i] = 0 }
            for i in aux.indices { aux[i] = 0 }
            for i in sv.indices { sv[i] = SVF() }
            for i in v.indices { v[i] = Voice() }
            for i in d.indices { d[i] = Drift() }
            for i in bird.indices { bird[i] = Bird() }
            for i in ph.indices { ph[i] = 0 }
            for i in pf.indices { pf[i] = 0 }
        }

        /// One sample of the left channel (kept for older callers and tests).
        mutating func next(_ kind: Kind, sampleRate: Double) -> Float { frame(kind, sampleRate: sampleRate).0 }

        /// One stereo sample, levelled and softly limited (never past ±1).
        mutating func frame(_ kind: Kind, sampleRate fs: Double) -> (Float, Float) {
            if k.fs != fs { k = Consts(fs: fs) }
            var L = 0.0, R = 0.0
            let t = self.t
            self.t += 1 / fs
            switch kind {
            case .white:
                L = wn() * 0.35; R = wn() * 0.35
            case .pink:
                let a = wn(); L = pink(0, a) * 0.5
                let b = wn(); R = pink(1, b) * 0.5
            case .brown:
                let a = wn(); L = brown(0, a)
                let b = wn(); R = brown(1, b)
            case .fan:
                // brown noise with a gentle 3 Hz blade wobble, a soft low-pass and the motor's faint hum
                let w = 1 + 0.12 * sin(2 * .pi * 3.1 * t), hum = 0.025 * sin(2 * .pi * 100 * t)
                for c in 0..<2 {
                    let w0 = wn(); let n = brown(c, w0) * w
                    let x = Self.pole(&p[c], n, 0.08) * 1.6 + hum
                    if c == 0 { L = x } else { R = x }
                }
            case .rain:
                // a soft pink bed plus scattered drops: short band-passed ticks in either ear
                let swell = 0.85 + 0.3 * drift(0, 0.2, 0.3, fs)
                for c in 0..<2 {
                    let w0 = wn(); let bed = pink(c, w0) * 0.32 * swell
                    let hp = bed - Self.pole(&p[c], bed, k.c300)
                    let dr = drops(c, 140, 1000, 3600, k.d4, 0.9, fs)
                    let x = Self.pole(&p[2 + c], hp + dr, k.c7000)
                    if c == 0 { L = x } else { R = x }
                }
            case .roofRain:
                // heavy rain heard from inside: a muffled roar, patter on the roof, and a gutter drip now and then
                for c in 0..<2 {
                    let w0 = wn(), w1 = wn()
                    let n = brown(c, w0) * 0.9 + pink(c, w1) * 0.5
                    let bed = Self.pole(&p[c], n, k.c900)
                    let x = bed + drops(c, 260, 500, 2400, k.d7, 1.0, fs)
                    if c == 0 { L = x } else { R = x }
                }
                if t >= nextEv {
                    let r1 = rnd(), r2 = rnd(), r3 = rnd()
                    nextEv = t + 0.7 + 2.2 * r1
                    trigger(650 + 450 * r2, 0.16, 0.12, exp(log(1.7) / (0.04 * fs)), 0.2 + 0.6 * r3, fs)
                }
                voices(&L, &R, fs)
            case .thunder:
                // a downpour with thunder rolling in every 10–26 s: a crack, then a long low rumble across the sky
                for c in 0..<2 {
                    let w0 = wn(), w1 = wn()
                    let pn = pink(c, w0) * 0.4, bn = brown(c, w1)
                    let low = Self.pole(&p[2 + c], bn, k.c600) * 0.4
                    let x = pn + low + drops(c, 220, 1200, 4500, k.d5, 0.9, fs)
                    if c == 0 { L = x } else { R = x }
                }
                if nextEv == 0 { let r = rnd(); nextEv = 2.5 + 3 * r }
                if t >= nextEv {
                    let r1 = rnd(), r2 = rnd(), r3 = rnd(), r4 = rnd()
                    t0 = t; aux[4] = 4 + 5 * r1; aux[5] = 0.5 + 0.5 * r2; aux[6] = r3; nextEv = t + 10 + 16 * r4
                }
                let tt = t - t0
                if t0 > 0 && tt < aux[4] * 2.5 {
                    let roll = 0.55 + 0.45 * drift(1, 3, 4, fs)
                    let e = (1 - exp(-tt / 0.06)) * exp(-tt / (aux[4] * 0.4)) * roll * aux[5]
                    let crack = exp(-tt / 0.18) * aux[5]
                    for c in 0..<2 {
                        let w0 = wn(); let b = brown(2 + c, w0)
                        let r1 = Self.pole(&p[6 + c], b, k.c140)
                        let rum = Self.pole(&p[4 + c], r1, k.c140) * 2.2
                        let w1 = wn(); let cr = Self.band(&sv[2 + c], w1, 900, 1.2, fs) * crack * 0.5
                        let pan = c == 0 ? 1 - 0.5 * aux[6] : 0.5 + 0.5 * aux[6]
                        let x = (rum * e + cr) * pan
                        if c == 0 { L += x } else { R += x }
                    }
                }
            case .ocean:
                // one wave every 7–12 s: it gathers, brightens as it rises, crashes into foam, then draws back
                if t >= nextEv {
                    let r1 = rnd(), r2 = rnd()
                    t0 = t; aux[4] = 7 + 5 * r1; nextEv = t + aux[4]; aux[5] = 0.7 + 0.3 * r2
                }
                for c in 0..<2 {
                    var u = (t - t0) / aux[4] - Double(c) * 0.035
                    if u < 0 { u += 1 }
                    var e = u < 0.55 ? pow(u / 0.55, 2) : exp(-(u - 0.55) * 5.5)
                    e *= aux[5]
                    let w0 = wn(); let pn = pink(c, w0) * 1.6
                    let body = Self.pole(&p[c], pn, 0.015 + 0.22 * e) * (0.25 + 0.95 * e)
                    var foam = 0.0
                    if u > 0.55 { let a = wn(), b = wn(); foam = (a - Self.pole(&p[2 + c], b, 0.3)) * e * 0.08 }
                    let w2 = wn(); let bd = brown(c, w2)
                    let deep = Self.pole(&p[4 + c], bd, 0.05) * 0.35
                    let x = body + foam + deep
                    if c == 0 { L = x } else { R = x }
                }
            case .stream:
                // water over stones: three resonant bands that babble at their own pace, and little bubbles
                for c in 0..<2 {
                    let w0 = wn(); let pn = pink(c, w0)
                    var x = 0.0
                    for b in 0..<3 {
                        let m = drift(b, 14, 60, fs)
                        x += Self.band(&sv[c * 3 + b], pn, Self.streamBands[b] * (1 + 0.1 * Double(c)), 0.35, fs) * (0.15 + 0.85 * m * m) * 0.9
                    }
                    x += pn * 0.08
                    if c == 0 { L = x } else { R = x }
                }
                if rnd() < 7 / fs {
                    let r1 = rnd(), r2 = rnd(), r3 = rnd()
                    trigger(280 + 600 * r1, 0.07 + 0.08 * r2, 0.05, exp(log(2.2) / (0.05 * fs)), r3, fs)
                }
                voices(&L, &R, fs)
            case .wind:
                // gusts: a resonant band that rises and falls with the wind's strength
                let g = drift(0, 0.25, 0.35, fs)
                for c in 0..<2 {
                    let w0 = wn(), w1 = wn()
                    let n = brown(c, w0) * 0.6 + pink(c, w1) * 0.6
                    let bp = Self.band(&sv[c], n, (230 + 650 * g) * (1 + 0.07 * Double(c)), 0.28, fs)
                    let lo = Self.pole(&p[c], n, 0.01)
                    let x = bp * (0.25 + 1.1 * g) + lo * 0.6
                    if c == 0 { L = x } else { R = x }
                }
            case .forest:
                // leaves in a breeze and two birds singing their own songs, now here, now there
                let rustle = 0.4 + 0.6 * drift(0, 0.4, 0.5, fs)
                for c in 0..<2 {
                    let w0 = wn(); let pn = pink(c, w0)
                    let hp = pn - Self.pole(&p[c], pn, k.c1500)
                    let w1 = wn(); let bn = brown(c, w1)
                    let x = hp * 0.22 * rustle + Self.pole(&p[2 + c], bn, 0.02) * 0.25
                    if c == 0 { L = x } else { R = x }
                }
                for b in 0..<2 { sing(b, t, fs, &L, &R) }
            case .crickets:
                // a still night and three crickets chirping at their own speeds, left, right and centre
                for c in 0..<2 {
                    let w0 = wn(); let bn = brown(c, w0)
                    let x = Self.pole(&p[c], bn, 0.03) * 0.1
                    if c == 0 { L = x } else { R = x }
                }
                for i in 0..<3 {
                    let act = drift(i, 0.08, 0.6, fs)
                    if act < 0.25 { continue }
                    let ct = (t + Self.cricketOffset[i]).truncatingRemainder(dividingBy: Self.cricketEvery[i])
                    let pulse = Int(ct / 0.032), pt = ct.truncatingRemainder(dividingBy: 0.032)
                    if pulse < 3 && pt < 0.014 {
                        let x = sin(2 * .pi * Self.cricketHz[i] * t) * sin(.pi * pt / 0.014) * Self.cricketAmp[i] * min(1, (act - 0.25) * 3)
                        L += x * cos(Self.cricketPan[i] * .pi / 2); R += x * sin(Self.cricketPan[i] * .pi / 2)
                    }
                }
            case .campfire:
                // a low roar that flickers, crackles in bursts, the odd pop of a log
                let fl = drift(0, 2, 3, fs), burst = drift(1, 0.5, 1, fs)
                for c in 0..<2 {
                    let w0 = wn(); let bn = brown(c, w0)
                    let r1 = Self.pole(&p[c], bn, k.c260)
                    let roar = Self.pole(&p[2 + c], r1, k.c260) * (1.2 + 0.8 * fl)
                    let w1 = wn(), w2 = wn()
                    let hiss = (w1 - Self.pole(&p[4 + c], w2, 0.5)) * 0.012
                    if rnd() < (6 + 50 * burst * burst * burst) / fs { let r = rnd(), f = rnd(); env[c] = 0.9 * r * r * r; aux[c] = 1500 + 4500 * f }
                    env[c] *= k.d3
                    let w3 = wn(); let ex = w3 * env[c]
                    let crack = Self.band(&sv[c], ex, aux[c], 0.7, fs) * 1.4
                    let x = roar + hiss + crack
                    if c == 0 { L = x } else { R = x }
                }
                if rnd() < 0.35 / fs { let r1 = rnd(), r2 = rnd(); trigger(160 + 120 * r1, 0.25, 0.04, 0.9999, r2, fs) }
                voices(&L, &R, fs)
            case .cabin:
                // the steady, muffled roar of a plane at cruise, with the engines' low drone
                let wob = 1 + 0.06 * sin(2 * .pi * 0.07 * t)
                let tone = 0.02 * sin(2 * .pi * 78 * t) + 0.012 * sin(2 * .pi * 156.4 * t)
                for c in 0..<2 {
                    let w0 = wn(), w1 = wn()
                    let n = pink(c, w0) * 0.9 + brown(c, w1)
                    let x = Self.pole(&p[c], n, k.c700) * 1.3 * wob + tone
                    if c == 0 { L = x } else { R = x }
                }
            case .train:
                // a carriage rumbling and swaying, wheels clicking over the rail joints: ta-tak … ta-tak
                let sway = 0.8 + 0.2 * sin(2 * .pi * 0.31 * t)
                for c in 0..<2 {
                    let w0 = wn(); let bn = brown(c, w0)
                    let r1 = Self.pole(&p[c], bn, k.c300)
                    let x = Self.pole(&p[2 + c], r1, k.c300) * 1.8 * sway
                    if c == 0 { L = x } else { R = x }
                }
                if t >= nextEv {
                    let strength = idx % 2 == 1 ? 0.75 : 1.0
                    env[0] = 1.3 * strength; env[1] = 1.2 * strength
                    trigger(85, 0.4 * strength, 0.12, 0.99995, 0.5, fs)
                    let nx = (idx + 1) % 4
                    if nx == 0 { t0 += 1.72 }
                    let j = wn()
                    nextEv = t0 + Self.trainPattern[nx] + 0.008 * j; idx = nx
                }
                for c in 0..<2 {
                    env[c] *= k.d22
                    let w0 = wn(); let ex = w0 * env[c]
                    let x = Self.band(&sv[c], ex, 1700, 0.8, fs)
                    if c == 0 { L += x } else { R += x }
                }
                voices(&L, &R, fs)
            case .bowl:
                // a singing bowl struck every 8–14 s, its partials beating slowly as it rings out
                if t >= nextEv {
                    let r1 = rnd(), r2 = rnd(), r3 = rnd()
                    nextEv = t + 8 + 6 * r1
                    strike(Self.bowlNotes[min(3, Int(r2 * 4))], 0.22, Self.bowlRatio, Self.bowlGain, Self.bowlDecay, count: 4, pan: 0.35 + 0.3 * r3, detune: 0.7, fs)
                    env[0] = 0.12
                }
                env[0] *= k.d12
                let w0 = wn(); let mallet = Self.pole(&p[0], w0, 0.1) * env[0]
                let w1 = wn(); let pn = pink(0, w1)
                let air = Self.pole(&p[2], pn, 0.05) * 0.04
                L = mallet + air; R = mallet + air
                voices(&L, &R, fs)
            case .pad:
                // a slow, warm chord that drifts to the next one every 16 s, each note gently breathing
                if t >= nextEv { nextEv = t + 16; if t > 0 { idx = (idx + 1) % 4 } }
                if pf[0] == 0 { for i in 0..<4 { pf[i] = Self.padChords[i] } }
                for i in 0..<4 {
                    pf[i] += (Self.padChords[idx * 4 + i] - pf[i]) * (1 / (2.5 * fs))
                    let lfo = 0.6 + 0.4 * sin(2 * .pi * (0.05 + 0.013 * Double(i)) * t + Double(i) * 1.7)
                    ph[i] += pf[i] * 1.0015 / fs; ph[i] -= floor(ph[i])
                    ph[4 + i] += pf[i] * 0.9985 / fs; ph[4 + i] -= floor(ph[4 + i])
                    let a = sin(2 * .pi * ph[i]) + 0.15 * sin(4 * .pi * ph[i])
                    let b = sin(2 * .pi * ph[4 + i]) + 0.15 * sin(4 * .pi * ph[4 + i])
                    let amp = 0.07 * lfo * (i == 0 ? 1.2 : 1)
                    L += (a * 0.7 + b * 0.3) * amp; R += (a * 0.3 + b * 0.7) * amp
                }
                let w0 = wn(), w1 = wn()
                let p0 = pink(0, w0), p1 = pink(1, w1)
                L += Self.pole(&p[0], p0, 0.03) * 0.03; R += Self.pole(&p[1], p1, 0.03) * 0.03
            case .chimes:
                // a breeze, and chimes that ring more often as it gusts
                let gst = drift(0, 0.3, 0.4, fs)
                for c in 0..<2 {
                    let w0 = wn(), w1 = wn()
                    let n = brown(c, w0) * 0.6 + pink(c, w1) * 0.5
                    let bp = Self.band(&sv[c], n, (260 + 500 * gst) * (1 + 0.07 * Double(c)), 0.3, fs)
                    let lo = Self.pole(&p[c], n, 0.01)
                    let x = bp * (0.15 + 0.6 * gst) + lo * 0.3
                    if c == 0 { L = x } else { R = x }
                }
                let r0 = rnd()
                if step == 0 || r0 < (0.25 + 3.0 * gst * gst) / fs {
                    step = 1
                    let r1 = rnd(), r2 = rnd(), r3 = rnd()
                    strike(Self.chimeNotes[min(5, Int(r1 * 6))], 0.06 + 0.07 * r2, Self.chimeRatio, Self.chimeGain, Self.chimeDecay, count: 3, pan: r3, detune: 0, fs)
                }
                voices(&L, &R, fs)
            case .musicBox:
                // a gentle tune that wanders over a five-note scale, never quite repeating, with a soft bass every bar
                if t >= nextEv {
                    let n = step; step += 1
                    nextEv = t + (n % 8 == 7 ? 0.84 : 0.42)
                    if n == 0 { idx = 4 }
                    let r0 = rnd()
                    if r0 > 0.12 || n == 0 {
                        if n > 0 { let r = rnd(); idx += Self.melodySteps[min(3, Int(r * 4))] }
                        if idx < 0 { idx = 1 }
                        if idx > 9 { idx = 8 }
                        let r2 = rnd()
                        strike(523.25 * pow(2, Double(Self.pentatonic[idx]) / 12), 0.11, Self.boxRatio, Self.boxGain, Self.boxDecay, count: 4, pan: 0.3 + 0.4 * r2, detune: 0, fs)
                    }
                    if n % 4 == 0 {
                        strike(261.63 * pow(2, Double(n % 8 == 0 ? 0 : 7) / 12), 0.07, Self.boxRatio, Self.boxGain, Self.boxDecay, count: 3, pan: 0.5, detune: 0, fs)
                    }
                }
                voices(&L, &R, fs)
            case .heartbeat, .womb:
                // a resting heart, lub-dub at 60 a minute; the womb is the whoosh of blood around it, muffled
                let period = kind == .heartbeat ? 1.0 : 0.86
                let tb = t.truncatingRemainder(dividingBy: period)
                var f = 0.0, e = 0.0, heart = 0.0
                if tb < 0.12 { let s = sin(.pi * tb / 0.12); e = s * s; f = 58 - 120 * tb }
                else if tb >= 0.27 && tb < 0.37 { let u = (tb - 0.27) / 0.1; let s = sin(.pi * u); e = 0.7 * s * s; f = 72 - 160 * (tb - 0.27) }
                if f > 0 { ph[0] += f / fs; ph[0] -= floor(ph[0]); heart = sin(2 * .pi * ph[0]) * e } else { ph[0] = 0 }
                let pulse = exp(-tb / 0.28)
                for c in 0..<2 {
                    let w0 = wn(); let bn = brown(c, w0)
                    let r1 = Self.pole(&p[c], bn, k.c300)
                    let wh = Self.pole(&p[2 + c], r1, k.c300)
                    let x = kind == .heartbeat ? heart * 0.55 + wh * 0.5 : wh * (1.2 + 1.6 * pulse) + heart * 0.18
                    if c == 0 { L = x } else { R = x }
                }
            }
            let g = kind.gain
            return (Float(tanh(L * g)), Float(tanh(R * g)))
        }

        // MARK: building blocks

        /// xorshift64*: fast, and plenty random for sound.
        private mutating func rnd() -> Double {
            var x = rng
            x ^= x >> 12; x ^= x << 25; x ^= x >> 27
            rng = x
            return Double((x &* 2685821657736338717) >> 11) * (1.0 / 9007199254740992.0)
        }
        private mutating func wn() -> Double { rnd() * 2 - 1 }
        /// Pink noise: Paul Kellet's 3-pole approximation.
        private mutating func pink(_ c: Int, _ w: Double) -> Double {
            pk[c].b0 = 0.99765 * pk[c].b0 + w * 0.0990460
            pk[c].b1 = 0.96300 * pk[c].b1 + w * 0.2965164
            pk[c].b2 = 0.57000 * pk[c].b2 + w * 1.0526913
            return (pk[c].b0 + pk[c].b1 + pk[c].b2 + w * 0.1848) * 0.18
        }
        /// Brown noise: a leaky integrator.
        private mutating func brown(_ i: Int, _ w: Double) -> Double {
            br[i] = (br[i] + 0.02 * w) / 1.02
            return br[i] * 2.2
        }
        /// A slow random wander between 0 and 1 (gusts, flicker, a cricket stopping and starting).
        private mutating func drift(_ i: Int, _ perSec: Double, _ speed: Double, _ fs: Double) -> Double {
            let r = rnd()
            if r < perSec / fs { let n = rnd(); d[i].target = n }
            d[i].v += (d[i].target - d[i].v) * speed / fs
            return d[i].v
        }
        private static func pole(_ y: inout Double, _ x: Double, _ a: Double) -> Double { y += a * (x - y); return y }
        /// Chamberlin state-variable band-pass (`q` is damping: smaller rings more).
        private static func band(_ f: inout SVF, _ x: Double, _ hz: Double, _ q: Double, _ fs: Double) -> Double {
            let g = 2 * sin(Double.pi * min(hz, fs / 7) / fs)
            f.low += g * f.band
            let hi = x - f.low - q * f.band
            f.band += g * hi
            return f.band
        }
        /// Rain drops: short band-passed noise ticks, each in one ear.
        private mutating func drops(_ c: Int, _ perSec: Double, _ lo: Double, _ hi: Double, _ decay: Double, _ amp: Double, _ fs: Double) -> Double {
            if rnd() < perSec / fs { let r = rnd(), f = rnd(); env[c] = amp * r * r; aux[c] = lo + (hi - lo) * f }
            env[c] *= decay
            let w = wn(); let x = w * env[c]
            return Self.band(&sv[c], x, aux[c], 0.9, fs)
        }
        /// Start a ringing tone on the quietest voice in the pool.
        private mutating func trigger(_ f: Double, _ a: Double, _ decaySeconds: Double, _ glide: Double, _ pan: Double, _ fs: Double) {
            var best = 0
            for i in 1..<v.count where v[i].a < v[best].a { best = i }
            v[best] = Voice(f: f, ph: 0, a: a, dec: exp(log(0.001) / (decaySeconds * fs)), glide: glide, pan: pan)
        }
        /// A struck bowl, chime or tine: inharmonic partials, each its own voice (a twin a touch sharp makes it sing).
        private mutating func strike(_ f: Double, _ amp: Double, _ ratio: [Double], _ gain: [Double], _ decay: [Double], count: Int, pan: Double, detune: Double, _ fs: Double) {
            for i in 0..<min(count, ratio.count) {
                trigger(f * ratio[i], amp * gain[i], decay[i], 1, pan, fs)
                if detune > 0 { trigger(f * ratio[i] + detune * Double(i + 1), amp * gain[i] * 0.8, decay[i] * 0.9, 1, min(1, pan + 0.15), fs) }
            }
        }
        private mutating func voices(_ L: inout Double, _ R: inout Double, _ fs: Double) {
            for i in 0..<v.count where v[i].a >= 1e-5 {
                let x = sin(2 * .pi * v[i].ph) * v[i].a
                L += x * cos(v[i].pan * .pi / 2); R += x * sin(v[i].pan * .pi / 2)
                v[i].ph += v[i].f / fs; v[i].ph -= floor(v[i].ph)
                v[i].a *= v[i].dec; v[i].f *= v[i].glide
                if v[i].f > fs / 3 { v[i].a = 0 }
            }
        }
        /// One bird: a phrase of a few notes, then a pause. Species 0 whistles down, 1 trills, 2 calls two notes.
        private mutating func sing(_ b: Int, _ t: Double, _ fs: Double, _ L: inout Double, _ R: inout Double) {
            var bd = bird[b]
            if bd.notes == 0 && t >= bd.next {
                let r0 = rnd(), r1 = rnd(), r2 = rnd(), r3 = rnd()
                bd.species = (b + Int(r0 * 1.6)) % 3
                bd.notes = bd.species == 1 ? 5 + Int(4 * r1) : 2 + Int(2 * r1)
                bd.start = t; bd.pan = 0.15 + 0.7 * r2; bd.amp = 0.05 + 0.06 * r3; bd.dur = 0
            }
            if bd.notes > 0 {
                if bd.dur == 0 {
                    let r = rnd()
                    switch bd.species {
                    case 0: bd.dur = 0.22 + 0.15 * r; bd.f0 = 3000 + 600 * rnd(); bd.f1 = bd.f0 * 0.72
                    case 1: bd.dur = 0.06 + 0.04 * r; bd.f0 = 3600 + 1400 * rnd(); bd.f1 = bd.f0 * 1.3
                    default: bd.dur = 0.16; bd.f0 = bd.notes % 2 == 1 ? 2300 : 2850; bd.f1 = bd.f0 * 1.04
                    }
                }
                let u = (t - bd.start) / bd.dur
                if u >= 0 && u < 1 {
                    var f = bd.f0 + (bd.f1 - bd.f0) * u
                    if bd.species == 1 { f *= 1 + 0.03 * sin(2 * .pi * 28 * (t - bd.start)) }
                    bd.ph += f / fs; bd.ph -= floor(bd.ph)
                    let x = sin(2 * .pi * bd.ph) * sin(.pi * u) * bd.amp
                    L += x * cos(bd.pan * .pi / 2); R += x * sin(bd.pan * .pi / 2)
                } else if u >= 1 {
                    let gap = bd.species == 1 ? 0.035 : 0.12
                    if u >= 1 + gap / bd.dur {
                        bd.notes -= 1; bd.start = t; bd.dur = 0
                        if bd.notes == 0 { bd.next = t + 1.2 + 4 * rnd() }
                    }
                }
            }
            bird[b] = bd
        }
    }

    /// Render `n` samples of the left channel (for tests / previews).
    static func render(_ kind: Kind, samples n: Int, sampleRate: Double = 44100, seed: UInt64? = nil) -> [Float] {
        var s = State(seed: seed); return (0..<n).map { _ in s.next(kind, sampleRate: sampleRate) }
    }
    /// Render both channels (for tests).
    static func renderStereo(_ kind: Kind, samples n: Int, sampleRate: Double = 44100, seed: UInt64? = nil) -> (left: [Float], right: [Float]) {
        var s = State(seed: seed)
        var l = [Float](), r = [Float](); l.reserveCapacity(n); r.reserveCapacity(n)
        for _ in 0..<n { let f = s.frame(kind, sampleRate: sampleRate); l.append(f.0); r.append(f.1) }
        return (l, r)
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
