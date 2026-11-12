import UIKit
import PDFKit
import Vision
import CoreText

/// The newer steps of Build your own: codes, web pages, text to PDF and the PDF steps. They run in the app and in the
/// share sheet. The steps that need the microphone's speech engine, a voice, a translator or the video encoder live in
/// ChainMedia, which only the app has.
extension Block {
    /// nil when this phone can run the step; otherwise one plain sentence saying why not. The builder still lists the
    /// step (greyed out, with the reason), and every other step stays usable.
    var unavailable: String? { ChainMedia.unavailable(self) }
}

extension Chain {
    /// nil when every step works on this phone; otherwise a sentence naming the first one that doesn't.
    var unavailable: String? {
        for s in steps { if let why = s.block.unavailable { return "\(s.block.title) isn't available on this phone. \(why)" } }
        return nil
    }
}

enum ChainExtras {
    typealias Outcome = Result<ChainPayload, ChainRunner.Failure>

    /// Steps the builder can't try on a sample (they need the network, a voice or a model, or a face or a clear
    /// subject the sample picture doesn't have), so it shows what each one does instead.
    static let noPreview: Set<Block> = [.pageText, .translate, .rewrite, .readAloud, .sticker, .emojiFaces]

    /// What "Read the page at a link" shows while a tool is being built, so no page is fetched for a preview.
    static let samplePage = "Example article\nThe words of the page appear here, without its menus, ads or buttons."

