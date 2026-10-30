import UIKit
import Foundation

/// The Capture hub's "Or try a sample" images — the prototype's four placeholders (receipt, business
/// card, event flyer, document) drawn on the fly, so a tester with nothing to scan still sees the
/// whole recognised flow. The same text is kept as a fallback for when OCR on the drawn bitmap comes
/// back thin (a simulator without Vision models, say) — the flow never dead-ends on a sample.
enum CaptureSamples {
    enum Kind: String, CaseIterable, Identifiable {
        case receipt = "Receipt", card = "Business card", flyer = "Event flyer", doc = "Document"
        var id: String { rawValue }
    }

    static func lines(_ k: Kind) -> [String] {
        switch k {
        case .receipt: return ["WHOLE FOODS MARKET", "", "Organic bananas      3.49", "Oat milk             4.99", "Sourdough            6.50", "Coffee beans        14.99", "Greens               5.21", "", "TOTAL              $42.18", "VISA ****4821", "14 JUN 2026 10:42"]
        case .card:    return ["", "  Priya Natarajan", "  Head of Partnerships", "  Northwind Labs", "", "  priya@northwind.io", "  +1 (312) 555-0148", "  northwind.io"]
        case .flyer:   return ["", "   SUMMER BLOCK PARTY", "", "   Sat 18 Jul 2026 · 4–9 PM", "   Riverside Park, Naperville", "", "   Live music · Food trucks", "   Free entry"]
        case .doc:     return ["SERVICE AGREEMENT", "", "This agreement is made between", "Northwind Labs (\"Provider\") and", "the Client, effective 1 Aug 2026.", "", "1. Scope. Provider will deliver the services in Schedule A.", "2. Term. Twelve (12) months.", "3. Fees. As set out in Schedule A."]
        }
    }

    static func text(_ k: Kind) -> String { lines(k).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n") }

    /// A deterministic "photo" of the sample — same palette as the prototype's canvas placeholders.
    static func image(_ k: Kind) -> UIImage {
        let size = CGSize(width: 1200, height: k == .card ? 720 : 920)
        let (bg, fg): (UIColor, UIColor) = {
            switch k {
            case .receipt: return (UIColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 1), UIColor(white: 0.13, alpha: 1))
            case .card:    return (UIColor(red: 0.12, green: 0.16, blue: 0.27, alpha: 1), .white)
            case .flyer:   return (UIColor(red: 0.48, green: 0.17, blue: 1.0, alpha: 1), .white)
            case .doc:     return (.white, UIColor(white: 0.13, alpha: 1))
            }
        }()
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            bg.setFill(); c.fill(CGRect(origin: .zero, size: size))
            let font = k == .receipt ? UIFont.monospacedSystemFont(ofSize: 44, weight: .semibold) : UIFont.systemFont(ofSize: 46, weight: .bold)
            for (i, l) in lines(k).enumerated() {
                (l as NSString).draw(at: CGPoint(x: 60, y: 70 + CGFloat(i) * 72), withAttributes: [.font: font, .foregroundColor: fg])
            }
        }
    }
}

/// Turns a photo's text into "what is it + the fields + the next steps" for the Capture hub. Detection
/// and field extraction are DataGrab's rules; the document type guess is Sorted's. Pure, testable.
enum CaptureFlow {
    struct Result {
        let image: UIImage
        let text: String
        let kind: CaptureSamples.Kind?      // nil → no text found
        let sample: CaptureSamples.Kind?    // which sample chip produced it, if any
        let receipt: DataGrab.Receipt
        let card: DataGrab.Card
        let event: DataGrab.Event
        let fields: [(String, String)]
        let pdf: Data?
        var words: Int { text.split { $0.isWhitespace || $0.isNewline }.count }
    }

    static func kind(for text: String) -> CaptureSamples.Kind {
        switch DataGrab.detect(text) {
        case .receipt: return .receipt
        case .card: return .card
        case .event: return .flyer
        case .table, .text: return .doc
        }
    }

