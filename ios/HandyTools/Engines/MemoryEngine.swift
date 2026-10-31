import Photos
import UIKit
import SwiftUI
import Vision

/// The engine behind Memory — "ask your photos anything". For each photo in your library (newest
/// first, bounded) it reads the text with Vision OCR AND recognises what's in it — scene/object
/// labels (clothing, food, dog, beach, receipt…) and the dominant colours — all on device, cached
/// once. You can then find things in plain language, by text ("the Wi-Fi password I saved") or by
/// what the photo shows ("me in red clothes", "my dog on the beach"). Nothing leaves the phone.
enum MemoryEngine {

    struct Entry: Codable, Identifiable {
        let id: String          // PHAsset.localIdentifier
        let date: Date
        let text: String        // OCR'd text
        var modified: Date      // for cache invalidation
        var readOK: Bool? = nil // true once the image was actually read (nil = entries saved before this field)
        // Fields added later are optional so an older cache still decodes (nil = not analysed yet).
        var labels: [String]? = nil      // Vision scene/object labels, lowercased
        var colors: [String]? = nil      // dominant colour names, e.g. ["red","black"]
        var isScreenshot: Bool? = nil     // so we can still say "screenshot" vs "photo"
    }

    /// A search result with the reason it surfaced, shown above the thumbnail.
    struct Match: Identifiable {
        let entry: Entry
        let reason: String
        var id: String { entry.id }
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

    // MARK: reading one asset — OCR + visual labels + colours, from a single image load.

    private struct Read { let text: String; let labels: [String]; let colors: [String] }

    /// Load one asset once, then read its text and recognise what it shows. Also caches a compact
    /// thumbnail so the source can be shown later without photo permission. Returns nil only when the
    /// image itself couldn't be loaded (so the caller retries later).
    private static func readAsset(_ asset: PHAsset) async -> Read? {
        let mgr = PHImageManager.default()
        let opt = PHImageRequestOptions()
        opt.deliveryMode = .highQualityFormat
        opt.isNetworkAccessAllowed = true
        opt.resizeMode = .fast
        let image: UIImage? = await withCheckedContinuation { cont in
            var resumed = false
            mgr.requestImage(for: asset, targetSize: CGSize(width: 1400, height: 1400), contentMode: .aspectFit, options: opt) { im, info in
                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded { return }
                if !resumed { resumed = true; cont.resume(returning: im) }
            }
        }
        guard let image else { return nil }
        persistThumb(image, id: asset.localIdentifier)
        let text = await AIEngine.recognizeText(image) ?? ""
        let (labels, colors) = analyze(image)
        return Read(text: text, labels: labels, colors: colors)
    }

    /// On-device Vision classification + dominant colours. Best-effort: returns empty on any failure.
    private static func analyze(_ image: UIImage) -> (labels: [String], colors: [String]) {
        guard let cg = image.cgImage else { return ([], []) }
        var labels: [String] = []
        let req = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([req])
        if let obs = req.results {
            labels = obs.filter { $0.confidence > 0.25 }.prefix(12)
                .map { $0.identifier.lowercased().replacingOccurrences(of: "_", with: " ") }
        }
        return (labels, dominantColors(cg))
    }

    /// Dominant colour names from a tiny downsample of the image.
    private static func dominantColors(_ cg: CGImage) -> [String] {
        let w = 24, h = 24
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var counts: [String: Int] = [:]
        var i = 0
        while i < data.count {
            let r = Double(data[i]) / 255, g = Double(data[i + 1]) / 255, b = Double(data[i + 2]) / 255
            if let name = colorName(r, g, b) { counts[name, default: 0] += 1 }
            i += 4
        }
        let total = w * h
        return counts.filter { $0.value > total / 12 }.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }

    /// Classify one RGB sample into an everyday colour name (nil = too neutral to count).
    private static func colorName(_ r: Double, _ g: Double, _ b: Double) -> String? {
        let maxc = max(r, g, b), minc = min(r, g, b), d = maxc - minc
        let light = (maxc + minc) / 2
        if d < 0.12 {                       // low saturation → grey scale
            if light < 0.2 { return "black" }
            if light > 0.85 { return "white" }
            return "gray"
        }
        var hue: Double
        if maxc == r { hue = (g - b) / d }
        else if maxc == g { hue = 2 + (b - r) / d }
        else { hue = 4 + (r - g) / d }
        hue = (hue * 60).truncatingRemainder(dividingBy: 360); if hue < 0 { hue += 360 }
        switch hue {
        case 0..<15, 345...360: return "red"
        case 15..<45:  return light < 0.4 ? "brown" : "orange"
        case 45..<70:  return "yellow"
        case 70..<170: return "green"
        case 170..<200: return "teal"
        case 200..<255: return "blue"
        case 255..<290: return "purple"
        default:        return "pink"
        }
    }

