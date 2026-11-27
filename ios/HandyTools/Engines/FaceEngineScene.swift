import CoreImage
import Foundation
import simd

/// What the face engine saw, turned into what the effects use (27 Nov rebuild): faces in Core Image points, and the
/// hair, face-skin and person masks at the frame's size with their edges snapped to the picture.
extension FaceFun {
    struct Parts {
        let frame: FaceEngine.Frame
        let hair: CIImage
        let face: CIImage
        let person: CIImage
    }

    /// One class share (or the sum of some) from the 256 x 256 map, as a grey mask the frame's size.
    static func classMask(_ f: FaceEngine.Frame, _ classes: [Int], guide: CIImage?, invert: Bool = false) -> CIImage {
        let n = FaceEngine.side
        var bytes = [UInt8](repeating: 0, count: n * n)
        for i in 0..<(n * n) {
            var v: Float = 0
            for c in classes { v += f.parts[i * 6 + c] }
            if invert { v = 1 - v }
            bytes[i] = UInt8(max(0, min(255, v * 255)))
        }
        let small = CIImage(bitmapData: Data(bytes), bytesPerRow: n, size: CGSize(width: n, height: n), format: .L8, colorSpace: nil)
        let rect = CGRect(origin: .zero, size: f.size)
        let big = small.samplingLinear().clampedToExtent()
            .transformed(by: CGAffineTransform(scaleX: f.size.width / CGFloat(n), y: f.size.height / CGFloat(n))).cropped(to: rect)
        // Edges snapped to the picture's own edges (hair strands, an ear), where Core Image has the guided filter.
        if let guide, let g = CIFilter(name: "CIGuidedFilter", parameters: [kCIInputImageKey: big, "inputGuideImage": guide,
                                                                            "inputRadius": max(2, f.size.width / 220), "inputEpsilon": 0.001])?.outputImage {
            return g.cropped(to: rect)
        }
        return big
    }

    static func parts(_ f: FaceEngine.Frame, guide: CIImage) -> Parts? {
        guard f.parts.count == FaceEngine.side * FaceEngine.side * 6 else { return nil }
        return Parts(frame: f, hair: classMask(f, [1], guide: guide), face: classMask(f, [3], guide: guide),
                     person: classMask(f, [0], guide: guide, invert: true))
    }

    /// Mesh points (MediaPipe's canonical face) the effects are built on.
    enum MeshIndex {
        static let jaw = [234, 93, 132, 58, 172, 136, 150, 149, 176, 148, 152, 377, 400, 378, 379, 365, 397, 288, 361, 323, 454]
        static let eyeA = [33, 160, 158, 133, 153, 144], eyeB = [362, 385, 387, 263, 373, 380]
        static let brows = [70, 63, 105, 66, 107, 336, 296, 334, 293, 300]
        static let nose = [6, 197, 195, 5, 4, 1]
        static let lips = [61, 185, 40, 39, 37, 0, 267, 269, 270, 409, 291, 375, 321, 405, 314, 17, 84, 181, 91, 146]
        static let top = 10, chin = 152
        static let forehead = [151, 9, 108, 337, 69, 299]
    }

    /// A face from the mesh (top-down pixels of a frame `height` tall), in Core Image points.
    static func face(mesh m: [SIMD3<Float>], height: CGFloat) -> Face? {
        guard m.count >= 468 else { return nil }
        func p(_ i: Int) -> CGPoint { CGPoint(x: CGFloat(m[i].x), y: height - CGFloat(m[i].y)) }
        return face(contour: MeshIndex.jaw.map(p), eyeA: MeshIndex.eyeA.map(p), eyeB: MeshIndex.eyeB.map(p),
                    brows: MeshIndex.brows.map(p), nose: MeshIndex.nose.map(p), lips: MeshIndex.lips.map(p))
    }

