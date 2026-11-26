import Photos
import Vision
import UIKit
import SwiftUI

/// On-device storage cleaner: finds screenshots, large videos, and near-duplicate photos so you can
/// delete the ones you choose. Nothing leaves the phone, and every deletion goes through the system's
/// own confirmation sheet — we only ever ASK PhotoKit to delete; iOS shows the "Delete N items?" prompt
/// and does the removal. Sizes are honest estimates (labelled "about"), derived from each asset's
/// pixels/duration — no private APIs.
enum PhotoCleaner {

    struct Item: Identifiable, Equatable {
        let asset: PHAsset
        var id: String { asset.localIdentifier }
        let bytes: Int64
        var fromCamera: Bool = true     // false = saved / downloaded / forwarded to this phone
        static func == (a: Item, b: Item) -> Bool { a.id == b.id }
    }

    /// True when a video looks like it was recorded by THIS phone's camera: a QuickTime .MOV whose
    /// original resource is named IMG_… (how iOS names camera captures). Videos saved, downloaded or
    /// forwarded in — from Messages, WhatsApp, the web — are almost always .mp4 with other names, so
    /// they come back false. A heuristic, but it catches the common "someone sent me this" case.
    static func isCameraOriginal(_ a: PHAsset) -> Bool {
        let resources = PHAssetResource.assetResources(for: a)
        guard let r = resources.first(where: { $0.type == .video }) ?? resources.first else { return true }
        let name = r.originalFilename.uppercased()
        let isMOV = r.uniformTypeIdentifier == "com.apple.quicktime-movie" || name.hasSuffix(".MOV")
        let isCameraName = name.hasPrefix("IMG_") || name.hasPrefix("TRIM.")   // captures + in-Photos trims
        return isMOV && isCameraName
    }

    // MARK: access

