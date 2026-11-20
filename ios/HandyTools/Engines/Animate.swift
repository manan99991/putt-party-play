import AVFoundation
import CoreImage
import UIKit

/// Animate — photos in, a polished, post-ready video out. 26 styles, drawn with Core Graphics and Core
/// Image, and encoded with the phone's own H.264 encoder, so it works on every iPhone, offline, in any
/// country. Frames are streamed straight into the encoder (constant memory: a 30-second 1080×1920 video
/// never holds more than a couple of frames), and photos are prepared lazily, a few at a time.
/// Output is sized to a real platform format (VideoFormat) — Reels/TikTok/Shorts, Story, Square,
/// Portrait or YouTube — either filling the frame or fitting the whole photo over a soft blurred backdrop.
enum Animate {

    enum Style: String, CaseIterable, Identifiable {
        case kenBurns, crossfade, slide, zoomPulse, polaroid, cube, filmStrip, flipbook, boomerang
        case pageTurn, fold, copyMachine, cardFlip, carousel, doors, whoosh, lightLeak
        case ripple, swirl, pixelate, glitch, iris, heart, blinds, shatter, dust
        var id: String { rawValue }

        /// How the style picker groups them.
        enum Group: String, CaseIterable, Identifiable {
            case smooth = "Smooth", paper = "Paper & film", threeD = "3D", fun = "Fun"
            var id: String { rawValue }
        }
        var group: Group {
            switch self {
            case .kenBurns, .crossfade, .slide, .whoosh, .lightLeak, .boomerang: return .smooth
            case .pageTurn, .flipbook, .fold, .polaroid, .filmStrip, .copyMachine: return .paper
            case .cube, .cardFlip, .carousel, .doors: return .threeD
            default: return .fun
            }
        }
        static func inGroup(_ g: Group) -> [Style] { allCases.filter { $0.group == g } }
        var title: String {
            switch self {
            case .kenBurns: return "Ken Burns"
            case .crossfade: return "Crossfade"
            case .slide: return "Slide"
            case .zoomPulse: return "Beat zoom"
            case .polaroid: return "Polaroid stack"
            case .cube: return "3D cube"
            case .filmStrip: return "Film strip"
            case .flipbook: return "Flipbook"
            case .boomerang: return "Boomerang"
            case .pageTurn: return "Page turn"
            case .fold: return "Fold"
            case .copyMachine: return "Scanner"
            case .cardFlip: return "Card flip"
            case .carousel: return "Carousel"
            case .doors: return "Doors"
            case .whoosh: return "Whoosh"
            case .lightLeak: return "Light leak"
            case .ripple: return "Ripple"
            case .swirl: return "Swirl"
            case .pixelate: return "Pixelate"
            case .glitch: return "Glitch"
            case .iris: return "Iris"
            case .heart: return "Heart"
            case .blinds: return "Blinds"
            case .shatter: return "Shatter"
            case .dust: return "Dust"
            }
        }
        var blurb: String {
            switch self {
            case .kenBurns: return "Slow cinematic pan and zoom"
            case .crossfade: return "Soft dissolve between photos"
            case .slide: return "Each photo pushes the last away"
            case .zoomPulse: return "Punchy zoom cuts with a flash"
            case .polaroid: return "Prints drop onto a pile"
            case .cube: return "Photos turn like a spinning cube"
            case .filmStrip: return "A strip of film rolls past"
            case .flipbook: return "Pages riffle past with a real page curl"
            case .boomerang: return "Back-and-forth loop — great for bursts"
            case .pageTurn: return "Each photo is a page you turn, curl and shadow"
            case .fold: return "Folds away like a paper fan"
            case .copyMachine: return "A light bar sweeps the next photo in"
            case .cardFlip: return "Each photo flips over like a card"
            case .carousel: return "Photos ride round on a 3D carousel"
            case .doors: return "Opens like double doors onto the next photo"
            case .whoosh: return "Zooms through with motion blur"
            case .lightLeak: return "Warm film light washes between photos"
            case .ripple: return "A ripple spreads like a drop in water"
            case .swirl: return "Twists into the next photo"
            case .pixelate: return "Breaks into pixels and back"
            case .glitch: return "Digital glitch cuts"
            case .iris: return "A circle opens onto the next photo"
            case .heart: return "A heart opens onto the next photo"
            case .blinds: return "Slats swipe across"
            case .shatter: return "Breaks into pieces"
            case .dust: return "Crumbles away like dust"
            }
        }
        var icon: String {
            switch self {
            case .kenBurns: return "camera.metering.center.weighted"
            case .crossfade: return "circle.lefthalf.filled"
            case .slide: return "rectangle.lefthalf.inset.filled.arrow.left"
            case .zoomPulse: return "bolt.fill"
            case .polaroid: return "photo.stack"
            case .cube: return "cube"
            case .filmStrip: return "film"
            case .flipbook: return "book.pages"
            case .boomerang: return "arrow.left.arrow.right"
            case .pageTurn: return "book"
            case .fold: return "rectangle.split.3x1"
            case .copyMachine: return "scanner"
            case .cardFlip: return "rectangle.portrait.rotate"
            case .carousel: return "rotate.3d"
            case .doors: return "door.french.open"
            case .whoosh: return "wind"
            case .lightLeak: return "sun.haze"
            case .ripple: return "drop"
            case .swirl: return "tornado"
            case .pixelate: return "square.grid.3x3"
            case .glitch: return "waveform.path"
            case .iris: return "circle.dashed"
            case .heart: return "heart"
            case .blinds: return "blinds.vertical.open"
            case .shatter: return "burst"
            case .dust: return "aqi.medium"
            }
        }
        var minPhotos: Int { [.kenBurns, .zoomPulse, .polaroid, .filmStrip].contains(self) ? 1 : 2 }
    }

    enum Pace: String, CaseIterable, Identifiable {
        case relaxed, normal, quick
        var id: String { rawValue }
        var title: String { self == .relaxed ? "Relaxed" : (self == .normal ? "Normal" : "Quick") }
        var factor: Double { self == .relaxed ? 1.4 : (self == .normal ? 1.0 : 0.65) }
    }

    enum Framing: String, CaseIterable, Identifiable {
        case fill, fit
        var id: String { rawValue }
        var title: String { self == .fill ? "Fill the frame" : "Show whole photo" }
    }

    struct Settings: Equatable {
        var style: Style = .kenBurns
        var format: VideoFormat.Spec = VideoFormat.presets[0]
        var framing: Framing = .fill
        var pace: Pace = .normal
    }

