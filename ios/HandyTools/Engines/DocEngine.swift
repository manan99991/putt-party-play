import UIKit
import PDFKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreText
import PencilKit

/// The document engine behind Scan: page cleanup (enhance / grayscale / black-and-white), rotation,
/// ink + stamps (signature, typed text), OCR, and PDF output with a real invisible text layer so the
/// result is searchable and selectable in every PDF reader — the thing Notes/Files scans never give you.
enum DocEngine {

    // MARK: model

    enum Filter: Int, CaseIterable { case color, enhance, gray, bw
        var title: String { ["Original", "Enhance", "Grayscale", "Black & white"][rawValue] } }

    enum PageSize: Int, CaseIterable { case auto, letter, a4
        var title: String { ["Auto", "US Letter", "A4"][rawValue] }
        var points: CGSize? { switch self { case .auto: return nil; case .letter: return CGSize(width: 612, height: 792); case .a4: return CGSize(width: 595, height: 842) } } }

    /// Something laid on a page: a saved signature image or a typed line. Position and size are
    /// normalized to the page so they survive different preview sizes.
    struct Stamp: Identifiable, Equatable, @unchecked Sendable {
        enum Kind: Equatable { case text(String), signature(UIImage) }
        let id = UUID()
        var kind: Kind
        var center: CGPoint = CGPoint(x: 0.5, y: 0.5)   // normalized 0–1
        var width: CGFloat = 0.35                        // fraction of page width
        var color: UIColor = .black
    }

    struct Page: Identifiable, @unchecked Sendable {
        let id = UUID()
        var source: UIImage              // upright, as captured/imported
        var rotation = 0                 // quarter turns clockwise
        var filter: Filter = .enhance
        var ink = PKDrawing()
        var inkCanvas = CGSize.zero      // canvas size `ink` was drawn in (points)
        var stamps: [Stamp] = []
        var ocr: [OCRLine]? = nil        // cached recognition of the cleaned page

        /// Cleaned + rotated, no ink/stamps — what the user sees under the overlays.
        var cleaned: UIImage { DocEngine.clean(source, filter: filter).rotated(quarterTurns: rotation) }
    }

    struct OCRLine { let text: String; let box: CGRect }   // box normalized, top-left origin

    // MARK: cleanup

    nonisolated(unsafe) private static let ctx = CIContext(options: [.useSoftwareRenderer: false])

    static func clean(_ image: UIImage, filter: Filter) -> UIImage {
        guard filter != .color, let cg = image.normalizedUp().cgImage else { return image.normalizedUp() }
        var ci = CIImage(cgImage: cg)
        let enh = CIFilter.documentEnhancer(); enh.inputImage = ci; enh.amount = 1.0
        ci = enh.outputImage ?? ci
        if filter == .gray || filter == .bw {
            let cc = CIFilter.colorControls(); cc.inputImage = ci; cc.saturation = 0; cc.contrast = 1.15
            ci = cc.outputImage ?? ci
        }
        if filter == .bw {
            let th = CIFilter.colorThreshold(); th.inputImage = ci; th.threshold = 0.55
            ci = th.outputImage ?? ci
        }
        guard let out = ctx.createCGImage(ci, from: CGRect(origin: .zero, size: CGSize(width: cg.width, height: cg.height))) else { return image }
        return UIImage(cgImage: out)
    }

    // MARK: OCR

