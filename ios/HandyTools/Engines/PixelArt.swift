import Foundation

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

    /// A printed-comic look: crisp ink outlines where shapes meet (edges of a lightly smoothed picture, so
    /// skin texture and noise don't turn into scribbles), flat cel-shaded colour, and Ben-Day halftone dots
    /// in the shadows. Lines and dots scale with the picture so it reads the same at any size.
    static func comic(_ px: [Int], width w: Int, height h: Int) -> [Int] {
        func rgb(_ r: Int, _ g: Int, _ b: Int) -> Int { r << 16 | g << 8 | b }
        func flat(_ c: Int) -> Int { min(255, (c + 32) / 64 * 64) }
        let side = min(w, h)
        // Smooth each channel a touch so cel areas are clean, then flatten.
        let r0 = max(1, side / 300)
        let rs = blur(px.map { $0 >> 16 & 0xFF }, width: w, height: h, radius: r0)
        let gs = blur(px.map { $0 >> 8 & 0xFF }, width: w, height: h, radius: r0)
        let bs = blur(px.map { $0 & 0xFF }, width: w, height: h, radius: r0)
        // Ink: Sobel edges of the smoothed brightness.
        let lum = blur(gray(px), width: w, height: h, radius: max(1, side / 400))
        var ink = [Bool](repeating: false, count: px.count)
        if w > 2, h > 2 {
            for y in 1..<(h - 1) {
                for x in 1..<(w - 1) {
                    let i = y * w + x
                    let gx = (lum[i - w + 1] + 2 * lum[i + 1] + lum[i + w + 1]) - (lum[i - w - 1] + 2 * lum[i - 1] + lum[i + w - 1])
                    let gy = (lum[i + w - 1] + 2 * lum[i + w] + lum[i + w + 1]) - (lum[i - w - 1] + 2 * lum[i - w] + lum[i - w + 1])
                    if abs(gx) + abs(gy) > 150 { ink[i] = true }
                }
            }
        }
        // Thicker lines on big pictures, so they survive being viewed small.
        if side >= 700 {
            let thin = ink
            for y in 1..<(h - 1) { for x in 1..<(w - 1) where !thin[y * w + x] {
                let i = y * w + x
                if thin[i - 1] || thin[i + 1] || thin[i - w] || thin[i + w] { ink[i] = true }
            } }
        }
        let period = max(4, side / 160)
        var out = [Int](repeating: 0, count: px.count)
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                if ink[i] { out[i] = rgb(24, 24, 28); continue }
                let fr = flat(rs[i]), fg = flat(gs[i]), fb = flat(bs[i])
                let l = lum[i]
                if l < 120 {
                    // Halftone: a dot per cell, bigger the darker it is, in a deeper shade of the same ink.
                    let cx = x / period * period + period / 2, cy = y / period * period + period / 2
                    let dx = x - cx, dy = y - cy
                    let radius = Double(period) * 0.55 * (1 - Double(l) / 120) + 0.5
                    if Double(dx * dx + dy * dy) < radius * radius {
                        out[i] = rgb(fr * 55 / 100, fg * 55 / 100, fb * 55 / 100); continue
                    }
                }
                out[i] = rgb(fr, fg, fb)
            }
        }
        return out
    }

    /// The picture in the chosen style, as 0xRRGGBB values. An unknown style gives the pencil sketch.
    static func apply(_ px: [Int], width: Int, height: Int, style: String) -> [Int] {
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
            return comic(px, width: width, height: height)
        default:
            return pencil(px, width: width, height: height).map { rgb($0, $0, $0) }
        }
    }
}
