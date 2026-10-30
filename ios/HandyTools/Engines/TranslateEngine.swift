import UIKit
import Vision
import Translation

/// One recognised line of text in a photo. `rect` is normalised to the image, origin top-left.
struct TextBlock: Identifiable {
    let id = UUID()
    let text: String
    let rect: CGRect
}

/// The bits of the Translate hub that aren't the Translation framework itself: language-pack state,
/// photo text blocks with positions (Vision), and the "translated text drawn over the original"
/// composite for sharing. All on the phone.
enum TranslateEngine {
    /// Quick-phrase chips from the prototype: chip label + the full phrase.
    struct Phrase: Identifiable { let label: String; let text: String; var id: String { text } }
    static let phrases: [Phrase] = [
        Phrase(label: "Pharmacy", text: "Where is the nearest pharmacy?"),
        Phrase(label: "How much…", text: "How much does this cost?"),
        Phrase(label: "Reservation", text: "I have a reservation."),
        Phrase(label: "Help", text: "Can you help me?"),
        Phrase(label: "Thanks", text: "Thank you very much."),
    ]

    static func name(_ code: String) -> String { Locale.current.localizedString(forLanguageCode: code) ?? code }

    enum PackState { case checking, installed, supported, unsupported }

    /// Is this pair downloaded (offline), downloadable, or not offered by Apple Translation at all?
    static func packState(from: String, to: String) async -> PackState {
        let status = await LanguageAvailability().status(from: Locale.Language(identifier: from), to: Locale.Language(identifier: to))
        switch status {
        case .installed: return .installed
        case .supported: return .supported
        case .unsupported: return .unsupported
        @unknown default: return .unsupported
        }
    }

    /// Every line of text in the photo with where it sits (accurate recognition, on-device).
    static func blocks(_ image: UIImage) -> [TextBlock] {
        guard let cg = image.normalizedUp().cgImage else { return [] }
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        try? handler.perform([req])
        return (req.results ?? []).compactMap { o in
            guard let t = o.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
            let b = o.boundingBox
            return TextBlock(text: t, rect: CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height))
        }
    }

    /// The photo with each translated line drawn over its original block: dark rounded box, white
    /// text shrunk to fit. JPEG data for sharing. Blocks without a translation are left as they are.
    static func render(_ image: UIImage, blocks: [TextBlock], translations: [String]) -> Data? {
        let base = image.normalizedUp()
        let size = CGSize(width: base.size.width * base.scale, height: base.size.height * base.scale)
        guard size.width > 0, size.height > 0 else { return nil }
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let out = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))
            for (i, b) in blocks.enumerated() where i < translations.count && !translations[i].isEmpty {
                let r = CGRect(x: b.rect.minX * size.width, y: b.rect.minY * size.height, width: b.rect.width * size.width, height: b.rect.height * size.height)
                    .insetBy(dx: -4, dy: -3).intersection(CGRect(origin: .zero, size: size))
                guard !r.isNull, r.width > 8, r.height > 6 else { continue }
                UIColor.black.withAlphaComponent(0.8).setFill()
                UIBezierPath(roundedRect: r, cornerRadius: min(8, r.height / 3)).fill()
                let text = translations[i] as NSString
                var fontSize = r.height * 0.72
                var font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
                var w = text.size(withAttributes: [.font: font]).width
                while w > r.width - 8, fontSize > 5 {
                    fontSize *= 0.9
                    font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
                    w = text.size(withAttributes: [.font: font]).width
                }
                let h = font.lineHeight
                text.draw(in: CGRect(x: r.minX + 4, y: r.midY - h / 2, width: r.width - 8, height: h), withAttributes: [.font: font, .foregroundColor: UIColor.white])
            }
        }
        return out.jpegData(compressionQuality: 0.9)
    }
}
