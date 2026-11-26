import UIKit

/// Designer collage layouts on real platform canvases (VideoFormat: Story 9:16, Square, Portrait 4:5,
/// wide 16:9). Each layout turns "n photos" into frames that tile the canvas exactly, with an even gap
/// between tiles and around the edge; photos are cropped to fill their frame (centered) so nothing is
/// stretched. Pure geometry, so the layouts are unit-tested; rendering is a single Core Graphics pass.
enum CollageLayout: String, CaseIterable, Identifiable {
    case grid, hero, sideHero, mosaic, strip
    var id: String { rawValue }
    var title: String {
        switch self {
        case .grid: return "Grid"
        case .hero: return "Hero"
        case .sideHero: return "Side hero"
        case .mosaic: return "Mosaic"
        case .strip: return "Photo strip"
        }
    }
    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .hero: return "rectangle.split.1x2"
        case .sideHero: return "rectangle.split.2x1"
        case .mosaic: return "square.grid.3x1.below.line.grid.1x2"
        case .strip: return "rectangle.split.3x1"
        }
    }

    /// Frames (in canvas points) for `count` photos, inset by `gap` everywhere.
    func frames(count: Int, canvas: CGSize, gap: CGFloat) -> [CGRect] {
        guard count > 0, canvas.width > 0, canvas.height > 0 else { return [] }
        let area = CGRect(origin: .zero, size: canvas).insetBy(dx: gap, dy: gap)
        if count == 1 { return [area] }
        switch self {
        case .grid:
            return Self.gridRows(count: count, in: area, gap: gap)
        case .hero:
            let (top, rest) = area.divided(atDistance: (area.height - gap) * (count <= 3 ? 0.6 : 0.55), from: .minYEdge)
            let below = CGRect(x: rest.minX, y: rest.minY + gap, width: rest.width, height: rest.height - gap)
            return [top] + Self.gridRows(count: count - 1, in: below, gap: gap, maxPerRow: 3)
        case .sideHero:
            let wide = canvas.width >= canvas.height
            let (main, rest) = area.divided(atDistance: ((wide ? area.width : area.height) - gap) * 0.6, from: wide ? .minXEdge : .minYEdge)
            let side = wide ? CGRect(x: rest.minX + gap, y: rest.minY, width: rest.width - gap, height: rest.height)
                            : CGRect(x: rest.minX, y: rest.minY + gap, width: rest.width, height: rest.height - gap)
            return [main] + Self.line(count: count - 1, in: side, gap: gap, vertical: wide)
        case .mosaic:
            // Rows alternate 2 and 3 tiles (2 first), giving a magazine rhythm.
            var sizes: [Int] = [], left = count, two = true
            while left > 0 { let n = min(left, two ? 2 : 3); sizes.append(n); left -= n; two.toggle() }
            return Self.rows(sizes, in: area, gap: gap)
        case .strip:
            return Self.line(count: count, in: area, gap: gap, vertical: canvas.height >= canvas.width)
        }
    }

    // MARK: geometry helpers

    /// As-square-as-possible rows; the last row's tiles widen to fill.
    static func gridRows(count: Int, in r: CGRect, gap: CGFloat, maxPerRow: Int? = nil) -> [CGRect] {
        guard count > 0 else { return [] }
        let aspect = r.width / max(r.height, 1)
        var cols = max(1, Int((Double(count) * Double(aspect)).squareRoot().rounded()))
        if let m = maxPerRow { cols = min(cols, m) }
        cols = min(cols, count)
        var sizes: [Int] = [], left = count
        while left > 0 { let n = min(cols, left); sizes.append(n); left -= n }
        return rows(sizes, in: r, gap: gap)
    }

    static func rows(_ sizes: [Int], in r: CGRect, gap: CGFloat) -> [CGRect] {
        let h = (r.height - gap * CGFloat(sizes.count - 1)) / CGFloat(max(1, sizes.count))
        var out: [CGRect] = []
        for (i, n) in sizes.enumerated() {
            let y = r.minY + CGFloat(i) * (h + gap)
            let w = (r.width - gap * CGFloat(n - 1)) / CGFloat(n)
            for j in 0..<n { out.append(CGRect(x: r.minX + CGFloat(j) * (w + gap), y: y, width: w, height: h)) }
        }
        return out
    }

    static func line(count: Int, in r: CGRect, gap: CGFloat, vertical: Bool) -> [CGRect] {
        guard count > 0 else { return [] }
        let n = CGFloat(count)
        if vertical {
            let h = (r.height - gap * (n - 1)) / n
            return (0..<count).map { CGRect(x: r.minX, y: r.minY + CGFloat($0) * (h + gap), width: r.width, height: h) }
        }
        let w = (r.width - gap * (n - 1)) / n
        return (0..<count).map { CGRect(x: r.minX + CGFloat($0) * (w + gap), y: r.minY, width: w, height: r.height) }
    }

    // MARK: render

    /// Where a filled photo goes in its frame: centred, or — when the photo's faces are known (`focus`, 0…1 from the
    /// top-left) — shifted so the faces sit in the middle of the frame as far as the photo allows. Never leaves a gap.
    static func placed(_ size: CGSize, in f: CGRect, focus: CGPoint?) -> CGRect {
        var x = f.midX - size.width / 2, y = f.midY - size.height / 2
        if let p = focus {
            x = min(f.minX, max(f.maxX - size.width, f.midX - p.x * size.width))
            y = min(f.minY, max(f.maxY - size.height, f.midY - p.y * size.height))
        }
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// The finished collage. `gapRatio` and `cornerRatio` are fractions of the canvas's short side.
    static func render(_ images: [UIImage], layout: CollageLayout, canvas: CGSize, gapRatio: CGFloat,
                       cornerRatio: CGFloat, background: UIColor, focus: [CGPoint?]? = nil, footer: String? = nil) -> UIImage {
        let short = min(canvas.width, canvas.height)
        let gap = (short * gapRatio).rounded()
        let corner = short * cornerRatio
        // A footer line (the day's date) takes a band at the bottom; the photos tile the rest.
        let band: CGFloat = footer == nil ? 0 : (short * 0.085).rounded()
        let frames = layout.frames(count: images.count, canvas: CGSize(width: canvas.width, height: canvas.height - band), gap: gap)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: canvas, format: fmt).image { c in
            background.setFill(); c.fill(CGRect(origin: .zero, size: canvas))
            for (i, (img, f)) in zip(images, frames).enumerated() {
                let src = img.normalizedUp()
                c.cgContext.saveGState()
                UIBezierPath(roundedRect: f, cornerRadius: min(corner, min(f.width, f.height) / 2)).addClip()
                let k = max(f.width / max(src.size.width, 1), f.height / max(src.size.height, 1))
                let w = src.size.width * k, h = src.size.height * k
                src.draw(in: placed(CGSize(width: w, height: h), in: f, focus: focus.flatMap { i < $0.count ? $0[i] : nil }))
                c.cgContext.restoreGState()
            }
            if let footer, band > 0 {
                let para = NSMutableParagraphStyle(); para.alignment = .center
                let font = UIFont(descriptor: UIFont.systemFont(ofSize: band * 0.42, weight: .semibold).fontDescriptor.withDesign(.serif) ?? UIFont.systemFont(ofSize: band * 0.42).fontDescriptor, size: band * 0.42)
                var lum: CGFloat = 1; background.getWhite(&lum, alpha: nil)
                let ink = lum < 0.5 ? UIColor.white.withAlphaComponent(0.85) : UIColor(white: 0.2, alpha: 1)
                (footer as NSString).draw(in: CGRect(x: gap, y: canvas.height - band - gap * 0.2 + (band - font.lineHeight) / 2, width: canvas.width - gap * 2, height: font.lineHeight + 2),
                                          withAttributes: [.font: font, .foregroundColor: ink, .paragraphStyle: para, .kern: band * 0.02])
            }
        }
    }
}
