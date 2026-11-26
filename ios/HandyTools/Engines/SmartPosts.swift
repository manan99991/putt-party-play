import Foundation
import UIKit
import AVFoundation
import Photos

/// Smart autorun: today's best videos, ready to post (25 Nov). From the clips taken in the window it picks the
/// sharpest few (4 s to 3 min), gives each the person's chosen look, makes it the tall 9:16 shape Reels, TikTok and
/// Shorts want — nothing cut off: the whole picture in front of a soft blurred fill — and trims anything longer than
/// the app allows to its liveliest part. Each one waits to be watched; Save puts it in Photos for posting, with Open
/// Instagram / TikTok / YouTube one tap away. Nothing is posted by Tenzy.
enum SmartPosts {
    struct Result: Codable, Equatable, Identifiable {
        var id: String               // the original clip's photo-library id
        var file: String
        var look: String
        var seconds: Double
        var created: Date?
        var saved = false
        var savedID: String?
        /// The finished clip's size in pixels (width, height).
        var size: [Int]?
    }

    static var folder: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SmartRuns/Posts", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Looks offered for the autorun (VideoFX's colour looks, "none" keeps the clip's own colour).
    static let looks = ["vivid", "golden", "cinema", "dream", "moon", "noir", "none"]

    /// How sharp a clip is at its middle: the spread of edges (variance of the Laplacian) on a small grey frame.
    /// Blurry, shaky or dark clips score low.
    static func sharpness(_ g: Stitcher.Gray) -> Double {
        let w = g.width, h = g.rows
        guard w > 2, h > 2 else { return 0 }
        var sum = 0.0, sq = 0.0, n = 0.0
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let c = Double(g.px[y * w + x]) * 4
                let l = c - Double(g.px[y * w + x - 1]) - Double(g.px[y * w + x + 1]) - Double(g.px[(y - 1) * w + x]) - Double(g.px[(y + 1) * w + x])
                sum += l; sq += l * l; n += 1
            }
        }
        let mean = sum / n
        return sq / n - mean * mean
    }

    /// The best clips of the window: the newest eight real clips, ranked by how sharp they are, best three kept.
    static func best(in window: DateInterval, limit: Int = 3) async -> [(SmartRuns.Found, PHAsset)] {
        let all = SmartVideos.found(in: window)
        let picks = SmartRuns.postPicks(all.map(\.0), limit: 8)
        var scored: [((SmartRuns.Found, PHAsset), Double)] = []
        for f in picks {
            guard let pair = all.first(where: { $0.0.id == f.id }), let av = await SmartVideos.avAsset(pair.1) else { continue }
            let g = AVAssetImageGenerator(asset: av)
            g.appliesPreferredTrackTransform = true
            g.maximumSize = CGSize(width: 480, height: 480)
            guard let cg = try? await g.image(at: CMTime(seconds: f.seconds / 2, preferredTimescale: 600)).image else { continue }
            scored.append((pair, sharpness(Stitcher.grayscale(UIImage(cgImage: cg), width: 240))))
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    /// One clip made ready to post. nil when the phone couldn't make it.
    static func make(_ f: SmartRuns.Found, _ asset: PHAsset, look: String, platform: String = "reels", progress: ((String) -> Void)? = nil) async -> Result? {
        guard let av = await SmartVideos.avAsset(asset) as? AVURLAsset else { return nil }
        var cur = av.url
        if look != "none" {
            progress?(L("Giving it your look…"))
            guard let styled = await VideoFX.export(cur, recipe: VideoFX.Recipe(look: look, amount: 0.55), caption: nil) else { return nil }
            cur = styled
        }
        guard let p = SocialPost.platform(platform), let ready = await SocialPost.prepare(cur, for: p, progress: progress).first else { return nil }
        let dest = folder.appendingPathComponent("\(UUID().uuidString).\(ready.pathExtension.isEmpty ? "mp4" : ready.pathExtension)")
        do { try FileManager.default.moveItem(at: ready, to: dest) } catch { return nil }
        let facts = await VideoFacts.read(dest)
        return Result(id: asset.localIdentifier, file: dest.lastPathComponent, look: look, seconds: facts?.seconds ?? f.seconds, created: asset.creationDate,
                      size: facts.map { [Int($0.size.width), Int($0.size.height)] })
    }
}
