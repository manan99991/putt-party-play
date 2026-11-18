import Foundation
import PDFKit

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
}
