import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Boomerangs that make people laugh or go "how?": the liveliest moment of the video (not just its first seconds),
/// played with a twist — a snappy back-and-forth, a record-scratch stutter, a slow-mo slingshot that whips back, a
/// dramatic triple zoom onto the face, a ghostly echo trail, or mirror twins. Each style is a pure plan of beats
/// (which frame, how long, how far zoomed, shaken or not), so it's unit-tested; the frames are taken from the video
/// once and kept, so trying another style is instant.
enum Boomerang {
    struct Style: Identifiable, Equatable {
        let id: String, name: String, emoji: String, line: String
    }

    static let styles: [Style] = [
        Style(id: "snap", name: "Snap", emoji: "⚡️", line: "Quick there-and-back with a punch at the turn"),
        Style(id: "stutter", name: "Stutter", emoji: "🔁", line: "Gets stuck on the best bit — again, again, again"),
        Style(id: "slingshot", name: "Slingshot", emoji: "🏹", line: "Slow-mo out, then whips back at full speed"),
        Style(id: "dramatic", name: "Dramatic zoom", emoji: "😱", line: "Three sudden zooms onto the face"),
        Style(id: "echo", name: "Echo trail", emoji: "👻", line: "Every move leaves ghosts behind"),
        Style(id: "twins", name: "Mirror twins", emoji: "🪞", line: "One half copies the other"),
        Style(id: "reverse", name: "Backwards", emoji: "⏪", line: "Plays it in reverse, for ever"),
    ]

    /// The saved setting as a style: older chains saved "boomerang", which is the classic Snap.
    static func style(_ setting: String?) -> Style {
        styles.first { $0.id == setting } ?? styles[0]
    }

    /// One frame of the finished loop.
    struct Beat: Equatable {
        var frame: Int
        /// Seconds on screen. Never under 0.02: most players turn anything faster into a slow 0.1.
        var delay: Double
        var zoom: Double = 1
        /// Nudged sideways and up/down this frame (a camera shake).
        var shake = false
        /// How many earlier frames show through as ghosts.
        var ghosts = 0
    }

    /// The beats for `style` over `n` frames taken from the moment. Pure, so it's unit-tested.
    static func plan(_ style: String?, count n: Int) -> [Beat] {
        guard n > 0 else { return [] }
        guard n > 2 else { return (0..<n).map { Beat(frame: $0, delay: 0.08) } }
        let last = n - 1
        let fwd = Array(0...last), back = Array((1..<last).reversed())
        switch Self.style(style).id {
        case "stutter":
            // Forwards to the best bit, then that bit three more times like a scratched record, then on and back.
            let a = Int(Double(n) * 0.4), b = max(a + 3, Int(Double(n) * 0.7))
            var out = (0..<b).map { Beat(frame: $0, delay: 0.04) }
            for rep in 0..<3 {
                out += (a..<b).map { Beat(frame: $0, delay: 0.03, zoom: 1.06 + 0.04 * Double(rep), shake: $0 == a) }
            }
            out += (b...last).map { Beat(frame: $0, delay: 0.04) }
            out += back.map { Beat(frame: $0, delay: 0.025) }
            return out
        case "slingshot":
            // Out in slow motion, creeping in; a held breath; then everything snaps back at once.
            var out = fwd.map { i in Beat(frame: i, delay: 0.08, zoom: 1 + 0.15 * Double(i) / Double(last)) }
            out[out.count - 1].delay = 0.4
            let whip = Array(stride(from: last - 2, through: 1, by: -2))
            out += whip.enumerated().map { k, i in
                Beat(frame: i, delay: 0.02, zoom: max(1, 1.15 - 0.15 * Double(k + 1) / Double(max(1, whip.count))), shake: k < 3)
            }
            return out
        case "dramatic":
            // Forwards, then three sudden zooms onto the face (each held, each shaking), then a snap back.
            var out = fwd.map { Beat(frame: $0, delay: 0.04) }
            for z in [1.4, 1.85, 2.4] {
                out.append(Beat(frame: last, delay: 0.06, zoom: z, shake: true))
                out.append(Beat(frame: last, delay: 0.38, zoom: z))
            }
            out += stride(from: last - 1, through: 1, by: -2).map { Beat(frame: $0, delay: 0.025) }
            return out
        case "echo":
            return fwd.map { Beat(frame: $0, delay: 0.045, ghosts: 4) } + back.map { Beat(frame: $0, delay: 0.045, ghosts: 4) }
        case "twins":
            return fwd.map { Beat(frame: $0, delay: 0.04) } + back.map { Beat(frame: $0, delay: 0.04) }
        case "reverse":
            return fwd.reversed().map { Beat(frame: $0, delay: 0.05) }
        default:
            // Snap: about twice as fast as filmed, with a little punch-in and shake right at the turn.
            var out = fwd.map { Beat(frame: $0, delay: 0.03) }
            out[out.count - 1] = Beat(frame: last, delay: 0.09, zoom: 1.12, shake: true)
            if out.count > 2 { out[out.count - 2].zoom = 1.05 }
            out += back.enumerated().map { k, i in Beat(frame: i, delay: 0.03, zoom: k == 0 ? 1.05 : 1) }
            return out
        }
    }

