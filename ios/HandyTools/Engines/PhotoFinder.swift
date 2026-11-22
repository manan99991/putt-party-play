import Photos
import UIKit
import Vision

/// "Show me only the receipts" — when a tool asks for a photo, the photos that look like what it needs come first,
/// so nobody scrolls through hundreds of pictures (Manan, 22 Nov: "if they go into the warranty flow and click on
/// photo, we only show the warranties that are present in their photos… and this is for each and every tool").
///
/// Each photo is read once, on the phone, at a small size: Vision's scene labels, a fast text read, faces and codes.
/// What it found is kept in a small cache keyed by the photo and its edit date, so the second time is instant and a
/// photo is never read twice. Nothing leaves the phone. Scoring is pure so it's unit-tested.
enum PhotoFinder {
    /// What a tool is looking for.
    enum Kind: String, CaseIterable, Codable {
        case receipt, document, card, menu, face, board, screenshot, code, product

        var title: String {
            switch self {
            case .receipt: return "Receipts and warranty cards"
            case .document: return "Documents and letters"
            case .card: return "Business cards"
            case .menu: return "Menus"
            case .face: return "Photos of a face"
            case .board: return "Whiteboards, lists and calendars"
            case .screenshot: return "Screenshots"
            case .code: return "Photos with a QR code or barcode"
            case .product: return "Things you might sell or list"
            }
        }
        var icon: String {
            switch self {
            case .receipt: return "receipt"
            case .document: return "doc.text"
            case .card: return "person.text.rectangle"
            case .menu: return "fork.knife"
            case .face: return "person.crop.square"
            case .board: return "list.bullet.rectangle"
            case .screenshot: return "iphone"
            case .code: return "qrcode"
            case .product: return "shippingbox"
            }
        }
    }

    /// What reading one photo found.
    struct Seen: Codable, Equatable {
        var modified: Double
        var labels: [String]
        var text: String
        var faces: Int
        var codes: Int
        var screenshot: Bool
    }

    // MARK: scoring (pure)

