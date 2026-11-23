import Foundation
import UIKit

/// Invoices & quotes for people who run a small business (Business tab, Manan 23 Nov: "give them options if they need
/// help"). Fill in who it's from, who it's for and a few lines; Tenzy works out the totals, makes a clean PDF to send,
/// and remembers which invoices are still unpaid so Home can say when one is overdue. Everything stays on the phone.
/// Free: 3 a month; Tenzy Pro: unlimited. The maths, numbering, allowance and PDF are pure and unit-tested.
enum Invoice {
    enum Kind: String, Codable, CaseIterable { case invoice, quote }

    struct Line: Codable, Equatable, Identifiable {
        var id = UUID()
        var what: String
        var qty: Double
        var price: Double
        var amount: Double { Invoice.round2(qty * price) }
    }

    struct Doc: Codable, Equatable, Identifiable {
        var id = UUID()
        var kind: Kind
        var number: String
        var date: Date
        var due: Date?              // invoice: pay by; quote: valid until
        var from: String
        var to: String
        var lines: [Line]
        var taxPercent: Double
        var notes: String
        var currency: String        // ISO code, e.g. "USD"
        var paid: Bool = false

        var subtotal: Double { Invoice.round2(lines.reduce(0) { $0 + $1.amount }) }
        var tax: Double { Invoice.round2(subtotal * taxPercent / 100) }
        var total: Double { Invoice.round2(subtotal + tax) }

        /// An unpaid invoice whose pay-by day has passed (a quote is never overdue).
        func overdue(now: Date = Date(), cal: Calendar = .current) -> Bool {
            guard kind == .invoice, !paid, let due else { return false }
            return cal.startOfDay(for: due) < cal.startOfDay(for: now)
        }
        /// A line for the list and the For you card: "Acme Plumbing · $1,250.00".
        var who: String { to.split(separator: "\n").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? "" }
    }

    /// Made without Tenzy Pro each calendar month (invoices and quotes together).
    static let freePerMonth = 3

