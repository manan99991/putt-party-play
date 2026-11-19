import UIKit

/// Where a page asks to be signed or dated: the "Signature", "Sign here", "Signed" and "Date" labels, read from the
/// page, with the spot just after the label (or on the line above it when the label sits under the line).
enum SignSpots {
    enum Kind: Equatable { case signature, date }
    struct Spot: Equatable { let kind: Kind; let center: CGPoint; let width: CGFloat }

    static func find(_ page: UIImage) -> [Spot] {
        find(lines: DocEngine.recognize(page))
    }

    /// Pure: spots from read lines (normalised, top-left origin).
    static func find(lines: [DocEngine.OCRLine]) -> [Spot] {
        var out: [Spot] = []
        for l in lines {
            let t = l.text.lowercased().trimmingCharacters(in: .whitespaces)
            let kind: Kind?
            if t.range(of: #"\b(signature|sign here|signed|sign)\b"#, options: .regularExpression) != nil, t.count < 60, !t.contains("date") { kind = .signature }
            else if t.range(of: #"^(date|dated|date signed)\b[:\s_.]*$"#, options: .regularExpression) != nil || t.range(of: #"\bdate\s*[:_]{1,}"#, options: .regularExpression) != nil { kind = .date }
            else { kind = nil }
            guard let kind else { continue }
            // Label followed by space on the same line → write after it; a label alone with nothing after → write just above.
            let room = 1 - l.box.maxX
            let width: CGFloat = kind == .signature ? 0.28 : 0.18
            let center: CGPoint
            if room > width + 0.04 {
                center = CGPoint(x: min(0.95 - width / 2, l.box.maxX + 0.02 + width / 2), y: l.box.midY - l.box.height * 0.15)
            } else {
                center = CGPoint(x: l.box.minX + width / 2, y: max(0.03, l.box.minY - l.box.height * 1.1))
            }
            if !out.contains(where: { $0.kind == kind && abs($0.center.y - center.y) < 0.02 && abs($0.center.x - center.x) < 0.1 }) {
                out.append(Spot(kind: kind, center: center, width: width))
            }
        }
        return out
    }

    /// Initials in the bottom-right corner of a page.
    static let initialsSpot = CGPoint(x: 0.9, y: 0.96)
}