    static func recognize(_ image: UIImage) -> [OCRLine] {
        guard let cg = image.cgImage else { return [] }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
        return (req.results ?? []).compactMap { obs in
            guard let top = obs.topCandidates(1).first else { return nil }
            let b = obs.boundingBox
            return OCRLine(text: top.string, box: CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height))
        }
    }

    static func text(_ lines: [OCRLine]) -> String { lines.map(\.text).joined(separator: "\n") }

    // MARK: render

    /// Final flattened page: cleaned + rotated image with ink and stamps burned in.
    static func render(_ page: Page) -> UIImage {
        let base = page.cleaned
        let size = CGSize(width: base.size.width * base.scale, height: base.size.height * base.scale)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            base.draw(in: CGRect(origin: .zero, size: size))
            if page.inkCanvas.width > 0, !page.ink.bounds.isEmpty {
                let s = size.width / page.inkCanvas.width
                let img = page.ink.image(from: CGRect(origin: .zero, size: page.inkCanvas), scale: s)
                img.draw(in: CGRect(origin: .zero, size: size))
            }
            for st in page.stamps { draw(st, in: size, context: c.cgContext) }
        }
    }

    static func draw(_ st: Stamp, in size: CGSize, context cg: CGContext) {
        let w = st.width * size.width
        switch st.kind {
        case .signature(let img):
            let h = w * img.size.height / max(1, img.size.width)
            img.draw(in: CGRect(x: st.center.x * size.width - w / 2, y: st.center.y * size.height - h / 2, width: w, height: h))
        case .text(let s):
            let fs = fontSize(for: s, width: w)
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: fs, weight: .regular), .foregroundColor: st.color]
            let sz = (s as NSString).size(withAttributes: attrs)
            (s as NSString).draw(at: CGPoint(x: st.center.x * size.width - sz.width / 2, y: st.center.y * size.height - sz.height / 2), withAttributes: attrs)
        }
    }

    /// Font size so `s` spans about `width` points.
    static func fontSize(for s: String, width: CGFloat) -> CGFloat {
        let probe = (s as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 100)])
        return max(6, 100 * width / max(1, probe.width))
    }

    // MARK: PDF

    struct PDFOptions { var searchable = true; var pageSize: PageSize = .auto; var maxWidth: CGFloat = 1600; var quality: CGFloat = 0.8 }

    /// Multi-page PDF. With `searchable`, each page gets an invisible text layer positioned over the
    /// recognized words, so find/select/copy work in Preview, Acrobat, Chrome and mail clients.
    static func pdf(_ pages: [Page], options: PDFOptions) -> Data? {
        guard !pages.isEmpty else { return nil }
        let rendered = pages.map { render($0) }
        let ocr: [[OCRLine]?] = pages.enumerated().map { i, p in options.searchable ? (p.ocr ?? recognize(rendered[i])) : nil }
        return pdf(images: rendered, ocr: ocr, options: options)
    }

    static func pdf(images: [UIImage], ocr: [[OCRLine]?], options: PDFOptions) -> Data? {
        let first = images.first.map { pageRect(for: $0, size: options.pageSize) } ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        let fmt = UIGraphicsPDFRendererFormat()
        fmt.documentInfo = [kCGPDFContextCreator as String: "Tenzy Scan"]
        return UIGraphicsPDFRenderer(bounds: first, format: fmt).pdfData { ctx in
            for (i, img) in images.enumerated() {
                let box = pageRect(for: img, size: options.pageSize)
                ctx.beginPage(withBounds: box, pageInfo: [:])
                let small = img.resized(maxDimension: options.maxWidth)
                let jpegBacked = small.jpegData(compressionQuality: options.quality).flatMap(UIImage.init(data:)) ?? small
                let dest = fit(img.size, in: box.insetBy(dx: options.pageSize == .auto ? 0 : 18, dy: options.pageSize == .auto ? 0 : 18))
                jpegBacked.draw(in: dest)
                if let lines = ocr[i] { drawInvisible(lines, in: dest, on: ctx.cgContext) }
            }
        }
    }

    private static func pageRect(for img: UIImage, size: PageSize) -> CGRect {
        if let p = size.points { return CGRect(origin: .zero, size: p) }
        let w: CGFloat = 612
        return CGRect(x: 0, y: 0, width: w, height: (w * img.size.height / max(1, img.size.width)).rounded())
    }

    private static func fit(_ s: CGSize, in r: CGRect) -> CGRect {
        let k = min(r.width / s.width, r.height / s.height)
        let w = s.width * k, h = s.height * k
        return CGRect(x: r.midX - w / 2, y: r.midY - h / 2, width: w, height: h)
    }

    /// Core Text with text-drawing-mode "invisible": zero pixels, but the glyphs are in the content
    /// stream exactly where the words sit, so selection and search line up with the image.
    private static func drawInvisible(_ lines: [OCRLine], in dest: CGRect, on cg: CGContext) {
        for l in lines where !l.text.isEmpty {
            let r = CGRect(x: dest.minX + l.box.minX * dest.width, y: dest.minY + l.box.minY * dest.height,
                           width: l.box.width * dest.width, height: l.box.height * dest.height)
            let fs = max(2, r.height * 0.8)
            let attr = NSAttributedString(string: l.text, attributes: [.font: UIFont.systemFont(ofSize: fs)])
            let line = CTLineCreateWithAttributedString(attr)
            var asc: CGFloat = 0, desc: CGFloat = 0
            let w = CGFloat(CTLineGetTypographicBounds(line, &asc, &desc, nil))
            guard w > 0 else { continue }
            cg.saveGState()
            cg.setTextDrawingMode(.invisible)
            cg.textMatrix = .identity
            cg.translateBy(x: r.minX, y: r.maxY - desc)
            cg.scaleBy(x: r.width / w, y: -1)
            CTLineDraw(line, cg)
            cg.restoreGState()
        }
    }

    /// Re-encode with a quality/size ladder until under `targetBytes`, keeping the text layer.
    static func pdfUnder(_ pages: [Page], targetBytes: Int, base: PDFOptions) -> Data? {
        let rendered = pages.map { render($0) }
        let ocr: [[OCRLine]?] = pages.enumerated().map { i, p in base.searchable ? (p.ocr ?? recognize(rendered[i])) : nil }
        let ladder: [(CGFloat, CGFloat)] = [(1600, 0.8), (1400, 0.6), (1200, 0.5), (1000, 0.4), (800, 0.35), (640, 0.3), (480, 0.25)]
        for (w, q) in ladder {
            var o = base; o.maxWidth = min(o.maxWidth, w); o.quality = q
            if let d = pdf(images: rendered, ocr: ocr, options: o), d.count <= targetBytes { return d }
        }
        return nil
    }

    /// Pages from an existing PDF, rendered crisp enough to re-OCR (capped width).
    static func importPDF(_ url: URL, maxWidth: CGFloat = 1600) -> [UIImage] {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let doc = PDFDocument(url: url) else { return [] }
        var out: [UIImage] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let b = page.bounds(for: .mediaBox)
            let scale = min(3, maxWidth / max(1, b.width))
            let size = CGSize(width: (b.width * scale).rounded(), height: (b.height * scale).rounded())
            let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
            out.append(UIGraphicsImageRenderer(size: size, format: fmt).image { c in
                UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
                c.cgContext.translateBy(x: 0, y: size.height); c.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: c.cgContext)
            })
        }
        return out
    }

    /// Split a finished PDF into the given 1-based inclusive page ranges ("1-3", "4", "5-").
    static func split(_ data: Data, ranges spec: String) -> [Data] {
        guard let doc = PDFDocument(data: data), doc.pageCount > 0 else { return [] }
        let n = doc.pageCount
        var parts: [ClosedRange<Int>] = []
        for piece in spec.split(separator: ",") {
            let t = piece.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { continue }
            if t.contains("-") {
                let bits = t.split(separator: "-", omittingEmptySubsequences: false).map { Int($0.trimmingCharacters(in: .whitespaces)) }
                let lo = bits.first?.flatMap { $0 } ?? 1, hi = (bits.count > 1 ? bits[1] : nil) ?? n
                if lo >= 1, hi <= n, lo <= hi { parts.append(lo...hi) }
            } else if let p = Int(t), p >= 1, p <= n { parts.append(p...p) }
        }
        if parts.isEmpty { parts = (1...n).map { $0...$0 } }   // "each page separately"
        return parts.compactMap { r in
            let d = PDFDocument()
            for p in r { if let pg = doc.page(at: p - 1) { d.insert(pg, at: d.pageCount) } }
            return d.dataRepresentation()
        }
    }

    // MARK: saved signature

    private static let sigKey = "tenzy.scan.signature.png"
    static var savedSignature: UIImage? {
        get { UserDefaults.standard.data(forKey: sigKey).flatMap(UIImage.init(data:)) }
    }
    /// Trim a PencilKit drawing to its ink and keep it as a transparent PNG.
    static func saveSignature(_ drawing: PKDrawing) -> UIImage? {
        let b = drawing.bounds.insetBy(dx: -8, dy: -8)
        guard !b.isEmpty else { return nil }
        let img = drawing.image(from: b, scale: 3)
        UserDefaults.standard.set(img.pngData(), forKey: sigKey)
        return img
    }
    static func clearSignature() { UserDefaults.standard.removeObject(forKey: sigKey) }
}

extension UIImage {
    /// Rotate by quarter turns clockwise, re-rasterizing so `.cgImage` is upright.
    func rotated(quarterTurns: Int) -> UIImage {
        let q = ((quarterTurns % 4) + 4) % 4
        guard q != 0 else { return self }
        let src = normalizedUp()
        let w = src.size.width * src.scale, h = src.size.height * src.scale
        let out = (q % 2 == 1) ? CGSize(width: h, height: w) : CGSize(width: w, height: h)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: out, format: fmt).image { c in
            let cg = c.cgContext
            cg.translateBy(x: out.width / 2, y: out.height / 2)
            cg.rotate(by: CGFloat(q) * .pi / 2)
            src.draw(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        }
    }
}
