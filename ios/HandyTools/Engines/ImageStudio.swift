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
        if (try? handler.perform([req])) != nil, let res = req.results?.first, !res.allInstances.isEmpty,
           let masked = try? res.generateMaskedImage(ofInstances: res.allInstances, from: handler, croppedToInstancesExtent: false) {
            let ci = CIImage(cvPixelBuffer: masked)
            if let out = CIContext().createCGImage(ci, from: ci.extent) { return UIImage(cgImage: out) }
        }
        return saliencyCutout(cg)
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

    // MARK: passport

    struct PassportSpec: Identifiable, Hashable { let id: String; let name: String; let px: CGSize }
    static let passportSpecs: [PassportSpec] = [
        PassportSpec(id: "us", name: "US 2×2 in",            px: CGSize(width: 600, height: 600)),
        PassportSpec(id: "eu", name: "EU / Schengen 35×45",  px: CGSize(width: 413, height: 531)),
        PassportSpec(id: "uk", name: "UK 35×45 mm",          px: CGSize(width: 413, height: 531)),
        PassportSpec(id: "in", name: "India 35×45 mm",       px: CGSize(width: 413, height: 531)),
        PassportSpec(id: "ca", name: "Canada 50×70 mm",      px: CGSize(width: 591, height: 827)),
    ]

    /// Optional clean background, then crop to the spec with the face ~62% of the height and a
    /// touch above centre — the usual ID layout. Nil if no clear face.
    static func passport(_ image: UIImage, spec: PassportSpec, background: UIColor?) -> UIImage? {
        var working = image.normalizedUp()
        if let background, let cut = cutout(working) { working = composite(cut, on: background) }
        guard let cg = working.cgImage else { return nil }
        let W = CGFloat(cg.width), H = CGFloat(cg.height)

        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        let faceReq = VNDetectFaceRectanglesRequest()
        try? handler.perform([faceReq])
        guard let face = faceReq.results?.max(by: { $0.boundingBox.height < $1.boundingBox.height }) else { return nil }
        let fb = face.boundingBox
        let faceRect = CGRect(x: fb.minX * W, y: (1 - fb.maxY) * H, width: fb.width * W, height: fb.height * H)

        let aspect = spec.px.width / spec.px.height
        let headH = faceRect.height * 1.5
        var cropH = headH / 0.62, cropW = cropH * aspect
        if cropW > W { cropW = W; cropH = cropW / aspect }
        if cropH > H { cropH = H; cropW = cropH * aspect }
        let originX = min(max(0, faceRect.midX - cropW / 2), W - cropW)
        let originY = min(max(0, faceRect.midY - cropH * 0.46), H - cropH)
        guard let cropped = cg.cropping(to: CGRect(x: originX, y: originY, width: cropW, height: cropH).integral) else { return nil }

        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: spec.px, format: fmt).image { _ in
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: spec.px))
        }
    }

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
