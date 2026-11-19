import Foundation
import CoreGraphics

/// Turns a photo into a pencil sketch, a comic, a black-and-white print or pop art. It works on plain numbers
/// (one 0xRRGGBB value per pixel, row by row), so it is the same on iPhone and Android and can be unit-tested.
enum PixelArt {
    static let styles: [(id: String, name: String)] = [("sketch", "Pencil sketch"), ("comic", "Comic"), ("noir", "Black and white"), ("pop", "Pop art")]
    static func style(_ setting: String?) -> String { styles.contains { $0.id == setting } ? (setting ?? "sketch") : "sketch" }

    /// How bright each pixel is, 0 (black) to 255 (white).
    static func gray(_ px: [Int]) -> [Int] {
        px.map { (($0 >> 16 & 0xFF) * 299 + ($0 >> 8 & 0xFF) * 587 + ($0 & 0xFF) * 114) / 1000 }
    }

    /// Each value replaced by the average of the square around it (`radius` pixels each way). Edges use what is there.
    static func blur(_ v: [Int], width: Int, height: Int, radius: Int) -> [Int] {
        guard radius > 0, width > 0, height > 0, v.count == width * height else { return v }
        var across = [Int](repeating: 0, count: v.count)
        for y in 0..<height {
            var sum = 0, n = 0
            for x in 0..<min(radius + 1, width) { sum += v[y * width + x]; n += 1 }
            for x in 0..<width {
                across[y * width + x] = sum / n
                let add = x + radius + 1, drop = x - radius
                if add < width { sum += v[y * width + add]; n += 1 }
                if drop >= 0 { sum -= v[y * width + drop]; n -= 1 }
            }
        }
        var out = [Int](repeating: 0, count: v.count)
        for x in 0..<width {
            var sum = 0, n = 0
            for y in 0..<min(radius + 1, height) { sum += across[y * width + x]; n += 1 }
            for y in 0..<height {
                out[y * width + x] = sum / n
                let add = y + radius + 1, drop = y - radius
                if add < height { sum += across[add * width + x]; n += 1 }
                if drop >= 0 { sum -= across[drop * width + x]; n -= 1 }
            }
        }
        return out
    }

    /// A pencil drawing of the picture: white paper, with a grey line wherever the picture changes. 0...255 per pixel.
    static func pencil(_ px: [Int], width: Int, height: Int) -> [Int] {
        let g = gray(px)
        let soft = blur(g.map { 255 - $0 }, width: width, height: height, radius: max(2, min(width, height) / 80))
        var out = [Int](repeating: 255, count: g.count)
        for i in g.indices {
            let v = min(255, g[i] * 255 / max(1, 255 - soft[i]))
            out[i] = v * v / 255          // a little darker, so the lines read as pencil rather than haze
        }
        return out
    }

    // MARK: comic

    /// Mean of the square around each value (`r` each way), edges clamped. Two sliding passes, so any radius costs the same.
    static func boxF(_ v: [Float], _ w: Int, _ h: Int, _ r: Int) -> [Float] {
        guard r > 0, w > 0, h > 0 else { return v }
        var a = [Float](repeating: 0, count: v.count), out = a
        v.withUnsafeBufferPointer { src in a.withUnsafeMutableBufferPointer { dst in
            for y in 0..<h {
                let row = y * w
                var sum: Float = 0
                for x in -r...r { sum += src[row + min(max(x, 0), w - 1)] }
                for x in 0..<w {
                    dst[row + x] = sum
                    sum += src[row + min(x + r + 1, w - 1)] - src[row + max(x - r, 0)]
                }
            }
        } }
        let n = Float((2 * r + 1) * (2 * r + 1))
        a.withUnsafeBufferPointer { src in out.withUnsafeMutableBufferPointer { dst in
            for x in 0..<w {
                var sum: Float = 0
                for y in -r...r { sum += src[min(max(y, 0), h - 1) * w + x] }
                for y in 0..<h {
                    dst[y * w + x] = sum / n
                    sum += src[min(y + r + 1, h - 1) * w + x] - src[max(y - r, 0) * w + x]
                }
            }
        } }
        return out
    }

