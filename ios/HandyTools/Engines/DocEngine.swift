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

    /// Every piece of text on a photo, the way a careful person would read it:
    ///  • the photo the right way up (phone photos are often stored sideways with a "rotate" flag),
    ///  • small text kept (a dense whiteboard or schedule has lines far smaller than Vision's default minimum),
    ///  • a small or soft photo enlarged first,
    ///  • and when the first read is thin or unsure (glare, faint marker, handwriting), a second read on a
    ///    contrast-cleaned copy — tiled for big photos so every part is read at full size — whose new finds
    ///    are added where nothing was read before.
    static func recognize(_ image: UIImage) -> [OCRLine] {
        guard var cg = image.normalizedUp().cgImage else { return [] }
        let long = max(cg.width, cg.height)
        if long < 1600, let up = scaled(cg, by: min(3, 1600 / CGFloat(long))) { cg = up }
        var found = pass(cg)
        let sure = found.isEmpty ? 0 : found.map(\.1).reduce(0, +) / Float(found.count)
        if found.count < 12 || sure < 0.75 {
            var extra: [(OCRLine, Float)] = []
            if let clean = enhanced(cg) {
                extra += pass(clean)
                if max(clean.width, clean.height) >= 1800 { extra += tiles(clean) }
            }
            for (l, c) in extra where !found.contains(where: { overlap($0.0.box, l.box) > 0.3 }) { found.append((l, c)) }
        }
        return found.map(\.0)
    }

    private static func pass(_ cg: CGImage) -> [(OCRLine, Float)] {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        req.minimumTextHeight = 0.008
        if #available(iOS 16.0, *) { req.automaticallyDetectsLanguage = true }
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
        return (req.results ?? []).compactMap { obs in
            guard let top = obs.topCandidates(1).first, !top.string.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let b = obs.boundingBox
            return (OCRLine(text: top.string, box: CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height)), top.confidence)
        }
    }

    /// 2×2 overlapping tiles, each read at full size; boxes mapped back to the whole photo.
    private static func tiles(_ cg: CGImage) -> [(OCRLine, Float)] {
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        var out: [(OCRLine, Float)] = []
        for (tx, ty) in [(0.0, 0.0), (0.45, 0.0), (0.0, 0.45), (0.45, 0.45)] as [(CGFloat, CGFloat)] {
            let r = CGRect(x: tx * w, y: ty * h, width: 0.55 * w, height: 0.55 * h).integral
            guard let piece = cg.cropping(to: r) else { continue }
            for (l, c) in pass(piece) {
                let b = l.box
                // Drop pieces cut by the tile edge; the neighbouring tile or the full read has them whole.
                if (b.minX < 0.01 && tx > 0) || (b.maxX > 0.99 && tx == 0) || (b.minY < 0.01 && ty > 0) || (b.maxY > 0.99 && ty == 0) { continue }
                out.append((OCRLine(text: l.text, box: CGRect(x: tx + b.minX * 0.55, y: ty + b.minY * 0.55, width: b.width * 0.55, height: b.height * 0.55)), c))
            }
        }
        return out
    }

    /// Grey, evened out and sharpened: faint marker, glare and shadows read better.
    private static func enhanced(_ cg: CGImage) -> CGImage? {
        let ci = CIImage(cgImage: cg)
        let mono = ci.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.6])
        let even = mono.applyingFilter("CIHighlightShadowAdjust", parameters: ["inputHighlightAmount": 0.25, "inputShadowAmount": 0.6])
        let sharp = even.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 0.6])
        return ctx.createCGImage(sharp, from: ci.extent)
    }

    private static func scaled(_ cg: CGImage, by f: CGFloat) -> CGImage? {
        guard f > 1.05 else { return cg }
        let ci = CIImage(cgImage: cg).applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: f, kCIInputAspectRatioKey: 1])
        return ctx.createCGImage(ci, from: ci.extent.integral)
    }

    private static func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let i = a.intersection(b); guard !i.isNull, i.width > 0, i.height > 0 else { return 0 }
        return (i.width * i.height) / min(a.width * a.height, b.width * b.height)
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

    /// Pull the text out of a PDF for the PDF → text converter: the embedded text layer when the PDF
    /// has one (fast and exact), otherwise OCR each rendered page so even a scanned PDF yields text.
    static func pdfText(_ data: Data) -> String {
        guard let doc = PDFDocument(data: data), doc.pageCount > 0 else { return "" }
        if let s = doc.string?.trimmingCharacters(in: .whitespacesAndNewlines), s.count > 2 { return s }
        var out: [String] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let b = page.bounds(for: .mediaBox)
            let scale = min(3, 1600 / max(1, b.width))
            let size = CGSize(width: (b.width * scale).rounded(), height: (b.height * scale).rounded())
            let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
            let img = UIGraphicsImageRenderer(size: size, format: fmt).image { c in
                UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
                c.cgContext.translateBy(x: 0, y: size.height); c.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: c.cgContext)
            }
            let t = text(recognize(img))
            if !t.isEmpty { out.append(t) }
        }
        return out.joined(separator: "\n\n")
    }

    /// Render each page of a PDF to a standalone image for the PDF → image converter. Returns the
    /// encoded bytes per page — JPEG by default (small, universal) or PNG when `png` is set — using the
    /// same crisp, white-backed rasterization as `importPDF`. Empty only if the PDF can't be read.
    /// Which pages to convert: every page, the one on screen, or a from–to range (1-based, clamped, never empty).
    static func pageIndexes(all: Bool, current: Int, from: Int, to: Int, count: Int) -> [Int] {
        guard count > 0 else { return [] }
        if all { return Array(0..<count) }
        let a = max(1, min(from, to, count)), b = min(count, max(from, to, 1))
        return Array((a - 1)...(b - 1))
    }

    /// Image sizes by what the pictures are for. Width in pixels of a US Letter / A4 page.
    static let imageSizes: [(label: String, width: CGFloat)] = [("Small, for email", 1000), ("Sharp, for sharing", 1600), ("For printing (300 dpi)", 2550)]

    static func pdfToImages(_ data: Data, png: Bool = false, maxWidth: CGFloat = 1600, quality: CGFloat = 0.9, only: [Int]? = nil) -> [Data] {
        guard let doc = PDFDocument(data: data), doc.pageCount > 0 else { return [] }
        var out: [Data] = []
        for i in (only ?? Array(0..<doc.pageCount)) where i >= 0 && i < doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let b = page.bounds(for: .mediaBox)
            let scale = min(4.5, maxWidth / max(1, b.width))
            let size = CGSize(width: (b.width * scale).rounded(), height: (b.height * scale).rounded())
            let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
            let img = UIGraphicsImageRenderer(size: size, format: fmt).image { c in
                UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
                c.cgContext.translateBy(x: 0, y: size.height); c.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: c.cgContext)
            }
            if let d = png ? img.pngData() : img.jpegData(compressionQuality: quality) { out.append(d) }
        }
        return out
    }

    /// True redaction. Each page is rasterized, opaque black is painted over the chosen regions, and
    /// the PDF is rebuilt from the flattened pages — so the hidden text and images are genuinely gone,
    /// with no selectable layer left underneath (the mistake a drawn-on black box makes). `boxes[i]`
    /// are the regions to hide on page i, normalized top-left (0...1). The output pages are flattened
    /// images, so the whole document loses its text layer — the honest cost of guaranteed removal, and
    /// the UI states that before saving. Returns nil only if the PDF can't be read.
    static func redact(_ data: Data, boxes: [[CGRect]], maxWidth: CGFloat = 1600) -> Data? {
        guard let doc = PDFDocument(data: data), doc.pageCount > 0 else { return nil }
        var flattened: [UIImage] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let b = page.bounds(for: .mediaBox)
            let scale = min(3, maxWidth / max(1, b.width))
            let size = CGSize(width: (b.width * scale).rounded(), height: (b.height * scale).rounded())
            let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
            flattened.append(UIGraphicsImageRenderer(size: size, format: fmt).image { c in
                let cg = c.cgContext
                UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
                cg.saveGState()
                cg.translateBy(x: 0, y: size.height); cg.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: cg)
                cg.restoreGState()
                // Opaque redaction, baked into the raster (top-left origin) before re-encoding.
                UIColor.black.setFill()
                for nb in (i < boxes.count ? boxes[i] : []) {
                    c.fill(CGRect(x: nb.minX * size.width, y: nb.minY * size.height,
                                  width: nb.width * size.width, height: nb.height * size.height))
                }
            })
        }
        guard !flattened.isEmpty else { return nil }
        var opts = PDFOptions(); opts.searchable = false; opts.maxWidth = maxWidth
        return pdf(images: flattened, ocr: Array(repeating: nil, count: flattened.count), options: opts)
    }

    // MARK: annotate

    /// A mark laid on a page: a translucent highlighter sweep, or a freehand ink stroke. The rect and
    /// the stroke points are normalized top-left (0...1) to the page, so a mark drawn at one preview
    /// size lands in the same place when it is baked into the full-resolution page.
    struct Annotation: @unchecked Sendable {
        enum Kind { case highlight(CGRect), stroke(points: [CGPoint], width: CGFloat) }   // width: fraction of page width
        var kind: Kind
        var color: UIColor
    }

    /// Flatten highlighter + freehand marks into a PDF. Each page is rasterized, its marks are painted
    /// on — highlights with a multiply blend so the text underneath stays readable, strokes as solid
    /// ink — and the document is rebuilt from the flattened pages, so the marks are a permanent part of
    /// the file that shows in every reader (not a removable annotation layer). Unlike redaction, the
    /// text is not destroyed, so the rebuilt pages are re-OCR'd and keep a searchable/selectable text
    /// layer. `marks[i]` are the marks on page i. Returns nil only if the PDF can't be read.
    static func annotate(_ data: Data, marks: [[Annotation]], maxWidth: CGFloat = 1600) -> Data? {
        guard let doc = PDFDocument(data: data), doc.pageCount > 0 else { return nil }
        var flattened: [UIImage] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let b = page.bounds(for: .mediaBox)
            let scale = min(3, maxWidth / max(1, b.width))
            let size = CGSize(width: (b.width * scale).rounded(), height: (b.height * scale).rounded())
            let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
            flattened.append(UIGraphicsImageRenderer(size: size, format: fmt).image { c in
                let cg = c.cgContext
                UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
                cg.saveGState()
                cg.translateBy(x: 0, y: size.height); cg.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: cg)
                cg.restoreGState()
                // Marks are painted in the renderer's top-left pixel space (normalized → size), after the
                // page is drawn, so they sit on top exactly where the user placed them.
                for m in (i < marks.count ? marks[i] : []) { paint(m, in: size, context: cg) }
            })
        }
        guard !flattened.isEmpty else { return nil }
        let ocr: [[OCRLine]?] = flattened.map { recognize($0) }
        var opts = PDFOptions(); opts.searchable = true; opts.maxWidth = maxWidth
        return pdf(images: flattened, ocr: ocr, options: opts)
    }

    /// Paint one mark into the flattened page. Top-left pixel space; coordinates are the normalized
    /// mark scaled by `size`.
    private static func paint(_ m: Annotation, in size: CGSize, context cg: CGContext) {
        cg.saveGState()
        defer { cg.restoreGState() }
        switch m.kind {
        case .highlight(let r):
            cg.setBlendMode(.multiply)   // yellow × black text ≈ black (text survives); × white ≈ yellow
            m.color.withAlphaComponent(0.4).setFill()
            cg.fill(CGRect(x: r.minX * size.width, y: r.minY * size.height,
                           width: r.width * size.width, height: r.height * size.height))
        case .stroke(let pts, let wFrac):
            guard pts.count > 1 else { return }
            cg.setStrokeColor(m.color.cgColor)
            cg.setLineWidth(max(1, wFrac * size.width))
            cg.setLineCap(.round); cg.setLineJoin(.round)
            cg.beginPath()
            cg.move(to: CGPoint(x: pts[0].x * size.width, y: pts[0].y * size.height))
            for p in pts.dropFirst() { cg.addLine(to: CGPoint(x: p.x * size.width, y: p.y * size.height)) }
            cg.strokePath()
        }
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
        get {
            // Kept in the App Group so a tool run from the share sheet can sign too. A signature saved before
            // that move is copied across the first time it is read.
            let g = AppGroup.defaults
            if g.data(forKey: sigKey) == nil, let old = UserDefaults.standard.data(forKey: sigKey) { g.set(old, forKey: sigKey) }
            guard let img = g.data(forKey: sigKey).flatMap(UIImage.init(data:)) else { return nil }
            // A blank signature saved by the old dark-mode bug (white ink): drop it so the person is asked to sign again.
            if inkCoverage(img) < 0.004 { clearSignature(); return nil }
            return img
        }
    }
    /// Trim a PencilKit drawing to its ink and keep it as a transparent PNG.
    static func saveSignature(_ drawing: PKDrawing) -> UIImage? {
        // A dot or a stray tap isn't a signature.
        guard !drawing.strokes.isEmpty, drawing.bounds.width >= 30 || drawing.bounds.height >= 30 else { return nil }
        let b = drawing.bounds.insetBy(dx: -8, dy: -8)
        // Render in light mode: in dark mode PencilKit draws black ink as white, which saved an invisible signature.
        var img = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent { img = drawing.image(from: b, scale: 3) }
        guard inkCoverage(img) > 0.004 else { return nil }   // never keep a blank one
        AppGroup.defaults.set(img.pngData(), forKey: sigKey)
        return img
    }
    /// Keep a signature drawn or typed on the pad (any pen colour). nil for a blank or a dot.
    static func saveSignature(image img: UIImage) -> UIImage? {
        guard max(img.size.width, img.size.height) >= 40, visibleInk(img) > 0.004 else { return nil }
        AppGroup.defaults.set(img.pngData(), forKey: sigKey)
        return img
    }
    /// Share of the picture covered by ink of any colour.
    static func visibleInk(_ img: UIImage) -> Double {
        guard let cg = img.cgImage else { return 0 }
        let w = min(cg.width, 300), h = max(1, Int(Double(cg.height) * Double(w) / Double(max(cg.width, 1))))
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var n = 0
        for i in stride(from: 3, to: buf.count, by: 4) where buf[i] > 100 { n += 1 }
        return Double(n) / Double(w * h)
    }
    /// Share of the picture that is dark, visible ink (not white, not see-through).
    static func inkCoverage(_ img: UIImage) -> Double {
        guard let cg = img.cgImage else { return 0 }
        let w = min(cg.width, 300), h = max(1, Int(Double(cg.height) * Double(w) / Double(max(cg.width, 1))))
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var dark = 0
        for i in stride(from: 0, to: buf.count, by: 4) where buf[i + 3] > 100 {
            let a = Double(buf[i + 3]) / 255
            let lum = (Double(buf[i]) + Double(buf[i + 1]) + Double(buf[i + 2])) / 3 / max(a, 0.01)
            if lum < 140 { dark += 1 }
        }
        return Double(dark) / Double(w * h)
    }

    static func clearSignature() { UserDefaults.standard.removeObject(forKey: sigKey); AppGroup.defaults.removeObject(forKey: sigKey) }
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

