import SwiftUI
import Vision
import UIKit
import UserNotifications

/// One stored receipt. The image is kept as a file; everything else is extracted once by OCR and
/// stored, so search is instant, works offline, and survives with no account or upload.
struct Receipt: Codable, Identifiable, Equatable {
    var id = UUID()
    var addedAt = Date()
    var imageFile: String               // filename under the receipts image dir
    var store: String                   // best-guess merchant
    var purchaseDate: Date?             // best-guess date on the receipt
    var total: String                   // display text, e.g. "$129.99" (kept as text — we never silently do math)
    var rawText: String                 // full OCR text — powers the forgiving search
    var items: [String] = []            // notable line items
    var warrantyMonths: Int?            // nil = not tracking a warranty
    var note: String = ""

    /// When the warranty lapses, measured from the purchase date (or the day it was filed if unknown).
    var warrantyEnds: Date? {
        guard let m = warrantyMonths, m > 0 else { return nil }
        return Calendar.current.date(byAdding: .month, value: m, to: purchaseDate ?? addedAt)
    }

    var daysLeftOnWarranty: Int? {
        guard let end = warrantyEnds else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                               to: Calendar.current.startOfDay(for: end)).day
    }
}

/// Pulls the useful fields off a photographed receipt with on-device OCR. Everything is best-effort and
/// fully editable afterwards — the goal is to save the user typing, never to be the final word.
enum ReceiptScan {
    struct Result { let store: String; let date: Date?; let total: String; let items: [String]; let rawText: String }

    static func read(_ image: UIImage) async -> Result {
        guard let cg = image.normalizedUp().cgImage else { return Result(store: "Receipt", date: nil, total: "", items: [], rawText: "") }
        let req = VNRecognizeTextRequest(); req.recognitionLevel = .accurate; req.usesLanguageCorrection = true
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
        let lines = (req.results as? [VNRecognizedTextObservation] ?? []).compactMap { $0.topCandidates(1).first?.string }
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return Result(store: guessStore(lines), date: guessDate(lines.joined(separator: " ")),
                      total: guessTotal(lines), items: guessItems(lines), rawText: lines.joined(separator: "\n"))
    }

    /// The merchant is almost always one of the first few lines, set in big type: mostly letters, not an
    /// address or a phone number. Take the first such line.
    static func guessStore(_ lines: [String]) -> String {
        for l in lines.prefix(6) {
            let letters = l.filter(\.isLetter).count
            let digits = l.filter(\.isNumber).count
            if letters >= 3, digits <= 2, l.count <= 32, !l.lowercased().contains("receipt"), !l.lowercased().contains("invoice") {
                return l.capitalizedStore
            }
        }
        return lines.first?.capitalizedStore ?? "Receipt"
    }

    static func guessDate(_ text: String) -> Date? {
        guard let d = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let r = d.matches(in: text, range: NSRange(text.startIndex..., in: text))
        // Prefer the most recent plausible date that isn't in the future.
        return r.compactMap(\.date).filter { $0 <= Date().addingTimeInterval(86_400) }.max()
    }

    /// The total is the amount on (or nearest) a line that says "total" — but not "subtotal". If none is
    /// labelled, fall back to the largest currency amount on the receipt.
    static func guessTotal(_ lines: [String]) -> String {
        func amounts(_ s: String) -> [String] {
            let pat = #"[$€£]?\s?\d{1,3}(?:[,]\d{3})*(?:\.\d{2})"#
            guard let re = try? NSRegularExpression(pattern: pat) else { return [] }
            return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { Range($0.range, in: s).map { String(s[$0]).trimmingCharacters(in: .whitespaces) } }
        }
        for l in lines {
            let low = l.lowercased()
            if low.contains("total"), !low.contains("subtotal"), let a = amounts(l).last { return a }
        }
        let all = lines.flatMap(amounts)
        return all.max { numeric($0) < numeric($1) } ?? ""
    }

    static func guessItems(_ lines: [String]) -> [String] {
        lines.filter { l in
            let low = l.lowercased()
            guard l.filter(\.isLetter).count >= 3 else { return false }
            if ["total", "subtotal", "tax", "change", "cash", "visa", "mastercard", "balance", "receipt", "thank"].contains(where: low.contains) { return false }
            return true
        }.prefix(8).map { String($0) }
    }

    private static func numeric(_ s: String) -> Double { Double(s.filter { $0.isNumber || $0 == "." }) ?? 0 }
}

/// Forgiving receipt search. Typos and vague phrasing still land the right receipt — "cosco tv" finds
/// the Costco television. Pure and deterministic so it can be unit-tested and trusted.
enum ReceiptSearch {
    static func rank(_ receipts: [Receipt], query: String) -> [Receipt] {
        let q = normalize(query)
        guard !q.isEmpty else { return receipts.sorted { $0.addedAt > $1.addedAt } }
        return receipts
            .map { (r: $0, s: score(query: query, store: $0.store, items: $0.items, rawText: $0.rawText)) }
            .filter { $0.s >= 0.5 }
            .sorted { $0.s != $1.s ? $0.s > $1.s : $0.r.addedAt > $1.r.addedAt }
            .map(\.r)
    }

