import CoreImage
import UIKit
import Vision

/// Face & body fun for the Video Studio (26 Nov, Manan: "effects that make people laugh by changing the faces or body
/// … no half measures"). Every face in every frame is found on the phone with Vision's face landmarks (eyes, brows,
/// nose, lips, jaw), smoothed from frame to frame so nothing jitters, and the effect is built on those points: heads
/// reshaped with Core Image warp kernels (Engines/FaceWarps.ci.metal), stickers Tenzy draws itself placed on the face
/// and turning with it, skin changed only inside the face, moods that combine them. Playful effects only — never
/// described as "AI", a deepfake or a face swap. Nothing leaves the phone.
enum FaceFun {
    enum Group: String, CaseIterable, Identifiable {
        case heads = "Heads", warps = "Warps", stickers = "Stickers", skin = "Skin & colour", moods = "Moods", body = "Body"
        var id: String { rawValue }
    }

    struct Effect: Identifiable, Equatable {
        let id: String, name: String, emoji: String, group: Group
    }

    static let effects: [Effect] = [
        // Bald was taken out on 27 Nov: on real home video it never reached the bar (Manan's call). Its code stays,
        // unlisted, in case a trained model makes it good one day.
        Effect(id: "cone", name: "Cone head", emoji: "🍦", group: .heads),
        Effect(id: "egg", name: "Egg head", emoji: "🥚", group: .heads),
        Effect(id: "balloon", name: "Balloon face", emoji: "🎈", group: .heads),
        Effect(id: "bighead", name: "Big head", emoji: "🎃", group: .heads),
        Effect(id: "tinyhead", name: "Tiny head", emoji: "🐜", group: .heads),

        Effect(id: "bigmouth", name: "Big mouth", emoji: "👄", group: .warps),
        Effect(id: "bigeyes", name: "Big eyes", emoji: "👀", group: .warps),
        Effect(id: "tinyface", name: "Tiny face", emoji: "🤏", group: .warps),
        Effect(id: "squish", name: "Squished", emoji: "🫓", group: .warps),
        Effect(id: "pinch", name: "Pinched", emoji: "🍐", group: .warps),
        Effect(id: "longchin", name: "Long chin", emoji: "🌙", group: .warps),
        Effect(id: "chipmunk", name: "Chipmunk cheeks", emoji: "🐿️", group: .warps),
        Effect(id: "stretchy", name: "Stretchy face", emoji: "🫠", group: .warps),
        Effect(id: "wobbly", name: "Wobbly face", emoji: "🌀", group: .warps),

        Effect(id: "sunglasses", name: "Cool shades", emoji: "🕶️", group: .stickers),
        Effect(id: "heartglasses", name: "Heart glasses", emoji: "😍", group: .stickers),
        Effect(id: "crown", name: "Crown", emoji: "👑", group: .stickers),
        Effect(id: "moustache", name: "Moustache", emoji: "🥸", group: .stickers),
        Effect(id: "dog", name: "Puppy", emoji: "🐶", group: .stickers),
        Effect(id: "bunny", name: "Bunny", emoji: "🐰", group: .stickers),
        Effect(id: "clown", name: "Clown nose", emoji: "🤡", group: .stickers),
        Effect(id: "halo", name: "Halo", emoji: "😇", group: .stickers),
        Effect(id: "devil", name: "Devil horns", emoji: "😈", group: .stickers),
        Effect(id: "partyhat", name: "Party hat", emoji: "🥳", group: .stickers),
        Effect(id: "flowers", name: "Flower crown", emoji: "🌸", group: .stickers),

        // Alien, Zombie, Robot, Glow, Beautiful and Wholesome (the face repaints) were taken out on 27 Nov with Bald:
        // hand-built, they looked cheap on real home video (Manan's call). Their code stays, unlisted.
        Effect(id: "cartoon", name: "Cartoon", emoji: "🎨", group: .moods),
        Effect(id: "sunny", name: "Seriously sunny", emoji: "☀️", group: .moods),
        Effect(id: "tacky", name: "Tacky", emoji: "💎", group: .moods),

        Effect(id: "longlegs", name: "Long legs", emoji: "🦵", group: .body),
        Effect(id: "tinybody", name: "Big head, tiny body", emoji: "🧸", group: .body),
    ]

    static func effect(_ id: String) -> Effect? { effects.first { $0.id == id } }

    // MARK: - Faces

