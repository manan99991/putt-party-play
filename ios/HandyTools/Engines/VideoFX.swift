import AVFoundation
import CoreImage
import UIKit

/// Video effects — "Make it stunning". Any video gets a look (colour grade), light (glow, light leaks, golden sun, a
/// sweeping flare, neon edges, vignette), motion (slow push-in, punches on the beat of its own sound, handheld shake,
/// drift), texture (film grain, VHS, cinema bars), sparkle (confetti, hearts, stars… or any festival from Celebrate)
/// and animated words — all scaled by one "How much" from barely-there to wild. Vibes set a whole recipe in one tap.
///
/// Every frame is a pure function of its time, so the live preview and the saved file match exactly, scrubbing
/// works, and nothing is downloaded. The sound is kept.
enum VideoFX {
    struct Choice: Identifiable, Equatable {
        let id: String, name: String, emoji: String
    }

    struct Recipe: Equatable {
        var look = "none"
        var light = "none"
        var motion = "none"
        var texture = "none"
        /// A sparkle id, or "fest:<Celebrate theme id>" for a festival's decorations.
        var sparkle = "none"
        /// How the words arrive: fade, pop, slide or bounce.
        var words = "pop"
        /// 0 = the video as filmed … 1 = all the way.
        var amount = 0.6

        var isPlain: Bool { look == "none" && light == "none" && motion == "none" && texture == "none" && sparkle == "none" }
    }

    static let looks: [Choice] = [
        Choice(id: "none", name: "Original", emoji: "⚪️"), Choice(id: "vivid", name: "Vivid", emoji: "🌈"),
        Choice(id: "cinema", name: "Cinematic", emoji: "🎬"), Choice(id: "golden", name: "Golden", emoji: "🌅"),
        Choice(id: "dream", name: "Dreamy", emoji: "☁️"), Choice(id: "retro", name: "Retro film", emoji: "📼"),
        Choice(id: "noir", name: "Black & white", emoji: "🖤"), Choice(id: "moon", name: "Moonlight", emoji: "🌙"),
        Choice(id: "neon", name: "Neon", emoji: "💜"), Choice(id: "sepia", name: "Vintage", emoji: "🟤"),
    ]
    static let lights: [Choice] = [
        Choice(id: "none", name: "None", emoji: "⚪️"), Choice(id: "glow", name: "Glow", emoji: "✨"),
        Choice(id: "leak", name: "Light leaks", emoji: "🔥"), Choice(id: "sun", name: "Golden sun", emoji: "☀️"),
        Choice(id: "flare", name: "Flare sweep", emoji: "💫"), Choice(id: "edges", name: "Neon edges", emoji: "⚡️"),
        Choice(id: "vignette", name: "Vignette", emoji: "🔦"),
    ]
    static let motions: [Choice] = [
        Choice(id: "none", name: "Still", emoji: "⚪️"), Choice(id: "zoom", name: "Slow zoom", emoji: "🔍"),
        Choice(id: "pulse", name: "Beat punch", emoji: "🥁"), Choice(id: "shake", name: "Handheld", emoji: "📳"),
        Choice(id: "drift", name: "Drift", emoji: "🎞️"),
    ]
    static let textures: [Choice] = [
        Choice(id: "none", name: "Clean", emoji: "⚪️"), Choice(id: "grain", name: "Film grain", emoji: "🎞️"),
        Choice(id: "vhs", name: "VHS", emoji: "📼"), Choice(id: "bars", name: "Cinema bars", emoji: "🎬"),
    ]
    static let sparkles: [Choice] = [
        Choice(id: "none", name: "None", emoji: "⚪️"), Choice(id: "sparkles", name: "Sparkles", emoji: "✨"),
        Choice(id: "confetti", name: "Confetti", emoji: "🎊"), Choice(id: "hearts", name: "Hearts", emoji: "💖"),
        Choice(id: "stars", name: "Starry", emoji: "⭐️"), Choice(id: "snow", name: "Snow", emoji: "❄️"),
        Choice(id: "bubbles", name: "Bubbles", emoji: "🫧"), Choice(id: "fireworks", name: "Fireworks", emoji: "🎆"),
        Choice(id: "petals", name: "Petals", emoji: "🌸"),
    ]
    static let wordStyles: [Choice] = [
        Choice(id: "pop", name: "Pop", emoji: "💥"), Choice(id: "slide", name: "Slide up", emoji: "⬆️"),
        Choice(id: "fade", name: "Fade", emoji: "🌫️"), Choice(id: "bounce", name: "Bounce", emoji: "🏀"),
    ]