    static func build(image: UIImage, text: String, forced: CaptureSamples.Kind?, pdf: Data?) -> Result {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 3 else {
            return Result(image: image, text: "", kind: nil, sample: forced, receipt: DataGrab.Receipt(), card: DataGrab.Card(), event: DataGrab.Event(), fields: [], pdf: pdf)
        }
        let k = forced ?? kind(for: clean)
        var receipt = DataGrab.Receipt(), card = DataGrab.Card(), event = DataGrab.Event()
        var fields: [(String, String)] = []
        switch k {
        case .receipt:
            receipt = DataGrab.receipt(clean)
            if !receipt.merchant.isEmpty { fields.append(("Merchant", receipt.merchant)) }
            if let d = receipt.date { fields.append(("Date", d.formatted(date: .abbreviated, time: .omitted))) }
            if let t = receipt.total { fields.append(("Total", money(t, receipt.currency))) }
            if !receipt.items.isEmpty { fields.append(("Items", "\(receipt.items.count)")) }
            if let cardLine = clean.components(separatedBy: .newlines).first(where: { $0.range(of: #"(?i)\b(visa|mastercard|amex|debit|credit)\b"#, options: .regularExpression) != nil }) { fields.append(("Card", cardLine.trimmingCharacters(in: .whitespaces))) }
        case .card:
            card = DataGrab.card(clean)
            if !card.name.isEmpty { fields.append(("Name", card.name)) }
            if !card.title.isEmpty { fields.append(("Title", card.title)) }
            if !card.company.isEmpty { fields.append(("Company", card.company)) }
            if let e = card.emails.first { fields.append(("Email", e)) }
            if let p = card.phones.first { fields.append(("Phone", p)) }
            if !card.website.isEmpty { fields.append(("Website", card.website)) }
        case .flyer:
            event = DataGrab.event(clean)
            if event.location.isEmpty { event.location = venueLine(in: clean) }
            fields.append(("Event", event.title))
            if let s = event.start { fields.append(("When", s.formatted(date: .abbreviated, time: .shortened))) }
            if !event.location.isEmpty { fields.append(("Where", event.location)) }
        case .doc:
            fields.append(("Type", docType(clean)))
            fields.append(("Pages", "1"))
            fields.append(("Words", "\(clean.split { $0.isWhitespace || $0.isNewline }.count)"))
        }
        return Result(image: image, text: clean, kind: k, sample: forced, receipt: receipt, card: card, event: event, fields: fields, pdf: pdf)
    }

    static func money(_ v: Double, _ currency: String) -> String { (currency.isEmpty ? "" : currency) + String(format: "%.2f", v) }

    static func docType(_ text: String) -> String {
        let t = text.lowercased()
        if t.contains("agreement") || t.contains("contract") || t.contains("terms") { return "Agreement" }
        if t.contains("menu") { return "Menu" }
        if t.contains("warning") || t.contains("caution") || t.contains("danger") { return "Sign" }
        let k = SortedEngine.guessKind(text)
        return k == "Document" ? "Text" : k
    }

    /// A line that reads like a venue — used when the system address detector finds nothing.
    static func venueLine(in text: String) -> String {
        let venue = #"(?i)\b(park|hall|street|st\.?|avenue|ave\.?|road|rd\.?|center|centre|blvd|arena|stadium|theatre|theater|club|hotel|library|church|school|plaza|square|room)\b"#
        return text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.range(of: venue, options: .regularExpression) != nil && $0.count < 60 } ?? ""
    }

    /// A one-line summary to share or read aloud.
    static func spoken(_ r: Result) -> String {
        guard let k = r.kind else { return "" }
        switch k {
        case .receipt: return [r.receipt.merchant, r.receipt.date.map { $0.formatted(date: .long, time: .omitted) } ?? "", r.receipt.total.map { "total " + money($0, r.receipt.currency) } ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
        case .card: return [r.card.name, r.card.title, r.card.company].filter { !$0.isEmpty }.joined(separator: ", ")
        case .flyer: return [r.event.title, r.event.start.map { $0.formatted(date: .long, time: .shortened) } ?? "", r.event.location].filter { !$0.isEmpty }.joined(separator: ", ")
        case .doc: return r.text
        }
    }

    // MARK: receipts folder

    /// Saves the receipt as a CSV in Documents/Receipts and returns the file. The folder is the app's
    /// own, so it needs no permission and survives relaunches.
    @discardableResult
    static func saveReceipt(_ r: DataGrab.Receipt) -> URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let dir = docs.appendingPathComponent("Receipts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let slug = r.merchant.lowercased().replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let url = dir.appendingPathComponent("\(slug.isEmpty ? "receipt" : slug)-\(f.string(from: r.date ?? Date())).csv")
        let body = DataGrab.expenseRow(r) + "\n\n" + DataGrab.receiptCSV(r)
        guard (try? body.write(to: url, atomically: true, encoding: .utf8)) != nil else { return nil }
        return url
    }
}
