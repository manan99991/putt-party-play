import Foundation
import PDFKit
import UIKit

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
        let out = PDFDocument()
        for it in items {
            guard it.index >= 0, it.index < src.pageCount,
                  let page = src.page(at: it.index)?.copy() as? PDFPage else { continue }
            page.rotation = normalized(page.rotation + it.rotation)
            out.insert(page, at: out.pageCount)
        }
        guard out.pageCount > 0 else { return nil }
        return out.dataRepresentation()
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
    static func looksBlank(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let w = 60, h = 80
        var px = [UInt8](repeating: 255, count: w * h)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let dark = px.reduce(0) { $0 + ($1 < 200 ? 1 : 0) }
        return Double(dark) / Double(w * h) < 0.003
    }
}
