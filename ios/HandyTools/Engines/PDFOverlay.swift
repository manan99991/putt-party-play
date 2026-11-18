import UIKit
import PDFKit

/// Put signatures, dates, text or a watermark on top of a PDF while keeping the original page as vectors —
/// so the document stays sharp and its text stays selectable (unlike flattening the page to a picture).
/// Stamps use DocEngine.Stamp's normalized, top-left coordinates on the page as it is displayed.
enum PDFOverlay {
    /// The page's displayed size (its media box, turned for a 90°/270° rotation).
    static func displaySize(_ page: PDFPage) -> CGSize {
        let b = page.bounds(for: .mediaBox).size
        return (page.rotation % 180 == 0) ? b : CGSize(width: b.height, height: b.width)
    }

    /// Re-write the PDF with `stamps[pageIndex]` drawn over each page. Pages without stamps are copied
    /// through unchanged. Nil only if the PDF can't be read.
    static func stamp(_ data: Data, stamps: [Int: [DocEngine.Stamp]]) -> Data? {
        rewrite(data) { i, size, ctx in
            for s in stamps[i] ?? [] { DocEngine.draw(s, in: size, context: ctx) }
        }
    }

    /// A diagonal, see-through text watermark across every page ("CONFIDENTIAL", "DRAFT", a name…).
    static func watermark(_ data: Data, text: String, opacity: CGFloat = 0.18) -> Data? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return rewrite(data) { _, size, ctx in
            let diagonal = (size.width * size.width + size.height * size.height).squareRoot()
            let fs = DocEngine.fontSize(for: t, width: diagonal * 0.7)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fs, weight: .bold),
                .foregroundColor: UIColor.gray.withAlphaComponent(min(max(opacity, 0.05), 0.6)),
            ]
            let sz = (t as NSString).size(withAttributes: attrs)
            ctx.saveGState()
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.rotate(by: -atan2(size.height, size.width))
            (t as NSString).draw(at: CGPoint(x: -sz.width / 2, y: -sz.height / 2), withAttributes: attrs)
            ctx.restoreGState()
        }
    }

    /// Copy every page as vectors into a fresh PDF, letting `decorate` draw on top of each one in UIKit
    /// (top-left origin) coordinates of the displayed page.
    private static func rewrite(_ data: Data, decorate: (Int, CGSize, CGContext) -> Void) -> Data? {
        guard let doc = PDFDocument(data: data), doc.pageCount > 0, !doc.isLocked else { return nil }
        let out = NSMutableData()
        guard let consumer = CGDataConsumer(data: out as CFMutableData) else { return nil }
        var firstBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &firstBox, nil) else { return nil }
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let size = displaySize(page)
            var box = CGRect(origin: .zero, size: size)
            let info = [kCGPDFContextMediaBox as String: NSData(bytes: &box, length: MemoryLayout<CGRect>.size)] as CFDictionary
            ctx.beginPDFPage(info)
            // The original page, as vectors, turned upright into the displayed box.
            ctx.saveGState()
            page.transform(ctx, for: .mediaBox)
            page.draw(with: .mediaBox, to: ctx)
            ctx.restoreGState()
            // Whatever goes on top, in UIKit (top-left) coordinates.
            ctx.saveGState()
            ctx.translateBy(x: 0, y: size.height)
            ctx.scaleBy(x: 1, y: -1)
            UIGraphicsPushContext(ctx)
            decorate(i, size, ctx)
            UIGraphicsPopContext()
            ctx.restoreGState()
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return out.length > 0 ? out as Data : nil
    }
}

/// Password protection for PDFs, on device.
enum PDFSecure {
    /// Is this PDF password-locked (needs a password to open)?
    static func isLocked(_ data: Data) -> Bool { PDFDocument(data: data)?.isLocked ?? false }

    /// Lock a PDF so it asks for `password` to open (and to change). Nil for an empty password or an
    /// already-locked file.
    static func protect(_ data: Data, password: String) -> Data? {
        guard !password.isEmpty, let doc = PDFDocument(data: data), !doc.isLocked else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-protect-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        guard doc.write(to: url, withOptions: [.userPasswordOption: password, .ownerPasswordOption: password]) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Remove the password: unlock with `password` and save a copy that opens freely. Nil if the
    /// password is wrong.
    static func unlock(_ data: Data, password: String) -> Data? {
        guard let doc = PDFDocument(data: data) else { return nil }
        if doc.isLocked { guard doc.unlock(withPassword: password) else { return nil } }
        let out = PDFDocument()
        for i in 0..<doc.pageCount {
            if let p = doc.page(at: i)?.copy() as? PDFPage { out.insert(p, at: out.pageCount) }
        }
        guard out.pageCount > 0 else { return nil }
        return out.dataRepresentation()
    }
}
