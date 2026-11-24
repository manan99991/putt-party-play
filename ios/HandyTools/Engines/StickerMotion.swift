import UIKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Animated stickers (Manan, 24 Nov: "can they be animated too… static and animated… funny, quirky, beautiful").
/// The finished still sticker — its cut-out, edge, caption and all — moves on a see-through square: a squash-and-
/// stretch hop, a jelly wobble, a pop with a burst, a heartbeat with hearts floating up, a laughing shake, a flip, a
/// float with twinkles, a confetti party, a disco colour spin. Every move is a seamless loop (the frame after the last
/// is the first), drawn on the phone, and saved as an animated PNG (keeps the soft see-through edge; Messages plays
/// it) and a GIF (Photos and every chat app play it).
enum StickerMotion: String, CaseIterable, Identifiable {
    case bounce, jelly, pop, love, lol, flip, float, party, disco

    var id: String { rawValue }
    var title: String {
        switch self {
        case .bounce: return "Bounce"
        case .jelly: return "Jelly"
        case .pop: return "Pop"
        case .love: return "Love"
        case .lol: return "LOL"
        case .flip: return "Flip"
        case .float: return "Float"
        case .party: return "Party"
        case .disco: return "Disco"
        }
    }
    var icon: String {
        switch self {
        case .bounce: return "arrow.up.and.down"
        case .jelly: return "water.waves"
        case .pop: return "burst.fill"
        case .love: return "heart.fill"
        case .lol: return "face.smiling.inverse"
        case .flip: return "arrow.clockwise"
        case .float: return "sparkles"
        case .party: return "party.popper.fill"
        case .disco: return "paintpalette.fill"
        }
    }

    /// The square chat apps show stickers at.
    static let canvas: CGFloat = 512
    /// One loop: 24 frames at 16 a second — 1.5 s, smooth and small enough to send.
    static let frameCount = 24
    static let delay = 1.0 / 16.0

    // MARK: - Frames

    /// One loop of the move. `sticker` is the finished still sticker (see-through, any size).
    static func frames(_ sticker: UIImage, motion: StickerMotion, side: CGFloat = canvas, count: Int = frameCount) -> [UIImage] {
        guard sticker.size.width > 0, sticker.size.height > 0, count > 0 else { return [] }
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: fmt)
        // Room to move: hops need headroom; the rest sit in the middle.
        let hops = motion == .bounce || motion == .flip
        // A flip turns a whole circle, so its box must fit corner to corner (0.52 × √2 ≈ 0.74).
        let box = side * (motion == .flip ? 0.52 : hops ? 0.64 : motion == .party || motion == .love ? 0.68 : 0.72)
        let k = box / max(sticker.size.width, sticker.size.height)
        let size = CGSize(width: sticker.size.width * k, height: sticker.size.height * k)
        let base = hops ? side * 0.93 : side / 2 + size.height / 2
        let tinted: [UIImage] = motion == .disco ? discoFrames(sticker, count: count) : []
        let confetti = motion == .party ? Confetti.pieces(side: side) : []
        let hearts = motion == .love ? Floaters.hearts(side: side) : []

