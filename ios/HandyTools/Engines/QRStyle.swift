import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// QR codes with a look of their own — your colour, soft dots, a picture in the middle, a caption — that
/// still scan every time. Every styled code is read back with Apple's own barcode reader before it's shown;
/// a style that wouldn't scan falls back to plain, and says so. The pure parts are unit-tested.
enum QRStyle {
    struct Look: Equatable {
        var ink: Int = 0x111111        // colour of the code, as hex
        var dots = false               // round dots instead of squares (the three corner eyes stay solid)
        var center: String?            // an emoji in the middle
        var caption = ""               // a line under the code ("Scan for our menu")
    }

    static let inks: [(name: String, hex: Int)] = [("Black", 0x111111), ("Navy", 0x1B2A6B), ("Purple", 0x5B2BB5),
                                                   ("Teal", 0x0B7A75), ("Red", 0xC62828), ("Green", 0x2E7D32)]
    static let centers = ["", "☕️", "🍕", "🎉", "📶", "❤️", "⭐️", "🏠", "🛍️", "📍"]

    /// The code as a grid of modules, true = dark, top row first. nil for empty text.
    static func matrix(_ message: String, correction: String) -> [[Bool]]? {
        let m = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return nil }
        let f = CIFilter.qrCodeGenerator(); f.message = Data(m.utf8); f.correctionLevel = correction
        guard let out = f.outputImage, let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        let n = cg.width
        guard n > 0, cg.height == n, let px = GrayPixels.read(cg, w: n, h: n, quality: .none) else { return nil }
        return (0..<n).map { y in (0..<n).map { x in px[y * n + x] < 128 } }
    }

    /// Is (x, y) inside one of the three corner "eyes" (7×7, inside the 1-module margin)?
    static func inEye(_ x: Int, _ y: Int, n: Int, margin: Int) -> Bool {
        let lo = margin, hi = n - margin - 7
        func near(_ a: Int, _ b: Int) -> Bool { a >= b && a < b + 7 }
        return (near(x, lo) && near(y, lo)) || (near(x, hi) && near(y, lo)) || (near(x, lo) && near(y, hi))
    }

    /// The styled code, `side` points square (plus room for a caption). nil when the text can't be encoded.
    static func render(_ message: String, look: Look, side: CGFloat = 1024) -> UIImage? {
        // A picture in the middle hides some of the code, so use the strongest error correction for it.
        guard let grid = matrix(message, correction: look.center == nil ? "M" : "H") else { return nil }
        let n = grid.count
        let margin = 1   // CIQRCodeGenerator draws a 1-module quiet border
        let pad = side * 0.06
        let cell = (side - pad * 2) / CGFloat(n)
        let captionH: CGFloat = look.caption.isEmpty ? 0 : side * 0.12
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let ink = UIColor(rgb: look.ink)
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side + captionH), format: fmt).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: side, height: side + captionH))
            ink.setFill()
            for y in 0..<n { for x in 0..<n where grid[y][x] {
                let r = CGRect(x: pad + CGFloat(x) * cell, y: pad + CGFloat(y) * cell, width: cell, height: cell)
                if look.dots && !inEye(x, y, n: n, margin: margin) {
                    UIBezierPath(ovalIn: r.insetBy(dx: cell * 0.08, dy: cell * 0.08)).fill()
                } else {
                    UIBezierPath(rect: r.insetBy(dx: -0.25, dy: -0.25)).fill()   // a hair of overlap: no white seams
                }
            } }
            if let e = look.center, !e.isEmpty {
                let box = (side - pad * 2) * 0.22
                let rect = CGRect(x: (side - box) / 2, y: (side - box) / 2, width: box, height: box)
                UIColor.white.setFill(); UIBezierPath(roundedRect: rect.insetBy(dx: -cell * 0.6, dy: -cell * 0.6), cornerRadius: box * 0.22).fill()
                let s = NSAttributedString(string: e, attributes: [.font: UIFont.systemFont(ofSize: box * 0.78)])
                let sz = s.size()
                s.draw(at: CGPoint(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2))
            }
            if !look.caption.isEmpty {
                let p = NSMutableParagraphStyle(); p.alignment = .center
                let s = NSAttributedString(string: look.caption, attributes: [.font: UIFont.systemFont(ofSize: captionH * 0.45, weight: .semibold),
                                                                              .foregroundColor: ink, .paragraphStyle: p])
                s.draw(in: CGRect(x: pad, y: side - pad * 0.3, width: side - pad * 2, height: captionH))
            }
        }
    }

    /// What a camera would read from the picture (Apple's barcode reader), or nil if it can't read it.
    static func reads(_ img: UIImage) -> String? { ChainExtras.readCode(img) }

    /// The styled code if it scans back to exactly the message. If it doesn't — and the reader can read the
    /// plain version, so it's the style at fault — plain black squares instead. (When the phone's reader can't
    /// read either, e.g. it's unavailable, the styled code stands: dots and a centre picture use the strongest
    /// error correction, made for exactly this.)
    static func safeRender(_ message: String, look: Look) -> (image: UIImage, fellBack: Bool)? {
        let m = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let styled = render(m, look: look) else { return nil }
        let got = reads(styled)
        if got == m { return (styled, false) }
        var plain = look; plain.dots = false; plain.center = nil; plain.ink = 0x111111
        guard plain != look, let flat = render(m, look: plain) else { return (styled, false) }
        if got != nil || reads(flat) == m { return (flat, true) }   // the reader works, and the style is what broke it
        return (styled, false)
    }
}

extension UIColor {
    convenience init(rgb: Int) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}