    /// The scene from the face engine: every face it follows, the body when the effect needs it, the person's outline.
    static func scene(engine f: FaceEngine.Frame, parts: Parts?, for id: String, src: CIImage) -> Scene {
        let H = f.size.height
        var s = Scene(faces: f.meshes.compactMap { face(mesh: $0, height: H) }.sorted { $0.width > $1.width })
        if needsBody(id) { s.body = body(in: src) }
        s.person = parts?.person
        s.parts = parts
        return s
    }

    // MARK: - Masks for the skin effects

    /// The face's skin from the parts map (only round this face, and with its eyes and lips left out when `holes`);
    /// the drawn jaw-line mask when there's no parts map.
    static func skinMask(_ f: Face, _ scene: Scene, rect: CGRect, forehead: CGFloat, holes: Bool) -> CIImage {
        guard let p = scene.parts else { return faceMask(f, rect: around(f, rect), forehead: forehead, holes: holes) }
        let c = f.point(f.center, up: f.height * 0.15), r = max(f.width, f.height) * 1.05
        var m = p.face
        if let near = CIFilter(name: "CIRadialGradient", parameters: ["inputCenter": CIVector(cgPoint: c), "inputRadius0": r * 0.8, "inputRadius1": r,
                                                                      "inputColor0": CIColor.white, "inputColor1": CIColor.black])?.outputImage?.cropped(to: rect) {
            m = near.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: m]).cropped(to: rect)
        }
        if holes {
            let cut = polyMask([f.eyePtsA, f.eyePtsB, f.lips], grow: 1.3, feather: f.eyeDistance * 0.04, rect: around(f, rect))
                .applyingFilter("CIColorInvert").cropped(to: rect)
            m = cut.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: m]).cropped(to: rect)
        }
        return m
    }

    // MARK: - Big head and tiny head (every head the engine found, turned away too)

    private static let scaleKernel: CIWarpKernel? = library.flatMap { try? CIWarpKernel(functionName: "tenzyScale", fromMetalLibraryData: $0) }

    /// Every head made `scale` times its size, proportions kept, easing back into the picture round it.
    static func scaleHeads(_ img: CIImage, _ p: Parts, scale: CGFloat, big: Bool) -> CIImage? {
        guard let k = scaleKernel, !p.frame.heads.isEmpty else { return nil }
        let rect = img.extent, H = rect.height
        var out = img
        for h in p.frame.heads {
            let e = h.ellipse
            let size = CGFloat(max(e.rx, e.ry))
            guard size > 8 else { continue }
            // The head's middle a little above its outline's centre (the outline takes in the beard and neck line); up is up.
            var ux = CGFloat(sin(e.tilt)), uy = CGFloat(cos(e.tilt))
            if uy < 0 { ux = -ux; uy = -uy }
            let c = CGPoint(x: CGFloat(e.cx) + ux * size * 0.05, y: H - CGFloat(e.cy) + uy * size * 0.05)
            let radius = big ? size * (1 + scale) * 0.95 : size * 1.6
            if let w = k.apply(extent: rect, roiCallback: { _, _ in rect }, image: out.clampedToExtent(),
                               arguments: [CIVector(cgPoint: c), radius, scale, 0.55]) { out = w.cropped(to: rect) }
        }
        return out
    }

    // MARK: - Bald (every head, faces turned away included)

    private static let hairOutKernel: CIColorKernel? = library.flatMap { try? CIColorKernel(functionName: "tenzyHairOut", fromMetalLibraryData: $0) }
    private static let scalpKernel: CIColorKernel? = library.flatMap { try? CIColorKernel(functionName: "tenzyScalp", fromMetalLibraryData: $0) }
    static var baldKernelsLoaded: Bool { hairOutKernel != nil && scalpKernel != nil }

    /// Where a head's bare skull sits (top-down pixels): the brow line's middle, the head's up, the skull's centre on the
    /// brow line, its half-width and height. From the face mesh when there is one; otherwise from the head's outline.
    static func skull(_ h: FaceEngine.Head, _ f: FaceEngine.Frame) -> (B: SIMD2<Float>, up: SIMD2<Float>, c: SIMD2<Float>, axes: SIMD2<Float>) {
        let e = h.ellipse
        var up = SIMD2<Float>(sin(e.tilt), -cos(e.tilt)), B = SIMD2<Float>(e.cx, e.cy) - up * e.ry * 0.5
        if let i = h.mesh, i < f.meshes.count {
            let m = f.meshes[i]
            let b = MeshIndex.brows.reduce(SIMD3<Float>(repeating: 0)) { $0 + m[$1] } / Float(MeshIndex.brows.count)
            B = SIMD2(b.x, b.y)
            let u = SIMD2(m[MeshIndex.top].x - m[MeshIndex.chin].x, m[MeshIndex.top].y - m[MeshIndex.chin].y)
            up = u / max(simd_length(u), 1e-3)
        }
        let side = SIMD2(-up.y, up.x)
        let n = FaceEngine.side
        let sx = Float(f.size.width) / Float(n), sy = Float(f.size.height) / Float(n)
        var along: [Float] = [], across: [Float] = []
        let reach = max(e.rx, e.ry) * 1.6
        for y in 0..<n {
            for x in 0..<n {
                let i = y * n + x
                guard f.parts[i * 6 + 1] + f.parts[i * 6 + 3] > 0.5 else { continue }
                let P = SIMD2((Float(x) + 0.5) * sx, (Float(y) + 0.5) * sy)
                guard simd_length(P - SIMD2(e.cx, e.cy)) < reach else { continue }
                let a = simd_dot(P - B, up)
                if a > 0 { along.append(a); across.append(simd_dot(P - B, side)) }
            }
        }
        func pct(_ v: [Float], _ q: Float) -> Float { let s = v.sorted(); return s[min(s.count - 1, max(0, Int(Float(s.count - 1) * q)))] }
        guard along.count > 10 else { return (B, up, B + up * e.ry * 0.5, SIMD2(e.rx, e.ry * 0.6)) }
        var top = pct(along, 0.99), lo = pct(across, 0.01), hi = pct(across, 0.99)
        let thick = 0.05 * max(top, (hi - lo) / 2)
        lo += thick; hi -= thick; top -= thick
        return (B, up, B + side * (lo + hi) / 2, SIMD2(max(1, (hi - lo) / 2), max(1, top)))
    }

    /// The head's own skin colour: its forehead when its face is seen, else face skin near it, else body skin.
    static func tone(_ h: FaceEngine.Head, _ f: FaceEngine.Frame) -> SIMD3<Float> {
        let n = FaceEngine.side
        guard f.rgb.count == n * n * 3 else { return SIMD3(0.85, 0.66, 0.55) }
        let sx = Float(n) / Float(f.size.width), sy = Float(n) / Float(f.size.height)
        func at(_ x: Float, _ y: Float) -> Int? {
            let gx = Int(x * sx), gy = Int(y * sy)
            return gx >= 0 && gx < n && gy >= 0 && gy < n ? gy * n + gx : nil
        }
        func rgb(_ i: Int) -> SIMD3<Float> { SIMD3(f.rgb[i * 3], f.rgb[i * 3 + 1], f.rgb[i * 3 + 2]) / 255 }
        func median(_ v: [SIMD3<Float>]) -> SIMD3<Float> {
            func m(_ k: KeyPath<SIMD3<Float>, Float>) -> Float { let s = v.map { $0[keyPath: k] }.sorted(); return s[s.count / 2] }
            return SIMD3(m(\.x), m(\.y), m(\.z))
        }
        if let mi = h.mesh, mi < f.meshes.count {
            let pts = MeshIndex.forehead.compactMap { at(f.meshes[mi][$0].x, f.meshes[mi][$0].y) }.map(rgb)
            if pts.count >= 3 { return median(pts) }
        }
        let e = h.ellipse, reach = max(e.rx, e.ry) * 2
        for cls in [3, 2] {
            var v: [SIMD3<Float>] = []
            for i in 0..<(n * n) where f.parts[i * 6 + cls] > 0.7 {
                let x = (Float(i % n) + 0.5) / sx, y = (Float(i / n) + 0.5) / sy
                if hypot(x - e.cx, y - e.cy) < reach { v.append(rgb(i)) }
            }
            if v.count > 8 { return median(v) }
        }
        return SIMD3(0.85, 0.66, 0.55)
    }

    /// Fills the white of `hole` from what's around it (push-pull: ever wider soft averages of the known pixels, the
    /// finest one that has enough to go on wins).
    static func fill(_ img: CIImage, hole: CIImage, rect: CGRect) -> CIImage {
        let grown = hole.applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: max(2, rect.width / 300)]).cropped(to: rect)
        let known = img.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: CIImage.empty(),
                                                                         kCIInputMaskImageKey: grown.applyingFilter("CIColorInvert")]).cropped(to: rect)
        var result: CIImage?
        for sigma in [32.0, 16, 8, 4, 2].map({ $0 * Double(rect.width) / 1000 }) {
            let b = known.clampedToExtent().applyingGaussianBlur(sigma: max(1, sigma)).cropped(to: rect)
            let est = b.unpremultiplyingAlpha().settingAlphaOne(in: rect)
            guard let r = result else { result = est; continue }
            // Where this scale saw enough known pixels (its alpha), use it.
            let enough = b.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 3), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 3),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 3), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)]).applyingFilter("CIColorClamp").cropped(to: rect)
            result = est.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: r, kCIInputMaskImageKey: enough]).cropped(to: rect)
        }
        guard let filled = result else { return img }
        let soft = grown.applyingGaussianBlur(sigma: 1.5).cropped(to: rect)
        return filled.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: img, kCIInputMaskImageKey: soft]).cropped(to: rect)
    }

    /// Bald on every head the engine found: the hair standing out beyond the skull filled from around it, then the
    /// scalp drawn over the skull in the head's own skin colour, lit as a round head. Beards and sideburns stay.
    static func baldHeads(_ img: CIImage, _ p: Parts, amount: CGFloat) -> CIImage {
        guard let hk = hairOutKernel, let sk = scalpKernel else { return img }
        let rect = img.extent, H = Float(rect.height), f = p.frame
        var out = img
        let noise = (CIFilter(name: "CIRandomGenerator")?.outputImage ?? CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)))
            .applyingGaussianBlur(sigma: Double(rect.width) / 160).cropped(to: rect)
        for h in f.heads {
            let s = skull(h, f)
            // To Core Image points (y up).
            func pt(_ v: SIMD2<Float>) -> CIVector { CIVector(x: CGFloat(v.x), y: CGFloat(H - v.y)) }
            func dir(_ v: SIMD2<Float>) -> CIVector { CIVector(x: CGFloat(v.x), y: CGFloat(-v.y)) }
            let up = dir(s.up), side = CIVector(x: up.y, y: -up.x)
            let scale = CGFloat(max(s.axes.x, s.axes.y))
            let args: [Any] = [pt(s.c), CIVector(x: CGFloat(s.axes.x), y: CGFloat(s.axes.y)), side, up, pt(s.B), scale]
            if let beyond = hk.apply(extent: rect, arguments: ([p.hair] as [Any]) + args) {
                out = fill(out, hole: beyond.applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.12]).cropped(to: rect), rect: rect)
            }
            let t = tone(h, f)
            let more: [Any] = [CIVector(x: CGFloat(t.x), y: CGFloat(t.y), z: CGFloat(t.z)), amount]
            if let b = sk.apply(extent: rect, arguments: ([out, p.hair, p.face, noise] as [Any]) + args + more) {
                out = b.cropped(to: rect)
            }
        }
        return out
    }
}
