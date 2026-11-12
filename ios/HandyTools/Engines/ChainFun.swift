import UIKit
import Vision

/// The playful picture steps of Build your own: a sticker, emojis over faces, meme text and an emoji mosaic.
/// Everything is drawn on the phone. They run in the app and in the share sheet.
enum ChainFun {
    /// nil when `step` is not one of these steps.
    /// - Parameter dryRun: true while the builder previews a tool, so a meme with no words yet shows where they will go.
    static func apply(_ step: ChainStep, to input: ChainPayload, dryRun: Bool = false) -> ChainExtras.Outcome? {
        let b = step.block
        switch (b, input) {
        case (.sticker, .image(let img)):
            // Saved as a PNG so the see-through background survives being shared.
            guard let cut = ImageStudio.cutout(img), let out = sticker(cut), let d = out.pngData() else {
                return .failure(.invalid("Make a sticker couldn't find a person, pet or object to cut out. Try a photo where it stands clear of the background."))
            }
            return .success(.file(d, ext: "png"))

        case (.emojiFaces, .image(let img)):
            let base = img.normalizedUp()
            let faces = faceRects(base)
            guard !faces.isEmpty else {
                return .failure(.invalid("Emoji over faces didn't find a face in that photo. Try one where the face is clear and turned to the camera."))
            }
            return .success(.image(emojiOver(base, faces: faces, emoji: ChainText.faceEmoji(step.settings["emoji"]))))

        case (.meme, .image(let img)):
            var top = ChainText.memeText(step.settings["top"] ?? ""), bottom = ChainText.memeText(step.settings["bottom"] ?? "")
            if dryRun, top.isEmpty, bottom.isEmpty { top = "TOP LINE"; bottom = "BOTTOM LINE" }
            guard !top.isEmpty || !bottom.isEmpty else {
                return .failure(.invalid("Add meme text needs some words. Type a top or a bottom line, then run it again."))
            }
            return .success(.image(meme(img.normalizedUp(), top: top, bottom: bottom)))

        case (.artFilter, .image(let img)):
            guard let out = art(img.normalizedUp(), style: PixelArt.style(step.settings["style"])) else { return .failure(.failed(b)) }
            return .success(.image(out))

        case (.emojiMosaic, .image(let img)):
            guard let out = mosaic(img.normalizedUp()) else { return .failure(.failed(b)) }
            return .success(.image(out))

        default:
            return nil
        }
    }

