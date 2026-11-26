import Foundation
import UIKit
import Photos
import PDFKit

/// Smart autorun: today's receipts into the expense sheet (25 Nov). Looks through the photos and screenshots taken in
/// the window and the PDFs saved to the folder the person chose, reads every receipt on the phone, and gets each ready
/// as one row — date, shop, total, tax, currency, how it was paid, a category, the receipt number and where it came
/// from. Nothing goes into the sheet until the person has looked: a missing total or numbers that don't add up hold
/// that receipt back, and the same receipt is never added twice.
enum SmartReceipts {
    /// The full set of columns a new expense sheet gets.
    static let header = "Date,Merchant,Total,Tax,Currency,Payment,Category,Receipt #,From"
    /// The columns sheets made before 25 Nov have; their rows keep that shape so nothing is dropped.
    static let oldHeader = "Date,Merchant,Total,Tax,Currency"

    /// One receipt found and read, as it will go into the sheet. Codable, so a run's findings wait for review.
    struct Entry: Codable, Equatable, Identifiable {
        var id: String               // the photo's id, or the PDF's path and page
        var from: String             // "Photo", "Screenshot" or "PDF: name.pdf p2"
        var taken: Date
        var merchant: String
        var date: Date?
        var total: Double?
        var tax: Double?
        var currency: String
        var payment: String
        var number: String
        var category: String
        var lines: [String]          // what was bought, for the review card
        var amounts: [Double]        // each line's amount, so a check after an edit is as strict as the first
        var subtotal: Double?
        var tip: Double?
        var block: String?           // why it's held back, if it is
        var unsure: [String]         // fields to look at again
        /// The person looked and says the receipt really reads this way (a misread line can't be typed over).
        var confirmed = false
        /// Also file it in Warranty (with its photo), for a purchase worth keeping: on by default when it is.
        var keep: Bool? = nil
        /// The store's return window read off the small print, in days.
        var returnDays: Int? = nil
        /// Electronics and appliances get a one-year warranty reminder by default.
        var warrantyMonths: Int? = nil

        var ready: Bool { block == nil || confirmed }

        init(id: String, from: String, taken: Date, receipt r: DataGrab.Receipt) {
            self.id = id; self.from = from; self.taken = taken
            merchant = r.merchant.trimmingCharacters(in: .whitespaces); date = r.date; total = r.total; tax = r.tax
            currency = r.currency; payment = r.payment; number = r.number
            category = SmartReceipts.category(r)
            lines = r.lines.map(\.name).prefix(12).map { $0 }
            amounts = r.lines.map(\.amount); subtotal = r.subtotal; tip = r.tip
            let p = DataGrab.entryProblems(r)
            block = p.block; unsure = Array(p.unsure).sorted()
        }

        /// Adds what the small print says about returns and warranty (from the whole text read).
        mutating func readKeeping(_ text: String) {
            returnDays = ReceiptScan.guessReturnDays(text, purchase: date)
            warrantyMonths = SmartReceipts.lastsYears(text, merchant: merchant) ? 12 : nil
            keep = (returnDays != nil || warrantyMonths != nil) ? true : nil   // only offered when it applies
        }

        /// Back to a receipt, after the person fixed a field on the review card.
        var receipt: DataGrab.Receipt {
            var r = DataGrab.Receipt()
            r.merchant = merchant; r.date = date; r.total = total; r.tax = tax; r.currency = currency; r.payment = payment; r.number = number
            r.subtotal = subtotal; r.tip = tip
            r.lines = amounts.enumerated().map { i, a in .init(name: i < lines.count ? lines[i] : "", qty: nil, unit: nil, amount: a) }
            return r
        }

        /// Checks again after an edit: a fixed total releases the hold.
        mutating func recheck() {
            let p = DataGrab.entryProblems(receipt)
            block = p.block; unsure = Array(p.unsure).sorted()
        }
    }

    // MARK: pure

