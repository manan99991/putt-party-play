import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Word Finder: a tiny on-device index over the user's own documents. Sources (files or whole
/// folders) are kept as security-scoped bookmarks so they survive relaunch; extracted text is cached
/// in Caches keyed by path + modification date; search is plain case/diacritic-insensitive matching
/// with ±80-character passages. Nothing leaves the phone.
@MainActor
final class WordFinder: ObservableObject {

    struct Source: Identifiable, Codable, Equatable {
        var id = UUID()
        var name: String
        var isFolder: Bool
        var bookmark: Data
    }
    struct Doc: Identifiable {
        let id = UUID()
        let url: URL          // inside a security scope held by its source while indexing/previewing
        let sourceID: UUID
        let name: String
        let text: String
    }
    struct Hit: Identifiable {
        let id = UUID()
        let docID: UUID
        let fileName: String
        let passage: String
        let matchRange: Range<String.Index>
    }
    struct SavedPassage: Identifiable, Codable, Equatable {
        var id = UUID()
        var fileName: String
        var passage: String
    }

    @Published var sources: [Source] = []
    @Published private(set) var docs: [Doc] = []
    @Published private(set) var indexing = false
    @Published private(set) var progress: (done: Int, total: Int) = (0, 0)
    @Published private(set) var hits: [Hit] = []
    @Published var saved: [SavedPassage] = []
    @Published var lastError: String?

    static let extensions: Set<String> = ["pdf", "txt", "md", "csv", "rtf", "docx", "xlsx", "pptx"]
    static let importTypes: [UTType] = [.pdf, .plainText, .commaSeparatedText, .rtf, .text, .data]
    private static let sourcesKey = "tenzy.wordfinder.sources", savedKey = "tenzy.wordfinder.saved"
    private var activeScopes: [URL] = []

    init() {
        if let d = UserDefaults.standard.data(forKey: Self.sourcesKey), let s = try? JSONDecoder().decode([Source].self, from: d) { sources = s }
        if let d = UserDefaults.standard.data(forKey: Self.savedKey), let s = try? JSONDecoder().decode([SavedPassage].self, from: d) { saved = s }
    }

    // MARK: sources

    func add(urls: [URL], asFolder: Bool) {
        for u in urls {
            let ok = u.startAccessingSecurityScopedResource()
            defer { if ok { u.stopAccessingSecurityScopedResource() } }
            guard let bm = try? u.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { lastError = "Couldn't keep access to \(u.lastPathComponent)."; continue }
            if !sources.contains(where: { $0.name == u.lastPathComponent && $0.isFolder == asFolder }) {
                sources.append(Source(name: u.lastPathComponent, isFolder: asFolder, bookmark: bm))
            }
        }
        persist(); reindex()
    }

    func remove(_ s: Source) {
        sources.removeAll { $0.id == s.id }
        docs.removeAll { $0.sourceID == s.id }
        persist(); hits = []
    }

    func save(_ h: Hit) {
        guard !saved.contains(where: { $0.passage == h.passage && $0.fileName == h.fileName }) else { return }
        saved.insert(SavedPassage(fileName: h.fileName, passage: h.passage), at: 0)
        persist()
    }
    func unsave(_ p: SavedPassage) { saved.removeAll { $0.id == p.id }; persist() }

    private func persist() {
        if let d = try? JSONEncoder().encode(sources) { UserDefaults.standard.set(d, forKey: Self.sourcesKey) }
        if let d = try? JSONEncoder().encode(saved) { UserDefaults.standard.set(d, forKey: Self.savedKey) }
    }

