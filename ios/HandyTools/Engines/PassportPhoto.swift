import UIKit
import Vision
import CoreImage

/// Passport and ID photos, made to each country's published rules and measured, not guessed.
///
/// One engine used everywhere a passport photo can be made (Studio, the Builder step, the Guide, batches,
/// the Share sheet), so every path gets the same result:
///  • finds the face with Apple's on-device face landmarks: pupils, chin, and the top of the head from the
///    person outline (hair included), with a sanity check against the eye-to-chin distance;
///  • fixes what software may fix: levels a tilted head, sizes the head and places the eye line inside the
///    country's range, centres the face, makes the background plain in the right colour, evens out a
///    one-sided shadow and lifts a dark face;
///  • measures the finished photo again (head height and eye line in millimetres on the printed photo) and
///    grades it, so the score is about the actual file, not about what we meant to do;
///  • is honest about what it can't fix (eyes closed, face turned away, blur) and says to retake.
/// A helper: the office that accepts the photo has the final say.
enum PassportPhoto {

    // MARK: country rules

    enum Background: String { case white, lightGrey
        var color: UIColor { self == .white ? .white : UIColor(white: 0.92, alpha: 1) }
        var name: String { self == .white ? "plain white" : "plain light grey" }
    }

    struct Spec: Identifiable, Equatable {
        let id: String
        let name: String            // full name, e.g. "US passport · 2×2 in"
        let short: String           // chip label
        let mm: CGSize              // printed size, width × height in mm
        let px: CGSize              // the file, in pixels
        let head: ClosedRange<Double>      // chin to top of head, mm on the printed photo
        let eyes: ClosedRange<Double>?     // eye line, mm up from the bottom edge
        let background: Background
        let unaltered: Bool         // the issuer asks for photos not changed by software
        let printable: Bool         // false for an online-only upload
        let percent: Bool           // the rule is written as a share of the photo's height
        let rules: [String]         // things only the person can check
        let source: String          // where the numbers come from
        var pxPerMM: Double { Double(px.height / mm.height) }
        var headText: String {
            percent ? "\(Int((head.lowerBound / mm.height * 100).rounded()))–\(Int((head.upperBound / mm.height * 100).rounded()))% of the height"
                    : "\(fmt(head.lowerBound))–\(fmt(head.upperBound)) mm"
        }
    }

