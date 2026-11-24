import Vision
import UIKit

/// Identify — "what is this?" Everything runs on the phone. It finds the main subject, reads any writing
/// and barcode on it, says honestly how sure it is, and knows what category the thing is so the result can
/// offer the useful next step (a plant's care, where to buy a product, a landmark on the map). When the
/// picture is really a group of people or a busy scene, it says so instead of guessing — and it never puts
/// a name on a person.
enum Identifier {
    struct Guess: Identifiable { let id = UUID(); let label: String; let confidence: Double }

    /// What the picture mainly is. `.people` means "a photo of people / a scene", not a single object to name.
    enum Subject { case object, animal, people }

    /// The kind of thing, so the result can offer the right next step. Drives the action buttons on the card.
    enum Category: String { case plant, animal, food, product, vehicle, place, art, money, object }

    struct Outcome {
        let subject: Subject
        let guesses: [Guess]
        let barcode: String?
        let symbology: String?
        let text: String?          // writing read off the thing (a brand, a model number, a label)
        let category: Category
        let sceneNote: String?     // set when it's really people / a scene, so we don't force a wrong guess
        /// Set when the photo is mostly writing — a schedule board, a receipt, a menu, a poster — named the way a
        /// person would, so the answer isn't "Document". Leads the result when present.
        var paper: Paper.Read? = nil
    }

    static func identify(_ image: UIImage) async -> Outcome {
        guard let cg = image.normalizedUp().cgImage else {
            return Outcome(subject: .object, guesses: [], barcode: nil, symbology: nil, text: nil, category: .object, sceneNote: nil)
        }
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)

        // Barcode — a product barcode is a definite answer, not a guess.
        let barcodeReq = VNDetectBarcodesRequest()
        try? handler.perform([barcodeReq])
        let bc = barcodeReq.results?.first
        let barcode = bc?.payloadStringValue
        let symbology = bc.map { prettySymbology($0.symbology) }

        // Writing on the thing — a brand or model number names it better than any classifier.
        let onThing = readText(cg)

        // How much of the frame is people — so a group photo is called what it is, not "Lamp".
        let people = peopleCoverage(cg)

        // Is it an animal? Apple recognises cats and dogs directly.
        let animal = recognisedAnimal(cg)

        // Classify the whole frame AND zoomed-in windows, so a small subject still surfaces; best confidence
        // per label across all views wins, with generic "any photo" labels demoted.
        // Each view counts by how much of the picture it shows (Manan, 23 Nov: a living room with a big TV came back
        // "Container 88%, Vase 88%" — a vase in one small corner window beat the TV that fills the frame). The whole
        // photo counts fully, the main subject nearly so, a quarter window much less, a ninth window least; a label
        // seen across many views gets a little more.
        var views: [(CGImage, Double)] = [(cg, 1.0)]
        if let subject = subjectCrop(cg) { views.append((subject, 0.95)) }
        views += windows(of: cg, fraction: 0.5).map { ($0, 0.6) }
        views += windows(of: cg, fraction: 0.33).map { ($0, 0.4) }
        let frames = views
        let box = Merge()
        DispatchQueue.concurrentPerform(iterations: frames.count) { i in
            let req = VNClassifyImageRequest()
            try? VNImageRequestHandler(cgImage: frames[i].0, orientation: .up).perform([req])
            box.add((req.results ?? []).filter { $0.confidence > 0.08 }.map { ($0.identifier, Double($0.confidence)) }, weight: frames[i].1)
        }
        let best = box.best
        let ranked = best.map { (id: $0.key, conf: $0.value, score: $0.value * (generic.contains($0.key.lowercased()) ? 0.3 : 1)) }
            .sorted { $0.score > $1.score }
        // A screen in the room — a TV on the wall — is named for what it is, not for the picture it's showing (24 Nov:
        // Manan's living room came back "Container, Vase", then "Night Sky" from the TV's own wallpaper). Found by its
        // shape, not by the classifier: a big, wide, TV-proportioned rectangle with a dark bezel round the edge.
        let screen = screenIn(cg)
        let onScreen: Set<String> = ["night_sky", "sky", "celestial_body", "moon", "screenshot", "document", "website", "text", "outdoor"]
        let specific = ranked.filter { !generic.contains($0.id.lowercased()) && !(screen != nil && onScreen.contains($0.id.lowercased())) }
        let topSpecific = specific.first

