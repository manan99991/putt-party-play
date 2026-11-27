import CoreImage
import UIKit

/// The things Face fun puts on a face (26 Nov): shades, a crown, a moustache, puppy ears… Every one is drawn here by
/// Tenzy with plain shapes — no emoji, no artwork from anywhere else — once, then placed on each face every frame,
/// sized to the face and turned with it.
enum FaceStickers {
    /// A drawn picture and the point on it (in its own pixels, y up) that sits on the face.
    struct Sprite { let image: CIImage; let anchor: CGPoint }

    private static var cache: [String: Sprite] = [:]
    private static let lock = NSLock()

    static func sprite(_ id: String) -> Sprite? {
        lock.lock(); defer { lock.unlock() }
        if let s = cache[id] { return s }
        guard let s = make(id) else { return nil }
        cache[id] = s
        return s
    }

    /// The sprite on the frame: its anchor at `p`, `width` wide, its up along `up` (plus `turn`), `alpha` see-through.
    static func place(_ id: String, at p: CGPoint, width: CGFloat, up: CGVector, turn: CGFloat = 0, alpha: CGFloat = 1) -> CIImage? {
        guard let sp = sprite(id), width > 1 else { return nil }
        let s = width / sp.image.extent.width
        let tr = CGAffineTransform(translationX: -sp.anchor.x, y: -sp.anchor.y)
            .concatenating(CGAffineTransform(scaleX: s, y: s))
            .concatenating(CGAffineTransform(rotationAngle: atan2(-up.dx, up.dy) + turn))
            .concatenating(CGAffineTransform(translationX: p.x, y: p.y))
        var im = sp.image.transformed(by: tr, highQualityDownsample: true)
        if alpha < 0.995 { im = im.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: max(0, alpha))]) }
        return im
    }

    // MARK: - Drawing

    private static func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
    }

    /// A see-through canvas `w` × `h` (origin bottom left, y up) drawn by `body`.
    private static func canvas(_ w: CGFloat, _ h: CGFloat, anchor: CGPoint, _ body: (CGContext) -> Void) -> Sprite? {
        guard let ctx = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setLineJoin(.round); ctx.setLineCap(.round)
        body(ctx)
        guard let cg = ctx.makeImage() else { return nil }
        return Sprite(image: CIImage(cgImage: cg), anchor: anchor)
    }

    /// `path` filled top-to-bottom from one colour to another.
    private static func fill(_ ctx: CGContext, _ path: CGPath, top: UInt32, bottom: UInt32) {
        let b = path.boundingBoxOfPath
        ctx.saveGState(); ctx.addPath(path); ctx.clip()
        if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [rgb(top), rgb(bottom)] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: b.midX, y: b.maxY), end: CGPoint(x: b.midX, y: b.minY), options: [])
        }
        ctx.restoreGState()
    }

    private static func stroke(_ ctx: CGContext, _ path: CGPath, _ hex: UInt32, _ width: CGFloat, alpha: CGFloat = 1) {
        ctx.addPath(path); ctx.setStrokeColor(rgb(hex, alpha)); ctx.setLineWidth(width); ctx.strokePath()
    }

    private static func solid(_ ctx: CGContext, _ path: CGPath, _ hex: UInt32, alpha: CGFloat = 1) {
        ctx.addPath(path); ctx.setFillColor(rgb(hex, alpha)); ctx.fillPath()
    }

    /// A ball lit from the upper left.
    private static func ball(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, light: UInt32, dark: UInt32) {
        ctx.saveGState(); ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)); ctx.clip()
        if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [rgb(light), rgb(dark)] as CFArray, locations: [0, 1]) {
            ctx.drawRadialGradient(g, startCenter: CGPoint(x: c.x - r * 0.3, y: c.y + r * 0.3), startRadius: r * 0.05, endCenter: c, endRadius: r * 1.05,
                                   options: [.drawsAfterEndLocation])
        }
        ctx.restoreGState()
        solid(ctx, CGPath(ellipseIn: CGRect(x: c.x - r * 0.52, y: c.y + r * 0.28, width: r * 0.42, height: r * 0.26), transform: nil), 0xFFFFFF, alpha: 0.75)
    }

    static func heart(_ c: CGPoint, _ size: CGFloat) -> CGPath {
        let w = size / 2, p = CGMutablePath()
        let tip = CGPoint(x: c.x, y: c.y - w * 0.92)
        p.move(to: tip)
        p.addCurve(to: CGPoint(x: c.x - w, y: c.y + w * 0.3), control1: CGPoint(x: c.x - w * 0.55, y: c.y - w * 0.45), control2: CGPoint(x: c.x - w, y: c.y - w * 0.15))
        p.addArc(center: CGPoint(x: c.x - w * 0.5, y: c.y + w * 0.3), radius: w * 0.5, startAngle: .pi, endAngle: 0, clockwise: true)
        p.addArc(center: CGPoint(x: c.x + w * 0.5, y: c.y + w * 0.3), radius: w * 0.5, startAngle: .pi, endAngle: 0, clockwise: true)
        p.addCurve(to: tip, control1: CGPoint(x: c.x + w, y: c.y - w * 0.15), control2: CGPoint(x: c.x + w * 0.55, y: c.y - w * 0.45))
        p.closeSubpath()
        return p
    }

    /// A star with `points` points.
    static func star(_ c: CGPoint, outer: CGFloat, inner: CGFloat, points: Int) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<(points * 2) {
            let r = i % 2 == 0 ? outer : inner, a = CGFloat(i) * .pi / CGFloat(points) + .pi / 2
            let q = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }

    private static func oval(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, turn: CGFloat = 0) -> CGPath {
        var t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: turn)
        return CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry), transform: &t)
    }

    /// Two lenses with a bridge and the start of the arms. The lens centres are 310 apart on a 600-wide canvas.
    private static func glasses(_ ctx: CGContext, lens: (CGFloat) -> CGPath, top: UInt32, bottom: UInt32, rim: UInt32, rimWidth: CGFloat) {
        let bridge = CGMutablePath(); bridge.move(to: CGPoint(x: 262, y: 138)); bridge.addQuadCurve(to: CGPoint(x: 338, y: 138), control: CGPoint(x: 300, y: 172))
        stroke(ctx, bridge, rim, rimWidth + 2)
        for (x0, x1) in [(CGFloat(34), CGFloat(2)), (566, 598)] {
            let arm = CGMutablePath(); arm.move(to: CGPoint(x: x0, y: 150)); arm.addLine(to: CGPoint(x: x1, y: 162))
            stroke(ctx, arm, rim, rimWidth)
        }
        for cx in [CGFloat(145), 455] {
            let p = lens(cx)
            fill(ctx, p, top: top, bottom: bottom)
            // A glint across the lens.
            ctx.saveGState(); ctx.addPath(p); ctx.clip()
            let g = CGMutablePath()
            g.move(to: CGPoint(x: cx - 80, y: 40)); g.addLine(to: CGPoint(x: cx - 30, y: 40)); g.addLine(to: CGPoint(x: cx + 60, y: 200)); g.addLine(to: CGPoint(x: cx + 10, y: 200)); g.closeSubpath()
            solid(ctx, g, 0xFFFFFF, alpha: 0.22)
            ctx.restoreGState()
            stroke(ctx, p, rim, rimWidth)
        }
    }

    private static func make(_ id: String) -> Sprite? {
        switch id {
        case "shades", "bling":
            let gold = id == "bling"
            return canvas(600, 230, anchor: CGPoint(x: 300, y: 115)) { ctx in
                glasses(ctx, lens: { cx in CGPath(roundedRect: CGRect(x: cx - 122, y: 28, width: 244, height: 172), cornerWidth: 62, cornerHeight: 62, transform: nil) },
                        top: gold ? 0x7A4B00 : 0x3B3B46, bottom: gold ? 0x2A1800 : 0x09090D, rim: gold ? 0xFFC93C : 0x0A0A0A, rimWidth: gold ? 18 : 13)
                if gold {
                    for c in [CGPoint(x: 40, y: 196), CGPoint(x: 560, y: 196)] { solid(ctx, star(c, outer: 30, inner: 9, points: 4), 0xFFFFFF) }
                }
            }
        case "heartglasses":
            return canvas(600, 250, anchor: CGPoint(x: 300, y: 118)) { ctx in
                glasses(ctx, lens: { cx in heart(CGPoint(x: cx, y: 122), 236) }, top: 0xFF86B4, bottom: 0xE8104F, rim: 0xFFFFFF, rimWidth: 12)
            }
        case "crown":
            return canvas(600, 420, anchor: CGPoint(x: 300, y: 34)) { ctx in
                let p = CGMutablePath()
                let pts: [(CGFloat, CGFloat)] = [(34, 60), (34, 280), (100, 172), (166, 330), (233, 172), (300, 376), (367, 172), (434, 330), (500, 172), (566, 280), (566, 60)]
                p.move(to: CGPoint(x: pts[0].0, y: pts[0].1)); for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.0, y: q.1)) }; p.closeSubpath()
                fill(ctx, p, top: 0xFFE873, bottom: 0xF0A400)
                stroke(ctx, p, 0x9A5B00, 8)
                let band = CGPath(roundedRect: CGRect(x: 22, y: 18, width: 556, height: 84), cornerWidth: 22, cornerHeight: 22, transform: nil)
                fill(ctx, band, top: 0xFFD84D, bottom: 0xD98A00)
                stroke(ctx, band, 0x9A5B00, 8)
                for (x, y) in [(CGFloat(34), CGFloat(280)), (166, 330), (300, 376), (434, 330), (566, 280)] { ball(ctx, CGPoint(x: x, y: y + 8), 24, light: 0xFFF3A6, dark: 0xE89B00) }
                for (x, light, dark) in [(CGFloat(120), UInt32(0xFF8A8A), UInt32(0xC2101C)), (300, 0x9FD4FF, 0x1565C0), (480, 0x9BEFB0, 0x12894A)] {
                    ball(ctx, CGPoint(x: x, y: 60), 25, light: light, dark: dark)
                }
                for x in [CGFloat(210), 390] { solid(ctx, star(CGPoint(x: x, y: 60), outer: 17, inner: 6, points: 4), 0xFFFFFF, alpha: 0.9) }
            }
        case "moustache":
            return canvas(600, 220, anchor: CGPoint(x: 300, y: 128)) { ctx in
                for side in [CGFloat(1), -1] {
                    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 300 + side * x, y: y) }
                    let p = CGMutablePath()
                    p.move(to: pt(0, 150))
                    p.addCurve(to: pt(170, 148), control1: pt(50, 186), control2: pt(120, 182))      // over the lip
                    p.addCurve(to: pt(282, 196), control1: pt(215, 118), control2: pt(262, 150))     // up into the curl
                    p.addCurve(to: pt(150, 66), control1: pt(292, 96), control2: pt(210, 52))        // round the tip and back
                    p.addCurve(to: pt(0, 96), control1: pt(95, 80), control2: pt(45, 70))            // under, to the middle
                    p.closeSubpath()
                    stroke(ctx, p, 0xFFF1D6, 40)          // a cream rim: on dark skin or in shade a brown moustache vanished (27 Nov phone run)
                    fill(ctx, p, top: 0x4A3324, bottom: 0x1E130C)
                    let shine = CGMutablePath(); shine.move(to: pt(40, 150)); shine.addQuadCurve(to: pt(160, 132), control: pt(100, 166))
                    stroke(ctx, shine, 0xFFFFFF, 7, alpha: 0.18)
                }
            }
        case "dogears":
            return canvas(700, 330, anchor: CGPoint(x: 350, y: 250)) { ctx in
                for side in [CGFloat(1), -1] {
                    let c = CGPoint(x: 350 + side * 255, y: 165)
                    fill(ctx, oval(c, 82, 150, turn: side * -0.3), top: 0x9A6535, bottom: 0x6B4020)
                    stroke(ctx, oval(c, 82, 150, turn: side * -0.3), 0x4A2B14, 7)
                    fill(ctx, oval(CGPoint(x: c.x + side * 6, y: c.y - 14), 44, 104, turn: side * -0.3), top: 0xD9A273, bottom: 0xB57A4C)
                }
            }
        case "dognose":
            return canvas(300, 230, anchor: CGPoint(x: 150, y: 130)) { ctx in
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 150, y: 44))
                p.addCurve(to: CGPoint(x: 28, y: 150), control1: CGPoint(x: 80, y: 44), control2: CGPoint(x: 22, y: 96))
                p.addCurve(to: CGPoint(x: 272, y: 150), control1: CGPoint(x: 36, y: 222), control2: CGPoint(x: 264, y: 222))
                p.addCurve(to: CGPoint(x: 150, y: 44), control1: CGPoint(x: 278, y: 96), control2: CGPoint(x: 220, y: 44))
                p.closeSubpath()
                fill(ctx, p, top: 0x3A3A3A, bottom: 0x050505)
                solid(ctx, oval(CGPoint(x: 112, y: 176), 46, 17, turn: 0.2), 0xFFFFFF, alpha: 0.55)
                let line = CGMutablePath(); line.move(to: CGPoint(x: 150, y: 46)); line.addLine(to: CGPoint(x: 150, y: 8))
                stroke(ctx, line, 0x050505, 9)
            }
        case "tongue":
            return canvas(200, 260, anchor: CGPoint(x: 100, y: 246)) { ctx in
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 26, y: 250)); p.addLine(to: CGPoint(x: 174, y: 250))
                p.addCurve(to: CGPoint(x: 100, y: 12), control1: CGPoint(x: 190, y: 120), control2: CGPoint(x: 170, y: 12))
                p.addCurve(to: CGPoint(x: 26, y: 250), control1: CGPoint(x: 30, y: 12), control2: CGPoint(x: 10, y: 120))
                p.closeSubpath()
                fill(ctx, p, top: 0xFF6F91, bottom: 0xFF9DB5)
                stroke(ctx, p, 0xD94B6E, 6)
                let mid = CGMutablePath(); mid.move(to: CGPoint(x: 100, y: 236)); mid.addLine(to: CGPoint(x: 100, y: 78))
                stroke(ctx, mid, 0xD94B6E, 6, alpha: 0.7)
            }
        case "bunnyears":
            return canvas(600, 560, anchor: CGPoint(x: 300, y: 40)) { ctx in
                for side in [CGFloat(1), -1] {
                    let c = CGPoint(x: 300 + side * 128, y: 290)
                    fill(ctx, oval(c, 78, 252, turn: side * -0.13), top: 0xFFFFFF, bottom: 0xECECF2)
                    stroke(ctx, oval(c, 78, 252, turn: side * -0.13), 0xC9C9D4, 7)
                    fill(ctx, oval(CGPoint(x: c.x, y: c.y - 6), 38, 196, turn: side * -0.13), top: 0xFFC2D4, bottom: 0xFF93B2)
                }
            }
        case "bunnynose":
            return canvas(700, 220, anchor: CGPoint(x: 350, y: 124)) { ctx in
                for side in [CGFloat(1), -1] {
                    for dy in [CGFloat(46), 0, -46] {
                        let w = CGMutablePath(); w.move(to: CGPoint(x: 350 + side * 74, y: 110 + dy * 0.25)); w.addLine(to: CGPoint(x: 350 + side * 330, y: 110 + dy * 1.6))
                        stroke(ctx, w, 0x2B2B2B, 9, alpha: 0.35)
                        stroke(ctx, w, 0xFFFFFF, 5, alpha: 0.95)
                    }
                }
                let n = CGMutablePath()
                n.move(to: CGPoint(x: 350, y: 84))
                n.addCurve(to: CGPoint(x: 296, y: 152), control1: CGPoint(x: 318, y: 96), control2: CGPoint(x: 284, y: 124))
                n.addCurve(to: CGPoint(x: 404, y: 152), control1: CGPoint(x: 312, y: 178), control2: CGPoint(x: 388, y: 178))
                n.addCurve(to: CGPoint(x: 350, y: 84), control1: CGPoint(x: 416, y: 124), control2: CGPoint(x: 382, y: 96))
                n.closeSubpath()
                fill(ctx, n, top: 0xFF9DB8, bottom: 0xF2577F)
                solid(ctx, oval(CGPoint(x: 332, y: 150), 16, 7, turn: 0.2), 0xFFFFFF, alpha: 0.6)
            }
        case "bunnyteeth":
            return canvas(220, 170, anchor: CGPoint(x: 110, y: 162)) { ctx in
                for x in [CGFloat(14), 114] {
                    let t = CGPath(roundedRect: CGRect(x: x, y: 10, width: 92, height: 150), cornerWidth: 20, cornerHeight: 20, transform: nil)
                    fill(ctx, t, top: 0xFFFFFF, bottom: 0xEEF0F5)
                    stroke(ctx, t, 0xB9BECB, 6)
                }
            }
        case "clownnose":
            return canvas(300, 300, anchor: CGPoint(x: 150, y: 150)) { ctx in
                solid(ctx, oval(CGPoint(x: 156, y: 134), 132, 128), 0x000000, alpha: 0.16)
                ball(ctx, CGPoint(x: 150, y: 152), 128, light: 0xFF7A6B, dark: 0xB80012)
            }
        case "halo":
            return canvas(600, 220, anchor: CGPoint(x: 300, y: 110)) { ctx in
                let ring = CGPath(ellipseIn: CGRect(x: 60, y: 50, width: 480, height: 120), transform: nil)
                stroke(ctx, ring, 0xFFE27A, 74, alpha: 0.16)
                stroke(ctx, ring, 0xFFE27A, 50, alpha: 0.22)
                stroke(ctx, ring, 0xF5B301, 28)
                stroke(ctx, ring, 0xFFF2A8, 12)
                let glint = CGMutablePath(); glint.addArc(center: CGPoint(x: 300, y: 110), radius: 236, startAngle: 2.2, endAngle: 2.75, clockwise: false)
                var squash = CGAffineTransform(translationX: 0, y: 82.5).scaledBy(x: 1, y: 0.25)
                if let g = glint.copy(using: &squash) { stroke(ctx, g, 0xFFFFFF, 7, alpha: 0.9) }
            }
        case "horns":
            return canvas(600, 330, anchor: CGPoint(x: 300, y: 24)) { ctx in
                for side in [CGFloat(1), -1] {
                    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 300 + side * x, y: y) }
                    let p = CGMutablePath()
                    p.move(to: pt(96, 12))
                    p.addCurve(to: pt(266, 312), control1: pt(110, 150), control2: pt(190, 250))
                    p.addCurve(to: pt(232, 12), control1: pt(292, 190), control2: pt(280, 70))
                    p.closeSubpath()
                    fill(ctx, p, top: 0xFF4D3D, bottom: 0x8E0A0A)
                    stroke(ctx, p, 0x5E0505, 7)
                    let shine = CGMutablePath(); shine.move(to: pt(136, 50)); shine.addQuadCurve(to: pt(232, 250), control: pt(150, 170))
                    stroke(ctx, shine, 0xFFFFFF, 8, alpha: 0.3)
                }
            }
        case "partyhat":
            return canvas(420, 560, anchor: CGPoint(x: 210, y: 46)) { ctx in
                let cone = CGMutablePath(); cone.move(to: CGPoint(x: 40, y: 50)); cone.addLine(to: CGPoint(x: 380, y: 50)); cone.addLine(to: CGPoint(x: 210, y: 480)); cone.closeSubpath()
                ctx.saveGState(); ctx.addPath(cone); ctx.clip()
                let colours: [UInt32] = [0xFF4FA3, 0x33C9FF, 0xFFD84D, 0x7BE495]
                for i in 0..<12 {
                    let y = CGFloat(i) * 62 - 120
                    let s = CGMutablePath(); s.move(to: CGPoint(x: 0, y: y)); s.addLine(to: CGPoint(x: 420, y: y + 190)); s.addLine(to: CGPoint(x: 420, y: y + 252)); s.addLine(to: CGPoint(x: 0, y: y + 62)); s.closeSubpath()
                    solid(ctx, s, colours[i % colours.count])
                }
                let shade = CGMutablePath(); shade.move(to: CGPoint(x: 250, y: 50)); shade.addLine(to: CGPoint(x: 380, y: 50)); shade.addLine(to: CGPoint(x: 210, y: 480)); shade.closeSubpath()
                solid(ctx, shade, 0x000000, alpha: 0.12)
                ctx.restoreGState()
                stroke(ctx, cone, 0xFFFFFF, 6, alpha: 0.9)
                for i in 0..<9 { ball(ctx, CGPoint(x: 40 + CGFloat(i) * 42.5, y: 48), 26, light: 0xFFFFFF, dark: 0xFFC83D) }
                for (dx, dy) in [(CGFloat(0), CGFloat(0)), (-26, -10), (26, -10), (-12, 24), (14, 22)] { ball(ctx, CGPoint(x: 210 + dx, y: 498 + dy), 30, light: 0xFFFFFF, dark: 0xFF7AB8) }
            }
        case "flowers":
            return canvas(760, 300, anchor: CGPoint(x: 380, y: 70)) { ctx in
                func y(_ x: CGFloat) -> CGFloat { 70 + 130 * (1 - pow((x - 380) / 340, 2)) }
                // The band and its leaves, then the flowers on top.
                let band = CGMutablePath(); band.move(to: CGPoint(x: 40, y: y(40)))
                for x in stride(from: CGFloat(60), through: 720, by: 20) { band.addLine(to: CGPoint(x: x, y: y(x))) }
                stroke(ctx, band, 0x2E8B4B, 16)
                for (i, x) in stride(from: CGFloat(70), through: 690, by: 62).enumerated() {
                    fill(ctx, oval(CGPoint(x: x, y: y(x) + (i % 2 == 0 ? 30 : -24)), 36, 15, turn: i % 2 == 0 ? 0.7 : -0.6), top: 0x6FD38A, bottom: 0x2E8B4B)
                }
                let petals: [(UInt32, UInt32)] = [(0xFF9CC4, 0xF2578F), (0xFFFFFF, 0xE9E3F5), (0xFFE08A, 0xF5A623), (0xC9B6FF, 0x8E6CF0)]
                let xs: [CGFloat] = [62, 168, 274, 380, 486, 592, 698], sizes: [CGFloat] = [44, 52, 58, 66, 58, 52, 44]
                for (i, x) in xs.enumerated() {
                    let c = CGPoint(x: x, y: y(x)), r = sizes[i], col = petals[i % petals.count]
                    for k in 0..<5 {
                        let a = CGFloat(k) * 2 * .pi / 5 + CGFloat(i) * 0.5
                        let pc = CGPoint(x: c.x + cos(a) * r * 0.62, y: c.y + sin(a) * r * 0.62)
                        fill(ctx, oval(pc, r * 0.52, r * 0.52), top: col.0, bottom: col.1)
                        stroke(ctx, oval(pc, r * 0.52, r * 0.52), 0x000000, 2, alpha: 0.08)
                    }
                    ball(ctx, c, r * 0.36, light: 0xFFF3A6, dark: 0xF59E0B)
                }
            }
        case "scar":
            return canvas(320, 120, anchor: CGPoint(x: 160, y: 60)) { ctx in
                let cut = CGMutablePath(); cut.move(to: CGPoint(x: 20, y: 50)); cut.addQuadCurve(to: CGPoint(x: 300, y: 70), control: CGPoint(x: 160, y: 82))
                stroke(ctx, cut, 0x5A0E12, 12)
                stroke(ctx, cut, 0x9E2A2F, 5)
                for x in stride(from: CGFloat(50), through: 270, by: 44) {
                    let s = CGMutablePath(); s.move(to: CGPoint(x: x - 6, y: 28)); s.addLine(to: CGPoint(x: x + 6, y: 98))
                    stroke(ctx, s, 0x1E1E1E, 7)
                }
            }
        case "antenna":
            return canvas(200, 340, anchor: CGPoint(x: 100, y: 16)) { ctx in
                let base = CGPath(roundedRect: CGRect(x: 44, y: 8, width: 112, height: 44), cornerWidth: 14, cornerHeight: 14, transform: nil)
                fill(ctx, base, top: 0xD5DAE2, bottom: 0x7F8894); stroke(ctx, base, 0x4B525C, 6)
                let rod = CGPath(roundedRect: CGRect(x: 90, y: 50, width: 20, height: 200), cornerWidth: 8, cornerHeight: 8, transform: nil)
                fill(ctx, rod, top: 0xC2C8D2, bottom: 0x7F8894); stroke(ctx, rod, 0x4B525C, 5)
                solid(ctx, oval(CGPoint(x: 100, y: 278), 58, 58), 0xFF3B30, alpha: 0.25)
                ball(ctx, CGPoint(x: 100, y: 278), 40, light: 0xFF9C94, dark: 0xD60A0A)
            }
        case "bolt":
            return canvas(160, 160, anchor: CGPoint(x: 80, y: 80)) { ctx in
                let hex = star(CGPoint(x: 80, y: 80), outer: 70, inner: 61, points: 6)
                fill(ctx, hex, top: 0xE1E5EB, bottom: 0x7F8894); stroke(ctx, hex, 0x4B525C, 7)
                let slot = CGMutablePath(); slot.move(to: CGPoint(x: 46, y: 80)); slot.addLine(to: CGPoint(x: 114, y: 80))
                stroke(ctx, slot, 0x4B525C, 12)
            }
        case "sparkle":
            return canvas(240, 240, anchor: CGPoint(x: 120, y: 120)) { ctx in
                solid(ctx, oval(CGPoint(x: 120, y: 120), 78, 78), 0xFFF2A8, alpha: 0.25)
                solid(ctx, star(CGPoint(x: 120, y: 120), outer: 116, inner: 22, points: 4), 0xFFE27A)
                solid(ctx, star(CGPoint(x: 120, y: 120), outer: 84, inner: 14, points: 4), 0xFFFFFF)
            }
        case "heart":
            return canvas(240, 240, anchor: CGPoint(x: 120, y: 120)) { ctx in
                let h = heart(CGPoint(x: 120, y: 124), 200)
                fill(ctx, h, top: 0xFF8FB3, bottom: 0xF2386E)
                stroke(ctx, h, 0xFFFFFF, 8, alpha: 0.9)
                solid(ctx, oval(CGPoint(x: 78, y: 162), 22, 13, turn: 0.5), 0xFFFFFF, alpha: 0.7)
            }
        case "sun":
            return canvas(600, 600, anchor: CGPoint(x: 300, y: 300)) { ctx in
                for i in 0..<12 {
                    let a = CGFloat(i) * .pi / 6
                    let ray = CGMutablePath()
                    ray.move(to: CGPoint(x: 300 + cos(a - 0.11) * 170, y: 300 + sin(a - 0.11) * 170))
                    ray.addLine(to: CGPoint(x: 300 + cos(a) * (i % 2 == 0 ? 292 : 246), y: 300 + sin(a) * (i % 2 == 0 ? 292 : 246)))
                    ray.addLine(to: CGPoint(x: 300 + cos(a + 0.11) * 170, y: 300 + sin(a + 0.11) * 170))
                    ray.closeSubpath()
                    solid(ctx, ray, 0xFFC531)
                }
                solid(ctx, oval(CGPoint(x: 300, y: 300), 176, 176), 0xFFE27A, alpha: 0.5)
                ball(ctx, CGPoint(x: 300, y: 300), 150, light: 0xFFF6B8, dark: 0xFFB300)
            }
        default: return nil
        }
    }
}
