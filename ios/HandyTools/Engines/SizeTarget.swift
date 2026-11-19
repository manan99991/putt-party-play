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

    /// "Where is it going?" — the common places a file has to fit, with their usual limit, so nobody has to
    /// know the number. Plain names; the limit is shown next to each.
    static let destinations: [(name: String, bytes: Int, icon: String)] = [
        ("Email (Gmail, iCloud, Yahoo)", 25_000_000, "envelope"),
        ("Outlook email", 20_000_000, "envelope.badge"),
        ("WhatsApp video", 16_000_000, "message"),
        ("Discord", 10_000_000, "bubble.left.and.bubble.right"),
        ("Job application", 5_000_000, "briefcase"),
        ("Most website forms", 2_000_000, "globe"),
        ("US visa photo (DS-160)", 240_000, "person.crop.square"),
        ("Small photo upload", 100_000, "photo"),
        ("Signature upload", 50_000, "signature"),
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

    static func imageSync(_ img: UIImage, targetBytes: Int) -> Data? { imageFit(img, targetBytes: targetBytes)?.data }

    /// What a fitted photo came out as: the file, its size in pixels and the JPEG quality used (0…1).
    struct ImageFit { let data: Data; let width: Int; let height: Int; let quality: CGFloat }

    /// Quality first. Keeps the full resolution and the best quality that fits; only when that would need a
    /// visibly blocky JPEG (below 70%) does it step the size down — gently, and only as far as it must. Every
    /// result is checked against the limit in real bytes, with a small margin so a site's own counting never tips it over.
    static func imageFit(_ img: UIImage, targetBytes: Int) -> ImageFit? {
        let limit = Int(Double(targetBytes) * 0.985)
        let upright = img.normalizedUp()
        let original = max(upright.size.width * upright.scale, upright.size.height * upright.scale)
        func encode(_ i: UIImage, _ q: CGFloat) -> Data? { autoreleasepool { i.jpegData(compressionQuality: q) } }
        func fit(_ i: UIImage, floor: CGFloat) -> ImageFit? {
            // Highest quality between `floor` and 92% that fits.
            guard let top = encode(i, 0.92) else { return nil }
            let px = (Int(i.size.width * i.scale), Int(i.size.height * i.scale))
            if top.count <= limit { return ImageFit(data: top, width: px.0, height: px.1, quality: 0.92) }
            guard let low = encode(i, floor), low.count <= limit else { return nil }
            var lo = floor, hi: CGFloat = 0.92, best = ImageFit(data: low, width: px.0, height: px.1, quality: floor)
            for _ in 0..<6 {
                let q = (lo + hi) / 2
                guard let d = encode(i, q) else { break }
                if d.count <= limit { best = ImageFit(data: d, width: px.0, height: px.1, quality: q); lo = q } else { hi = q }
            }
            return best
        }
        // 1. Full size, good quality.
        if let r = fit(upright, floor: 0.7) { return r }
        // 2. Jump close to the size the budget can hold at good quality (from one measurement), then step down gently.
        let probe = encode(upright, 0.8)?.count ?? 1
        var side = min(original, original * CGFloat((Double(limit) / Double(max(probe, 1))).squareRoot()) * 1.02)
        for _ in 0..<8 {
            let cur = upright.resized(maxDimension: max(320, side))
            if let r = fit(cur, floor: 0.7) { return r }
            if side <= 320 { break }
            side *= 0.88
        }
        // 3. A very small limit: accept a lower quality rather than fail.
        var cur = upright.resized(maxDimension: max(240, min(side, 1200)))
        for _ in 0..<8 {
            if let r = fit(cur, floor: 0.3) { return r }
            let longest = max(cur.size.width, cur.size.height) * cur.scale
            if longest < 160 { break }
            cur = cur.resized(maxDimension: longest * 0.75)
        }
        return nil
    }

    // MARK: PDF — re-render pages at a descending (scale, quality) ladder until it fits. Output is flattened.

    static func pdf(_ data: Data, targetBytes: Int) async -> Data? {
        await Task.detached(priority: .userInitiated) { pdfSync(data, targetBytes: targetBytes) }.value
    }

    static func pdfSync(_ data: Data, targetBytes: Int) -> Data? {
        if data.count <= targetBytes { return data }
        guard let doc = PDFDocument(data: data), doc.pageCount > 0 else { return nil }
        // Pixels per point, JPEG quality. Ends around 36 dpi / q 0.3 — still readable text on screen.
        let ladder: [(CGFloat, CGFloat)] = [(2.0, 0.8), (1.6, 0.7), (1.3, 0.6), (1.0, 0.55), (0.8, 0.5), (0.65, 0.45), (0.5, 0.4), (0.4, 0.35), (0.33, 0.3)]
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
                // Draw the page as a JPEG-backed CGImage: the PDF then stores the compressed JPEG as-is.
                // (Drawing a decoded UIImage made the PDF keep raw pixels — the "shrunk" file barely shrank.)
                if let jd = raster.jpegData(compressionQuality: quality), let provider = CGDataProvider(data: jd as CFData),
                   let cg = CGImage(jpegDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
                    let c = ctx.cgContext
                    c.saveGState()
                    c.translateBy(x: bounds.minX, y: bounds.maxY); c.scaleBy(x: 1, y: -1)
                    c.draw(cg, in: CGRect(origin: .zero, size: bounds.size))
                    c.restoreGState()
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