    // MARK: cached source thumbnails — written at index time, shown without needing photo permission.

    private static var thumbDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("memory-thumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private static func thumbURL(_ id: String) -> URL {
        let safe = Data(id.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "=", with: "")
        return thumbDir.appendingPathComponent(safe + ".jpg")
    }
    private static func persistThumb(_ image: UIImage, id: String) {
        let target: CGFloat = 480
        let longest = max(image.size.width, image.size.height)
        let scale = longest > target ? target / longest : 1
        let sz = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let small = UIGraphicsImageRenderer(size: sz).image { _ in image.draw(in: CGRect(origin: .zero, size: sz)) }
        if let d = small.jpegData(compressionQuality: 0.7) { try? d.write(to: thumbURL(id), options: .atomic) }
    }
    static func cachedThumbnail(id: String) -> UIImage? {
        guard let d = try? Data(contentsOf: thumbURL(id)) else { return nil }
        return UIImage(data: d)
    }

    /// True when the library has photos not yet in the saved index (new shots since last time, or a
    /// never-built index). A cheap count check used to continue indexing in the background so the first
    /// build is the only slow one and later opens just pick up what's new.
    static func hasUnindexed() -> Bool {
        PHAsset.fetchAssets(with: .image, options: PHFetchOptions()).count > loadCache().count
    }

    /// Build or continue the index over the WHOLE photo library (newest first — no cap), reusing the
    /// cache for photos already read so only new/changed ones are analysed. The index is saved after
    /// every batch, so it's resumable and searchable *as it builds*: `onBatch` hands back the sorted
    /// index so far, `onProgress` reports (done, total). Returns the final sorted index.
    static func index(onBatch: @escaping ([Entry]) -> Void,
                      onProgress: @escaping (_ done: Int, _ total: Int) -> Void) async -> [Entry] {
        var cache = Dictionary(uniqueKeysWithValues: loadCache().map { ($0.id, $0) })
        let fetch = PHFetchOptions()
        fetch.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .image, options: fetch)   // no fetchLimit — the whole library
        let total = assets.count
        guard total > 0 else { onProgress(0, 0); onBatch([]); return [] }
        var out: [Entry] = []; out.reserveCapacity(total)
        var sinceSave = 0
        for i in 0..<total {
            let a = assets.object(at: i)
            let mod = a.modificationDate ?? a.creationDate ?? .distantPast
            let shot = a.mediaSubtypes.contains(.photoScreenshot)
            // Reuse the cache only if it was read AND already carries the visual analysis (labels key
            // present) — older text-only entries are re-read once so visual search works on them too.
            if let hit = cache[a.localIdentifier], hit.modified == mod, hit.readOK ?? true, hit.labels != nil {
                out.append(hit)
            } else if let r = await readAsset(a) {
                let e = Entry(id: a.localIdentifier, date: a.creationDate ?? .distantPast, text: r.text,
                              modified: mod, readOK: true, labels: r.labels, colors: r.colors, isScreenshot: shot)
                cache[a.localIdentifier] = e
                out.append(e)
                sinceSave += 1
            } else if let stale = cache[a.localIdentifier] {
                out.append(stale)   // keep whatever we had rather than dropping the photo
            }
            onProgress(i + 1, total)
            // Persist + publish a searchable snapshot every 40 freshly-read photos, and at the very end,
            // so a 10,000-photo library fills in gradually and survives the app being closed mid-build.
            if sinceSave >= 40 || i == total - 1 {
                let snapshot = out.sorted { $0.date > $1.date }
                saveCache(snapshot)
                onBatch(snapshot)
                sinceSave = 0
            }
        }
        return out.sorted { $0.date > $1.date }
    }

    // MARK: search — text + visual labels + colour, each result carrying why it matched.

    /// Colour words people use that should map onto our detected colour names.
    private static let colorWords: Set<String> = ["red","orange","yellow","green","blue","teal","purple","pink","brown","black","white","gray","grey"]
    private static func normColor(_ t: String) -> String { t == "grey" ? "gray" : t }

