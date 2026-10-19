import Photos
import Vision
import UIKit

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
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return collect(PHAsset.fetchAssets(with: .video, options: o))
            .filter { $0.bytes >= minBytes }
            .sorted { $0.bytes > $1.bytes }
    }

    /// Group near-duplicate photos using Vision feature prints over the most recent `scanLimit` photos
    /// (bounded so a huge library can't stall). Each returned group has 2+ look-alikes.
    static func duplicates(scanLimit: Int = 400, progress: @escaping (Double) -> Void) async -> [[Item]] {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
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
            var members = [i]; used[i] = true
            for j in (i + 1)..<prints.count where !used[j] {
                var dist = Float.greatestFiniteMagnitude
                try? prints[i].1.computeDistance(&dist, to: prints[j].1)
                if dist < 0.30 { members.append(j); used[j] = true }   // near-identical
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