    /// Smart default for how many photos were picked.
    static func suggestedStyle(count: Int) -> Style {
        switch count {
        case ...1: return .kenBurns
        case 2: return .slide
        case 3...8: return .kenBurns
        default: return .zoomPulse
        }
    }

    // MARK: - Timeline

    struct Timeline: Equatable {
        let fps: Int
        let hold: Double          // seconds each photo rests
        let trans: Double         // seconds each transition takes
        let count: Int
        let frameCount: Int
        var seconds: Double { Double(frameCount) / Double(fps) }
    }

    static func timeline(count: Int, settings: Settings, fps: Int = 30) -> Timeline {
        let n = max(1, count)
        let f = settings.pace.factor
        if settings.style == .boomerang {
            let per = max(2, Int((4 * f).rounded()))                       // frames per photo
            let cycle = max(1, 2 * n - 2)
            return Timeline(fps: fps, hold: Double(per) / Double(fps), trans: 0, count: n, frameCount: cycle * per * 3)
        }
        let baseHold: Double = n == 1 ? 5 : (n <= 3 ? 2.6 : (n <= 8 ? 2.0 : 1.3))
        // A flipbook riffles: short rests, quick curls (photos repeat to make a loop — see `sequence`).
        let hold = (settings.style == .flipbook ? 0.35 : baseHold) * f
        let trans: Double
        switch settings.style {
        case .zoomPulse, .glitch: trans = 0.3 * f
        case .flipbook, .whoosh: trans = 0.45 * f
        case .crossfade, .kenBurns, .carousel, .iris, .pixelate, .blinds: trans = 0.7 * f
        case .cube, .cardFlip, .fold, .swirl, .heart, .shatter: trans = 0.85 * f
        case .pageTurn, .doors, .copyMachine, .lightLeak, .ripple, .dust: trans = 1.05 * f
        default: trans = 0.5 * f
        }
        let total = Double(n) * hold + Double(n - 1) * trans
        return Timeline(fps: fps, hold: hold, trans: trans, count: n, frameCount: max(1, Int((total * Double(fps)).rounded())))
    }

    /// Where frame `i` falls: resting on photo `k` (progress u) or moving from `k` to `k+1` (progress v).
    enum Phase: Equatable { case hold(k: Int, u: Double), move(k: Int, v: Double) }

    static func phase(frame i: Int, in tl: Timeline) -> Phase {
        let t = Double(i) / Double(tl.fps)
        let seg = tl.hold + tl.trans
        let k = min(tl.count - 1, Int(t / max(seg, 0.0001)))
        let local = t - Double(k) * seg
        if local < tl.hold || k == tl.count - 1 || tl.trans <= 0 {
            return .hold(k: k, u: min(1, local / max(tl.hold, 0.0001)))
        }
        return .move(k: k, v: min(1, (local - tl.hold) / tl.trans))
    }

    // MARK: - Render

    /// The photos in the order they play. A flipbook riffles the pages round and round (ending back on the first
    /// page so it loops cleanly) until it lasts at least ~6 seconds; every other style plays each photo once.
    static func sequence(_ images: [UIImage], settings: Settings) -> [UIImage] {
        guard settings.style == .flipbook, images.count >= 2 else { return images }
        let per = 0.8 * settings.pace.factor
        let rounds = max(1, min(6, Int((6 / (per * Double(images.count))).rounded(.up))))
        let out = Array((0..<rounds).flatMap { _ in images }.prefix(80))
        return out + [images[0]]
    }
    /// How many photos actually play (for the preview's length label).
    static func playCount(_ n: Int, settings: Settings) -> Int {
        guard settings.style == .flipbook, n >= 2 else { return n }
        let per = 0.8 * settings.pace.factor
        return min(80, max(1, min(6, Int((6 / (per * Double(n))).rounded(.up)))) * n) + 1
    }

    /// Render the video. `scale` < 1 makes a quick low-resolution draft for the live preview.
    static func render(_ images: [UIImage], settings: Settings, scale: CGFloat = 1, fps: Int = 30,
                       progress: ((Double) -> Void)? = nil) async -> URL? {
        let images = sequence(images, settings: settings)
        guard !images.isEmpty else { return nil }
        let size = evenSize(CGSize(width: settings.format.size.width * scale, height: settings.format.size.height * scale))
        let tl = timeline(count: images.count, settings: settings, fps: fps)
        let painter = Painter(images: images, size: size, framing: settings.framing)
        let style = settings.style
        let bitRate = Int(size.width * size.height * 4)               // ~8 Mbps at 1080×1920
        return await encode(size: size, fps: fps, frameCount: tl.frameCount, bitRate: bitRate, progress: progress) { i, ctx in
            painter.draw(style: style, frame: i, timeline: tl, in: ctx)
        }
    }

