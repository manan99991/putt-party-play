import UIKit
import PDFKit

/// Redact's helpers: find the personal details on a page for you (account and card numbers, phone numbers,
/// emails, addresses, ID numbers), and prove afterwards that what was hidden really is gone — by searching the
/// finished file's text and a fresh read of every page for each hidden word.
enum RedactFinder {
    /// Boxes (normalised, top-left origin) over the personal details on one page.
    static func find(_ page: UIImage) -> [CGRect] {
        let lines = DocEngine.recognize(page)
        let address = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue | NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
        return lines.compactMap { l in
            let t = l.text
            let personal = Scrubber.looksPersonal(t)
                || t.range(of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.regularExpression, .caseInsensitive]) != nil
                || t.range(of: #"\b(account|acct|sort code|routing|iban|swift|ssn|social security|passport|licen[cs]e|member|policy)\b.{0,12}[A-Z0-9-]{4,}"#, options: [.regularExpression, .caseInsensitive]) != nil
                || (address?.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil)
            return personal ? l.box.insetBy(dx: -0.004, dy: -0.003) : nil
        }
    }

    /// The words under the boxes on each page (what the person meant to hide).
    static func hiddenWords(pages: [UIImage], boxes: [[CGRect]]) -> [String] {
        var out: [String] = []
        for (i, img) in pages.enumerated() where i < boxes.count && !boxes[i].isEmpty {
            for l in DocEngine.recognize(img) where boxes[i].contains(where: { covered(l.box, by: $0) > 0.5 }) {
                out += l.text.split(whereSeparator: { $0.isWhitespace }).map { norm(String($0)) }.filter { $0.count >= 3 }
            }
        }
        return Array(Set(out)).sorted()
    }

    struct Proof: Equatable { let checked: Int; let stillFound: [String] }

    /// Every hidden word searched for in the finished file — its own text, and a fresh read of each page.
    static func proof(hidden: [String], result: Data) -> Proof {
        guard let doc = PDFDocument(data: result) else { return Proof(checked: hidden.count, stillFound: hidden) }
        var text = norm(doc.string ?? "")
        for i in 0..<doc.pageCount {
            guard let p = doc.page(at: i) else { continue }
            let img = PDFSearchable.render(p, maxWidth: 1600)
            text += " " + norm(DocEngine.recognize(img).map(\.text).joined(separator: " "))
        }
        return Proof(checked: hidden.count, stillFound: hidden.filter { text.contains($0) })
    }

    static func norm(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " } }

    /// How much of `a` lies inside `b`.
    static func covered(_ a: CGRect, by b: CGRect) -> CGFloat {
        let i = a.intersection(b)
        guard !i.isNull, a.width > 0, a.height > 0 else { return 0 }
        return (i.width * i.height) / (a.width * a.height)
    }
}
