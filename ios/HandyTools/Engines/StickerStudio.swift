import UIKit
import CoreImage

/// The sticker studio: one cut-out subject → a designed sticker. Every part is a choice with a great
/// default: the look of the subject (original, pop, cartoon, pencil, noir, retro), its edge (none, thin,
/// die-cut thick, double), the edge colour (white, black, any colour, or holographic rainbow), a neon glow,
/// a soft drop shadow, a backdrop shape behind it (circle badge, rounded tile, starburst), a caption in
/// bold sticker lettering, and sparkles. Ten presets combine these into finished designs. All drawn on
/// device with Core Graphics / Core Image; output is a trimmed, see-through PNG.
enum StickerStudio {

    enum Look: String, CaseIterable, Identifiable { case original, pop, cartoon, pencil, noir, retro
        var id: String { rawValue }
        var title: String { ["Original", "Pop", "Cartoon", "Pencil", "Noir", "Retro"][Self.allCases.firstIndex(of: self)!] }
    }
    enum Edge: String, CaseIterable, Identifiable { case none, thin, thick, double
        var id: String { rawValue }
        var title: String { ["None", "Thin", "Die-cut", "Double"][Self.allCases.firstIndex(of: self)!] }
    }
    enum EdgeColor: String, CaseIterable, Identifiable { case white, black, yellow, pink, sky, mint, rainbow
        var id: String { rawValue }
        var color: UIColor {
            switch self {
            case .white: return .white
            case .black: return UIColor(white: 0.08, alpha: 1)
            case .yellow: return UIColor(red: 1, green: 0.84, blue: 0.1, alpha: 1)
            case .pink: return UIColor(red: 1, green: 0.36, blue: 0.62, alpha: 1)
            case .sky: return UIColor(red: 0.2, green: 0.62, blue: 1, alpha: 1)
            case .mint: return UIColor(red: 0.2, green: 0.86, blue: 0.62, alpha: 1)
            case .rainbow: return .white
            }
        }
    }
    enum Backdrop: String, CaseIterable, Identifiable { case none, circle, tile, burst
        var id: String { rawValue }
        var title: String { ["None", "Circle", "Tile", "Burst"][Self.allCases.firstIndex(of: self)!] }
    }

    struct Style: Equatable {
        var look: Look = .original
        var edge: Edge = .thick
        var edgeColor: EdgeColor = .white
        var outline: Bool = false            // a thin dark keyline outside the edge, comic-style
        var glow: Bool = false
        var shadow: Bool = true
        var backdrop: Backdrop = .none
        var backdropColor: EdgeColor = .yellow
        var caption: String = ""
        var sparkles: Bool = false
    }

    struct Preset: Identifiable { let id: String; let name: String; let style: Style }
    static let presets: [Preset] = [
        Preset(id: "classic", name: "Classic", style: Style(edge: .thick, edgeColor: .white, shadow: true)),
        Preset(id: "comic", name: "Comic", style: Style(look: .cartoon, edge: .thick, edgeColor: .white, outline: true, shadow: false)),
        Preset(id: "neon", name: "Neon", style: Style(look: .pop, edge: .thin, edgeColor: .pink, glow: true, shadow: false)),
        Preset(id: "holo", name: "Holographic", style: Style(edge: .thick, edgeColor: .rainbow, shadow: true, sparkles: true)),
        Preset(id: "badge", name: "Badge", style: Style(edge: .thin, edgeColor: .white, shadow: true, backdrop: .circle, backdropColor: .sky)),
        Preset(id: "burst", name: "Pop burst", style: Style(look: .pop, edge: .thick, edgeColor: .white, outline: true, shadow: false, backdrop: .burst, backdropColor: .yellow)),
        Preset(id: "retro", name: "Retro", style: Style(look: .retro, edge: .double, edgeColor: .yellow, shadow: true)),
        Preset(id: "sketch", name: "Sketch", style: Style(look: .pencil, edge: .thick, edgeColor: .white, outline: true, shadow: true)),
        Preset(id: "noir", name: "Noir", style: Style(look: .noir, edge: .thick, edgeColor: .black, shadow: false, backdrop: .tile, backdropColor: .white)),
        Preset(id: "clean", name: "Clean", style: Style(edge: .none, shadow: true)),
    ]

    // MARK: - Render

