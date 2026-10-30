import UIKit
import PDFKit

/// Merge / split / rotate / compress / PDF → images on top of PDFKit. Merge, split and rotate are
/// lossless page moves (PDFDocument insert/remove); compress re-renders pages at a smaller size and
/// keeps them searchable by OCR-ing the pages that had text. Every result is a real file in tmp.
enum PDFTools {

    struct Item: Identifiable, Equatable {
        let id = UUID()
        let url: URL          // private tmp copy, no security scope needed
        let name: String
        let pages: Int
        let bytes: Int
        static func == (a: Item, b: Item) -> Bool { a.id == b.id }
    }

    private static var dir: URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("PDFTools", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Copy a picked PDF into tmp (so it stays readable after the picker's scope ends) and inspect it.
    static func load(_ picked: URL) -> Item? {
        let access = picked.startAccessingSecurityScopedResource(); defer { if access { picked.stopAccessingSecurityScopedResource() } }
        let dest = dir.appendingPathComponent(UUID().uuidString + "-" + picked.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        guard (try? FileManager.default.copyItem(at: picked, to: dest)) != nil, let doc = PDFDocument(url: dest), doc.pageCount > 0 else { return nil }
        let bytes = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int) ?? 0
        return Item(url: dest, name: picked.lastPathComponent, pages: doc.pageCount, bytes: bytes)
    }

    static func write(_ data: Data, name: String) -> URL? {
        let url = dir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        return (try? data.write(to: url)) != nil ? url : nil
    }

    /// All pages of every item, in order, into one document.
    static func merge(_ items: [Item]) -> Data? {
        let out = PDFDocument()
        for it in items {
            guard let doc = PDFDocument(url: it.url) else { continue }
            for i in 0..<doc.pageCount { if let p = doc.page(at: i) { out.insert(p, at: out.pageCount) } }
        }
        return out.pageCount > 0 ? out.dataRepresentation() : nil
    }

    /// Split by ranges ("1-3, 4, 5-"); blank = one file per page.
    static func split(_ item: Item, spec: String) -> [Data] {
        guard let d = try? Data(contentsOf: item.url) else { return [] }
        return DocEngine.split(d, ranges: spec)
    }

    /// Rotate every page a quarter turn clockwise (lossless — a page attribute).
    static func rotate(_ item: Item, quarterTurns: Int = 1) -> Data? {
        guard let doc = PDFDocument(url: item.url) else { return nil }
        for i in 0..<doc.pageCount { if let p = doc.page(at: i) { p.rotation = (p.rotation + 90 * quarterTurns) % 360 } }
        return doc.dataRepresentation()
    }

    /// Re-render pages as JPEG at `maxWidth` px. Pages that had a text layer get one back via OCR.
    static func compress(_ item: Item, maxWidth: CGFloat, quality: CGFloat) -> Data? {
        guard let doc = PDFDocument(url: item.url) else { return nil }
        let images = DocEngine.render(doc, maxWidth: maxWidth)
        guard !images.isEmpty else { return nil }
        let ocr: [[DocEngine.OCRLine]?] = images.enumerated().map { i, img in
            let hadText = ((doc.page(at: i)?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).count) > 10
            return hadText && i < 40 ? DocEngine.recognize(img) : nil
        }
        var opts = DocEngine.PDFOptions(searchable: true, pageSize: .auto)
        opts.maxWidth = maxWidth; opts.quality = quality
        return DocEngine.pdf(images: images, ocr: ocr, options: opts)
    }

    /// One JPG per page.
    static func images(_ item: Item, maxWidth: CGFloat = 1600) -> [URL] {
        guard let doc = PDFDocument(url: item.url) else { return [] }
        let base = (item.name as NSString).deletingPathExtension
        var urls: [URL] = []
        for (i, img) in DocEngine.render(doc, maxWidth: maxWidth).enumerated() {
            guard let d = img.jpegData(compressionQuality: 0.9), let u = write(d, name: "\(base)-page\(i + 1).jpg") else { continue }
            urls.append(u)
        }
        return urls
    }

    static func format(_ bytes: Int) -> String { SizeTarget.format(bytes) }
}