    /// One face, in the frame's own points (Core Image: origin bottom left, y up), with what the effects are built on.
    struct Face: Equatable {
        var contour: [CGPoint]          // the jaw line, ear to ear through the chin
        var eyeA: CGPoint, eyeB: CGPoint // the eye on the picture's left, and on its right
        var eyePtsA: [CGPoint], eyePtsB: [CGPoint]
        var lips: [CGPoint]
        var brow: CGPoint               // the middle of the brow line
        var nose: CGPoint               // the tip of the nose
        var mouth: CGPoint              // the middle of the lips
        var mouthWidth: CGFloat
        var chin: CGPoint
        var cheekA: CGPoint, cheekB: CGPoint
        var roll: CGFloat               // how far the head is tilted (radians)
        var up: CGVector                // from the chin toward the top of the head
        var width: CGFloat              // cheek to cheek
        var height: CGFloat             // brows to chin
        var eyeDistance: CGFloat

        /// Across the face, toward the picture's right when the head is upright.
        var side: CGVector { CGVector(dx: up.dy, dy: -up.dx) }
        /// The middle of the face (between the eyes and the mouth).
        var center: CGPoint { CGPoint(x: (eyeA.x + eyeB.x) / 4 + mouth.x / 2, y: (eyeA.y + eyeB.y) / 4 + mouth.y / 2) }
        /// Just above the hair: where a hat sits.
        var top: CGPoint { point(brow, up: height * 0.92) }
        /// A point `up` along the face's up direction and `across` along its side, from `p`.
        func point(_ p: CGPoint, up u: CGFloat = 0, across s: CGFloat = 0) -> CGPoint {
            CGPoint(x: p.x + up.dx * u + side.dx * s, y: p.y + up.dy * u + side.dy * s)
        }
    }

    static func dot(_ a: CGPoint, _ v: CGVector) -> CGFloat { a.x * v.dx + a.y * v.dy }
    static func mid(_ p: [CGPoint]) -> CGPoint {
        guard !p.isEmpty else { return .zero }
        return CGPoint(x: p.map(\.x).reduce(0, +) / CGFloat(p.count), y: p.map(\.y).reduce(0, +) / CGFloat(p.count))
    }

    /// The faces in a frame, biggest first (at most three).
    static func faces(in img: CIImage) -> [Face] {
        faces(in: img, boxes: nil)
    }

    /// The faces, and (for the tests) each one's box as the finder gave it, in the frame's points.
    ///
    /// 27 Nov: on the build machine the finder's landmark points (eyes, mouth, jaw) came back different every time it
    /// was asked about the same picture — drifting outward until they were thousands of faces wide — in every way of
    /// asking (each model revision, CPU only, with the box given), while the face box stayed the same. So the box is
    /// what's trusted: the landmarks are used only when they sit sensibly inside it, and otherwise the face is laid out
    /// from the box and its tilt with ordinary face proportions.
    static func faces(in img: CIImage, boxes: ((CGRect) -> Void)?) -> [Face] {
        let req = VNDetectFaceLandmarksRequest()
        try? VNImageRequestHandler(ciImage: img, options: [:]).perform([req])
        let W = img.extent.width, H = img.extent.height, origin = img.extent.origin
        let frame = img.extent
        return (req.results ?? []).filter { $0.confidence > 0.5 }
            .compactMap { o -> Face? in
                let box = CGRect(x: origin.x + o.boundingBox.minX * W, y: origin.y + o.boundingBox.minY * H,
                                 width: o.boundingBox.width * W, height: o.boundingBox.height * H)
                boxes?(box)
                guard box.width > 2, box.height > 2, frame.insetBy(dx: -frame.width * 0.5, dy: -frame.height * 0.5).contains(box) else { return nil }
                let roll = CGFloat(o.roll?.doubleValue ?? 0)
                guard let lm = o.landmarks, sensible(lm) else { return face(box: box, roll: roll) }
                func pts(_ r: VNFaceLandmarkRegion2D?) -> [CGPoint] {
                    (r?.normalizedPoints ?? []).map { CGPoint(x: box.minX + $0.x * box.width, y: box.minY + $0.y * box.height) }
                }
                return face(contour: pts(lm.faceContour), eyeA: pts(lm.leftEye), eyeB: pts(lm.rightEye),
                            brows: pts(lm.leftEyebrow) + pts(lm.rightEyebrow), nose: pts(lm.nose) + pts(lm.noseCrest), lips: pts(lm.outerLips))
                    ?? face(box: box, roll: roll)
            }
            .sorted { $0.width > $1.width }
            .prefix(3).map { $0 }
    }