    /// The picture's own pixels, whatever scale it carries.
    private static func pixels(_ image: UIImage) -> CGSize { CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale) }

    // MARK: sticker

    /// A cut-out with the empty space trimmed away and a white edge drawn round it, like a printed sticker.
    /// nil when the cut-out holds nothing.
    static func sticker(_ cut: UIImage, side: CGFloat = 1024) -> UIImage? {
        guard let cg = cut.cgImage, let box = solidBounds(cg), let subject = cg.cropping(to: box) else { return nil }
        let fit = min(2, side * 0.9 / max(box.width, box.height))
        let w = (box.width * fit).rounded(), h = (box.height * fit).rounded()
        let edge = max(6, (max(w, h) * 0.022).rounded())
        let canvas = CGSize(width: w + edge * 4, height: h + edge * 4)
        let at = CGRect(x: edge * 2, y: edge * 2, width: w, height: h)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        let piece = UIImage(cgImage: subject)
        // The same shape, all white: stamped in a ring it becomes the sticker's edge.
        let white = UIGraphicsImageRenderer(size: at.size, format: fmt).image { ctx in
            piece.draw(in: CGRect(origin: .zero, size: at.size))
            // Filled through the context itself: UIKit's own fill would replace the shape instead of tinting it.
            ctx.cgContext.setBlendMode(.sourceIn)
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: at.size))
        }
        return UIGraphicsImageRenderer(size: canvas, format: fmt).image { _ in
            for i in 0..<24 {
                let a = CGFloat(i) / 24 * 2 * .pi
                white.draw(in: at.offsetBy(dx: cos(a) * edge, dy: sin(a) * edge))
            }
            piece.draw(in: at)
        }
    }

    /// The smallest box holding every pixel that isn't see-through, in the picture's own pixels. nil when all of it is.
    static func solidBounds(_ cg: CGImage) -> CGRect? {
        let k = min(1, 256 / CGFloat(max(cg.width, cg.height, 1)))
        let w = max(1, Int(CGFloat(cg.width) * k)), h = max(1, Int(CGFloat(cg.height) * k))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let raw = ctx.data else { return nil }
        let row = ctx.bytesPerRow
        let px = raw.bindMemory(to: UInt8.self, capacity: row * h)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h { for x in 0..<w where px[y * row + x * 4 + 3] > 24 {
            if x < minX { minX = x }; if x > maxX { maxX = x }; if y < minY { minY = y }; if y > maxY { maxY = y }
        } }
        guard maxX >= minX, maxY >= minY else { return nil }
        // Row 0 of the buffer is the top of the picture, the same way a crop counts.
        let box = CGRect(x: CGFloat(minX) / k, y: CGFloat(minY) / k, width: CGFloat(maxX - minX + 1) / k, height: CGFloat(maxY - minY + 1) / k)
        return box.insetBy(dx: -1 / k, dy: -1 / k).intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height)).integral
    }

    // MARK: emoji over faces

    /// Every face in the picture, in its own pixels, counted from the top-left corner.
    static func faceRects(_ image: UIImage) -> [CGRect] {
        guard let cg = image.cgImage else { return [] }
        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([request])
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        return (request.results ?? []).map { CGRect(x: $0.boundingBox.minX * w, y: (1 - $0.boundingBox.maxY) * h, width: $0.boundingBox.width * w, height: $0.boundingBox.height * h) }
    }

    /// The emoji drawn over each face, a little bigger than the face so none of it shows round the edge.
    static func emojiOver(_ image: UIImage, faces: [CGRect], emoji: String) -> UIImage {
        let size = pixels(image)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            for f in faces {
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: max(f.width, f.height) * 1.3)]
                let glyph = emoji as NSString
                let s = glyph.size(withAttributes: attrs)
                glyph.draw(at: CGPoint(x: f.midX - s.width / 2, y: f.midY - s.height / 2), withAttributes: attrs)
            }
        }
    }

    // MARK: meme text

    /// Big white capitals with a black edge, across the top and the bottom. The words shrink until each block fits.
    static func meme(_ image: UIImage, top: String, bottom: String) -> UIImage {
        let size = pixels(image)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            let width = size.width * 0.94, room = size.height * 0.3, gap = size.height * 0.025
            for (words, atTop) in [(top, true), (bottom, false)] where !words.isEmpty {
                var points = max(16, min(size.width, size.height) / 7)
                var line = memeLine(words, points: points)
                var box = line.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                while box.height > room, points > 12 {
                    points *= 0.9
                    line = memeLine(words, points: points)
                    box = line.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                }
                let y = atTop ? gap : size.height - ceil(box.height) - gap
                line.draw(with: CGRect(x: (size.width - width) / 2, y: y, width: width, height: ceil(box.height)), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            }
        }
    }

    private static func memeLine(_ words: String, points: CGFloat) -> NSAttributedString {
        let style = NSMutableParagraphStyle(); style.alignment = .center; style.lineBreakMode = .byWordWrapping
        let font = UIFont(name: "HelveticaNeue-CondensedBlack", size: points) ?? UIFont.systemFont(ofSize: points, weight: .black)
        return NSAttributedString(string: words, attributes: [.font: font, .foregroundColor: UIColor.white, .strokeColor: UIColor.black, .strokeWidth: -4.5, .paragraphStyle: style])
    }

    // MARK: sketch, comic, pop art

    /// The photo redrawn in a style. Worked out at up to 1600 pixels on the long side, which is plenty to share.
    static func art(_ image: UIImage, style: String, long: CGFloat = 1600) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let k = min(1, long / CGFloat(max(cg.width, cg.height, 1)))
        let w = max(1, Int(CGFloat(cg.width) * k)), h = max(1, Int(CGFloat(cg.height) * k))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(UIColor.white.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let raw = ctx.data else { return nil }
        let row = ctx.bytesPerRow
        let bytes = raw.bindMemory(to: UInt8.self, capacity: row * h)
        var px = [Int](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w {
            let at = y * row + x * 4
            px[y * w + x] = Int(bytes[at]) << 16 | Int(bytes[at + 1]) << 8 | Int(bytes[at + 2])
        } }
        let out = PixelArt.apply(px, width: w, height: h, style: style)
        for y in 0..<h { for x in 0..<w {
            let at = y * row + x * 4, v = out[y * w + x]
            bytes[at] = UInt8(v >> 16 & 0xFF); bytes[at + 1] = UInt8(v >> 8 & 0xFF); bytes[at + 2] = UInt8(v & 0xFF)
        } }
        return ctx.makeImage().map { UIImage(cgImage: $0) }
    }

    // MARK: emoji mosaic

    /// One emoji drawn on white at `side` pixels.
    private static func tile(_ emoji: String, side: CGFloat) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: fmt).image { _ in
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: side * 0.82)]
            let s = (emoji as NSString).size(withAttributes: attrs)
            (emoji as NSString).draw(at: CGPoint(x: (side - s.width) / 2, y: (side - s.height) / 2), withAttributes: attrs)
        }
    }

    /// The colours of a picture squeezed down to `cols` by `rows` pixels, row by row from the top.
    private static func colours(_ cg: CGImage, cols: Int, rows: Int) -> [(r: Int, g: Int, b: Int)]? {
        guard let ctx = CGContext(data: nil, width: cols, height: rows, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(UIColor.white.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: cols, height: rows))
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cols, height: rows))
        guard let raw = ctx.data else { return nil }
        let row = ctx.bytesPerRow
        let px = raw.bindMemory(to: UInt8.self, capacity: row * rows)
        var out: [(r: Int, g: Int, b: Int)] = []
        out.reserveCapacity(cols * rows)
        for y in 0..<rows { for x in 0..<cols {
            let at = y * row + x * 4
            out.append((r: Int(px[at]), g: Int(px[at + 1]), b: Int(px[at + 2])))
        } }
        return out
    }

    /// What colour each mosaic emoji is on the whole, measured once from how this phone draws it.
    private static let palette: [(r: Int, g: Int, b: Int)] = ChainText.mosaicEmojis.map { e -> (r: Int, g: Int, b: Int) in
        guard let cg = tile(e, side: 24).cgImage, let c = colours(cg, cols: 1, rows: 1)?.first else { return (r: 128, g: 128, b: 128) }
        return c
    }

    /// The photo rebuilt from emojis: each small square of it becomes the emoji closest to its colour, on a square
    /// of that colour, so from a step back it still reads as the photo.
    static func mosaic(_ image: UIImage, cell: CGFloat = 28) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let grid = ChainText.mosaicGrid(width: Double(cg.width), height: Double(cg.height))
        guard grid.cols > 0, grid.rows > 0, let cells = colours(cg, cols: grid.cols, rows: grid.rows) else { return nil }
        var tiles: [Int: UIImage] = [:]
        let size = CGSize(width: CGFloat(grid.cols) * cell, height: CGFloat(grid.rows) * cell)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            for (i, c) in cells.enumerated() {
                let r = CGRect(x: CGFloat(i % grid.cols) * cell, y: CGFloat(i / grid.cols) * cell, width: cell, height: cell)
                UIColor(red: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1).setFill()
                ctx.fill(r)
                let pick = ChainText.nearestColor(r: c.r, g: c.g, b: c.b, in: palette)
                guard pick >= 0 else { continue }
                if tiles[pick] == nil { tiles[pick] = tile(ChainText.mosaicEmojis[pick], side: cell) }
                tiles[pick]?.draw(in: r)
            }
        }
    }
}
