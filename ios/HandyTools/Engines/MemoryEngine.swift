import Photos
import BackgroundTasks
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
        var isVideo: Bool? = nil          // indexed from a video's poster frame
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
            labels = obs.filter { $0.confidence > 0.20 }.prefix(16)
                .map { $0.identifier.lowercased().replacingOccurrences(of: "_", with: " ") }
        }
        return (labels, dominantColors(cg))
    }

    /// Dominant colour names from a tiny downsample of the image.
    private static func dominantColors(_ cg: CGImage) -> [String] {
        let w = 24, h = 24
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        let drew = data.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drew else { return [] }
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
        let cached = Set(loadCache().map { $0.id })
        let assets = PHAsset.fetchAssets(with: mediaFetch())
        var found = false
        assets.enumerateObjects { a, _, stop in
            if !cached.contains(a.localIdentifier) { found = true; stop.pointee = true }
        }
        return found
    }

    /// Photos AND videos, newest first. Videos are indexed from their poster frame (objects, colours,
    /// any on-screen text), so "my dog at the beach" or a clip with a code in it is findable too.
    private static func mediaFetch() -> PHFetchOptions {
        let f = PHFetchOptions()
        f.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        f.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d",
                                  PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        return f
    }

    /// Build or continue the index over the WHOLE photo library (newest first — no cap), reusing the
    /// cache for photos already read so only new/changed ones are analysed. The index is saved after
    /// every batch, so it's resumable and searchable *as it builds*: `onBatch` hands back the sorted
    /// index so far, `onProgress` reports (done, total). Returns the final sorted index.
    static func index(quiet: Bool = false, onBatch: @escaping ([Entry]) -> Void,
                      onProgress: @escaping (_ done: Int, _ total: Int) -> Void) async -> [Entry] {
        var cache = Dictionary(uniqueKeysWithValues: loadCache().map { ($0.id, $0) })
        let assets = PHAsset.fetchAssets(with: mediaFetch())   // whole library, photos + videos, no cap
        let n = assets.count
        guard n > 0 else { onProgress(0, 0); onBatch([]); saveCache([]); return [] }

        // One cheap metadata pass (no image loads): collect only the photos that still need reading —
        // brand-new ones, or ones edited since we read them — and note which ids still exist so deleted
        // photos drop out. Everything already in the cache is left untouched and never re-analysed.
        var todo: [PHAsset] = []
        var liveIds = Set<String>(); liveIds.reserveCapacity(n)
        for i in 0..<n {
            let a = assets.object(at: i)
            liveIds.insert(a.localIdentifier)
            let mod = a.modificationDate ?? a.creationDate ?? .distantPast
            // Reuse the cache only if it was read AND already carries the visual analysis (labels key
            // present) — older text-only entries are re-read once so visual search works on them too.
            if let hit = cache[a.localIdentifier], hit.modified == mod, hit.readOK ?? true, hit.labels != nil {
                continue
            }
            todo.append(a)
        }
        // Forget photos that no longer exist, so counts and search stay honest.
        if cache.count != liveIds.count || !cache.keys.allSatisfy(liveIds.contains) {
            cache = cache.filter { liveIds.contains($0.key) }
        }

        // Nothing new since last time — the common path on every open after the first build. Do no
        // heavy work: hand back the saved index instantly, no "building" progress.
        if todo.isEmpty {
            let snapshot = cache.values.sorted { $0.date > $1.date }
            onProgress(0, 0); onBatch(snapshot); saveCache(snapshot)
            return snapshot
        }

        // Read ONLY the new/changed photos. Progress is over this delta (e.g. "12"), never the whole
        // library, so the slow first build is the only slow pass — later opens just pick up what's new.
        let total = todo.count
        var done = 0, sinceSave = 0
        for a in todo {
            // Stop cleanly when told to (leaving, background time up) — what's read so far is saved below.
            if Task.isCancelled { break }
            // In the background of the app, go gently: pause on Low Power Mode or a hot phone, and breathe
            // between photos so the phone stays cool and every other tool stays quick.
            if quiet, !(await PhotoIndexPacer.mayContinue()) { break }
            let mod = a.modificationDate ?? a.creationDate ?? .distantPast
            let shot = a.mediaSubtypes.contains(.photoScreenshot)
            let vid = a.mediaType == .video
            if let r = await readAsset(a) {
                cache[a.localIdentifier] = Entry(id: a.localIdentifier, date: a.creationDate ?? .distantPast, text: r.text,
                                                 modified: mod, readOK: true, labels: r.labels, colors: r.colors, isScreenshot: shot, isVideo: vid)
                sinceSave += 1
            }   // a failed read keeps any existing entry and is retried on a later open
            done += 1
            onProgress(done, total)
            // Persist + publish a searchable snapshot every 40 freshly-read photos, and at the very end,
            // so a big first build fills in gradually and survives the app being closed mid-build.
            if sinceSave >= 40 || done == total {
                let snapshot = cache.values.sorted { $0.date > $1.date }
                saveCache(snapshot)
                onBatch(snapshot)
                sinceSave = 0
            }
        }
        let final = cache.values.sorted { $0.date > $1.date }
        if sinceSave > 0 { saveCache(final); onBatch(final) }
        return final
    }

    // MARK: search — text + visual labels + colour, each result carrying why it matched.

    /// Colour words people use that should map onto our detected colour names.
    private static let colorWords: Set<String> = ["red","orange","yellow","green","blue","teal","purple","pink","brown","black","white","gray","grey"]
    private static func normColor(_ t: String) -> String { t == "grey" ? "gray" : t }

    /// Everyday words → the broader labels Apple's on-device classifier actually emits, so a specific
    /// query ("red dress", "my dog at the beach") still matches the general labels on the photo.
    private static let labelSynonyms: [String: [String]] = [
        "dress": ["clothing","apparel","gown","outfit","skirt","frock","woman","person"],
        "shirt": ["clothing","apparel","top","tshirt","jersey","person"],
        "clothes": ["clothing","apparel","outfit","dress","shirt","jacket","coat"],
        "outfit": ["clothing","apparel","dress","fashion","person"],
        "suit": ["clothing","apparel","formal","blazer","tuxedo"],
        "car": ["vehicle","automobile","truck","suv","sedan","van"],
        "bike": ["bicycle","cycle","motorcycle","vehicle"],
        "dog": ["pet","puppy","canine","animal"],
        "cat": ["pet","kitten","feline","animal"],
        "pet": ["dog","cat","animal","puppy","kitten"],
        "beach": ["sea","ocean","sand","shore","coast","seaside"],
        "food": ["meal","dish","plate","cuisine","restaurant","snack"],
        "drink": ["beverage","cocktail","coffee","tea","cup","glass"],
        "flower": ["flowers","plant","bloom","blossom","floral"],
        "mountain": ["mountains","hill","peak","landscape"],
        "building": ["house","architecture","tower","skyscraper","city"],
        "receipt": ["bill","invoice","document","paper","text"],
        "baby": ["infant","child","toddler","newborn","person"],
        "selfie": ["person","face","portrait","people"],
        "sunset": ["sunrise","sky","dusk","horizon"],
        "snow": ["winter","ice","snowy","landscape"],
    ]

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
                // Match the word itself AND the broader labels it implies (dress → clothing/person…).
                let expanded = [t] + (labelSynonyms[t] ?? [])
                if let lbl = labels.first(where: { lbl in expanded.contains { lbl.contains($0) || $0.contains(lbl) } }) {
                    score += 3; reasons.append("shows \(lbl)")
                }
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

