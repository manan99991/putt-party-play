import UIKit
import CoreGraphics

/// Stitches a sequence of overlapping screenshots into one tall image. Works for content from ANY
/// app because the user takes the screenshots normally; we only align them — no OS lets a third-
/// party app auto-scroll other apps, and that's by design. The trick is (1) detect the fixed chrome
/// (status bar/header at top, nav bar/keyboard at bottom) so it appears once, and (2) find the
/// vertical overlap between each consecutive pair by sliding a grayscale strip and minimising error.
enum Stitcher {

    struct Gray { let rows: Int; let width: Int; let px: [UInt8] }

    /// Result image (scale 1, pixel dimensions) or nil if nothing usable.
    static func stitch(_ images: [UIImage]) -> UIImage? {
        let srcs = images.map { $0.normalizedUp() }
        guard !srcs.isEmpty else { return nil }
        if srcs.count == 1 { return srcs[0] }

        // Normalise all to the narrowest pixel width so columns line up.
        let targetW = srcs.map { $0.size.width * $0.scale }.min() ?? 0
        guard targetW > 10 else { return nil }
        var norm = srcs.map { normalize($0, pixelWidth: targetW) }
        var small = norm.map { grayscale($0, width: 160) }
        guard small.allSatisfy({ $0.rows > 20 }) else { return nil }

        // The screenshots may have been picked in any order — infer the real top-to-bottom sequence
        // (each image's bottom content flows into the next image's top) before stitching.
        let order = inferOrder(small)
        norm = order.map { norm[$0] }
        small = order.map { small[$0] }

        // Fixed chrome from the first pair (clamped so a giant identical region can't eat the content).
        var header = 0, footer = 0
        if small.count >= 2 {
            header = min(commonTop(small[0], small[1]), small[0].rows / 4)
            footer = min(commonBottom(small[0], small[1]), small[0].rows / 4)
        }

        // Per-pair overlap in small-image rows.
        var skipTop: [Int] = []
        for i in 1..<small.count {
            let L = bestOverlap(small[i - 1], small[i], header: header, footer: footer)
            skipTop.append(header + L)
        }

        // Compose at full resolution.
        var pieces: [(UIImage, CGRect)] = []
        var totalH: CGFloat = 0
        for (i, img) in norm.enumerated() {
            let fullH = img.size.height
            let rowScale = fullH / CGFloat(small[i].rows)
            let top: CGFloat = i == 0 ? 0 : CGFloat(skipTop[i - 1]) * rowScale
            let bottom: CGFloat = i == norm.count - 1 ? fullH : fullH - CGFloat(footer) * rowScale
            let h = max(0, bottom - top)
            guard h > 0 else { continue }
            pieces.append((img, CGRect(x: 0, y: top, width: img.size.width, height: h)))
            totalH += h
        }
        guard totalH > 0 else { return nil }

        return compose(pieces: pieces, width: targetW, height: totalH)
    }

    // MARK: compose