    static func authorize() async -> PHAuthorizationStatus {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { cont.resume(returning: $0) }
        }
    }
    static var authorized: Bool {
        let s = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return s == .authorized || s == .limited
    }

    /// Honest size estimate (no private file-size API): photos from pixels, videos from duration.
    static func estimatedBytes(of a: PHAsset) -> Int64 {
        if a.mediaType == .video { return Int64(max(1, a.duration) * 3_000_000 / 8) }   // ~3 Mbps
        let px = Int64(a.pixelWidth) * Int64(a.pixelHeight)
        return max(120_000, px / 4)                                                     // typical HEIC/JPEG
    }

    private static func collect(_ result: PHFetchResult<PHAsset>) -> [Item] {
        var out: [Item] = []
        result.enumerateObjects { a, _, _ in out.append(Item(asset: a, bytes: estimatedBytes(of: a))) }
        return out
    }

    // MARK: scans

    /// "Keep only my newest N": everything after the first `keep` of a newest-first list, leaving out anything
    /// to protect (a favourite stays even when it's old). Pure and unit-tested.
    static func beyondNewest<T>(_ newestFirst: [T], keep: Int, protect: (T) -> Bool = { _ in false }) -> [T] {
        guard keep >= 0, newestFirst.count > keep else { return [] }
        return newestFirst.dropFirst(keep).filter { !protect($0) }
    }

    static func screenshots() -> [Item] {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "(mediaSubtype & %d) != 0", Int(PHAssetMediaSubtype.photoScreenshot.rawValue))
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return collect(PHAsset.fetchAssets(with: .image, options: o))
    }

    /// Videos worth clearing. `receivedOnly == false`: large videos (≥20 MB), any source — the big
    /// files. `receivedOnly == true`: videos that didn't come from this phone's camera (saved,
    /// downloaded or forwarded to you), any size down to ~1 MB, so you can clear what others sent.
    static func videos(receivedOnly: Bool) -> [Item] {
        let o = PHFetchOptions()
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]   // newest-first; the view re-sorts by size when asked
        var out: [Item] = []
        PHAsset.fetchAssets(with: .video, options: o).enumerateObjects { a, _, _ in
            let bytes = estimatedBytes(of: a)
            if receivedOnly {
                guard !isCameraOriginal(a), bytes >= 1_000_000 else { return }
                out.append(Item(asset: a, bytes: bytes, fromCamera: false))
            } else {
                guard bytes >= 20_000_000 else { return }
                out.append(Item(asset: a, bytes: bytes, fromCamera: isCameraOriginal(a)))
            }
        }
        return out
    }

    /// What a duplicate check found, and how much of the library it looked at — so the screen never calls a
    /// library "tidy" without saying what was checked.
    struct DupScan {
        var groups: [[Item]]
        var skipped: Int          // in iCloud only (not on the phone) or unreadable, so not checked
        var photos: Int           // photos checked
        var videos: Int           // videos checked
    }

    /// Look-alike photos and copies of the same video, across the WHOLE library (26 Nov: it used to stop at the
    /// newest 500 items, so two copies of an older clip were never compared — Manan found two 31.1 MB copies by eye).
    /// `scanLimit` keeps only the newest N (the daily tidy autorun looks at recent photos only).
    ///
    /// Photos: two photos are copies when Vision's feature print is close (< 0.28) AND the 128-bit difference hash
    /// is near-identical (≤ 10 bits) — the hash stops all white document screenshots grouping as one. The hash is the
    /// cheap half, so every photo gets one (kept on the phone between checks, so a photo is read once), and the feature
    /// print is worked out only for photos whose hash has a near-twin.
    /// Videos: a copy is the same length, so only clips with a same-length partner are looked at; their poster frames
    /// must then be very close (< 0.22). Photos and videos are never grouped with each other.
    static func duplicates(scanLimit: Int? = nil, progress: @escaping (Double) -> Void) async -> DupScan {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if let scanLimit { o.fetchLimit = scanLimit }
        var photos: [PHAsset] = [], videos: [PHAsset] = []
        PHAsset.fetchAssets(with: o).enumerateObjects { a, _, _ in if a.mediaType == .video { videos.append(a) } else { photos.append(a) } }
        guard photos.count + videos.count > 1 else { progress(1); return DupScan(groups: [], skipped: 0, photos: photos.count, videos: videos.count) }

        let mgr = PHImageManager.default()
        let req = PHImageRequestOptions()
        req.isSynchronous = true; req.deliveryMode = .fastFormat; req.resizeMode = .fast; req.isNetworkAccessAllowed = false
        func thumb(_ a: PHAsset) -> CGImage? {
            var image: UIImage?
            mgr.requestImage(for: a, targetSize: CGSize(width: 160, height: 160), contentMode: .aspectFit, options: req) { im, _ in image = im }
            return image?.cgImage
        }
        func featurePrint(_ cg: CGImage) -> VNFeaturePrintObservation? {
            let r = VNGenerateImageFeaturePrintRequest()
            try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([r])
            return r.results?.first as? VNFeaturePrintObservation
        }
        func distance(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) -> Float {
            var d = Float.greatestFiniteMagnitude; try? a.computeDistance(&d, to: b); return d
        }

        // 1. A difference hash for every photo (most come straight from the saved index).
        var index = DupHashIndex.load()
        var hashes: [(UInt64, UInt64)?] = []
        hashes.reserveCapacity(photos.count)
        var skipped = 0
        for (i, a) in photos.enumerated() {
            if Task.isCancelled { break }
            if i % 50 == 0 { progress(0.85 * Double(i) / Double(max(1, photos.count))) }
            let mod = (a.modificationDate ?? a.creationDate ?? .distantPast).timeIntervalSince1970
            if let h = index.hash(a.localIdentifier, modified: mod) { hashes.append(h); continue }
            guard let cg = thumb(a) else { skipped += 1; hashes.append(nil); continue }
            let h = dHash(cg)
            index.set(a.localIdentifier, modified: mod, hash: h); hashes.append(h)
            if index.unsaved >= 500 { index.save() }   // a long first check keeps what it has if the app is closed
        }
        if scanLimit == nil, !Task.isCancelled { index.keepOnly(Set(photos.map(\.localIdentifier))) }
        index.save()
        if Task.isCancelled { return DupScan(groups: [], skipped: skipped, photos: 0, videos: 0) }

        var groups: [[Item]] = []
        // 2. Photos with a near-twin hash: feature prints, then the same rule as always.
        let hashed = hashes.indices.filter { hashes[$0] != nil }
        let photoPairs = nearHashPairs(hashed.map { hashes[$0]! }, within: 10).map { (hashed[$0.0], hashed[$0.1]) }
        var photoPrints: [Int: VNFeaturePrintObservation] = [:]
        for k in Set(photoPairs.flatMap { [$0.0, $0.1] }).sorted() {
            if let cg = thumb(photos[k]), let p = featurePrint(cg) { photoPrints[k] = p }
        }
        progress(0.92)
        let photoMatches = photoPairs.filter { p in
            guard let a = photoPrints[p.0], let b = photoPrints[p.1] else { return false }
            return distance(a, b) < 0.28
        }
        groups += seededGroups(count: photos.count, matches: photoMatches).map { $0.map { Item(asset: photos[$0], bytes: estimatedBytes(of: photos[$0])) } }

        // 3. Videos the same length: poster-frame prints, held to the stricter rule.
        let videoPairs = sameLengthPairs(videos.map(\.duration))
        var videoPrints: [Int: VNFeaturePrintObservation] = [:]
        for k in Set(videoPairs.flatMap { [$0.0, $0.1] }).sorted() {
            if Task.isCancelled { break }
            guard let cg = thumb(videos[k]) else { skipped += 1; continue }
            if let p = featurePrint(cg) { videoPrints[k] = p }
        }
        let videoMatches = videoPairs.filter { p in
            guard let a = videoPrints[p.0], let b = videoPrints[p.1] else { return false }
            return distance(a, b) < 0.22
        }
        groups += seededGroups(count: videos.count, matches: videoMatches).map { $0.map { Item(asset: videos[$0], bytes: estimatedBytes(of: videos[$0])) } }
        progress(1)
        return DupScan(groups: groups, skipped: skipped, photos: photos.count, videos: videos.count)
    }

    /// Every pair of hashes at most `within` bits apart, without comparing every photo with every other: split the
    /// 128 bits into `within + 1` slices — two hashes that close must agree exactly on at least one slice — and only
    /// compare hashes that share a slice. Pure and unit-tested; pairs come back (lower index, higher index), once each.
    static func nearHashPairs(_ hashes: [(UInt64, UInt64)], within: Int) -> [(Int, Int)] {
        guard hashes.count > 1 else { return [] }
        let slices = max(1, within + 1)
        func bit(_ h: (UInt64, UInt64), _ i: Int) -> UInt64 { i < 64 ? (h.0 >> UInt64(i)) & 1 : (h.1 >> UInt64(i - 64)) & 1 }
        let bounds = (0...slices).map { $0 * 128 / slices }
        var seen = Set<Int>()
        var out: [(Int, Int)] = []
        for s in 0..<slices {
            var buckets: [UInt64: [Int]] = [:]
            for (i, h) in hashes.enumerated() {
                var key: UInt64 = 0
                for b in bounds[s]..<bounds[s + 1] { key = (key << 1) | bit(h, b) }
                buckets[key, default: []].append(i)
            }
            for members in buckets.values where members.count > 1 {
                for x in 0..<members.count { for y in (x + 1)..<members.count {
                    let i = members[x], j = members[y]
                    let key = i * hashes.count + j
                    guard !seen.contains(key) else { continue }
                    seen.insert(key)
                    if hamming(hashes[i], hashes[j]) <= within { out.append((i, j)) }
                } }
            }
        }
        return out.sorted { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1 < $1.1 }
    }

    /// Pairs of clips close enough in length to be copies of each other (within a second, or 8% of the longer clip
    /// for long ones). Pure and unit-tested; pairs come back (lower index, higher index).
    static func sameLengthPairs(_ seconds: [Double]) -> [(Int, Int)] {
        let order = seconds.indices.filter { seconds[$0] > 0 }.sorted { seconds[$0] < seconds[$1] }
        var out: [(Int, Int)] = []
        for (k, i) in order.enumerated() {
            for j in order[(k + 1)...] {
                let longer = max(seconds[i], seconds[j])
                guard seconds[j] - seconds[i] < max(1.0, longer * 0.08) else { break }   // sorted: no later clip is closer
                out.append((min(i, j), max(i, j)))
            }
        }
        return out.sorted { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1 < $1.1 }
    }

    /// Groups from matching pairs, newest first: each group is one item plus every later item that matches IT (not a
    /// chain of look-alikes of look-alikes). Pure and unit-tested.
    static func seededGroups(count: Int, matches: [(Int, Int)]) -> [[Int]] {
        var twins: [Int: [Int]] = [:]
        for (a, b) in matches { twins[min(a, b), default: []].append(max(a, b)) }
        var used = Set<Int>()
        var out: [[Int]] = []
        for i in 0..<count where !used.contains(i) {
            guard let later = twins[i] else { continue }
            let members = [i] + later.filter { !used.contains($0) }.sorted()
            guard members.count > 1 else { continue }
            used.formUnion(members); out.append(members)
        }
        return out
    }

    /// 128-bit difference hash (horizontal + vertical gradients). Unlike an average hash — which only
    /// encodes each cell's brightness and so is nearly identical for any two mostly-white documents —
    /// dHash encodes WHERE brightness changes, i.e. where the text and edges are. Two different
    /// documents put their text in different places, so their dHashes differ in many bits; true copies
    /// (and re-saves/resizes) still match. This is the precision guard that stops Vision's perceptual
    /// feature-print from lumping unrelated screenshots together as look-alikes.
    static func dHash(_ cg: CGImage) -> (UInt64, UInt64) {
        func gray(_ w: Int, _ h: Int) -> [UInt8]? { GrayPixels.read(cg, w: w, h: h) }
        var h: UInt64 = 0, v: UInt64 = 0
        if let p = gray(9, 8) {                                    // horizontal: compare each pixel to its right neighbour
            var bit: UInt64 = 0
            for y in 0..<8 { for x in 0..<8 { if p[y * 9 + x] > p[y * 9 + x + 1] { h |= (1 << bit) }; bit += 1 } }
        }
        if let p = gray(8, 9) {                                    // vertical: compare each pixel to the one below it
            var bit: UInt64 = 0
            for y in 0..<8 { for x in 0..<8 { if p[y * 8 + x] > p[(y + 1) * 8 + x] { v |= (1 << bit) }; bit += 1 } }
        }
        return (h, v)
    }
    static func hamming(_ a: (UInt64, UInt64), _ b: (UInt64, UInt64)) -> Int {
        (a.0 ^ b.0).nonzeroBitCount + (a.1 ^ b.1).nonzeroBitCount
    }

    /// Each photo's difference hash, kept on the phone (Application Support, never synced) so the whole library is
    /// read once and later checks only read photos that are new or edited. Holds hashes only — no pictures.
    struct DupHashIndex: Codable {
        struct Entry: Codable { var m: Double; var h: UInt64; var v: UInt64 }
        private(set) var entries: [String: Entry] = [:]
        private(set) var unsaved = 0

        enum CodingKeys: String, CodingKey { case entries }

        static var file: URL {
            let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Cleaner", isDirectory: true)
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
            return d.appendingPathComponent("photo-hashes.plist")
        }
        static var exists: Bool { FileManager.default.fileExists(atPath: file.path) }
        static func load() -> DupHashIndex {
            guard let d = try? Data(contentsOf: file), let i = try? PropertyListDecoder().decode(DupHashIndex.self, from: d) else { return DupHashIndex() }
            return i
        }
        func hash(_ id: String, modified: Double) -> (UInt64, UInt64)? {
            guard let e = entries[id], e.m == modified else { return nil }
            return (e.h, e.v)
        }
        mutating func set(_ id: String, modified: Double, hash: (UInt64, UInt64)) {
            entries[id] = Entry(m: modified, h: hash.0, v: hash.1); unsaved += 1
        }
        /// Forget photos that are no longer in the library.
        mutating func keepOnly(_ ids: Set<String>) {
            let before = entries.count
            entries = entries.filter { ids.contains($0.key) }
            if entries.count != before { unsaved += 1 }
        }
        mutating func save() {
            guard unsaved > 0 || !Self.exists else { return }
            let e = PropertyListEncoder(); e.outputFormat = .binary
            if let d = try? e.encode(self) {
                var url = Self.file
                try? d.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                var rv = URLResourceValues(); rv.isExcludedFromBackup = true; try? url.setResourceValues(rv)
            }
            unsaved = 0
        }
    }

    // MARK: bursts — the best shot of each kept, the rest cleared

    struct Burst: Identifiable { let keep: Item; let extras: [Item]; let why: String; var id: String { keep.id } }

    /// Burst photos: iPhone keeps every frame (hidden behind the cover photo) and they all take space. Keep the
    /// one you picked, else the one iPhone picked as best, else the cover — and say which.
    static func bursts(limit: Int = 4000) -> [Burst] {
        let o = PHFetchOptions()
        o.includeAllBurstAssets = true
        o.predicate = NSPredicate(format: "burstIdentifier != nil")
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        o.fetchLimit = limit
        var byBurst: [String: [PHAsset]] = [:]
        PHAsset.fetchAssets(with: .image, options: o).enumerateObjects { a, _, _ in
            if let b = a.burstIdentifier { byBurst[b, default: []].append(a) }
        }
        return byBurst.values.compactMap { frames -> Burst? in
            guard frames.count > 1 else { return nil }
            let pick = best(frames.map { (id: $0.localIdentifier, user: $0.burstSelectionTypes.contains(.userPick),
                                          auto: $0.burstSelectionTypes.contains(.autoPick), cover: $0.representsBurst, fav: $0.isFavorite) })
            guard let keep = frames.first(where: { $0.localIdentifier == pick.id }) else { return nil }
            let extras = frames.filter { $0.localIdentifier != pick.id && !$0.isFavorite }.map { Item(asset: $0, bytes: estimatedBytes(of: $0)) }
            return extras.isEmpty ? nil : Burst(keep: Item(asset: keep, bytes: estimatedBytes(of: keep)), extras: extras, why: pick.why)
        }.sorted { $0.extras.count > $1.extras.count }
    }

    /// Which frame of a burst to keep, and why. Pure and unit-tested.
    static func best(_ frames: [(id: String, user: Bool, auto: Bool, cover: Bool, fav: Bool)]) -> (id: String, why: String) {
        if let f = frames.first(where: { $0.user }) { return (f.id, "the one you picked") }
        if let f = frames.first(where: { $0.fav }) { return (f.id, "your favourite") }
        if let f = frames.first(where: { $0.auto }) { return (f.id, "iPhone's pick of the burst — sharpest, eyes open") }
        if let f = frames.first(where: { $0.cover }) { return (f.id, "the burst's cover photo") }
        return (frames[0].id, "the first frame")
    }

    // MARK: screenshots older than a month

    static func oldScreenshots(days: Int = 30, now: Date = Date()) -> [Item] {
        let cut = now.addingTimeInterval(-Double(days) * 86_400)
        return screenshots().filter { ($0.asset.creationDate ?? now) < cut && !$0.asset.isFavorite }
    }

    // MARK: the plan — biggest wins first

    struct PlanRow: Identifiable { let id: String; let title: String; let why: String; let items: [Item]
        var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } } }

    /// Rows with something in them, largest first. Pure: the caller fills the rows.
    static func plan(_ rows: [PlanRow]) -> [PlanRow] { rows.filter { !$0.items.isEmpty }.sorted { $0.bytes > $1.bytes } }

    /// Space free on the phone right now (what iOS would let an important download use).
    static func freeBytes() -> Int64? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        return (try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage
    }

    // MARK: delete (iOS shows the confirmation and performs it)

    static func delete(_ assets: [PHAsset]) async -> Bool {
        guard !assets.isEmpty else { return false }
        return await withCheckedContinuation { cont in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
            } completionHandler: { ok, _ in cont.resume(returning: ok) }
        }
    }

    static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// Runs the expensive duplicate scan in the background and caches the result, so by the time the user
