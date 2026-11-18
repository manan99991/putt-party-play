import AVFoundation
import CoreImage
import UIKit

/// Animate — photos in, a polished, post-ready video out. Nine styles, every one drawn with plain Core
/// Graphics and encoded with the phone's own H.264 encoder, so it works on every iPhone, offline, in any
/// country. Frames are streamed straight into the encoder (constant memory: a 30-second 1080×1920 video
/// never holds more than a couple of frames), and photos are prepared lazily, a few at a time.
/// Output is sized to a real platform format (VideoFormat) — Reels/TikTok/Shorts, Story, Square,
/// Portrait or YouTube — either filling the frame or fitting the whole photo over a soft blurred backdrop.
enum Animate {

    enum Style: String, CaseIterable, Identifiable {
        case kenBurns, crossfade, slide, zoomPulse, polaroid, cube, filmStrip, flipbook, boomerang
        var id: String { rawValue }
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
            case .flipbook: return "Pages flick like a flipbook"
            case .boomerang: return "Back-and-forth loop — great for bursts"
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
        let hold = baseHold * f
        let trans: Double
        switch settings.style {
        case .zoomPulse: trans = 0.25 * f
        case .flipbook: trans = 0.35 * f
        case .crossfade, .kenBurns: trans = 0.7 * f
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

    /// Render the video. `scale` < 1 makes a quick low-resolution draft for the live preview.
    static func render(_ images: [UIImage], settings: Settings, scale: CGFloat = 1, fps: Int = 30,
                       progress: ((Double) -> Void)? = nil) async -> URL? {
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
                    flip(k, k + 1, e, ctx)
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

        private func cube(_ a: Int, _ b: Int, _ e: Double, _ ctx: CGContext) {
            let w = size.width, h = size.height, p = CGFloat(e)
            let edge = w * (1 - p)
            let bulge = 0.06 * sin(.pi * p)                               // faces shrink a touch mid-turn
            if edge > 1 {
                let rect = CGRect(x: 0, y: h * bulge / 2, width: edge, height: h * (1 - bulge))
                drawCanvas(a, in: rect, ctx: ctx)
                ctx.setFillColor(UIColor(white: 0, alpha: 0.55 * p).cgColor); ctx.fill(rect)
            }
            if w - edge > 1 {
                let rect = CGRect(x: edge, y: h * bulge / 2, width: w - edge, height: h * (1 - bulge))
                drawCanvas(b, in: rect, ctx: ctx)
                ctx.setFillColor(UIColor(white: 0, alpha: 0.55 * (1 - p)).cgColor); ctx.fill(rect)
            }
        }

        private func flip(_ a: Int, _ b: Int, _ e: Double, _ ctx: CGContext) {
            photo(b, ctx)
            let w = size.width * (1 - CGFloat(e))
            guard w > 1 else { return }
            let rect = CGRect(x: 0, y: 0, width: w, height: size.height)
            ctx.saveGState(); ctx.clip(to: rect)
            drawCanvas(a, in: rect, ctx: ctx)
            let shadowW = min(size.width * 0.05, w)
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor(white: 0, alpha: 0).cgColor, UIColor(white: 0, alpha: 0.55).cgColor] as CFArray,
                                  locations: [0, 1]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: w - shadowW, y: 0), end: CGPoint(x: w, y: 0), options: [])
            }
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

        private func backdrop(_ j: Int) -> CGImage? {
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