    /// Resolve a source's bookmark and start its security scope (kept open until `releaseScopes`).
    private func resolve(_ s: Source) -> URL? {
        var stale = false
        guard let u = try? URL(resolvingBookmarkData: s.bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if u.startAccessingSecurityScopedResource() { activeScopes.append(u) }
        return u
    }
    func releaseScopes() { activeScopes.forEach { $0.stopAccessingSecurityScopedResource() }; activeScopes = [] }

    /// URL for a doc with its scope re-opened (for QuickLook); call `releaseScopes` after dismiss.
    func previewURL(for doc: Doc) -> URL? {
        guard let s = sources.first(where: { $0.id == doc.sourceID }), let base = resolve(s) else { return nil }
        return s.isFolder ? doc.url : base
    }

    // MARK: indexing

    func reindex() {
        guard !indexing else { return }
        indexing = true; lastError = nil; hits = []
        // Enumerate on the main actor (needs the scopes), extract text off it.
        var files: [(URL, UUID)] = []
        for s in sources {
            guard let u = resolve(s) else { continue }
            if s.isFolder {
                let keys: [URLResourceKey] = [.isRegularFileKey]
                if let en = FileManager.default.enumerator(at: u, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                    for case let f as URL in en where Self.extensions.contains(f.pathExtension.lowercased()) {
                        files.append((f, s.id)); if files.count >= 600 { break }
                    }
                }
            } else if Self.extensions.contains(u.pathExtension.lowercased()) { files.append((u, s.id)) }
        }
        progress = (0, files.count)
        let work = files
        Task.detached(priority: .userInitiated) { [weak self] in
            var out: [Doc] = []
            for (i, (url, sid)) in work.enumerated() {
                let text = Self.extract(url)
                if !text.isEmpty { out.append(Doc(url: url, sourceID: sid, name: url.lastPathComponent, text: text)) }
                let done = i + 1
                await MainActor.run { self?.progress = (done, work.count) }
            }
            let result = out
            await MainActor.run {
                guard let self else { return }
                self.docs = result; self.indexing = false; self.releaseScopes()
                if result.isEmpty && !work.isEmpty { self.lastError = "No readable text in those files yet." }
            }
        }
    }

    /// Cached per URL + modification date under Caches/WordFinder.
    nonisolated static func extract(_ url: URL) -> String {
        let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0
        let key = fnv("\(url.path)|\(Int(mod))") + ".txt"
        let dir = (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory).appendingPathComponent("WordFinder", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let cache = dir.appendingPathComponent(key)
        if let s = try? String(contentsOf: cache, encoding: .utf8) { return s }
        let text = String(rawText(url).prefix(3_000_000))
        try? text.write(to: cache, atomically: true, encoding: .utf8)
        return text
    }

    nonisolated private static func rawText(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let doc = PDFDocument(url: url) else { return "" }
            let s = (doc.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if s.count > 20 { return ZipText.clean(s) }
            // Scanned PDF: OCR the first pages on-device.
            let pages = DocEngine.render(doc, maxWidth: 1400, maxPages: 6)
            return ZipText.clean(pages.map { DocEngine.text(DocEngine.recognize($0)) }.joined(separator: "\n\n"))
        case "txt", "md", "csv":
            if let s = try? String(contentsOf: url, encoding: .utf8) { return ZipText.clean(s) }
            if let d = try? Data(contentsOf: url), let s = String(data: d, encoding: .isoLatin1) { return ZipText.clean(s) }
            return ""
        case "rtf":
            guard let d = try? Data(contentsOf: url),
                  let a = try? NSAttributedString(data: d, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) else { return "" }
            return ZipText.clean(a.string)
        case "docx", "xlsx", "pptx":
            return ZipText.text(of: url)
        default:
            return ""
        }
    }

    nonisolated private static func fnv(_ s: String) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        return String(h, radix: 16)
    }

    // MARK: search

    func search(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { hits = []; return }
        var out: [Hit] = []
        let opts: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        for d in docs {
            var from = d.text.startIndex
            while let r = d.text.range(of: q, options: opts, range: from..<d.text.endIndex) {
                let lo = d.text.index(r.lowerBound, offsetBy: -80, limitedBy: d.text.startIndex) ?? d.text.startIndex
                let hi = d.text.index(r.upperBound, offsetBy: 80, limitedBy: d.text.endIndex) ?? d.text.endIndex
                var passage = String(d.text[lo..<hi]).replacingOccurrences(of: "\n", with: " ")
                if lo > d.text.startIndex { passage = "…" + passage }
                if hi < d.text.endIndex { passage += "…" }
                // the match's position inside the passage
                let prefixLen = d.text.distance(from: lo, to: r.lowerBound) + (lo > d.text.startIndex ? 1 : 0)
                let mlo = passage.index(passage.startIndex, offsetBy: prefixLen, limitedBy: passage.endIndex) ?? passage.startIndex
                let mhi = passage.index(mlo, offsetBy: d.text.distance(from: r.lowerBound, to: r.upperBound), limitedBy: passage.endIndex) ?? passage.endIndex
                out.append(Hit(docID: d.id, fileName: d.name, passage: passage, matchRange: mlo..<mhi))
                from = r.upperBound
                if out.count >= 60 { break }
            }
            if out.count >= 60 { break }
        }
        hits = out
    }

    /// Passage with the match highlighted.
    static func highlighted(_ h: Hit) -> AttributedString {
        var a = AttributedString(h.passage)
        if let lo = AttributedString.Index(h.matchRange.lowerBound, within: a), let hi = AttributedString.Index(h.matchRange.upperBound, within: a), lo < hi {
            a[lo..<hi].backgroundColor = HandyColor.accentSoft
            a[lo..<hi].foregroundColor = HandyColor.accent
            a[lo..<hi].font = HandyFont.bodyStrong
        }
        return a
    }

    var fileCount: Int { Set(hits.map(\.docID)).count }
}