    /// A whole recipe in one tap.
    struct Vibe: Identifiable, Equatable {
        let id: String, name: String, emoji: String, recipe: Recipe
    }
    static let vibes: [Vibe] = [
        Vibe(id: "cinematic", name: "Cinematic", emoji: "🎬", recipe: Recipe(look: "cinema", light: "vignette", motion: "zoom", texture: "bars")),
        Vibe(id: "golden", name: "Golden hour", emoji: "🌅", recipe: Recipe(look: "golden", light: "leak", motion: "drift", texture: "grain")),
        Vibe(id: "party", name: "Party", emoji: "🪩", recipe: Recipe(look: "neon", light: "flare", motion: "pulse", sparkle: "confetti")),
        Vibe(id: "dreamy", name: "Dreamy", emoji: "☁️", recipe: Recipe(look: "dream", light: "glow", motion: "zoom", sparkle: "sparkles")),
        Vibe(id: "love", name: "Love", emoji: "💖", recipe: Recipe(look: "dream", light: "leak", motion: "drift", sparkle: "hearts")),
        Vibe(id: "retro", name: "Retro VHS", emoji: "📼", recipe: Recipe(look: "retro", motion: "shake", texture: "vhs")),
        Vibe(id: "noir", name: "Noir", emoji: "🖤", recipe: Recipe(look: "noir", light: "vignette", motion: "zoom", texture: "grain")),
        Vibe(id: "epic", name: "Epic", emoji: "⚡️", recipe: Recipe(look: "vivid", light: "flare", motion: "pulse", texture: "bars")),
        Vibe(id: "night", name: "Night sky", emoji: "🌙", recipe: Recipe(look: "moon", light: "glow", motion: "drift", sparkle: "stars")),
        Vibe(id: "original", name: "Original", emoji: "⚪️", recipe: Recipe()),
    ]

    /// The vibe a recipe matches (looks, light, motion, texture and sparkle the same), if any.
    static func vibe(of r: Recipe) -> Vibe? {
        vibes.first { v in v.recipe.look == r.look && v.recipe.light == r.light && v.recipe.motion == r.motion && v.recipe.texture == r.texture && v.recipe.sparkle == r.sparkle }
    }

    // MARK: - Looks: a colour cube per look, mixed with the original by how much

    typealias RGB = (r: Double, g: Double, b: Double)