        // Decide what the picture mainly is.
        let subject: Subject
        var sceneNote: String? = nil
        if animal != nil {
            subject = .animal
        } else if barcode != nil {
            subject = .object
        } else if screen == nil && people > 0.3 && (topSpecific?.conf ?? 0) < 0.5 {
            // People fill the frame and nothing else stands out — don't invent an object name.
            subject = .people
            sceneNote = "This looks like a photo of people, not a single object. To name something, point at the one thing you want — get in close on just that."
        } else {
            subject = .object
        }

        // Build the guess list. For an animal, lead with the recognised kind, then the breed if the classifier found one.
        var guesses: [Guess]
        switch subject {
        case .people:
            guesses = []
        case .animal:
            var g: [Guess] = []
            if let a = animal { g.append(Guess(label: a.label, confidence: a.confidence)) }
            g += specific.prefix(4).map { Guess(label: cleanLabel($0.id), confidence: $0.conf) }
            guesses = dedupe(g)
        case .object:
            // Prefer specific labels; fall back to whatever we have (still honest about low confidence).
            let source = specific.isEmpty && screen == nil ? ranked : specific
            var g = source.prefix(6).map { Guess(label: cleanLabel($0.id), confidence: $0.conf) }
            if let screen { g.insert(Guess(label: screen.label, confidence: screen.confidence), at: 0) }
            guesses = dedupe(Array(g.prefix(6)))
        }

