import Foundation
import Photos
import UIKit

/// The parts of Long Screenshot around the stitching: finding the screenshots you just took while
/// scrolling, and turning a tall result into PDF pages. The deciding is pure and unit-tested.
enum StitchExtras {
    /// How many of the newest screenshots belong to one scrolling run: each taken within `maxGap`
    /// seconds of the next. `newestFirst` are their dates. Capped at `limit`; 0 when there are none.
    static func burstCount(_ newestFirst: [Date], maxGap: TimeInterval = 90, limit: Int = 12) -> Int {
        guard !newestFirst.isEmpty else { return 0 }
        var n = 1
        while n < min(limit, newestFirst.count), newestFirst[n - 1].timeIntervalSince(newestFirst[n]) <= maxGap { n += 1 }
        return n
    }

    /// The screenshots of your latest scrolling run, oldest first (top of the page first).
    static func latestRun(limit: Int = 12) async -> [UIImage] {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "(mediaSubtype & %d) != 0", Int(PHAssetMediaSubtype.photoScreenshot.rawValue))
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        o.fetchLimit = limit
        let r = PHAsset.fetchAssets(with: .image, options: o)
        var assets: [PHAsset] = []
        r.enumerateObjects { a, _, _ in assets.append(a) }
        let n = burstCount(assets.map { $0.creationDate ?? .distantPast }, limit: limit)
        var out: [UIImage] = []
        for a in assets.prefix(n).reversed() { if let img = await full(a) { out.append(img) } }
        return out
    }

    private static func full(_ a: PHAsset) async -> UIImage? {
        await withCheckedContinuation { c in
            let o = PHImageRequestOptions(); o.deliveryMode = .highQualityFormat; o.isNetworkAccessAllowed = true; o.isSynchronous = false
            var done = false
            PHImageManager.default().requestImage(for: a, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: o) { img, info in
                if done { return }
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                done = true; c.resume(returning: img)
            }
        }
    }

    /// Page cuts down a tall image: each page as tall as `pageHeight`, the last one shorter.
    static func pageSlices(height: CGFloat, pageHeight: CGFloat) -> [CGRect] {
        guard height > 0, pageHeight > 0 else { return [] }
        var out: [CGRect] = [], y: CGFloat = 0
        while y < height - 0.5 { let h = min(pageHeight, height - y); out.append(CGRect(x: 0, y: y, width: 1, height: h)); y += h }
        return out
    }

    /// The tall image as a PDF, cut into pages shaped like A4 so it prints and reads like a document.
    static func pdf(_ img: UIImage) -> Data? {
        guard let cg = img.cgImage else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let pageH = (w * 1.414).rounded()
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let scale = page.width / w
        return UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            for s in pageSlices(height: h, pageHeight: pageH) {
                guard let piece = cg.cropping(to: CGRect(x: 0, y: s.minY, width: w, height: s.height)) else { continue }
                ctx.beginPage()
                UIImage(cgImage: piece).draw(in: CGRect(x: 0, y: 0, width: page.width, height: s.height * scale))
            }
        }
    }

    /// Faces and personal numbers (phone, email, card, account, plates) hidden across a long screenshot. Read in
    /// phone-screen-sized slices so small chat text is still found; returns the covered image and how many.
    static func hidePersonal(_ img: UIImage) -> (image: UIImage, hidden: Int)? {
        guard let cg = img.normalizedUp().cgImage else { return nil }
        let W = CGFloat(cg.width), H = CGFloat(cg.height)
        let sliceH = max(200, W * 2.0)
        var rects: [CGRect] = []
        var y: CGFloat = 0
        while y < H {
            let h = min(sliceH, H - y)
            if let piece = cg.cropping(to: CGRect(x: 0, y: y, width: W, height: h)) {
                let hits = Scrubber.detect(UIImage(cgImage: piece))
                for r in hits.faces + hits.text.filter(\.personal).map(\.rect) {
                    rects.append(CGRect(x: r.minX, y: (y + r.minY * h) / H, width: r.width, height: r.height * h / H))
                }
            }
            y += sliceH * 0.9            // a little overlap so nothing on a slice edge is missed
        }
        guard let data = Scrubber.render(UIImage(cgImage: cg), rects: rects, style: .block), let out = UIImage(data: data) else { return nil }
        return (out, Scrubber.mergeFaces(rects).count)
    }
}
