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
    /// (top-left origin) coordinates of the displayed page. `info` carries passwords and permissions; `flatten`
    /// turns each finished page into a picture so nothing drawn on it can be lifted off in a PDF editor.
    static func rewrite(_ data: Data, info: [String: Any] = [:], flatten: Bool = false, decorate: (Int, CGSize, CGContext) -> Void) -> Data? {
        guard let doc = PDFDocument(data: data), doc.pageCount > 0, !doc.isLocked else { return nil }
        let out = NSMutableData()
        guard let consumer = CGDataConsumer(data: out as CFMutableData) else { return nil }
        var firstBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &firstBox, info.isEmpty ? nil : info as CFDictionary) else { return nil }
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let size = displaySize(page)
            var box = CGRect(origin: .zero, size: size)
            let pageInfo = [kCGPDFContextMediaBox as String: NSData(bytes: &box, length: MemoryLayout<CGRect>.size)] as CFDictionary
            ctx.beginPDFPage(pageInfo)
            if flatten, let pic = flattened(page, index: i, size: size, decorate: decorate) {
                ctx.draw(pic, in: box)
                ctx.endPDFPage()
                continue
            }
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

    /// The page and what's drawn on it as one JPEG picture (about 200 dpi), embedded as-is in the PDF.
    private static func flattened(_ page: PDFPage, index: Int, size: CGSize, decorate: (Int, CGSize, CGContext) -> Void) -> CGImage? {
        let k: CGFloat = 200 / 72
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = k; fmt.opaque = true
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { r in
            let c = r.cgContext
            UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
            c.saveGState()
            c.translateBy(x: 0, y: size.height); c.scaleBy(x: 1, y: -1)
            page.transform(c, for: .mediaBox)
            page.draw(with: .mediaBox, to: c)
            c.restoreGState()
            decorate(index, size, c)
        }
        guard let jpeg = img.jpegData(compressionQuality: 0.82), let provider = CGDataProvider(data: jpeg as CFData) else { return img.cgImage }
        return CGImage(jpegDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) ?? img.cgImage
    }
}

/// Password protection for PDFs, on device.
enum PDFSecure {
    /// Everything that can be done to protect one PDF, in one go: a watermark (diagonal, tiled or a footer line,
    /// in a colour, optionally naming who it's for so a leak can be traced), a password to open, blocking printing
    /// and copying, and burning the watermark in so it can't be edited out. Hidden details (author, app) are dropped.
    struct Protection: Equatable {
        enum Style: String, CaseIterable, Identifiable {
            case diagonal, tiled, footer
            var id: String { rawValue }
            var title: String { self == .diagonal ? "Diagonal" : (self == .tiled ? "Repeated" : "Bottom edge") }  // short: three fit a phone-width segmented control
        }
        var watermark = ""
        var style: Style = .diagonal
        var color: UInt32 = 0x808080
        var opacity: CGFloat = 0.18
        /// Who this copy is for — printed small on every page with today's date ("For Priya · 20 Nov 2026").
        var recipient = ""
        var openPassword = ""
        var allowPrinting = true
        var allowCopying = true
        var burnIn = false

        var hasWatermark: Bool { !watermark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var restricts: Bool { !allowPrinting || !allowCopying }
        var encrypts: Bool { !openPassword.isEmpty || restricts }
    }

    static let markColors: [UInt32] = [0x808080, 0xD32F2F, 0x1565C0, 0x111111]

    static func traceLine(_ who: String, on day: Date = Date()) -> String {
        let w = who.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty else { return "" }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return "\(L("For")) \(w) · \(f.string(from: day))"
    }