/// Several PDFs made in one go, joined into one file in order. Used wherever a tool hands back 2+ PDFs (the run
/// screen for every ready-made and built tool, and the Share sheet), so the person can choose one PDF or many.
enum PDFMerge {
    /// True when every file is a PDF that can be joined (2 or more, none locked with a password).
    static func canMerge(_ urls: [URL]) -> Bool {
        guard urls.count > 1, urls.allSatisfy({ $0.pathExtension.lowercased() == "pdf" }) else { return false }
        return urls.allSatisfy { u in PDFDocument(url: u).map { !$0.isLocked && $0.pageCount > 0 } ?? false }
    }

    /// The pages of every file, in order, as one PDF written next to them. Nil if any file can't be read.
    static func merge(_ urls: [URL], name: String) -> URL? {
        let out = PDFDocument()
        for u in urls {
            guard let doc = PDFDocument(url: u), !doc.isLocked else { return nil }
            for i in 0..<doc.pageCount { if let p = doc.page(at: i)?.copy() as? PDFPage { out.insert(p, at: out.pageCount) } }
        }
        guard out.pageCount > 0, let dir = urls.first?.deletingLastPathComponent() else { return nil }
        let safe = name.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespaces)
        let url = dir.appendingPathComponent((safe.isEmpty ? "Combined" : safe) + ".pdf")
        guard out.write(to: url) else { return nil }
        return url
    }

    static func pageCount(_ url: URL) -> Int { PDFDocument(url: url)?.pageCount ?? 0 }
}