/// The photo index, one for the whole app: it builds quietly from the moment Tenzy has photo access — at launch,
/// while you use any other tool, and overnight while the phone charges — so Search My Photos is ready the first time
/// it's opened, and every later open only reads the photos taken since. Opening the tool while it's still building
/// switches it to full speed.
@MainActor final class MemoryIndex: ObservableObject {
    static let shared = MemoryIndex()

    @Published private(set) var entries: [MemoryEngine.Entry] = MemoryEngine.loadCache()
    @Published private(set) var indexing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var done = 0
    @Published private(set) var total = 0
    @Published private(set) var indexedAt: Date? = nil
    private var work: Task<Void, Never>?
    private var bgToken: BackgroundToken?

    static let backgroundTaskID = "com.tenzy.toolkit.photoindex"

    /// Build (or catch up) at full speed — someone is waiting in Search My Photos.
    func refresh() {
        PhotoIndexPacer.setUrgent(true)
        run(quiet: false)
    }

    /// Build or catch up gently, without anyone waiting: on launch, and whenever the app comes back.
    func startQuietly() {
        guard !indexing, Self.hasAccess else { return }
        Task.detached(priority: .background) {
            let needed = MemoryEngine.hasUnindexed()
            await MainActor.run { if needed { self.run(quiet: true) } else { self.scheduleOvernight(false) } }
        }
    }

