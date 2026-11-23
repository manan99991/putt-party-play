import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics
import Vision
import CoreMotion
import AVFoundation

/// The camera that thinks: reads what the lens sees (Vision on-device classification + faces, the
/// picture's brightness, highlights, warmth and motion, the camera's own ISO/shutter, how the phone is
/// held) and decides the scene — sunset, portrait, night, food, document… — then the single most useful
/// tip ("tilt left a little", "hold still"). Works on every iPhone, offline, in any country.
/// The deciding is pure and unit-tested; `SceneReader` gathers the signals live.
enum SceneSense {
    struct Signals: Equatable {
        var labels: [String: Float] = [:]     // Vision's classifications (identifier → confidence)
        var faces = 0
        var faceArea: Double = 0              // largest face, fraction of the frame
        var faceCenter: CGPoint?              // normalized, top-left origin
        var meanLuma: Double = 0.5
        var highlights: Double = 0            // share of pixels that are blown out
        var shadows: Double = 0               // share of pixels that are near black
        var warmth: Double = 0                // mean (R − B), −1…1
        var centerVsEdge: Double = 0          // centre brightness − edge brightness (negative = backlit)
        var iso: Double = 100
        var shutter: Double = 1.0 / 60
        var motion: Double = 0                // change between frames, 0…1
        var shake: Double = 0                 // how much the phone moves (rad/s)
        var tilt: Double = 0                  // degrees off level (+ = clockwise)
        var hour = 12
        var textBoxes = 0                     // lines of text Vision sees — a page has many; a door has none
    }

    enum Scene: String, CaseIterable {
        case sunset, stars, night, portrait, group, pet, food, document, snowBeach, backlit, action, landscape, closeup, indoor, everyday

        var title: String {
            switch self {
            case .sunset: return "Sunset spotted"
            case .stars: return "Night sky spotted"
            case .night: return "It's dark — night mode"
            case .portrait: return "Portrait spotted"
            case .group: return "Group photo spotted"
            case .pet: return "Pet spotted"
            case .food: return "Food spotted"
            case .document: return "Page spotted"
            case .snowBeach: return "Bright snow or beach"
            case .backlit: return "Strong light behind"
            case .action: return "Movement spotted"
            case .landscape: return "Landscape spotted"
            case .closeup: return "Close-up spotted"
            case .indoor: return "Indoor light"
            case .everyday: return "Ready"
            }
        }
        var button: String {
            switch self {
            case .sunset: return "Take the best sunset shot"
            case .stars: return "Take the best night-sky shot"
            case .night: return "Take the best night photo"
            case .portrait: return "Take the best portrait"
            case .group: return "Take the best group photo"
            case .pet: return "Take the best pet photo"
            case .food: return "Take the best food photo"
            case .document: return "Take the clearest page photo"
            case .snowBeach: return "Take the best bright-scene shot"
            case .backlit: return "Take the best shot into the light"
            case .action: return "Freeze the action"
            case .landscape: return "Take the best landscape"
            case .closeup: return "Take the best close-up"
            case .indoor: return "Take the best indoor photo"
            case .everyday: return "Take the best photo"
            }
        }
        /// What Tenzy changed for this scene, in plain words.
        var why: String {
            switch self {
            case .sunset: return "Warmer colour and a slightly darker exposure so the sky keeps its glow."
            case .stars: return "Long exposure and focus set to the far distance."
            case .night: return "Brighter exposure; the phone stacks frames to keep it clean."
            case .portrait: return "Focus and exposure follow the face."
            case .group: return "Fast enough to catch everyone, exposure balanced across faces."
            case .pet: return "Faster shutter so a moving pet stays sharp."
            case .food: return "A touch brighter and warmer, so it looks as good as it tastes."
            case .document: return "Sharp, even exposure so every word reads."
            case .snowBeach: return "Brighter exposure so white looks white, not grey."
            case .backlit: return "Exposure lifted so your subject isn't a dark shape."
            case .action: return "Shutter never slower than 1/500 s — motion freezes."
            case .landscape: return "Slightly darker exposure to keep detail in the sky."
            case .closeup: return "Focus on the nearest detail."
            case .indoor: return "Exposure and colour balanced for indoor light."
            case .everyday: return "The camera's own best automatic settings."
            }
        }
        /// After the shot: the looks worth offering for this scene (the first is "as shot").
        var looks: [Look] {
            switch self {
            case .sunset: return [.natural, .golden, .dramatic, .silhouette]
            case .portrait, .group: return [.natural, .soft, .warm, .mono]
            case .food: return [.natural, .warm, .vivid]
            case .landscape, .snowBeach: return [.natural, .vivid, .dramatic, .mono]
            case .night, .stars: return [.natural, .cool, .dramatic]
            case .document: return [.natural, .crisp]
            case .pet, .closeup: return [.natural, .vivid, .warm, .mono]
            default: return [.natural, .vivid, .warm, .mono]
            }
        }
    }

