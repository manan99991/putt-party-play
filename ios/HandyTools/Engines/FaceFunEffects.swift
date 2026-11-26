import CoreImage
import UIKit

/// What each Face fun effect does to a frame (26 Nov). Colour and skin first, on the picture as filmed (so the masks
/// sit exactly on the face Vision found), then the warps, then the stickers on top.
extension FaceFun {
    /// What was found in a frame.
    struct Scene {
        var faces: [Face] = []
        var body: Body?
        /// Where the person is (1 = person), the frame's size; nil if not asked for or none.
        var person: CIImage?
    }

    /// What's kept from frame to frame so the effects sit still.
    final class Memory: @unchecked Sendable {
        var faces: [Face] = []
        var body: Body?
        var skin: [CIColor] = []
        var t = -10.0
        let lock = NSLock()
    }

    static func needsBody(_ id: String) -> Bool { id == "longlegs" }
    static func needsPerson(_ id: String) -> Bool { id == "bald" }

    /// The faces (steadied against the last frame's) and, when the effect needs them, the body and the person's outline.
    static func scene(_ img: CIImage, for id: String, t: Double, memory: Memory, person: @autoclosure () -> CIImage?) -> Scene {
        var found = faces(in: img)
        var b = needsBody(id) ? body(in: img) : nil
        memory.lock.lock()
        let near = abs(t - memory.t) < 0.6
        if found.isEmpty, near { found = memory.faces }                      // the finder blinked: keep the effect on
        else if !found.isEmpty {
            found = near ? smoothed(found, previous: memory.faces) : found
            memory.faces = found; memory.t = t
        }
        if needsBody(id) {
            if let new = b, let old = memory.body, near {
                func l(_ o: CGPoint, _ n: CGPoint) -> CGPoint { CGPoint(x: n.x + (o.x - n.x) * 0.6, y: n.y + (o.y - n.y) * 0.6) }
                b = Body(hips: l(old.hips, new.hips), neck: l(old.neck, new.neck), ankles: new.ankles.map { n in old.ankles.map { l($0, n) } ?? n })
            } else if b == nil, near { b = memory.body }
            if b != nil { memory.body = b }
        }
        memory.lock.unlock()
        return Scene(faces: found, body: b, person: needsPerson(id) && !found.isEmpty ? person() : nil)
    }

    // MARK: - One frame

