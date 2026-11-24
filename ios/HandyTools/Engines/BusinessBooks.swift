import Foundation
import UIKit

/// Business miles (Business tab, 24 Nov): log a drive in a few seconds — where, why, how far — and see this month's
/// and this year's miles with a rough deduction at the IRS standard rate. Hand the log to an accountant as a
/// spreadsheet. Money content is general guidance only: the estimate says so, and the rate is the published one.
enum Mileage {
    enum Purpose: String, Codable, CaseIterable, Identifiable {
        case business, medical, charity
        var id: String { rawValue }
        var title: String {
            switch self {
            case .business: return "Business"
            case .medical: return "Medical"
            case .charity: return "Charity"
            }
        }
    }

    struct Trip: Codable, Equatable, Identifiable {
        var id = UUID()
        var date: Date
        var from: String
        var to: String
        var why: String
        var miles: Double
        var roundTrip: Bool = false
        var purpose: Purpose = .business
        /// The distance that counts: there and back when it's a round trip.
        var counted: Double { Mileage.round1(roundTrip ? miles * 2 : miles) }
    }

    /// IRS standard mileage rates in dollars a mile (irs.gov, IR-2025-128: 2026 business 72.5¢, medical 20.5¢, charity
    /// 14¢; 2025 business 70¢, medical 21¢, charity 14¢). A year not listed uses the newest one we know, said as such.
    static let rates: [Int: [Purpose: Double]] = [
        2025: [.business: 0.70, .medical: 0.21, .charity: 0.14],
        2026: [.business: 0.725, .medical: 0.205, .charity: 0.14],
    ]
    static func rate(_ p: Purpose, year: Int) -> (rate: Double, year: Int) {
        let y = rates[year] != nil ? year : (rates.keys.filter { $0 <= year }.max() ?? rates.keys.max()!)
        return (rates[y]?[p] ?? 0, y)
    }

    static func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
    static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }

    struct Totals: Equatable {
        var miles: [Purpose: Double] = [:]
        var estimate: Double = 0
        var trips = 0
        var total: Double { Mileage.round1(miles.values.reduce(0, +)) }
    }

    /// Miles by purpose and the rough deduction for the trips in a period (a month or a year).
    static func totals(_ trips: [Trip], in period: Calendar.Component, of day: Date, cal: Calendar = .current) -> Totals {
        var t = Totals()
        for trip in trips where cal.isDate(trip.date, equalTo: day, toGranularity: period) {
            t.trips += 1
            t.miles[trip.purpose, default: 0] = round1(t.miles[trip.purpose, default: 0] + trip.counted)
            t.estimate += trip.counted * rate(trip.purpose, year: cal.component(.year, from: trip.date)).rate
        }
        t.estimate = round2(t.estimate)
        return t
    }

    /// The places and reasons used before, most used first — one tap fills them in again.
    static func usual(_ trips: [Trip], limit: Int = 4) -> [Trip] {
        var seen: [String: (Trip, Int)] = [:]
        for t in trips {
            let k = "\(t.from.lowercased())→\(t.to.lowercased())→\(t.why.lowercased())"
            seen[k] = (seen[k]?.0 ?? t, (seen[k]?.1 ?? 0) + 1)
        }
        return seen.values.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.date > $1.0.date }.prefix(limit).map(\.0)
    }

    /// A spreadsheet the accountant can open in Numbers or Excel: one row a trip, then the totals.
    static func csv(_ trips: [Trip], locale: Locale = Locale(identifier: "en_US_POSIX")) -> String {
        func cell(_ s: String) -> String { s.contains(where: { ",\"\n".contains($0) }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s }
        let df = DateFormatter(); df.locale = locale; df.dateFormat = "yyyy-MM-dd"
        var rows = ["Date,From,To,Purpose,Why,Round trip,Miles,Rate ($/mile),Estimate ($)"]
        var miles = 0.0, est = 0.0
        for t in trips.sorted(by: { $0.date < $1.date }) {
            let r = rate(t.purpose, year: Calendar(identifier: .gregorian).component(.year, from: t.date)).rate
            let e = round2(t.counted * r)
            miles += t.counted; est += e
            rows.append([df.string(from: t.date), cell(t.from), cell(t.to), t.purpose.title, cell(t.why), t.roundTrip ? "Yes" : "No",
                         String(format: "%.1f", t.counted), String(format: "%.3f", r), String(format: "%.2f", e)].joined(separator: ","))
        }
        rows.append(["Total", "", "", "", "", "", String(format: "%.1f", round1(miles)), "", String(format: "%.2f", round2(est))].joined(separator: ","))
        return rows.joined(separator: "\n") + "\n"
    }

    /// "Mileage 2026.csv"
    static func fileName(year: Int) -> String { "Mileage \(year).csv" }
}

/// The trips logged on this phone.
@MainActor
final class MileageStore: ObservableObject {
    static let shared = MileageStore()
    @Published private(set) var trips: [Mileage.Trip] = []
    private let url: URL