    /// Whether the landmark points sit sensibly inside their face box (shares of it): the jaw spans most of the box,
    /// nothing is far outside it, and the eyes sit above the mouth.
    static func sensible(_ lm: VNFaceLandmarks2D) -> Bool {
        guard let c = lm.faceContour?.normalizedPoints, c.count >= 5,
              let ea = lm.leftEye?.normalizedPoints, let eb = lm.rightEye?.normalizedPoints, !ea.isEmpty, !eb.isEmpty else { return false }
        return sensible(contour: c, eyes: ea + eb, lips: lm.outerLips?.normalizedPoints ?? [])
    }

    /// Pure, so it's tested with made-up points.
    static func sensible(contour c: [CGPoint], eyes: [CGPoint], lips: [CGPoint]) -> Bool {
        let all = c + eyes + lips
        // A real jaw spans about nine tenths of the box and both eyes about half of it (round 16: drifting points that
        // still passed a looser check read the same face 222 to 433 wide).
        guard all.allSatisfy({ $0.x > -0.12 && $0.x < 1.12 && $0.y > -0.12 && $0.y < 1.12 }) else { return false }
        let xs = c.map(\.x), across = (xs.max() ?? 0) - (xs.min() ?? 0)
        guard across > 0.78, across < 1.08 else { return false }
        let eyeSpan = (eyes.map(\.x).max() ?? 0) - (eyes.map(\.x).min() ?? 0)
        return eyeSpan > 0.3 && eyeSpan < 0.68
    }

    /// A face laid out from its box and tilt with ordinary proportions (the box runs from the brows to the chin).
    static func face(box: CGRect, roll: CGFloat) -> Face? {
        let s = min(box.width, box.height), c = CGPoint(x: box.midX, y: box.midY)
        // Vision's roll turns the face clockwise for positive values in a top-left picture; in Core Image's y-up frame
        // that is the other way round.
        let a = -roll
        func at(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
            CGPoint(x: c.x + (u * cos(a) - v * sin(a)) * s, y: c.y + (u * sin(a) + v * cos(a)) * s)
        }
        func oval(_ u: CGFloat, _ v: CGFloat, _ ru: CGFloat, _ rv: CGFloat, _ n: Int = 8) -> [CGPoint] {
            (0..<n).map { k in let t = CGFloat(k) * 2 * .pi / CGFloat(n); return at(u + cos(t) * ru, v + sin(t) * rv) }
        }
        let contour = (0...10).map { k -> CGPoint in
            let t = CGFloat.pi * (1 + CGFloat(k) / 10)
            return at(cos(t) * 0.46, 0.1 + sin(t) * 0.58)
        }
        return face(contour: contour, eyeA: oval(-0.2, 0.12, 0.075, 0.035), eyeB: oval(0.2, 0.12, 0.075, 0.035),
                    brows: [at(-0.2, 0.25), at(0.2, 0.25)], nose: [at(0, 0.08), at(0, -0.08)], lips: oval(0, -0.27, 0.18, 0.06, 10))
    }

