import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// A photo of a page, made into the page: finds the sheet's four corners (even with a table edge, a hand or
/// a shadow around it), flattens it square as if it had been scanned, then whitens the paper and darkens the ink
/// so faint print reads cleanly. Leaves the photo alone when no page is clearly there, so it never crops into
/// the writing.
enum PageFlatten {
    struct Result { let image: UIImage; let flattened: Bool; let whitened: Bool }

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
        let enh = CIFilter.documentEnhancer(); enh.inputImage = ci; enh.amount = 1.0
        let cleaned = enh.outputImage ?? ci
        guard let out = ctx.createCGImage(cleaned, from: cleaned.extent.integral) else { return Result(image: up, flattened: false, whitened: false) }
        return Result(image: UIImage(cgImage: out), flattened: flattened, whitened: true)
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