    /// Draw the watermark for one page (UIKit coordinates of the displayed page).
    static func drawMark(_ p: Protection, page i: Int, of n: Int, size: CGSize, day: Date = Date()) {
        let text = p.watermark.trimmingCharacters(in: .whitespacesAndNewlines)
        let col = UIColor(red: CGFloat((p.color >> 16) & 0xFF) / 255, green: CGFloat((p.color >> 8) & 0xFF) / 255, blue: CGFloat(p.color & 0xFF) / 255, alpha: 1)
        let ink = col.withAlphaComponent(min(max(p.opacity, 0.05), 0.6))
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let angle = -atan2(size.height, size.width)
        if !text.isEmpty {
            switch p.style {
            case .diagonal:
                let diagonal = (size.width * size.width + size.height * size.height).squareRoot()
                let fs = DocEngine.fontSize(for: text, width: diagonal * 0.7)
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: fs, weight: .bold), .foregroundColor: ink]
                let sz = (text as NSString).size(withAttributes: attrs)
                ctx.saveGState(); ctx.translateBy(x: size.width / 2, y: size.height / 2); ctx.rotate(by: angle)
                (text as NSString).draw(at: CGPoint(x: -sz.width / 2, y: -sz.height / 2), withAttributes: attrs)
                ctx.restoreGState()
            case .tiled:
                // A repeating pattern over the whole page — it can't be cropped or covered out of one corner.
                let line = [text, traceLine(p.recipient, on: day)].filter { !$0.isEmpty }.joined(separator: "  ·  ")
                let fs = max(9, size.width / 26)
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: fs, weight: .semibold), .foregroundColor: ink]
                let sz = (line as NSString).size(withAttributes: attrs)
                let span = (size.width * size.width + size.height * size.height).squareRoot()
                ctx.saveGState(); ctx.translateBy(x: size.width / 2, y: size.height / 2); ctx.rotate(by: angle)
                var y = -span / 2, row = 0
                while y < span / 2 {
                    var x = -span / 2 + (row % 2 == 0 ? 0 : (sz.width + fs * 3) / 2)
                    while x < span / 2 { (line as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs); x += sz.width + fs * 3 }
                    y += sz.height * 3.2; row += 1
                }
                ctx.restoreGState()
            case .footer:
                let fs = max(10, size.width / 34)
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: fs, weight: .bold), .foregroundColor: col.withAlphaComponent(min(1, p.opacity * 3)),
                                                            .kern: fs * 0.25]
                let sz = (text as NSString).size(withAttributes: attrs)
                (text as NSString).draw(at: CGPoint(x: (size.width - sz.width) / 2, y: size.height * 0.02), withAttributes: attrs)
                (text as NSString).draw(at: CGPoint(x: (size.width - sz.width) / 2, y: size.height - sz.height - size.height * 0.035), withAttributes: attrs)
            }
        }
        // Who it's for, small on every page, so a leaked copy says whose it was.
        let trace = traceLine(p.recipient, on: day)
        if !trace.isEmpty && !(p.style == .tiled && !text.isEmpty) {
            let fs = max(8, size.width / 60)
            let line = "\(trace) · \(L("Page")) \(i + 1)/\(n)"
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: fs, weight: .medium), .foregroundColor: col.withAlphaComponent(0.75)]
            let sz = (line as NSString).size(withAttributes: attrs)
            (line as NSString).draw(at: CGPoint(x: size.width - sz.width - size.width * 0.04, y: size.height - sz.height - size.height * 0.012), withAttributes: attrs)
        }
    }

    /// Apply a whole Protection in one pass. nil for an unreadable or locked file.
    static func apply(_ data: Data, _ p: Protection, day: Date = Date()) -> Data? {
        guard let doc = PDFDocument(data: data), !doc.isLocked else { return nil }
        let n = doc.pageCount
        var info: [String: Any] = [kCGPDFContextCreator as String: "Tenzy"]
        if p.encrypts {
            info[kCGPDFContextUserPassword as String] = p.openPassword
            // A separate owner password nobody knows, so the open password can't be used to lift the restrictions.
            info[kCGPDFContextOwnerPassword as String] = p.restricts ? UUID().uuidString + UUID().uuidString : p.openPassword
            info[kCGPDFContextAllowsPrinting as String] = p.allowPrinting
            info[kCGPDFContextAllowsCopying as String] = p.allowCopying
            info[kCGPDFContextEncryptionKeyLength as String] = 128
        }
        return PDFOverlay.rewrite(data, info: info, flatten: p.burnIn && p.hasWatermark) { i, size, _ in
            if p.hasWatermark { drawMark(p, page: i, of: n, size: size, day: day) }
        }
    }

    /// The first page with the watermark on it, exactly as it will be drawn — for the live preview.
    static func preview(_ data: Data, _ p: Protection, width: CGFloat = 900) -> UIImage? {
        guard let doc = PDFDocument(data: data), !doc.isLocked, let page = doc.page(at: 0) else { return nil }
        let size = PDFOverlay.displaySize(page)
        let k = width / max(size.width, 1)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = k; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { r in
            let c = r.cgContext
            UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
            c.saveGState(); c.translateBy(x: 0, y: size.height); c.scaleBy(x: 1, y: -1)
            page.transform(c, for: .mediaBox); page.draw(with: .mediaBox, to: c)
            c.restoreGState()
            if p.hasWatermark { drawMark(p, page: 0, of: doc.pageCount, size: size) }
        }
    }

    /// What the saved file really does, read back from it.
    struct Check: Equatable {
        var opensWithoutPassword: Bool
        var passwordOpens: Bool
        var printingAllowed: Bool
        var copyingAllowed: Bool
        var watermarkFound: Bool
        var pages: Int
    }
    static func check(_ data: Data, password: String, watermark: String) -> Check? {
        guard let doc = PDFDocument(data: data) else { return nil }
        let opensFree = !doc.isLocked
        var opens = opensFree
        if doc.isLocked { opens = doc.unlock(withPassword: password) }
        let w = watermark.trimmingCharacters(in: .whitespacesAndNewlines)
        let found = !w.isEmpty && opens && !(doc.findString(w, withOptions: .caseInsensitive).isEmpty)
        return Check(opensWithoutPassword: opensFree, passwordOpens: opens, printingAllowed: doc.allowsPrinting,
                     copyingAllowed: doc.allowsCopying, watermarkFound: found, pages: doc.pageCount)
    }

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