    private static func hits(_ t: String, _ words: [String]) -> Int { words.reduce(0) { $0 + (t.contains($1) ? 1 : 0) } }
    private static func matches(_ t: String, _ pattern: String) -> Int {
        (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))?.numberOfMatches(in: t, range: NSRange(t.startIndex..., in: t)) ?? 0
    }

    /// How strongly a photo looks like `kind` — 0 means "not at all"; anything at or above `threshold` is shown first.
    static func score(_ s: Seen, for kind: Kind) -> Double {
        let t = s.text.lowercased()
        let words = t.split { $0 == " " || $0 == "\n" }.count
        let label = { (names: [String]) in names.contains { n in s.labels.contains { $0.contains(n) } } ? 1.0 : 0.0 }
        let money = Double(min(6, matches(t, #"\d+[.,]\d{2}\b"#)))
        switch kind {
        case .receipt:
            let words = hits(t, ["total", "subtotal", "tax", "receipt", "invoice", "visa", "mastercard", "amex", "debit", "cash",
                                 "change due", "qty", "order #", "order no", "store #", "thank you for", "warranty", "guarantee",
                                 "serial", "s/n", "model no", "purchase date", "proof of purchase", "return policy", "valid until"])
            return Double(words) * 1.2 + money * 0.6 + label(["receipt", "document", "paper"]) * 1.5 - (s.screenshot ? 1 : 0)
        case .document:
            return (words > 60 ? 2.5 : words > 25 ? 1.5 : 0) + label(["document", "paper", "text", "letter"]) * 1.5
                + Double(hits(t, ["dear", "sincerely", "page ", "account", "date:", "re:", "agreement", "form"])) * 0.6 - (s.screenshot ? 1.5 : 0)
        case .card:
            let phone = matches(t, #"\+?\d[\d\s().-]{7,}\d"#) > 0 ? 1.5 : 0
            let email = matches(t, #"[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}"#) > 0 ? 1.5 : 0
            let web = matches(t, #"(www\.|\.com\b|\.io\b|\.co\b)"#) > 0 ? 0.7 : 0
            return phone + email + web + (words > 3 && words < 70 ? 0.8 : -1) + label(["business card", "card"]) * 1.0 - (s.screenshot ? 2 : 0)
        case .menu:
            return Double(hits(t, ["menu", "appetizer", "starters", "entree", "entrée", "mains", "dessert", "drinks", "salad",
                                   "chicken", "beef", "pasta", "pizza", "soup", "rice", "burger", "sandwich", "wine", "beer"])) * 0.8
                + money * 0.4 + label(["menu"]) * 2
        case .face:
            return s.faces == 1 ? 3 : (s.faces > 1 ? 1 : 0) - (s.screenshot ? 2 : 0) - (words > 20 ? 1 : 0)
        case .board:
            return label(["whiteboard", "blackboard", "chalkboard", "handwriting", "calendar", "sticky note", "notebook"]) * 2.5
                + Double(hits(t, ["monday", "tuesday", "wednesday", "thursday", "friday", "to do", "todo", "groceries", "list"])) * 0.6
        case .screenshot:
            return s.screenshot ? 3 : 0
        case .code:
            return s.codes > 0 ? 3 : 0
        case .product:
            return label(["shoe", "bag", "furniture", "chair", "table", "lamp", "toy", "clothing", "jacket", "bottle", "watch",
                          "phone", "laptop", "camera", "bicycle", "book"]) * 2 + (s.faces == 0 ? 0.5 : -1) - (s.screenshot ? 2 : 0) - (words > 30 ? 1 : 0)
        }
    }

    static let threshold = 2.4

    // MARK: reading photos (on device)

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("photo-finder.json")
    }
    static func loadCache() -> [String: Seen] {
        (try? Data(contentsOf: cacheURL)).flatMap { try? JSONDecoder().decode([String: Seen].self, from: $0) } ?? [:]
    }
    static func saveCache(_ c: [String: Seen]) {
        if let d = try? JSONEncoder().encode(c) { try? d.write(to: cacheURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }

    /// The newest photos (not videos), up to `limit` — what the finder looks through.
    static func recentPhotos(limit: Int) -> [PHAsset] {
        let o = PHFetchOptions()
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        o.fetchLimit = limit
        let r = PHAsset.fetchAssets(with: .image, options: o)
        var out: [PHAsset] = []; out.reserveCapacity(r.count)
        r.enumerateObjects { a, _, _ in out.append(a) }
        return out
    }

    static func image(_ a: PHAsset, side: CGFloat) async -> UIImage? {
        let opt = PHImageRequestOptions()
        opt.deliveryMode = .highQualityFormat; opt.resizeMode = .fast; opt.isNetworkAccessAllowed = true; opt.isSynchronous = false
        return await withCheckedContinuation { cont in
            var done = false
            PHImageManager.default().requestImage(for: a, targetSize: CGSize(width: side, height: side), contentMode: .aspectFit, options: opt) { im, info in
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                if !done { done = true; cont.resume(returning: im) }
            }
        }
    }

    /// Read one photo: labels, a fast text pass, faces, codes. Small image, one handler — about 0.1 s on a phone.
    static func read(_ a: PHAsset) async -> Seen? {
        guard let img = await image(a, side: 720), let cg = img.cgImage else { return nil }
        let shot = a.mediaSubtypes.contains(.photoScreenshot)
        return await Task.detached(priority: .utility) { () -> Seen in
            let cls = VNClassifyImageRequest()
            let txt = VNRecognizeTextRequest(); txt.recognitionLevel = .fast; txt.usesLanguageCorrection = false
            let face = VNDetectFaceRectanglesRequest()
            let code = VNDetectBarcodesRequest()
            try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([cls, txt, face, code])
            let labels = (cls.results ?? []).filter { $0.confidence > 0.25 }.prefix(12).map { $0.identifier.lowercased().replacingOccurrences(of: "_", with: " ") }
            let text = (txt.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            return Seen(modified: a.modificationDate?.timeIntervalSince1970 ?? 0, labels: Array(labels), text: String(text.prefix(600)),
                        faces: face.results?.count ?? 0, codes: code.results?.count ?? 0, screenshot: shot)
        }.value
    }
}

/// Runs the look-through for one kind, newest first, publishing matches as they're found so the first ones show in a
/// second or two, with an honest "Looking through your photos — 120 of 500".
@MainActor final class PhotoFinderModel: ObservableObject {
    @Published private(set) var matches: [PHAsset] = []
    @Published private(set) var looked = 0
    @Published private(set) var total = 0
    @Published private(set) var finished = false
    @Published private(set) var access: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    private var task: Task<Void, Never>?

    func start(_ kind: PhotoFinder.Kind, limit: Int = 600) {
        task?.cancel()
        task = Task {
            if access == .notDetermined { access = await PHPhotoLibrary.requestAuthorization(for: .readWrite) }
            guard access == .authorized || access == .limited else { finished = true; return }
            let assets = PhotoFinder.recentPhotos(limit: limit)
            total = assets.count; looked = 0; matches = []; finished = false
            var cache = PhotoFinder.loadCache()
            var scored: [(PHAsset, Double)] = []
            var fresh = 0
            for a in assets {
                if Task.isCancelled { break }
                let mod = a.modificationDate?.timeIntervalSince1970 ?? 0
                var seen = cache[a.localIdentifier]
                if seen == nil || seen!.modified != mod {
                    seen = await PhotoFinder.read(a)
                    if let s = seen { cache[a.localIdentifier] = s; fresh += 1 }
                    if fresh > 0, fresh % 40 == 0 { PhotoFinder.saveCache(cache) }
                }
                looked += 1
                if let s = seen {
                    let sc = PhotoFinder.score(s, for: kind)
                    if sc >= PhotoFinder.threshold {
                        scored.append((a, sc))
                        // Newest first among the strong matches, so what you just photographed leads.
                        matches = scored.map(\.0)
                    }
                }
            }
            if fresh > 0 { PhotoFinder.saveCache(cache) }
            finished = true
        }
    }

    func stop() { task?.cancel() }
}