        return (0..<count).map { i in
            let p = CGFloat(i) / CGFloat(count)          // 0 ..< 1, so frame `count` would be frame 0 again
            let m = pose(motion, p)
            return renderer.image { c in
                let ctx = c.cgContext
                if hops { groundShadow(ctx, side: side, width: size.width, base: base, lift: m.lift) }
                if motion == .party { Confetti.draw(confetti.filter { !$0.front }, p: p, side: side, in: ctx) }
                if motion == .love { Floaters.draw(hearts.filter { !$0.front }, p: p, side: side, in: ctx) }
                if motion == .pop { burst(ctx, p: p, center: CGPoint(x: side / 2, y: base - size.height / 2), radius: box * 0.58) }
                ctx.saveGState()
                // To the feet; hops squash and stretch about the feet, as anything landing does…
                ctx.translateBy(x: side / 2 + m.dx * side, y: base - m.lift * side)
                if hops { ctx.scaleBy(x: m.sx, y: m.sy) }
                // …then turn and lean about the middle (a flip spins in place, it doesn't swing round its feet),
                ctx.translateBy(x: 0, y: -size.height / 2)
                ctx.rotate(by: m.angle)
                ctx.concatenate(CGAffineTransform(a: 1, b: 0, c: m.skew, d: 1, tx: 0, ty: 0))
                // and everything else breathes about the middle too.
                if !hops { ctx.scaleBy(x: m.sx, y: m.sy) }
                let art = motion == .disco ? tinted[i % max(1, tinted.count)] : sticker
                art.draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
                ctx.restoreGState()
                if motion == .party { Confetti.draw(confetti.filter(\.front), p: p, side: side, in: ctx) }
                if motion == .love { Floaters.draw(hearts.filter(\.front), p: p, side: side, in: ctx) }
                if motion == .float { twinkles(ctx, p: p, side: side, around: CGRect(x: (side - size.width) / 2, y: base - size.height, width: size.width, height: size.height)) }
                if motion == .lol { laughs(ctx, p: p, side: side) }
            }
        }
    }

    /// Where the sticker is at moment `p` (0 ..< 1) of the loop.
    struct Pose { var dx: CGFloat = 0; var lift: CGFloat = 0; var angle: CGFloat = 0; var sx: CGFloat = 1; var sy: CGFloat = 1; var skew: CGFloat = 0 }

    static func pose(_ motion: StickerMotion, _ p: CGFloat) -> Pose {
        let tau = CGFloat.pi * 2
        var m = Pose()
        switch motion {
        case .bounce:
            // Two hops a loop. Squash on landing, stretch on the way up, hang a little at the top.
            let q = (p * 2).truncatingRemainder(dividingBy: 1)
            let u = sin(.pi * q)                       // 0 on the ground, 1 at the top
            m.lift = 0.17 * pow(u, 0.85)
            let land = max(0, 0.22 - u) / 0.22         // only near the ground
            let rise = cos(.pi * q)                    // + going up, − coming down
            m.sx = 1 + 0.16 * land - 0.05 * u * abs(rise)
            m.sy = 1 - 0.16 * land + 0.07 * u * abs(rise)
        case .jelly:
            let w = sin(tau * p * 2)
            m.angle = 0.07 * sin(tau * p)
            m.skew = 0.14 * w
            m.sx = 1 + 0.06 * sin(tau * p * 2 + .pi / 2)
            m.sy = 1 - 0.06 * sin(tau * p * 2 + .pi / 2)
        case .pop:
            // In with a springy overshoot, a breath while it's up, then a quick shrink back to where it started.
            let s: CGFloat
            if p < 0.42 {
                let t = p / 0.42
                s = 1 - exp(-5.5 * t) * cos(13 * t) * 0.78
            } else if p < 0.86 {
                s = 1 + 0.025 * sin(tau * (p - 0.42) / 0.44)
            } else {
                let t = (p - 0.86) / 0.14
                s = 1 - 0.78 * t * t
            }
            m.sx = s; m.sy = s
            m.angle = p < 0.42 ? 0.10 * exp(-5 * p / 0.42) * sin(16 * p / 0.42) : 0
        case .love:
            // Lub-dub, twice a loop.
            let q = (p * 2).truncatingRemainder(dividingBy: 1)
            let beat = 0.09 * exp(-pow((q - 0.12) / 0.06, 2)) + 0.06 * exp(-pow((q - 0.32) / 0.06, 2))
            m.sx = 1 + beat; m.sy = 1 + beat
            m.angle = 0.03 * sin(tau * p)
        case .lol:
            // A fit of the giggles, then a breath, then again.
            let env = p < 0.6 ? sin(.pi * p / 0.6) : 0
            m.dx = 0.035 * env * sin(tau * p * 9)
            m.angle = 0.09 * env * sin(tau * p * 9 + 0.6) + (p >= 0.6 ? -0.04 * sin(.pi * (p - 0.6) / 0.4) : 0)
            m.sx = 1 + 0.03 * env; m.sy = 1 - 0.03 * env
        case .flip:
            // One big hop with a full turn in the air, squash on take-off and landing.
            let air = min(max((p - 0.14) / 0.72, 0), 1)
            let u = sin(.pi * air)
            m.lift = 0.22 * u
            let e = air * air * (3 - 2 * air)          // ease in-out
            m.angle = tau * e
            let ground = air == 0 || air == 1 ? 1 : max(0, 0.18 - u) / 0.18
            let crouch = p < 0.14 ? sin(.pi * p / 0.14) : p > 0.86 ? sin(.pi * (p - 0.86) / 0.14) : 0
            m.sx = 1 + 0.14 * crouch * ground
            m.sy = 1 - 0.14 * crouch * ground
        case .float:
            m.lift = 0.035 * sin(tau * p)
            m.angle = 0.035 * sin(tau * p + .pi / 3)
        case .party:
            let q = (p * 2).truncatingRemainder(dividingBy: 1)
            m.lift = 0.045 * sin(.pi * q)
            m.angle = 0.06 * sin(tau * p)
            m.sx = 1 + 0.03 * sin(tau * p * 2); m.sy = 1 - 0.03 * sin(tau * p * 2)
        case .disco:
            m.angle = 0.07 * sin(tau * p * 2)
            m.dx = 0.02 * sin(tau * p)
        }
        return m
    }

    // MARK: - Pieces

    private static func groundShadow(_ ctx: CGContext, side: CGFloat, width: CGFloat, base: CGFloat, lift: CGFloat) {
        let k = max(0.35, 1 - lift * 3.2)
        let w = width * 0.62 * k, h = side * 0.035 * k
        ctx.saveGState()
        ctx.setFillColor(UIColor(white: 0, alpha: 0.16 * k).cgColor)
        ctx.fillEllipse(in: CGRect(x: side / 2 - w / 2, y: base - h / 2, width: w, height: h))
        ctx.restoreGState()
    }

    /// Pop: eight short rays fly out as it lands.
    private static func burst(_ ctx: CGContext, p: CGFloat, center c: CGPoint, radius r: CGFloat) {
        guard p > 0.04, p < 0.34 else { return }
        let t = (p - 0.04) / 0.30
        let colors: [UIColor] = [.systemYellow, .systemPink, .systemTeal, .systemOrange]
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineWidth(r * 0.06 * (1 - t))
        for k in 0..<8 {
            let a = CGFloat(k) / 8 * .pi * 2 + .pi / 8
            let r0 = r * (0.7 + 0.2 * t), r1 = r * (0.82 + 0.25 * t)
            ctx.setStrokeColor(colors[k % colors.count].withAlphaComponent(1 - t * 0.6).cgColor)
            ctx.move(to: CGPoint(x: c.x + cos(a) * r0, y: c.y + sin(a) * r0))
            ctx.addLine(to: CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    /// Float: four-point stars that twinkle in turn around the sticker.
    private static func twinkles(_ ctx: CGContext, p: CGFloat, side: CGFloat, around r: CGRect) {
        let spots: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(-0.06, 0.12, 0.09, 0), (1.04, 0.05, 0.07, 0.33), (1.08, 0.62, 0.08, 0.66),
                                                             (-0.08, 0.74, 0.06, 0.5), (0.5, -0.1, 0.06, 0.17), (0.86, 1.02, 0.05, 0.83)]
        for (x, y, s, ph) in spots {
            let v = max(0, sin(.pi * 2 * (p + ph)))
            guard v > 0.02 else { continue }
            let size = side * s * (0.4 + 0.6 * v)
            let c = CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: size * 0.6, color: UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 0.9 * v).cgColor)
            ctx.setFillColor(UIColor(red: 1, green: 0.95, blue: 0.75, alpha: v).cgColor)
            ctx.addPath(star(c, size))
            ctx.fillPath()
            ctx.restoreGState()
        }
    }

    static func star(_ c: CGPoint, _ size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let r = size / 2, w = size * 0.14
        path.move(to: CGPoint(x: c.x, y: c.y - r))
        path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + w, y: c.y - w))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + w, y: c.y + w))
        path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - w, y: c.y + w))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - w, y: c.y - w))
        path.closeSubpath()
        return path
    }

    /// LOL: "HA" bubbles pop up on either side while it laughs.
    private static func laughs(_ ctx: CGContext, p: CGFloat, side: CGFloat) {
        let spots: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(0.13, 0.16, 0.02, -0.25), (0.82, 0.12, 0.16, 0.2), (0.86, 0.42, 0.3, 0.15)]
        let base = UIFont.systemFont(ofSize: side * 0.1, weight: .black)
        let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: side * 0.1) } ?? base
        for (x, y, start, tilt) in spots {
            let t = (p - start) / 0.32
            guard t > 0, t < 1 else { continue }
            let s = t < 0.25 ? t / 0.25 * 1.15 : 1.15 - 0.15 * min(1, (t - 0.25) / 0.2)
            let alpha = t > 0.8 ? (1 - t) / 0.2 : 1
            let text = "HA" as NSString
            let sz = text.size(withAttributes: [.font: font])
            ctx.saveGState()
            ctx.translateBy(x: side * x, y: side * y - t * side * 0.04)
            ctx.rotate(by: tilt)
            ctx.scaleBy(x: s, y: s)
            ctx.setAlpha(alpha)
            let at = CGPoint(x: -sz.width / 2, y: -sz.height / 2)
            text.draw(at: at, withAttributes: [.font: font, .strokeColor: UIColor(white: 0.08, alpha: 1), .strokeWidth: 16, .foregroundColor: UIColor(white: 0.08, alpha: 1)])
            text.draw(at: at, withAttributes: [.font: font, .foregroundColor: UIColor(red: 1, green: 0.84, blue: 0.1, alpha: 1)])
            ctx.restoreGState()
        }
    }

    /// Disco: the whole sticker's colours turn once round the wheel over the loop.
    private static func discoFrames(_ sticker: UIImage, count: Int) -> [UIImage] {
        guard let cg = sticker.cgImage else { return Array(repeating: sticker, count: count) }
        let input = CIImage(cgImage: cg)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        return (0..<count).map { i in
            let f = CIFilter(name: "CIHueAdjust")
            f?.setValue(input, forKey: kCIInputImageKey)
            f?.setValue(Double(i) / Double(count) * .pi * 2, forKey: kCIInputAngleKey)
            guard let out = f?.outputImage, let made = context.createCGImage(out, from: input.extent) else { return sticker }
            return UIImage(cgImage: made)
        }
    }

    /// A tiny repeatable random, so the confetti and hearts fall the same way every time.
    struct Seeded {
        private var s: UInt64
        init(_ seed: UInt64) { s = seed }
        mutating func next() -> CGFloat {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((s >> 33) % 10_000) / 10_000
        }
    }

    enum Confetti {
        struct Piece { let x: CGFloat; let phase: CGFloat; let speed: CGFloat; let spin: CGFloat; let w: CGFloat; let color: UIColor; let front: Bool; let sway: CGFloat }
        static func pieces(side: CGFloat) -> [Piece] {
            var r = Seeded(42)
            let colors: [UIColor] = [.systemPink, .systemYellow, .systemTeal, .systemPurple, .systemOrange, .systemGreen, .systemBlue]
            return (0..<34).map { k in
                Piece(x: r.next(), phase: r.next(), speed: r.next() < 0.5 ? 1 : 2, spin: r.next() < 0.5 ? 1 : -2,
                      w: side * (0.018 + 0.016 * r.next()), color: colors[k % colors.count], front: k % 4 == 0, sway: r.next())
            }
        }
        /// Each piece falls a whole number of screens per loop and turns a whole number of times, so the loop has no seam.
        static func draw(_ pieces: [Piece], p: CGFloat, side: CGFloat, in ctx: CGContext) {
            for c in pieces {
                let y = ((p * c.speed + c.phase).truncatingRemainder(dividingBy: 1)) * side * 1.15 - side * 0.08
                let x = c.x * side + sin((p * 2 + c.sway) * .pi * 2) * side * 0.02
                ctx.saveGState()
                ctx.translateBy(x: x, y: y)
                ctx.rotate(by: p * c.spin * .pi * 2 + c.sway * 6)
                ctx.scaleBy(x: 1, y: max(0.2, abs(cos((p * 2 + c.phase) * .pi * 2))))   // tumbling: it flips edge-on
                ctx.setFillColor(c.color.cgColor)
                ctx.fill(CGRect(x: -c.w / 2, y: -c.w * 0.3, width: c.w, height: c.w * 0.6))
                ctx.restoreGState()
            }
        }
    }

    enum Floaters {
        struct Heart { let x: CGFloat; let phase: CGFloat; let size: CGFloat; let color: UIColor; let front: Bool; let sway: CGFloat }
        static func hearts(side: CGFloat) -> [Heart] {
            var r = Seeded(7)
            let colors: [UIColor] = [UIColor(red: 1, green: 0.23, blue: 0.42, alpha: 1), UIColor(red: 1, green: 0.45, blue: 0.62, alpha: 1), UIColor(red: 0.93, green: 0.11, blue: 0.3, alpha: 1)]
            let xs: [CGFloat] = [0.1, 0.24, 0.78, 0.9, 0.16, 0.84, 0.5]
            return xs.enumerated().map { k, x in
                Heart(x: x, phase: CGFloat(k) / CGFloat(xs.count) + r.next() * 0.05, size: side * (0.06 + 0.04 * r.next()),
                      color: colors[k % colors.count], front: k % 3 == 1, sway: r.next())
            }
        }
        static func draw(_ hearts: [Heart], p: CGFloat, side: CGFloat, in ctx: CGContext) {
            for h in hearts {
                let t = (p + h.phase).truncatingRemainder(dividingBy: 1)
                let y = side * (0.95 - 0.85 * t)
                let x = side * h.x + sin((t * 2 + h.sway) * .pi * 2) * side * 0.025
                let a = t < 0.15 ? t / 0.15 : t > 0.75 ? (1 - t) / 0.25 : 1
                let s = h.size * (0.7 + 0.3 * min(1, t * 3))
                ctx.saveGState()
                ctx.setAlpha(a)
                ctx.setFillColor(h.color.cgColor)
                ctx.setShadow(offset: CGSize(width: 0, height: s * 0.06), blur: s * 0.15, color: UIColor(white: 0, alpha: 0.18).cgColor)
                ctx.addPath(heart(CGPoint(x: x, y: y), s))
                ctx.fillPath()
                ctx.restoreGState()
            }
        }
        static func heart(_ c: CGPoint, _ s: CGFloat) -> CGPath {
            let p = CGMutablePath()
            let w = s, h = s * 0.92
            let top = c.y - h * 0.32
            p.move(to: CGPoint(x: c.x, y: c.y + h * 0.5))
            p.addCurve(to: CGPoint(x: c.x - w / 2, y: top), control1: CGPoint(x: c.x - w * 0.12, y: c.y + h * 0.3), control2: CGPoint(x: c.x - w / 2, y: c.y + h * 0.1))
            p.addArc(center: CGPoint(x: c.x - w / 4, y: top), radius: w / 4, startAngle: .pi, endAngle: 0, clockwise: false)
            p.addArc(center: CGPoint(x: c.x + w / 4, y: top), radius: w / 4, startAngle: .pi, endAngle: 0, clockwise: false)
            p.addCurve(to: CGPoint(x: c.x, y: c.y + h * 0.5), control1: CGPoint(x: c.x + w / 2, y: c.y + h * 0.1), control2: CGPoint(x: c.x + w * 0.12, y: c.y + h * 0.3))
            p.closeSubpath()
            return p
        }
    }

    // MARK: - Files

    /// An animated PNG that loops forever: the soft see-through edge survives (a GIF's can't), and Messages plays it.
    static func apng(_ frames: [UIImage], delay: Double = delay) -> Data? {
        encode(frames, type: .png, container: kCGImagePropertyPNGDictionary,
               loop: [kCGImagePropertyAPNGLoopCount as String: 0],
               frame: [kCGImagePropertyAPNGDelayTime as String: delay, kCGImagePropertyAPNGUnclampedDelayTime as String: delay])
    }

    /// A looping GIF — what Photos and every chat app play. Its edge is hard (GIFs have no half-see-through).
    static func gif(_ frames: [UIImage], delay: Double = delay) -> Data? {
        let t = max(0.02, (delay * 100).rounded() / 100)
        return encode(frames, type: .gif, container: kCGImagePropertyGIFDictionary,
                      loop: [kCGImagePropertyGIFLoopCount as String: 0],
                      frame: [kCGImagePropertyGIFDelayTime as String: t, kCGImagePropertyGIFUnclampedDelayTime as String: t])
    }

    private static func encode(_ frames: [UIImage], type: UTType, container: CFString, loop: [String: Any], frame: [String: Any]) -> Data? {
        let cgs = frames.compactMap(\.cgImage)
        guard !cgs.isEmpty, cgs.count == frames.count else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, type.identifier as CFString, cgs.count, nil) else { return nil }
        CGImageDestinationSetProperties(dest, [container as String: loop] as CFDictionary)
        for cg in cgs { CGImageDestinationAddImage(dest, cg, [container as String: frame] as CFDictionary) }
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }
}