    /// Paint the computed pieces into one tall image. A long stitch can be 10–30k px tall, and
    /// UIGraphicsImageRenderer (GPU-backed) silently returns a BLANK image past ~10k px on many
    /// devices — the "one long white image" bug. We composite into a CPU CGBitmapContext instead,
    /// which is limited only by memory (up to 32,767 px/side), on an opaque white background so any
    /// gap is white rather than transparent. Falls back to a bounded renderer only for extreme sizes.
    static func compose(pieces: [(UIImage, CGRect)], width: CGFloat, height: CGFloat) -> UIImage? {
        guard width > 0, height > 0, !pieces.isEmpty else { return nil }
        let maxSide: CGFloat = 32_000
        guard width <= maxSide, height <= maxSide else { return composeBounded(pieces: pieces, width: width, height: height) }
        let w = Int(width.rounded()), h = Int(height.rounded())
        guard w > 0, h > 0,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return composeBounded(pieces: pieces, width: width, height: height) }
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        // CGContext is bottom-left; flip once so screenshots stack top-to-bottom and draw upright.
        ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
        var y: CGFloat = 0
        for (img, src) in pieces {
            if let cg = img.cgImage?.cropping(to: src) {
                ctx.draw(cg, in: CGRect(x: 0, y: y, width: width, height: src.height))
            }
            y += src.height
        }
        guard let cg = ctx.makeImage() else { return composeBounded(pieces: pieces, width: width, height: height) }
        return UIImage(cgImage: cg)
    }

    /// Last-resort path for a composite taller than a bitmap context allows: scale the whole thing down
    /// to a safe budget and render it. Still legible, and never blank.
    private static func composeBounded(pieces: [(UIImage, CGRect)], width: CGFloat, height: CGFloat) -> UIImage? {
        guard width > 0, height > 0 else { return nil }
        let budget: CGFloat = 24_000_000
        var scale = min(1, (budget / (width * height)).squareRoot())
        let cap: CGFloat = 16_000
        if height * scale > cap { scale = cap / height }
        if width * scale > cap { scale = min(scale, cap / width) }
        let outW = max(1, (width * scale).rounded()), outH = max(1, (height * scale).rounded())
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: outW, height: outH), format: fmt).image { rctx in
            UIColor.white.setFill(); rctx.fill(CGRect(x: 0, y: 0, width: outW, height: outH))
            var y: CGFloat = 0
            for (img, src) in pieces {
                let dh = src.height * scale
                if let cg = img.cgImage?.cropping(to: src) {
                    UIImage(cgImage: cg).draw(in: CGRect(x: 0, y: y, width: outW, height: dh))
                }
                y += dh
            }
        }
    }

    // MARK: helpers

    /// Re-render to scale 1 at the given pixel width, preserving aspect.
    static func normalize(_ img: UIImage, pixelWidth w: CGFloat) -> UIImage {
        let pw = img.size.width * img.scale, ph = img.size.height * img.scale
        let h = (ph * (w / pw)).rounded()
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { _ in
            img.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        }
    }

    /// Downsample to `width` px grayscale for fast comparison.
    static func grayscale(_ img: UIImage, width: Int) -> Gray {
        guard let cg = img.cgImage else { return Gray(rows: 0, width: 0, px: []) }
        let rows = max(1, Int((CGFloat(cg.height) * CGFloat(width) / CGFloat(cg.width)).rounded()))
        var buf = [UInt8](repeating: 0, count: rows * width)
        buf.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: width, height: rows, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: rows))
        }
        return Gray(rows: rows, width: width, px: buf)
    }

    @inline(__always) static func rowDiff(_ a: Gray, _ ra: Int, _ b: Gray, _ rb: Int) -> Int {
        let w = min(a.width, b.width)
        var s = 0
        let oa = ra * a.width, ob = rb * b.width
        for x in 0..<w { s += abs(Int(a.px[oa + x]) - Int(b.px[ob + x])) }
        return s / max(1, w)
    }

    /// Rows from the top that are (nearly) identical in both — the status bar / header.
    static func commonTop(_ a: Gray, _ b: Gray) -> Int {
        var n = 0
        while n < min(a.rows, b.rows), rowDiff(a, n, b, n) < 8 { n += 1 }
        return n
    }

    /// Rows from the bottom that are (nearly) identical — the nav bar / keyboard.
    static func commonBottom(_ a: Gray, _ b: Gray) -> Int {
        var n = 0
        while n < min(a.rows, b.rows), rowDiff(a, a.rows - 1 - n, b, b.rows - 1 - n) < 8 { n += 1 }
        return n
    }

    /// Best vertical overlap of A's bottom content against B's top content: the overlap length in
    /// rows and the average per-row error of that fit (err == Int.max when nothing is convincing).
    static func overlapFit(_ a: Gray, _ b: Gray, header: Int, footer: Int) -> (len: Int, err: Int) {
        let aEnd = a.rows - footer           // exclusive end of A's content
        let bStart = header                  // start of B's content
        let maxL = min(aEnd - header, b.rows - footer - bStart) - 2
        guard maxL >= 12 else { return (0, Int.max) }
        var bestL = 0, bestErr = Int.max
        var L = maxL
        while L >= 12 {
            var err = 0
            let step = max(1, L / 48)       // sample rows for speed
            var count = 0
            var r = 0
            while r < L {
                err += rowDiff(a, aEnd - L + r, b, bStart + r); count += 1
                if count > 6, err / count > bestErr { break }   // early out
                r += step
            }
            let avg = err / max(1, count)
            if avg < bestErr { bestErr = avg; bestL = L }
            L -= 1
        }
        return (bestL, bestErr)
    }

    /// Overlap length (in rows) between A's bottom content and B's top content; 0 if none convincing.
    static func bestOverlap(_ a: Gray, _ b: Gray, header: Int, footer: Int) -> Int {
        let f = overlapFit(a, b, header: header, footer: footer)
        return f.err < 10 ? f.len : 0
    }

    /// Infer the top-to-bottom order of screenshots supplied in ANY order. For a scroll sequence each
    /// image's bottom content overlaps the next image's top, so we score every ordered pair "i sits
    /// directly above j" and greedily chain from the image that nothing convincingly sits above.
    static func inferOrder(_ small: [Gray]) -> [Int] {
        let n = small.count
        if n <= 1 { return Array(0..<n) }
        let threshold = 10
        // err[i][j] = how well i's bottom flows into j's top (lower is better; chrome left in, it's
        // common to every shot so it only adds a constant and never flips the best pairing).
        var err = Array(repeating: Array(repeating: Int.max, count: n), count: n)
        for i in 0..<n { for j in 0..<n where i != j {
            err[i][j] = overlapFit(small[i], small[j], header: 0, footer: 0).err
        } }
        // Start at the image least likely to have anything above it (worst best-incoming score).
        var start = 0, worstIncoming = -1
        for j in 0..<n {
            var bestIn = Int.max
            for i in 0..<n where i != j { bestIn = min(bestIn, err[i][j]) }
            if bestIn > worstIncoming { worstIncoming = bestIn; start = j }
        }
        var used = [Bool](repeating: false, count: n)
        var order = [start]; used[start] = true
        var cur = start
        while true {
            var next = -1, bestE = threshold
            for j in 0..<n where !used[j] { if err[cur][j] < bestE { bestE = err[cur][j]; next = j } }
            if next == -1 { break }
            order.append(next); used[next] = true; cur = next
        }
        // Anything with no convincing overlap (unrelated shots) keeps its original relative order.
        for j in 0..<n where !used[j] { order.append(j) }
        return order
    }
}
