import UIKit
import Vision
import ImageIO
import MapKit

/// Privacy Scrubber engine. Two jobs most apps get wrong:
///  1. Strip EXIF/GPS — a fresh encode carries none of the original metadata.
///  2. Redact *irreversibly* — most apps blur or pixelate, and both can be reversed (Unredacter, PETS'16).
///     We paint opaque blocks and re-encode, so the pixels underneath no longer exist in the output.
enum Scrubber {

    struct Metadata {
        var hasGPS = false
        var coordinate: CLLocationCoordinate2D?
        var taken: String?
        var device: String?
    }

    /// What the photo quietly carries.
    static func metadata(in data: Data) -> Metadata {
        var m = Metadata()
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] else { return m }
        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        let gps  = props[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
        if let t = exif[kCGImagePropertyExifDateTimeOriginal as String] { m.taken = "\(t)" }
        if let d = tiff[kCGImagePropertyTIFFModel as String] { m.device = "\(d)" }
        if let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double, let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double {
            let ns = (gps[kCGImagePropertyGPSLatitudeRef as String] as? String) == "S" ? -1.0 : 1.0
            let ew = (gps[kCGImagePropertyGPSLongitudeRef as String] as? String) == "W" ? -1.0 : 1.0
            m.hasGPS = true
            m.coordinate = CLLocationCoordinate2D(latitude: lat * ns, longitude: lon * ew)
        }
        return m
    }

    /// Faces and text regions as normalized UIKit rects (origin top-left, 0…1).
    static func detect(_ image: UIImage) -> (faces: [CGRect], text: [CGRect]) {
        guard let cg = image.normalizedUp().cgImage else { return ([], []) }
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        let fr = VNDetectFaceRectanglesRequest()
        let tr = VNRecognizeTextRequest(); tr.recognitionLevel = .fast
        try? handler.perform([fr, tr])
        let faces = (fr.results ?? []).map { flip($0.boundingBox).insetBy(dx: -$0.boundingBox.width * 0.1, dy: -$0.boundingBox.height * 0.12) }
        let text = (tr.results as? [VNRecognizedTextObservation] ?? []).map { flip($0.boundingBox) }
        return (faces, text)
    }

    /// Paint opaque blocks over `rects` (normalized, top-left origin) and return a FRESH JPEG with no
    /// metadata. The output never contains the covered pixels.
    static func render(_ image: UIImage, rects: [CGRect], quality: CGFloat = 0.92) -> Data? {
        let base = image.normalizedUp()
        let size = CGSize(width: base.size.width * base.scale, height: base.size.height * base.scale)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let out = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            for r in rects {
                let px = CGRect(x: r.minX * size.width, y: r.minY * size.height, width: r.width * size.width, height: r.height * size.height)
                    .insetBy(dx: -2, dy: -2).intersection(CGRect(origin: .zero, size: size))
                if !px.isNull { ctx.fill(px) }
            }
        }
        return out.jpegData(compressionQuality: quality)
    }

    /// Small static map with a pin — the "oh, it knows where I live" moment that makes people strip it.
    static func mapSnapshot(_ c: CLLocationCoordinate2D) async -> UIImage? {
        let opts = MKMapSnapshotter.Options()
        opts.region = MKCoordinateRegion(center: c, latitudinalMeters: 2500, longitudinalMeters: 2500)
        opts.size = CGSize(width: 640, height: 220)
        guard let shot = try? await MKMapSnapshotter(options: opts).start() else { return nil }
        return UIGraphicsImageRenderer(size: opts.size).image { _ in
            shot.image.draw(at: .zero)
            let p = shot.point(for: c), r: CGFloat = 11
            UIColor.systemRed.setFill()
            UIBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)).fill()
            UIColor.white.setStroke()
            UIBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)).stroke()
        }
    }

    private static func flip(_ b: CGRect) -> CGRect { CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height) }
}
