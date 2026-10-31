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

        // Classify the main subject. Saliency gives us a crop so background clutter doesn't win.
        let subject = subjectCrop(cg) ?? cg
        let classify = VNClassifyImageRequest()
        try? VNImageRequestHandler(cgImage: subject, orientation: .up).perform([classify])
        let guesses = (classify.results as? [VNClassificationObservation] ?? [])
            .filter { $0.hasMinimumRecall(0.01, forPrecision: 0.3) || $0.confidence > 0.1 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(5)
            .map { Guess(label: cleanLabel($0.identifier), confidence: Double($0.confidence)) }

        return Outcome(guesses: Array(guesses), barcode: payload, symbology: symbology)
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
