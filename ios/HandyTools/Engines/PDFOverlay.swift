import UIKit
import PDFKit

/// Put signatures, dates or text on top of a PDF while keeping the original page as vectors — so the
/// document stays sharp and its text stays selectable (unlike flattening the page to a picture). Stamps
/// use DocEngine.Stamp's normalized, top-left coordinates on the page as it is displayed.
enum PDFOverlay {
    /// The page's displayed size (its media box, turned for a 90°/270° rotation).
    static func displaySize(_ page: PDFPage) -> CGSize {
        let b = page.bounds(for: .mediaBox).size
        return (page.rotation % 180 == 0) ? b : CGSize(width: b.height, height: b.width)
    }

    /// Re-write the PDF with `stamps[pageIndex]` drawn over each page. Pages without stamps are copied
    /// through unchanged. Nil only if the PDF can't be read.
    static func stamp(_ data: Data, stamps: [Int: [DocEngine.Stamp]]) -> Data? {
        guard let doc = PDFDocument(data: data), doc.pageCount > 0 else { return nil }
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
            // The stamps, in UIKit (top-left) coordinates.
            if let list = stamps[i], !list.isEmpty {
                ctx.saveGState()
                ctx.translateBy(x: 0, y: size.height)
                ctx.scaleBy(x: 1, y: -1)
                UIGraphicsPushContext(ctx)
                for s in list { DocEngine.draw(s, in: size, context: ctx) }
                UIGraphicsPopContext()
                ctx.restoreGState()
            }
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return out.length > 0 ? out as Data : nil
    }
}