    /// The finished sticker. `subject` is a see-through cut-out (any size); `side` is the longest edge
    /// of the subject in the output.
    static func render(_ subject: UIImage, style: Style, side: CGFloat = 900) -> UIImage? {
        guard let trimmed = trim(subject) else { return nil }
        let k = side / max(trimmed.size.width, trimmed.size.height)
        let subjSize = CGSize(width: (trimmed.size.width * k).rounded(), height: (trimmed.size.height * k).rounded())
        let looked = applyLook(style.look, to: resize(trimmed, subjSize))

        let edgeW: CGFloat = style.edge == .none ? 0 : side * (style.edge == .thin ? 0.018 : 0.04)
        let outlineW: CGFloat = style.outline ? side * 0.012 : 0
        let doubleW: CGFloat = style.edge == .double ? side * 0.03 : 0
        let glowR: CGFloat = style.glow ? side * 0.06 : 0
        let shadowR: CGFloat = style.shadow ? side * 0.035 : 0
        let captionH: CGFloat = style.caption.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : side * 0.22
        let backPad: CGFloat = style.backdrop == .none ? 0 : side * 0.14
        let margin = edgeW + outlineW + doubleW + glowR + shadowR * 2 + backPad + side * 0.03
        let canvas = CGSize(width: subjSize.width + margin * 2, height: subjSize.height + margin * 2 + captionH * 0.6)
        let subjRect = CGRect(x: margin, y: margin, width: subjSize.width, height: subjSize.height)

        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        let art = UIGraphicsImageRenderer(size: canvas, format: fmt).image { c in
            let ctx = c.cgContext
            // Backdrop shape behind everything.
            if style.backdrop != .none {
                drawBackdrop(style.backdrop, color: style.backdropColor, around: subjRect.insetBy(dx: -backPad, dy: -backPad), in: ctx)
            }
            // Glow: the silhouette in colour, blurred, twice for intensity.
            if glowR > 0, let g = blurred(tint(looked, style.edgeColor == .white ? EdgeColor.pink.color : style.edgeColor.color), radius: glowR) {
                g.draw(in: subjRect.insetBy(dx: -glowR * 2, dy: -glowR * 2))
                g.draw(in: subjRect.insetBy(dx: -glowR * 2, dy: -glowR * 2))
            }
            // Edges, outermost first.
            let totalEdge = edgeW + doubleW
            if outlineW > 0 { ring(looked, in: subjRect, radius: totalEdge + outlineW, color: UIColor(white: 0.08, alpha: 1), rainbow: false) }
            if doubleW > 0 { ring(looked, in: subjRect, radius: totalEdge, color: style.edgeColor.color, rainbow: style.edgeColor == .rainbow) }
            if doubleW > 0 { ring(looked, in: subjRect, radius: edgeW, color: .white, rainbow: false) }
            else if edgeW > 0 { ring(looked, in: subjRect, radius: edgeW, color: style.edgeColor.color, rainbow: style.edgeColor == .rainbow) }
            looked.draw(in: subjRect)
            if style.sparkles { drawSparkles(around: subjRect, side: side) }
            if captionH > 0 { drawCaption(style.caption, under: subjRect, height: captionH, canvasWidth: canvas.width) }
        }
        guard style.shadow else { return trim(art) ?? art }
        // Soft drop shadow under the whole design.
        let shadowed = UIGraphicsImageRenderer(size: canvas, format: fmt).image { c in
            c.cgContext.setShadow(offset: CGSize(width: 0, height: shadowR * 0.6), blur: shadowR, color: UIColor(white: 0, alpha: 0.35).cgColor)
            art.draw(at: .zero)
        }
        return trim(shadowed) ?? shadowed
    }

    // MARK: - Pieces

    /// Crop to the visible pixels (+1px).
    static func trim(_ img: UIImage) -> UIImage? {
        guard let cg = img.cgImage, let box = ChainFun.solidBounds(cg), let c = cg.cropping(to: box) else { return nil }
        return UIImage(cgImage: c)
    }

