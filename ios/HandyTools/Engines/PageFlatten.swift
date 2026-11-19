import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// A photo of a page, made into the page: finds the sheet's four corners (even with a table edge, a hand or
/// a shadow around it), flattens it square as if it had been scanned, then whitens the paper and darkens the ink
/// so faint print reads cleanly. Leaves the photo alone when no page is clearly there, so it never crops into
/// the writing.
enum PageFlatten {
    struct Result { let image: UIImage; let flattened: Bool; let whitened: Bool; var handsRemoved = false }

    static func scan(_ image: UIImage) -> Result {
        let up = image.normalizedUp()
        guard let cg = up.cgImage else { return Result(image: up, flattened: false, whitened: false) }
        var ci = CIImage(cgImage: cg)
        var flattened = false
        if let q = corners(cg) {
            let w = CGFloat(cg.width), h = CGFloat(cg.height)
            func p(_ v: CGPoint) -> CIVector { CIVector(x: v.x * w, y: v.y * h) }   // Vision: bottom-left origin, like Core Image
            let f = CIFilter.perspectiveCorrection()
            f.inputImage = ci
            f.topLeft = p(q.topLeft).cgPointValue; f.topRight = p(q.topRight).cgPointValue
            f.bottomLeft = p(q.bottomLeft).cgPointValue; f.bottomRight = p(q.bottomRight).cgPointValue
            if let out = f.outputImage, out.extent.width > 200, out.extent.height > 200 { ci = out; flattened = true }
        }
        // Fingers holding the page: painted out with the paper's own colour, so only the document is kept.
        var hands = false
        if let flat = ctx.createCGImage(ci, from: ci.extent.integral), case let (clean, n)? = removeHands(flat), n > 0 {
            ci = CIImage(cgImage: clean); hands = true
        }
        let enh = CIFilter.documentEnhancer(); enh.inputImage = ci; enh.amount = 1.0
        let cleaned = enh.outputImage ?? ci
        guard let out = ctx.createCGImage(cleaned, from: cleaned.extent.integral) else { return Result(image: up, flattened: false, whitened: false) }
        return Result(image: UIImage(cgImage: out), flattened: flattened, whitened: true, handsRemoved: hands)
    }

    /// A page photo (scanned or taken) with the fingers and hands that held it painted out. Use on every image
    /// that comes in as a document.
    static func withoutHands(_ image: UIImage) -> UIImage {
        guard let cg = image.normalizedUp().cgImage, case let (clean, n)? = removeHands(cg), n > 0 else { return image }
        return UIImage(cgImage: clean)
    }