    /// A face from its landmark points. Pure, so it's tested with made-up points.
    static func face(contour: [CGPoint], eyeA ea: [CGPoint], eyeB eb: [CGPoint], brows: [CGPoint], nose noseP: [CGPoint], lips: [CGPoint]) -> Face? {
        guard contour.count >= 5, !ea.isEmpty, !eb.isEmpty else { return nil }
        var pa = ea, pb = eb
        var a = mid(pa), b = mid(pb)
        if a.x > b.x { swap(&a, &b); swap(&pa, &pb) }
        let eyeDistance = hypot(b.x - a.x, b.y - a.y)
        guard eyeDistance > 2 else { return nil }
        let roll = atan2(b.y - a.y, b.x - a.x)
        var up = CGVector(dx: -sin(roll), dy: cos(roll))
        let eyes = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let mouth = lips.isEmpty ? CGPoint(x: eyes.x - up.dx * eyeDistance * 1.1, y: eyes.y - up.dy * eyeDistance * 1.1) : mid(lips)
        // "Up" points from the mouth toward the eyes, whichever way the head is turned.
        if dot(CGPoint(x: eyes.x - mouth.x, y: eyes.y - mouth.y), up) < 0 { up = CGVector(dx: -up.dx, dy: -up.dy) }
        let brow = brows.isEmpty ? CGPoint(x: eyes.x + up.dx * eyeDistance * 0.3, y: eyes.y + up.dy * eyeDistance * 0.3) : mid(brows)
        let chin = contour.min { dot($0, up) < dot($1, up) } ?? mouth
        let height = max(eyeDistance, dot(CGPoint(x: brow.x - chin.x, y: brow.y - chin.y), up))
        let side = CGVector(dx: up.dy, dy: -up.dx)
        let across = contour.map { dot(CGPoint(x: $0.x - eyes.x, y: $0.y - eyes.y), side) }
        let width = max(eyeDistance * 1.9, (across.max() ?? 0) - (across.min() ?? 0))
        let cheekA = contour.min { dot($0, side) < dot($1, side) } ?? a
        let cheekB = contour.max { dot($0, side) < dot($1, side) } ?? b
        let nose = noseP.min { dot($0, up) < dot($1, up) } ?? CGPoint(x: (eyes.x + mouth.x) / 2, y: (eyes.y + mouth.y) / 2)
        let lipAcross = lips.map { dot($0, side) }
        let mouthWidth = lips.isEmpty ? eyeDistance * 0.9 : max(eyeDistance * 0.5, (lipAcross.max() ?? 0) - (lipAcross.min() ?? 0))
        return Face(contour: contour, eyeA: a, eyeB: b, eyePtsA: pa, eyePtsB: pb, lips: lips, brow: brow, nose: nose, mouth: mouth,
                    mouthWidth: mouthWidth, chin: chin, cheekA: cheekA, cheekB: cheekB, roll: roll, up: up, width: width, height: height,
                    eyeDistance: eyeDistance)
    }

    /// Each new face moved `keep` of the way back toward where it was last frame, so the effects sit still instead of
    /// trembling with the detector. A face that wasn't there before (or moved a lot) is taken as found.
    static func smoothed(_ new: [Face], previous: [Face], keep: CGFloat = 0.45) -> [Face] {
        new.map { n in
            guard let o = previous.min(by: { hypot($0.center.x - n.center.x, $0.center.y - n.center.y) < hypot($1.center.x - n.center.x, $1.center.y - n.center.y) }),
                  hypot(o.center.x - n.center.x, o.center.y - n.center.y) < n.width * 0.35 else { return n }
            func l(_ x: CGFloat, _ y: CGFloat) -> CGFloat { y + (x - y) * keep }
            func p(_ x: CGPoint, _ y: CGPoint) -> CGPoint { CGPoint(x: l(x.x, y.x), y: l(x.y, y.y)) }
            func ps(_ x: [CGPoint], _ y: [CGPoint]) -> [CGPoint] { x.count == y.count ? zip(x, y).map { p($0, $1) } : y }
            var f = n
            f.eyeA = p(o.eyeA, n.eyeA); f.eyeB = p(o.eyeB, n.eyeB); f.brow = p(o.brow, n.brow); f.nose = p(o.nose, n.nose)
            f.mouth = p(o.mouth, n.mouth); f.chin = p(o.chin, n.chin); f.cheekA = p(o.cheekA, n.cheekA); f.cheekB = p(o.cheekB, n.cheekB)
            f.contour = ps(o.contour, n.contour); f.lips = ps(o.lips, n.lips); f.eyePtsA = ps(o.eyePtsA, n.eyePtsA); f.eyePtsB = ps(o.eyePtsB, n.eyePtsB)
            f.width = l(o.width, n.width); f.height = l(o.height, n.height); f.mouthWidth = l(o.mouthWidth, n.mouthWidth)
            f.eyeDistance = l(o.eyeDistance, n.eyeDistance)
            let dr = atan2(sin(o.roll - n.roll), cos(o.roll - n.roll))
            f.roll = n.roll + dr * keep
            let upSign: CGFloat = (n.up.dy * cos(n.roll) - n.up.dx * sin(n.roll)) >= 0 ? 1 : -1
            f.up = CGVector(dx: -sin(f.roll) * upSign, dy: cos(f.roll) * upSign)
            return f
        }
    }

    // MARK: - Bodies

    /// Where a person's hips and neck are (for long legs and a tiny body), from Vision's body pose. nil if no body.
    struct Body: Equatable { var hips: CGPoint; var neck: CGPoint; var ankles: CGPoint? }

