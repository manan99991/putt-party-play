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
        let norm = srcs.map { normalize($0, pixelWidth: targetW) }
        let small = norm.map { grayscale($0, width: 160) }
        guard small.allSatisfy({ $0.rows > 20 }) else { return nil }

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

        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: targetW, height: totalH), format: fmt).image { _ in
            var y: CGFloat = 0
            for (img, src) in pieces {
                if let cg = img.cgImage?.cropping(to: src) {
                    UIImage(cgImage: cg).draw(in: CGRect(x: 0, y: y, width: src.width, height: src.height))
                }
                y += src.height
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

    /// Overlap length (in rows) between A's bottom content and B's top content; 0 if none convincing.
    static func bestOverlap(_ a: Gray, _ b: Gray, header: Int, footer: Int) -> Int {
        let aEnd = a.rows - footer           // exclusive end of A's content
        let bStart = header                  // start of B's content
        let maxL = min(aEnd - header, b.rows - footer - bStart) - 2
        guard maxL >= 12 else { return 0 }
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
        return bestErr < 10 ? bestL : 0
    }
}
