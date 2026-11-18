import UIKit
import PDFKit

/// Make a scanned PDF searchable: read every page with on-device OCR and rebuild the file with an
/// invisible text layer laid exactly over the words — so Find, select and copy work in Preview, Files,
/// Acrobat, Chrome and mail. The pages look the same; they just gain real text.
enum PDFSearchable {
    /// Does this PDF already carry real text (so OCR would add little)?
    static func hasText(_ data: Data) -> Bool {
        let s = (PDFDocument(data: data)?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return s.count >= 20
    }

    /// OCR every page and rebuild. `progress` reports 0…1 as pages finish. Nil if the PDF can't be read
    /// or is password-locked.
    static func make(_ data: Data, maxWidth: CGFloat = 2000,
                     progress: ((Double) -> Void)? = nil) async -> (data: Data, words: Int)? {
        await Task.detached(priority: .userInitiated) { () -> (data: Data, words: Int)? in
            guard let doc = PDFDocument(data: data), doc.pageCount > 0, !doc.isLocked else { return nil }
            var images: [UIImage] = []
            var ocr: [[DocEngine.OCRLine]?] = []
            var words = 0
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                let img = render(page, maxWidth: maxWidth)
                let lines = DocEngine.recognize(img)
                words += lines.reduce(0) { $0 + $1.text.split(separator: " ").count }
                images.append(img); ocr.append(lines)
                progress?(Double(i + 1) / Double(doc.pageCount))
            }
            guard !images.isEmpty else { return nil }
            var opts = DocEngine.PDFOptions(); opts.searchable = true; opts.maxWidth = maxWidth
            guard let out = DocEngine.pdf(images: images, ocr: ocr, options: opts) else { return nil }
            return (out, words)
        }.value
    }

    /// One page as a sharp, upright image for OCR.
    static func render(_ page: PDFPage, maxWidth: CGFloat) -> UIImage {
        let b = page.bounds(for: .mediaBox)
        let scale = min(4, maxWidth / max(1, b.width))
        let size = CGSize(width: (b.width * scale).rounded(), height: (b.height * scale).rounded())
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
            c.cgContext.translateBy(x: 0, y: size.height); c.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: c.cgContext)
        }
    }
}
