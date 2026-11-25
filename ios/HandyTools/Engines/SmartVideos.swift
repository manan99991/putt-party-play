import Foundation
import UIKit
import AVFoundation
import Photos

/// Smart autorun: heavy videos made smaller without losing quality (25 Nov). Today's big videos are re-saved in HEVC
/// at their own size and frame rate (HDR kept), then compared with the original frame by frame: every checked frame
/// must clear the "looks the same" bar, or that video is left alone. Only a saving of real size is offered. The smaller
/// copy goes into Photos with the original's date and place; the original is only removed when the person says so,
/// through iPhone's own delete prompt (and it waits in Recently Deleted for 30 days).
enum SmartVideos {
    struct Result: Codable, Equatable, Identifiable {
        var id: String               // the original's photo-library id
        var file: String             // the smaller copy, in the autorun's folder
        var before: Int
        var after: Int
        var seconds: Double
        var worstDB: Double          // the lowest frame match found, in dB
        var created: Date?
        var saved = false            // the smaller copy is in Photos
        var savedID: String?

        var saving: Int { max(0, before - after) }
    }

    static var folder: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SmartRuns/Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Today's videos, as the picking rules need them.
    static func found(in window: DateInterval) -> [(SmartRuns.Found, PHAsset)] {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", window.start as NSDate, window.end as NSDate)
        let r = PHAsset.fetchAssets(with: .video, options: o)
        var out: [(SmartRuns.Found, PHAsset)] = []
        r.enumerateObjects { a, _, _ in
            let res = PHAssetResource.assetResources(for: a).first { $0.type == .video || $0.type == .fullSizeVideo }
            let bytes = (res?.value(forKey: "fileSize") as? NSNumber)?.intValue ?? 0
            out.append((SmartRuns.Found(id: a.localIdentifier, created: a.creationDate ?? window.end, isVideo: true, bytes: bytes,
                                        seconds: a.duration, width: a.pixelWidth, height: a.pixelHeight), a))
        }
        return out
    }

    static func avAsset(_ a: PHAsset) async -> AVAsset? {
        let opt = PHVideoRequestOptions(); opt.isNetworkAccessAllowed = true; opt.deliveryMode = .highQualityFormat; opt.version = .current
        return await withCheckedContinuation { c in PHImageManager.default().requestAVAsset(forVideo: a, options: opt) { av, _, _ in c.resume(returning: av) } }
    }

    /// Re-save one video smaller and prove it looks the same. nil when it can't be made smaller without a visible change.
    static func shrink(_ found: SmartRuns.Found, _ asset: PHAsset, progress: ((Double) -> Void)? = nil) async -> Result? {
        guard let src = await avAsset(asset) else { return nil }
        let before = found.bytes > 0 ? found.bytes : ((src as? AVURLAsset).flatMap { SizeTarget.fileSize($0.url) } ?? 0)
        guard before > 0 else { return nil }
        // Apple's own HEVC export at the highest quality: keeps the size, frame rate and HDR, uses the hardware encoder.
        guard let s = AVAssetExportSession(asset: src, presetName: AVAssetExportPresetHEVCHighestQuality), s.supportedFileTypes.contains(.mov) else { return nil }
        let out = folder.appendingPathComponent("\(UUID().uuidString).mov")
        s.outputURL = out; s.outputFileType = .mov; s.shouldOptimizeForNetworkUse = true
        let ticker = Task { while !Task.isCancelled { progress?(Double(s.progress)); try? await Task.sleep(nanoseconds: 400_000_000) } }
        let ok = await VideoEngine.run(s, seconds: found.seconds)
        ticker.cancel()
        guard ok, let after = SizeTarget.fileSize(out) else { try? FileManager.default.removeItem(at: out); return nil }
        guard SmartRuns.worthIt(original: before, smaller: after) else { try? FileManager.default.removeItem(at: out); return nil }
        let worst = await worstMatch(src, AVURLAsset(url: out), seconds: found.seconds)
        guard worst >= SmartRuns.samePictureDB else { try? FileManager.default.removeItem(at: out); return nil }
        return Result(id: asset.localIdentifier, file: out.lastPathComponent, before: before, after: after, seconds: found.seconds,
                      worstDB: worst, created: asset.creationDate)
    }

    /// The lowest frame-by-frame match between two videos, sampled at seven points from start to end, in dB.
    static func worstMatch(_ a: AVAsset, _ b: AVAsset, seconds: Double) async -> Double {
        func generator(_ x: AVAsset) -> AVAssetImageGenerator {
            let g = AVAssetImageGenerator(asset: x)
            g.appliesPreferredTrackTransform = true
            g.requestedTimeToleranceBefore = .zero; g.requestedTimeToleranceAfter = .zero
            g.maximumSize = CGSize(width: 640, height: 640)
            return g
        }
        let ga = generator(a), gb = generator(b)
        var worst = 99.0
        for f in [0.05, 0.2, 0.35, 0.5, 0.65, 0.8, 0.95] {
            let t = CMTime(seconds: max(0, seconds * f), preferredTimescale: 600)
            guard let ia = try? await ga.image(at: t).image, let ib = try? await gb.image(at: t).image else { return 0 }   // a frame that won't open fails the check
            let pa = Stitcher.grayscale(UIImage(cgImage: ia), width: 320), pb = Stitcher.grayscale(UIImage(cgImage: ib), width: 320)
            let n = min(pa.px.count, pb.px.count)
            guard n > 0 else { return 0 }
            worst = min(worst, SmartRuns.psnr(Array(pa.px.prefix(n)), Array(pb.px.prefix(n))))
        }
        return worst
    }

    /// Puts the smaller copy into Photos with the original's date, place and favourite mark. Returns the new id.
    static func saveToPhotos(_ r: Result) async -> String? {
        let url = folder.appendingPathComponent(r.file)
        let original = PHAsset.fetchAssets(withLocalIdentifiers: [r.id], options: nil).firstObject
        var newID: String?
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .video, fileURL: url, options: nil)
                req.creationDate = original?.creationDate
                req.location = original?.location
                req.isFavorite = original?.isFavorite ?? false
                newID = req.placeholderForCreatedAsset?.localIdentifier
            }
        } catch { return nil }
        return newID
    }

    /// iPhone's own prompt to delete the originals; true if the person allowed it.
    static func deleteOriginals(_ ids: [String]) async -> Bool {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        guard assets.count > 0 else { return false }
        do { try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(assets) }; return true } catch { return false }
    }

    static func bytes(_ n: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .file) }
}
