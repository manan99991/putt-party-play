import Vision
import UIKit

/// Identify — "what is this?" On-device image recognition gives the best guesses with how sure it is,
/// reads any barcode, and (honestly) hands off to a web search to confirm the specifics it can't know
/// locally. It crops to the main subject first so a bee on a flower is identified as the bee.
enum Identifier {
    struct Guess: Identifiable { let id = UUID(); let label: String; let confidence: Double }
    struct Outcome { let guesses: [Guess]; let barcode: String?; let symbology: String? }

    static func identify(_ image: UIImage) async -> Outcome {
        guard let cg = image.normalizedUp().cgImage else { return Outcome(guesses: [], barcode: nil, symbology: nil) }

        // Barcode first — a product barcode is a definite answer, not a guess.
        let barcodeReq = VNDetectBarcodesRequest()
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([barcodeReq])
        let bc = (barcodeReq.results)?.first
        let payload = bc?.payloadStringValue
        let symbology = bc.map { prettySymbology($0.symbology) }

        // Classify the whole picture AND zoomed-in windows of it. One pass over the whole frame is
        // dominated by whatever fills it (people, clothing, sky), so a small subject like a statue in the
        // distance never surfaced. Looking at crops at two zoom levels finds it; the best confidence for
        // each label across all views wins.
        var views: [CGImage] = [cg]
        if let subject = subjectCrop(cg) { views.append(subject) }
        views += windows(of: cg, fraction: 0.5)
        views += windows(of: cg, fraction: 0.33)

        let frames = views
        let box = Merge()
        DispatchQueue.concurrentPerform(iterations: frames.count) { i in
            let req = VNClassifyImageRequest()
            try? VNImageRequestHandler(cgImage: frames[i], orientation: .up).perform([req])
            box.add((req.results ?? []).filter { $0.confidence > 0.08 }.map { ($0.identifier, Double($0.confidence)) })
        }
        let best = box.best

        // Generic "what's in every photo of people/sky" labels would always win; rank specific ones first
        // (they're still shown if nothing more specific was found).
        let ranked = best.map { (id: $0.key, conf: $0.value, score: $0.value * (generic.contains($0.key.lowercased()) ? 0.35 : 1)) }
            .sorted { $0.score > $1.score }
            .prefix(6)
            .map { Guess(label: cleanLabel($0.id), confidence: $0.conf) }

        return Outcome(guesses: Array(ranked), barcode: payload, symbology: symbology)
    }

    /// Thread-safe "best confidence per label" accumulator for the parallel classification passes.
    private final class Merge: @unchecked Sendable {
        private let lock = NSLock()
        private var map: [String: Double] = [:]
        func add(_ items: [(String, Double)]) { lock.lock(); for (k, v) in items { map[k] = max(map[k] ?? 0, v) }; lock.unlock() }
        var best: [String: Double] { lock.lock(); defer { lock.unlock() }; return map }
    }

    /// Labels that describe nearly any photo with people, sky or ground in it.
    private static let generic: Set<String> = [
        "clothing", "jeans", "footwear", "shoes", "shoe", "boot", "people", "adult", "crowd", "person", "outerwear", "jacket", "hat",
        "headwear", "portrait", "face", "hair", "sky", "cloudy", "cloud", "outdoor", "structure", "water", "material", "wood_processed",
        "textile", "fabric", "denim", "sportswear", "t_shirt", "shirt", "pants", "coat", "sweater", "hoodie", "sunglasses", "glasses",
        "machine", "vehicle", "land", "ground", "floor", "wall", "plant", "tree", "vegetation", "grass"
    ]

    /// Overlapping square-ish windows covering the picture, each `fraction` of its size, stepping by half a window.
    private static func windows(of cg: CGImage, fraction: CGFloat) -> [CGImage] {
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let cw = w * fraction, ch = h * fraction
        guard cw >= 64, ch >= 64 else { return [] }
        var out: [CGImage] = []
        var y: CGFloat = 0
        while y + ch <= h + 1 {
            var x: CGFloat = 0
            while x + cw <= w + 1 {
                if let c = cg.cropping(to: CGRect(x: x, y: y, width: cw, height: ch).integral) { out.append(c) }
                x += cw / 2
            }
            y += ch / 2
        }
        return out
    }

    /// Turn a raw classifier identifier ("golden_retriever") into something a person reads
    /// ("Golden Retriever").
    static func cleanLabel(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    /// A tight crop around the most salient region, so classification focuses on the actual subject.
    private static func subjectCrop(_ cg: CGImage) -> CGImage? {
        let req = VNGenerateObjectnessBasedSaliencyImageRequest()
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
        guard let obj = req.results?.first as? VNSaliencyImageObservation,
              let salient = obj.salientObjects?.max(by: { $0.confidence < $1.confidence }) else { return nil }
        let b = salient.boundingBox
        // Pad the box a little and convert from normalized (bottom-left) to pixel (top-left) space.
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let rect = CGRect(x: b.minX * w, y: (1 - b.maxY) * h, width: b.width * w, height: b.height * h)
            .insetBy(dx: -b.width * w * 0.08, dy: -b.height * h * 0.08)
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard !rect.isNull, rect.width > w * 0.15, rect.height > h * 0.15 else { return nil }
        return cg.cropping(to: rect)
    }

    private static func prettySymbology(_ s: VNBarcodeSymbology) -> String {
        switch s {
        case .ean13, .ean8, .upce: return "Product barcode"
        case .qr: return "QR code"
        case .code128, .code39, .code93: return "Barcode"
        default: return "Barcode"
        }
    }
}
