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
            // Flat blocks of colour with an ink line round them.
            let lines = pencil(px, width: width, height: height)
            var out = px
            for i in px.indices {
                if lines[i] < 150 { out[i] = rgb(24, 24, 28); continue }
                func flat(_ c: Int) -> Int { min(255, (c + 32) / 64 * 64) }
                out[i] = rgb(flat(px[i] >> 16 & 0xFF), flat(px[i] >> 8 & 0xFF), flat(px[i] & 0xFF))
            }
            return out
        default:
            return pencil(px, width: width, height: height).map { rgb($0, $0, $0) }
        }
    }
}