    static func body(in img: CIImage) -> Body? {
        let req = VNDetectHumanBodyPoseRequest()
        try? VNImageRequestHandler(ciImage: img, options: [:]).perform([req])
        guard let o = req.results?.first, let pts = try? o.recognizedPoints(.all) else { return nil }
        let W = img.extent.width, H = img.extent.height
        func at(_ j: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let p = pts[j], p.confidence > 0.3 else { return nil }
            return CGPoint(x: img.extent.minX + p.location.x * W, y: img.extent.minY + p.location.y * H)
        }
        let hipsL = at(.leftHip), hipsR = at(.rightHip)
        guard let neck = at(.neck), let hl = hipsL ?? hipsR, let hr = hipsR ?? hipsL else { return nil }
        let hips = CGPoint(x: (hl.x + hr.x) / 2, y: (hl.y + hr.y) / 2)
        let ankles = [at(.leftAnkle), at(.rightAnkle)].compactMap { $0 }
        return Body(hips: hips, neck: neck, ankles: ankles.isEmpty ? nil : mid(ankles))
    }

    // MARK: - Warps (FaceWarps.ci.metal, with Core Image's own filters if the kernels can't load)

    static let library: Data? = Bundle.main.url(forResource: "default", withExtension: "metallib").flatMap { try? Data(contentsOf: $0) }
    private static let bulgeKernel: CIWarpKernel? = library.flatMap { try? CIWarpKernel(functionName: "tenzyBulge", fromMetalLibraryData: $0) }
    private static let coneKernel: CIWarpKernel? = library.flatMap { try? CIWarpKernel(functionName: "tenzyCone", fromMetalLibraryData: $0) }
    private static let bandKernel: CIWarpKernel? = library.flatMap { try? CIWarpKernel(functionName: "tenzyBand", fromMetalLibraryData: $0) }
    /// Whether the warp kernels loaded (the tests check it: without them the effects fall back to plainer filters).
    static var kernelsLoaded: Bool { bulgeKernel != nil && coneKernel != nil && bandKernel != nil }

    /// An oval swelling (positive strength) or shrinking (negative) around `c`, each axis with its own strength.
    static func bulge(_ img: CIImage, at c: CGPoint, radii: CGSize, angle: CGFloat, strength: CGVector) -> CIImage {
        let extent = img.extent
        guard let k = bulgeKernel else {
            return img.applyingFilter("CIBumpDistortion", parameters: [kCIInputCenterKey: CIVector(cgPoint: c),
                kCIInputRadiusKey: max(radii.width, radii.height), kCIInputScaleKey: (strength.dx + strength.dy) / 2]).cropped(to: extent)
        }
        return k.apply(extent: extent, roiCallback: { _, _ in extent }, image: img.clampedToExtent(), arguments: [
            CIVector(cgPoint: c), CIVector(x: radii.width, y: radii.height), angle, CIVector(x: strength.dx, y: strength.dy),
        ])?.cropped(to: extent) ?? img
    }

    /// The head drawn up taller above the brows, and narrowed to a point when `point` > 0.
    static func cone(_ img: CIImage, _ f: Face, stretch: CGFloat, point: CGFloat) -> CIImage {
        guard coneKernel != nil else {
            return bulge(img, at: f.point(f.brow, up: f.height * 0.7), radii: CGSize(width: f.width * 0.6, height: f.height), angle: f.roll,
                         strength: CGVector(dx: -0.2, dy: stretch * 0.5))
        }
        return drawnUp(img, from: f.brow, up: f.up, height: f.height * 0.98, halfWidth: f.width * 0.56, stretch: stretch, point: point)
    }

    /// The band `height` tall above `base` (along `up`, `halfWidth` either side) drawn `1 + stretch` times as tall.
    static func drawnUp(_ img: CIImage, from base: CGPoint, up: CGVector, height: CGFloat, halfWidth: CGFloat, stretch: CGFloat, point: CGFloat = 0) -> CIImage {
        let extent = img.extent
        guard let k = coneKernel else { return img }
        return k.apply(extent: extent, roiCallback: { _, _ in extent }, image: img.clampedToExtent(), arguments: [
            CIVector(cgPoint: base), CIVector(x: up.dx, y: up.dy), height, halfWidth, stretch, point,
        ])?.cropped(to: extent) ?? img
    }