    /// Skin-coloured regions that reach in from the edge of the page — a thumb on the margin, fingers along the
    /// side, a palm under the corner — replaced with the paper colour. Only regions touching the edge count, so a
    /// photo printed on the page is left alone; and if "skin" would cover more than a third of the page, the paper
    /// itself must be skin-toned and nothing is touched. Returns the cleaned image and how many pixels changed.
    static func removeHands(_ cg: CGImage) -> (CGImage, Int)? {
        let W = cg.width, H = cg.height
        guard W > 16, H > 16 else { return nil }
        // Work on a copy no bigger than 1600 px for the mask, then apply it at full size.
        let scale = min(1, 1600 / Double(max(W, H)))
        let w = max(8, Int(Double(W) * scale)), h = max(8, Int(Double(H) * scale))
        guard let small = rgba(cg, w, h) else { return nil }
        var skin = [Bool](repeating: false, count: w * h)
        var paperSum = (0.0, 0.0, 0.0), paperN = 0.0
        for i in 0..<(w * h) {
            let r = Double(small[i * 4]), g = Double(small[i * 4 + 1]), b = Double(small[i * 4 + 2])
            skin[i] = isSkin(r, g, b)
            if !skin[i], r + g + b > 540 { paperSum.0 += r; paperSum.1 += g; paperSum.2 += b; paperN += 1 }
        }
        // Grow from skin pixels on the border.
        var mask = [Bool](repeating: false, count: w * h)
        var stack: [Int] = []
        for x in 0..<w { stack.append(x); stack.append((h - 1) * w + x) }
        for y in 0..<h { stack.append(y * w); stack.append(y * w + w - 1) }
        stack = stack.filter { skin[$0] }
        var count = 0
        while let i = stack.popLast() {
            if mask[i] || !skin[i] { continue }
            mask[i] = true; count += 1
            let x = i % w, y = i / w
            if x > 0 { stack.append(i - 1) }; if x < w - 1 { stack.append(i + 1) }
            if y > 0 { stack.append(i - w) }; if y < h - 1 { stack.append(i + w) }
        }
        guard count > w * h / 400, count < w * h / 3 else { return count == 0 ? (cg, 0) : nil }
        // Widen the mask a little to take the soft edge and shadow of the finger too.
        let grow = max(2, w / 160)
        var wide = mask
        for y in 0..<h { for x in 0..<w where mask[y * w + x] {
            for dy in -grow...grow { let yy = y + dy; guard yy >= 0, yy < h else { continue }
                for dx in -grow...grow { let xx = x + dx; if xx >= 0, xx < w { wide[yy * w + xx] = true } } }
        } }
        let paper: (UInt8, UInt8, UInt8) = paperN > 50 ? (UInt8(paperSum.0 / paperN), UInt8(paperSum.1 / paperN), UInt8(paperSum.2 / paperN)) : (245, 245, 245)
        guard var full = rgba(cg, W, H) else { return nil }
        var changed = 0
        for Y in 0..<H {
            let y = min(h - 1, Int(Double(Y) * scale))
            for X in 0..<W {
                let x = min(w - 1, Int(Double(X) * scale))
                if wide[y * w + x] {
                    let o = (Y * W + X) * 4
                    full[o] = paper.0; full[o + 1] = paper.1; full[o + 2] = paper.2; full[o + 3] = 255
                    changed += 1
                }
            }
        }
        let out = full.withUnsafeMutableBytes { p -> CGImage? in
            CGContext(data: p.baseAddress, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        return out.map { ($0, changed) }
    }

    /// Skin in RGB and YCbCr together (both must agree), which keeps out beige paper, wood and grey shadow.
    static func isSkin(_ r: Double, _ g: Double, _ b: Double) -> Bool {
        guard r > 95, g > 40, b > 20, r > g, r > b, r - min(g, b) > 15, abs(r - g) > 15 else { return false }
        let cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b
        let cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b
        return cb >= 77 && cb <= 127 && cr >= 137 && cr <= 173
    }

    private static func rgba(_ cg: CGImage, _ w: Int, _ h: Int) -> [UInt8]? {
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        let ok = buf.withUnsafeMutableBytes { p -> Bool in
            guard let c = CGContext(data: p.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            c.interpolationQuality = .medium
            c.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? buf : nil
    }

    struct Quad { let topLeft, topRight, bottomLeft, bottomRight: CGPoint }

    /// The page's corners, normalised, when a page clearly fills a good part of the photo but not all of it.
    static func corners(_ cg: CGImage) -> Quad? {
        let req = VNDetectDocumentSegmentationRequest()
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
        if let d = req.results?.first, d.confidence > 0.6, let q = accept(d.topLeft, d.topRight, d.bottomLeft, d.bottomRight) { return q }
        let rect = VNDetectRectanglesRequest()
        rect.minimumAspectRatio = 0.3; rect.maximumAspectRatio = 1; rect.minimumSize = 0.4; rect.quadratureTolerance = 25; rect.maximumObservations = 1
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([rect])
        if let r = rect.results?.first, r.confidence > 0.7 { return accept(r.topLeft, r.topRight, r.bottomLeft, r.bottomRight) }
        return nil
    }

    /// A real page: covers 25–97 % of the photo (all of it means it's already a clean page or a full-frame scan).
    static func accept(_ tl: CGPoint, _ tr: CGPoint, _ bl: CGPoint, _ br: CGPoint) -> Quad? {
        let pts = [tl, tr, br, bl]
        var a: CGFloat = 0
        for i in 0..<4 { let p = pts[i], q = pts[(i + 1) % 4]; a += p.x * q.y - q.x * p.y }
        let area = abs(a) / 2
        guard area >= 0.25, area <= 0.97 else { return nil }
        return Quad(topLeft: tl, topRight: tr, bottomLeft: bl, bottomRight: br)
    }

    nonisolated(unsafe) private static let ctx = CIContext(options: [.useSoftwareRenderer: false])
}