    /// 0…1 match of `query` against a receipt. Each query word scores its best fuzzy hit among the
    /// receipt's words, weighted up when it matches the store name or an item rather than buried text.
    static func score(query: String, store: String, items: [String], rawText: String) -> Double {
        let qTokens = tokens(query)
        guard !qTokens.isEmpty else { return 0 }
        let storeT = Set(tokens(store))
        let itemsT = Set(items.flatMap(tokens))
        let rawT = Set(tokens(rawText))
        var sum = 0.0
        for q in qTokens {
            let best = max(bestSim(q, storeT) * 1.0, bestSim(q, itemsT) * 0.92, bestSim(q, rawT) * 0.85)
            sum += best
        }
        return sum / Double(qTokens.count)
    }

    // MARK: internals

    static func normalize(_ s: String) -> String {
        String(s.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " })
            .split(separator: " ").joined(separator: " ")
    }
    private static func tokens(_ s: String) -> [String] {
        normalize(s).split(separator: " ").map(String.init).filter { $0.count >= 2 }
    }
    private static func bestSim(_ q: String, _ set: Set<String>) -> Double { set.map { sim(q, $0) }.max() ?? 0 }

    /// Similarity of two words, 0…1. Exact or containment scores high; otherwise an edit-distance ratio,
    /// with weak matches zeroed so unrelated words don't leak in.
    static func sim(_ a: String, _ b: String) -> Double {
        if a == b { return 1 }
        if a.count >= 3, b.contains(a) { return 0.95 }
        if b.count >= 3, a.contains(b) { return 0.9 }
        let d = levenshtein(a, b)
        let ratio = 1 - Double(d) / Double(max(a.count, b.count))
        return ratio >= 0.6 ? ratio : 0
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }; if y.isEmpty { return x.count }
        var prev = Array(0...y.count)
        var cur = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            cur[0] = i
            for j in 1...y.count {
                cur[j] = x[i - 1] == y[j - 1] ? prev[j - 1] : min(prev[j - 1], prev[j], cur[j - 1]) + 1
            }
            swap(&prev, &cur)
        }
        return prev[y.count]
    }
}

/// The vault: receipts persisted as JSON plus their image files, all in the app's own container.
@MainActor final class ReceiptStore: ObservableObject {
    @Published private(set) var receipts: [Receipt] = ReceiptStore.load()

    nonisolated private static var dir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("receipts", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    nonisolated private static var dbURL: URL { dir.appendingPathComponent("index.json") }
    nonisolated private static func load() -> [Receipt] { (try? JSONDecoder().decode([Receipt].self, from: Data(contentsOf: dbURL))) ?? [] }
    private func persist() { try? JSONEncoder().encode(receipts).write(to: Self.dbURL) }

    func imageURL(_ r: Receipt) -> URL { Self.dir.appendingPathComponent(r.imageFile) }
    func image(_ r: Receipt) -> UIImage? { UIImage(contentsOfFile: imageURL(r).path) }

    func add(image: UIImage, scan: ReceiptScan.Result, warrantyMonths: Int?) -> Receipt {
        let name = "\(UUID().uuidString).jpg"
        if let data = image.jpegData(compressionQuality: 0.8) { try? data.write(to: Self.dir.appendingPathComponent(name)) }
        let r = Receipt(imageFile: name, store: scan.store, purchaseDate: scan.date, total: scan.total,
                        rawText: scan.rawText, items: scan.items, warrantyMonths: warrantyMonths)
        receipts.insert(r, at: 0); persist()
        if r.warrantyEnds != nil { WarrantyReminders.schedule(r) }
        return r
    }

    func update(_ r: Receipt) {
        guard let i = receipts.firstIndex(where: { $0.id == r.id }) else { return }
        receipts[i] = r; persist()
        WarrantyReminders.cancel(r); if r.warrantyEnds != nil { WarrantyReminders.schedule(r) }
    }

    func delete(_ r: Receipt) {
        try? FileManager.default.removeItem(at: imageURL(r))
        receipts.removeAll { $0.id == r.id }; persist()
        WarrantyReminders.cancel(r)
    }

    /// Receipts whose warranty lapses within `days`, soonest first — the home screen's "act now" list.
    func expiring(within days: Int) -> [Receipt] {
        receipts.filter { if let d = $0.daysLeftOnWarranty { return d >= 0 && d <= days } else { return false } }
            .sorted { ($0.daysLeftOnWarranty ?? 0) < ($1.daysLeftOnWarranty ?? 0) }
    }
}

/// Local reminders a week before a warranty lapses — no server, scheduled on the phone. Best-effort:
/// if the user hasn't granted notifications, the in-app "expiring soon" list still covers them.
enum WarrantyReminders {
    static func schedule(_ r: Receipt) {
        guard let end = r.warrantyEnds, let fire = Calendar.current.date(byAdding: .day, value: -7, to: end), fire > Date() else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let c = UNMutableNotificationContent()
            c.title = "Warranty ending soon"
            c.body = "\(r.store) — warranty ends \(end.formatted(date: .abbreviated, time: .omitted)). Tap to find the receipt."
            c.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: "warranty-\(r.id.uuidString)", content: c, trigger: trigger))
        }
    }
    static func cancel(_ r: Receipt) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["warranty-\(r.id.uuidString)"])
    }
}

private extension String {
    /// Tidy an all-caps OCR'd store name into something readable ("COSTCO WHOLESALE" → "Costco Wholesale").
    var capitalizedStore: String {
        let t = trimmingCharacters(in: .whitespaces)
        return t == t.uppercased() ? t.capitalized : t
    }
}