    /// A plain category an accountant expects, from the shop's name and what was bought. "Other" when unsure.
    static func category(_ r: DataGrab.Receipt) -> String {
        let t = (r.merchant + " " + r.lines.map(\.name).joined(separator: " ") + " " + r.items.map(\.0).joined(separator: " ")).lowercased()
        // Whole words only: "inn" must not match "dinner", nor "ink" "drink", nor "tip" "multiple".
        func has(_ w: [String]) -> Bool {
            w.contains { word in
                let k = NSRegularExpression.escapedPattern(for: word.trimmingCharacters(in: .whitespaces))
                return t.range(of: "(^|[^\\p{L}])" + k + "($|[^\\p{L}])", options: .regularExpression) != nil
            }
        }
        if has(["shell", "chevron", "exxon", "mobil", "bp ", "speedway", "marathon", "citgo", "sunoco", "valero", "costco gas", "fuel", "gasoline", "unleaded", "diesel", "petrol"]) { return "Fuel" }
        if has(["parking", "parkwhiz", "spothero", "garage", "meter", "toll", "ipass", "e-zpass"]) { return "Parking & tolls" }
        if has(["hotel", "inn", "marriott", "hilton", "hyatt", "airbnb", "motel", "resort", "lodging"]) { return "Lodging" }
        if has(["airline", "airlines", "delta", "united", "american air", "southwest", "uber", "lyft", "taxi", "amtrak", "metra", "train", "boarding"]) { return "Travel" }
        if has(["restaurant", "cafe", "café", "coffee", "starbucks", "dunkin", "pizza", "grill", "bar ", "kitchen", "diner", "bistro", "burger",
                "taco", "sushi", "mcdonald", "chipotle", "subway", "panera", "tip", "gratuity", "server", "table "]) { return "Meals" }
        if has(["office depot", "officemax", "staples", "paper", "printer", "ink", "toner", "postage", "usps", "fedex", "ups store", "envelope"]) { return "Office & shipping" }
        if has(["jewel", "mariano", "kroger", "safeway", "whole foods", "trader joe", "aldi", "grocery", "market", "produce", "milk", "eggs", "bread"]) { return "Groceries" }
        if has(["home depot", "lowe's", "lowes", "menards", "ace hardware", "hardware", "lumber", "tools"]) { return "Supplies & hardware" }
        if has(["apple", "best buy", "verizon", "at&t", "t-mobile", "comcast", "xfinity", "software", "subscription", "internet", "phone bill"]) { return "Phone, internet & software" }
        if has(["pharmacy", "walgreens", "cvs", "clinic", "medical", "dental", "optical"]) { return "Health" }
        return "Other"
    }

    /// A purchase that's worth keeping the receipt for: electronics, appliances, tools, furniture — the things with a
    /// warranty — or anything sold at an electronics or home store. Whole words only.
    static func lastsYears(_ text: String, merchant: String) -> Bool {
        let t = (merchant + " " + text).lowercased()
        let words = ["best buy", "apple store", "apple", "micro center", "b&h", "costco", "home depot", "lowe's", "lowes", "ikea", "wayfair",
                     "laptop", "macbook", "ipad", "iphone", "tablet", "television", "tv", "monitor", "headphones", "airpods", "camera", "printer",
                     "router", "console", "playstation", "xbox", "nintendo", "speaker", "soundbar", "smartwatch", "watch",
                     "refrigerator", "fridge", "washer", "dryer", "dishwasher", "microwave", "vacuum", "blender", "air fryer", "mixer",
                     "drill", "saw", "mower", "sofa", "mattress", "warranty", "serial", "s/n", "applecare", "protection plan"]
        return words.contains { w in
            t.range(of: "(^|[^\\p{L}])" + NSRegularExpression.escapedPattern(for: w) + "($|[^\\p{L}])", options: .regularExpression) != nil
        }
    }

