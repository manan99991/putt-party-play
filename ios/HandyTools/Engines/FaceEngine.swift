import CoreImage
import Foundation
import TFLite
import simd

/// The Video Studio's face engine (27 Nov rebuild). Google's open models, run directly with TensorFlow Lite — nothing
/// leaves the phone:
/// - faces are found (BlazeFace, on the whole frame and on overlapping tiles so small faces count too), then a 478-point
///   face mesh is followed from frame to frame from the last mesh and steadied (One-Euro), so effects sit on a face that
///   is small, tilted or turning;
/// - every frame is split into background, hair, body skin, face skin and clothes, so heads are found even turned away,
///   Bald removes real hair, skin effects colour only skin, and the person's outline is clean.
///
/// Work is in top-down pixels of the frame (like the models); `scene` hands back Core Image points (y up).
final class FaceEngine: @unchecked Sendable {
    /// What the engine saw in one frame.
    struct Frame {
        var meshes: [[SIMD3<Float>]] = []       // top-down pixels; z in the same scale
        var parts: [Float] = []                 // 256 x 256 x 6 class shares (0 background, 1 hair, 2 body skin, 3 face skin, 4 clothes, 5 other)
        var heads: [Head] = []
        var rgb: [Float] = []                   // the frame at 256 x 256 (0…255 RGB), for skin colours
        var size = CGSize.zero
    }

    /// A head: where its skull sits above the brow line, in top-down pixels.
    struct Head {
        var ellipse: (cx: Float, cy: Float, rx: Float, ry: Float, tilt: Float)
        var mesh: Int?                           // which mesh is this head's face, if one was found
    }

    static let side = 256

    private let detector: Lite
    private let mesh: Lite
    private let parts: Lite
    private let ctx = CIContext(options: [.cacheIntermediates: false, .useSoftwareRenderer: false])
    private let anchors: [SIMD2<Float>]
    private var tracks: [Track] = []
    private var heads: [HeadTrack] = []
    private var count = 0
    private var lastT = -10.0
    private let lock = NSLock()

    private struct Track {
        var roi: (centre: SIMD2<Float>, size: Float, angle: Float)
        var filter: OneEuro
        var mesh: [SIMD3<Float>]
    }

    private struct HeadTrack {
        var filter: OneEuro
        var ellipse: [Float]
        var misses = 0
    }