    static func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }

    /// Sources: travel.state.gov (US), gov.uk/photos-for-passports (UK), canada.ca passport photos (Canada),
    /// EU Visa Code / ICAO 9303 (Schengen), Indian missions' ICAO photo guidelines 2025 (India).
    static let specs: [Spec] = [
        Spec(id: "us", name: "US passport · 2×2 in", short: "US", mm: CGSize(width: 51, height: 51), px: CGSize(width: 600, height: 600),
             head: 25...35, eyes: 28...35, background: .white, unaltered: false, printable: true, percent: false,
             rules: ["Glasses off — the US no longer accepts glasses in passport photos", "No hat or head covering, unless for religious or medical reasons", "Taken in the last 6 months, in colour"],
             source: "travel.state.gov"),
        Spec(id: "uk", name: "UK passport · 35×45 mm", short: "UK", mm: CGSize(width: 35, height: 45), px: CGSize(width: 413, height: 531),
             head: 29...34, eyes: nil, background: .lightGrey, unaltered: false, printable: true, percent: false,
             rules: ["Background: plain cream or light grey", "Glasses only if you need them: no tint, glare or frames over the eyes", "Taken in the last month"],
             source: "gov.uk/photos-for-passports"),
        Spec(id: "eu", name: "EU / Schengen · 35×45 mm", short: "EU / Schengen", mm: CGSize(width: 35, height: 45), px: CGSize(width: 413, height: 531),
             head: 32...36, eyes: nil, background: .white, unaltered: false, printable: true, percent: false,
             rules: ["No tinted glasses or glare over the eyes", "Taken in the last 6 months"],
             source: "EU Visa Code and ICAO 9303"),
        Spec(id: "in", name: "India passport · 35×45 mm", short: "India", mm: CGSize(width: 35, height: 45), px: CGSize(width: 630, height: 810),
             head: 36...38.25, eyes: nil, background: .white, unaltered: true, printable: true, percent: false,
             rules: ["White background", "India asks for photos not altered by software — retake rather than retouch", "No glare on glasses; eyes clearly visible"],
             source: "Indian missions' ICAO photo guidelines"),
        Spec(id: "ca", name: "Canada passport · 50×70 mm", short: "Canada", mm: CGSize(width: 50, height: 70), px: CGSize(width: 591, height: 827),
             head: 31...36, eyes: nil, background: .white, unaltered: false, printable: true, percent: false,
             rules: ["Two identical prints, with the photographer's details on the back of one", "Eyes clearly visible: no tinted glasses or glare", "Taken in the last 6 months"],
             source: "canada.ca passport photos"),
        Spec(id: "ca-online", name: "Canada online renewal · 1200×1800", short: "Canada online", mm: CGSize(width: 50, height: 75), px: CGSize(width: 1200, height: 1800),
             head: 33.75...37.5, eyes: nil, background: .white, unaltered: false, printable: false, percent: true,
             rules: ["Upload as JPEG, 200 KB to 5 MB — this file fits", "Eyes clearly visible: no tinted glasses or glare", "Taken in the last 6 months"],
             source: "canada.ca passport photos"),
    ]

    static func spec(_ id: String?) -> Spec { specs.first { $0.id == id } ?? specs[0] }

    // MARK: what was found and made

    struct Options: Hashable {
        var background = true       // make the background plain, in the country's colour
        var light = true            // even out a one-sided shadow, lift a dark face
        var straighten = true       // level a tilted head
        static func defaults(for spec: Spec) -> Options {
            spec.unaltered ? Options(background: false, light: false, straighten: true) : Options()
        }
    }

    enum State: Int { case pass, warn, fail }

    struct Check: Identifiable {
        let id: String
        let title: String
        let state: State
        let detail: String          // what was measured, in plain words
        let fix: String             // what to do when it isn't a pass
        let weight: Double
        let hard: Bool              // can't be fixed by software — a retake
    }

    struct Fix: Identifiable { let id = UUID(); let icon: String; let text: String }

    struct Guides {
        var crownY: CGFloat, chinY: CGFloat, eyeY: CGFloat     // in the output's pixels, top = 0
        var headBand: ClosedRange<CGFloat>                      // where the crown may sit for the chin as placed
        var eyeBand: ClosedRange<CGFloat>?                      // the allowed eye-line band, top to bottom
        var centreX: CGFloat
    }

    struct Made {
        let image: UIImage
        let spec: Spec
        let options: Options
        let checks: [Check]
        let fixes: [Fix]
        let guides: Guides
        let headMM: Double
        let eyesMM: Double
        let score: Int
        var passing: Int { checks.filter { $0.state == .pass }.count }
        var toFix: [Check] { checks.filter { $0.state != .pass } }
        var retake: Bool { checks.contains { $0.hard && $0.state == .fail } }
        var verdict: String {
            if retake { return "Retake recommended" }
            return score >= 90 ? "Ready to use" : (score >= 70 ? "Almost there" : "Needs work")
        }
    }

    /// Where the face is, in image pixels with the top-left as origin.
    struct Face {
        var box: CGRect
        var chin: CGPoint
        var crown: CGPoint
        var eyes: (CGPoint, CGPoint)            // left-in-image, right-in-image
        var crownMeasured: Bool                 // from the head outline (true) or estimated
        var roll: Double                        // eye-line tilt in degrees; + = clockwise on screen
        var yaw: Double, pitch: Double
        var eyeOpen: [Double], mouth: Double?
        var quality: Float?
        var count: Int
        var eyeY: CGFloat { (eyes.0.y + eyes.1.y) / 2 }
        var centreX: CGFloat { ((eyes.0.x + eyes.1.x) / 2 + chin.x) / 2 }
    }

    // MARK: make

    /// The whole job: level, light, background, size and place, then measure and grade the result.
    /// Nil when there's no face at all.
    static func make(_ image: UIImage, spec: Spec, options: Options? = nil) -> Made? {
        let opts = options ?? Options.defaults(for: spec)
        var src = image.normalizedUp()
        if max(src.size.width, src.size.height) * src.scale > 4000 { src = src.resized(maxDimension: 4000) }
        guard var cg = src.cgImage, var face = analyze(cg) else { return nil }
        var fixes: [Fix] = []

        // 1. Level the head (geometry only — allowed everywhere).
        if opts.straighten, abs(face.roll) > 1, abs(face.roll) < 25 {
            for sign in [1.0, -1.0] {
                if let turned = rotate(cg, degrees: face.roll * sign, about: CGPoint(x: face.centreX, y: face.eyeY)),
                   let again = analyze(turned), abs(again.roll) < abs(face.roll) {
                    fixes.append(Fix(icon: "level", text: "Straightened your head by \(Int(abs(face.roll).rounded()))°"))
                    cg = turned; face = again; break
                }
            }
        }

        let mask = personMask(cg)
        if let mask, let crown = crownFromMask(mask, face: face, height: CGFloat(cg.height), width: CGFloat(cg.width)) {
            face.crown = crown; face.crownMeasured = true
        }
        let crownWasClamped = clampCrown(&face)

        // 2. Light: even out a one-sided shadow, lift a dark face.
        var ci = CIImage(cgImage: cg)
        if opts.light, let h = halves(cg, face.box) {
            let (l, r) = h
            if abs(l - r) > 0.08 {
                let dark = min(l, r), bright = max(l, r)
                let ev = min(0.9, log2(bright / max(dark, 0.05)) * 0.9)
                ci = evenOut(ci, face: face.box, height: CGFloat(cg.height), leftDark: l < r, ev: ev, mask: mask, size: CGSize(width: cg.width, height: cg.height))
                fixes.append(Fix(icon: "sun.max", text: "Evened out the shadow on the \(l < r ? "left" : "right") of your face"))
            }
            let mean = (l + r) / 2
            if mean < 0.38 {
                ci = ci.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: min(1.0, log2(0.5 / max(mean, 0.05)))])
                fixes.append(Fix(icon: "sun.min", text: "Brightened your face, which was in shade"))
            }
        }

        // 3. Background: the person on the country's colour.
        if opts.background, let mask {
            ci = onPlain(ci, mask: mask, color: spec.background.color)
            fixes.append(Fix(icon: "rectangle.portrait", text: "Background made \(spec.background.name)"))
        }
        guard let worked = context.createCGImage(ci, from: CGRect(x: 0, y: 0, width: cg.width, height: cg.height), format: .RGBA8,
                                                 colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else { return nil }

        // 4. Size and place: the head in the middle of the allowed range, the eye line in its band, centred.
        let ppm = CGFloat(spec.pxPerMM)
        let outW = spec.px.width, outH = spec.px.height
        let headPx = max(1, face.chin.y - face.crown.y)
        let s = CGFloat((spec.head.lowerBound + spec.head.upperBound) / 2) * ppm / headPx
        var crownOut: CGFloat
        if let eyes = spec.eyes {
            let eyeOut = outH - CGFloat((eyes.lowerBound + eyes.upperBound) / 2) * ppm
            crownOut = eyeOut - (face.eyeY - face.crown.y) * s
        } else {
            crownOut = CGFloat(Double(spec.mm.height) - (spec.head.lowerBound + spec.head.upperBound) / 2) * 0.42 * ppm
        }
        crownOut = max(crownOut, 1.5 * ppm)
        let draw = CGRect(x: outW / 2 - face.centreX * s, y: crownOut - face.crown.y * s, width: CGFloat(worked.width) * s, height: CGFloat(worked.height) * s)
        let fmtR = UIGraphicsImageRendererFormat.default(); fmtR.scale = 1; fmtR.opaque = true
        let out = UIGraphicsImageRenderer(size: spec.px, format: fmtR).image { c in
            spec.background.color.setFill(); c.fill(CGRect(origin: .zero, size: spec.px))
            c.cgContext.interpolationQuality = .high
            UIImage(cgImage: worked).draw(in: draw)
        }
        let placedHead = Double(headPx * s / ppm)
        fixes.append(Fix(icon: "arrow.up.and.down", text: "Head sized to \(fmt((placedHead * 10).rounded() / 10)) mm and centred (needs \(spec.headText))"))
        let bottomGap = max(0, outH - draw.maxY) / outH
        let sideGap = max(0, draw.minX, outW - draw.maxX) / outW
        if bottomGap > 0.01 || sideGap > 0.01 || draw.minY > 1 {
            fixes.append(Fix(icon: "square.dashed", text: "Your photo didn't reach the \(bottomGap > 0.01 ? "bottom" : "edge") — filled in with plain background"))
        }

        // 5. Measure the finished photo again and grade it.
        let outCG = out.cgImage
        let after = outCG.flatMap(analyze)
        var placed = after ?? project(face, s: s, dx: draw.minX, dy: draw.minY)
        if after != nil {
            // The crown and chin, as placed, are exact; re-reading the crown from a small file is noisier.
            placed.crown = CGPoint(x: face.crown.x * s + draw.minX, y: crownOut)
        }
        let headMM = Double((placed.chin.y - placed.crown.y) / ppm)
        let eyesMM = Double((outH - placed.eyeY) / ppm)

        var checks: [Check] = []
        func add(_ id: String, _ title: String, _ st: State, _ detail: String, _ fix: String, _ w: Double, hard: Bool = false) {
            checks.append(Check(id: id, title: title, state: st, detail: detail, fix: fix, weight: w, hard: hard))
        }
        add("one", "Just you, face fully in view", face.count == 1 ? .pass : .fail,
            face.count == 1 ? "One face found" : "\(face.count) faces found",
            "Only you should be in the photo. Take one with nobody else in the frame.", 15, hard: true)
        add("facing", "Facing the camera", face.yaw < 8 ? .pass : (face.yaw < 14 ? .warn : .fail),
            "Turned \(Int(face.yaw.rounded()))° to the side",
            "Turn your face straight to the camera, shoulders square.", 10, hard: face.yaw >= 14)
        add("chin", "Chin level, not up or down", face.pitch < 12 ? .pass : (face.pitch < 18 ? .warn : .fail),
            "Tilted \(Int(face.pitch.rounded()))° up or down",
            "Hold the camera at eye level and keep your chin level.", 5, hard: face.pitch >= 18)
        let headIn = spec.head.contains(headMM)
        add("head", "Head size", headIn ? .pass : .warn,
            spec.percent ? "\(Int((headMM / Double(spec.mm.height) * 100).rounded()))% of the height (needs \(spec.headText))" : "\(fmt((headMM * 10).rounded() / 10)) mm (needs \(spec.headText))",
            crownWasClamped ? "Hair or a head covering made the top of your head hard to find. Check the top line sits at the top of your head." : "Try a photo with your whole head and shoulders in view.", 15)
        if let eyes = spec.eyes {
            add("eyeline", "Eye height", eyes.contains(eyesMM) ? .pass : .warn,
                "\(fmt((eyesMM * 10).rounded() / 10)) mm from the bottom (needs \(fmt(eyes.lowerBound))–\(fmt(eyes.upperBound)) mm)",
                "Take the photo from a little further away so there's room above and below.", 5)
        }
        let level = abs(placed.roll)
        add("level", "Head level", level < 2.5 ? .pass : (level < 6 ? .warn : .fail),
            level < 2.5 ? "Level" : "Tilted \(Int(level.rounded()))°", "Keep your head straight, not leaning to one side.", 5)
        let eyesOK = !face.eyeOpen.isEmpty && face.eyeOpen.allSatisfy { $0 > 0.14 }
        add("eyes", "Eyes open", face.eyeOpen.isEmpty ? .warn : (eyesOK ? .pass : .fail),
            face.eyeOpen.isEmpty ? "Couldn't see your eyes clearly" : (eyesOK ? "Both open" : "Look closed or squinting"),
            "Take another with your eyes fully open, looking at the lens.", 10, hard: !face.eyeOpen.isEmpty && !eyesOK)
        if let m = face.mouth {
            add("mouth", "Neutral expression, mouth closed", m < 0.45 ? .pass : .warn,
                m < 0.45 ? "Neutral" : "Mouth open or a big smile",
                "Close your mouth and keep a neutral face — most countries don't accept a smile with teeth.", 5)
        }
        if let q = face.quality {
            add("sharp", "Sharp and in focus", q >= 0.35 ? .pass : (q >= 0.22 ? .warn : .fail),
                q >= 0.35 ? "Sharp" : "Soft or blurry",
                "Hold steady, use more light and tap your face to focus. Software can't sharpen a blurry face honestly.", 10, hard: q < 0.22)
        }
        if let outCG, let h = halves(outCG, placed.box) {
            let (l, r) = h
            let even = abs(l - r) < 0.12, bright = min(l, r) > 0.28
            add("light", "Even light on your face", even && bright ? .pass : .warn,
                even && bright ? "Even" : (bright ? "One side darker" : "Face is dark"),
                "Face a window or a lamp so light falls evenly on both sides.", 5)
        }
        if let outCG, let bg = PassportCheck.borderStats(outCG) {
            let ok = bg.mean > 0.78 && bg.spread < 0.08
            add("background", "Background \(spec.background.name)", ok ? .pass : (bg.mean > 0.65 ? .warn : .fail),
                ok ? "Plain" : (bg.mean > 0.65 ? "Not quite plain" : "Too dark or busy"),
                opts.background ? "Stand in front of a plain light wall and try again." : "Turn on \"Plain background\", or stand in front of a plain light wall.", 10)
        }
        add("detail", "Enough detail to print", s <= 1.6 ? .pass : (s <= 2.6 ? .warn : .fail),
            s <= 1.6 ? "Plenty" : "Your face is small in the original — this was enlarged \(String(format: "%.1f", Double(s)))×",
            "Step closer or use the back camera so your face fills more of the frame.", 5)
        add("shoulders", "Head and shoulders in frame", bottomGap <= 0.04 && draw.minY <= 1 ? .pass : .warn,
            bottomGap <= 0.04 ? "In frame" : "The original stops above your shoulders",
            "Take it from a little further away so your shoulders show.", 5)

        let total = checks.reduce(0.0) { $0 + $1.weight }
        let got = checks.reduce(0.0) { $0 + $1.weight * ($1.state == .pass ? 1 : ($1.state == .warn ? 0.5 : 0)) }
        var score = Int((got / max(total, 1) * 100).rounded())
        if checks.contains(where: { $0.hard && $0.state == .fail }) { score = min(score, 45) }

        let ppmOut = ppm
        let chinOut = placed.chin.y
        let guides = Guides(crownY: placed.crown.y, chinY: chinOut, eyeY: placed.eyeY,
                            headBand: (chinOut - CGFloat(spec.head.upperBound) * ppmOut)...(chinOut - CGFloat(spec.head.lowerBound) * ppmOut),
                            eyeBand: spec.eyes.map { (outH - CGFloat($0.upperBound) * ppmOut)...(outH - CGFloat($0.lowerBound) * ppmOut) },
                            centreX: placed.centreX)
        return Made(image: out, spec: spec, options: opts, checks: checks, fixes: fixes, guides: guides, headMM: headMM, eyesMM: eyesMM, score: score)
    }

    // MARK: files

    /// The file to hand in: JPEG at the country's pixel size, kept within the upload limits.
    static func file(_ made: Made) -> Data? {
        guard var d = made.image.jpegData(compressionQuality: 0.95) else { return nil }
        if made.spec.id == "ca-online", d.count < 200_000, let hi = made.image.jpegData(compressionQuality: 1) { d = hi }
        return d
    }

    /// A 4×6 in print at 300 dpi, the photo tiled at its true printed size with thin cut lines.
    static func printSheet(_ made: Made) -> (data: Data, copies: Int)? {
        let sheet = CGSize(width: 1200, height: 1800)
        let pw = (made.spec.mm.width / 25.4 * 300).rounded(), ph = (made.spec.mm.height / 25.4 * 300).rounded()
        let gap: CGFloat = 24, margin: CGFloat = 30
        let cols = max(1, Int((sheet.width - 2 * margin + gap) / (pw + gap)))
        let rows = max(1, Int((sheet.height - 2 * margin + gap) / (ph + gap)))
        let fmtR = UIGraphicsImageRendererFormat.default(); fmtR.scale = 1
        let img = UIGraphicsImageRenderer(size: sheet, format: fmtR).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: sheet))
            let gridW = CGFloat(cols) * pw + CGFloat(cols - 1) * gap, gridH = CGFloat(rows) * ph + CGFloat(rows - 1) * gap
            let x0 = (sheet.width - gridW) / 2, y0 = (sheet.height - gridH) / 2
            UIColor(white: 0.75, alpha: 1).setStroke()
            for r in 0..<rows { for c in 0..<cols {
                let rect = CGRect(x: x0 + CGFloat(c) * (pw + gap), y: y0 + CGFloat(r) * (ph + gap), width: pw, height: ph)
                made.image.draw(in: rect)
                let g = UIBezierPath(rect: rect.insetBy(dx: -0.5, dy: -0.5)); g.lineWidth = 1; g.stroke()
            } }
        }
        guard let d = img.jpegData(compressionQuality: 0.95) else { return nil }
        return (d, rows * cols)
    }

    // MARK: reading the face

    private static let context = CIContext()

    static func analyze(_ cg: CGImage) -> Face? {
        let W = CGFloat(cg.width), H = CGFloat(cg.height)
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        let rects = VNDetectFaceRectanglesRequest(); rects.revision = VNDetectFaceRectanglesRequestRevision3
        try? handler.perform([rects])
        let faces = rects.results ?? []
        guard let main = faces.max(by: { $0.boundingBox.height < $1.boundingBox.height }) else { return nil }
        let marks = VNDetectFaceLandmarksRequest(); marks.revision = VNDetectFaceLandmarksRequestRevision3
        marks.inputFaceObservations = [main]
        let quality = VNDetectFaceCaptureQualityRequest(); quality.inputFaceObservations = [main]
        try? handler.perform([marks, quality])
        let obs = marks.results?.first ?? main
        let size = CGSize(width: W, height: H)
        func pts(_ r: VNFaceLandmarkRegion2D?) -> [CGPoint] { (r?.pointsInImage(imageSize: size) ?? []).map { CGPoint(x: $0.x, y: H - $0.y) } }
        func mid(_ p: [CGPoint]) -> CGPoint? { p.isEmpty ? nil : CGPoint(x: p.map(\.x).reduce(0, +) / CGFloat(p.count), y: p.map(\.y).reduce(0, +) / CGFloat(p.count)) }

        let bb = main.boundingBox
        let box = CGRect(x: bb.minX * W, y: (1 - bb.maxY) * H, width: bb.width * W, height: bb.height * H)
        let lm = obs.landmarks
        let contour = pts(lm?.faceContour)
        let chin = contour.max(by: { $0.y < $1.y }) ?? CGPoint(x: box.midX, y: box.maxY)
        var e1 = mid(pts(lm?.leftPupil)) ?? mid(pts(lm?.leftEye)) ?? CGPoint(x: box.minX + box.width * 0.3, y: box.minY + box.height * 0.4)
        var e2 = mid(pts(lm?.rightPupil)) ?? mid(pts(lm?.rightEye)) ?? CGPoint(x: box.minX + box.width * 0.7, y: box.minY + box.height * 0.4)
        if e1.x > e2.x { swap(&e1, &e2) }
        let roll = atan2(Double(e2.y - e1.y), Double(e2.x - e1.x)) * 180 / .pi
        func deg(_ n: NSNumber?) -> Double { abs((n?.doubleValue ?? 0) * 180 / .pi) }
        let eyeOpen = [lm?.leftEye, lm?.rightEye].compactMap { $0 }.map(PassportCheck.openness)
        let mouth = lm?.outerLips.map(PassportCheck.openness)
        let eyeY = (e1.y + e2.y) / 2
        // Until the head outline is read: the eye line sits close to the middle of the head.
        let crownY = chin.y - (chin.y - eyeY) * 2.12
        return Face(box: box, chin: chin, crown: CGPoint(x: chin.x, y: crownY), eyes: (e1, e2), crownMeasured: false,
                    roll: roll, yaw: deg(obs.yaw), pitch: deg(obs.pitch), eyeOpen: eyeOpen, mouth: mouth,
                    quality: quality.results?.first?.faceCaptureQuality, count: faces.count)
    }

    /// Keep the measured top of the head believable: on real heads it sits about 1.8–2.7× the eye-to-chin
    /// distance above the chin. Big hair or a hat reads taller; a cut-off head reads shorter. True if clamped.
    @discardableResult static func clampCrown(_ f: inout Face) -> Bool {
        let e2c = max(1, f.chin.y - f.eyeY)
        let ratio = (f.chin.y - f.crown.y) / e2c
        if ratio > 2.7 { f.crown.y = f.chin.y - e2c * 2.7; return true }
        if ratio < 1.8 { f.crown.y = f.chin.y - e2c * 2.12; f.crownMeasured = false; return true }
        return false
    }

    /// Person outline (hair and shoulders included), as an 8-bit mask.
    static func personMask(_ cg: CGImage) -> CVPixelBuffer? {
        let req = VNGeneratePersonSegmentationRequest()
        req.qualityLevel = .accurate
        req.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        guard (try? handler.perform([req])) != nil, let pb = req.results?.first?.pixelBuffer else { return nil }
        return pb
    }

    /// The top of the head: the first row, scanning down above the face, where the person outline covers
    /// most of a narrow band over the middle of the face.
    static func crownFromMask(_ pb: CVPixelBuffer, face: Face, height H: CGFloat, width W: CGFloat) -> CGPoint? {
        CVPixelBufferLockBaseAddress(pb, .readOnly); defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return nil }
        let mw = CVPixelBufferGetWidth(pb), mh = CVPixelBufferGetHeight(pb), row = CVPixelBufferGetBytesPerRow(pb)
        let p = base.assumingMemoryBound(to: UInt8.self)
        let sx = CGFloat(mw) / W, sy = CGFloat(mh) / H
        let half = face.box.width * 0.18
        let x0 = max(0, Int((face.centreX - half) * sx)), x1 = min(mw - 1, Int((face.centreX + half) * sx))
        let yEnd = min(mh - 1, Int(face.eyeY * sy))
        guard x1 > x0, yEnd > 0 else { return nil }
        for y in 0...yEnd {
            var on = 0
            for x in x0...x1 where p[y * row + x] > 127 { on += 1 }
            if Double(on) / Double(x1 - x0 + 1) > 0.5 {
                if y == 0 { return nil }      // the head runs off the top of the photo: can't measure it
                return CGPoint(x: face.centreX, y: CGFloat(y) / sy)
            }
        }
        return nil
    }

    // MARK: fixing

    /// Turn the photo about a point (the eyes), keeping its size; the corners turn see-through.
    static func rotate(_ cg: CGImage, degrees: Double, about p: CGPoint) -> CGImage? {
        let H = CGFloat(cg.height)
        let a = CGFloat(degrees * .pi / 180)
        let pivot = CGPoint(x: p.x, y: H - p.y)              // Core Image counts y from the bottom
        let t = CGAffineTransform(translationX: pivot.x, y: pivot.y).rotated(by: a).translatedBy(x: -pivot.x, y: -pivot.y)
        let out = CIImage(cgImage: cg).transformed(by: t)
        return context.createCGImage(out, from: CGRect(x: 0, y: 0, width: cg.width, height: cg.height), format: .RGBA8,
                                     colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    }

    /// Brighten the darker side of the face, fading to nothing across it, only on the person.
    static func evenOut(_ ci: CIImage, face: CGRect, height H: CGFloat, leftDark: Bool, ev: Double, mask: CVPixelBuffer?, size: CGSize) -> CIImage {
        let lifted = ci.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: ev])
        let y = H - face.midY
        let from = CIVector(x: leftDark ? face.minX : face.maxX, y: y)
        let to = CIVector(x: leftDark ? face.maxX - face.width * 0.2 : face.minX + face.width * 0.2, y: y)
        var ramp = CIFilter(name: "CILinearGradient", parameters: ["inputPoint0": from, "inputPoint1": to,
                                                                   "inputColor0": CIColor.white, "inputColor1": CIColor.black])?.outputImage?
            .cropped(to: CGRect(origin: .zero, size: size)) ?? CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
        if let m = scaledMask(mask, to: size) { ramp = ramp.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: m]) }
        return lifted.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: ci, kCIInputMaskImageKey: ramp])
    }

    /// The person over a flat colour, with the edge pulled in a touch and softened so hair blends.
    static func onPlain(_ ci: CIImage, mask: CVPixelBuffer, color: UIColor) -> CIImage {
        let size = ci.extent.size
        guard let m = scaledMask(mask, to: size) else { return ci }
        let r = max(1, min(size.width, size.height) / 700)
        let soft = m.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: r]).clampedToExtent()
            .applyingGaussianBlur(sigma: Double(r) * 0.9).cropped(to: ci.extent)
        let plain = CIImage(color: CIColor(color: color)).cropped(to: ci.extent)
        return ci.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: plain, kCIInputMaskImageKey: soft])
    }

    private static func scaledMask(_ pb: CVPixelBuffer?, to size: CGSize) -> CIImage? {
        guard let pb else { return nil }
        let m = CIImage(cvPixelBuffer: pb)
        guard m.extent.width > 0, m.extent.height > 0 else { return nil }
        return m.transformed(by: CGAffineTransform(scaleX: size.width / m.extent.width, y: size.height / m.extent.height))
    }

    /// Mean brightness of the left and right halves of the face, as seen in the image.
    static func halves(_ cg: CGImage, _ box: CGRect) -> (Double, Double)? {
        let b = box.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard b.width > 8, b.height > 8 else { return nil }
        return PassportCheck.halves(cg, b)
    }

    /// Where the face lands in the output, when the output can't be read again.
    private static func project(_ f: Face, s: CGFloat, dx: CGFloat, dy: CGFloat) -> Face {
        func m(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * s + dx, y: p.y * s + dy) }
        var g = f
        g.box = CGRect(x: f.box.minX * s + dx, y: f.box.minY * s + dy, width: f.box.width * s, height: f.box.height * s)
        g.chin = m(f.chin); g.crown = m(f.crown); g.eyes = (m(f.eyes.0), m(f.eyes.1))
        return g
    }
}
