import Foundation
import UIKit
import Photos

/// Smart autorun: paper into PDFs (26 Nov). Today's photos of letters, bills, forms and pages become clean,
/// searchable PDFs — each page found in the photo, flattened square, the paper whitened and the ink darkened, with an
/// invisible text layer so the words can be found, selected and copied anywhere. Pages photographed one after another
/// become one document; each is named from what it says ("Lease Agreement 2026-11-26"). Receipts and business cards are
/// left to their own autoruns. Nothing leaves the phone; each PDF waits to be looked at and saved where the person wants.
enum SmartPapers {
    struct Entry: Codable, Equatable, Identifiable {
        var id: String                // the first page's photo id
        var pages: [String]           // every page's photo id, in order
        var title: String
        var file: String              // the PDF, in Application Support/SmartRuns/Papers
        var taken: Date
        var words = 0                 // how many words the text layer holds
        var saved = false

        /// The file name it's saved under: its title and day, with characters Files doesn't allow taken out.
        var fileName: String { SmartPapers.fileName(title, taken) }
    }

    /// What the last run saw, photo by photo — shown under UI tests, so a miss says why instead of guessing.
    nonisolated(unsafe) static var trail: [String] = []
    nonisolated(unsafe) static var seedNote = "not seeded"

    static var folder: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SmartRuns/Papers", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    // MARK: pure rules

    /// A photo of a page that isn't a receipt or a business card: those have autoruns of their own.
    /// `afterAPage`: taken moments after a page that was kept — the short last page of a letter (a signature, two
    /// closing paragraphs) belongs to it, so the bar is lower.
    static func isPaper(_ s: PhotoFinder.Seen, afterAPage: Bool = false) -> Bool {
        guard !s.screenshot else { return false }
        let doc = PhotoFinder.score(s, for: .document)
        guard doc >= (afterAPage ? 1.2 : PhotoFinder.threshold) else { return false }
        return PhotoFinder.score(s, for: .receipt) < doc && PhotoFinder.score(s, for: .card) < PhotoFinder.threshold
    }

    /// Pages photographed one after another (within `gap`) are one document — unless a page says it is the first
    /// ("Page 1 of 3", "1/3"), which always starts a new one.
    static func group(_ pages: [(id: String, taken: Date, text: String)], gap: TimeInterval = 180) -> [[String]] {
        var out: [[String]] = []
        var last: Date?
        for p in pages.sorted(by: { $0.taken < $1.taken }) {
            if let l = last, p.taken.timeIntervalSince(l) <= gap, !startsADocument(p.text), !out.isEmpty {
                out[out.count - 1].append(p.id)
            } else { out.append([p.id]) }
            last = p.taken
        }
        return out
    }