    /// Which scene this is. Order matters: the more specific reading wins.
    static func scene(_ s: Signals) -> Scene {
        func lab(_ keys: [String], _ min: Float = 0.3) -> Bool {
            s.labels.contains { k, v in v >= min && keys.contains { k.contains($0) } }
        }
        // A page needs real writing on it: white closet doors or a blank wall look like "paper" to the classifier,
        // so the page mode only switches on when Vision also sees several lines of text.
        if s.textBoxes >= 4, lab(["document", "text", "paper", "receipt", "handwriting", "whiteboard"], 0.3) || s.textBoxes >= 10 { return .document }
        if s.faces >= 2 { return .group }
        if s.faces == 1, s.faceArea >= 0.02 { return .portrait }
        if lab(["dog", "cat", "puppy", "kitten", "pet", "animal"], 0.35) { return .pet }
        if lab(["food", "meal", "dish", "dessert", "cake", "pizza", "salad", "sushi", "burger", "fruit", "bread"], 0.35) { return .food }
        let goldenHour = (16...20).contains(s.hour) || (5...8).contains(s.hour)
        if lab(["sunset", "sunrise"], 0.25) || (goldenHour && s.warmth > 0.12 && (0.15...0.75).contains(s.meanLuma) && lab(["sky", "cloud", "outdoor", "sea", "ocean", "horizon"], 0.2)) {
            return .sunset
        }
        let dark = s.meanLuma < 0.18 || (s.iso >= 1000 && s.shutter >= 1.0 / 30)
        if dark, s.meanLuma < 0.1, s.motion < 0.03, lab(["sky", "night", "star", "outdoor", "moon"], 0.2) || (s.hour >= 20 || s.hour <= 4) && s.iso >= 1600 {
            return .stars
        }
        if dark { return .night }
        if lab(["snow", "beach", "sand", "ski"], 0.3) || (s.meanLuma > 0.75 && s.highlights > 0.1) { return .snowBeach }
        if s.centerVsEdge < -0.2, s.highlights > 0.08 { return .backlit }
        if s.motion > 0.08 { return .action }
        if lab(["flower", "plant", "leaf", "insect", "macro"], 0.35) { return .closeup }
        if lab(["sky", "mountain", "landscape", "outdoor", "tree", "forest", "water", "lake", "sea", "ocean", "field", "building", "city", "bridge"], 0.3) { return .landscape }
        if s.iso >= 400 { return .indoor }
        return .everyday
    }

    /// The one most useful thing to tell the person right now, or nil when the shot is good to go.
    static func coach(_ s: Signals, scene: Scene) -> String? {
        let slow = s.shutter >= 1.0 / 30 || [.night, .stars].contains(scene)
        if s.shake > 0.6, slow { return "Hold still — brace your elbows or lean on something." }
        let levelMatters: Set<Scene> = [.sunset, .landscape, .snowBeach, .stars, .everyday, .document, .backlit]
        if abs(s.tilt) > 2.5, levelMatters.contains(scene) {
            return s.tilt > 0 ? "Tilt left a little — the horizon is crooked." : "Tilt right a little — the horizon is crooked."
        }
        switch scene {
        case .portrait:
            if s.faceArea > 0.35 { return "Step back a little — you're very close to their face." }
            if let c = s.faceCenter, c.x < 0.15 || c.x > 0.85 || c.y < 0.08 { return "Move so their face isn't at the edge of the frame." }
            if s.centerVsEdge < -0.2 { return "Light is behind them — I've brightened their face. Turning them toward the light is even better." }
            return "Tap their face to lock focus, then shoot."
        case .group: return "Everyone in? Leave a little room around the edges."
        case .sunset: return s.highlights > 0.15 ? "The sun is very bright — I've darkened it to keep the colours." : "Put the horizon on the lower line for more sky."
        case .stars: return "Rest the phone on something still — this one takes a few seconds."
        case .night: return "Hold still for a moment after you tap."
        case .pet: return "Get down to their eye level for the best shot."
        case .food: return "Try straight from above, or a 45° angle near a window."
        case .document: return "Hold the phone flat above the page, filling the frame."
        case .action: return "Follow the movement and tap — the shutter is set to freeze it."
        case .snowBeach: return "Bright scene — I've lifted the exposure so white stays white."
        case .backlit: return "Strong light behind — I've lifted the exposure. Moving so the light is beside you helps too."
        case .landscape: return "Put the horizon on a line, not across the middle."
        case .closeup: return "Get close and tap the detail you want sharp."
        case .indoor: return "Near a window is the best light indoors."
        case .everyday: return nil
        }
    }

    // MARK: - Reading a frame (pure where it can be)

