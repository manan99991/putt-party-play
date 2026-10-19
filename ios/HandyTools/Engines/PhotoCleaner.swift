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
        static func == (a: Item, b: Item) -> Bool { a.id == b.id }
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

    static func largeVideos(minBytes: Int64 = 20_000_000) -> [Item] {
        let o = PHFetchOptions()
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]   // newest-first; the view re-sorts by size when asked
        return collect(PHAsset.fetchAssets(with: .video, options: o)).filter { $0.bytes >= minBytes }
    }

    /// Group near-duplicate photos using Vision feature prints over the most recent `scanLimit` photos
    /// (bounded so a huge library can't stall). Each returned group has 2+ look-alikes.
    /// Covers photos AND videos. A video is fingerprinted on its poster frame (PhotoKit hands one back
    /// for a video the same as a photo), so two copies of the same clip group together. Photos and
    /// videos are never grouped with each other, and video matches are held to a stricter look-alike
    /// threshold plus a similar-duration check so two unrelated clips that open on a dark frame don't
    /// get lumped in.
    static func duplicates(scanLimit: Int = 500, progress: @escaping (Double) -> Void) async -> [[Item]] {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        o.fetchLimit = scanLimit
        let fetch = PHAsset.fetchAssets(with: o)
        var assets: [PHAsset] = []
        fetch.enumerateObjects { a, _, _ in assets.append(a) }
        guard assets.count > 1 else { progress(1); return [] }

        let mgr = PHImageManager.default()
        let req = PHImageRequestOptions()
        req.isSynchronous = true; req.deliveryMode = .fastFormat; req.resizeMode = .fast; req.isNetworkAccessAllowed = false

        var prints: [(PHAsset, VNFeaturePrintObservation)] = []
        for (i, a) in assets.enumerated() {
            if i % 10 == 0 { progress(Double(i) / Double(assets.count)) }
            var image: UIImage?
            mgr.requestImage(for: a, targetSize: CGSize(width: 160, height: 160), contentMode: .aspectFit, options: req) { im, _ in image = im }
            guard let cg = image?.cgImage else { continue }
            let r = VNGenerateImageFeaturePrintRequest()
            try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([r])
            if let p = r.results?.first as? VNFeaturePrintObservation { prints.append((a, p)) }
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
                    : dist < 0.30
                if nearIdentical { members.append(j); used[j] = true }
            }
            if members.count > 1 { groups.append(members.map { Item(asset: prints[$0].0, bytes: estimatedBytes(of: prints[$0].0)) }) }
        }
        return groups
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
            let groups = await PhotoCleaner.duplicates(progress: { p in Task { @MainActor in self?.progress = p } })
            guard let self, !Task.isCancelled else { return }
            self.duplicates = groups
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