    static func luma(_ c: RGB) -> Double { 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
    private static func sat(_ c: RGB, _ s: Double) -> RGB { let l = luma(c); return (l + (c.r - l) * s, l + (c.g - l) * s, l + (c.b - l) * s) }
    private static func curve(_ x: Double, _ k: Double) -> Double { x + k * x * (1 - x) * (2 * x - 1) }
    private static func curve(_ c: RGB, _ k: Double) -> RGB { (curve(c.r, k), curve(c.g, k), curve(c.b, k)) }
    private static func add(_ c: RGB, _ d: RGB, _ w: Double) -> RGB { (c.r + d.r * w, c.g + d.g * w, c.b + d.b * w) }

    /// One colour through a look, all the way. Pure, so it's unit-tested.
    static func grade(_ look: String, _ c: RGB) -> RGB {
        let l = luma(c)
        switch look {
        case "vivid": return curve(sat((c.r + 0.01, c.g, c.b), 1.45), 0.35)
        case "cinema":
            var o = add(c, (-0.07, 0.02, 0.08), (1 - l) * (1 - l))
            o = add(o, (0.09, 0.025, -0.08), l * l)
            return sat(curve(o, 0.45), 1.05)
        case "golden": return sat(curve((c.r * 1.06 + 0.05, c.g * 1.0 + 0.025, c.b * 0.8), 0.15), 1.12)
        case "dream":
            let o = sat((c.r * 0.84 + 0.13, c.g * 0.84 + 0.12, c.b * 0.84 + 0.13), 0.82)
            return add(o, (0.05, 0.0, 0.035), l)
        case "retro":
            var o = sat((c.r * 0.8 + 0.1, c.g * 0.8 + 0.09, c.b * 0.8 + 0.08), 0.75)
            o = add(o, (0.0, 0.035, 0.03), 1 - l)
            return add(o, (0.06, 0.02, -0.02), l)
        case "noir":
            let k = curve(l, 0.85)
            return (k * 0.98, k * 0.99, k * 1.03)
        case "moon": return curve(sat((c.r * 0.86, c.g * 0.95 + 0.01, c.b * 1.08 + 0.05), 0.8), 0.2)
        case "neon":
            var o = sat(c, 1.75)
            o = add(o, (0.1, -0.02, 0.13), 1 - l)
            o = add(o, (-0.03, 0.07, 0.1), l)
            return curve(o, 0.3)
        case "sepia":
            let s = (l * 1.07 + 0.05, l * 0.95 + 0.03, l * 0.76)
            return (s.0 * 0.85 + c.r * 0.15, s.1 * 0.85 + c.g * 0.15, s.2 * 0.85 + c.b * 0.15)
        // Celebration grades — each tells its festival's story.
        case "diwali":   // lamplight: rich gold, warm shadows, colours that glow
            var o = add((c.r * 1.08 + 0.03, c.g * 1.0 + 0.015, c.b * 0.8), (0.05, 0.02, -0.01), (1 - l) * (1 - l))
            o = sat(curve(o, 0.32), 1.22)
            return o
        case "xmas":     // a warm room on a winter night: deep reds and greens, glowing highlights, cool shadows
            var o = add(c, (-0.02, 0.01, 0.05), (1 - l) * (1 - l))
            o = add(o, (0.08, 0.04, -0.03), l * l)
            return sat(curve(o, 0.35), 1.22)
        case "harvest":  // golden hour in the fall: amber light, soft warm blacks
            var o = (c.r * 1.05 + 0.05, c.g * 0.98 + 0.03, c.b * 0.78 + 0.01)
            o = add(o, (0.03, 0.015, 0.0), 1 - l)
            return sat(curve(o, 0.25), 1.1)
        case "spooky":   // teal shadows, orange highlights, a darker night
            var o = (c.r * 0.92, c.g * 0.92, c.b * 0.95)
            o = add(o, (-0.06, 0.03, 0.08), (1 - l) * (1 - l))
            o = add(o, (0.11, 0.03, -0.08), l * l)
            return sat(curve(o, 0.5), 0.92)
        case "frost":    // silver and blue: a clean, glittering winter
            let o = (c.r * 0.93 + 0.01, c.g * 0.98 + 0.02, c.b * 1.07 + 0.05)
            return sat(curve(o, 0.25), 0.92)
        case "festive":  // a party: vivid, warm, punchy
            let o = add(sat(c, 1.35), (0.03, 0.01, -0.02), 1)
            return curve(o, 0.35)
        case "romance":  // soft pink light, gentle contrast
            let o = sat((c.r * 0.9 + 0.08, c.g * 0.88 + 0.06, c.b * 0.9 + 0.07), 0.95)
            return add(o, (0.06, 0.0, 0.03), l)
        case "spring":   // fresh and bright, petal pinks and new greens
            let o = sat((c.r * 0.96 + 0.04, c.g * 0.97 + 0.035, c.b * 0.95 + 0.04), 1.15)
            return curve(o, 0.15)
        case "lunar":    // red and gold, lantern-lit
            var o = add(c, (0.09, 0.03, -0.05), l * l)
            o = add(o, (0.04, -0.01, -0.02), (1 - l) * (1 - l))
            return sat(curve(o, 0.35), 1.25)
        default: return c
        }
    }

    /// A colour cube (float RGBA, red fastest) for `look` mixed with the original by `amount`.
    static func cube(_ look: String, amount: Double, size n: Int = 24) -> Data {
        var v = [Float](); v.reserveCapacity(n * n * n * 4)
        let a = min(1, max(0, amount))
        for bi in 0..<n {
            for gi in 0..<n {
                for ri in 0..<n {
                    let c: RGB = (Double(ri) / Double(n - 1), Double(gi) / Double(n - 1), Double(bi) / Double(n - 1))
                    let o = grade(look, c)
                    func mix(_ x: Double, _ y: Double) -> Float { Float(min(1, max(0, x + (y - x) * a))) }
                    v.append(mix(c.r, o.r)); v.append(mix(c.g, o.g)); v.append(mix(c.b, o.b)); v.append(1)
                }
            }
        }
        return v.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    // MARK: - Motion

    /// A smooth wobble in −1…1 (several slow waves), the same every time for the same x.
    static func wobble(_ x: Double) -> Double { (sin(x) + 0.6 * sin(2.17 * x + 1.3) + 0.3 * sin(3.91 * x + 2.1)) / 1.9 }

    /// How hard the beat is hitting at `t`: 1 right on a beat, falling away over about a tenth of a second.
    static func punch(_ t: Double, beats: [Double]) -> Double {
        var e = 0.0
        for b in beats where b <= t && t - b < 0.6 { e = max(e, exp(-(t - b) / 0.11)) }
        return e
    }

    /// How a `size` frame moves at `t` of `duration`: scaled about the middle and nudged, never showing an edge.
    static func motion(_ id: String, t: Double, duration: Double, size: CGSize, amount a: Double, beats: [Double]) -> CGAffineTransform {
        let W = Double(size.width), H = Double(size.height)
        let p = duration > 0 ? min(1, max(0, t / duration)) : 0
        var s = 1.0, dx = 0.0, dy = 0.0, rot = 0.0
        switch id {
        case "zoom": s = 1 + 0.16 * a * (p * p * (3 - 2 * p))
        case "pulse": s = 1 + 0.11 * a * punch(t, beats: beats)
        case "shake":
            s = 1 + 0.045 * a
            dx = wobble(t * 7.3) * W * 0.014 * a; dy = wobble(t * 6.1 + 5) * H * 0.012 * a; rot = wobble(t * 4.7 + 9) * 0.008 * a
        case "drift":
            s = 1.06 + 0.08 * a
            dx = (p * 2 - 1) * (s - 1) * W / 2 * 0.9
        default: break
        }
        // Keep every corner covered: the slack the zoom leaves bounds the nudge (rotation needs a little more zoom).
        s += abs(rot) * 1.2
        let slackX = (s - 1) * W / 2, slackY = (s - 1) * H / 2
        dx = min(slackX, max(-slackX, dx)); dy = min(slackY, max(-slackY, dy))
        return CGAffineTransform(translationX: -W / 2, y: -H / 2)
            .concatenating(CGAffineTransform(scaleX: s, y: s))
            .concatenating(CGAffineTransform(rotationAngle: rot))
            .concatenating(CGAffineTransform(translationX: W / 2 + dx, y: H / 2 + dy))
    }

    // MARK: - The beat of the video's own sound

    /// Beat times from loudness every `hop` seconds: where it jumps up clearly, at least 0.22 s apart. Pure.
    static func beats(loudness e: [Double], hop: Double) -> [Double] {
        guard e.count > 4 else { return [] }
        let flux = (0..<e.count).map { i in i == 0 ? 0 : max(0, e[i] - e[i - 1]) }
        let mean = flux.reduce(0, +) / Double(flux.count)
        let sd = sqrt(flux.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(flux.count))
        let bar = mean + 1.2 * sd
        guard sd > 1e-6 else { return [] }
        var out: [Double] = [], last = -1.0
        for i in 1..<(flux.count - 1) where flux[i] > bar && flux[i] >= flux[i - 1] && flux[i] >= flux[i + 1] {
            let t = Double(i) * hop
            if t - last >= 0.22 { out.append(t); last = t }
        }
        return out
    }

    /// A steady beat (twice a second) for videos with no sound or nothing to dance to.
    static func steady(_ duration: Double) -> [Double] { stride(from: 0.25, to: max(0.25, duration), by: 0.5).map { $0 } }

    /// The beats of the video's own sound (first five minutes), or a steady beat when there's nothing clear.
    static func beats(_ url: URL) async -> [Double] {
        let asset = AVURLAsset(url: url)
        let dur = (try? await asset.load(.duration).seconds) ?? 0
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first, let reader = try? AVAssetReader(asset: asset) else { return steady(dur) }
        let rate = 8000.0, hop = 0.05
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false, AVNumberOfChannelsKey: 1, AVSampleRateKey: rate,
        ])
        reader.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: min(dur, 300), preferredTimescale: 600))
        guard reader.canAdd(out) else { return steady(dur) }
        reader.add(out)
        guard reader.startReading() else { return steady(dur) }
        let per = Int(rate * hop)
        var loud: [Double] = [], acc = 0.0, n = 0
        while let buf = out.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(buf) {
            var len = 0; var ptr: UnsafeMutablePointer<Int8>?
            guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &len, dataPointerOut: &ptr) == noErr, let ptr else { continue }
            ptr.withMemoryRebound(to: Int16.self, capacity: len / 2) { s in
                for i in 0..<(len / 2) {
                    let x = Double(s[i]) / 32768; acc += x * x; n += 1
                    if n == per { loud.append(sqrt(acc / Double(n))); acc = 0; n = 0 }
                }
            }
        }
        let found = beats(loudness: loud, hop: hop)
        return found.count >= max(2, Int(dur / 4)) ? found : steady(dur)
    }

    // MARK: - One frame

    /// What the composition keeps between frames: the colour cube, the sparkle painter, the words.
    final class Kit: @unchecked Sendable {
        let recipe: Recipe
        let cube: CIFilter?
        var painter: Celebrate.Painter?
        var words: (image: CIImage, size: CGSize)?
        let lock = NSLock()
        init(_ r: Recipe) {
            recipe = r
            cube = r.look == "none" ? nil : CIFilter(name: "CIColorCubeWithColorSpace", parameters: [
                "inputCubeDimension": 24, "inputCubeData": VideoFX.cube(r.look, amount: min(1, 0.25 + r.amount), size: 24),
                "inputColorSpace": CGColorSpace(name: CGColorSpace.sRGB) as Any,
            ])
        }
    }

    /// The decorations a sparkle choice draws (a festival's, for "fest:<id>").
    static func sparkleTheme(_ id: String) -> Celebrate.Theme? {
        if id.hasPrefix("fest:") { return Celebrate.theme(String(id.dropFirst(5))) }
        let layers: [Celebrate.Layer]
        switch id {
        case "sparkles": layers = [.sparkles([0xFFFFFF, 0xFFE082, 0xFFD54A])]
        case "confetti": layers = [.confetti(Celebrate.rainbow)]
        case "hearts": layers = [.rise(["💖", "❤️", "💕"]), .sparkles([0xF8BBD0, 0xFFFFFF])]
        case "stars": layers = [.stars, .sparkles([0xFFFFFF, 0xB3E5FC])]
        case "snow": layers = [.snow]
        case "bubbles": layers = [.bubbles]
        case "fireworks": layers = [.fireworks(Celebrate.rainbow)]
        case "petals": layers = [.fall(["🌸", "🌺", "🌸"])]
        default: return nil
        }
        return Celebrate.Theme(id: "fx-" + id, name: id, emoji: "", greeting: "", months: [], keywords: [], palette: [], layers: layers)
    }

    private static func gradient(_ center: CGPoint, _ radius: CGFloat, _ c: (Double, Double, Double), _ k: Double) -> CIImage? {
        CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: center.x, y: center.y), "inputRadius0": 0, "inputRadius1": radius,
            "inputColor0": CIColor(red: c.0 * k, green: c.1 * k, blue: c.2 * k), "inputColor1": CIColor(red: 0, green: 0, blue: 0),
        ])?.outputImage
    }
    private static func screen(_ top: CIImage?, over img: CIImage) -> CIImage {
        guard let top else { return img }
        return top.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: img])
    }

    /// One frame with the whole recipe on it. `src` is upright with its corner at zero and `size` big.
    static func frame(_ src: CIImage, t: Double, duration: Double, size: CGSize, kit: Kit, beats: [Double], caption: Celebrate.Caption?) -> CIImage {
        let r = kit.recipe, a = min(1, max(0, r.amount))
        let rect = CGRect(origin: .zero, size: size)
        let W = size.width, H = size.height, short = min(W, H), long = max(W, H)
        // Motion first (on the clean picture), clamped so the edges never show.
        var img = src.clampedToExtent().transformed(by: motion(r.motion, t: t, duration: duration, size: size, amount: a, beats: beats)).cropped(to: rect)
        // Look.
        if let f = kit.cube { f.setValue(img, forKey: kCIInputImageKey); img = f.outputImage?.cropped(to: rect) ?? img }
        // Light.
        switch r.light {
        case "glow":
            img = img.applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: short * 0.03, kCIInputIntensityKey: 0.25 + 0.85 * a]).cropped(to: rect)
        case "leak":
            let c1 = CGPoint(x: W * (0.15 + 0.7 * (0.5 + 0.5 * sin(t * 0.55))), y: H * (0.82 + 0.1 * sin(t * 0.8)))
            let c2 = CGPoint(x: W * (0.85 - 0.6 * (0.5 + 0.5 * sin(t * 0.43 + 1.7))), y: H * 0.12)
            img = screen(gradient(c1, long * 0.62, (1, 0.5, 0.18), 0.85 * a)?.cropped(to: rect), over: img)
            img = screen(gradient(c2, long * 0.5, (1, 0.25, 0.45), 0.6 * a)?.cropped(to: rect), over: img)
        case "sun":
            let breathe = 1 + 0.06 * sin(t * 1.3)
            img = screen(gradient(CGPoint(x: W * 0.1, y: H * 0.92), long * 0.75 * breathe, (1, 0.72, 0.3), 0.9 * a)?.cropped(to: rect), over: img)
        case "flare":
            let x = ((t * 0.42).truncatingRemainder(dividingBy: 1.5) - 0.25) * W
            let cy = H * 0.55
            let streak = gradient(CGPoint(x: x, y: cy), H * 0.95, (1, 0.93, 0.8), 0.95 * a)?
                .transformed(by: CGAffineTransform(translationX: -x, y: -cy).concatenating(CGAffineTransform(scaleX: 0.14, y: 1)).concatenating(CGAffineTransform(translationX: x, y: cy)))
            img = screen(streak?.cropped(to: rect), over: img)
            img = screen(gradient(CGPoint(x: x, y: cy), short * 0.18, (1, 0.95, 0.85), 0.7 * a)?.cropped(to: rect), over: img)
        case "edges":
            let hue = 0.5 + 0.5 * sin(t * 1.6)
            let col = (0.95 * (1 - hue) + 0.1 * hue, 0.15 * (1 - hue) + 0.95 * hue, 1.0)
            let e = img.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 5])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: col.0 * 1.6 * a, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: col.1 * 1.6 * a, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: col.2 * 1.6 * a, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                ])
                .applyingGaussianBlur(sigma: Double(short) * 0.004).cropped(to: rect)
            img = e.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: img]).cropped(to: rect)
        case "vignette":
            img = img.applyingFilter("CIVignetteEffect", parameters: [
                kCIInputCenterKey: CIVector(x: W / 2, y: H / 2), kCIInputRadiusKey: long * 0.62, kCIInputIntensityKey: 0.35 + 0.75 * a, "inputFalloff": 0.6,
            ]).cropped(to: rect)
        default: break
        }
        // Texture.
        switch r.texture {
        case "grain", "vhs":
            if let noise = CIFilter(name: "CIRandomGenerator")?.outputImage {
                let n = Int(t * 30)
                let mono = noise.transformed(by: CGAffineTransform(translationX: CGFloat((n * 137) % 997), y: CGFloat((n * 271) % 991)))
                    .applyingFilter("CIColorMatrix", parameters: [
                        "inputRVector": CIVector(x: 0, y: 1, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                        "inputBVector": CIVector(x: 0, y: 1, z: 0, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    ]).cropped(to: rect)
                let grained = mono.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: img]).cropped(to: rect)
                img = img.applyingFilter("CIDissolveTransition", parameters: [kCIInputTargetImageKey: grained, kCIInputTimeKey: (r.texture == "vhs" ? 0.3 : 0.2) + 0.5 * a]).cropped(to: rect)
            }
            if r.texture == "vhs" {
                let dx = Double(W) * (0.002 + 0.005 * a) * (1 + 0.5 * wobble(t * 9))
                func only(_ v: (Double, Double, Double), alpha: Double) -> CIImage {
                    img.applyingFilter("CIColorMatrix", parameters: [
                        "inputRVector": CIVector(x: v.0, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: v.1, z: 0, w: 0),
                        "inputBVector": CIVector(x: 0, y: 0, z: v.2, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha),
                    ])
                }
                let red = only((1, 0, 0), alpha: 1).transformed(by: CGAffineTransform(translationX: dx, y: 0))
                let green = only((0, 1, 0), alpha: 0), blue = only((0, 0, 1), alpha: 0).transformed(by: CGAffineTransform(translationX: -dx, y: 0))
                img = red.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: green])
                    .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: blue]).cropped(to: rect)
                if let lines = CIFilter(name: "CIStripesGenerator", parameters: [
                    "inputCenter": CIVector(x: 0, y: 0), "inputColor0": CIColor(red: 1, green: 1, blue: 1),
                    "inputColor1": CIColor(red: 1 - 0.28 * a, green: 1 - 0.28 * a, blue: 1 - 0.28 * a), "inputWidth": max(1.5, Double(short) / 240), "inputSharpness": 0.4,
                ])?.outputImage?.transformed(by: CGAffineTransform(rotationAngle: .pi / 2)).cropped(to: rect) {
                    img = lines.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: img]).cropped(to: rect)
                }
            }
        default: break
        }
        // Cinema bars slide in over the first half second — under the decorations, so nothing is ever hidden behind them.
        if r.texture == "bars" {
            let tall = H > W
            let full = tall ? H * 0.09 : max(0, (H - W / 2.39) / 2)
            let bar = full * CGFloat(min(1, t / 0.5)) * CGFloat(0.7 + 0.3 * a)
            let black = CIImage(color: .black)
            img = black.cropped(to: CGRect(x: 0, y: H - bar, width: W, height: bar)).composited(over: img)
            img = black.cropped(to: CGRect(x: 0, y: 0, width: W, height: bar)).composited(over: img)
        }
        // Sparkle.
        kit.lock.lock()
        if kit.painter == nil, let th = sparkleTheme(r.sparkle) {
            let k = min(1, 1280 / max(W, H))
            kit.painter = Celebrate.Painter(theme: th, size: CGSize(width: W * k, height: H * k), amount: 0.45 + 1.15 * a)
        }
        if kit.words == nil, let c = caption, let cg = Celebrate.captionImage(c, frame: size)?.cgImage {
            kit.words = (CIImage(cgImage: cg), CGSize(width: cg.width, height: cg.height))
        }
        let painter = kit.painter, words = kit.words
        kit.lock.unlock()
        if let p = painter { img = Celebrate.decorate(img, painter: p, t: t, size: size) }
        // Words, arriving in their style.
        if let w = words, let c = caption {
            let wimg = w.image, sz = w.size
            let (alpha, scale, lift) = wordsMotion(r.words, t: t)
            let cx = c.center.x * W, cy = (1 - c.center.y) * H + lift * H
            let placed = wimg
                .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)])
                .transformed(by: CGAffineTransform(translationX: -sz.width / 2, y: -sz.height / 2)
                    .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                    .concatenating(CGAffineTransform(translationX: cx, y: cy)))
            img = placed.composited(over: img)
        }
        return img.cropped(to: rect)
    }

    /// How the words look at `t`: how see-through, how big, how far up (share of the height). Pure.
    static func wordsMotion(_ style: String, t: Double) -> (alpha: Double, scale: Double, lift: Double) {
        let s = max(0, t - 0.2)
        switch style {
        case "fade": return (min(1, s / 0.7), 1, 0)
        case "slide":
            let p = min(1, s / 0.55), e = 1 - pow(1 - p, 3)
            return (min(1, s / 0.3), 1, -0.08 * (1 - e))
        case "bounce":
            let p = min(1, s / 0.45)
            let pop = p < 1 ? 1.18 * sin(p * .pi / 2) - 0.18 * sin(p * .pi) : 1
            return (min(1, s / 0.2), pop, s > 0.45 ? 0.006 * sin((s - 0.45) * 4.2) : 0)
        default: // pop: grows past full size, settles
            let p = min(1, s / 0.4)
            let scale = p < 1 ? 0.4 + 0.75 * p + 0.25 * sin(p * .pi) * (1 - p) * 2 : 1
            return (min(1, s / 0.15), min(1.2, scale), 0)
        }
    }

    // MARK: - The video

    /// The whole recipe on every frame of `asset`: for the live preview (set on the player item) and the saved file.
    static func composition(for asset: AVAsset, recipe: Recipe, caption: Celebrate.Caption?, beats: [Double]) async -> AVVideoComposition? {
        let track = try? await asset.loadTracks(withMediaType: .video).first
        let tr = (try? await track?.load(.preferredTransform)) ?? .identity
        let duration = (try? await asset.load(.duration).seconds) ?? 0
        let orient: CGImagePropertyOrientation = {
            switch (tr.a, tr.b, tr.c, tr.d) {
            case (0, 1, -1, 0): return .right
            case (0, -1, 1, 0): return .left
            case (-1, 0, 0, -1): return .down
            default: return .up
            }
        }()
        let kit = Kit(recipe)
        return try? await AVMutableVideoComposition.videoComposition(with: asset) { request in
            let render = request.renderSize
            var src = request.sourceImage
            if abs(src.extent.width - render.width) > 2 || abs(src.extent.height - render.height) > 2, orient != .up { src = src.oriented(orient) }
            if src.extent.origin != .zero { src = src.transformed(by: CGAffineTransform(translationX: -src.extent.minX, y: -src.extent.minY)) }
            let out = frame(src, t: request.compositionTime.seconds, duration: duration, size: render, kit: kit, beats: beats, caption: caption)
            request.finish(with: out, context: nil)
        }
    }

    /// Saves the video with the recipe on it (sound kept), with live progress. nil if the phone couldn't make it.
    static func export(_ source: URL, recipe: Recipe, caption: Celebrate.Caption?) async -> URL? {
        let asset = AVURLAsset(url: source)
        var b: [Double] = []
        if recipe.motion == "pulse" { b = await beats(source) }
        guard let comp = await composition(for: asset, recipe: recipe, caption: caption, beats: b),
              let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = VideoEngine.tempURL("mp4")
        s.outputURL = out; s.outputFileType = .mp4; s.videoComposition = comp; s.metadata = []
        let secs = (try? await asset.load(.duration).seconds) ?? 0
        return await VideoEngine.run(s, seconds: secs) ? out : nil
    }

    /// A quick, smaller copy of the first seconds with the recipe on, for a player that can't run the effects live (the
    /// build machine's simulator fails any video composition in playback; export works). Plays in the preview box.
    static func previewClip(_ source: URL, recipe: Recipe, beats: [Double], seconds: Double = 8) async -> URL? {
        let asset = AVURLAsset(url: source)
        guard let comp = await composition(for: asset, recipe: recipe, caption: nil, beats: beats),
              let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else { return nil }
        let length = (try? await asset.load(.duration)) ?? .zero
        s.videoComposition = comp
        s.metadata = []
        s.timeRange = CMTimeRange(start: .zero, duration: CMTimeMinimum(length, CMTime(seconds: seconds, preferredTimescale: 600)))
        let out = VideoEngine.tempURL("mp4")
        do { try await s.export(to: out, as: .mp4) } catch { return nil }
        return FileManager.default.fileExists(atPath: out.path) ? out : nil
    }

    /// A small picture of the recipe on one frame, for the choices (the moment `t` of a `duration` clip).
    static let context = CIContext(options: [.cacheIntermediates: false])
    static func still(_ poster: CGImage, recipe: Recipe, t: Double = 1.4, duration: Double = 4, beats: [Double] = []) -> UIImage? {
        let src = CIImage(cgImage: poster)
        let out = frame(src, t: t, duration: duration, size: src.extent.size, kit: Kit(recipe), beats: beats.isEmpty ? [t - 0.03] : beats, caption: nil)
        guard let cg = context.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