    /// Brightness, highlights, shadows, warmth and centre-vs-edge from a small RGBA copy (top row first).
    static func tones(_ rgba: [UInt8], w: Int, h: Int) -> (mean: Double, highlights: Double, shadows: Double, warmth: Double, centerVsEdge: Double) {
        guard w > 0, h > 0, rgba.count >= w * h * 4 else { return (0.5, 0, 0, 0, 0) }
        var sum = 0.0, hi = 0, lo = 0, warm = 0.0, cSum = 0.0, cN = 0, eSum = 0.0, eN = 0
        for y in 0..<h { for x in 0..<w {
            let i = (y * w + x) * 4
            let r = Double(rgba[i]) / 255, g = Double(rgba[i + 1]) / 255, b = Double(rgba[i + 2]) / 255
            let l = 0.299 * r + 0.587 * g + 0.114 * b
            sum += l; warm += r - b
            if l > 0.97 { hi += 1 }; if l < 0.04 { lo += 1 }
            let cx = abs(Double(x) / Double(w) - 0.5), cy = abs(Double(y) / Double(h) - 0.5)
            if cx < 0.2 && cy < 0.2 { cSum += l; cN += 1 } else if cx > 0.35 || cy > 0.35 { eSum += l; eN += 1 }
        } }
        let n = Double(w * h)
        return (sum / n, Double(hi) / n, Double(lo) / n, warm / n, (cN > 0 ? cSum / Double(cN) : 0) - (eN > 0 ? eSum / Double(eN) : 0))
    }

    /// How much two small gray copies differ, 0…1.
    static func motion(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard !a.isEmpty, a.count == b.count else { return 0 }
        var d = 0
        for i in a.indices { d += abs(Int(a[i]) - Int(b[i])) }
        return Double(d) / Double(a.count * 255)
    }

    /// Degrees off level from gravity, however the phone is held — upright, on either side or upside down — so a phone
    /// held level on its side reads level (0 = level, + = turned clockwise from the nearest of the four ways round).
    static func tilt(gravityX x: Double, gravityY y: Double) -> Double {
        guard abs(x) + abs(y) > 0.3 else { return 0 }   // lying flat (shooting straight down): no horizon to level
        let a = atan2(x, -y) * 180 / .pi
        return a - (a / 90).rounded() * 90
    }

    // MARK: - Looks after the shot

    enum Look: String, CaseIterable {
        case natural, golden, warm, cool, vivid, dramatic, soft, mono, silhouette, crisp
        var title: String {
            switch self {
            case .natural: return "As shot"; case .golden: return "Golden"; case .warm: return "Warm"; case .cool: return "Cool"
            case .vivid: return "Vivid"; case .dramatic: return "Dramatic"; case .soft: return "Soft glow"; case .mono: return "Black & white"
            case .silhouette: return "Silhouette"; case .crisp: return "Crisp"
            }
        }
    }

    static func apply(_ look: Look, to img: CIImage) -> CIImage {
        func temp(_ t: CGFloat) -> CIImage {
            let f = CIFilter.temperatureAndTint(); f.inputImage = img; f.neutral = CIVector(x: 6500, y: 0); f.targetNeutral = CIVector(x: t, y: 0)
            return f.outputImage ?? img
        }
        func color(_ i: CIImage, sat: Float, con: Float, bri: Float = 0) -> CIImage {
            let f = CIFilter.colorControls(); f.inputImage = i; f.saturation = sat; f.contrast = con; f.brightness = bri
            return f.outputImage ?? i
        }
        func vignette(_ i: CIImage, _ k: Float) -> CIImage {
            let f = CIFilter.vignette(); f.inputImage = i; f.intensity = k; f.radius = 1.6
            return f.outputImage ?? i
        }
        let e = img.extent
        let out: CIImage
        switch look {
        case .natural: out = img
        case .golden: out = vignette(color(temp(5200), sat: 1.15, con: 1.05), 0.5)
        case .warm: out = color(temp(5800), sat: 1.05, con: 1.0)
        case .cool: out = color(temp(7600), sat: 1.0, con: 1.05)
        case .vivid: let v = CIFilter.vibrance(); v.inputImage = img; v.amount = 0.6; out = color(v.outputImage ?? img, sat: 1.05, con: 1.06)
        case .dramatic: out = vignette(color(img, sat: 1.1, con: 1.25, bri: -0.03), 0.9)
        case .soft:
            let b = CIFilter.bloom(); b.inputImage = img; b.radius = 8; b.intensity = 0.35
            out = color(b.outputImage ?? img, sat: 1.0, con: 0.97, bri: 0.02)
        case .mono: let m = CIFilter.photoEffectNoir(); m.inputImage = img; out = m.outputImage ?? img
        case .silhouette:
            let ex = CIFilter.exposureAdjust(); ex.inputImage = img; ex.ev = -1.0
            out = vignette(color(ex.outputImage ?? img, sat: 1.25, con: 1.4), 0.6)
        case .crisp:
            let sh = CIFilter.sharpenLuminance(); sh.inputImage = img; sh.sharpness = 0.6
            out = color(sh.outputImage ?? img, sat: 0.9, con: 1.15, bri: 0.02)
        }
        return out.cropped(to: e)
    }
}