    /// One CSV cell.
    static func cell(_ s: String) -> String {
        s.contains(where: { ",\"\n".contains($0) }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
    }

    /// The row for a sheet with this header (a new sheet's, or the older five-column one), header line first.
    static func rows(_ entries: [Entry], header existing: String?) -> String {
        let h = (existing?.isEmpty == false ? existing! : header)
        let old = RunningList.fields(h).count == RunningList.fields(oldHeader).count
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        let body = entries.map { e -> String in
            // No date printed on it: the day the photo was taken or the PDF saved, which the review card says.
            let base = [f.string(from: e.date ?? e.taken), cell(e.merchant), e.total.map { String(format: "%.2f", $0) } ?? "",
                        e.tax.map { String(format: "%.2f", $0) } ?? "", e.currency]
            return (old ? base : base + [cell(e.payment), cell(e.category), cell(e.number), cell(e.from)]).joined(separator: ",")
        }
        return ([old ? oldHeader : header] + body).joined(separator: "\n")
    }

    /// The same receipt seen twice — a photo and a PDF of it, or a photo taken twice — counts once: same shop, same
    /// total, same day. The one with fewer problems is kept.
    static func deduped(_ entries: [Entry]) -> [Entry] {
        var out: [Entry] = []
        let cal = Calendar(identifier: .gregorian)
        for e in entries {
            if let i = out.firstIndex(where: { o in
                o.total != nil && o.total == e.total && o.merchant.lowercased() == e.merchant.lowercased()
                    && (o.date == nil || e.date == nil || cal.isDate(o.date!, inSameDayAs: e.date!))
            }) {
                if out[i].unsure.count + (out[i].ready ? 0 : 10) > e.unsure.count + (e.ready ? 0 : 10) { out[i] = e }
            } else { out.append(e) }
        }
        return out
    }

    // MARK: the folder of PDFs

    private static let folderKey = "smart.receipts.folder"
    /// The folder the person chose for PDFs (Downloads, a scans folder…), kept as a bookmark so it still opens later.
    static func remember(folder url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let d = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { return false }
        AppGroup.defaults.set(d, forKey: folderKey)
        return true
    }
    static func forgetFolder() { AppGroup.defaults.removeObject(forKey: folderKey) }
    static var folder: URL? {
        guard let d = AppGroup.defaults.data(forKey: folderKey) else { return nil }
        var stale = false
        guard let u = try? URL(resolvingBookmarkData: d, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale { _ = remember(folder: u) }
        return u
    }

    // MARK: reading the phone

    /// Every receipt made in the window, read and checked. `progress` is the share done (0…1) and what's being read.
    static func gather(in window: DateInterval, progress: ((Double, String) -> Void)? = nil) async -> [Entry] {
        var out: [Entry] = []
        // Photos and screenshots taken in the window.
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", window.start as NSDate, window.end as NSDate)
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let found = PHAsset.fetchAssets(with: .image, options: o)
        var assets: [PHAsset] = []
        found.enumerateObjects { a, _, _ in assets.append(a) }
        let pdfs = pdfFiles(in: window)
        let total = Double(max(1, assets.count + pdfs.count))
        var cache = PhotoFinder.loadCache()
        var done = 0.0
        for a in assets {
            if Task.isCancelled { break }
            progress?(done / total, "Looking at photo \(Int(done) + 1) of \(Int(total))")
            done += 1
            // The quick read (cached by the photo index) decides whether it's worth a full read.
            let seen: PhotoFinder.Seen?
            if let s = cache[a.localIdentifier], s.modified == (a.modificationDate?.timeIntervalSince1970 ?? 0) { seen = s }
            else { seen = await PhotoFinder.read(a); if let seen { cache[a.localIdentifier] = seen } }
            guard let seen, PhotoFinder.score(seen, for: .receipt) >= PhotoFinder.threshold else { continue }
            guard let img = await PhotoFinder.image(a, side: 3000) else { continue }
            let text = await Task.detached(priority: .userInitiated) { ChainText.documentText(img) }.value
            guard DataGrab.looksLikeReceipt(text) else { continue }
            let r = DataGrab.receipt(text)
            guard r.total != nil || !r.lines.isEmpty else { continue }
            var e = Entry(id: a.localIdentifier, from: seen.screenshot ? "Screenshot" : "Photo", taken: a.creationDate ?? window.end, receipt: r)
            e.readKeeping(text)
            out.append(e)
        }
        PhotoFinder.saveCache(cache)
        for p in pdfs {
            if Task.isCancelled { break }
            progress?(done / total, "Reading \(p.lastPathComponent)")
            done += 1
            out += await readPDF(p)
        }
        progress?(1, "Done")
        return deduped(out)
    }

    /// PDFs in the chosen folder (and one level of folders inside it) saved or changed in the window.
    static func pdfFiles(in window: DateInterval) -> [URL] {
        guard let root = folder, root.startAccessingSecurityScopedResource() else { return [] }
        defer { root.stopAccessingSecurityScopedResource() }
        let keys: [URLResourceKey] = [.contentModificationDateKey, .creationDateKey, .isDirectoryKey]
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        var out: [URL] = []
        for case let u as URL in e {
            if e.level > 2 { e.skipDescendants(); continue }
            guard u.pathExtension.lowercased() == "pdf", let v = try? u.resourceValues(forKeys: Set(keys)) else { continue }
            let when = max(v.contentModificationDate ?? .distantPast, v.creationDate ?? .distantPast)
            if window.contains(when) { out.append(u) }
        }
        return out.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Each page that is a receipt becomes one entry (a PDF of several receipts, one a page), or the whole file when
    /// the receipt runs over pages. Scanned PDFs with no text layer are read like photos.
    static func readPDF(_ url: URL) async -> [Entry] {
        guard let root = folder else { return [] }
        let ok = root.startAccessingSecurityScopedResource()
        defer { if ok { root.stopAccessingSecurityScopedResource() } }
        guard let doc = PDFDocument(url: url), !doc.isLocked else { return [] }
        let taken = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        var pages: [String] = []
        for i in 0..<min(doc.pageCount, 40) {
            guard let page = doc.page(at: i) else { continue }
            var t = page.string ?? ""
            if t.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 {
                let size = page.bounds(for: .mediaBox).size
                let k = 2400 / max(size.width, size.height, 1)
                let img = page.thumbnail(of: CGSize(width: size.width * k, height: size.height * k), for: .mediaBox)
                t = await Task.detached(priority: .userInitiated) { ChainText.documentText(img) }.value
            }
            pages.append(t)
        }
        let name = url.lastPathComponent
        let each = pages.enumerated().compactMap { i, t -> Entry? in
            guard DataGrab.looksLikeReceipt(t) else { return nil }
            let r = DataGrab.receipt(t)
            guard r.total != nil else { return nil }
            var e = Entry(id: url.path + "#\(i)", from: "PDF: \(name)" + (pages.count > 1 ? " p\(i + 1)" : ""), taken: taken, receipt: r)
            e.readKeeping(t)
            return e
        }
        if !each.isEmpty { return each }
        let whole = pages.joined(separator: "\n")
        guard DataGrab.looksLikeReceipt(whole) else { return [] }
        let r = DataGrab.receipt(whole)
        guard r.total != nil || !r.lines.isEmpty else { return [] }
        var e = Entry(id: url.path, from: "PDF: \(name)", taken: taken, receipt: r)
        e.readKeeping(whole)
        return [e]
    }

    /// The picture of a found receipt, for filing in Warranty: the photo, or the PDF's page.
    static func picture(_ e: Entry) async -> UIImage? {
        if e.from.hasPrefix("PDF") {
            guard let root = folder else { return nil }
            let ok = root.startAccessingSecurityScopedResource(); defer { if ok { root.stopAccessingSecurityScopedResource() } }
            let parts = e.id.split(separator: "#")
            guard let doc = PDFDocument(url: URL(fileURLWithPath: String(parts[0]))),
                  let page = doc.page(at: parts.count > 1 ? Int(parts[1]) ?? 0 : 0) else { return nil }
            let size = page.bounds(for: .mediaBox).size, k = 2000 / max(size.width, size.height, 1)
            return page.thumbnail(of: CGSize(width: size.width * k, height: size.height * k), for: .mediaBox)
        }
        guard let a = PHAsset.fetchAssets(withLocalIdentifiers: [e.id], options: nil).firstObject else { return nil }
        return await PhotoFinder.image(a, side: 2400)
    }

    /// Files the kept ones in Warranty, with their return window and warranty reminders. Returns how many.
    @MainActor static func file(_ entries: [Entry]) async -> Int {
        let store = ReceiptStore()
        var n = 0
        for e in entries where e.ready && e.keep == true {
            guard let img = await picture(e) else { continue }
            let f = NumberFormatter(); f.numberStyle = .currency; f.currencySymbol = e.currency.isEmpty ? "$" : e.currency
            let scan = ReceiptScan.Result(store: e.merchant, date: e.date ?? e.taken, total: e.total.flatMap { f.string(from: NSNumber(value: $0)) } ?? "",
                                          items: e.lines, rawText: ([e.merchant] + e.lines).joined(separator: "\n"))
            _ = store.add(image: img, scan: scan, warrantyMonths: e.warrantyMonths, returnDays: e.returnDays)
            n += 1
        }
        return n
    }

    /// Adds the ready entries the person kept to the period's expense sheet. Returns the sheet's name, how many were
    /// added, and how many were already in it.
    @discardableResult static func add(_ entries: [Entry]) -> (sheet: String, added: Int, already: Int) {
        let file = RunningList.target(pattern: RunningList.defaultName)
        let existing = RunningList.read(file)
        let head = existing.components(separatedBy: .newlines).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let before = RunningList.rowCount(existing)
        let merged = RunningList.merged(existing: existing, incoming: rows(entries.filter(\.ready), header: head))
        RunningList.write(file, merged)
        let after = RunningList.rowCount(merged)
        let ready = entries.filter(\.ready).count
        return ((file as NSString).deletingPathExtension, after - before, max(0, ready - (after - before)))
    }
}
