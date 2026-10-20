import Photos
import UIKit
import SwiftUI

/// The engine behind Memory — "ask your photos anything". It reads the text out of your screenshots
/// once (on device, with Vision OCR), caches it, and then lets you find things by plain language:
/// "the Wi-Fi password I saved", "my parking spot", "that confirmation number". On an Apple
/// Intelligence phone it also pulls the exact answer out with the on-device model; everywhere else it
/// falls back to the best-matching screenshot and line. Nothing leaves the phone.
enum MemoryEngine {

    struct Entry: Codable, Identifiable {
        let id: String          // PHAsset.localIdentifier
        let date: Date
        let text: String        // OCR'd text
        var modified: Date      // for cache invalidation
    }

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("memory-index.json")
    }

    static func loadCache() -> [Entry] {
        guard let d = try? Data(contentsOf: cacheURL) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: d)) ?? []
    }

    static func saveCache(_ entries: [Entry]) {
        if let d = try? JSONEncoder().encode(entries) { try? d.write(to: cacheURL) }
    }

    /// OCR one asset at a readable size.
    private static func text(for asset: PHAsset) async -> String {
        let mgr = PHImageManager.default()
        let opt = PHImageRequestOptions()
        opt.deliveryMode = .highQualityFormat
        opt.isNetworkAccessAllowed = true
        opt.resizeMode = .fast
        let image: UIImage? = await withCheckedContinuation { cont in
            mgr.requestImage(for: asset, targetSize: CGSize(width: 1400, height: 1400), contentMode: .aspectFit, options: opt) { im, info in
                // Avoid the low-res placeholder callback resuming the continuation twice.
                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded { return }
                cont.resume(returning: im)
            }
        }
        guard let image else { return "" }
        return await AIEngine.recognizeText(image)
    }

    /// Build or refresh the index over the phone's screenshots (newest first, bounded), reusing the
    /// cache for assets we've already read. `progress` is 0…1; returns the full, sorted index.
    static func index(limit: Int = 400, progress: @escaping (Double) -> Void) async -> [Entry] {
        var cache = Dictionary(uniqueKeysWithValues: loadCache().map { ($0.id, $0) })
        let shots = PhotoCleaner.screenshots().prefix(limit)
        guard !shots.isEmpty else { progress(1); return [] }
        var out: [Entry] = []
        let total = Double(shots.count)
        for (i, item) in shots.enumerated() {
            let a = item.asset
            let mod = a.modificationDate ?? a.creationDate ?? .distantPast
            if let hit = cache[a.localIdentifier], hit.modified == mod {
                out.append(hit)
            } else {
                let t = await text(for: a)
                let e = Entry(id: a.localIdentifier, date: a.creationDate ?? .distantPast, text: t, modified: mod)
                cache[a.localIdentifier] = e
                out.append(e)
            }
            progress(Double(i + 1) / total)
        }
        out.sort { $0.date > $1.date }
        saveCache(out)
        return out
    }

    /// Keyword ranking: how well an entry matches the question's meaningful words, with a nudge for
    /// more recent screenshots. Works on every phone.
    static func search(_ query: String, in entries: [Entry], top: Int = 6) -> [Entry] {
        let terms = tokens(query)
        guard !terms.isEmpty else { return [] }
        let now = Date()
        let scored = entries.compactMap { e -> (Entry, Double)? in
            let hay = e.text.lowercased()
            var score = 0.0
            for t in terms where hay.contains(t) { score += 1 + Double(t.count) / 12 }
            guard score > 0 else { return nil }
            let ageDays = now.timeIntervalSince(e.date) / 86_400
            score += max(0, 1.5 - ageDays / 120)   // gentle recency boost
            return (e, score)
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(top).map { $0.0 }
    }

    private static let stop: Set<String> = ["the","a","an","my","me","i","is","was","of","to","in","on","for","what","whats","where","show","find","that","this","it","and","do","did","have","had","saved","photo","photos","screenshot","screenshots","picture"]
    static func tokens(_ s: String) -> [String] {
        s.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stop.contains($0) }
    }

    /// The single best line from a matched screenshot — the fallback "answer" when there's no model.
    static func bestLine(for query: String, in entry: Entry) -> String {
        let terms = tokens(query)
        let lines = entry.text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let best = lines.max { a, b in
            let sa = terms.filter { a.lowercased().contains($0) }.count
            let sb = terms.filter { b.lowercased().contains($0) }.count
            return sa < sb
        }
        return best ?? entry.text.components(separatedBy: .newlines).first ?? ""
    }

    /// On Apple Intelligence phones, extract the precise answer from the matched screenshots' text.
    static func answer(question: String, from entries: [Entry]) async -> String? {
        guard AIEngine.isAvailable, !entries.isEmpty else { return nil }
        let context = entries.prefix(4).enumerated()
            .map { "SCREENSHOT \($0.offset + 1) (\(Self.dateString($0.element.date))):\n\($0.element.text.prefix(600))" }
            .joined(separator: "\n\n")
        let instructions = "You answer a question using ONLY the text read from the user's own screenshots below. Give the exact answer in one short line (a password, code, number, address, name, date). If the answer isn't in the text, say 'I couldn't find that in your screenshots.' Never guess."
        return try? await AIEngine.run(instructions: instructions, prompt: "Question: \(question)\n\n\(context)")
    }

    static func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d)
    }

    /// Load a thumbnail for a result row.
    static func thumbnail(id: String, size: CGFloat = 120) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let mgr = PHImageManager.default()
        let opt = PHImageRequestOptions(); opt.deliveryMode = .opportunistic; opt.isNetworkAccessAllowed = true
        return await withCheckedContinuation { cont in
            var resumed = false
            mgr.requestImage(for: asset, targetSize: CGSize(width: size, height: size), contentMode: .aspectFill, options: opt) { im, info in
                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded { return }
                if !resumed { resumed = true; cont.resume(returning: im) }
            }
        }
    }
}

/// Observable index for the Memory view: tracks progress and holds the entries.
@MainActor final class MemoryIndex: ObservableObject {
    @Published private(set) var entries: [MemoryEngine.Entry] = MemoryEngine.loadCache()
    @Published private(set) var indexing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var indexedAt: Date? = nil

    func refresh() {
        guard !indexing else { return }
        indexing = true; progress = 0
        Task {
            let result = await MemoryEngine.index { p in Task { @MainActor in self.progress = p } }
            self.entries = result
            self.indexedAt = Date()
            self.indexing = false
        }
    }
}