/// Gathers the live signals: classifies and finds faces about once a second (off the main thread),
/// measures tones and motion, reads the camera's exposure and the phone's tilt. Publishes the scene + tip.
@MainActor final class SceneReader: ObservableObject {
    @Published var scene: SceneSense.Scene = .everyday
    @Published var tip: String?
    @Published var tilt: Double = 0
    @Published var signals = SceneSense.Signals()

    private let motion = CMMotionManager()
    private var busy = false
    private var lastGray: [UInt8] = []
    private var history: [SceneSense.Scene] = []
    private let ctx = CIContext(options: [.useSoftwareRenderer: false])

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let m else { return }
            let t = SceneSense.tilt(gravityX: m.gravity.x, gravityY: m.gravity.y)
            self.tilt = self.tilt * 0.7 + t * 0.3
            let r = m.rotationRate
            self.signals.shake = self.signals.shake * 0.7 + sqrt(r.x * r.x + r.y * r.y + r.z * r.z) * 0.3
            self.signals.tilt = self.tilt
        }
    }
    func stop() { motion.stopDeviceMotionUpdates() }

    /// Read one frame. Call about once a second.
    func read(_ frame: CIImage, device: AVCaptureDevice?) {
        guard !busy else { return }
        busy = true
        let w = 48, h = 64
        let e = frame.extent
        let small = frame.transformed(by: CGAffineTransform(scaleX: CGFloat(w) / e.width, y: CGFloat(h) / e.height))
            .transformed(by: CGAffineTransform(translationX: -e.minX * CGFloat(w) / e.width, y: -e.minY * CGFloat(h) / e.height))
        let thumbScale = 360 / max(e.width, e.height)
        let thumb = frame.transformed(by: CGAffineTransform(scaleX: thumbScale, y: thumbScale))
        guard let smallCG = ctx.createCGImage(small, from: CGRect(x: 0, y: 0, width: w, height: h)),
              let thumbCG = ctx.createCGImage(thumb, from: thumb.extent) else { busy = false; return }
        let iso = Double(device?.iso ?? 100), shutter = device?.exposureDuration.seconds ?? 1.0 / 60
        let prev = lastGray
        let hour = Calendar.current.component(.hour, from: Date())
        nonisolated(unsafe) let sCG = smallCG, tCG = thumbCG
        Task.detached(priority: .utility) {
            var rgba = [UInt8](repeating: 0, count: w * h * 4)
            rgba.withUnsafeMutableBytes { buf in
                CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?
                    .draw(sCG, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
            let tones = SceneSense.tones(rgba, w: w, h: h)
            let gray = GrayPixels.read(sCG, w: w, h: h) ?? []
            let mot = SceneSense.motion(prev, gray)
            // Vision: what's in it, and where the faces are.
            let classify = VNClassifyImageRequest()
            let faces = VNDetectFaceRectanglesRequest()
            let text = VNDetectTextRectanglesRequest()
            try? VNImageRequestHandler(cgImage: tCG, options: [:]).perform([classify, faces, text])
            let lines = text.results?.count ?? 0
            var labels: [String: Float] = [:]
            for o in (classify.results ?? []).prefix(40) where o.confidence > 0.15 { labels[o.identifier.lowercased()] = o.confidence }
            let fs = faces.results ?? []
            let big = fs.max { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }
            await MainActor.run {
                var s = self.signals
                s.labels = labels; s.faces = fs.count
                s.faceArea = big.map { Double($0.boundingBox.width * $0.boundingBox.height) } ?? 0
                s.faceCenter = big.map { CGPoint(x: $0.boundingBox.midX, y: 1 - $0.boundingBox.midY) }
                s.meanLuma = tones.mean; s.highlights = tones.highlights; s.shadows = tones.shadows
                s.warmth = tones.warmth; s.centerVsEdge = tones.centerVsEdge
                s.iso = iso; s.shutter = shutter.isFinite && shutter > 0 ? shutter : 1.0 / 60
                s.motion = mot; s.hour = hour; s.textBoxes = lines
                self.signals = s
                self.lastGray = gray
                // Steady the label: switch scene only when two readings in a row agree.
                let now = SceneSense.scene(s)
                self.history = Array((self.history + [now]).suffix(2))
                if self.history.count == 2, self.history[0] == self.history[1], self.scene != now { self.scene = now }
                self.tip = SceneSense.coach(s, scene: self.scene)
                self.busy = false
            }
        }
    }
}