    static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }

    /// The next number for this kind: one past the highest used so far ("INV-0007" after "INV-0006").
    static func nextNumber(_ kind: Kind, after docs: [Doc]) -> String {
        let prefix = kind == .invoice ? "INV-" : "Q-"
        let used = docs.filter { $0.kind == kind }.compactMap { d -> Int? in
            let digits = d.number.reversed().prefix { $0.isNumber }
            return Int(String(digits.reversed()))
        }
        return prefix + String(format: "%04d", (used.max() ?? 0) + 1)
    }

    static func madeThisMonth(_ docs: [Doc], now: Date = Date(), cal: Calendar = .current) -> Int {
        docs.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }.count
    }

    /// How many more can be made this month without Pro (nil: no limit).
    static func left(_ docs: [Doc], premium: Bool, now: Date = Date(), cal: Calendar = .current) -> Int? {
        premium ? nil : max(0, freePerMonth - madeThisMonth(docs, now: now, cal: cal))
    }

    static func money(_ v: Double, currency: String, locale: Locale = .current) -> String {
        v.formatted(.currency(code: currency).locale(locale))
    }

    /// The currency this phone's region uses, or US dollars.
    static var localCurrency: String { Locale.current.currency?.identifier ?? "USD" }
    static let currencies = ["USD", "EUR", "GBP", "CAD", "AUD", "INR", "JPY", "CNY", "BRL", "MXN", "CHF", "NZD", "SGD", "ZAR", "AED"]

    /// Paper: US Letter where people use it, A4 everywhere else.
    static func pageSize(region: String? = Locale.current.region?.identifier) -> CGSize {
        ["US", "CA", "MX", "PH", "CL", "CO", "VE"].contains(region ?? "") ? CGSize(width: 612, height: 792) : CGSize(width: 595, height: 842)
    }

    // MARK: - PDF

    /// A clean one-colour PDF: the title and number, from / bill to, the lines, the totals, notes. Long lists continue on
    /// further pages with the column heads repeated.
    static func pdf(_ d: Doc, page: CGSize = pageSize(), locale: Locale = .current) -> Data {
        let m: CGFloat = 48
        let r = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: page))
        let ink = UIColor(white: 0.08, alpha: 1), grey = UIColor(white: 0.42, alpha: 1), rule = UIColor(white: 0.84, alpha: 1)
        let accent = UIColor(red: 0.05, green: 0.58, blue: 0.53, alpha: 1)
        func font(_ s: CGFloat, _ w: UIFont.Weight = .regular) -> UIFont { .systemFont(ofSize: s, weight: w) }
        let money: (Double) -> String = { Invoice.money($0, currency: d.currency, locale: locale) }
        let date: (Date) -> String = { $0.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)) }
        let isQuote = d.kind == .quote
        let colAmt = page.width - m, colUnit = colAmt - 96, colQty = colUnit - 92
        let descWidth = colQty - 52 - m

        return r.pdfData { ctx in
            var y: CGFloat = 0
            func text(_ s: String, _ x: CGFloat, _ f: UIFont, _ c: UIColor, right: Bool = false, width: CGFloat? = nil) -> CGFloat {
                let attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: c]
                let ns = s as NSString
                if right {
                    let w = ns.size(withAttributes: attrs).width
                    ns.draw(at: CGPoint(x: x - w, y: y), withAttributes: attrs)
                    return ceil(f.lineHeight)
                }
                let box = ns.boundingRect(with: CGSize(width: width ?? (page.width - x - m), height: 2000),
                                          options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                ns.draw(with: CGRect(x: x, y: y, width: width ?? (page.width - x - m), height: ceil(box.height)),
                        options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                return ceil(box.height)
            }
            func line(_ x0: CGFloat, _ x1: CGFloat) {
                rule.setFill(); UIRectFill(CGRect(x: x0, y: y, width: x1 - x0, height: 0.75))
            }
            func heads() {
                _ = text(L("Description"), m, font(10, .semibold), grey)
                _ = text(L("Qty"), colQty, font(10, .semibold), grey, right: true)
                _ = text(L("Price"), colUnit, font(10, .semibold), grey, right: true)
                _ = text(L("Amount"), colAmt, font(10, .semibold), grey, right: true)
                y += 16; line(m, colAmt); y += 10
            }

            ctx.beginPage()
            y = m
            accent.setFill(); UIRectFill(CGRect(x: m, y: y, width: 36, height: 4)); y += 14
            y += text(L(isQuote ? "QUOTE" : "INVOICE"), m, font(26, .bold), ink)
            var meta = "\(d.number)  ·  \(date(d.date))"
            if let due = d.due { meta += "  ·  " + (isQuote ? L("Valid until") : L("Due")) + " " + date(due) }
            y += 4; y += text(meta, m, font(11), grey) + 22

            let top = y, half = (page.width - 2 * m) / 2
            y += text(L("FROM"), m, font(9, .semibold), grey) + 3
            let hFrom = text(d.from, m, font(11.5), ink, width: half - 16)
            y = top
            y += text(isQuote ? L("FOR") : L("BILL TO"), m + half, font(9, .semibold), grey) + 3
            let hTo = text(d.to, m + half, font(11.5), ink, width: half)
            y += max(hFrom, hTo) + 26

            heads()
            for l in d.lines where !l.what.trimmingCharacters(in: .whitespaces).isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: font(11.5)]
                let h = ceil((l.what as NSString).boundingRect(with: CGSize(width: descWidth, height: 2000), options: [.usesLineFragmentOrigin], attributes: attrs, context: nil).height)
                if y + h > page.height - m - 40 { ctx.beginPage(); y = m; heads() }
                _ = text(l.what, m, font(11.5), ink, width: descWidth)
                _ = text(Invoice.qty(l.qty), colQty, font(11.5), ink, right: true)
                _ = text(money(l.price), colUnit, font(11.5), ink, right: true)
                _ = text(money(l.amount), colAmt, font(11.5), ink, right: true)
                y += max(h, 15) + 9
            }

            if y > page.height - m - 120 { ctx.beginPage(); y = m }
            y += 4; line(colQty - 40, colAmt); y += 10
            _ = text(L("Subtotal"), colUnit, font(11.5), grey, right: true); y += text(money(d.subtotal), colAmt, font(11.5), ink, right: true) + 4
            if d.taxPercent > 0 {
                _ = text(L("Tax") + " (\(Invoice.qty(d.taxPercent))%)", colUnit, font(11.5), grey, right: true)
                y += text(money(d.tax), colAmt, font(11.5), ink, right: true) + 4
            }
            y += 2
            _ = text(L("Total"), colUnit, font(14, .bold), ink, right: true); y += text(money(d.total), colAmt, font(14, .bold), ink, right: true) + 28

            let notes = d.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty {
                if y > page.height - m - 60 { ctx.beginPage(); y = m }
                y += text(L("NOTES"), m, font(9, .semibold), grey) + 3
                y += text(notes, m, font(11), ink)
            }
        }
    }

    /// 2 not 2.0; 1.5 stays 1.5.
    static func qty(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%g", v)
    }

    /// The file name people see when they send it: "Invoice INV-0003.pdf".
    static func fileName(_ d: Doc) -> String {
        (d.kind == .quote ? "Quote " : "Invoice ") + d.number.replacingOccurrences(of: "/", with: "-") + ".pdf"
    }
}

/// The invoices and quotes made on this phone, and the business details people type once.
@MainActor
final class InvoiceStore: ObservableObject {
    static let shared = InvoiceStore()
    @Published private(set) var docs: [Invoice.Doc] = []
    private let url: URL

    init(folder: URL? = nil) {
        let base = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Invoices", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("invoices.json")
        if let data = try? Data(contentsOf: url), let d = try? JSONDecoder().decode([Invoice.Doc].self, from: data) { docs = d }
    }

    /// Who it's from, typed once and remembered.
    static let fromKey = "invoice.from", currencyKey = "invoice.currency", taxKey = "invoice.tax"

    func add(_ d: Invoice.Doc) { docs.insert(d, at: 0); save() }
    func setPaid(_ id: UUID, _ paid: Bool) {
        guard let i = docs.firstIndex(where: { $0.id == id }) else { return }
        docs[i].paid = paid; save()
    }
    func remove(_ id: UUID) { docs.removeAll { $0.id == id }; save() }

    /// Unpaid invoices, overdue first.
    var unpaid: [Invoice.Doc] {
        docs.filter { $0.kind == .invoice && !$0.paid }
            .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(docs) {
            try? data.write(to: url, options: [.atomic, .completeFileProtection])
        }
    }

    /// Writes the PDF to a temporary file named for sending.
    static func file(for d: Invoice.Doc) -> URL? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Invoices", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let u = dir.appendingPathComponent(Invoice.fileName(d))
        do { try Invoice.pdf(d).write(to: u, options: .atomic); return u } catch { return nil }
    }
}