    /// A soft blur close to a Gaussian (three box passes).
    static func softF(_ v: [Float], _ w: Int, _ h: Int, sigma: Float) -> [Float] {
        let r = max(1, Int((sigma * 1.2).rounded()))
        return boxF(boxF(boxF(v, w, h, max(1, r / 2 + (r % 2))), w, h, max(1, r / 2)), w, h, max(1, r / 2 + (r % 2)))
    }

    /// Edge-aware smoothing (a guided filter): flattens skin texture and noise into clean cel areas while
    /// keeping the edges between shapes sharp — no blotches, no blocky steps.
    static func guided(_ guide: [Float], _ p: [Float], _ w: Int, _ h: Int, r: Int, eps: Float) -> [Float] {
        let mI = boxF(guide, w, h, r), mp = boxF(p, w, h, r)
        var ip = [Float](repeating: 0, count: p.count), ii = ip
        for i in p.indices { ip[i] = guide[i] * p[i]; ii[i] = guide[i] * guide[i] }
        let mIp = boxF(ip, w, h, r), mII = boxF(ii, w, h, r)
        var a = ip, b = ip
        for i in p.indices {
            let cov = mIp[i] - mI[i] * mp[i], vr = mII[i] - mI[i] * mI[i]
            a[i] = cov / (vr + eps); b[i] = mp[i] - a[i] * mI[i]
        }
        let ma = boxF(a, w, h, r), mb = boxF(b, w, h, r)
        var out = a
        for i in p.indices { out[i] = ma[i] * guide[i] + mb[i] }
        return out
    }