    static func url(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "tflite", subdirectory: "face")
            ?? Bundle.main.url(forResource: name, withExtension: "tflite")
    }

    init?() {
        guard let d = Self.url("face_detector").flatMap({ Lite(url: $0) }),
              let m = Self.url("face_landmarks_detector").flatMap({ Lite(url: $0) }),
              let p = Self.url("selfie_multiclass_256x256").flatMap({ Lite(url: $0) }) else { return nil }
        detector = d; mesh = m; parts = p
        var a: [SIMD2<Float>] = []
        for (stride, n) in [(8, 2), (16, 6)] {
            let g = 128 / stride
            for y in 0..<g { for x in 0..<g { for _ in 0..<n { a.append(SIMD2(Float(x) + 0.5, Float(y) + 0.5) / Float(g)) } } }
        }
        anchors = a
    }

    // MARK: - One frame

    /// Everything the effects need from `img` (upright, corner at zero) at time `t`. Frames are expected in order; a
    /// jump (a seek in the preview) starts the following afresh.
    func step(_ img: CIImage, t: Double, wantParts: Bool = true) -> Frame {
        lock.lock(); defer { lock.unlock() }
        let W = Float(img.extent.width), H = Float(img.extent.height)
        let fps = Float(max(10, min(60, t - lastT > 0 ? 1 / (t - lastT) : 30)))
        if abs(t - lastT) > 0.4 { tracks = []; heads = []; count = 0 }
        lastT = t
        let src = img.clampedToExtent()

        // 1. Follow the faces already found.
        var alive: [Track] = []
        for var tr in tracks {
            guard let r = runMesh(src, H: H, roi: tr.roi), r.1 > 0.5 else { continue }
            let m = r.0
            tr.filter.fps = fps
            tr.mesh = tr.filter.filter(m)
            tr.roi = Self.roi(m)
            alive.append(tr)
        }
        tracks = alive
        // 2. Every few frames (or when none are followed), look for new ones.
        if count % 8 == 0 || tracks.isEmpty {
            for d in findFaces(src, W: W, H: H) {
                if tracks.contains(where: { Self.iou(d.box, Self.box($0.mesh)) > 0.2 }) { continue }
                let c = SIMD2((d.box.0 + d.box.2) / 2, (d.box.1 + d.box.3) / 2)
                var angle = atan2(d.eyes.1.y - d.eyes.0.y, d.eyes.1.x - d.eyes.0.x)
                if abs(angle) > .pi / 2 { angle -= angle > 0 ? .pi : -.pi }
                guard let r = runMesh(src, H: H, roi: (c, (d.box.2 - d.box.0) * 1.9, angle)), r.1 > 0.5 else { continue }
                let m = r.0
                var f = OneEuro(fps: fps)
                let first = f.filter(m)
                tracks.append(Track(roi: Self.roi(m), filter: f, mesh: first))
            }
        }
        count += 1
        var frame = Frame(meshes: tracks.map(\.mesh), size: img.extent.size)
        // 3. The parts of the picture, and the heads in it.
        if wantParts, let r = runParts(src, W: W, H: H) {
            let p = r.0
            frame.parts = p; frame.rgb = r.1
            frame.heads = followHeads(p, W: W, H: H, meshes: frame.meshes, fps: fps)
        }
        return frame
    }

    // MARK: - Models

    /// The pixels of `src` inside the square of top-down `size` at `centre`, turned by `angle`, as `n` x `n` RGB floats.
    private func crop(_ src: CIImage, H: Float, centre: SIMD2<Float>, size: Float, angle: Float, n: Int, signed: Bool) -> ([Float], CGAffineTransform)? {
        // Top-down transform from the frame to the crop (the crop's corners at the turned square's corners).
        let k = Float(n) / size, c = cos(-angle), s = sin(-angle)
        // p_crop = R(-angle) * (p - centre) * k + n/2
        let a = CGFloat(c * k), b = CGFloat(s * k), cc = CGFloat(-s * k), d = CGFloat(c * k)
        let tx = CGFloat(Float(n) / 2) - (a * CGFloat(centre.x) + cc * CGFloat(centre.y))
        let ty = CGFloat(Float(n) / 2) - (b * CGFloat(centre.x) + d * CGFloat(centre.y))
        let td = CGAffineTransform(a: a, b: b, c: cc, d: d, tx: tx, ty: ty)
        let flipIn = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(H))
        let flipOut = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(n))
        let t = flipIn.concatenating(td).concatenating(flipOut)
        let out = src.transformed(by: t).cropped(to: CGRect(x: 0, y: 0, width: n, height: n))
        guard let px = pixels(out, n: n) else { return nil }
        return (px.map { signed ? $0 / 127.5 - 1 : $0 / 255 }, td)
    }

    private func pixels(_ img: CIImage, n: Int) -> [Float]? {
        var bytes = [UInt8](repeating: 0, count: n * n * 4)
        ctx.render(img, toBitmap: &bytes, rowBytes: n * 4, bounds: CGRect(x: 0, y: 0, width: n, height: n), format: .RGBA8,
                   colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        var out = [Float](repeating: 0, count: n * n * 3)
        for i in 0..<(n * n) { out[i * 3] = Float(bytes[i * 4]); out[i * 3 + 1] = Float(bytes[i * 4 + 1]); out[i * 3 + 2] = Float(bytes[i * 4 + 2]) }
        return out
    }

    private struct Detection { var score: Float; var box: (Float, Float, Float, Float); var eyes: (SIMD2<Float>, SIMD2<Float>) }

    /// Faces in the top-down rectangle `r` of the frame (square-padded to the model's 128 x 128).
    private func detect(_ src: CIImage, H: Float, r: (x: Float, y: Float, w: Float, h: Float)) -> [Detection] {
        let s = max(r.w, r.h)
        // The rectangle's top-left at the crop's top-left (padding right and below with the clamped edge is fine).
        guard let cr = crop(src, H: H, centre: SIMD2(r.x + s / 2, r.y + s / 2), size: s, angle: 0, n: 128, signed: true),
              let outs = detector.run(cr.0), outs.count >= 2 else { return [] }
        let reg = outs[0], cls = outs[1]
        var found: [Detection] = []
        for i in 0..<anchors.count {
            let score = 1 / (1 + exp(-max(-80, min(80, cls[i]))))
            guard score > 0.55 else { continue }
            let a = anchors[i], o = i * 16
            let cx = a.x + reg[o] / 128, cy = a.y + reg[o + 1] / 128, bw = reg[o + 2] / 128, bh = reg[o + 3] / 128
            func p(_ u: Float, _ v: Float) -> SIMD2<Float> { SIMD2(r.x + u * s, r.y + v * s) }
            // Keep only what lies inside the real rectangle (the padding is the clamped edge).
            guard cx * s < r.w + 4, cy * s < r.h + 4 else { continue }
            found.append(Detection(score: score, box: (r.x + (cx - bw / 2) * s, r.y + (cy - bh / 2) * s, r.x + (cx + bw / 2) * s, r.y + (cy + bh / 2) * s),
                                   eyes: (p(a.x + reg[o + 4] / 128, a.y + reg[o + 5] / 128), p(a.x + reg[o + 6] / 128, a.y + reg[o + 7] / 128))))
        }
        return found
    }

    /// The whole frame, and 3 x 2 overlapping tiles (each seen larger), so faces a few percent of the frame are found.
    private func findFaces(_ src: CIImage, W: Float, H: Float) -> [Detection] {
        var all = detect(src, H: H, r: (0, 0, W, H))
        let tw = W / 2.2, th = H / 1.6
        for ty in [0, H - th] { for tx in [0, (W - tw) / 2, W - tw] { all += detect(src, H: H, r: (tx, ty, tw, th)) } }
        var kept: [Detection] = []
        for d in all.sorted(by: { $0.score > $1.score }) where d.box.2 - d.box.0 > 12 {
            if kept.allSatisfy({ Self.iou($0.box, d.box) < 0.3 }) { kept.append(d) }
        }
        return kept
    }

    /// The face mesh in the turned square `roi`, back in frame pixels, and how sure the model is a face is there.
    private func runMesh(_ src: CIImage, H: Float, roi: (centre: SIMD2<Float>, size: Float, angle: Float)) -> ([SIMD3<Float>], Float)? {
        guard roi.size > 8, let cr = crop(src, H: H, centre: roi.centre, size: roi.size, angle: roi.angle, n: 256, signed: false),
              let outs = mesh.run(cr.0), outs.count >= 2, outs[0].count >= 478 * 3 else { return nil }
        let inv = cr.1.inverted(), k = roi.size / 256
        let pts = (0..<478).map { i -> SIMD3<Float> in
            let p = CGPoint(x: CGFloat(outs[0][i * 3]), y: CGFloat(outs[0][i * 3 + 1])).applying(inv)
            return SIMD3(Float(p.x), Float(p.y), outs[0][i * 3 + 2] * k)
        }
        let presence = 1 / (1 + exp(-(outs[1].first ?? -10)))
        return (pts, presence)
    }

    /// Class shares for the whole frame (stretched to 256 x 256, like the model was trained).
    private func runParts(_ src: CIImage, W: Float, H: Float) -> ([Float], [Float])? {
        let n = Self.side
        let flipIn = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(H))
        let td = CGAffineTransform(scaleX: CGFloat(Float(n) / W), y: CGFloat(Float(n) / H))
        let flipOut = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(n))
        let out = src.transformed(by: flipIn.concatenating(td).concatenating(flipOut)).cropped(to: CGRect(x: 0, y: 0, width: n, height: n))
        guard let px = pixels(out, n: n), let outs = parts.run(px.map { $0 / 255 }), let p = outs.first, p.count == n * n * 6 else { return nil }
        var sm = [Float](repeating: 0, count: p.count)
        for i in 0..<(n * n) {
            let o = i * 6
            var mx = p[o]; for c in 1..<6 { mx = max(mx, p[o + c]) }
            var sum: Float = 0
            for c in 0..<6 { let e = exp(p[o + c] - mx); sm[o + c] = e; sum += e }
            for c in 0..<6 { sm[o + c] /= sum }
        }
        return (sm, px)
    }

    // MARK: - Heads

    /// Heads as blobs of hair and face skin (so a head turned away is a head too), the skull inside the hair, followed.
    private func followHeads(_ p: [Float], W: Float, H: Float, meshes: [[SIMD3<Float>]], fps: Float) -> [Head] {
        let n = Self.side
        var on = [Bool](repeating: false, count: n * n)
        for i in 0..<(n * n) { on[i] = p[i * 6 + 1] + p[i * 6 + 3] > 0.5 }
        var label = [Int32](repeating: 0, count: n * n)
        var found: [[Float]] = []
        var next: Int32 = 1
        let sx = W / Float(n), sy = H / Float(n)
        for start in 0..<(n * n) where on[start] && label[start] == 0 {
            var stack = [start]; label[start] = next
            var px: [Int] = []
            while let i = stack.popLast() {
                px.append(i)
                let x = i % n, y = i / n
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let xx = x + dx, yy = y + dy
                    guard xx >= 0, xx < n, yy >= 0, yy < n else { continue }
                    let j = yy * n + xx
                    if on[j] && label[j] == 0 { label[j] = next; stack.append(j) }
                }
            }
            next += 1
            guard Float(px.count) > Float(n * n) * 0.002 else { continue }
            // Moments in frame pixels; the skull is the blob pulled in by the hair's thickness (~7 %).
            var mx: Float = 0, my: Float = 0
            for i in px { mx += (Float(i % n) + 0.5) * sx; my += (Float(i / n) + 0.5) * sy }
            mx /= Float(px.count); my /= Float(px.count)
            var cxx: Float = 0, cyy: Float = 0, cxy: Float = 0
            for i in px {
                let dx = (Float(i % n) + 0.5) * sx - mx, dy = (Float(i / n) + 0.5) * sy - my
                cxx += dx * dx; cyy += dy * dy; cxy += dx * dy
            }
            cxx /= Float(px.count); cyy /= Float(px.count); cxy /= Float(px.count)
            let tr = cxx + cyy, det = cxx * cyy - cxy * cxy
            let l1 = tr / 2 + sqrt(max(0, tr * tr / 4 - det)), l2 = tr / 2 - sqrt(max(0, tr * tr / 4 - det))
            // The long axis's tilt from upright (heads are taller than wide).
            var tilt = 0.5 * atan2(2 * cxy, cxx - cyy) - .pi / 2
            if tilt < -.pi / 2 { tilt += .pi }
            if tilt > .pi / 2 { tilt -= .pi }
            found.append([mx, my, 2 * sqrt(max(l2, 1)) * 0.93, 2 * sqrt(max(l1, 1)) * 0.93, tilt])
        }
        var used = Set<Int>(), keep: [HeadTrack] = []
        for var h in heads {
            let r = max(h.ellipse[2], h.ellipse[3]) * 1.5
            let best = found.indices.filter { !used.contains($0) }.min { hypot(found[$0][0] - h.ellipse[0], found[$0][1] - h.ellipse[1]) < hypot(found[$1][0] - h.ellipse[0], found[$1][1] - h.ellipse[1]) }
            if let b = best, hypot(found[b][0] - h.ellipse[0], found[b][1] - h.ellipse[1]) < r {
                used.insert(b); h.misses = 0; h.filter.fps = fps; h.ellipse = h.filter.filter(found[b]); keep.append(h)
            } else {
                h.misses += 1
                if Float(h.misses) < fps * 0.4 { keep.append(h) }
            }
        }
        for (i, e) in found.enumerated() where !used.contains(i) {
            var f = OneEuro(fps: fps, minCut: 1.5, beta: 0.02)
            let first = f.filter(e)
            keep.append(HeadTrack(filter: f, ellipse: first))
        }
        heads = keep
        return keep.map { h in
            let e = h.ellipse
            let m = meshes.firstIndex { mesh in
                let c = mesh.reduce(SIMD3<Float>(repeating: 0), +) / Float(mesh.count)
                return hypot(c.x - e[0], c.y - e[1]) < max(e[2], e[3]) * 1.2
            }
            return Head(ellipse: (e[0], e[1], e[2], e[3], e[4]), mesh: m)
        }
    }

    // MARK: - Geometry

    /// The next frame's crop from a mesh: centred on it, 1.5 x its turned extent, turned with its eyes.
    static func roi(_ m: [SIMD3<Float>]) -> (centre: SIMD2<Float>, size: Float, angle: Float) {
        let r = (m[33] + m[133]) / 2, l = (m[362] + m[263]) / 2
        let angle = atan2(l.y - r.y, l.x - r.x)
        let c2 = m.reduce(SIMD3<Float>(repeating: 0), +) / Float(m.count)
        let c = cos(-angle), s = sin(-angle)
        var lo = SIMD2<Float>(repeating: .greatestFiniteMagnitude), hi = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
        for p in m {
            let dx = p.x - c2.x, dy = p.y - c2.y
            let q = SIMD2(c * dx - s * dy, s * dx + c * dy)
            lo = simd_min(lo, q); hi = simd_max(hi, q)
        }
        return (SIMD2(c2.x, c2.y), max(hi.x - lo.x, hi.y - lo.y) * 1.5, angle)
    }

    static func box(_ m: [SIMD3<Float>]) -> (Float, Float, Float, Float) {
        (m.map(\.x).min() ?? 0, m.map(\.y).min() ?? 0, m.map(\.x).max() ?? 0, m.map(\.y).max() ?? 0)
    }

    static func iou(_ a: (Float, Float, Float, Float), _ b: (Float, Float, Float, Float)) -> Float {
        let x0 = max(a.0, b.0), y0 = max(a.1, b.1), x1 = min(a.2, b.2), y1 = min(a.3, b.3)
        let inter = max(0, x1 - x0) * max(0, y1 - y0)
        return inter / ((a.2 - a.0) * (a.3 - a.1) + (b.2 - b.0) * (b.3 - b.1) - inter + 1e-6)
    }
}

