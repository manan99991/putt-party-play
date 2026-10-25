import UIKit
import ImageIO
import PDFKit
import AVFoundation
import UniformTypeIdentifiers

/// Hits an exact byte target. This exists because no OS lets you say "make this under 2 MB" —
/// you get all-or-nothing share-sheet compression, and an entire web of "compress-to-2MB" tools
/// grew up around that gap. One engine, three media types, shared by Fit It, Studio, Video, Scan
/// and Share-Ready. Everything runs on the phone.
enum SizeTarget {

    static let presets: [(label: String, bytes: Int)] = [
        ("10 MB", 10_000_000), ("5 MB", 5_000_000), ("2 MB", 2_000_000), ("1 MB", 1_000_000),
        ("500 KB", 500_000), ("200 KB", 200_000), ("50 KB", 50_000),
    ]

    static func format(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    /// Wraps a non-Sendable value so it can cross into a detached task. The value is only ever read
    /// on one task at a time, so this is safe.
    private struct Box<T>: @unchecked Sendable { let v: T }

    // MARK: Image — ALWAYS off the main thread (heavy re-encoding would otherwise freeze the UI).
    // Pre-shrink a large photo toward a size the target can plausibly hold, then binary-search JPEG
    // quality, stepping the resolution down only if quality alone can't get there.

    static func image(_ img: UIImage, targetBytes: Int) async -> Data? {
        let box = Box(v: img)
        return await Task.detached(priority: .userInitiated) { imageSync(box.v, targetBytes: targetBytes) }.value
    }

    static func imageSync(_ img: UIImage, targetBytes: Int) -> Data? {
        let upright = img.normalizedUp()
        let original = max(upright.size.width, upright.size.height)
        // Don't encode a 12-megapixel photo at full res when the target is small — start near the
        // largest resolution the byte budget could hold, so the first encode is already cheap.
        let cap = startDimension(for: targetBytes, original: original)
        var cur = cap < original ? upright.resized(maxDimension: cap) : upright
        for _ in 0..<9 {
            if let d = bestJPEG(cur, under: targetBytes) { return d }
            let longest = max(cur.size.width, cur.size.height)
            if longest < 200 { break }
            cur = cur.resized(maxDimension: longest * 0.75)
        }
        return nil
    }

    /// Upper bound on the longest side for a given JPEG byte budget (~0.12 bytes/px with headroom),
    /// clamped to the original. Keeps huge photos from being encoded at full resolution on the way down.
    private static func startDimension(for targetBytes: Int, original: CGFloat) -> CGFloat {
        let pixelBudget = Double(targetBytes) / 0.12
        let side = min(Double(original), max(360.0, pixelBudget.squareRoot() * 1.3))
        return CGFloat(side)
    }

    private static func bestJPEG(_ img: UIImage, under limit: Int) -> Data? {
        var lo: CGFloat = 0.02, hi: CGFloat = 0.95
        var best: Data?
        for _ in 0..<8 {
            let q = (lo + hi) / 2
            let d: Data? = autoreleasepool { img.jpegData(compressionQuality: q) }  // drain each encode
            guard let d else { break }
            if d.count <= limit { best = d; lo = q } else { hi = q }
        }
        return best
    }

    // MARK: PDF — re-render pages at a descending (scale, quality) ladder until it fits. Output is flattened.

    static func pdf(_ data: Data, targetBytes: Int) async -> Data? {
        await Task.detached(priority: .userInitiated) { pdfSync(data, targetBytes: targetBytes) }.value
    }

    static func pdfSync(_ data: Data, targetBytes: Int) -> Data? {
        if data.count <= targetBytes { return data }
        guard let doc = PDFDocument(data: data), doc.pageCount > 0 else { return nil }
        let ladder: [(CGFloat, CGFloat)] = [(2.0, 0.8), (1.6, 0.7), (1.3, 0.6), (1.0, 0.55), (0.8, 0.5), (0.65, 0.45), (0.5, 0.4), (0.4, 0.35)]
        for (scale, q) in ladder {
            if let out = rerender(doc, scale: scale, quality: q), out.count <= targetBytes { return out }
        }
        return nil
    }

    private static func rerender(_ doc: PDFDocument, scale: CGFloat, quality: CGFloat) -> Data? {
        guard let first = doc.page(at: 0) else { return nil }
        let renderer = UIGraphicsPDFRenderer(bounds: first.bounds(for: .mediaBox))
        return renderer.pdfData { ctx in
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                ctx.beginPage(withBounds: bounds, pageInfo: [:])
                let px = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
                let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
                let raster = UIGraphicsImageRenderer(size: px, format: fmt).image { c in
                    UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: px))
                    c.cgContext.saveGState()
                    c.cgContext.translateBy(x: 0, y: px.height)
                    c.cgContext.scaleBy(x: scale, y: -scale)
                    page.draw(with: .mediaBox, to: c.cgContext)
                    c.cgContext.restoreGState()
                }
                if let jd = raster.jpegData(compressionQuality: quality), let j = UIImage(data: jd) {
                    j.draw(in: bounds)
                } else {
                    raster.draw(in: bounds)
                }
            }
        }
    }

    // MARK: Video — derive a bitrate from the target and duration, transcode with AVAssetWriter, retry tighter if needed.

    /// Best-effort shrink. Returns the SMALLEST file it can make and whether it met the target —
    /// nil only when the source can't be transcoded at all. A caller can hand the result back either
    /// way: a 184 MB clip that only reaches 11 MB is still a real reduction, not a dead end. This is
    /// what the shrink tools should use so they never promise, fail, and block.
    static func videoBestEffort(url: URL, targetBytes: Int, progress: ((Double) -> Void)? = nil) async -> (url: URL, fits: Bool)? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration).seconds, duration > 0 else { return nil }
        if let src = fileSize(url), src <= targetBytes { return (url, true) }
        // Longest source side, so we can shrink RELATIVE to it — an absolute cap bigger than the
        // source would never downscale, and very noisy content can't hit a small target at full res.
        var longest: CGFloat = 1920
        if let v = try? await asset.loadTracks(withMediaType: .video).first,
           let n = try? await v.load(.naturalSize) {
            longest = max(n.width, n.height, 2)
        }
        let audioBps = 96_000
        var videoBps = max(120_000, Int(Double(targetBytes) * 8.0 / duration) - audioBps)
        // Each retry both lowers the bitrate AND shrinks the frame relative to the source, so the
        // output always gets smaller (works for a 320p clip and a 4K clip alike). An absolute
        // bitrate ceiling still caps huge frames. Delegates to the one robust, bounded transcode.
        //
        // The ladder goes down to ~1/8 of the source's longest side on purpose: hard-to-compress
        // footage (noise, grain, confetti, fast motion) makes the H.264 encoder blow past a low
        // requested bitrate, so for those clips RESOLUTION is the only lever that actually shrinks
        // the file. Compressible clips hit the target in the first pass or two and never reach the
        // small steps; a near-incompressible 1080p clip needs them to land under an aggressive target.
        func bitrateCeiling(_ bps: Int) -> CGFloat { bps < 1_200_000 ? 960 : (bps < 3_000_000 ? 1440 : 3840) }
        let shrink: [CGFloat] = [1.0, 0.7, 0.5, 0.35, 0.25, 0.18, 0.13]
        var best: URL?; var bestSize = Int.max
        for s in shrink {
            let cap = max(192, min(bitrateCeiling(videoBps), longest * s))   // never below ~192px
            if let out = await VideoEngine.transcodeH264(asset, maxDimension: cap, videoBps: videoBps, progress: progress) {
                let sz = fileSize(out) ?? Int.max
                if sz <= targetBytes { if let b = best { try? FileManager.default.removeItem(at: b) }; return (out, true) }
                // Keep the smallest attempt as the fallback; a tighter frame next pass may still fit.
                if sz < bestSize { if let b = best { try? FileManager.default.removeItem(at: b) }; best = out; bestSize = sz }
                else { try? FileManager.default.removeItem(at: out) }
            }
            videoBps = Int(Double(videoBps) * 0.8)
        }
        if let best { return (best, false) }   // couldn't hit the target, but hand back the smallest we got
        return nil
    }

    /// Strict: the result only if it lands at or under the target, else nil. Used by Share-Ready and
    /// the size-target test, which need a hard "it fits" guarantee.
    static func video(url: URL, targetBytes: Int, progress: ((Double) -> Void)? = nil) async -> URL? {
        guard let r = await videoBestEffort(url: url, targetBytes: targetBytes, progress: progress) else { return nil }
        if r.fits { return r.url }
        try? FileManager.default.removeItem(at: r.url)
        return nil
    }

    static func fileSize(_ url: URL) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil
    }
}