    static func startsADocument(_ text: String) -> Bool {
        let t = text.lowercased()
        return t.range(of: #"\bpage\s+1\s+(of|/)\s*\d+"#, options: .regularExpression) != nil
            || t.range(of: #"(?m)^\s*1\s*/\s*\d+\s*$"#, options: .regularExpression) != nil
    }

    /// Words that name what a page is. A line holding one makes the best title.
    static let kinds = ["agreement", "contract", "lease", "invoice", "statement", "notice", "letter", "report", "form", "application",
                        "certificate", "policy", "bill", "estimate", "quote", "quotation", "proposal", "minutes", "agenda", "itinerary",
                        "prescription", "permit", "license", "licence", "registration", "declaration", "summary", "schedule",
                        "confirmation", "receipt", "order", "tax", "w-2", "1099", "pay stub", "payslip", "transcript", "resume", "syllabus"]

    /// A short, true name from the page's own words: the line naming what it is ("Residential Lease Agreement"),
    /// else the first line that reads like a heading. Never a date, an address, a number or a greeting.
    static func title(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.prefix(14)
        func usable(_ l: String) -> Bool {
            let letters = l.filter(\.isLetter).count
            guard letters >= 4, l.count <= 70, Double(letters) / Double(max(1, l.count)) > 0.55 else { return false }
            let low = l.lowercased()
            if low.hasPrefix("dear ") || low.hasPrefix("to:") || low.hasPrefix("from:") || low.hasPrefix("date") { return false }
            if low.range(of: #"\d{1,5}\s+\w+\s+(st|street|ave|avenue|rd|road|blvd|dr|drive|ln|lane|way|ct)\b"#, options: .regularExpression) != nil { return false }
            if low.range(of: #"@|www\.|https?://|\(\d{3}\)|\d{3}[-.\s]\d{3}[-.\s]\d{4}"#, options: .regularExpression) != nil { return false }
            if DataGrab.dates(in: l).count > 0 && letters < 12 { return false }
            return true
        }
        let named = lines.first { l in usable(l) && l.split(separator: " ").count <= 8 && kinds.contains { k in
            l.lowercased().range(of: "\\b\(NSRegularExpression.escapedPattern(for: k))\\b", options: .regularExpression) != nil } }
        let pick = named ?? lines.first { usable($0) && $0.split(separator: " ").count <= 8 } ?? ""
        return tidy(pick)
    }

    /// "RESIDENTIAL LEASE AGREEMENT" → "Residential Lease Agreement"; a mixed-case line is kept as written.
    static func tidy(_ s: String) -> String {
        let t = s.trimmingCharacters(in: CharacterSet(charactersIn: " :-–—.,;"))
        guard t == t.uppercased(), t.contains(where: \.isLetter) else { return t }
        let small: Set<String> = ["of", "and", "the", "for", "to", "in", "on", "a", "an", "or", "by"]
        return t.lowercased().split(separator: " ").enumerated().map { i, w in
            let s = String(w)
            if i > 0 && small.contains(s) { return s }
            if s.count <= 3, s.contains(where: \.isNumber) || ["llc", "inc", "usa", "irs", "w-2"].contains(s) { return s.uppercased() }
            return s.prefix(1).uppercased() + s.dropFirst()
        }.joined(separator: " ")
    }

    static func fileName(_ title: String, _ day: Date) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let clean = title.components(separatedBy: bad).joined(separator: " ").split(separator: " ").joined(separator: " ")
        let name = clean.isEmpty ? L("Document") : String(clean.prefix(60))
        return "\(name) \(DateFormatter.posixDay.string(from: day)).pdf"
    }

    // MARK: on the phone

    /// Reads the window's photos, finds the pages and makes one searchable PDF per document. `skip`: photos already made.
    static func gather(in window: DateInterval, skip: Set<String> = [], progress: ((Double, String) -> Void)? = nil) async -> [Entry] {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", window.start as NSDate, window.end as NSDate)
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let r = PHAsset.fetchAssets(with: .image, options: o)
        var assets: [PHAsset] = []
        r.enumerateObjects { a, _, _ in if !skip.contains(a.localIdentifier) { assets.append(a) } }
        trail = ["\(assets.count) photos in the window"]
        var cache = PhotoFinder.loadCache()
        var found: [(id: String, taken: Date, text: String)] = []
        var byID: [String: PHAsset] = [:]
        for (i, a) in assets.enumerated() {
            if Task.isCancelled { break }
            progress?(0.4 * Double(i) / Double(max(1, assets.count)), "\(L("Looking at photo")) \(i + 1)/\(assets.count)")
            let seen: PhotoFinder.Seen?
            if let s = cache[a.localIdentifier], s.modified == (a.modificationDate?.timeIntervalSince1970 ?? 0) { seen = s }
            else { seen = await PhotoFinder.read(a); if let seen { cache[a.localIdentifier] = seen } }
            let taken = a.creationDate ?? window.end
            let after = found.last.map { taken.timeIntervalSince($0.taken) <= 180 } ?? false
            var looked = ""
            if let small = await PhotoFinder.image(a, side: 720), let cg = small.cgImage {
                let px = Stitcher.grayscale(small, width: 40).px
                looked = " · read back \(cg.width)x\(cg.height) \(cg.bitsPerComponent)bpc \(cg.colorSpace?.name.map { $0 as String } ?? "?") mean \(px.reduce(0) { $0 + Int($1) } / max(1, px.count))"
            }
            trail.append("\(a.pixelWidth)x\(a.pixelHeight) \(Int(Date().timeIntervalSince(a.creationDate ?? .distantPast)))s ago" + looked)
            if let seen {
                let words = seen.text.split { $0 == " " || $0 == "\n" }.count
                trail.append(String(format: "doc %.1f rec %.1f card %.1f · %d words · %@%@", PhotoFinder.score(seen, for: .document),
                                    PhotoFinder.score(seen, for: .receipt), PhotoFinder.score(seen, for: .card), words,
                                    seen.labels.prefix(3).joined(separator: "/"), seen.screenshot ? " · shot" : ""))
            } else { trail.append("unreadable") }
            guard let seen, isPaper(seen, afterAPage: after) else { continue }
            found.append((a.localIdentifier, taken, seen.text)); byID[a.localIdentifier] = a
        }
        PhotoFinder.saveCache(cache)
        let docs = group(found)
        var out: [Entry] = []
        for (d, ids) in docs.enumerated() {
            if Task.isCancelled { break }
            progress?(0.4 + 0.6 * Double(d) / Double(max(1, docs.count)), "\(L("Making PDF")) \(d + 1)/\(docs.count)")
            let list = ids.compactMap { byID[$0] }
            if let e = await make(list) { out.append(e) }
        }
        progress?(1, L("Done"))
        return out
    }

    /// One document from its page photos: each page found, flattened and cleaned, read, and laid into a PDF whose
    /// invisible words sit exactly over the printed ones.
    static func make(_ pages: [PHAsset], title wanted: String? = nil) async -> Entry? {
        guard let first = pages.first else { return nil }
        var images: [UIImage] = []
        for a in pages { if let img = await PhotoFinder.image(a, side: 2600) { images.append(img) } }
        guard !images.isEmpty else { return nil }
        guard let (data, text, words) = await Task.detached(priority: .userInitiated, operation: { build(images) }).value else { return nil }
        let file = "\(UUID().uuidString).pdf"
        guard (try? data.write(to: folder.appendingPathComponent(file), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])) != nil else { return nil }
        let name = wanted ?? title(text)
        return Entry(id: first.localIdentifier, pages: pages.map(\.localIdentifier), title: name.isEmpty ? L("Document") : name,
                     file: file, taken: first.creationDate ?? Date(), words: words)
    }

    /// The PDF itself, from the page photos: each page found in its photo, flattened and cleaned, read, and laid out with
    /// an invisible text layer over the printed words. Returns the PDF, the first page's text (for its name) and how
    /// many words can be searched.
    static func build(_ images: [UIImage]) -> (Data, String, Int)? {
        var clean: [UIImage] = [], ocr: [[DocEngine.OCRLine]?] = []
        for img in images {
            let page = PageFlatten.scan(img).image
            clean.append(page); ocr.append(DocEngine.recognize(page))
        }
        var opts = DocEngine.PDFOptions(); opts.maxWidth = 1800; opts.quality = 0.82
        guard let data = DocEngine.pdf(images: clean, ocr: ocr, options: opts) else { return nil }
        let firstText = ChainText.documentText(ocr.first.flatMap { $0 } ?? [])
        let words = ocr.reduce(0) { $0 + ($1 ?? []).reduce(0) { $0 + $1.text.split(separator: " ").count } }
        return (data, firstText, words)
    }

    /// Re-makes a document from page photo ids (after joining two, or splitting one apart).
    static func remake(_ ids: [String], title: String?) async -> Entry? {
        let r = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var byID: [String: PHAsset] = [:]
        r.enumerateObjects { a, _, _ in byID[a.localIdentifier] = a }
        return await make(ids.compactMap { byID[$0] }, title: title)
    }

    /// A copy under its real name, for Save or Share.
    static func named(_ e: Entry) -> URL? {
        let src = folder.appendingPathComponent(e.file)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("papers-\(e.id.hashValue)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(e.fileName)
        try? FileManager.default.removeItem(at: dest)
        return (try? FileManager.default.copyItem(at: src, to: dest)) != nil ? dest : nil
    }
}
