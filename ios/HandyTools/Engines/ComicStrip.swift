import UIKit

/// A comic strip from 1–4 photos: each photo inked (PixelArt "comic"), framed in a bold black panel with
/// white gutters, a speech bubble per panel with a tail, and an optional yellow title caption — the
/// classic newspaper-strip look, drawn on device.
enum ComicStrip {
    /// Panel layout for `n` photos on `canvas`: a 2×2 grid for four, a strip otherwise.
    static func layout(for n: Int) -> CollageLayout { n == 4 ? .grid : .strip }

    static func bubbleFont(_ size: CGFloat) -> UIFont {
        UIFont(name: "ChalkboardSE-Bold", size: size) ?? .systemFont(ofSize: size, weight: .heavy)
    }

    static func render(panels: [UIImage], words: [String], title: String, canvas: CGSize) -> UIImage {
        let short = min(canvas.width, canvas.height)
        let gap = (short * 0.03).rounded()
        let titleH: CGFloat = title.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : (short * 0.11).rounded()
        let area = CGSize(width: canvas.width, height: canvas.height - titleH)
        let frames = layout(for: panels.count).frames(count: panels.count, canvas: area, gap: gap)
            .map { $0.offsetBy(dx: 0, dy: titleH) }
        let border = max(3, (short * 0.007).rounded())
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: canvas, format: fmt).image { c in
            UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: canvas))
            if titleH > 0 {
                let box = CGRect(x: gap, y: gap * 0.6, width: canvas.width - gap * 2, height: titleH - gap * 0.6)
                UIColor(red: 1, green: 0.88, blue: 0.2, alpha: 1).setFill(); UIBezierPath(rect: box).fill()
                UIColor.black.setStroke(); let p = UIBezierPath(rect: box); p.lineWidth = border; p.stroke()
                draw(title.uppercased(), in: box.insetBy(dx: gap * 0.5, dy: 4), font: bubbleFont(box.height * 0.42), align: .center)
            }
            for (i, f) in frames.enumerated() where i < panels.count {
                let img = panels[i]
                c.cgContext.saveGState()
                UIBezierPath(rect: f).addClip()
                let k = max(f.width / max(img.size.width, 1), f.height / max(img.size.height, 1))
                let w = img.size.width * k, h = img.size.height * k
                img.draw(in: CGRect(x: f.midX - w / 2, y: f.midY - h / 2, width: w, height: h))
                c.cgContext.restoreGState()
                UIColor.black.setStroke(); let p = UIBezierPath(rect: f); p.lineWidth = border * 1.6; p.stroke()
                let text = i < words.count ? words[i].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                if !text.isEmpty { bubble(text, in: f, border: border) }
            }
        }
    }

    /// A white rounded speech bubble near the top of `panel`, with a tail pointing down toward the speaker.
    static func bubble(_ text: String, in panel: CGRect, border: CGFloat) {
        let maxW = panel.width * 0.72
        var size = panel.height * 0.075
        var rect = CGRect.zero
        while size > 10 {
            let font = bubbleFont(size)
            let b = (text as NSString).boundingRect(with: CGSize(width: maxW, height: .greatestFiniteMagnitude),
                                                    options: [.usesLineFragmentOrigin], attributes: [.font: font], context: nil)
            rect = b
            if b.height <= panel.height * 0.38 { break }
            size -= 2
        }
        let pad = size * 0.6
        let bubble = CGRect(x: panel.minX + panel.width * 0.06, y: panel.minY + panel.height * 0.05,
                            width: min(maxW, rect.width) + pad * 2, height: rect.height + pad * 2)
        let path = UIBezierPath(roundedRect: bubble, cornerRadius: min(bubble.height, bubble.width) * 0.45)
        // Tail: from the bubble's lower middle, down and to the right.
        let tailBase = CGPoint(x: bubble.minX + bubble.width * 0.35, y: bubble.maxY - 2)
        let tail = UIBezierPath()
        tail.move(to: CGPoint(x: tailBase.x - size * 0.5, y: tailBase.y))
        tail.addLine(to: CGPoint(x: tailBase.x + size * 1.4, y: min(panel.maxY - 6, bubble.maxY + size * 1.5)))
        tail.addLine(to: CGPoint(x: tailBase.x + size * 0.6, y: tailBase.y))
        tail.close()
        UIColor.black.setStroke(); UIColor.white.setFill()
        path.lineWidth = border; tail.lineWidth = border
        tail.fill(); tail.stroke(); path.fill(); path.stroke()
        // Paint over the seam where tail meets bubble.
        UIColor.white.setFill()
        UIBezierPath(rect: CGRect(x: tailBase.x - size * 0.5 + border, y: tailBase.y - border * 1.5, width: size * 1.1 - border * 2, height: border * 2.5)).fill()
        draw(text, in: bubble.insetBy(dx: pad, dy: pad), font: bubbleFont(size), align: .center)
    }

    private static func draw(_ s: String, in r: CGRect, font: UIFont, align: NSTextAlignment) {
        let para = NSMutableParagraphStyle(); para.alignment = align; para.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black, .paragraphStyle: para]
        let h = (s as NSString).boundingRect(with: CGSize(width: r.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin],
                                             attributes: attrs, context: nil).height
        (s as NSString).draw(with: CGRect(x: r.minX, y: r.midY - h / 2, width: r.width, height: h + 2), options: [.usesLineFragmentOrigin],
                             attributes: attrs, context: nil)
    }
}