    /// The frames of the liveliest moment, and where to zoom (a face, else where the movement is). Kept per video.
    struct Clip {
        let frames: [CGImage]
        /// 0…1 across, 0…1 up from the bottom (Core Graphics' way up).
        let focus: CGPoint
    }

    private static var clips: [URL: Clip] = [:]
    private static let lock = NSLock()

    /// How long a boomerang's moment is, and how many frames a second are taken from it.
    static let momentLength = 1.6
    static let framesPerSecond = 18.0

    static func clip(_ url: URL) async -> Clip? {
        lock.lock(); let kept = clips[url]; lock.unlock()
        if let kept { return kept }
        let asset = AVURLAsset(url: url)
        guard let d = try? await asset.load(.duration).seconds, d > 0 else { return nil }
        let length = min(momentLength, max(0.2, d))
        let start = await VideoJoin.busiestMoment(url, length: length)?.lowerBound ?? 0
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter = .zero
        // Bigger than the GIF, so a zoom stays sharp.
        gen.maximumSize = CGSize(width: 760, height: 760)
        let count = max(2, min(36, Int(length * framesPerSecond)))
        var frames: [CGImage] = []
        for i in 0..<count {
            let t = start + Double(i) / Double(count) * length
            if let (cg, _) = try? await gen.image(at: CMTime(seconds: min(t, max(0, d - 0.02)), preferredTimescale: 600)) { frames.append(cg) }
        }
        guard frames.count >= 2 else { return nil }
        let c = Clip(frames: frames, focus: focus(frames))
        lock.lock(); clips[url] = c; lock.unlock()
        return c
    }