        let topLabel = guesses.first?.label
        let category = categoryFor(topLabel, animal: animal != nil, barcode: barcode != nil)
        var out = Outcome(subject: subject, guesses: guesses, barcode: barcode, symbology: symbology, text: onThing, category: category, sceneNote: sceneNote)
        // A photo that's mostly writing is a written thing first: read all of it and name what kind. A product
        // with a barcode stays a product.
        if barcode == nil, animal == nil {
            let all = DocEngine.recognize(image.normalizedUp())
            out.paper = Paper.classify(all)
        }
        return out
    }

    // MARK: - Category → the useful next step

    /// Work out the category from the best label, so the card can offer the right action (plant care, where to buy…).
    static func categoryFor(_ label: String?, animal: Bool, barcode: Bool) -> Category {
        if animal { return .animal }
        if barcode { return .product }
        let l = (label ?? "").lowercased()
        func has(_ words: [String]) -> Bool { words.contains { l.contains($0) } }
        if has(["dog", "cat", "bird", "fish", "retriever", "terrier", "spaniel", "poodle", "bulldog", "tabby", "kitten", "puppy", "horse", "rabbit", "hamster", "reptile", "snake", "lizard", "turtle", "spider", "insect", "bee", "butterfly", "beetle", "frog", "ant"]) { return .animal }
        if has(["plant", "flower", "tree", "leaf", "succulent", "fern", "cactus", "rose", "orchid", "monstera", "houseplant", "shrub", "moss", "bonsai", "mushroom", "fungus", "ivy", "palm"]) { return .plant }
        if has(["food", "dish", "cake", "pizza", "bread", "fruit", "vegetable", "meal", "dessert", "soup", "salad", "burger", "sandwich", "coffee", "sushi", "pasta", "rice", "noodle", "cheese", "pie", "cookie", "banana", "apple", "drink"]) { return .food }
        if has(["car", "truck", "suv", "motorcycle", "bicycle", "bike", "vehicle", "van", "bus", "scooter", "sedan", "automobile"]) { return .vehicle }
        if has(["building", "landmark", "tower", "bridge", "monument", "church", "temple", "castle", "statue", "skyscraper", "mountain", "architecture", "palace", "cathedral", "lighthouse"]) { return .place }
        if has(["painting", "sculpture", "artwork", "portrait", "drawing", "mural", "fresco"]) { return .art }
        if has(["coin", "currency", "banknote", "cash", "stamp", "medal", "bill"]) { return .money }
        if has(["phone", "laptop", "camera", "headphone", "earbud", "watch", "appliance", "gadget", "device", "bottle", "shoe", "bag", "furniture", "chair", "lamp", "tool", "keyboard", "mouse", "speaker", "console", "controller"]) { return .product }
        return .object
    }

    // MARK: - Pieces

    /// A TV or monitor in the picture, found by its shape: the biggest wide rectangle that is TV-proportioned (about
    /// 16:9, between 3:2 and 2.2:1), takes a fair part of the photo but isn't the whole photo (then it's a screenshot
    /// or a photo of a screen up close), and has a dark bezel — the thin band just inside its edge is near-black.
    static func screenIn(_ cg: CGImage) -> (label: String, confidence: Double, box: CGRect)? {
        let req = VNDetectRectanglesRequest()
        req.maximumObservations = 8
        req.minimumSize = 0.2
        req.minimumConfidence = 0.6
        req.minimumAspectRatio = 0.4
        req.maximumAspectRatio = 0.72
        req.quadratureTolerance = 20
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
        let W = CGFloat(cg.width), H = CGFloat(cg.height)
        let found = (req.results ?? []).sorted { $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height }
        for r in found {
            let b = r.boundingBox
            let rect = CGRect(x: b.minX * W, y: (1 - b.maxY) * H, width: b.width * W, height: b.height * H).integral
            let area = b.width * b.height
            let aspect = rect.width / max(1, rect.height)
            guard area >= 0.06, area <= 0.7, aspect >= 1.45, aspect <= 2.2 else { continue }
            guard let edge = bezelLuma(cg, rect), edge < 0.22 else { continue }
            return ("Television", min(0.95, 0.75 + 0.2 * Double(r.confidence)), rect)
        }
        return nil
    }

    /// Brightness (0…1) of the darkest thin ring just inside a rectangle's edge, looking a little way in (0–11.5%), so a
    /// detected box that sits a few pixels off the TV's real edge still finds the bezel.
    static func bezelLuma(_ cg: CGImage, _ rect: CGRect) -> Double? {
        guard let crop = cg.cropping(to: rect) else { return nil }
        let w = 240, h = max(16, Int(240 * rect.height / max(1, rect.width)))
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
        var rings: [Double] = []
        // Rings 1.5% wide, every 1%: a TV's bezel is often only about 1% of its width.
        for start in stride(from: 0.0, through: 0.10, by: 0.01) {
            let lo = Int(Double(w) * start), hi = lo + max(2, Int(Double(w) * 0.015))
            var sum = 0.0, n = 0
            for y in 0..<h { for x in 0..<w {
                let d = min(x, y, w - 1 - x, h - 1 - y)
                guard d >= lo, d < hi else { continue }
                let i = (y * w + x) * 4
                sum += (0.2126 * Double(px[i]) + 0.7152 * Double(px[i + 1]) + 0.0722 * Double(px[i + 2])) / 255; n += 1
            } }
            if n > 0 { rings.append(sum / Double(n)) }
        }
        return rings.min()
    }

    /// Thread-safe "best confidence per label" accumulator for the parallel classification passes.
    private final class Merge: @unchecked Sendable {
        private let lock = NSLock()
        private var map: [String: Double] = [:]
        private var seen: [String: Int] = [:]
        func add(_ items: [(String, Double)], weight: Double = 1) {
            lock.lock()
            for (k, v) in items { map[k] = max(map[k] ?? 0, v * weight); seen[k, default: 0] += 1 }
            lock.unlock()
        }
        /// Weighted best per label, nudged up (at most 15%) when many views agree, capped at 1.
        var best: [String: Double] {
            lock.lock(); defer { lock.unlock() }
            return map.reduce(into: [:]) { out, kv in out[kv.key] = min(1, kv.value * (1 + min(0.15, 0.03 * Double((seen[kv.key] ?? 1) - 1)))) }
        }
    }

    /// Labels that describe nearly any photo with people, sky or ground in it — including the people words that
    /// let "Child" slip through before. These are demoted, and people words never become a guess.
    private static let generic: Set<String> = [
        "clothing", "jeans", "footwear", "shoes", "shoe", "boot", "people", "adult", "crowd", "person", "child", "children",
        "baby", "toddler", "man", "woman", "boy", "girl", "human", "kid", "family", "group", "outerwear", "jacket", "hat",
        "headwear", "portrait", "face", "hair", "sky", "cloudy", "cloud", "outdoor", "indoor", "structure", "water", "material",
        "wood_processed", "textile", "fabric", "denim", "sportswear", "t_shirt", "shirt", "pants", "coat", "sweater", "hoodie",
        "sunglasses", "glasses", "machine", "land", "ground", "floor", "wall", "ceiling", "room", "furniture", "table",
        // Words that fit almost anything and named nothing useful (23 Nov: "Container", "Document", "Screenshot" for a TV).
        "container", "decoration", "art", "document", "screenshot", "interior_room", "interior_shop", "consumer_electronics",
        "electronics", "appliance", "object", "equipment", "liquid_container", "vessel"
    ]

    /// Read the most prominent writing on the thing (a brand, a model number). The two largest text lines, joined.
    private static func readText(_ cg: CGImage) -> String? {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
        let lines = (req.results ?? [])
            .compactMap { obs -> (text: String, height: CGFloat)? in
                guard let s = obs.topCandidates(1).first?.string else { return nil }
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                guard t.count >= 2, t.count <= 40, t.rangeOfCharacter(from: .letters) != nil else { return nil }
                return (t, obs.boundingBox.height)
            }
            .sorted { $0.height > $1.height }
            .prefix(2)
            .map { $0.text }
        let joined = lines.joined(separator: " · ")
        return joined.isEmpty ? nil : joined
    }

    /// Fraction of the frame covered by people (faces and bodies), used to tell a scene from a single object.
    private static func peopleCoverage(_ cg: CGImage) -> CGFloat {
        let faces = VNDetectFaceRectanglesRequest()
        let bodies = VNDetectHumanRectanglesRequest()
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([faces, bodies])
        func cover(_ boxes: [CGRect]) -> CGFloat { min(1, boxes.reduce(0) { $0 + $1.width * $1.height }) }
        let faceCover = cover((faces.results ?? []).map { $0.boundingBox })
        let bodyCover = cover((bodies.results ?? []).map { $0.boundingBox })
        // Faces are small but reliable; count several faces as a strong people signal too.
        let faceCount = CGFloat((faces.results ?? []).count)
        return max(bodyCover, faceCover, min(1, faceCount * 0.12))
    }

    /// Apple's on-device cat/dog recogniser. Returns the kind and how sure it is.
    private static func recognisedAnimal(_ cg: CGImage) -> (label: String, confidence: Double)? {
        let req = VNRecognizeAnimalsRequest()
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
        guard let obj = req.results?.max(by: { ($0.labels.first?.confidence ?? 0) < ($1.labels.first?.confidence ?? 0) }),
              let top = obj.labels.first, top.confidence > 0.6 else { return nil }
        return (cleanLabel(top.identifier), Double(top.confidence))
    }

    /// Overlapping square-ish windows covering the picture, each `fraction` of its size, stepping by half a window.
    private static func windows(of cg: CGImage, fraction: CGFloat) -> [CGImage] {
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let cw = w * fraction, ch = h * fraction
        guard cw >= 64, ch >= 64 else { return [] }
        var out: [CGImage] = []
        var y: CGFloat = 0
        while y + ch <= h + 1 {
            var x: CGFloat = 0
            while x + cw <= w + 1 {
                if let c = cg.cropping(to: CGRect(x: x, y: y, width: cw, height: ch).integral) { out.append(c) }
                x += cw / 2
            }
            y += ch / 2
        }
        return out
    }

    /// Turn a raw classifier identifier ("golden_retriever") into something a person reads ("Golden Retriever").
    static func cleanLabel(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    /// Drop repeated labels (case-insensitive), keeping the first (highest) occurrence.
    private static func dedupe(_ g: [Guess]) -> [Guess] {
        var seen = Set<String>(); var out: [Guess] = []
        for x in g where seen.insert(x.label.lowercased()).inserted { out.append(x) }
        return out
    }

    /// A tight crop around the most salient region, so classification focuses on the actual subject.
    private static func subjectCrop(_ cg: CGImage) -> CGImage? {
        let req = VNGenerateObjectnessBasedSaliencyImageRequest()
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
        guard let obj = req.results?.first as? VNSaliencyImageObservation,
              let salient = obj.salientObjects?.max(by: { $0.confidence < $1.confidence }) else { return nil }
        let b = salient.boundingBox
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let rect = CGRect(x: b.minX * w, y: (1 - b.maxY) * h, width: b.width * w, height: b.height * h)
            .insetBy(dx: -b.width * w * 0.08, dy: -b.height * h * 0.08)
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard !rect.isNull, rect.width > w * 0.15, rect.height > h * 0.15 else { return nil }
        return cg.cropping(to: rect)
    }

    private static func prettySymbology(_ s: VNBarcodeSymbology) -> String {
        switch s {
        case .ean13, .ean8, .upce: return "Product barcode"
        case .qr: return "QR code"
        case .code128, .code39, .code93: return "Barcode"
        default: return "Barcode"
        }
    }
}