    /// A printed-comic look that keeps people looking like themselves: edge-aware smoothing, cel shading on
    /// brightness only (so skin keeps its real colour instead of turning pink or green), clean ink lines from
    /// a difference of blurs, and Ben-Day dots in the deep shadows. `faces` (pixel rectangles, top-left origin)
    /// get softer shading steps, lighter lines and no dots, so eyes and smiles stay clear.
    static func comic(_ px: [Int], width w: Int, height h: Int, faces: [CGRect] = []) -> [Int] {
        let n = w * h
        guard n > 0, px.count == n else { return px }
        let side = min(w, h)
        var R = [Float](repeating: 0, count: n), G = R, B = R, Y = R
        for i in 0..<n {
            let v = px[i]
            R[i] = Float(v >> 16 & 0xFF); G[i] = Float(v >> 8 & 0xFF); B[i] = Float(v & 0xFF)
            Y[i] = 0.299 * R[i] + 0.587 * G[i] + 0.114 * B[i]
        }
        // Where the faces are (with a margin for hair and chin).
        var face = [Float](repeating: 0, count: n)
        for f in faces {
            let pad = f.width * 0.35
            let x0 = max(0, Int(f.minX - pad)), x1 = min(w - 1, Int(f.maxX + pad))
            let y0 = max(0, Int(f.minY - pad)), y1 = min(h - 1, Int(f.maxY + pad))
            guard x0 <= x1, y0 <= y1 else { continue }
            for y in y0...y1 { for x in x0...x1 { face[y * w + x] = 1 } }
        }
        // 1. Clean, flat areas with sharp edges.
        let r1 = max(3, side / 110), eps: Float = (0.06 * 255) * (0.06 * 255)
        R = guided(Y, R, w, h, r: r1, eps: eps); G = guided(Y, G, w, h, r: r1, eps: eps); B = guided(Y, B, w, h, r: r1, eps: eps)
        var Ys = Y
        for i in 0..<n { Ys[i] = 0.299 * R[i] + 0.587 * G[i] + 0.114 * B[i] }
        let r2 = max(2, r1 / 2)
        R = guided(Ys, R, w, h, r: r2, eps: eps); G = guided(Ys, G, w, h, r: r2, eps: eps); B = guided(Ys, B, w, h, r: r2, eps: eps)
        // 2. Ink: where a lightly smoothed picture's brightness dips (difference of two blurs), thin and clean.
        let Yl = guided(Y, Y, w, h, r: r2, eps: (0.03 * 255) * (0.03 * 255))
        let sigma = max(1, Float(side) / 650)
        let g1 = softF(Yl, w, h, sigma: sigma), g2 = softF(Yl, w, h, sigma: sigma * 1.6)
        var ink = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let d = g1[i] - 0.985 * g2[i]
            ink[i] = min(1, max(0, (-d - (2.6 + face[i] * 1.2)) / 2.0))
        }
        // No lone specks: a line pixel needs a few line neighbours.
        if w > 2, h > 2 {
            let solid = ink.map { $0 > 0.3 ? Float(1) : 0 }
            let around = boxF(solid, w, h, 1)
            for i in 0..<n where around[i] * 9 < 3 { ink[i] = 0 }
        }
        // 3. Colour: shade the brightness in flat steps, keep each pixel's own colour, a little richer.
        func cel(_ y: Float, _ levels: Float, _ soft: Float) -> Float {
            let t = y / 255 * levels, f = t.rounded(.down), frac = t - f
            let s = min(1, max(0, (frac - 0.5) / soft + 0.5))
            return min(255, max(0, (f + s) / levels * 255))
        }
        let per = max(4, side / 140)
        var out = [Int](repeating: 0, count: n)
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                let yy = 0.299 * R[i] + 0.587 * G[i] + 0.114 * B[i]
                let cb = B[i] - yy, cr = R[i] - yy
                let fc = face[i]
                var yc = cel(yy, 5, 0.18) * (1 - fc) + cel(yy, 9, 0.35) * fc
                yc = min(255, max(0, (yc - 128) * 1.08 + 132))
                var r = yc + cr * 1.25, b = yc + cb * 1.25
                var g = (yc - 0.299 * r - 0.114 * b) / 0.587
                // Ben-Day dots in the deepest shadows, never on a face.
                let dark = min(1, max(0, (85 - yy) / 85)) * (1 - fc)
                if dark > 0 {
                    let cx = Float(x / per * per) + Float(per) / 2, cy = Float(y / per * per) + Float(per) / 2
                    let dx = Float(x) - cx, dy = Float(y) - cy, rad = Float(per) * 0.5 * dark
                    if dx * dx + dy * dy < rad * rad { r *= 0.6; g *= 0.6; b *= 0.6 }
                }
                let k = ink[i]
                r = r * (1 - k) + 30 * k; g = g * (1 - k) + 26 * k; b = b * (1 - k) + 34 * k
                out[i] = Int(min(255, max(0, r.rounded()))) << 16 | Int(min(255, max(0, g.rounded()))) << 8 | Int(min(255, max(0, b.rounded())))
            }
        }
        return out
    }

    /// The picture in the chosen style, as 0xRRGGBB values. An unknown style gives the pencil sketch.
    static func apply(_ px: [Int], width: Int, height: Int, style: String, faces: [CGRect] = []) -> [Int] {
        guard width > 0, height > 0, px.count == width * height else { return px }
        func rgb(_ r: Int, _ g: Int, _ b: Int) -> Int { r << 16 | g << 8 | b }
        switch style {
        case "noir":
            return gray(px).map { let v = min(255, max(0, ($0 - 128) * 135 / 100 + 128)); return rgb(v, v, v) }
        case "pop":
            // Four flat inks, darkest to lightest.
            let inks = [rgb(27, 20, 100), rgb(230, 0, 126), rgb(255, 230, 0), rgb(255, 248, 231)]
            return gray(px).map { inks[min(3, $0 / 64)] }
        case "comic":
            return comic(px, width: width, height: height, faces: faces)
        default:
            return pencil(px, width: width, height: height).map { rgb($0, $0, $0) }
        }
    }
}