    /// The tool is open: whatever's building goes full speed; otherwise catch up on new photos.
    func catchUpIfNeeded() {
        PhotoIndexPacer.setUrgent(true)
        guard !indexing else { return }
        Task.detached {
            if MemoryEngine.hasUnindexed() { await MainActor.run { self.refresh() } }
        }
    }

    /// The tool was closed: anything still building carries on gently.
    func leftTheTool() { PhotoIndexPacer.setUrgent(false) }

    static var hasAccess: Bool {
        let s = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return s == .authorized || s == .limited
    }

    private func run(quiet: Bool) {
        guard !indexing else { return }
        indexing = true; progress = 0; done = 0; total = 0
        work = Task(priority: quiet ? .background : .userInitiated) {
            let result = await MemoryEngine.index(
                quiet: quiet,
                onBatch: { snap in Task { @MainActor in self.entries = snap } },
                onProgress: { d, t in Task { @MainActor in self.done = d; self.total = t; self.progress = t > 0 ? Double(d) / Double(t) : 0 } }
            )
            await MainActor.run {
                self.entries = result; self.indexedAt = Date(); self.indexing = false
                self.bgToken?.end(); self.bgToken = nil
                // Not finished (paused for battery, heat or background)? Finish overnight on the charger.
                self.scheduleOvernight(self.total > 0 && self.done < self.total)
            }
        }
    }

    /// Going to the background: keep reading for the half-minute iOS allows, saving as it goes.
    func enteredBackground() {
        guard indexing else { return }
        let token = BackgroundToken()
        let job = work
        token.id = UIApplication.shared.beginBackgroundTask(withName: "photo-index") { job?.cancel(); token.end() }
        bgToken = token
        scheduleOvernight(true)
    }

    @MainActor private final class BackgroundToken {
        var id: UIBackgroundTaskIdentifier = .invalid
        func end() { if id != .invalid { UIApplication.shared.endBackgroundTask(id); id = .invalid } }
    }

    /// Ask iOS for time to finish while the phone is charging and idle (usually overnight). Never on battery.
    func scheduleOvernight(_ needed: Bool) {
        guard needed else { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskID); return }
        let r = BGProcessingTaskRequest(identifier: Self.backgroundTaskID)
        r.requiresExternalPower = true
        r.requiresNetworkConnectivity = false
        try? BGTaskScheduler.shared.submit(r)
    }

    /// Register the overnight job (call once at launch).
    nonisolated static func registerBackground() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskID, using: nil) { task in
            let job = Task {
                let result = await MemoryEngine.index(quiet: false, onBatch: { _ in }, onProgress: { _, _ in })
                await MainActor.run {
                    MemoryIndex.shared.entries = result
                    MemoryIndex.shared.scheduleOvernight(MemoryEngine.hasUnindexed())
                }
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { job.cancel() }
        }
    }
}

/// How hard the photo index may work right now. Full speed while someone waits in the tool; otherwise gentle:
/// stops on Low Power Mode or when the phone is warm, and pauses between photos (shorter on the charger).
enum PhotoIndexPacer {
    private static let lock = NSLock()
    private static var urgent = false
    static func setUrgent(_ on: Bool) { lock.lock(); urgent = on; lock.unlock() }
    static var isUrgent: Bool { lock.lock(); defer { lock.unlock() }; return urgent }

    /// Pure: whether to keep going, and how long to rest before the next photo.
    static func plan(urgent: Bool, lowPower: Bool, thermal: ProcessInfo.ThermalState, charging: Bool) -> (go: Bool, restMs: Int) {
        if urgent { return (thermal != .critical, 0) }
        if lowPower || thermal == .serious || thermal == .critical { return (false, 0) }
        if thermal == .fair { return (true, charging ? 150 : 400) }
        return (true, charging ? 20 : 120)
    }

    static func mayContinue() async -> Bool {
        let charging = await MainActor.run { () -> Bool in
            UIDevice.current.isBatteryMonitoringEnabled = true
            return UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        }
        let pi = ProcessInfo.processInfo
        let p = plan(urgent: isUrgent, lowPower: pi.isLowPowerModeEnabled, thermal: pi.thermalState, charging: charging)
        if p.go, p.restMs > 0 { try? await Task.sleep(nanoseconds: UInt64(p.restMs) * 1_000_000) }
        return p.go && !Task.isCancelled
    }
}