/// The One-Euro filter (Casiez et al.): steady when still, quick when moving. Works on flat arrays of numbers.
struct OneEuro {
    var fps: Float
    var minCut: Float = 1.2
    var beta: Float = 0.04
    var dCut: Float = 1.0
    private var x: [Float]?
    private var dx: [Float] = []

    init(fps: Float, minCut: Float = 1.2, beta: Float = 0.04) { self.fps = fps; self.minCut = minCut; self.beta = beta }

    private func alpha(_ cut: Float) -> Float { 1 / (1 + 1 / (2 * .pi * cut) * fps) }

    mutating func filter(_ v: [Float]) -> [Float] {
        guard let old = x, old.count == v.count else { x = v; dx = [Float](repeating: 0, count: v.count); return v }
        let ad = alpha(dCut)
        var out = v
        for i in v.indices {
            let d = (v[i] - old[i]) * fps
            dx[i] = ad * d + (1 - ad) * dx[i]
            let a = alpha(minCut + beta * abs(dx[i]))
            out[i] = a * v[i] + (1 - a) * old[i]
        }
        x = out
        return out
    }

    mutating func filter(_ m: [SIMD3<Float>]) -> [SIMD3<Float>] {
        let flat = filter(m.flatMap { [$0.x, $0.y, $0.z] })
        return (0..<m.count).map { SIMD3(flat[$0 * 3], flat[$0 * 3 + 1], flat[$0 * 3 + 2]) }
    }
}
