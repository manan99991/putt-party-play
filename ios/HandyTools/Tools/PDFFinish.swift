import SwiftUI
import PDFKit

/// What a finished PDF really is, read back from the file: pages, size, whether its words can be searched and
/// copied, whether it's locked.
struct PDFFacts: Equatable {
    var pages: Int, bytes: Int, words: Int, locked: Bool

    static func read(_ d: Data) -> PDFFacts? {
        guard let doc = PDFDocument(data: d) else { return nil }
        let locked = doc.isEncrypted
        let words = locked ? 0 : (doc.string ?? "").split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        return PDFFacts(pages: doc.pageCount, bytes: d.count, words: words, locked: locked)
    }
}

/// The checks shown on every finished PDF — in the PDF tools and in every ready-made or built tool that ends in a
/// PDF: pages (and how many of the original were kept), size against the original and against a limit, searchable
/// words, and locked when it was meant to be. Each line is read from the file.
struct PDFFactsRows: View {
    let data: Data
    var source: Data?
    var limitBytes: Int?
    var expectLocked = false

    var body: some View {
        if let f = PDFFacts.read(data) {
            let before = source.flatMap(PDFFacts.read)
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                if let b = before, b.pages != f.pages {
                    row(true, "\(f.pages) \(L(f.pages == 1 ? "page" : "pages")) — \(L("from")) \(b.pages)")
                } else {
                    row(true, "\(f.pages) \(L(f.pages == 1 ? "page" : "pages"))")
                }
                if let b = before, b.bytes > f.bytes {
                    row(true, "\(SizeTarget.format(f.bytes)) — \(L("down from")) \(SizeTarget.format(b.bytes)) · \(Int((1 - Double(f.bytes) / Double(b.bytes)) * 100))% \(L("smaller"))")
                } else {
                    row(true, SizeTarget.format(f.bytes))
                }
                if let limit = limitBytes {
                    let ok = f.bytes <= limit
                    row(ok, "\(L(ok ? "Under" : "Still over")) \(SizeTarget.format(limit))").accessibilityIdentifier("pdf-size-check")
                }
                if expectLocked || f.locked {
                    row(f.locked, f.locked ? L("Locked — opens only with your password") : L("Not locked"))
                        .accessibilityIdentifier("pdf-lock-check")
                } else {
                    row(f.words > 0, f.words > 0 ? "\(L("Searchable — words can be found and copied")) (\(f.words))" : L("Pictures only — words can't be searched yet"))
                        .accessibilityIdentifier("pdf-search-check")
                }
            }
        }
    }

    private func row(_ ok: Bool, _ text: String) -> some View {
        Label { Text(text).font(HandyFont.caption).fixedSize(horizontal: false, vertical: true) } icon: {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(ok ? Color.green : Color.orange)
        }
        .accessibilityElement(children: .combine)   // one element per check, so a test (and VoiceOver) reads it once
    }
}