    init(folder: URL? = nil) {
        let base = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Business", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("mileage.json")
        if let data = try? Data(contentsOf: url), let t = try? JSONDecoder().decode([Mileage.Trip].self, from: data) { trips = t }
    }
    func add(_ t: Mileage.Trip) { trips.insert(t, at: 0); trips.sort { $0.date > $1.date }; save() }
    func remove(_ id: UUID) { trips.removeAll { $0.id == id }; save() }
    private func save() {
        if let data = try? JSONEncoder().encode(trips) { try? data.write(to: url, options: [.atomic, .completeFileProtection]) }
    }
    /// The year's log as a spreadsheet file, named for sending.
    func file(year: Int) -> URL? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Business", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let u = dir.appendingPathComponent(Mileage.fileName(year: year))
        let rows = trips.filter { Calendar.current.component(.year, from: $0.date) == year }
        do { try Mileage.csv(rows).write(to: u, atomically: true, encoding: .utf8); return u } catch { return nil }
    }
}

/// Your price list (Business tab, 24 Nov): what you sell or charge, with prices, kept in one place. Send it to a
/// customer as a clean PDF, and pick from it when making an invoice so nothing is typed twice.
enum PriceList {
    struct Item: Codable, Equatable, Identifiable {
        var id = UUID()
        var name: String
        var price: Double
        /// "each", "per hour", "per sq ft" — optional.
        var unit: String = ""
        var label: String {
            unit.trimmingCharacters(in: .whitespaces).isEmpty ? name : "\(name) (\(unit.trimmingCharacters(in: .whitespaces)))"
        }
    }

    static let units = ["each", "per hour", "per day", "per visit", "per item", "per sq ft", "per m²", "per mile"]

    /// A one-colour price list PDF: your name, the date, every item with its price, and a note.
    static func pdf(_ items: [Item], from: String, currency: String, note: String = "", page: CGSize = Invoice.pageSize(), locale: Locale = .current) -> Data {
        let m: CGFloat = 48
        let ink = UIColor(white: 0.08, alpha: 1), grey = UIColor(white: 0.42, alpha: 1), rule = UIColor(white: 0.86, alpha: 1)
        let accent = UIColor(red: 0.05, green: 0.58, blue: 0.53, alpha: 1)
        func font(_ s: CGFloat, _ w: UIFont.Weight = .regular) -> UIFont { .systemFont(ofSize: s, weight: w) }
        let r = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: page))
        return r.pdfData { ctx in
            var y: CGFloat = m
            func text(_ s: String, _ x: CGFloat, _ f: UIFont, _ c: UIColor, right: Bool = false, width: CGFloat? = nil) -> CGFloat {
                let a: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: c]
                let ns = s as NSString
                if right { let w = ns.size(withAttributes: a).width; ns.draw(at: CGPoint(x: x - w, y: y), withAttributes: a); return ceil(f.lineHeight) }
                let wd = width ?? (page.width - x - m)
                let box = ns.boundingRect(with: CGSize(width: wd, height: 2000), options: [.usesLineFragmentOrigin], attributes: a, context: nil)
                ns.draw(with: CGRect(x: x, y: y, width: wd, height: ceil(box.height)), options: [.usesLineFragmentOrigin], attributes: a, context: nil)
                return ceil(box.height)
            }
            ctx.beginPage()
            accent.setFill(); UIRectFill(CGRect(x: m, y: y, width: 36, height: 4)); y += 14
            y += text(L("PRICE LIST"), m, font(26, .bold), ink) + 4
            y += text(Date().formatted(Date.FormatStyle(date: .long, time: .omitted).locale(locale)), m, font(11), grey) + 14
            let who = from.trimmingCharacters(in: .whitespacesAndNewlines)
            if !who.isEmpty { y += text(who, m, font(11.5), ink) + 20 }
            for item in items where !item.name.trimmingCharacters(in: .whitespaces).isEmpty {
                let nameW = page.width - 2 * m - 130
                let h = ceil((item.label as NSString).boundingRect(with: CGSize(width: nameW, height: 2000), options: [.usesLineFragmentOrigin], attributes: [.font: font(12.5)], context: nil).height)
                if y + h > page.height - m - 30 { ctx.beginPage(); y = m }
                _ = text(item.label, m, font(12.5), ink, width: nameW)
                _ = text(Invoice.money(item.price, currency: currency, locale: locale), page.width - m, font(12.5, .semibold), ink, right: true)
                y += max(h, 16) + 8
                rule.setFill(); UIRectFill(CGRect(x: m, y: y - 4, width: page.width - 2 * m, height: 0.75))
                y += 4
            }
            let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !n.isEmpty { y += 14; if y > page.height - m - 40 { ctx.beginPage(); y = m }; _ = text(n, m, font(11), grey) }
        }
    }
}

@MainActor
final class PriceListStore: ObservableObject {
    static let shared = PriceListStore()
    @Published private(set) var items: [PriceList.Item] = []
    private let url: URL

    init(folder: URL? = nil) {
        let base = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Business", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("pricelist.json")
        if let data = try? Data(contentsOf: url), let i = try? JSONDecoder().decode([PriceList.Item].self, from: data) { items = i }
    }
    func add(_ i: PriceList.Item) { items.append(i); save() }
    func update(_ i: PriceList.Item) { if let k = items.firstIndex(where: { $0.id == i.id }) { items[k] = i; save() } }
    func remove(_ id: UUID) { items.removeAll { $0.id == id }; save() }
    func move(from: IndexSet, to: Int) { items.move(fromOffsets: from, toOffset: to); save() }
    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: url, options: [.atomic, .completeFileProtection]) }
    }
    func file(from: String, currency: String, note: String) -> URL? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Business", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let u = dir.appendingPathComponent("Price list.pdf")
        do { try PriceList.pdf(items, from: from, currency: currency, note: note).write(to: u, options: .atomic); return u } catch { return nil }
    }
}