    /// `id` on every face in `scene`. `amount` 0…1 is how far to take it; `t` (seconds) makes a few of them move.
    static func apply(_ id: String, to img: CIImage, scene: Scene, t: Double, amount: Double, memory: Memory? = nil) -> CIImage {
        let rect = img.extent
        let a = CGFloat(min(1, max(0, amount))), tt = CGFloat(t)
        func s(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { lo + (hi - lo) * a }
        func both(_ v: CGFloat) -> CGVector { CGVector(dx: v, dy: v) }
        switch id {
        case "cartoon": return cartoon(img, a)
        case "longlegs": return longLegs(img, scene, a)
        default: break
        }
        var out = img
        // 1. Colour and skin, on the faces where Vision found them.
        for (i, f) in scene.faces.enumerated() {
            switch id {
            case "bald": out = bald(out, f, person: scene.person, index: i, memory: memory)
            case "alien":
                let skin = faceMask(f, rect: around(f, rect), forehead: 0.9, holes: true)
                let green = out.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.45])
                    .applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0.6, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 1.0, z: 0, w: 0),
                                                                  "inputBVector": CIVector(x: 0, y: 0, z: 0.66, w: 0)])
                out = blend(green, over: out, mask: dim(skin, s(0.6, 0.95)))
                for e in [f.eyeA, f.eyeB] {
                    let dark = out.applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: -0.35, kCIInputContrastKey: 1.2])
                    out = blend(dark, over: out, mask: dim(spot(e, radius: f.eyeDistance * 0.34, inner: 0.5, rect: rect), 0.8))
                }
            case "zombie":
                let skin = faceMask(f, rect: around(f, rect), forehead: 0.62, holes: true)
                let dead = out.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.3, kCIInputContrastKey: 1.18])
                    .applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0.74, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0.95, z: 0, w: 0),
                                                                  "inputBVector": CIVector(x: 0, y: 0, z: 0.72, w: 0)])
                out = blend(dead, over: out, mask: dim(skin, s(0.65, 0.97)))
                // Sunken eyes: dark, a little purple, round each eye but not on the eye itself.
                let sunk = out.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0.42, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0.3, z: 0, w: 0),
                                                                           "inputBVector": CIVector(x: 0, y: 0, z: 0.46, w: 0)])
                for e in [f.eyeA, f.eyeB] {
                    let ring = spot(e, radius: f.eyeDistance * 0.46, inner: 0.35, rect: rect)
                        .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: skin]).cropped(to: rect)
                    out = blend(sunk, over: out, mask: dim(ring, s(0.55, 0.85)))
                }
            case "robot":
                let skin = faceMask(f, rect: around(f, rect), forehead: 0.7, holes: true)
                let steel = out.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.35])
                    .applyingFilter("CIColorPosterize", parameters: ["inputLevels": 7])
                    .applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0.74, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0.86, z: 0, w: 0),
                                                                  "inputBVector": CIVector(x: 0, y: 0, z: 1.04, w: 0)])
                out = blend(steel, over: out, mask: dim(skin, s(0.7, 1)))
                for e in [f.eyeA, f.eyeB] {
                    let pulse = 0.75 + 0.25 * sin(tt * 4)
                    out = glow(out, at: e, radius: f.eyeDistance * 0.36, colour: CIColor(red: 0.2, green: 0.95, blue: 1), strength: pulse * s(0.6, 0.95))
                }
            case "glow": out = smoothSkin(out, f, s(0.4, 0.75))
            case "beautiful":
                out = smoothSkin(out, f, s(0.35, 0.7))
                // Brighter eyes, a touch more colour on the lips.
                let eyes = polyMask([f.eyePtsA, f.eyePtsB], grow: 1.25, feather: f.eyeDistance * 0.03, rect: around(f, rect))
                out = blend(out.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: s(0.2, 0.42)]), over: out, mask: eyes)
                let lips = polyMask([f.lips], grow: 1.0, feather: f.eyeDistance * 0.03, rect: around(f, rect))
                out = blend(out.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: s(1.25, 1.6)]), over: out, mask: dim(lips, 0.8))
            case "wholesome":
                out = smoothSkin(out, f, s(0.25, 0.5))
                for c in [f.cheekA, f.cheekB] {
                    let p = CGPoint(x: c.x * 0.62 + f.nose.x * 0.38, y: c.y * 0.62 + f.nose.y * 0.38)
                    out = tint(out, at: p, radius: f.width * 0.2, colour: CIColor(red: 1, green: 0.42, blue: 0.5), strength: s(0.3, 0.5))
                }
            default: break
            }
        }
        // 2. The warps.
        for f in scene.faces {
            let c = f.center
            switch id {
            case "bighead": out = bulge(out, at: f.point(c, up: f.height * 0.12), radii: CGSize(width: f.width * 1.15, height: f.height * 1.35), angle: f.roll, strength: both(s(0.3, 0.6)))
            case "tinyhead": out = bulge(out, at: f.point(c, up: f.height * 0.12), radii: CGSize(width: f.width * 1.05, height: f.height * 1.25), angle: f.roll, strength: both(-s(0.5, 1.1)))
            case "balloon":
                let puff = s(0.42, 0.66) * (1 + 0.06 * sin(tt * 2.4))
                out = bulge(out, at: f.point(c, up: f.height * 0.05), radii: CGSize(width: f.width * 1.08, height: f.height * 1.22), angle: f.roll, strength: both(puff))
            case "cone": out = cone(out, f, stretch: s(0.5, 1.0), point: s(0.6, 1.0))
            case "egg": out = cone(out, f, stretch: s(0.35, 0.7), point: 0.22)
            case "alien":
                out = bulge(out, at: f.point(f.brow, up: f.height * 0.35), radii: CGSize(width: f.width * 0.95, height: f.height * 0.95), angle: f.roll, strength: both(s(0.3, 0.5)))
                out = bulge(out, at: f.point(f.mouth, up: -f.height * 0.1), radii: CGSize(width: f.width * 0.6, height: f.height * 0.55), angle: f.roll, strength: CGVector(dx: -s(0.5, 0.9), dy: 0))
                for e in [f.eyeA, f.eyeB] {
                    out = bulge(out, at: e, radii: CGSize(width: f.eyeDistance * 0.46, height: f.eyeDistance * 0.38), angle: f.roll, strength: both(s(0.4, 0.6)))
                }
            case "bigmouth":
                out = bulge(out, at: f.mouth, radii: CGSize(width: f.mouthWidth * 1.25, height: f.mouthWidth * 0.95), angle: f.roll, strength: both(s(0.4, 0.68)))
            case "bigeyes":
                for e in [f.eyeA, f.eyeB] {
                    out = bulge(out, at: e, radii: CGSize(width: f.eyeDistance * 0.46, height: f.eyeDistance * 0.46), angle: f.roll, strength: both(s(0.4, 0.66)))
                }
            case "tinyface": out = bulge(out, at: c, radii: CGSize(width: f.width * 0.62, height: f.height * 0.72), angle: f.roll, strength: both(-s(0.6, 1.15)))
            case "squish":
                out = bulge(out, at: c, radii: CGSize(width: f.width * 1.1, height: f.height * 1.2), angle: f.roll, strength: CGVector(dx: s(0.3, 0.5), dy: -s(0.5, 1.0)))
            case "pinch":
                out = bulge(out, at: f.point(f.brow, up: f.height * 0.1), radii: CGSize(width: f.width * 0.85, height: f.height * 0.7), angle: f.roll, strength: CGVector(dx: -s(0.5, 1.0), dy: 0))
                out = bulge(out, at: f.point(f.mouth, up: -f.height * 0.05), radii: CGSize(width: f.width * 0.8, height: f.height * 0.6), angle: f.roll, strength: CGVector(dx: s(0.3, 0.5), dy: 0))
            case "longchin":
                out = bulge(out, at: f.point(f.mouth, up: -f.height * 0.2), radii: CGSize(width: f.width * 0.5, height: f.height * 0.7), angle: f.roll, strength: CGVector(dx: -0.1, dy: s(0.45, 0.72)))
            case "chipmunk":
                for ch in [f.cheekA, f.cheekB] {
                    let p = f.point(CGPoint(x: f.mouth.x + (ch.x - f.mouth.x) * 0.62, y: f.mouth.y + (ch.y - f.mouth.y) * 0.62), up: f.height * 0.05)
                    out = bulge(out, at: p, radii: CGSize(width: f.width * 0.34, height: f.width * 0.34), angle: f.roll, strength: both(s(0.4, 0.66)))
                }
            case "stretchy":
                out = bulge(out, at: c, radii: CGSize(width: f.width * 1.0, height: f.height * 1.35), angle: f.roll, strength: CGVector(dx: -0.25, dy: s(0.4, 0.62) + 0.06 * sin(tt * 3)))
            case "wobbly":
                let twirled = out.applyingFilter("CITwirlDistortion", parameters: [kCIInputCenterKey: CIVector(cgPoint: c), kCIInputRadiusKey: f.width * 0.95,
                                                                                    kCIInputAngleKey: (0.35 + 0.7 * a) * sin(tt * 5)])
                out = twirled.cropped(to: rect)
            case "tinybody":
                // The head swells; what's under it (found from the face: about a head and a half below the chin) is drawn in.
                out = bulge(out, at: f.point(f.chin, up: -f.height * 1.75), radii: CGSize(width: f.width * 1.7, height: f.height * 1.75), angle: f.roll,
                            strength: CGVector(dx: -s(0.55, 1.1), dy: -s(0.2, 0.45)))
                out = bulge(out, at: f.point(c, up: f.height * 0.15), radii: CGSize(width: f.width * 1.2, height: f.height * 1.4), angle: f.roll, strength: both(s(0.4, 0.64)))
            case "beautiful": for e in [f.eyeA, f.eyeB] { out = bulge(out, at: e, radii: CGSize(width: f.eyeDistance * 0.44, height: f.eyeDistance * 0.44), angle: f.roll, strength: both(s(0.08, 0.2))) }
            case "wholesome": for e in [f.eyeA, f.eyeB] { out = bulge(out, at: e, radii: CGSize(width: f.eyeDistance * 0.44, height: f.eyeDistance * 0.44), angle: f.roll, strength: both(s(0.1, 0.24))) }
            default: break
            }
        }
        // 3. The whole picture's mood, under the stickers.
        switch id {
        case "glow": out = out.applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: min(rect.width, rect.height) * 0.02, kCIInputIntensityKey: s(0.25, 0.6)]).cropped(to: rect)
        case "beautiful":
            out = out.applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: min(rect.width, rect.height) * 0.015, kCIInputIntensityKey: s(0.15, 0.35)]).cropped(to: rect)
                .applyingFilter("CIColorMatrix", parameters: warm(s(0.3, 0.6)))
        case "wholesome":
            out = out.applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: min(rect.width, rect.height) * 0.02, kCIInputIntensityKey: s(0.2, 0.45)]).cropped(to: rect)
                .applyingFilter("CIColorMatrix", parameters: warm(s(0.4, 0.8)))
        case "sunny":
            out = out.applyingFilter("CIColorMatrix", parameters: warm(s(0.9, 1.6)))
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: s(1.12, 1.3), kCIInputBrightnessKey: 0.02, kCIInputContrastKey: 1.05])
            let corner = CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY - rect.width * 0.12)
            out = glow(out, at: corner, radius: max(rect.width, rect.height) * 0.75, colour: CIColor(red: 1, green: 0.78, blue: 0.35), strength: s(0.5, 0.8))
            if let sun = FaceStickers.place("sun", at: corner, width: rect.width * 0.42, up: CGVector(dx: 0, dy: 1), turn: tt * 0.35) { out = sun.composited(over: out) }
        case "tacky":
            out = out.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: s(1.4, 1.9), kCIInputContrastKey: s(1.08, 1.2)])
            out = glow(out, at: CGPoint(x: rect.minX, y: rect.maxY), radius: max(rect.width, rect.height) * 0.7, colour: CIColor(red: 1, green: 0.25, blue: 0.7), strength: s(0.3, 0.55))
            out = glow(out, at: CGPoint(x: rect.maxX, y: rect.minY), radius: max(rect.width, rect.height) * 0.7, colour: CIColor(red: 1, green: 0.8, blue: 0.2), strength: s(0.3, 0.55))
        default: break
        }
        // 4. The stickers.
        for (i, f) in scene.faces.enumerated() {
            for layer in stickers(id, f, t: tt, index: i) { out = layer.composited(over: out) }
        }
        return out.cropped(to: rect)
    }

    // MARK: - Stickers

    /// The drawn things `id` puts on one face, bottom layer first.
    static func stickers(_ id: String, _ f: Face, t: CGFloat, index: Int = 0) -> [CIImage] {
        func put(_ sprite: String, _ p: CGPoint, _ width: CGFloat, turn: CGFloat = 0, alpha: CGFloat = 1) -> CIImage? {
            FaceStickers.place(sprite, at: p, width: width, up: f.up, turn: turn, alpha: alpha)
        }
        let eyes = CGPoint(x: (f.eyeA.x + f.eyeB.x) / 2, y: (f.eyeA.y + f.eyeB.y) / 2)
        let glassesWidth = f.eyeDistance * 600 / 310          // the lens centres sit on the eyes
        let underNose = CGPoint(x: f.nose.x * 0.55 + f.mouth.x * 0.45, y: f.nose.y * 0.55 + f.mouth.y * 0.45)
        let noseTip = f.point(f.nose, up: f.height * 0.05)
        var out: [CIImage?] = []
        switch id {
        case "sunglasses": out = [put("shades", eyes, glassesWidth)]
        case "heartglasses": out = [put("heartglasses", eyes, glassesWidth * 1.04)]
        case "crown": out = [put("crown", f.point(f.brow, up: f.height * 0.6), f.width * 0.95)]
        case "moustache": out = [put("moustache", underNose, max(f.mouthWidth * 1.9, f.width * 0.5))]
        case "dog":
            out = [put("dogears", f.point(f.brow, up: f.height * 0.5), f.width * 1.55),
                   put("tongue", f.point(f.mouth, up: -f.mouthWidth * 0.08), f.mouthWidth * 0.55, turn: 0.1 * sin(t * 6)),
                   put("dognose", noseTip, f.eyeDistance * 0.68)]
        case "bunny":
            out = [put("bunnyears", f.point(f.brow, up: f.height * 0.58), f.width * 1.05, turn: 0.03 * sin(t * 3)),
                   put("bunnyteeth", f.point(f.mouth, up: f.mouthWidth * 0.06), f.mouthWidth * 0.36),
                   put("bunnynose", noseTip, f.width * 1.0)]
        case "clown": out = [put("clownnose", noseTip, f.eyeDistance * 0.66)]
        case "halo": out = [put("halo", f.point(f.brow, up: f.height * (1.02 + 0.03 * sin(t * 2.2))), f.width * 0.95)]
        case "devil": out = [put("horns", f.point(f.brow, up: f.height * 0.42), f.width * 1.0)]
        case "partyhat": out = [put("partyhat", f.point(f.brow, up: f.height * 0.6, across: f.width * 0.08), f.width * 0.78, turn: -0.14)]
        case "flowers": out = [put("flowers", f.point(f.brow, up: f.height * 0.3), f.width * 1.3)]
        case "zombie": out = [put("scar", f.point(f.brow, up: f.height * 0.26, across: f.width * 0.14), f.width * 0.3, turn: 0.2)]
        case "robot":
            out = [put("antenna", f.point(f.brow, up: f.height * 0.72), f.width * 0.2),
                   put("bolt", f.point(f.cheekA, up: f.height * 0.12), f.width * 0.15), put("bolt", f.point(f.cheekB, up: f.height * 0.12), f.width * 0.15)]
        case "sunny": out = [put("shades", eyes, glassesWidth)]
        case "tacky":
            out = [put("crown", f.point(f.brow, up: f.height * 0.6, across: -f.width * 0.06), f.width * 0.9, turn: 0.16), put("bling", eyes, glassesWidth * 1.06)]
            // Sparkles twinkling round the head.
            for k in 0..<7 {
                let ang = CGFloat(k) * 2 * .pi / 7 + CGFloat(index), tw = 0.5 + 0.5 * sin(t * 5 + CGFloat(k) * 1.9)
                let p = f.point(f.point(f.center, up: f.height * 0.2), up: sin(ang) * f.height * 1.05, across: cos(ang) * f.width * 0.95)
                out.append(put("sparkle", p, f.width * (0.1 + 0.14 * tw), turn: t * 0.6, alpha: 0.35 + 0.65 * tw))
            }
        case "wholesome":
            out = [put("flowers", f.point(f.brow, up: f.height * 0.3), f.width * 1.3)]
            // Hearts drifting up beside the head, fading as they go.
            for k in 0..<6 {
                let phase = (t * 0.32 + CGFloat(k) / 6).truncatingRemainder(dividingBy: 1)
                let sideways: CGFloat = (k % 2 == 0 ? 1 : -1) * (0.72 + 0.12 * CGFloat(k % 3)) + 0.05 * sin(t * 2 + CGFloat(k))
                let p = f.point(f.center, up: f.height * (-0.3 + 1.7 * phase), across: f.width * sideways)
                out.append(put("heart", p, f.width * (0.12 + 0.06 * CGFloat(k % 3)), turn: 0.2 * sin(t * 1.5 + CGFloat(k)), alpha: min(1, 4 * phase) * (1 - phase)))
            }
        default: break
        }
        return out.compactMap { $0 }
    }

    // MARK: - The pieces

    /// The part of the frame a face's masks are drawn in (the face and some room round it), so a mask is small.
    static func around(_ f: Face, _ rect: CGRect) -> CGRect {
        let r = max(f.width, f.height) * 1.6
        return CGRect(x: f.center.x - r, y: f.center.y - r, width: 2 * r, height: 2 * r).intersection(rect).integral
    }

    /// Warmer light: more red, a little less blue. `k` 1 is a sunny afternoon.
    static func warm(_ k: CGFloat) -> [String: Any] {
        ["inputRVector": CIVector(x: 1 + 0.07 * k, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 1 + 0.02 * k, z: 0, w: 0),
         "inputBVector": CIVector(x: 0, y: 0, z: 1 - 0.1 * k, w: 0)]
    }

    /// A mask made `k` times as strong (0…1).
    static func dim(_ mask: CIImage, _ k: CGFloat) -> CIImage {
        mask.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: k, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: k, z: 0, w: 0),
                                                          "inputBVector": CIVector(x: 0, y: 0, z: k, w: 0)])
    }

    /// A soft mask of some outlines (the eyes, the lips), each grown about its middle.
    static func polyMask(_ polys: [[CGPoint]], grow: CGFloat, feather: CGFloat, rect: CGRect) -> CIImage {
        let w = Int(rect.width.rounded()), h = Int(rect.height.rounded())
        guard w > 0, h > 0, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                                                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return CIImage(color: .black).cropped(to: rect) }
        ctx.setFillColor(gray: 1, alpha: 1)
        for poly in polys where poly.count >= 3 {
            let c = mid(poly)
            let pts = poly.map { CGPoint(x: c.x + ($0.x - c.x) * grow - rect.minX, y: c.y + ($0.y - c.y) * grow - rect.minY) }
            ctx.beginPath(); ctx.move(to: pts[0]); for p in pts.dropFirst() { ctx.addLine(to: p) }; ctx.closePath(); ctx.fillPath()
        }
        guard let cg = ctx.makeImage() else { return CIImage(color: .black).cropped(to: rect) }
        return CIImage(cgImage: cg).transformed(by: CGAffineTransform(translationX: rect.minX, y: rect.minY))
            .clampedToExtent().applyingGaussianBlur(sigma: Double(max(0.5, feather))).cropped(to: rect)
    }

    /// A mask drawn in the face's own directions: the origin on the brow line's middle, x across the face, y up it.
    static func faceShape(_ f: Face, rect: CGRect, feather: CGFloat, _ draw: (CGContext) -> Void) -> CIImage {
        let w = Int(rect.width.rounded()), h = Int(rect.height.rounded())
        guard w > 0, h > 0, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                                                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return CIImage(color: .black).cropped(to: rect) }
        ctx.translateBy(x: f.brow.x - rect.minX, y: f.brow.y - rect.minY)
        ctx.concatenate(CGAffineTransform(a: f.side.dx, b: f.side.dy, c: f.up.dx, d: f.up.dy, tx: 0, ty: 0))
        ctx.setFillColor(gray: 1, alpha: 1)
        draw(ctx)
        guard let cg = ctx.makeImage() else { return CIImage(color: .black).cropped(to: rect) }
        return CIImage(cgImage: cg).transformed(by: CGAffineTransform(translationX: rect.minX, y: rect.minY))
            .clampedToExtent().applyingGaussianBlur(sigma: Double(max(0.5, feather))).cropped(to: rect)
    }

    /// Light added round a point (eyes that glow, the sun in the corner).
    static func glow(_ img: CIImage, at c: CGPoint, radius: CGFloat, colour: CIColor, strength: CGFloat) -> CIImage {
        let k = max(0, min(1, strength))
        guard let g = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(cgPoint: c), "inputRadius0": radius * 0.08, "inputRadius1": radius,
            "inputColor0": CIColor(red: colour.red * k, green: colour.green * k, blue: colour.blue * k), "inputColor1": CIColor(red: 0, green: 0, blue: 0),
        ])?.outputImage?.cropped(to: img.extent) else { return img }
        return g.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: img]).cropped(to: img.extent)
    }

    /// A soft wash of colour round a point (rosy cheeks).
    static func tint(_ img: CIImage, at c: CGPoint, radius: CGFloat, colour: CIColor, strength: CGFloat) -> CIImage {
        let wash = CIImage(color: colour).cropped(to: img.extent).applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: img])
        let rosy = CIImage(color: colour).cropped(to: img.extent).applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: wash, kCIInputMaskImageKey: CIImage(color: CIColor(red: 0.35, green: 0.35, blue: 0.35)).cropped(to: img.extent)])
        return blend(rosy, over: img, mask: dim(spot(c, radius: radius, inner: 0.15, rect: img.extent), strength))
    }

    /// Smoother skin on one face: the skin's fine detail softened, its shape, eyes and mouth kept.
    static func smoothSkin(_ img: CIImage, _ f: Face, _ k: CGFloat) -> CIImage {
        let skin = faceMask(f, rect: around(f, img.extent), forehead: 0.5, holes: true, feather: 0.05)
        let soft = img.clampedToExtent().applyingGaussianBlur(sigma: Double(max(1, f.width * 0.022))).cropped(to: img.extent)
        return blend(soft, over: img, mask: dim(skin, k))
    }

    /// The whole picture as a cartoon: flat colours with inked lines.
    static func cartoon(_ img: CIImage, _ a: CGFloat) -> CIImage {
        let rect = img.extent, short = min(rect.width, rect.height)
        let flat = img.applyingFilter("CINoiseReduction", parameters: ["inputNoiseLevel": 0.04, "inputSharpness": 0.2])
            .clampedToExtent().applyingGaussianBlur(sigma: Double(short * 0.004)).cropped(to: rect)
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.25 + 0.4 * a, kCIInputContrastKey: 1.08])
            .applyingFilter("CIColorPosterize", parameters: ["inputLevels": 9 - 3 * a])
        let lines = img.applyingFilter("CILineOverlay", parameters: ["inputNRNoiseLevel": 0.07, "inputNRSharpness": 0.71, "inputEdgeIntensity": 1.0 + 0.6 * a,
                                                                     "inputThreshold": 0.1, "inputContrast": 50])
        return lines.composited(over: flat).cropped(to: rect)
    }

    /// Legs made longer: from the ankles (or the bottom of the picture) up to the hips drawn taller, the body above
    /// moved up by as much — never further than the room above the head.
    static func longLegs(_ img: CIImage, _ scene: Scene, _ a: CGFloat) -> CIImage {
        guard let b = scene.body else { return img }
        let rect = img.extent
        let floor = max(rect.minY, b.ankles?.y ?? rect.minY), legs = b.hips.y - floor
        guard legs > rect.height * 0.08 else { return img }
        let headTop = scene.faces.first.map { $0.point($0.brow, up: $0.height * 0.8).y } ?? (b.neck.y + (b.neck.y - b.hips.y) * 0.6)
        let room = max(0, rect.maxY - headTop - rect.height * 0.01)
        let k = min(1.2 + 0.3 * a, 1 + room / legs)
        guard k > 1.02 else { return img }
        return band(img, line: CGPoint(x: rect.midX, y: floor), dir: CGVector(dx: 0, dy: 1), length: legs, k: k)
    }

    /// A bald head: the hair that stands out round the head filled in from what's behind the person, then the top of
    /// the head painted in the forehead's own colour, lit like a head and blended into the real forehead.
    static func bald(_ img: CIImage, _ f: Face, person: CIImage?, index: Int, memory: Memory?) -> CIImage {
        let rect = img.extent, local = around(f, rect)
        // The skin's colour on each side of the forehead, steadied over time so the head doesn't flicker.
        func patch(_ across: CGFloat) -> CGRect {
            let p = f.point(f.brow, up: f.height * 0.2, across: f.width * across), r = f.width * 0.07
            return CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)
        }
        var left = average(img, in: patch(-0.16)), right = average(img, in: patch(0.16))
        if let m = memory {
            m.lock.lock()
            if m.skin.count > index * 2 + 1 {
                func l(_ o: CIColor, _ n: CIColor) -> CIColor { CIColor(red: n.red + (o.red - n.red) * 0.8, green: n.green + (o.green - n.green) * 0.8, blue: n.blue + (o.blue - n.blue) * 0.8) }
                left = l(m.skin[index * 2], left); right = l(m.skin[index * 2 + 1], right)
                m.skin[index * 2] = left; m.skin[index * 2 + 1] = right
            } else if m.skin.count == index * 2 { m.skin += [left, right] }
            m.lock.unlock()
        }
        // The head's own shape (brow line at y = 0): an oval from the temples up over the crown.
        let rx = f.width * 0.54, cy = f.height * 0.1, ry = f.height * 0.72
        var out = img
        if let person {
            // What's behind the person, spread in over where the person is.
            let behind = img.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: person.applyingFilter("CIColorInvert")])
                .cropped(to: rect)
            let spread = behind.applyingGaussianBlur(sigma: Double(f.width * 0.22)).cropped(to: rect).unpremultiplyingAlpha().settingAlphaOne(in: rect)
            let hair = faceShape(f, rect: local, feather: f.width * 0.03) { ctx in
                ctx.clip(to: CGRect(x: -f.width * 2, y: f.height * 0.12, width: f.width * 4, height: f.height * 3))
                ctx.addEllipse(in: CGRect(x: -f.width * 1.0, y: cy - f.height * 1.25, width: f.width * 2.0, height: f.height * 2.5))
                ctx.addEllipse(in: CGRect(x: -rx, y: cy - ry, width: 2 * rx, height: 2 * ry))
                ctx.fillPath(using: .evenOdd)
            }
            let hairOnPerson = hair.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: person]).cropped(to: rect)
            out = blend(spread, over: out, mask: hairOnPerson)
        }
        // The dome: skin from one side's colour to the other's, a soft highlight, darker toward the rim.
        let a0 = f.point(f.brow, across: -rx), a1 = f.point(f.brow, across: rx)
        var dome = CIFilter(name: "CILinearGradient", parameters: ["inputPoint0": CIVector(cgPoint: a0), "inputPoint1": CIVector(cgPoint: a1),
                                                                  "inputColor0": left, "inputColor1": right])?.outputImage?.cropped(to: rect) ?? CIImage(color: left).cropped(to: rect)
        let crown = f.point(f.brow, up: cy + ry * 0.45, across: -rx * 0.25)
        dome = glow(dome, at: crown, radius: rx * 0.9, colour: CIColor(red: 1, green: 0.97, blue: 0.92), strength: 0.2)
        let rim = CIFilter(name: "CIRadialGradient", parameters: ["inputCenter": CIVector(cgPoint: f.point(f.brow, up: cy)), "inputRadius0": rx * 0.55, "inputRadius1": ry * 1.08,
                                                                 "inputColor0": CIColor(red: 1, green: 1, blue: 1), "inputColor1": CIColor(red: 0.74, green: 0.72, blue: 0.72)])?.outputImage?.cropped(to: rect)
        if let rim { dome = rim.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: dome]).cropped(to: rect) }
        let cap = faceShape(f, rect: local, feather: f.width * 0.035) { ctx in
            // From a little above the brows (so the real forehead shows) up over the crown.
            ctx.clip(to: CGRect(x: -f.width * 2, y: f.height * 0.3, width: f.width * 4, height: f.height * 3))
            ctx.fillEllipse(in: CGRect(x: -rx, y: cy - ry, width: 2 * rx, height: 2 * ry))
        }
        return blend(dome, over: out, mask: cap)
    }
}