    /// The biggest face in the middle frame; with none, the middle of where things moved.
    static func focus(_ frames: [CGImage]) -> CGPoint {
        let mid = frames[frames.count / 2]
        let req = VNDetectFaceRectanglesRequest()
        if (try? VNImageRequestHandler(cgImage: mid).perform([req])) != nil,
           let f = (req.results ?? []).max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
            return CGPoint(x: f.boundingBox.midX, y: f.boundingBox.midY)
        }
        return motionCenter(frames)
    }

    /// The middle of everything that changed between the first and last frames (0…1, up from the bottom).
    static func motionCenter(_ frames: [CGImage]) -> CGPoint {
        guard let a = frames.first, let b = frames.last else { return CGPoint(x: 0.5, y: 0.5) }
        let side = 48
        func small(_ cg: CGImage) -> [UInt8] {
            var px = [UInt8](repeating: 0, count: side * side)
            guard let ctx = CGContext(data: &px, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0) else { return [] }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return px
        }
        return weightedCenter(small(a), small(b), side: side)
    }

    /// Where two small grey pictures differ, on average (0…1, up from the bottom). The middle when they don't. Pure.
    static func weightedCenter(_ a: [UInt8], _ b: [UInt8], side: Int) -> CGPoint {
        guard a.count == side * side, b.count == a.count else { return CGPoint(x: 0.5, y: 0.5) }
        var sx = 0.0, sy = 0.0, sw = 0.0
        for y in 0..<side {
            for x in 0..<side {
                let k = y * side + x
                let w = Double(abs(Int(a[k]) - Int(b[k])))
                guard w > 12 else { continue }
                // Row 0 of the bitmap is the top of the picture.
                sx += w * (Double(x) + 0.5) / Double(side); sy += w * (1 - (Double(y) + 0.5) / Double(side)); sw += w
            }
        }
        return sw > 0 ? CGPoint(x: sx / sw, y: sy / sw) : CGPoint(x: 0.5, y: 0.5)
    }

    /// Where a `w`×`h` frame drawn `zoom` times bigger goes so `focus` moves toward the middle without showing an
    /// edge. Pure, so it's unit-tested.
    static func placement(w: Double, h: Double, zoom: Double, focus: CGPoint) -> CGRect {
        let z = max(1, zoom)
        func axis(_ size: Double, _ f: Double) -> Double { min(0, max(size - size * z, size / 2 - f * size * z)) }
        return CGRect(x: axis(w, focus.x), y: axis(h, focus.y), width: w * z, height: h * z)
    }

    private static let shakes: [CGPoint] = [CGPoint(x: 7, y: -5), CGPoint(x: -6, y: 6), CGPoint(x: 5, y: 4), CGPoint(x: -7, y: -4)]

    /// The finished loop as a GIF, `side` pixels along its long edge.
    static func gif(_ clip: Clip, style: String?, side: CGFloat = 440) -> URL? {
        let beats = plan(style, count: clip.frames.count)
        guard let first = clip.frames.first, !beats.isEmpty else { return nil }
        let s = side / CGFloat(max(first.width, first.height))
        let w = Int((CGFloat(first.width) * min(1, s)).rounded()), h = Int((CGFloat(first.height) * min(1, s)).rounded())
        guard w > 0, h > 0 else { return nil }
        let twins = Self.style(style).id == "twins"
        // Mirror twins: the face sits on the fold, so it becomes one symmetrical face.
        let twinZoom = twins ? min(1.7, 1 + 2 * abs(0.5 - Double(clip.focus.x))) : 1
        var images: [CGImage] = []
        for (n, beat) in beats.enumerated() {
            guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { continue }
            ctx.interpolationQuality = .high
            var zoom = max(beat.zoom, twinZoom)
            if beat.shake { zoom = max(zoom, 1.06) }
            var rect = placement(w: Double(w), h: Double(h), zoom: zoom, focus: clip.focus)
            if beat.shake {
                let p = shakes[n % shakes.count], k = CGFloat(w) / 400
                // Kept inside the slack the zoom leaves, so no edge ever shows.
                rect.origin.x = min(0, max(CGFloat(w) - rect.width, rect.origin.x + p.x * k))
                rect.origin.y = min(0, max(CGFloat(h) - rect.height, rect.origin.y + p.y * k))
            }
            ctx.draw(clip.frames[beat.frame], in: rect)
            if beat.ghosts > 0 {
                // Earlier frames of the loop, lighter parts only, fading the further back they are.
                ctx.setBlendMode(.lighten)
                for g in stride(from: beat.ghosts, through: 1, by: -1) {
                    let prev = beats[(n - g * 2 + beats.count * 4) % beats.count]
                    ctx.setAlpha(0.55 * CGFloat(beat.ghosts - g + 1) / CGFloat(beat.ghosts + 1))
                    ctx.draw(clip.frames[prev.frame], in: placement(w: Double(w), h: Double(h), zoom: prev.zoom, focus: clip.focus))
                }
                ctx.setAlpha(1); ctx.setBlendMode(.normal)
            }
            if twins, let drawn = ctx.makeImage(), let left = drawn.cropping(to: CGRect(x: 0, y: 0, width: w / 2, height: h)) {
                ctx.saveGState()
                ctx.translateBy(x: CGFloat(w), y: 0); ctx.scaleBy(x: -1, y: 1)
                ctx.draw(left, in: CGRect(x: 0, y: 0, width: CGFloat(w / 2), height: CGFloat(h)))
                ctx.restoreGState()
            }
            if let img = ctx.makeImage() { images.append(img) }
        }
        guard images.count == beats.count else { return nil }
        return tenzyWriteGIF(frames: images, delays: beats.map(\.delay))
    }

    /// From a video straight to a GIF.
    static func make(_ url: URL, style: String?) async -> URL? {
        guard let c = await clip(url) else { return nil }
        return gif(c, style: style)
    }
}

/// A looping GIF where every frame has its own time on screen (rounded to the hundredths GIFs store).
func tenzyWriteGIF(frames: [CGImage], delays: [Double]) -> URL? {
    guard !frames.isEmpty, frames.count == delays.count else { return nil }
    let url = VideoEngine.tempURL("gif")
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { return nil }
    CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary)
    for (f, d) in zip(frames, delays) {
        let t = max(0.02, (d * 100).rounded() / 100)
        let props = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: t, kCGImagePropertyGIFUnclampedDelayTime as String: t]] as CFDictionary
        CGImageDestinationAddImage(dest, f, props)
    }
    return CGImageDestinationFinalize(dest) ? url : nil
}
