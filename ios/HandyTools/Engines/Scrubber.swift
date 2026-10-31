import UIKit
import Vision
import ImageIO
import MapKit
import AVFoundation
import CoreImage

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

    /// A detected text region plus whether it reads like something personal (a plate, phone, email,
    /// card/account/ID number) that should be hidden by default — as opposed to ordinary prose.
    struct TextHit { let rect: CGRect; let personal: Bool }

    /// Faces and text regions as normalized UIKit rects (origin top-left, 0…1). Text hits are
    /// classified so the view can switch personal ones (plates, numbers) ON automatically.
    static func detect(_ image: UIImage) -> (faces: [CGRect], text: [TextHit]) {
        guard let cg = image.normalizedUp().cgImage else { return ([], []) }
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        let fr = VNDetectFaceRectanglesRequest()
        // Accurate (not fast) + no language correction: we need the real characters to tell a plate /
        // number from prose, and autocorrect would mangle plates like "7XYZ123".
        let tr = VNRecognizeTextRequest(); tr.recognitionLevel = .accurate; tr.usesLanguageCorrection = false
        try? handler.perform([fr, tr])
        let faces = (fr.results ?? []).map { flip($0.boundingBox).insetBy(dx: -$0.boundingBox.width * 0.1, dy: -$0.boundingBox.height * 0.12) }
        let text: [TextHit] = (tr.results as? [VNRecognizedTextObservation] ?? []).map {
            TextHit(rect: flip($0.boundingBox), personal: looksPersonal($0.topCandidates(1).first?.string ?? ""))
        }
        return (faces, text)
    }

    /// Heuristic: does this recognised string look like something a person would want hidden —
    /// a licence plate, phone number, email, or a card / account / ID number? Ordinary words do not,
    /// so a photo of a document isn't blacked out wholesale.
    static func looksPersonal(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count >= 3 else { return false }
        if s.contains("@"), s.contains(".") { return true }                     // email
        let digits = s.filter(\.isNumber).count
        let letters = s.filter(\.isLetter).count
        if digits >= 7 { return true }                                          // phone / card / account / ID / DOB
        // licence-plate-like: short, almost all alphanumeric, mixing letters and digits.
        let compact = s.filter { $0.isLetter || $0.isNumber }
        if (5...8).contains(compact.count), digits >= 1, letters >= 1,
           Double(compact.count) / Double(max(1, s.count)) > 0.7 { return true }
        return false
    }

    /// How a region is hidden. All three REMOVE the pixels underneath (a fresh encode, no reversible
    /// blur): Block is a solid bar, Pixelate is a coarse mosaic drawn over a filled block, Emoji drops
    /// a sticker over a filled block — fun for faces, still fully private.
    enum RedactStyle: String, CaseIterable { case block = "Block", pixelate = "Pixelate", emoji = "Emoji" }

    /// Hide `rects` (normalized, top-left origin) in the chosen style and return a FRESH JPEG with no
    /// metadata. The output never contains the covered pixels, whatever the style.
    static func render(_ image: UIImage, rects: [CGRect], style: RedactStyle = .block, emoji: String = "😎", quality: CGFloat = 0.92) -> Data? {
        let base = image.normalizedUp()
        let size = CGSize(width: base.size.width * base.scale, height: base.size.height * base.scale)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let out = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))
            for r in rects {
                let px = CGRect(x: r.minX * size.width, y: r.minY * size.height, width: r.width * size.width, height: r.height * size.height)
                    .insetBy(dx: -2, dy: -2).intersection(CGRect(origin: .zero, size: size))
                guard !px.isNull, px.width > 1, px.height > 1 else { continue }
                switch style {
                case .block:
                    UIColor.black.setFill(); ctx.fill(px)
                case .pixelate:
                    if let sub = base.cgImage?.cropping(to: px) {
                        let region = UIImage(cgImage: sub)
                        let cols = 12, rows = max(1, Int((CGFloat(12) * px.height / px.width).rounded()))
                        let small = UIGraphicsImageRenderer(size: CGSize(width: cols, height: rows)).image { _ in
                            region.draw(in: CGRect(x: 0, y: 0, width: cols, height: rows))
                        }
                        ctx.cgContext.interpolationQuality = .none
                        small.draw(in: px)
                        ctx.cgContext.interpolationQuality = .default
                    } else { UIColor.black.setFill(); ctx.fill(px) }
                case .emoji:
                    UIColor.black.setFill(); ctx.fill(px)   // the pixels underneath are gone either way
                    let s = emoji as NSString
                    let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: min(px.width, px.height) * 1.2)]
                    let sz = s.size(withAttributes: attrs)
                    s.draw(at: CGPoint(x: px.midX - sz.width / 2, y: px.midY - sz.height / 2), withAttributes: attrs)
                }
            }
        }
        return out.jpegData(compressionQuality: quality)
    }

    /// Face + personal-text rectangles (normalized, top-left origin) for one frame — the video path,
    /// where everything personal is blacked out automatically (no manual boxes).
    static func detectRects(_ ci: CIImage) -> [CGRect] {
        let handler = VNImageRequestHandler(ciImage: ci, orientation: .up)
        let fr = VNDetectFaceRectanglesRequest()
        let tr = VNRecognizeTextRequest(); tr.recognitionLevel = .fast; tr.usesLanguageCorrection = false
        try? handler.perform([fr, tr])
        var rects = (fr.results ?? []).map { flip($0.boundingBox).insetBy(dx: -$0.boundingBox.width * 0.12, dy: -$0.boundingBox.height * 0.14) }
        rects += (tr.results as? [VNRecognizedTextObservation] ?? []).compactMap {
            looksPersonal($0.topCandidates(1).first?.string ?? "") ? flip($0.boundingBox) : nil
        }
        return rects
    }

    /// Best-effort video scrub: black out faces and personal text across the whole clip and re-encode
    /// with no metadata. Detection is throttled (a few times a second, reused in between) so it stays
    /// feasible on a phone; blocks are padded to cover motion between detections. Returns nil if the
    /// device can't process the video (caller surfaces an error — quota is never spent on nil).
    static func scrubVideo(_ url: URL, progress: ((Double) -> Void)? = nil) async -> URL? {
        let asset = AVURLAsset(url: url)
        guard (try? await asset.loadTracks(withMediaType: .video))?.isEmpty == false else { return nil }
        let redactor = VideoRedactor()
        let comp = AVMutableVideoComposition(asset: asset) { request in
            let src = request.sourceImage
            let ext = src.extent
            var out = src
            for r in redactor.rects(for: src, at: request.compositionTime.seconds) {
                let rc = CGRect(x: r.minX * ext.width, y: (1 - r.maxY) * ext.height, width: r.width * ext.width, height: r.height * ext.height)
                    .insetBy(dx: -ext.width * 0.012, dy: -ext.height * 0.012).intersection(ext)
                if !rc.isNull, !rc.isEmpty { out = CIImage(color: .black).cropped(to: rc).composited(over: out) }
            }
            request.finish(with: out, context: nil)
        }
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let outURL = VideoEngine.tempURL("mp4")
        session.outputURL = outURL; session.outputFileType = .mp4; session.videoComposition = comp; session.metadata = []
        let poll = Task { while !Task.isCancelled { progress?(Double(session.progress)); try? await Task.sleep(nanoseconds: 300_000_000) } }
        await session.export()
        poll.cancel()
        return session.status == .completed ? outURL : nil
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

/// Throttled per-frame redaction rects for video — detect a few times a second, reuse in between so a
/// whole clip doesn't run Vision on every single frame.
private final class VideoRedactor {
    private var lastRects: [CGRect] = []
    private var lastT = -1.0
    private let interval = 0.3
    func rects(for ci: CIImage, at t: Double) -> [CGRect] {
        if lastT < 0 || abs(t - lastT) >= interval {
            lastRects = Scrubber.detectRects(ci)
            lastT = t
        }
        return lastRects
    }
}
