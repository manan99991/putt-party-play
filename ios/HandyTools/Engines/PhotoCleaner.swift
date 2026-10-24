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

    /// Group near-duplicate photos using Vision feature prints over the most recent `scanLimit` photos
    /// (bounded so a huge library can't stall). Each returned group has 2+ look-alikes.
    /// Covers photos AND videos. A video is fingerprinted on its poster frame (PhotoKit hands one back
    /// for a video the same as a photo), so two copies of the same clip group together. Photos and
    /// videos are never grouped with each other, and video matches are held to a stricter look-alike
    /// threshold plus a similar-duration check so two unrelated clips that open on a dark frame don't
    /// get lumped in.
    static func duplicates(scanLimit: Int = 500, progress: @escaping (Double) -> Void) async -> (groups: [[Item]], skipped: Int) {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        o.fetchLimit = scanLimit
        let fetch = PHAsset.fetchAssets(with: o)
        var assets: [PHAsset] = []
        fetch.enumerateObjects { a, _, _ in assets.append(a) }
        guard assets.count > 1 else { progress(1); return ([], 0) }

        let mgr = PHImageManager.default()
        let req = PHImageRequestOptions()
        req.isSynchronous = true; req.deliveryMode = .fastFormat; req.resizeMode = .fast; req.isNetworkAccessAllowed = false

        var prints: [(PHAsset, VNFeaturePrintObservation, (UInt64, UInt64))] = []
        var skipped = 0   // iCloud-only or unreadable assets we couldn't fingerprint (network is off here)
        for (i, a) in assets.enumerated() {
            if i % 10 == 0 { progress(Double(i) / Double(assets.count)) }
            var image: UIImage?
            mgr.requestImage(for: a, targetSize: CGSize(width: 160, height: 160), contentMode: .aspectFit, options: req) { im, _ in image = im }
            guard let cg = image?.cgImage else { skipped += 1; continue }
            let r = VNGenerateImageFeaturePrintRequest()
            try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([r])
            if let p = r.results?.first as? VNFeaturePrintObservation { prints.append((a, p, dHash(cg))) }
        }
        progress(1)

        var used = [Bool](repeating: false, count: prints.count)
        var groups: [[Item]] = []
        for i in 0..<prints.count where !used[i] {
            let a = prints[i].0
            var members = [i]; used[i] = true
            for j in (i + 1)..<prints.count where !used[j] {
                let b = prints[j].0
                guard a.mediaType == b.mediaType else { continue }     // never mix a photo with a video
                var dist = Float.greatestFiniteMagnitude
                try? prints[i].1.computeDistance(&dist, to: prints[j].1)
                let nearIdentical = a.mediaType == .video
                    ? (dist < 0.22 && abs(a.duration - b.duration) < max(1.0, a.duration * 0.08))  // stricter + similar length
                    // Photos: the perceptual feature-print lumps all white text screenshots together
                    // (they're semantically "a document"), so require the 128-bit difference hash to be
                    // near-identical too. dHash encodes WHERE edges/text sit, so two different documents
                    // differ in many bits and are no longer grouped — while true copies still match.
                    : (dist < 0.28 && hamming(prints[i].2, prints[j].2) <= 10)
                if nearIdentical { members.append(j); used[j] = true }
            }
            if members.count > 1 { groups.append(members.map { Item(asset: prints[$0].0, bytes: estimatedBytes(of: prints[$0].0)) }) }
        }
        return (groups, skipped)
    }

    /// 128-bit difference hash (horizontal + vertical gradients). Unlike an average hash — which only
    /// encodes each cell's brightness and so is nearly identical for any two mostly-white documents —
    /// dHash encodes WHERE brightness changes, i.e. where the text and edges are. Two different
    /// documents put their text in different places, so their dHashes differ in many bits; true copies
    /// (and re-saves/resizes) still match. This is the precision guard that stops Vision's perceptual
    /// feature-print from lumping unrelated screenshots together as look-alikes.
    static func dHash(_ cg: CGImage) -> (UInt64, UInt64) {
        func gray(_ w: Int, _ h: Int) -> [UInt8]? {
            var px = [UInt8](repeating: 0, count: w * h)
            guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return px
        }
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

    private var scannedAt: Date?
    private var task: Task<Void, Never>?

    /// Fresh for 10 minutes — long enough that opening the tool reuses the launch scan, short enough
    /// that a library that changed during a session gets re-scanned on the next prewarm.
    var isFresh: Bool { duplicates != nil && (scannedAt.map { Date().timeIntervalSince($0) < 600 } ?? false) }

    /// Start a background scan if one isn't already running and the cache isn't fresh. Safe to call
    /// repeatedly (launch, tool appear, permission granted) — it no-ops when there's nothing to do.
    func prewarm() {
        guard PhotoCleaner.authorized, !scanning, !isFresh else { return }
        start()
    }

    /// Force a fresh scan (the Rescan button).
    func rescan() { scannedAt = nil; start() }

    private func start() {
        guard !scanning else { return }
        scanning = true; progress = 0
        task?.cancel()
        task = Task { [weak self] in
            let (groups, skipped) = await PhotoCleaner.duplicates(progress: { p in Task { @MainActor in self?.progress = p } })
            guard let self, !Task.isCancelled else { return }
            self.duplicates = groups
            self.skippedInCloud = skipped
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