    private static func resize(_ img: UIImage, _ size: CGSize) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// The subject's shape filled with one colour.
    static func tint(_ img: UIImage, _ color: UIColor) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        return UIGraphicsImageRenderer(size: img.size, format: fmt).image { c in
            img.draw(at: .zero)
            c.cgContext.setBlendMode(.sourceIn)
            color.setFill(); c.cgContext.fill(CGRect(origin: .zero, size: img.size))
        }
    }

    /// The silhouette grown by `radius` (stamped round a circle), in a colour or a rainbow sweep.
    private static func ring(_ img: UIImage, in rect: CGRect, radius: CGFloat, color: UIColor, rainbow: Bool) {
        guard radius > 0.5 else { return }
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        let solid = tint(img, .white)
        let pad = radius + 2
        let size = CGSize(width: rect.width + pad * 2, height: rect.height + pad * 2)
        let grown = UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            let steps = max(24, Int(radius / 1.5))
            for r in [radius, radius * 0.66, radius * 0.33] {
                for i in 0..<steps {
                    let a = CGFloat(i) / CGFloat(steps) * 2 * .pi
                    solid.draw(in: CGRect(x: pad + cos(a) * r, y: pad + sin(a) * r, width: rect.width, height: rect.height))
                }
            }
            solid.draw(in: CGRect(x: pad, y: pad, width: rect.width, height: rect.height))
            c.cgContext.setBlendMode(.sourceIn)
            if rainbow {
                let colors = [UIColor(red: 1, green: 0.4, blue: 0.7, alpha: 1), UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1),
                              UIColor(red: 0.4, green: 0.95, blue: 0.7, alpha: 1), UIColor(red: 0.4, green: 0.7, blue: 1, alpha: 1),
                              UIColor(red: 0.75, green: 0.5, blue: 1, alpha: 1)].map(\.cgColor)
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil) {
                    c.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
                }
            } else {
                color.setFill(); c.cgContext.fill(CGRect(origin: .zero, size: size))
            }
        }
        grown.draw(in: CGRect(x: rect.minX - pad, y: rect.minY - pad, width: size.width, height: size.height))
    }

    private static func blurred(_ img: UIImage, radius: CGFloat) -> UIImage? {
        guard let cg = img.cgImage else { return nil }
        let pad = radius * 2
        let ci = CIImage(cgImage: cg).transformed(by: CGAffineTransform(translationX: pad, y: pad))
        let canvas = CGRect(x: 0, y: 0, width: CGFloat(cg.width) + pad * 2, height: CGFloat(cg.height) + pad * 2)
        let out = ci.applyingGaussianBlur(sigma: Double(radius) * 0.6).cropped(to: canvas)
        guard let made = CIContext().createCGImage(out, from: canvas) else { return nil }
        return UIImage(cgImage: made)
    }

    /// The subject in the chosen look; transparency kept.
    static func applyLook(_ look: Look, to img: UIImage) -> UIImage {
        guard look != .original, let cg = img.cgImage else { return img }
        var styled: UIImage?
        switch look {
        case .cartoon: styled = ChainFun.art(opaque(img), style: "comic", long: max(img.size.width, img.size.height))
        case .pencil: styled = ChainFun.art(opaque(img), style: "sketch", long: max(img.size.width, img.size.height))
        default:
            let ci = CIImage(cgImage: cg)
            let f: CIImage
            switch look {
            case .pop: f = ci.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.7, kCIInputContrastKey: 1.15])
            case .noir: f = ci.applyingFilter("CIPhotoEffectNoir")
            case .retro: f = ci.applyingFilter("CIPhotoEffectTransfer")
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 0.95, kCIInputSaturationKey: 0.9])
            default: f = ci
            }
            if let out = CIContext().createCGImage(f, from: ci.extent) { styled = UIImage(cgImage: out) }
        }
        guard let s = styled else { return img }
        // Put the original see-through shape back on the styled pixels.
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        return UIGraphicsImageRenderer(size: img.size, format: fmt).image { c in
            s.draw(in: CGRect(origin: .zero, size: img.size))
            img.draw(in: CGRect(origin: .zero, size: img.size), blendMode: .destinationIn, alpha: 1)
        }
    }

    /// Flatten on white for the filters that need solid pixels.
    private static func opaque(_ img: UIImage) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: img.size, format: fmt).image { c in
            UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: img.size)); img.draw(at: .zero)
        }
    }

    private static func drawBackdrop(_ b: Backdrop, color: EdgeColor, around r: CGRect, in ctx: CGContext) {
        let fill = color == .rainbow ? EdgeColor.yellow.color : color.color
        let path: UIBezierPath
        switch b {
        case .circle:
            let s = max(r.width, r.height)
            path = UIBezierPath(ovalIn: CGRect(x: r.midX - s / 2, y: r.midY - s / 2, width: s, height: s))
        case .tile:
            path = UIBezierPath(roundedRect: r, cornerRadius: min(r.width, r.height) * 0.18)
        case .burst:
            path = UIBezierPath()
            let c = CGPoint(x: r.midX, y: r.midY), outer = max(r.width, r.height) * 0.56, inner = outer * 0.8
            for i in 0..<32 {
                let a = CGFloat(i) / 32 * 2 * .pi - .pi / 2, rad = i % 2 == 0 ? outer : inner
                let p = CGPoint(x: c.x + cos(a) * rad, y: c.y + sin(a) * rad)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.close()
        case .none: return
        }
        fill.setFill(); path.fill()
        UIColor(white: 0.08, alpha: 1).setStroke(); path.lineWidth = max(3, r.width * 0.012); path.stroke()
    }

    private static func drawSparkles(around r: CGRect, side: CGFloat) {
        let spots: [(CGFloat, CGFloat, CGFloat)] = [(0.02, 0.06, 0.16), (0.9, 0.02, 0.12), (0.95, 0.7, 0.14), (0.0, 0.8, 0.1)]
        for (x, y, s) in spots {
            let size = side * s
            ("✨" as NSString).draw(at: CGPoint(x: r.minX + r.width * x - size / 2, y: r.minY + r.height * y - size / 2),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: size)])
        }
    }

    /// Bold rounded caption with a thick dark outline — readable on any chat background.
    private static func drawCaption(_ text: String, under r: CGRect, height: CGFloat, canvasWidth: CGFloat) {
        let t = text.uppercased()
        var size = height * 0.62
        let base = UIFont.systemFont(ofSize: size, weight: .black)
        func font(_ s: CGFloat) -> UIFont {
            base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: s) } ?? .systemFont(ofSize: s, weight: .black)
        }
        while size > 10, (t as NSString).size(withAttributes: [.font: font(size)]).width > canvasWidth * 0.92 { size -= 2 }
        let f = font(size)
        let w = (t as NSString).size(withAttributes: [.font: f])
        let at = CGPoint(x: (canvasWidth - w.width) / 2, y: r.maxY - height * 0.35)
        (t as NSString).draw(at: at, withAttributes: [.font: f, .strokeColor: UIColor(white: 0.08, alpha: 1), .strokeWidth: 18,
                                                      .foregroundColor: UIColor(white: 0.08, alpha: 1)])
        (t as NSString).draw(at: at, withAttributes: [.font: f, .foregroundColor: UIColor.white])
    }

    // MARK: - Sticker sheet

    /// A printable A4 sheet — 12 stickers of about 6 cm, 3 across. A short pack repeats to fill the whole
    /// page (that's what you want on a sheet of sticker paper); a big pack runs onto more pages.
    static let sheetPerPage = 12
    static func sheetPDF(_ stickers: [UIImage]) -> Data? {
        guard !stickers.isEmpty else { return nil }
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 32, gap: CGFloat = 18, cols = 3, footer: CGFloat = 22
        let cell = (page.width - margin * 2 - gap * CGFloat(cols - 1)) / CGFloat(cols)
        let rows = sheetPerPage / cols
        let top = margin + max(0, (page.height - footer - margin * 2 - (cell * CGFloat(rows) + gap * CGFloat(rows - 1))) / 2)
        let slots = Int((Double(stickers.count) / Double(sheetPerPage)).rounded(.up)) * sheetPerPage
        let note = "Tenzy sticker sheet · print at 100% on sticker paper, then cut around the white edge" as NSString
        return UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            for i in 0..<slots {
                let slot = i % sheetPerPage
                if slot == 0 {
                    ctx.beginPage()
                    note.draw(at: CGPoint(x: margin, y: page.height - margin + 6),
                              withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.gray])
                }
                let s = stickers[i % stickers.count]
                let cellRect = CGRect(x: margin + CGFloat(slot % cols) * (cell + gap), y: top + CGFloat(slot / cols) * (cell + gap), width: cell, height: cell)
                let k = min(cell / max(s.size.width, 1), cell / max(s.size.height, 1))
                let w = s.size.width * k, h = s.size.height * k
                s.draw(in: CGRect(x: cellRect.midX - w / 2, y: cellRect.midY - h / 2, width: w, height: h))
            }
        }
    }
}
