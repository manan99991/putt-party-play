import Foundation
import PDFKit
import UIKit
import Vision

/// Organize a PDF's pages: keep any subset, in any order, each with its own extra rotation. Pages are
/// COPIED from the source — not re-rendered — so text stays sharp, vector and selectable, and the file
/// doesn't balloon. Pure and testable; the Organize Pages tool drives it.
enum PDFPages {
    struct Item: Equatable, Identifiable {
        let id = UUID()
        var index: Int        // 0-based page in the source PDF
        var rotation: Int = 0 // extra clockwise rotation, multiples of 90
        static func == (a: Item, b: Item) -> Bool { a.index == b.index && a.rotation == b.rotation }
    }

    /// One item per source page, in the original order — the starting point the user edits.
    static func items(pageCount: Int) -> [Item] { (0..<max(0, pageCount)).map { Item(index: $0) } }

    /// Normalise any rotation into 0, 90, 180 or 270.
    static func normalized(_ degrees: Int) -> Int { ((degrees % 360) + 360) % 360 }

    /// Build a new PDF from `items`, in that order. Out-of-range indexes are skipped; nil when nothing
    /// usable is left (so the tool never hands back an empty file).
    static func build(_ data: Data, items: [Item]) -> Data? {
        guard let src = PDFDocument(data: data), src.pageCount > 0, !items.isEmpty else { return nil }
        let valid = items.filter { $0.index >= 0 && $0.index < src.pageCount }
        guard !valid.isEmpty else { return nil }
        // Nothing moved, turned or removed: hand back the original bytes — forms, signatures, links and odd
        // fonts all stay exactly as they were.
        if valid.count == src.pageCount, valid.enumerated().allSatisfy({ $0.offset == $0.element.index && normalized($0.element.rotation) == 0 }) {
            return data
        }
        let out = PDFDocument()
        for it in valid {
            guard let page = src.page(at: it.index)?.copy() as? PDFPage else { continue }
            page.rotation = normalized(page.rotation + it.rotation)
            out.insert(page, at: out.pageCount)
        }
        guard out.pageCount > 0, let kit = out.dataRepresentation() else { return nil }
        // PDFKit's writer can drop a page's font maps on unusual PDFs, so the words stop being searchable or
        // copyable (the QA lab saw this on 6 of 24 real-world files). Check every page still reads the same; if
        // not, redraw the pages with Core Graphics, which carries each page's fonts across untouched.
        if keepsText(kit, src: src, items: valid) { return kit }
        if let drawn = drawn(data, items: valid), keepsText(drawn, src: src, items: valid) { return drawn }
        return kit
    }

    private static func letters(_ p: PDFPage?) -> String { (p?.string ?? "").filter { $0.isLetter || $0.isNumber } }

    /// Every page of `out` holds the same words as the source page it came from.
    static func keepsText(_ out: Data, src: PDFDocument, items: [Item]) -> Bool {
        guard let doc = PDFDocument(data: out), doc.pageCount == items.count else { return false }
        for (i, it) in items.enumerated() where letters(doc.page(at: i)) != letters(src.page(at: it.index)) { return false }
        return true
    }

    /// The same pages, in order and turned, drawn into a fresh PDF by Core Graphics (each page's own content
    /// and fonts copied as they are). Links and form fields don't come across, so this is only the fallback.
    static func drawn(_ data: Data, items: [Item]) -> Data? {
        guard let provider = CGDataProvider(data: data as CFData), let doc = CGPDFDocument(provider) else { return nil }
        let out = NSMutableData()
        guard let consumer = CGDataConsumer(data: out as CFMutableData), let ctx = CGContext(consumer: consumer, mediaBox: nil, nil) else { return nil }
        var made = 0
        for it in items {
            guard let page = doc.page(at: it.index + 1) else { continue }
            let box = page.getBoxRect(.cropBox)
            let turn = normalized(Int(page.rotationAngle) + it.rotation)
            let size = turn % 180 == 0 ? box.size : CGSize(width: box.height, height: box.width)
            var media = CGRect(origin: .zero, size: size)
            ctx.beginPage(mediaBox: &media)
            ctx.saveGState()
            // Centre the page's crop box on the new page and turn it clockwise (PDF /Rotate is clockwise).
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.rotate(by: -CGFloat(turn) * .pi / 180)
            ctx.translateBy(x: -box.width / 2 - box.minX, y: -box.height / 2 - box.minY)
            ctx.clip(to: box)
            ctx.drawPDFPage(page)
            ctx.restoreGState()
            ctx.endPage()
            made += 1
        }
        ctx.closePDF()
        return made > 0 ? out as Data : nil
    }

    /// Add another PDF's pages after this one's — the merged file becomes the new source, so every tool here
    /// (move, turn, remove) works across both. Pages are copied, not re-rendered.
    static func merge(_ a: Data, _ b: Data) -> Data? {
        guard let first = PDFDocument(data: a), let second = PDFDocument(data: b), second.pageCount > 0 else { return nil }
        for i in 0..<second.pageCount {
            if let p = second.page(at: i)?.copy() as? PDFPage { first.insert(p, at: first.pageCount) }
        }
        return first.dataRepresentation()
    }

    /// Every page as its own PDF ("split"). Named "<name> – page N.pdf" in a fresh folder.
    static func split(_ data: Data, items: [Item], name: String) -> [URL] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("split-\(UUID().uuidString.prefix(6))", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var out: [URL] = []
        for (n, it) in items.enumerated() {
            guard let one = build(data, items: [it]) else { continue }
            let u = dir.appendingPathComponent("\(name) – page \(n + 1).pdf")
            if (try? one.write(to: u)) != nil { out.append(u) }
        }
        return out
    }

    /// A page with (almost) nothing on it: fewer than 0.3% of its pixels are darker than light grey.
    /// Scanners and "print to PDF" leave these behind all the time.
    /// True when a page's text reads clearly only turned round: read both ways up, and the 180° turn wins by a clear
    /// margin (more words, read with more confidence). Pages with little text are left as they are.
    static func looksUpsideDown(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        // Text read the wrong way up still comes back as "text" with fair confidence, so count real words instead:
        // the way that yields far more correctly spelled words is the page's right way up.
        let checker = UITextChecker()
        func score(_ o: CGImagePropertyOrientation) -> Int {
            let r = VNRecognizeTextRequest(); r.recognitionLevel = .fast; r.usesLanguageCorrection = false
            try? VNImageRequestHandler(cgImage: cg, orientation: o).perform([r])
            let words = (r.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .flatMap { $0.split(whereSeparator: { !$0.isLetter }).map(String.init) }.filter { $0.count >= 3 }
            return words.filter { w in
                checker.rangeOfMisspelledWord(in: w, range: NSRange(location: 0, length: (w as NSString).length), startingAt: 0, wrap: false, language: "en").location == NSNotFound
            }.count
        }
        let up = score(.up), turned = score(.down)
        return turned >= 4 && Double(turned) > Double(up) * 1.5
    }

    static func looksBlank(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let w = 60, h = 80
        var px = [UInt8](repeating: 255, count: w * h)
        let drawn: Bool = px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.setFillColor(gray: 1, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return false }
        let dark = px.reduce(0) { $0 + ($1 < 200 ? 1 : 0) }
        return Double(dark) / Double(w * h) < 0.003
    }
}