    static func search(_ query: String, in entries: [Entry], top: Int = 8) -> [Match] {
        let terms = tokens(query)
        guard !terms.isEmpty else { return [] }
        let now = Date()
        let scored: [(Match, Double)] = entries.compactMap { e in
            let text = e.text.lowercased()
            let labels = e.labels ?? []
            let colors = e.colors ?? []
            var score = 0.0
            var reasons: [String] = []
            for t in terms {
                if text.contains(t) { score += 2 + Double(t.count) / 12; reasons.append("“\(t)” in the text") }
                if let lbl = labels.first(where: { $0.contains(t) || t.contains($0) }) { score += 3; reasons.append("shows \(lbl)") }
                if colorWords.contains(t), colors.contains(normColor(t)) { score += 2.5; reasons.append("\(t) in the picture") }
            }
            guard score > 0 else { return nil }
            let ageDays = now.timeIntervalSince(e.date) / 86_400
            score += max(0, 1.0 - ageDays / 180)               // gentle recency nudge
            // De-duplicate reasons, keep order, cap at three.
            var seen = Set<String>(); var uniq: [String] = []
            for r in reasons where !seen.contains(r) { seen.insert(r); uniq.append(r) }
            let reason = uniq.prefix(3).joined(separator: " · ")
            return (Match(entry: e, reason: reason.isEmpty ? "related" : reason), score)
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(top).map { $0.0 }
    }

    private static let stop: Set<String> = ["the","a","an","my","me","i","is","was","of","to","in","on","for","what","whats","where","show","find","that","this","it","and","do","did","have","had","saved","photo","photos","screenshot","screenshots","picture","pictures","pic","pics","with","wearing","was","at"]
    static func tokens(_ s: String) -> [String] {
        s.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stop.contains($0) }
    }

    /// The single best line from a matched photo — the fallback "answer" when there's no model.
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

    /// On Apple Intelligence phones, extract the precise answer from the matched photos' text.
    static func answer(question: String, from entries: [Entry]) async -> String? {
        guard AIEngine.isAvailable, !entries.isEmpty else { return nil }
        // Only text-bearing photos can answer a factual question; a purely visual match has nothing to read.
        let withText = entries.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !withText.isEmpty else { return nil }
        let context = withText.prefix(4).enumerated()
            .map { "PHOTO \($0.offset + 1) (\(Self.dateString($0.element.date))):\n\($0.element.text.prefix(600))" }
            .joined(separator: "\n\n")
        let instructions = "You answer a question using ONLY the text read from the user's own photos below. Give the exact answer in one short line (a password, code, number, address, name, date). If the answer isn't in the text, say 'I couldn't find that in your photos.' Never guess."
        return try? await AIEngine.run(instructions: instructions, prompt: "Question: \(question)\n\n\(context)")
    }

    static func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d)
    }

    /// Load a thumbnail for a result row — the cached copy first (reliable, no permission needed).
    static func thumbnail(id: String, size: CGFloat = 120) async -> UIImage? {
        if let cached = cachedThumbnail(id: id) { return cached }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let mgr = PHImageManager.default()
        let opt = PHImageRequestOptions(); opt.deliveryMode = .highQualityFormat; opt.isNetworkAccessAllowed = true
        return await withCheckedContinuation { cont in
            var resumed = false
            mgr.requestImage(for: asset, targetSize: CGSize(width: size, height: size), contentMode: .aspectFill, options: opt) { im, info in
                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded { return }
                if !resumed { resumed = true; cont.resume(returning: im) }
            }
        }
    }

    /// The full-resolution source photo, for the viewer. Falls back to the cached thumbnail.
    static func fullImage(id: String) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return cachedThumbnail(id: id) }
        let mgr = PHImageManager.default()
        let opt = PHImageRequestOptions(); opt.deliveryMode = .highQualityFormat; opt.isNetworkAccessAllowed = true
        let img: UIImage? = await withCheckedContinuation { cont in
            var resumed = false
            mgr.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: opt) { im, info in
                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded { return }
                if !resumed { resumed = true; cont.resume(returning: im) }
            }
        }
        return img ?? cachedThumbnail(id: id)
    }
}

/// Observable index for the Memory view: tracks progress and holds the entries.
@MainActor final class MemoryIndex: ObservableObject {
    @Published private(set) var entries: [MemoryEngine.Entry] = MemoryEngine.loadCache()
    @Published private(set) var indexing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var done = 0
    @Published private(set) var total = 0
    @Published private(set) var indexedAt: Date? = nil

    func refresh() {
        guard !indexing else { return }
        indexing = true; progress = 0; done = 0; total = 0
        Task {
            let result = await MemoryEngine.index(
                onBatch: { snap in Task { @MainActor in self.entries = snap } },
                onProgress: { d, t in Task { @MainActor in self.done = d; self.total = t; self.progress = t > 0 ? Double(d) / Double(t) : 0 } }
            )
            await MainActor.run { self.entries = result; self.indexedAt = Date(); self.indexing = false }
        }
    }

    /// After an index already exists, quietly pick up photos taken since last time so later opens are
    /// instant and self-maintaining. No-op while already building or if nothing is new.
    func catchUpIfNeeded() {
        guard !indexing, !entries.isEmpty else { return }
        Task.detached {
            if MemoryEngine.hasUnindexed() { await MainActor.run { self.refresh() } }
        }
    }
}