/// opens Cleaner the Duplicates tab is already filled instead of making them wait. Kicked off at app
/// launch (when photo access is already granted) and again when Cleaner appears. The cheap scans
/// (screenshots, large videos) are plain PhotoKit fetches and stay on-demand — they're already fast.
@MainActor final class CleanerIndex: ObservableObject {
    static let shared = CleanerIndex()
    private init() {}

    @Published private(set) var duplicates: [[PhotoCleaner.Item]]? = nil   // nil = never scanned yet
    @Published private(set) var scanning = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var skippedInCloud = 0   // couldn't be dup-checked (in iCloud, not downloaded)
    @Published private(set) var photosChecked = 0
    @Published private(set) var videosChecked = 0
    @Published private(set) var startedAt: Date?

    private var scannedAt: Date?
    private var task: Task<Void, Never>?

    /// Fresh for 10 minutes — long enough that opening the tool reuses the launch scan, short enough
    /// that a library that changed during a session gets re-scanned on the next prewarm.
    var isFresh: Bool { duplicates != nil && (scannedAt.map { Date().timeIntervalSince($0) < 600 } ?? false) }

    /// "About 2 min left" while a check runs, from how far it has got (nil until there's enough to go on).
    var timeLeft: String? {
        guard scanning, let s = startedAt, progress > 0.05, progress < 0.99 else { return nil }
        let left = Date().timeIntervalSince(s) * (1 - progress) / progress
        return left < 60 ? L("Less than a minute left") : String(format: L("About %d min left"), Int((left / 60).rounded(.up)))
    }