    /// One still frame (for thumbnails and tests).
    static func still(_ images: [UIImage], settings: Settings, at fraction: Double, scale: CGFloat = 0.25) -> UIImage? {
        let images = sequence(images, settings: settings)
        guard !images.isEmpty else { return nil }
        let size = evenSize(CGSize(width: settings.format.size.width * scale, height: settings.format.size.height * scale))
        let tl = timeline(count: images.count, settings: settings)
        let painter = Painter(images: images, size: size, framing: settings.framing)
        let i = min(tl.frameCount - 1, max(0, Int(Double(tl.frameCount) * fraction)))
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            let ctx = c.cgContext
            ctx.translateBy(x: 0, y: size.height); ctx.scaleBy(x: 1, y: -1)     // match the encoder's y-up space
            painter.draw(style: settings.style, frame: i, timeline: tl, in: ctx)
        }
    }

    static func evenSize(_ s: CGSize) -> CGSize {
        CGSize(width: max(2, (Int(s.width) / 2) * 2), height: max(2, (Int(s.height) / 2) * 2))
    }

    /// Stream frames straight into an H.264 MP4 — constant memory however long the video.
    static func encode(size: CGSize, fps: Int, frameCount: Int, bitRate: Int,
                       progress: ((Double) -> Void)?, draw: (Int, CGContext) -> Void) async -> URL? {
        let url = VideoEngine.tempURL("mp4")
        guard frameCount > 0, let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(1_000_000, bitRate),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: fps * 2,
            ] as [String: Any],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)
        let space = CGColorSpaceCreateDeviceRGB()
        for i in 0..<frameCount {
            if Task.isCancelled { writer.cancelWriting(); return nil }
            var waited = 0
            while !input.isReadyForMoreMediaData {
                try? await Task.sleep(nanoseconds: 4_000_000); waited += 1
                if waited > 2500 || writer.status == .failed { writer.cancelWriting(); return nil }   // ~10 s stuck
            }
            var pb: CVPixelBuffer?
            if let pool = adaptor.pixelBufferPool { CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb) }
            if pb == nil {
                CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB,
                                    [kCVPixelBufferCGBitmapContextCompatibilityKey as String: true] as CFDictionary, &pb)
            }
            guard let buffer = pb else { continue }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width), height: Int(size.height),
                                   bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                                   bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
                ctx.interpolationQuality = .high
                autoreleasepool { draw(i, ctx) }
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(i), timescale: Int32(fps)))
            if i % 6 == 0 { progress?(Double(i + 1) / Double(frameCount)) }
        }
        input.markAsFinished()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in writer.finishWriting { cont.resume() } }
        guard writer.status == .completed else { try? FileManager.default.removeItem(at: url); return nil }
        progress?(1)
        return url
    }

    // MARK: - Painter

    /// Prepares photos lazily (only the few on screen are kept) and draws each style's frame.
    final class Painter {
        let images: [UIImage]
        let size: CGSize
        let framing: Framing
        private var canvases: [Int: CGImage] = [:]
        private var cards: [Int: CGImage] = [:]
        private let ci = CIContext(options: [.useSoftwareRenderer: false])

        init(images: [UIImage], size: CGSize, framing: Framing) {
            self.images = images; self.size = size; self.framing = framing
        }

        var full: CGRect { CGRect(origin: .zero, size: size) }

        func draw(style: Style, frame i: Int, timeline tl: Timeline, in ctx: CGContext) {
            ctx.setFillColor(UIColor(white: 0.06, alpha: 1).cgColor); ctx.fill(full)
            if style == .boomerang { boomerang(i, tl, ctx); return }
            switch style {
            case .filmStrip: filmStrip(i, tl, ctx); return
            case .polaroid: polaroid(i, tl, ctx); return
            case .kenBurns: kenBurns(i, tl, ctx); return
            case .carousel: carousel(i, tl, ctx); return
            default: break
            }
            switch Animate.phase(frame: i, in: tl) {
            case .hold(let k, let u):
                if style == .zoomPulse {
                    let punch = 1 + 0.10 * (1 - Animate.easeOut(min(1, u * 3)))
                    photo(k, ctx, scale: punch)
                } else {
                    photo(k, ctx)
                }
            case .move(let k, let v):
                let e = Animate.easeInOut(v)
                switch style {
                case .crossfade:
                    photo(k, ctx); photo(k + 1, ctx, alpha: e)
                case .slide:
                    photo(k, ctx, dx: -e * size.width); photo(k + 1, ctx, dx: (1 - e) * size.width)
                case .zoomPulse:
                    if v < 0.5 { photo(k, ctx, scale: 1 + 0.12 * v) } else { photo(k + 1, ctx, scale: 1.1) }
                    ctx.setFillColor(UIColor(white: 1, alpha: 0.85 * (1 - abs(v - 0.5) * 2)).cgColor); ctx.fill(full)
                case .cube:
                    cube(k, k + 1, e, ctx)
                case .flipbook:
                    curl(k, k + 1, e, radius: 0.09, ctx)
                case .pageTurn:
                    curl(k, k + 1, e, radius: 0.2, ctx)
                case .cardFlip:
                    cardFlip(k, k + 1, e, ctx)
                case .doors:
                    doors(k, k + 1, v, ctx)
                case .fold, .ripple, .blinds, .copyMachine, .shatter, .dust:
                    transition(style, k, k + 1, e, ctx)
                case .swirl, .pixelate, .whoosh:
                    warp(style, k, k + 1, e, ctx)
                case .glitch:
                    glitch(k, k + 1, v, frame: i, ctx)
                case .iris, .heart:
                    reveal(k, k + 1, e, heart: style == .heart, ctx)
                case .lightLeak:
                    lightLeak(k, k + 1, e, ctx)
                default:
                    photo(k, ctx)
                }
            }
            prepareAhead(Animate.phase(frame: i, in: tl))
        }

        // Styles

        private func kenBurns(_ i: Int, _ tl: Timeline, _ ctx: CGContext) {
            let t = Double(i) / Double(tl.fps), seg = tl.hold + tl.trans
            func motion(_ j: Int) -> Double {
                let start = Double(j) * seg - (j > 0 ? tl.trans : 0)
                let life = tl.hold + (j > 0 ? tl.trans : 0) + (j < tl.count - 1 ? tl.trans : 0)
                return min(1, max(0, (t - start) / max(life, 0.001)))
            }
            func drawKB(_ j: Int, alpha: CGFloat) {
                let m = CGFloat(Animate.easeInOut(motion(j)))
                let zoomIn = j % 2 == 0
                let s = zoomIn ? 1.0 + 0.14 * m : 1.14 - 0.14 * m
                let dir: CGFloat = (j / 2) % 2 == 0 ? 1 : -1
                photo(j, ctx, scale: s, dx: dir * 0.035 * size.width * (m - 0.5), dy: 0.02 * size.height * (m - 0.5), alpha: alpha)
            }
            switch Animate.phase(frame: i, in: tl) {
            case .hold(let k, _): drawKB(k, alpha: 1)
            case .move(let k, let v): drawKB(k, alpha: 1); drawKB(k + 1, alpha: CGFloat(Animate.easeInOut(v)))
            }
            prepareAhead(Animate.phase(frame: i, in: tl))
        }

        // MARK: Core Image / 3D styles

        private func ciCanvas(_ j: Int) -> CIImage? { canvas(j).map { CIImage(cgImage: $0) } }

        /// Draw a Core Image result over whatever is already on the frame (transparent parts let it show).
        private func put(_ img: CIImage, _ ctx: CGContext) {
            guard let cg = ci.createCGImage(img.cropped(to: full), from: full) else { return }
            ctx.draw(cg, in: full)
        }

        private func shade(_ img: CIImage, _ k: CGFloat) -> CIImage {
            let m = max(0, min(1, 1 - k))
            return img.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: m, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: m, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: m, w: 0)])
        }

        /// A photo standing upright in 3D: centre (cx, cz) — z grows away from the viewer, 0 is the screen —
        /// turned by `yaw` about its vertical axis, seen in perspective from `D` in front of the screen.
        /// nil when it is edge-on or facing away.
        private func plane(_ img: CIImage, cx: CGFloat, cz: CGFloat, yaw: CGFloat, halfW: CGFloat, halfH: CGFloat,
                           D: CGFloat, zoom: CGFloat = 1) -> CIImage? {
            func edge(_ u: CGFloat) -> (x: CGFloat, f: CGFloat) {
                let x = cx + u * cos(yaw), z = cz + u * sin(yaw)
                let f = D / max(1, D + z) * zoom
                return (size.width / 2 + x * f, f)
            }
            let l = edge(-halfW), r = edge(halfW)
            guard r.x - l.x > 1 else { return nil }
            let my = size.height / 2
            return img.applyingFilter("CIPerspectiveTransform", parameters: [
                "inputTopLeft": CIVector(x: l.x, y: my + halfH * l.f), "inputTopRight": CIVector(x: r.x, y: my + halfH * r.f),
                "inputBottomRight": CIVector(x: r.x, y: my - halfH * r.f), "inputBottomLeft": CIVector(x: l.x, y: my - halfH * l.f)])
        }

        private func drawBackdrop(_ j: Int, _ ctx: CGContext, dim: CGFloat = 0.45) {
            if let bg = backdrop(j) { ctx.draw(bg, in: full) }
            ctx.setFillColor(UIColor(white: 0, alpha: dim).cgColor); ctx.fill(full)
        }

        /// A real cube turning left: the front face swings away as the right face comes round, in perspective.
        private func cube(_ a: Int, _ b: Int, _ e: Double, _ ctx: CGContext) {
            guard let A = ciCanvas(a), let B = ciCanvas(b) else { return }
            let half = size.width / 2, hh = size.height / 2, p = CGFloat(e)
            let phi = p * .pi / 2, D = size.width * 2.2
            let zoom = 1 / (1 + 0.25 * sin(p * .pi))
            drawBackdrop(p < 0.5 ? a : b, ctx)
            var faces: [(CIImage, CGFloat)] = []
            if let f = plane(shade(A, 0.6 * p), cx: -half * sin(phi), cz: half - half * cos(phi), yaw: -phi, halfW: half, halfH: hh, D: D, zoom: zoom) {
                faces.append((f, half - half * cos(phi)))
            }
            if let f = plane(shade(B, 0.6 * (1 - p)), cx: half * cos(phi), cz: half - half * sin(phi), yaw: .pi / 2 - phi, halfW: half, halfH: hh, D: D, zoom: zoom) {
                faces.append((f, half - half * sin(phi)))
            }
            var out = CIImage.empty()
            for (img, _) in faces.sorted(by: { $0.1 > $1.1 }) { out = img.composited(over: out) }
            put(out, ctx)
        }

        /// The photo flips over like a playing card, lifting a little as it turns; the next photo is on its back.
        private func cardFlip(_ a: Int, _ b: Int, _ e: Double, _ ctx: CGContext) {
            guard let A = ciCanvas(a), let B = ciCanvas(b) else { return }
            let th = CGFloat(e) * .pi
            drawBackdrop(e < 0.5 ? a : b, ctx)
            let img = th < .pi / 2 ? A : B
            let yaw = th < .pi / 2 ? th : th - .pi
            let lift = 1 / (1 + 0.18 * sin(th))
            if let f = plane(shade(img, 0.35 * sin(th)), cx: 0, cz: 0, yaw: yaw, halfW: size.width / 2, halfH: size.height / 2,
                             D: size.width * 2.6, zoom: lift) { put(f, ctx) }
        }

        /// Photos on a turning 3D carousel: the one in front faces you, its neighbours angle away to each side.
        private func carousel(_ i: Int, _ tl: Timeline, _ ctx: CGContext) {
            let pos: CGFloat
            switch Animate.phase(frame: i, in: tl) {
            case .hold(let k, _): pos = CGFloat(k)
            case .move(let k, let v): pos = CGFloat(k) + CGFloat(Animate.easeInOut(v))
            }
            let cur = min(tl.count - 1, Int(pos.rounded()))
            drawBackdrop(cur, ctx, dim: 0.5)
            let w = size.width
            var cards: [(CIImage, CGFloat)] = []
            for j in max(0, Int(pos) - 2)...min(tl.count - 1, Int(pos) + 2) {
                let s = CGFloat(j) - pos
                guard abs(s) < 1.9, let img = ciCanvas(j) else { continue }
                let c = max(-1, min(1, s))
                let z = abs(s) * w * 0.5
                if let f = plane(shade(img, min(0.7, abs(s) * 0.45)), cx: s * w * 0.5, cz: z, yaw: c * 0.95,
                                 halfW: w * 0.36, halfH: size.height * 0.36, D: w * 2.2) {
                    cards.append((f, z))
                }
            }
            var out = CIImage.empty()
            for (img, _) in cards.sorted(by: { $0.1 > $1.1 }) { out = img.composited(over: out) }
            put(out, ctx)
            evict(keep: [cur - 1, cur, cur + 1, cur + 2])
        }

        /// The photo splits down the middle and swings open toward you like double doors.
        private func doors(_ a: Int, _ b: Int, _ v: Double, _ ctx: CGContext) {
            guard let A = ciCanvas(a) else { return }
            let w = size.width, hh = size.height / 2, q = w / 4
            let e = CGFloat(Animate.easeInOut(v))
            photo(b, ctx, scale: 0.86 + 0.14 * e)
            ctx.setFillColor(UIColor(white: 0, alpha: 0.6 * (1 - e)).cgColor); ctx.fill(full)
            let beta = e * .pi * 0.56
            let D = w * 2.2
            let left = A.cropped(to: CGRect(x: 0, y: 0, width: w / 2, height: size.height))
            let right = A.cropped(to: CGRect(x: w / 2, y: 0, width: w / 2, height: size.height))
            var out = CIImage.empty()
            if let l = plane(shade(left, 0.5 * sin(beta)), cx: -w / 2 + q * cos(beta), cz: -q * sin(beta), yaw: -beta, halfW: q, halfH: hh, D: D) {
                out = l.composited(over: out)
            }
            if let r = plane(shade(right, 0.5 * sin(beta)), cx: w / 2 - q * cos(beta), cz: -q * sin(beta), yaw: beta, halfW: q, halfH: hh, D: D) {
                out = r.composited(over: out)
            }
            put(out, ctx)
        }

        /// A real page curl: the page lifts from the right edge, shows its paper back and casts a shadow.
        private func curl(_ a: Int, _ b: Int, _ e: Double, radius: CGFloat, _ ctx: CGContext) {
            guard let A = ciCanvas(a), let B = ciCanvas(b) else { return }
            let back = A.transformed(by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -size.width, y: 0))
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.25, kCIInputBrightnessKey: 0.38, kCIInputContrastKey: 0.45])
            guard let f = CIFilter(name: "CIPageCurlWithShadowTransition") else { photo(e < 0.5 ? a : b, ctx); return }
            f.setValue(A, forKey: kCIInputImageKey)
            f.setValue(B, forKey: kCIInputTargetImageKey)
            f.setValue(back, forKey: "inputBacksideImage")
            f.setValue(CIVector(cgRect: full), forKey: kCIInputExtentKey)
            f.setValue(e, forKey: kCIInputTimeKey)
            f.setValue(Animate.curlAngle + 0.16, forKey: kCIInputAngleKey)
            f.setValue(size.width * radius, forKey: kCIInputRadiusKey)
            f.setValue(0.6, forKey: "inputShadowSize")
            f.setValue(0.75, forKey: "inputShadowAmount")
            f.setValue(CIVector(cgRect: full), forKey: "inputShadowExtent")
            guard let out = f.outputImage else { return }
            put(out.composited(over: B), ctx)
        }

        private lazy var dustMask: CIImage = {
            let noise = CIFilter(name: "CIRandomGenerator")?.outputImage ?? CIImage(color: .gray)
            let w = self.size.width
            return noise.transformed(by: CGAffineTransform(scaleX: max(1, w / 90), y: max(1, w / 90)))
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                .clampedToExtent().applyingGaussianBlur(sigma: Double(w) / 60).cropped(to: self.full)
        }()

        /// Core Image's built-in transitions, each tuned for the frame size.
        private func transition(_ style: Style, _ a: Int, _ b: Int, _ e: Double, _ ctx: CGContext) {
            guard let A = ciCanvas(a), let B = ciCanvas(b) else { return }
            let w = size.width
            let center = CIVector(x: size.width / 2, y: size.height / 2)
            var out: CIImage?
            switch style {
            case .fold:
                out = A.applyingFilter("CIAccordionFoldTransition", parameters: [kCIInputTargetImageKey: B, kCIInputTimeKey: e,
                    "inputBottomHeight": 0, "inputNumberOfFolds": 4, "inputFoldShadowAmount": 0.6])
            case .ripple:
                let shading = CIFilter(name: "CIRadialGradient", parameters: ["inputCenter": center, "inputRadius0": 0, "inputRadius1": w * 0.7,
                    "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: 0.55), "inputColor1": CIColor(red: 1, green: 1, blue: 1, alpha: 0)])?
                    .outputImage?.cropped(to: full) ?? CIImage.empty()
                out = A.applyingFilter("CIRippleTransition", parameters: [kCIInputTargetImageKey: B, kCIInputTimeKey: e,
                    "inputShadingImage": shading, kCIInputCenterKey: center, kCIInputExtentKey: CIVector(cgRect: full),
                    kCIInputWidthKey: w * 0.14, kCIInputScaleKey: w * 0.05])
            case .blinds:
                out = A.applyingFilter("CIBarsSwipeTransition", parameters: [kCIInputTargetImageKey: B, kCIInputTimeKey: e,
                    kCIInputAngleKey: CGFloat.pi, kCIInputWidthKey: w * 0.09, "inputBarOffset": 12])
            case .copyMachine:
                out = A.applyingFilter("CICopyMachineTransition", parameters: [kCIInputTargetImageKey: B, kCIInputTimeKey: e,
                    kCIInputExtentKey: CIVector(cgRect: full), kCIInputColorKey: CIColor(red: 0.7, green: 0.95, blue: 1),
                    kCIInputAngleKey: 0, kCIInputWidthKey: w * 0.22, "inputOpacity": 1.3])
            case .shatter:
                out = A.applyingFilter("CIModTransition", parameters: [kCIInputTargetImageKey: B, kCIInputTimeKey: e,
                    kCIInputCenterKey: center, kCIInputAngleKey: 2.0, kCIInputRadiusKey: w * 0.22, "inputCompression": 300])
            case .dust:
                out = A.applyingFilter("CIDisintegrateWithMaskTransition", parameters: [kCIInputTargetImageKey: B, kCIInputTimeKey: e,
                    kCIInputMaskImageKey: dustMask, "inputShadowRadius": w * 0.012, "inputShadowDensity": 0.6,
                    "inputShadowOffset": CIVector(x: 0, y: -w * 0.008)])
            default: break
            }
            guard let out else { photo(e < 0.5 ? a : b, ctx); return }
            put(out.cropped(to: full).composited(over: B), ctx)
        }

        /// Twist, pixel or zoom-blur on the way out of one photo and into the next.
        private func warp(_ style: Style, _ a: Int, _ b: Int, _ e: Double, _ ctx: CGContext) {
            guard let A = ciCanvas(a), let B = ciCanvas(b) else { return }
            let w = size.width, c = CIVector(x: size.width / 2, y: size.height / 2)
            let peak = CGFloat(sin(e * .pi))
            var out: CIImage
            switch style {
            case .swirl:
                let mix = A.applyingFilter("CIDissolveTransition", parameters: [kCIInputTargetImageKey: B, kCIInputTimeKey: e])
                out = mix.clampedToExtent().applyingFilter("CITwirlDistortion", parameters: [kCIInputCenterKey: c,
                    kCIInputRadiusKey: max(size.width, size.height) * 0.75, kCIInputAngleKey: 2.6 * .pi * peak])
            case .pixelate:
                let base = e < 0.5 ? A : B
                out = base.clampedToExtent().applyingFilter("CIPixellate", parameters: [kCIInputCenterKey: c, kCIInputScaleKey: max(1, w / 11 * peak)])
            default:   // whoosh
                func zoomed(_ img: CIImage, _ s: CGFloat, _ blur: CGFloat) -> CIImage {
                    let t = CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2).concatenating(CGAffineTransform(scaleX: s, y: s))
                        .concatenating(CGAffineTransform(translationX: size.width / 2, y: size.height / 2))
                    return img.transformed(by: t).clampedToExtent().applyingFilter("CIZoomBlur", parameters: [kCIInputCenterKey: c, "inputAmount": blur])
                }
                let p = CGFloat(e)
                let outA = zoomed(A, 1 + 0.6 * p, w * 0.07 * p)
                let inB = zoomed(B, 0.7 + 0.3 * p, w * 0.07 * (1 - p))
                let mixT = min(1, max(0, (e - 0.35) / 0.3))
                out = outA.applyingFilter("CIDissolveTransition", parameters: [kCIInputTargetImageKey: inB, kCIInputTimeKey: mixT])
            }
            put(out.cropped(to: full), ctx)
        }

        /// Digital glitch: colour channels split, slices jump sideways, then it cuts to the next photo.
        private func glitch(_ a: Int, _ b: Int, _ v: Double, frame i: Int, _ ctx: CGContext) {
            guard let base = ciCanvas(v < 0.5 ? a : b) else { return }
            let w = size.width, h = size.height, k = CGFloat(sin(v * .pi))
            func only(_ ch: Int) -> CIImage {
                base.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: ch == 0 ? 1 : 0, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: ch == 1 ? 1 : 0, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: ch == 2 ? 1 : 0, w: 0)])
            }
            let d = w * 0.03 * k
            let split = only(0).transformed(by: CGAffineTransform(translationX: d, y: 0))
                .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: only(1)])
                .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: only(2).transformed(by: CGAffineTransform(translationX: -d, y: 0))])
                .cropped(to: full)
            var out = split
            var rng = SeededRandom(seed: UInt64(i / 2 + 11) &* 2654435761)
            for _ in 0..<(1 + Int(9 * k)) {
                let y = CGFloat(rng.next()) * h, sh = CGFloat(rng.next(0.01, 0.07)) * h
                let dx = CGFloat(rng.next(-0.14, 0.14)) * w * k
                out = split.cropped(to: CGRect(x: 0, y: y, width: w, height: sh)).transformed(by: CGAffineTransform(translationX: dx, y: 0)).composited(over: out)
            }
            put(out, ctx)
        }

        /// The next photo opens through a growing circle or heart, with a soft bright rim.
        private func reveal(_ a: Int, _ b: Int, _ e: Double, heart: Bool, _ ctx: CGContext) {
            photo(a, ctx)
            let r = CGFloat(e) * hypot(size.width, size.height) * (heart ? 0.95 : 0.55)
            guard r > 1 else { return }
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let path: CGPath
            if heart {
                let m = CGMutablePath()
                func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: c.x + x * r, y: c.y + y * r) }
                m.move(to: p(0, -0.85))
                m.addCurve(to: p(-1, 0.25), control1: p(-0.5, -0.45), control2: p(-1, -0.15))
                m.addCurve(to: p(0, 0.55), control1: p(-1, 0.85), control2: p(-0.25, 0.95))
                m.addCurve(to: p(1, 0.25), control1: p(0.25, 0.95), control2: p(1, 0.85))
                m.addCurve(to: p(0, -0.85), control1: p(1, -0.15), control2: p(0.5, -0.45))
                m.closeSubpath()
                path = m
            } else {
                path = CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), transform: nil)
            }
            ctx.saveGState(); ctx.addPath(path); ctx.clip()
            photo(b, ctx)
            ctx.restoreGState()
            ctx.saveGState()
            ctx.addPath(path)
            ctx.setStrokeColor(UIColor(white: 1, alpha: 0.85 * (1 - CGFloat(e))).cgColor)
            ctx.setLineWidth(size.width * 0.012)
            ctx.setShadow(offset: .zero, blur: size.width * 0.03, color: UIColor(white: 1, alpha: 0.9).cgColor)
            ctx.strokePath()
            ctx.restoreGState()
        }

        /// A warm film light leak washes across as one photo dissolves into the next.
        private func lightLeak(_ a: Int, _ b: Int, _ e: Double, _ ctx: CGContext) {
            photo(a, ctx); photo(b, ctx, alpha: CGFloat(e))
            let k = CGFloat(sin(e * .pi))
            let x = size.width * (-0.2 + 1.4 * CGFloat(e))
            let cols = [UIColor(red: 1, green: 0.62, blue: 0.2, alpha: 0.95 * k).cgColor,
                        UIColor(red: 1, green: 0.3, blue: 0.35, alpha: 0.55 * k).cgColor,
                        UIColor(red: 1, green: 0.2, blue: 0.4, alpha: 0).cgColor] as CFArray
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 0.45, 1]) else { return }
            ctx.saveGState(); ctx.setBlendMode(.screen)
            ctx.drawRadialGradient(g, startCenter: CGPoint(x: x, y: size.height * 0.62), startRadius: 0,
                                   endCenter: CGPoint(x: x, y: size.height * 0.62), endRadius: max(size.width, size.height) * 0.7, options: [])
            ctx.restoreGState()
        }

        private func boomerang(_ i: Int, _ tl: Timeline, _ ctx: CGContext) {
            let n = tl.count
            let per = max(1, Int((tl.hold * Double(tl.fps)).rounded()))
            let order = Array(0..<n) + (n > 2 ? Array((1...(n - 2)).reversed()) : [])
            let k = order[(i / per) % order.count]
            photo(k, ctx)
            let next = order[((i / per) + 1) % order.count]
            _ = canvas(next)
            evict(keep: [k, next])
        }

        private func filmStrip(_ i: Int, _ tl: Timeline, _ ctx: CGContext) {
            let ph = Animate.phase(frame: i, in: tl)
            let pos: CGFloat
            switch ph {
            case .hold(let k, _): pos = CGFloat(k)
            case .move(let k, let v): pos = CGFloat(k) + CGFloat(Animate.easeInOut(v))
            }
            let cur = min(tl.count - 1, Int(pos.rounded()))
            // Backdrop: the current photo, blurred and dimmed.
            if let bg = backdrop(cur) { ctx.draw(bg, in: full) }
            ctx.setFillColor(UIColor(white: 0, alpha: 0.35).cgColor); ctx.fill(full)
            let bandH = min(size.height * 0.46, size.width * 0.78)
            let frameH = bandH * 0.74, frameW = frameH * 1.25
            let gap = frameW * 0.08, pitch = frameW + gap
            let band = CGRect(x: 0, y: (size.height - bandH) / 2, width: size.width, height: bandH)
            ctx.setFillColor(UIColor(white: 0.04, alpha: 1).cgColor); ctx.fill(band)
            // Sprocket holes move with the film.
            let hole = CGSize(width: bandH * 0.05, height: bandH * 0.07), holePitch = hole.width * 2.2
            let shift = (pos * pitch).truncatingRemainder(dividingBy: holePitch)
            ctx.setFillColor(UIColor(white: 0.85, alpha: 0.9).cgColor)
            var x = -shift - holePitch
            while x < size.width + holePitch {
                for y in [band.minY + bandH * 0.04, band.maxY - bandH * 0.04 - hole.height] {
                    ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: hole.width, height: hole.height),
                                       cornerWidth: hole.width * 0.25, cornerHeight: hole.width * 0.25, transform: nil))
                }
                x += holePitch
            }
            ctx.fillPath()
            for j in 0..<tl.count {
                let cx = size.width / 2 + (CGFloat(j) - pos) * pitch
                guard cx > -pitch, cx < size.width + pitch else { continue }
                let r = CGRect(x: cx - frameW / 2, y: band.midY - frameH / 2, width: frameW, height: frameH)
                if let img = cardPhoto(j, aspect: frameW / frameH) { ctx.draw(img, in: r) }
            }
            evict(keep: [cur, cur + 1, cur - 1])
        }

        private func polaroid(_ i: Int, _ tl: Timeline, _ ctx: CGContext) {
            let t = Double(i) / Double(tl.fps), seg = tl.hold + tl.trans
            // Table surface: a warm dark gradient.
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor(red: 0.20, green: 0.17, blue: 0.15, alpha: 1).cgColor,
                                           UIColor(red: 0.09, green: 0.08, blue: 0.07, alpha: 1).cgColor] as CFArray,
                                  locations: [0, 1]) {
                ctx.drawRadialGradient(g, startCenter: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: 0,
                                       endCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                                       endRadius: max(size.width, size.height) * 0.75, options: [.drawsAfterEndLocation])
            }
            let landing = 0.55 * tl.pace
            let shown = min(tl.count - 1, Int(t / max(seg, 0.001)) + ((t.truncatingRemainder(dividingBy: max(seg, 0.001)) > tl.hold && tl.count > 1) ? 1 : 0))
            let first = max(0, shown - 5)
            for j in first...shown {
                let arrive = j == 0 ? 0 : Double(j) * seg - tl.trans
                let a = min(1, max(0, (t - arrive) / landing))
                guard a > 0 || j == 0 else { continue }
                let e = CGFloat(Animate.easeOut(j == 0 ? min(1, t / landing) : a))
                guard let card = card(j) else { continue }
                let cw = min(size.width, size.height) * 0.74
                let ch = cw * CGFloat(card.height) / CGFloat(card.width)
                var rng = SeededRandom(seed: UInt64(j + 1) * 2654435761)
                let rot = CGFloat(rng.next(-0.14, 0.14))
                let off = CGPoint(x: CGFloat(rng.next(-0.07, 0.07)) * size.width, y: CGFloat(rng.next(-0.05, 0.05)) * size.height)
                let s = 1.6 - 0.6 * e
                ctx.saveGState()
                ctx.setAlpha(min(1, e * 1.4))
                ctx.translateBy(x: size.width / 2 + off.x, y: size.height / 2 + off.y)
                ctx.rotate(by: rot * (0.4 + 0.6 * e))
                ctx.scaleBy(x: s, y: s)
                ctx.setShadow(offset: CGSize(width: 0, height: -cw * 0.02), blur: cw * 0.06, color: UIColor(white: 0, alpha: 0.55).cgColor)
                ctx.draw(card, in: CGRect(x: -cw / 2, y: -ch / 2, width: cw, height: ch))
                ctx.restoreGState()
            }
            cards = cards.filter { $0.key >= first - 1 && $0.key <= shown + 1 }
            evict(keep: [])
        }

        // Drawing helpers

        private func photo(_ j: Int, _ ctx: CGContext, scale: CGFloat = 1, dx: CGFloat = 0, dy: CGFloat = 0, alpha: CGFloat = 1) {
            let w = size.width * scale, h = size.height * scale
            let rect = CGRect(x: (size.width - w) / 2 + dx, y: (size.height - h) / 2 + dy, width: w, height: h)
            ctx.saveGState(); ctx.setAlpha(alpha)
            drawCanvas(j, in: rect, ctx: ctx)
            ctx.restoreGState()
        }

        private func drawCanvas(_ j: Int, in rect: CGRect, ctx: CGContext) {
            guard let img = canvas(j) else { return }
            ctx.draw(img, in: rect)
        }

        /// Photo `j` laid out on the full canvas (filled, or fitted over a blurred backdrop).
        func canvas(_ j: Int) -> CGImage? {
            guard images.indices.contains(j) else { return nil }
            if let c = canvases[j] { return c }
            let src = images[j].normalizedUp()
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
            let img = UIGraphicsImageRenderer(size: size, format: fmt).image { c in
                UIColor(white: 0.06, alpha: 1).setFill(); c.fill(full)
                if framing == .fill {
                    let crop = VideoFormat.fillCrop(source: src.size, target: size)
                    let k = size.width / crop.width
                    src.draw(in: CGRect(x: -crop.minX * k, y: -crop.minY * k, width: src.size.width * k, height: src.size.height * k))
                } else {
                    if let bg = blurred(src) { UIImage(cgImage: bg).draw(in: aspectFillRect(src.size, in: size)) }
                    UIColor(white: 0, alpha: 0.25).setFill(); c.fill(full)
                    src.draw(in: VideoFormat.fitRect(source: src.size, target: size))
                }
            }.cgImage
            canvases[j] = img
            return img
        }

        private var backs: [Int: CGImage] = [:]
        private func backdrop(_ j: Int) -> CGImage? {
            if let b = backs[j] { return b }
            if backs.count > 3 { backs = [:] }
            let made = makeBackdrop(j)
            backs[j] = made
            return made
        }
        private func makeBackdrop(_ j: Int) -> CGImage? {
            guard images.indices.contains(j) else { return nil }
            let src = images[j].normalizedUp()
            guard let b = blurred(src) else { return nil }
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
            return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
                UIImage(cgImage: b).draw(in: aspectFillRect(src.size, in: size))
            }.cgImage
        }

        /// A photo cropped to `aspect`, sized for a film frame.
        private func cardPhoto(_ j: Int, aspect: CGFloat) -> CGImage? {
            if let c = cards[j] { return c }
            guard images.indices.contains(j) else { return nil }
            let src = images[j].normalizedUp()
            let h = min(size.height, size.width) * 0.6, w = h * aspect
            let target = CGSize(width: w.rounded(), height: h.rounded())
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
            let img = UIGraphicsImageRenderer(size: target, format: fmt).image { _ in
                src.draw(in: aspectFillRect(src.size, in: target))
            }.cgImage
            cards[j] = img
            return img
        }

        /// A white-bordered print of photo `j` (thicker border at the bottom, like an instant photo).
        private func card(_ j: Int) -> CGImage? {
            if let c = cards[j] { return c }
            guard images.indices.contains(j) else { return nil }
            let src = images[j].normalizedUp()
            let cw = (min(size.width, size.height) * 0.74).rounded()
            let border = cw * 0.05, photoSide = cw - border * 2
            let target = CGSize(width: cw, height: (border + photoSide + border * 3.6).rounded())
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
            let img = UIGraphicsImageRenderer(size: target, format: fmt).image { c in
                UIColor(white: 0.97, alpha: 1).setFill(); c.fill(CGRect(origin: .zero, size: target))
                let pr = CGRect(x: border, y: border, width: photoSide, height: photoSide)
                c.cgContext.saveGState(); c.cgContext.clip(to: pr)
                src.draw(in: aspectFillRect(src.size, in: pr.size).offsetBy(dx: pr.minX, dy: pr.minY))
                c.cgContext.restoreGState()
            }.cgImage
            cards[j] = img
            return img
        }

        private func blurred(_ src: UIImage) -> CGImage? {
            guard let cg = src.cgImage else { return nil }
            let small = CIImage(cgImage: cg).transformed(by: CGAffineTransform(scaleX: 0.12, y: 0.12))
            let out = small.clampedToExtent().applyingGaussianBlur(sigma: 6).cropped(to: small.extent)
            return ci.createCGImage(out, from: small.extent)
        }

        private func aspectFillRect(_ s: CGSize, in target: CGSize) -> CGRect {
            let k = max(target.width / max(s.width, 1), target.height / max(s.height, 1))
            let w = s.width * k, h = s.height * k
            return CGRect(x: (target.width - w) / 2, y: (target.height - h) / 2, width: w, height: h)
        }

        private func prepareAhead(_ ph: Phase) {
            let k: Int
            switch ph { case .hold(let a, _): k = a; case .move(let a, _): k = a }
            evict(keep: [k, k + 1])
        }

        private func evict(keep: Set<Int>) {
            if canvases.count > 3 { canvases = canvases.filter { keep.contains($0.key) } }
        }
    }

    /// The page-curl angle that lifts the RIGHT edge first, so pages turn like a book's. Measured once on a tiny
    /// test picture instead of assumed, so the direction is right on every iOS version.
    static let curlAngle: CGFloat = {
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        let ext = CGRect(x: 0, y: 0, width: 64, height: 32)
        let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: ext)
        let blue = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: ext)
        for a in [CGFloat.pi, 0, -CGFloat.pi / 2, CGFloat.pi / 2] {
            guard let f = CIFilter(name: "CIPageCurlWithShadowTransition") else { break }
            f.setValue(red, forKey: kCIInputImageKey); f.setValue(blue, forKey: kCIInputTargetImageKey)
            f.setValue(red, forKey: "inputBacksideImage")
            f.setValue(CIVector(cgRect: ext), forKey: kCIInputExtentKey)
            f.setValue(0.3, forKey: kCIInputTimeKey); f.setValue(a, forKey: kCIInputAngleKey); f.setValue(4, forKey: kCIInputRadiusKey)
            guard let out = f.outputImage?.composited(over: blue).cropped(to: ext) else { continue }
            var px = [UInt8](repeating: 0, count: 64 * 32 * 4)
            ctx.render(out, toBitmap: &px, rowBytes: 64 * 4, bounds: ext, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            func isBlue(_ x: Int) -> Bool { let o = (16 * 64 + x) * 4; return Int(px[o + 2]) > Int(px[o]) + 60 }
            if isBlue(62) && !isBlue(2) { return a }
        }
        return .pi
    }()

    static func easeInOut(_ t: Double) -> Double { t * t * (3 - 2 * t) }
    static func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
}