    /// nil when `step` is not one of these steps (the runner then reports the wrong input).
    static func apply(_ step: ChainStep, to input: ChainPayload, dryRun: Bool) async -> Outcome? {
        let b = step.block
        switch (b, input) {
        case (.readCode, .image(let img)):
            guard let code = readCode(img) else { return .failure(.invalid("Read a QR or barcode didn't find a code in it. Fill the frame with the code and try again.")) }
            return .success(.text(code))

        case (.pageText, .text(let t)):
            guard let link = ChainText.pageLink(in: t), let url = URL(string: link.replacingOccurrences(of: "http://", with: "https://")) else {
                return .failure(.invalid("Read the page at a link needs a web link, and didn't find one in that text."))
            }
            if dryRun { return .success(.text(samplePage)) }
            guard let html = await fetch(url) else {
                return .failure(.invalid("Read the page at a link couldn't open \(url.host ?? "that link"). Check the connection and try again."))
            }
            let words = ChainText.article(html: html)
            return words.isEmpty ? .failure(.invalid("Read the page at a link opened the page but found no words to read on it.")) : .success(.text(words))

        case (.textPdf, .text(let t)):
            let words = t.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !words.isEmpty else { return .failure(.nothingFound(b)) }
            return .success(.file(textPDF(words), ext: "pdf"))

        case (.pdfShrink, .file(let d, _)):
            guard PDFDocument(data: d) != nil else { return .failure(.invalid(cantOpen(b))) }
            // Best effort: the smallest copy that fits the limit, or the smallest one this PDF allows. Never bigger than it came in.
            var target = ChainText.pdfLimit(step.settings["mb"]) * 1_048_576
            while target < d.count {
                if let out = await SizeTarget.pdf(d, targetBytes: target), out.count < d.count { return .success(.file(out, ext: "pdf")) }
                target *= 2
            }
            return .success(.file(d, ext: "pdf"))

        case (.pdfLock, .file(let d, _)):
            let password = (step.settings["password"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !password.isEmpty else { return .failure(.invalid("Lock with a password needs a password. Edit the tool and type one in.")) }
            guard let doc = PDFDocument(data: d) else { return .failure(.invalid(cantOpen(b))) }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
            defer { try? FileManager.default.removeItem(at: url) }
            guard doc.write(to: url, withOptions: [.userPasswordOption: password, .ownerPasswordOption: password]), let out = try? Data(contentsOf: url) else { return .failure(.failed(b)) }
            return .success(.file(out, ext: "pdf"))

        case (.pdfPages, .file(let d, _)):
            guard let doc = PDFDocument(data: d), doc.pageCount > 0 else { return .failure(.invalid(cantOpen(b))) }
            let out = PDFDocument()
            for i in ChainText.pageList(step.settings["pages"] ?? "", count: doc.pageCount) {
                if let p = doc.page(at: i) { out.insert((p.copy() as? PDFPage) ?? p, at: out.pageCount) }
            }
            guard out.pageCount > 0, let data = out.dataRepresentation() else { return .failure(.failed(b)) }
            return .success(.file(data, ext: "pdf"))

        case (.pdfText, .file(let d, _)):
            guard let doc = PDFDocument(data: d), doc.pageCount > 0 else { return .failure(.invalid(cantOpen(b))) }
            var words = (doc.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if words.isEmpty {
                // A scan has no words of its own, so read its pages as pictures (the first 20).
                words = (0..<min(doc.pageCount, 20)).compactMap { doc.page(at: $0) }.map { ChainRunner.rows(DocEngine.recognize(picture(of: $0))) }
                    .joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return words.isEmpty ? .failure(.invalid("Read the PDF's words found no words in that PDF.")) : .success(.text(words))

        default:
            // The playful picture steps run anywhere; the rest need parts only the app has.
            if let fun = ChainFun.apply(step, to: input, dryRun: dryRun) { return fun }
            return await ChainMedia.apply(step, to: input, dryRun: dryRun)
        }
    }

    private static func cantOpen(_ b: Block) -> String { "\(b.title) couldn't open that PDF. It may be damaged or locked with a password." }

    // MARK: codes

    /// What a QR code or barcode in the picture says. A QR code wins when the picture holds both.
    static func readCode(_ image: UIImage) -> String? {
        // A code cropped right to its edge often isn't found, so it gets a white border first.
        let src = image.normalizedUp()
        let pad = max(32, src.size.width * 0.08)
        let size = CGSize(width: src.size.width + pad * 2, height: src.size.height + pad * 2)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let padded = UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
            src.draw(in: CGRect(x: pad, y: pad, width: src.size.width, height: src.size.height))
        }
        guard let cg = padded.cgImage else { return nil }
        for revision in [VNDetectBarcodesRequest.currentRevision, VNDetectBarcodesRequestRevision1] {
            let request = VNDetectBarcodesRequest()
            request.revision = revision
            try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([request])
            let found = (request.results ?? []).filter { !($0.payloadStringValue ?? "").isEmpty }
            if let hit = found.first(where: { $0.symbology == .qr }) ?? found.first { return hit.payloadStringValue }
        }
        return nil
    }

    // MARK: web pages

    /// The page's HTML. Only the page the person asked for is fetched; nothing is sent besides the request itself.
    static func fetch(_ url: URL) async -> String? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Mozilla/5.0 (Mobile) Tenzy", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        guard data.count < 6_000_000 else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }

    // MARK: PDFs

    /// Plain text laid out on A4 pages with comfortable margins, as many pages as it needs (up to 300).
    static func textPDF(_ text: String) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let box = page.insetBy(dx: 54, dy: 60)
        let style = NSMutableParagraphStyle(); style.lineSpacing = 3; style.paragraphSpacing = 8
        let words = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.black, .paragraphStyle: style])
        let setter = CTFramesetterCreateWithAttributedString(words as CFAttributedString)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            var at = 0, pages = 0
            while at < words.length, pages < 300 {
                ctx.beginPage()
                let cg = ctx.cgContext
                cg.saveGState()
                cg.textMatrix = .identity
                cg.translateBy(x: 0, y: page.height)
                cg.scaleBy(x: 1, y: -1)
                let path = CGPath(rect: CGRect(x: box.minX, y: page.height - box.maxY, width: box.width, height: box.height), transform: nil)
                let frame = CTFramesetterCreateFrame(setter, CFRange(location: at, length: 0), path, nil)
                CTFrameDraw(frame, cg)
                cg.restoreGState()
                let shown = CTFrameGetVisibleStringRange(frame).length
                if shown <= 0 { break }
                at += shown; pages += 1
            }
        }
    }

    /// One PDF page as a picture sharp enough to read (long side about 2000 px).
    static func picture(of page: PDFPage) -> UIImage {
        let b = page.bounds(for: .mediaBox)
        let scale = min(3, 2000 / max(b.width, b.height, 1))
        let size = CGSize(width: max(1, b.width * scale), height: max(1, b.height * scale))
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1; f.opaque = true
        return UIGraphicsImageRenderer(size: size, format: f).image { c in
            UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
            c.cgContext.translateBy(x: 0, y: size.height)
            c.cgContext.scaleBy(x: scale, y: -scale)
            c.cgContext.translateBy(x: -b.minX, y: -b.minY)
            page.draw(with: .mediaBox, to: c.cgContext)
        }
    }
}
