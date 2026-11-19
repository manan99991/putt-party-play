import UIKit
import Vision
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// The image engine behind Studio (and reused by Share-Ready/Scan): subject cutout, passport
/// crop, resize, and encode. All on-device via Vision + Core Image + ImageIO.
enum ImageStudio {

    // MARK: cutout

    /// Subject lifted off the background (alpha PNG), via Vision's foreground-instance mask, with a
    /// saliency fallback for subjects the instance model misses (flat graphics, low-texture photos).
    static func cutout(_ image: UIImage) -> UIImage? {
        guard let cg = image.normalizedUp().cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: cg)
        let req = VNGenerateForegroundInstanceMaskRequest()
        if (try? handler.perform([req])) != nil, let res = req.results?.first, !res.allInstances.isEmpty {
            if let mask = try? res.generateScaledMaskForImage(forInstances: res.allInstances, from: handler),
               let clean = refinedCutout(cg, mask: CIImage(cvPixelBuffer: mask)) { return clean }
        }
        if let res = req.results?.first, !res.allInstances.isEmpty,
           let masked = try? res.generateMaskedImage(ofInstances: res.allInstances, from: handler, croppedToInstancesExtent: false) {
            let ci = CIImage(cvPixelBuffer: masked)
            if let out = CIContext().createCGImage(ci, from: ci.extent) { return UIImage(cgImage: out) }
        }
        return saliencyCutout(cg)
    }

    /// Clean edges: pull the mask in by a pixel or two (removes the background "halo" that clings to a
    /// raw cut-out), then feather it slightly so hair and soft edges blend instead of looking cut with
    /// scissors. The amount scales with the photo so it looks the same on a selfie and a 48 MP shot.
    static func refinedCutout(_ cg: CGImage, mask raw: CIImage) -> UIImage? {
        let full = CIImage(cgImage: cg)
        guard raw.extent.width > 0, raw.extent.height > 0 else { return nil }
        let fit = raw.transformed(by: CGAffineTransform(scaleX: full.extent.width / raw.extent.width, y: full.extent.height / raw.extent.height))
        let r = max(1, min(full.extent.width, full.extent.height) / 700)
        let mask = fit
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: r])
            .clampedToExtent()
            .applyingGaussianBlur(sigma: Double(r) * 0.9)
            .cropped(to: full.extent)
        let clear = CIImage(color: .clear).cropped(to: full.extent)
        let out = full.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: clear, kCIInputMaskImageKey: mask])
        guard let made = CIContext().createCGImage(out, from: full.extent, format: .RGBA8,
                                                   colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else { return nil }
        return UIImage(cgImage: made)
    }

    /// When the instance model finds no subject, fall back to attention-based saliency: scale the
    /// heatmap up to the image, sharpen it into an alpha mask, and blend the photo over transparency.
    /// Rough at the edges, but it always returns *something* to lift rather than failing outright.
    private static func saliencyCutout(_ cg: CGImage) -> UIImage? {
        let handler = VNImageRequestHandler(cgImage: cg)
        let req = VNGenerateAttentionBasedSaliencyImageRequest()
        guard (try? handler.perform([req])) != nil,
              let obs = req.results?.first as? VNSaliencyImageObservation else { return nil }
        let full = CIImage(cgImage: cg)
        let heat = CIImage(cvPixelBuffer: obs.pixelBuffer)
        let sx = full.extent.width / heat.extent.width, sy = full.extent.height / heat.extent.height
        let mask = heat.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
            .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 2.2, kCIInputBrightnessKey: -0.15])
            .applyingFilter("CIMaskToAlpha")
        let masked = full.applyingFilter("CIBlendWithMask", parameters: [kCIInputMaskImageKey: mask])
        guard let out = CIContext().createCGImage(masked, from: full.extent) else { return nil }
        return UIImage(cgImage: out)
    }

    /// Lay an alpha subject over a flat colour.
    static func composite(_ subject: UIImage, on color: UIColor) -> UIImage {
        let size = CGSize(width: subject.size.width * subject.scale, height: subject.size.height * subject.scale)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            color.setFill(); c.fill(CGRect(origin: .zero, size: size))
            subject.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: listing photo

    /// Where a product photo is going, and what that place wants: square, plain white, the product filling most
    /// of the frame. Sizes from each marketplace's own photo guidance.
    struct Market: Identifiable, Equatable { let id: String; let name: String; let side: CGFloat; let fill: CGFloat }
    static let markets: [Market] = [
        Market(id: "amazon", name: "Amazon", side: 2000, fill: 0.85),        // pure white, product ≥ 85% of the frame
        Market(id: "ebay", name: "eBay", side: 1600, fill: 0.8),
        Market(id: "etsy", name: "Etsy", side: 2000, fill: 0.75),
        Market(id: "fbm", name: "Marketplace", side: 1200, fill: 0.78),
    ]

    /// A cut-out product placed on pure white: trimmed to the product, centred, scaled so it fills `fill` of the
    /// square, with a soft contact shadow so it doesn't float.
    static func listing(_ cut: UIImage, market: Market, shadow: Bool = true) -> UIImage? {
        guard let cg = cut.cgImage, let box = opaqueBounds(cg) else { return nil }
        let side = market.side
        let scale = min(side * market.fill / box.width, side * market.fill / box.height)
        let w = box.width * scale, h = box.height * scale
        let rect = CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h)
        guard let trimmed = cg.cropping(to: box) else { return nil }
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: fmt).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
            if shadow {
                let c = ctx.cgContext
                c.saveGState()
                c.setShadow(offset: .zero, blur: side * 0.03, color: UIColor(white: 0, alpha: 0.22).cgColor)
                UIColor(white: 0.9, alpha: 1).setFill()
                c.fillEllipse(in: CGRect(x: rect.minX + w * 0.12, y: rect.maxY - side * 0.012, width: w * 0.76, height: side * 0.018))
                c.restoreGState()
            }
            UIImage(cgImage: trimmed).draw(in: rect)
        }
    }

    /// The box around everything not see-through, in pixels (top-left origin).
    static func opaqueBounds(_ cg: CGImage, threshold: UInt8 = 24) -> CGRect? {
        let w = cg.width, h = cg.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let c = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        c.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var minX = w, minY = h, maxX = -1, maxY = -1
        let step = max(1, min(w, h) / 600)
        for y in stride(from: 0, to: h, by: step) { for x in stride(from: 0, to: w, by: step) where buf[(y * w + x) * 4 + 3] > threshold {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        } }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + step, height: maxY - minY + step).intersection(CGRect(x: 0, y: 0, width: w, height: h))
    }

    // MARK: profile picture

    enum ProfileBackground: String, CaseIterable { case keep, blur, plain }

    /// A square profile picture: the face centred, the head about 55% of the height with room above it, 1080 px
    /// (what Instagram, LinkedIn, WhatsApp and Slack all crop to a circle). Background kept, softly blurred, or
    /// swapped for a plain colour. Nil when there's no face.
    static func profile(_ image: UIImage, background: ProfileBackground = .keep, color: UIColor = UIColor(red: 0.86, green: 0.9, blue: 0.96, alpha: 1)) -> UIImage? {
        let up = image.normalizedUp()
        guard let cg = up.cgImage else { return nil }
        // The passport engine measures the head itself: crown to chin, in pixels, top-left origin.
        guard let f = PassportPhoto.analyze(cg) else { return nil }
        let W = CGFloat(cg.width), H = CGFloat(cg.height)
        let head = max(1, f.chin.y - f.crown.y)
        var side = min(head / 0.55, W, H)
        side = max(side, min(W, H) * 0.3)
        let cx = f.centreX, top = f.crown.y - side * 0.2          // a little room above the hair
        var crop = CGRect(x: cx - side / 2, y: top, width: side, height: side)
        crop.origin.x = min(max(0, crop.minX), W - side); crop.origin.y = min(max(0, crop.minY), H - side)
        guard let piece = cg.cropping(to: crop.integral) else { return nil }
        var base = UIImage(cgImage: piece)
        if background != .keep, let cut = cutout(base) {
            let size = CGSize(width: piece.width, height: piece.height)
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
            let behind: UIImage = background == .plain ? UIGraphicsImageRenderer(size: size, format: fmt).image { c in color.setFill(); c.fill(CGRect(origin: .zero, size: size)) }
                : blurred(base, radius: size.width * 0.03)
            base = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
                behind.draw(in: CGRect(origin: .zero, size: size)); cut.draw(in: CGRect(origin: .zero, size: size))
            }
        }
        let out = CGSize(width: 1080, height: 1080)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: out, format: fmt).image { _ in base.draw(in: CGRect(origin: .zero, size: out)) }
    }

    static func blurred(_ image: UIImage, radius: CGFloat) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let ci = CIImage(cgImage: cg)
        let b = ci.clampedToExtent().applyingGaussianBlur(sigma: Double(radius)).cropped(to: ci.extent)
        guard let out = CIContext().createCGImage(b, from: ci.extent) else { return image }
        return UIImage(cgImage: out)
    }

    // MARK: what changed

    /// Plain words for what a fix did to a photo, measured on both: brighter, more contrast, sharper, bigger.
    static func changes(from a: UIImage, to b: UIImage) -> [String] {
        func stats(_ img: UIImage) -> (mean: Double, spread: Double, px: Int)? {
            guard let cg = img.cgImage else { return nil }
            let w = 64, h = 64
            var buf = [UInt8](repeating: 0, count: w * h * 4)
            guard let c = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            c.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            var l: [Double] = []
            for i in stride(from: 0, to: buf.count, by: 4) { l.append(0.299 * Double(buf[i]) + 0.587 * Double(buf[i + 1]) + 0.114 * Double(buf[i + 2])) }
            let m = l.reduce(0, +) / Double(l.count)
            let sd = (l.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(l.count)).squareRoot()
            return (m, sd, cg.width * cg.height)
        }
        guard let x = stats(a), let y = stats(b) else { return [] }
        var out: [String] = []
        let bright = (y.mean - x.mean) / max(1, x.mean) * 100
        if abs(bright) >= 4 { out.append(bright > 0 ? "\(Int(bright.rounded()))% brighter" : "\(Int(-bright.rounded()))% darker") }
        let contrast = (y.spread - x.spread) / max(1, x.spread) * 100
        if abs(contrast) >= 5 { out.append(contrast > 0 ? "\(Int(contrast.rounded()))% more contrast" : "softer contrast") }
        if y.px > x.px * 3 / 2 {
            let sa = Int((Double(a.size.width * a.scale)).rounded()), sb = Int((Double(b.size.width * b.scale)).rounded())
            out.append("enlarged \(sa) → \(sb) px wide")
        }
        return out
    }

    // MARK: passport — see PassportPhoto (one engine for Studio, the Builder step and the Guide)

    /// Tile a finished ID photo across a 4×6 sheet at 300 dpi with light cut guides.
    static func printSheet(_ photo: UIImage) -> Data? {
        let sheet = CGSize(width: 1200, height: 1800)
        let gap: CGFloat = 24, margin: CGFloat = 36
        let pw = photo.size.width, ph = photo.size.height
        let cols = max(1, Int((sheet.width - 2 * margin + gap) / (pw + gap)))
        let rows = max(1, Int((sheet.height - 2 * margin + gap) / (ph + gap)))
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let img = UIGraphicsImageRenderer(size: sheet, format: fmt).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: sheet))
            let gridW = CGFloat(cols) * pw + CGFloat(cols - 1) * gap, gridH = CGFloat(rows) * ph + CGFloat(rows - 1) * gap
            let x0 = (sheet.width - gridW) / 2, y0 = (sheet.height - gridH) / 2
            UIColor(white: 0.8, alpha: 1).setStroke()
            for r in 0..<rows { for c in 0..<cols {
                let rect = CGRect(x: x0 + CGFloat(c) * (pw + gap), y: y0 + CGFloat(r) * (ph + gap), width: pw, height: ph)
                photo.draw(in: rect)
                let g = UIBezierPath(rect: rect.insetBy(dx: -0.5, dy: -0.5)); g.lineWidth = 1; g.stroke()
            } }
        }
        return img.jpegData(compressionQuality: 0.95)
    }

    // MARK: enhance

    /// One-tap cleanup for dull or soft phone shots: Apple's own auto-tone (exposure, contrast,
    /// tone curve), a gentle denoise, light sharpening, and an optional 2× Lanczos upscale (capped
    /// so we never blow past ~4096 px on the long side). All Core Image, on-device. This is heavy
    /// for large photos, so callers run it off the main thread.
    static func enhance(_ image: UIImage, upscale: Bool) -> UIImage? {
        guard let cg0 = image.normalizedUp().cgImage else { return nil }
        let ctx = CIContext()
        var ci = CIImage(cgImage: cg0)

        // Auto-tone: Apple's built-in auto adjustments (skip red-eye / face work).
        for f in ci.autoAdjustmentFilters(options: [.enhance: true, .redEye: false]) {
            f.setValue(ci, forKey: kCIInputImageKey)
            if let out = f.outputImage { ci = out }
        }
        // Gentle denoise.
        if let nr = CIFilter(name: "CINoiseReduction", parameters: [kCIInputImageKey: ci, "inputNoiseLevel": 0.015, "inputSharpness": 0.4]),
           let out = nr.outputImage { ci = out }
        // Light sharpening.
        if let s = CIFilter(name: "CIUnsharpMask", parameters: [kCIInputImageKey: ci, kCIInputRadiusKey: 2.2, kCIInputIntensityKey: 0.5]),
           let out = s.outputImage { ci = out }
        // Optional upscale, capped at a sane maximum.
        if upscale {
            let longest = max(ci.extent.width, ci.extent.height)
            let scale = min(2.0, max(1.0, 4096.0 / max(1, longest)))
            if scale > 1.01,
               let sc = CIFilter(name: "CILanczosScaleTransform", parameters: [kCIInputImageKey: ci, kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1.0]),
               let out = sc.outputImage { ci = out }
        }

        let rect = ci.extent.isInfinite ? CIImage(cgImage: cg0).extent : ci.extent
        guard rect.width > 0, rect.height > 0, let cg = ctx.createCGImage(ci, from: rect) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: encode

    enum Format: String, CaseIterable { case jpg = "JPG", png = "PNG", heic = "HEIC" }

    /// Fresh encode (no metadata). HEIC via ImageIO; returns nil if the device can't encode it.
    static func encode(_ image: UIImage, as format: Format, quality: CGFloat) -> Data? {
        let img = image.normalizedUp()
        switch format {
        case .jpg: return img.jpegData(compressionQuality: quality)
        case .png: return img.pngData()
        case .heic:
            guard let cg = img.cgImage else { return nil }
            let out = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(out, UTType.heic.identifier as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality as String: quality] as CFDictionary)
            return CGImageDestinationFinalize(dest) ? out as Data : nil
        }
    }
}

extension UIImage {
    /// Scale down so the longest side is at most `maxDimension` (never upscales).
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let s = maxDimension / longest
        let newSize = CGSize(width: size.width * s, height: size.height * s)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: fmt).image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