extension Animate.Timeline {
    /// Pace multiplier recovered from the hold length (used by styles that animate within a hold).
    var pace: Double { max(0.5, min(1.6, hold / 2.0)) }
}

/// Tiny deterministic random numbers, so each Polaroid lands the same way in the preview and the final.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000
    }
    mutating func next(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }
}

// MARK: - Looks & printable flipbook

extension Animate {
    /// A drawn look applied to every photo before animating (the "sketch / comic feed").
    enum Look: String, CaseIterable, Identifiable {
        case original, comic, sketch, noir, pop
        var id: String { rawValue }
        var title: String {
            switch self {
            case .original: return "Original"
            case .comic: return "Comic"
            case .sketch: return "Pencil"
            case .noir: return "Noir"
            case .pop: return "Pop art"
            }
        }
        /// PixelArt style id, nil for the photo as-is.
        var style: String? { self == .original ? nil : rawValue }
    }

    static func applyLook(_ look: Look, to images: [UIImage]) -> [UIImage] {
        guard let style = look.style else { return images }
        return images.map { ChainFun.art($0, style: style, long: 1440) ?? $0 }
    }

    /// A printable flipbook: the animation's frames, numbered, 8 to an A4/Letter page, each with a blank
    /// staple margin on the left and light cut lines. Print, cut, stack in order, staple, flick.
    static func flipbookPDF(_ images: [UIImage], settings: Settings, frames wanted: Int = 32) -> Data? {
        guard !images.isEmpty else { return nil }
        let tl = timeline(count: images.count, settings: settings, fps: 12)
        let count = min(max(8, wanted), tl.frameCount)
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)          // A4 in points (Letter crops a hair)
        let margin: CGFloat = 28, cols = 2, rows = 4
        let cellW = (page.width - margin * 2) / CGFloat(cols), cellH = (page.height - margin * 2) / CGFloat(rows)
        let staple = cellW * 0.22
        let frameW = cellW - staple - 10, frameH = min(cellH - 14, frameW * settings.format.size.height / settings.format.size.width)
        let scale = min(1, 600 / max(settings.format.size.width, settings.format.size.height))
        let r = UIGraphicsPDFRenderer(bounds: page)
        return r.pdfData { ctx in
            for i in 0..<count {
                if i % (cols * rows) == 0 { ctx.beginPage() }
                let slot = i % (cols * rows)
                let cell = CGRect(x: margin + CGFloat(slot % cols) * cellW, y: margin + CGFloat(slot / cols) * cellH, width: cellW, height: cellH)
                let at = Double(i) / Double(max(1, count - 1))
                if let img = still(images, settings: settings, at: at, scale: scale) {
                    img.draw(in: CGRect(x: cell.minX + staple, y: cell.minY + (cellH - frameH) / 2, width: frameW, height: frameH))
                }
                let n = "\(i + 1)" as NSString
                n.draw(at: CGPoint(x: cell.minX + 6, y: cell.minY + 6),
                       withAttributes: [.font: UIFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: UIColor.gray])
                UIColor(white: 0.75, alpha: 1).setStroke()
                let cut = UIBezierPath(rect: cell); cut.lineWidth = 0.5
                cut.setLineDash([3, 3], count: 2, phase: 0); cut.stroke()
            }
        }
    }
}
