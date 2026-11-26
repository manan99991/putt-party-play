import Foundation
import UIKit
import Photos
import Vision

/// Smart autorun: today's photos as one collage (25 Nov). From the day's photos of people it keeps one per moment
/// (the sharpest of a burst), leaves out screenshots, documents and blurry shots, puts little ones first and spreads
/// the picks across the day; the sharpest, fullest photo leads as the big one, the rest follow in the order they were
/// taken. Every photo is cropped around its faces so nobody is cut off, and the day's date sits underneath.
enum SmartCollage {
    struct Result: Codable, Equatable, Identifiable {
        var id: String                // the day, "2026-11-25"
        var file: String
        var count: Int
        var ids: [String]
        var layout: String
        var saved = false
    }

    static var folder: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SmartRuns/Collages", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// The day's photos of people, read for the picking rules (labels, faces, words, how sharp).
    static func found(in window: DateInterval) async -> [(SmartRuns.Found, PHAsset)] {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", window.start as NSDate, window.end as NSDate)
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let r = PHAsset.fetchAssets(with: .image, options: o)
        var assets: [PHAsset] = []
        r.enumerateObjects { a, _, _ in if !a.mediaSubtypes.contains(.photoScreenshot) { assets.append(a) } }
        var cache = PhotoFinder.loadCache()
        var out: [(SmartRuns.Found, PHAsset)] = []
        for a in assets.suffix(400) {
            let seen: PhotoFinder.Seen?
            if let s = cache[a.localIdentifier], s.modified == (a.modificationDate?.timeIntervalSince1970 ?? 0) { seen = s }
            else { seen = await PhotoFinder.read(a); if let seen { cache[a.localIdentifier] = seen } }
            guard let seen, seen.faces > 0 else { continue }
            var sharp = 1.0
            if let small = await PhotoFinder.image(a, side: 480) {
                sharp = min(1, SmartPosts.sharpness(Stitcher.grayscale(small, width: 240)) / 300)
            }
            out.append((SmartRuns.Found(id: a.localIdentifier, created: a.creationDate ?? window.end, isScreenshot: seen.screenshot,
                                        seen: SmartRuns.PhotoSeen(labels: seen.labels, text: seen.text, faces: seen.faces, sharpness: sharp)), a))
        }
        PhotoFinder.saveCache(cache)
        return out
    }

    /// Where a photo's faces are (the middle of all of them, 0…1 from the top-left), to crop around.
    static func faceFocus(_ img: UIImage) -> CGPoint? {
        guard let cg = img.normalizedUp().cgImage else { return nil }
        let req = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
        let faces = req.results ?? []
        guard !faces.isEmpty else { return nil }
        let u = faces.map(\.boundingBox).reduce(faces[0].boundingBox) { $0.union($1) }
        return CGPoint(x: u.midX, y: 1 - u.midY)
    }

    /// The collage for one day. nil when there aren't at least three good photos of people.
    static func make(in window: DateInterval, layout: CollageLayout? = nil, progress: ((Double, String) -> Void)? = nil) async -> Result? {
        progress?(0.05, L("Looking at today's photos…"))
        let all = await found(in: window)
        let picks = SmartRuns.collagePicks(all.map(\.0), limit: 10)
        guard picks.count >= 3 else { return nil }
        // The lead photo: most faces, then sharpest.
        let lead = picks.max { a, b in
            let fa = a.seen?.faces ?? 0, fb = b.seen?.faces ?? 0
            return fa != fb ? fa < fb : (a.seen?.sharpness ?? 0) < (b.seen?.sharpness ?? 0)
        }!
        let order = [lead] + picks.filter { $0.id != lead.id }
        var images: [UIImage] = [], focus: [CGPoint?] = []
        for (i, f) in order.enumerated() {
            progress?(0.3 + 0.6 * Double(i) / Double(order.count), L("Arranging the photos…"))
            guard let a = all.first(where: { $0.0.id == f.id })?.1, let img = await PhotoFinder.image(a, side: 1400) else { continue }
            images.append(img); focus.append(faceFocus(img))
        }
        guard images.count >= 3 else { return nil }
        let chosen = layout ?? (images.count <= 4 ? .grid : .hero)
        let day = window.end
        let footer = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let img = CollageLayout.render(images, layout: chosen, canvas: CGSize(width: 2160, height: 2700), gapRatio: 0.012, cornerRatio: 0.018,
                                       background: UIColor(red: 0.985, green: 0.975, blue: 0.96, alpha: 1), focus: focus, footer: footer)
        guard let data = img.jpegData(compressionQuality: 0.92) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        do { try data.write(to: folder.appendingPathComponent(name), options: .atomic) } catch { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        progress?(1, L("Done"))
        return Result(id: f.string(from: day), file: name, count: images.count, ids: order.map(\.id), layout: chosen.rawValue)
    }

    static func save(_ r: Result) async -> Bool {
        guard let img = UIImage(contentsOfFile: folder.appendingPathComponent(r.file).path) else { return false }
        do { try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: img) }; return true } catch { return false }
    }
}