    /// The band that starts at `line` and runs `length` along `dir`, drawn `k` times as long; what's beyond it moves along.
    static func band(_ img: CIImage, line: CGPoint, dir: CGVector, length: CGFloat, k: CGFloat) -> CIImage {
        let extent = img.extent
        guard let kern = bandKernel else { return img }
        return kern.apply(extent: extent, roiCallback: { _, _ in extent }, image: img.clampedToExtent(), arguments: [
            CIVector(cgPoint: line), CIVector(x: dir.dx, y: dir.dy), length, k,
        ])?.cropped(to: extent) ?? img
    }

    // MARK: - Masks

    /// A soft mask of the face's skin: the jaw line, up over the forehead to `forehead` × the face height above the
    /// brows. With `holes`, the eyes and the mouth are left out (so skin effects never smear them).
    static func faceMask(_ f: Face, rect: CGRect, forehead: CGFloat = 0.55, holes: Bool = false, feather: CGFloat = 0.06) -> CIImage {
        let w = Int(rect.width.rounded()), h = Int(rect.height.rounded())
        guard w > 0, h > 0, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return CIImage(color: .black).cropped(to: rect)
        }
        func local(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - rect.minX, y: p.y - rect.minY) }
        // The jaw line as Vision gives it (ear, round the chin, to the other ear), then up and over the forehead.
        let path = CGMutablePath()
        if let first = f.contour.first, let last = f.contour.last {
            path.move(to: local(first))
            for p in f.contour.dropFirst() { path.addLine(to: local(p)) }
            let sgn: CGFloat = dot(CGPoint(x: last.x - f.brow.x, y: last.y - f.brow.y), f.side) >= 0 ? 1 : -1
            let topY = f.height * forehead
            path.addCurve(to: local(f.point(f.brow, up: topY)), control1: local(f.point(last, up: topY * 0.75)),
                          control2: local(f.point(f.brow, up: topY, across: sgn * f.width * 0.42)))
            path.addCurve(to: local(first), control1: local(f.point(f.brow, up: topY, across: -sgn * f.width * 0.42)),
                          control2: local(f.point(first, up: topY * 0.75)))
            path.closeSubpath()
        }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.addPath(path); ctx.fillPath()
        if holes {
            ctx.setFillColor(gray: 0, alpha: 1)
            for poly in [f.eyePtsA, f.eyePtsB, f.lips] where poly.count >= 3 {
                let c = mid(poly)
                let grown = poly.map { CGPoint(x: c.x + ($0.x - c.x) * 1.35, y: c.y + ($0.y - c.y) * 1.35) }
                ctx.beginPath(); ctx.move(to: local(grown[0])); for p in grown.dropFirst() { ctx.addLine(to: local(p)) }; ctx.closePath(); ctx.fillPath()
            }
        }
        guard let cg = ctx.makeImage() else { return CIImage(color: .black).cropped(to: rect) }
        let m = CIImage(cgImage: cg).transformed(by: CGAffineTransform(translationX: rect.minX, y: rect.minY))
        return m.clampedToExtent().applyingGaussianBlur(sigma: Double(f.width * feather)).cropped(to: rect)
    }

    /// A soft round mask (1 in the middle, 0 past `radius`).
    static func spot(_ c: CGPoint, radius: CGFloat, inner: CGFloat = 0.55, rect: CGRect) -> CIImage {
        CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(cgPoint: c), "inputRadius0": radius * inner, "inputRadius1": radius,
            "inputColor0": CIColor(red: 1, green: 1, blue: 1), "inputColor1": CIColor(red: 0, green: 0, blue: 0),
        ])?.outputImage?.cropped(to: rect) ?? CIImage(color: .black).cropped(to: rect)
    }

    /// `top` over `img` where `mask` is white.
    static func blend(_ top: CIImage, over img: CIImage, mask: CIImage) -> CIImage {
        top.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: img, kCIInputMaskImageKey: mask]).cropped(to: img.extent)
    }

    /// The average colour inside `r` (the skin's colour, sampled on the forehead).
    static func average(_ img: CIImage, in r: CGRect) -> CIColor {
        let ctx = shared
        guard let out = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: img, kCIInputExtentKey: CIVector(cgRect: r.intersection(img.extent))])?.outputImage
        else { return CIColor(red: 0.85, green: 0.68, blue: 0.58) }
        var px = [UInt8](repeating: 0, count: 4)
        ctx.render(out, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return CIColor(red: CGFloat(px[0]) / 255, green: CGFloat(px[1]) / 255, blue: CGFloat(px[2]) / 255)
    }

    static let shared = CIContext(options: [.cacheIntermediates: false])
}