    /// Start a background scan if one isn't already running and the cache isn't fresh. Safe to call
    /// repeatedly (launch, tool appear, permission granted) — it no-ops when there's nothing to do.
    /// At launch it only runs once the library has been checked before (then it reads just the new photos);
    /// the first whole-library read waits until the person opens Cleaner, so it never costs battery unasked.
    func prewarm(fromLaunch: Bool = false) {
        guard PhotoCleaner.authorized, !scanning, !isFresh else { return }
        if fromLaunch && !PhotoCleaner.DupHashIndex.exists { return }
        start()
    }

    /// Force a fresh scan (the Rescan button).
    func rescan() { scannedAt = nil; start() }

    private func start() {
        guard !scanning else { return }
        scanning = true; progress = 0; startedAt = Date()
        task?.cancel()
        task = Task { [weak self] in
            let found = await PhotoCleaner.duplicates(progress: { p in Task { @MainActor in self?.progress = p } })
            guard let self, !Task.isCancelled else { return }
            self.duplicates = found.groups
            self.skippedInCloud = found.skipped
            self.photosChecked = found.photos
            self.videosChecked = found.videos
            self.scannedAt = Date()
            self.scanning = false
        }
    }

    /// Drop deleted assets from the cache after a delete, without a re-scan.
    func remove(ids: Set<String>) {
        guard var g = duplicates else { return }
        g = g.map { $0.filter { !ids.contains($0.id) } }.filter { $0.count > 1 }
        duplicates = g
    }
}
