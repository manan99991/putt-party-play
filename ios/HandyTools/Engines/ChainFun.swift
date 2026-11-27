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
            // A look from the sticker studio when one is picked on the finish (Classic, Comic, Neon, Holographic…),
            // otherwise the plain white-edged sticker.
            let preset = StickerStudio.presets.first { $0.id == step.settings["style"] }
            guard let cut = ImageStudio.cutout(img), let out = preset.flatMap({ StickerStudio.render(cut, style: $0.style) }) ?? sticker(cut),
                  let d = out.pngData() else {
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
            return .success(.image(meme(img.normalizedUp(), top: top, bottom: bottom, style: step.settings["style"])))

        case (.artFilter, .image(let img)):
            guard let out = art(img.normalizedUp(), style: PixelArt.style(step.settings["style"])) else { return .failure(.failed(b)) }
            return .success(.image(out))

        case (.emojiMosaic, .image(let img)):
            guard let out = mosaic(img.normalizedUp(), style: step.settings["style"]) else { return .failure(.failed(b)) }
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
        // Shares the Privacy Scrubber's stronger detector (latest face model + a body-detection safety
        // net), so Emoji covers the same faces a privacy scrub does — no one left showing. Normalized
        // top-left rects are scaled to pixels for drawing.
        let px = pixels(image)
        return Scrubber.faces(in: image).map { CGRect(x: $0.minX * px.width, y: $0.minY * px.height, width: $0.width * px.width, height: $0.height * px.height) }
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

    /// The words on the photo, in one of four looks. Classic: big white capitals with a black edge, across the top
    /// and the bottom. Caption: a white band above the photo with black words (both lines in it). Bars: black bands
    /// above and below with white words, the photo untouched. Pop: thick-edged yellow capitals. Words shrink to fit.
    static func meme(_ image: UIImage, top: String, bottom: String, style: String? = nil) -> UIImage {
        let photo = pixels(image)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        let width = photo.width * 0.94, short = min(photo.width, photo.height)
        func fit(_ words: String, room: CGFloat, ink: UIColor, edge: UIColor?, edgeWidth: CGFloat, start: CGFloat) -> (NSAttributedString, CGFloat) {
            var points = start
            var line = memeLine(words, points: points, ink: ink, edge: edge, edgeWidth: edgeWidth)
            var h = ceil(line.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
            while h > room, points > 12 {
                points *= 0.9
                line = memeLine(words, points: points, ink: ink, edge: edge, edgeWidth: edgeWidth)
                h = ceil(line.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
            }
            return (line, h)
        }
        func draw(_ line: NSAttributedString, y: CGFloat, h: CGFloat, canvasWidth: CGFloat) {
            line.draw(with: CGRect(x: (canvasWidth - width) / 2, y: y, width: width, height: h), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
        switch style {
        case "caption":
            let words = [top, bottom].filter { !$0.isEmpty }.joined(separator: " ")
            let (line, h) = fit(words, room: photo.height * 0.4, ink: .black, edge: nil, edgeWidth: 0, start: max(16, short / 11))
            let pad = short * 0.05, band = h + pad * 2
            let size = CGSize(width: photo.width, height: photo.height + band)
            return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
                UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
                draw(line, y: pad, h: h, canvasWidth: size.width)
                image.draw(in: CGRect(x: 0, y: band, width: photo.width, height: photo.height))
            }
        case "bars":
            let t = top.isEmpty ? nil : fit(top, room: photo.height * 0.22, ink: .white, edge: nil, edgeWidth: 0, start: max(16, short / 9))
            let b = bottom.isEmpty ? nil : fit(bottom, room: photo.height * 0.22, ink: .white, edge: nil, edgeWidth: 0, start: max(16, short / 9))
            let pad = short * 0.04
            let topBand = t.map { $0.1 + pad * 2 } ?? 0, bottomBand = b.map { $0.1 + pad * 2 } ?? 0
            let size = CGSize(width: photo.width, height: photo.height + topBand + bottomBand)
            return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
                UIColor.black.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
                image.draw(in: CGRect(x: 0, y: topBand, width: photo.width, height: photo.height))
                if let t { draw(t.0, y: pad, h: t.1, canvasWidth: size.width) }
                if let b { draw(b.0, y: topBand + photo.height + pad, h: b.1, canvasWidth: size.width) }
            }
        default:
            let pop = style == "pop"
            let ink = pop ? UIColor(red: 1, green: 0.87, blue: 0.1, alpha: 1) : UIColor.white
            return UIGraphicsImageRenderer(size: photo, format: fmt).image { _ in
                image.draw(in: CGRect(origin: .zero, size: photo))
                let gap = photo.height * 0.025
                for (words, atTop) in [(top, true), (bottom, false)] where !words.isEmpty {
                    let (line, h) = fit(words, room: photo.height * 0.3, ink: ink, edge: .black, edgeWidth: pop ? -7 : -4.5, start: max(16, short / 7))
                    draw(line, y: atTop ? gap : photo.height - h - gap, h: h, canvasWidth: photo.width)
                }
            }
        }
    }

    private static func memeLine(_ words: String, points: CGFloat, ink: UIColor = .white, edge: UIColor? = .black, edgeWidth: CGFloat = -4.5) -> NSAttributedString {
        let style = NSMutableParagraphStyle(); style.alignment = .center; style.lineBreakMode = .byWordWrapping
        let font = UIFont(name: "HelveticaNeue-CondensedBlack", size: points) ?? UIFont.systemFont(ofSize: points, weight: .black)
        var a: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink, .paragraphStyle: style]
        if let edge { a[.strokeColor] = edge; a[.strokeWidth] = edgeWidth }
        return NSAttributedString(string: words, attributes: a)
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
        // The comic keeps faces clear, so find them first (on the phone, in a moment).
        var faces: [CGRect] = []
        if style == "comic", let small = ctx.makeImage() {
            let req = VNDetectFaceRectanglesRequest()
            try? VNImageRequestHandler(cgImage: small, orientation: .up).perform([req])
            faces = (req.results ?? []).map { o in
                let b = o.boundingBox
                return CGRect(x: b.minX * CGFloat(w), y: (1 - b.maxY) * CGFloat(h), width: b.width * CGFloat(w), height: b.height * CGFloat(h))
            }
        }
        let out = PixelArt.apply(px, width: w, height: h, style: style, faces: faces)
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

    /// What colour each emoji is on the whole, measured from how this phone draws it (once per set of emojis).
    private static var palettes: [String: [(r: Int, g: Int, b: Int)]] = [:]
    private static let paletteLock = NSLock()
    private static func palette(_ emojis: [String]) -> [(r: Int, g: Int, b: Int)] {
        let key = emojis.joined()
        paletteLock.lock(); defer { paletteLock.unlock() }
        if let p = palettes[key] { return p }
        let p = emojis.map { e -> (r: Int, g: Int, b: Int) in
            guard let cg = tile(e, side: 24).cgImage, let c = colours(cg, cols: 1, rows: 1)?.first else { return (r: 128, g: 128, b: 128) }
            return c
        }
        palettes[key] = p
        return p
    }

    /// The photo rebuilt from emojis in one of the looks (ChainText.mosaicStyles): each small square of it becomes the
    /// emoji closest to its colour, on a square of that colour so from a step back it still reads as the photo, or on
    /// its own (slightly larger, touching) for a wall of emoji.
    static func mosaic(_ image: UIImage, style: String? = nil, cell: CGFloat = 28) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let look = ChainText.mosaicLook(style)
        let grid = ChainText.mosaicGrid(width: Double(cg.width), height: Double(cg.height), long: look.long)
        guard grid.cols > 0, grid.rows > 0, let cells = colours(cg, cols: grid.cols, rows: grid.rows) else { return nil }
        let pal = palette(look.emojis)
        // Keep the picture about the same size whatever the count: fewer emojis are drawn bigger.
        let side = max(18, (cell * 56 / CGFloat(look.long)).rounded())
        var tiles: [Int: UIImage] = [:]
        let size = CGSize(width: CGFloat(grid.cols) * side, height: CGFloat(grid.rows) * side)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            if !look.backed { UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size)) }
            for (i, c) in cells.enumerated() {
                let r = CGRect(x: CGFloat(i % grid.cols) * side, y: CGFloat(i / grid.cols) * side, width: side, height: side)
                if look.backed {
                    UIColor(red: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1).setFill()
                    ctx.fill(r)
                }
                let pick = ChainText.nearestColor(r: c.r, g: c.g, b: c.b, in: pal)
                guard pick >= 0 else { continue }
                let drawSide = look.backed ? side : side * 1.18
                if tiles[pick] == nil { tiles[pick] = tile(look.emojis[pick], side: drawSide) }
                tiles[pick]?.draw(in: look.backed ? r : r.insetBy(dx: -(drawSide - side) / 2, dy: -(drawSide - side) / 2))
            }
        }
    }
}
