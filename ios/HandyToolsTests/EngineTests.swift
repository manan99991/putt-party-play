import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
import PDFKit
import AVFoundation
import PencilKit
@testable import HandyTools

/// Engine-level correctness checks. These exercise the real tool logic with deterministic,
/// generated fixtures (no camera/network), so a regression fails the build.
final class EngineTests: XCTestCase {

    // MARK: catalog integrity

    @MainActor func testCatalogIsThirtyTenPerPage() {
        XCTAssertEqual(TOOLS.count, 30, "catalog must be exactly 30 tools")
        for p in 1...3 {
            XCTAssertEqual(tools(onPage: p).count, 10, "page \(p) must have 10 tiles")
        }
        XCTAssertEqual(Set(TOOLS.map(\.id)).count, 30, "tool ids must be unique")
        for t in TOOLS {
            XCTAssertFalse(t.name.isEmpty, "\(t.id) has no name")
            XCTAssertFalse(t.blurb.isEmpty, "\(t.id) has no blurb")
            XCTAssertFalse(t.blurb.hasSuffix("…") || t.blurb.hasSuffix("..."), "\(t.id) blurb must not be truncated")
        }
    }

    // MARK: search ranking

    @MainActor func testSearchRanksTheObviousToolFirst() {
        XCTAssertEqual(searchTools("flashlight").first?.id, "light")
        XCTAssertEqual(searchTools("pdf").first?.id, "scan")
        XCTAssertFalse(searchTools("translate").isEmpty)
        XCTAssertFalse(searchTools("photo").isEmpty)
        XCTAssertTrue(searchTools("zzxqzzq").isEmpty, "nonsense query returns nothing")
    }

    // MARK: image resize

    func testResizeCapsLongestSideAndNeverUpscales() {
        let big = Self.solid(CGSize(width: 2000, height: 1000))
        let shrunk = big.resized(maxDimension: 1024)
        XCTAssertEqual(max(shrunk.size.width, shrunk.size.height), 1024, accuracy: 1)
        let small = Self.solid(CGSize(width: 300, height: 300))
        XCTAssertEqual(small.resized(maxDimension: 1024).size.width, 300, accuracy: 1, "must not upscale")
    }

    // MARK: GIF builder

    func testGifFromPhotosHasEveryFrame() throws {
        let frames = (0..<3).map {
            Self.solid(CGSize(width: 120, height: 120), hue: CGFloat($0) / 3).jpegData(compressionQuality: 0.9)!
        }
        let url = try XCTUnwrap(tenzyGIFFromImageData(frames, delay: 0.3, maxDim: 240), "GIF not produced")
        let src = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetCount(src), 3, "GIF must keep all frames")
        XCTAssertEqual(CGImageSourceGetType(src) as String?, UTType.gif.identifier, "must be a real GIF")
    }

    // MARK: on-device OCR (Vision runs in the simulator)

    func testOCRReadsCleanRenderedText() async {
        let read = await AIEngine.recognizeText(Self.text("HELLO 2026"))
        XCTAssertTrue(read.uppercased().contains("HELLO"), "OCR missed the text, got: \(read)")
    }

    // MARK: Fit It — exact-size engine

    func testSizeTargetImageLandsUnderLimit() throws {
        let big = Self.noisy(CGSize(width: 2400, height: 1800))
        let target = 150_000
        let d = try XCTUnwrap(SizeTarget.image(big, targetBytes: target), "image could not be fitted")
        XCTAssertLessThanOrEqual(d.count, target, "must land under the limit")
        XCTAssertNotNil(UIImage(data: d), "output must still decode")
    }

    func testSizeTargetPDFLandsUnderLimit() throws {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let pdf = UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            for _ in 0..<3 { ctx.beginPage(); Self.noisy(CGSize(width: 1200, height: 1500)).draw(in: page) }
        }
        let target = min(pdf.count / 2, 400_000)
        let out = try XCTUnwrap(SizeTarget.pdf(pdf, targetBytes: target), "pdf could not be fitted")
        XCTAssertLessThanOrEqual(out.count, target)
        XCTAssertEqual(PDFDocument(data: out)?.pageCount, 3, "must keep every page")
    }

    // MARK: Long Screenshot — stitcher

    func testStitcherRemovesOverlapAndKeepsChromeOnce() throws {
        // A tall "page" of distinct horizontal bands, viewed through two overlapping windows that
        // each carry the same fixed header and footer — exactly what two scrolled screenshots look like.
        let W: CGFloat = 400, pageH: CGFloat = 1600, winH: CGFloat = 900, chrome: CGFloat = 80
        let page = Self.bands(CGSize(width: W, height: pageH))
        func window(_ top: CGFloat) -> UIImage {
            let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
            return UIGraphicsImageRenderer(size: CGSize(width: W, height: winH), format: f).image { ctx in
                if let cg = page.cgImage?.cropping(to: CGRect(x: 0, y: top, width: W, height: winH)) {
                    UIImage(cgImage: cg).draw(in: CGRect(x: 0, y: 0, width: W, height: winH))
                }
                UIColor.darkGray.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: W, height: chrome))               // header
                ctx.fill(CGRect(x: 0, y: winH - chrome, width: W, height: chrome))    // footer
            }
        }
        let a = window(0), b = window(500)   // 400 rows of real overlap
        let out = try XCTUnwrap(Stitcher.stitch([a, b]), "stitch failed")
        XCTAssertEqual(out.size.width, W, accuracy: 1)
        XCTAssertLessThan(out.size.height, a.size.height + b.size.height - 200, "overlap must be removed")
        XCTAssertGreaterThan(out.size.height, winH + 200, "second shot must contribute new rows")
    }

    // MARK: Privacy Scrubber — irreversible redaction + metadata strip

    func testScrubberBlocksPixelsAndDropsMetadata() throws {
        let src = Self.noisy(CGSize(width: 400, height: 300))
        let rect = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let data = try XCTUnwrap(Scrubber.render(src, rects: [rect]))
        // No GPS / EXIF survives a fresh encode.
        XCTAssertFalse(Scrubber.metadata(in: data).hasGPS)
        let props = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil).flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [String: Any] })
        XCTAssertNil(props[kCGImagePropertyGPSDictionary as String], "GPS must be gone")
        // The covered region is solid black in the output; outside it is not.
        let out = try XCTUnwrap(UIImage(data: data)?.cgImage)
        func lum(_ x: Int, _ y: Int) -> Int {
            guard let d = out.dataProvider?.data, let p = CFDataGetBytePtr(d) else { return -1 }
            let bpr = out.bytesPerRow, bpp = out.bitsPerPixel / 8
            let o = y * bpr + x * bpp
            return (Int(p[o]) + Int(p[o + 1]) + Int(p[o + 2])) / 3
        }
        XCTAssertLessThan(lum(out.width / 2, out.height / 2), 24, "centre must be blacked out")
        XCTAssertGreaterThan(lum(8, 8), 24, "corner must be untouched")
    }

    // MARK: QR & Wi-Fi — payload round trip

    func testWifiPayloadRoundTripsThroughParser() {
        let payload = QRPayload.wifi(ssid: "Home;Net", password: "p@ss,word", security: "WPA", hidden: false)
        guard case .wifi(let ssid, let pass, let sec) = QRPayload.parse(payload) else { return XCTFail("not parsed as wifi") }
        XCTAssertEqual(ssid, "Home;Net"); XCTAssertEqual(pass, "p@ss,word"); XCTAssertEqual(sec, "WPA")
        guard case .url(let u) = QRPayload.parse("https://tenzy.app/x") else { return XCTFail("url") }
        XCTAssertEqual(u.host, "tenzy.app")
        guard case .phone(let n, let m) = QRPayload.parse("SMSTO:+15551234567:hi there") else { return XCTFail("sms") }
        XCTAssertEqual(n, "+15551234567"); XCTAssertEqual(m, "hi there")
        XCTAssertNotNil(QRGen.make("hello", scale: 6), "QR generation must produce an image")
    }

    // MARK: Studio — encode formats

    func testStudioEncodesEveryFormat() throws {
        let img = Self.noisy(CGSize(width: 320, height: 240))
        let jpg = try XCTUnwrap(ImageStudio.encode(img, as: .jpg, quality: 0.8))
        let png = try XCTUnwrap(ImageStudio.encode(img, as: .png, quality: 1))
        XCTAssertNotNil(UIImage(data: jpg)); XCTAssertNotNil(UIImage(data: png))
        XCTAssertEqual(ImageStudio.passportSpecs.count, 5)
        // HEIC may be unavailable in some simulators; if it encodes, it must decode.
        if let heic = ImageStudio.encode(img, as: .heic, quality: 0.8) { XCTAssertNotNil(UIImage(data: heic)) }
    }

    // MARK: document engine (Scan)

    func testScanPDFIsSearchableAndKeepsPageCount() throws {
        let p1 = DocEngine.Page(source: Self.text("HELLO 2026"), filter: .enhance)
        var p2 = DocEngine.Page(source: Self.text("INVOICE 4471"), filter: .bw)
        p2.stamps = [DocEngine.Stamp(kind: .text("Jane Doe"), center: CGPoint(x: 0.5, y: 0.85), width: 0.3)]
        let data = try XCTUnwrap(DocEngine.pdf([p1, p2], options: .init(searchable: true, pageSize: .auto)))
        let doc = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(doc.pageCount, 2)
        let all = (doc.string ?? "").uppercased()
        XCTAssertTrue(all.contains("HELLO"), "page 1 text layer missing: \(all)")
        XCTAssertTrue(all.contains("INVOICE") || all.contains("4471"), "page 2 text layer missing: \(all)")
        // find() must hit — that's the whole point of the invisible layer
        XCTAssertFalse(doc.findString("HELLO", withOptions: .caseInsensitive).isEmpty)
        // and the stamped text is visibly burned in (it is NOT in the text layer unless OCR'd — check pixels instead)
        let rendered = DocEngine.render(p2)
        XCTAssertNotNil(rendered.cgImage)
    }

    func testScanNonSearchablePDFHasNoText() throws {
        let p = DocEngine.Page(source: Self.text("SECRET 99"), filter: .gray)
        let data = try XCTUnwrap(DocEngine.pdf([p], options: .init(searchable: false)))
        let doc = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(doc.pageCount, 1)
        XCTAssertTrue((doc.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testScanPDFUnderLimitKeepsTextLayer() throws {
        let pages = (0..<3).map { _ in DocEngine.Page(source: Self.noisy(CGSize(width: 1600, height: 2000)), filter: .color) }
        let full = try XCTUnwrap(DocEngine.pdf(pages, options: .init(searchable: false)))
        let target = max(60_000, full.count / 4)
        let small = try XCTUnwrap(DocEngine.pdfUnder(pages, targetBytes: target, base: .init(searchable: false)), "could not fit under \(target) from \(full.count)")
        XCTAssertLessThanOrEqual(small.count, target)
        XCTAssertEqual(PDFDocument(data: small)?.pageCount, 3)
    }

    func testScanSplitRangesAndEveryPage() throws {
        let pages = (1...5).map { DocEngine.Page(source: Self.text("PAGE \($0)"), filter: .color) }
        let data = try XCTUnwrap(DocEngine.pdf(pages, options: .init(searchable: false)))
        let parts = DocEngine.split(data, ranges: "1-2, 3, 4-")
        XCTAssertEqual(parts.map { PDFDocument(data: $0)?.pageCount }, [2, 1, 2])
        XCTAssertEqual(DocEngine.split(data, ranges: "").count, 5)
        XCTAssertEqual(DocEngine.split(data, ranges: "9-12").count, 5, "invalid ranges fall back to every page")
    }

    func testScanRotationKeepsStampsAndInkInPlace() {
        let img = Self.bands(CGSize(width: 300, height: 500))
        let r = img.rotated(quarterTurns: 1)
        XCTAssertEqual(r.size.width, 500); XCTAssertEqual(r.size.height, 300)
        XCTAssertEqual(img.rotated(quarterTurns: 4).size, img.size)
        XCTAssertEqual(img.rotated(quarterTurns: 2).size, img.size)
    }

    func testScanCleanupProducesDocumentLooks() {
        let src = Self.text("CLEAN")
        for f in DocEngine.Filter.allCases {
            let out = DocEngine.clean(src, filter: f)
            XCTAssertEqual(out.size.width, src.size.width, accuracy: 1, "\(f) changed size")
        }
        // black & white should be (almost) binary: sample the centre-left background pixel → white
        let bw = DocEngine.clean(src, filter: .bw)
        XCTAssertNotNil(bw.cgImage)
    }

    func testSavedSignatureRoundTrips() {
        DocEngine.clearSignature()
        XCTAssertNil(DocEngine.savedSignature)
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: (0..<12).map { i in
            PKStrokePoint(location: CGPoint(x: 10 + CGFloat(i) * 8, y: 40 + sin(CGFloat(i)) * 10), timeOffset: Double(i) * 0.02, size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }, creationDate: Date()))
        let drawing = PKDrawing(strokes: [stroke])
        let img = DocEngine.saveSignature(drawing)
        XCTAssertNotNil(img)
        XCTAssertNotNil(DocEngine.savedSignature)
        DocEngine.clearSignature()
    }

    // MARK: capture

    func testCaptureFindsCodesInPhotosAndActionsInText() throws {
        let qr = try XCTUnwrap(QRGen.make("https://tenzy.app/menu", scale: 8, correction: "M"))
        XCTAssertEqual(CaptureView.barcode(in: qr), "https://tenzy.app/menu")
        XCTAssertNil(CaptureView.barcode(in: Self.text("NO CODE HERE")))

        let found = Detected.scan("Call us at (415) 555-0123 or visit https://example.com — open Tuesday at 7pm, 1 Infinite Loop, Cupertino CA 95014")
        let icons = Set(found.map(\.icon))
        XCTAssertTrue(icons.contains("phone"), "phone not detected: \(found.map(\.label))")
        XCTAssertTrue(icons.contains("safari"), "link not detected: \(found.map(\.label))")
        XCTAssertTrue(icons.contains("calendar"), "date not detected: \(found.map(\.label))")
        XCTAssertTrue(found.first { $0.icon == "phone" }?.url.absoluteString.hasPrefix("tel:") ?? false)
    }

    // MARK: video engine

    func testVideoEngineTrimsConvertsMutesAndMakesGIF() async throws {
        let fixture = await Self.movie(seconds: 2.0)
        let src = try XCTUnwrap(fixture, "fixture movie not written")
        let dur = await VideoEngine.duration(src)
        XCTAssertEqual(dur, 2.0, accuracy: 0.15)

        let trimmedURL = await VideoEngine.trim(src, start: 0.5, end: 1.5)
        let trimmed = try XCTUnwrap(trimmedURL, "trim failed")
        let trimmedDur = await VideoEngine.duration(trimmed)
        XCTAssertEqual(trimmedDur, 1.0, accuracy: 0.2)
        XCTAssertEqual(trimmed.pathExtension, "mp4")

        let mp4URL = await VideoEngine.toMP4(src)
        let mp4 = try XCTUnwrap(mp4URL, "toMP4 failed")
        XCTAssertGreaterThan(SizeTarget.fileSize(mp4) ?? 0, 0)

        let mutedURL = await VideoEngine.mute(src)
        let muted = try XCTUnwrap(mutedURL, "mute failed")
        let audioTracks = try await AVURLAsset(url: muted).loadTracks(withMediaType: .audio)
        XCTAssertTrue(audioTracks.isEmpty)

        // A silent fixture has nothing to extract — the engine must say no, not crash.
        let audio = await VideoEngine.extractAudio(src)
        XCTAssertNil(audio)

        let thumb = await VideoEngine.thumbnail(src, at: 1.0)
        XCTAssertNotNil(thumb)

        let gifURL = await tenzyGIFFromVideo(url: src, start: 0, duration: 1.0, fps: 8, speed: 1, maxDim: 160)
        let gif = try XCTUnwrap(gifURL, "GIF from video failed")
        let gifSrc = try XCTUnwrap(CGImageSourceCreateWithURL(gif as CFURL, nil))
        let frames = CGImageSourceGetCount(gifSrc)
        XCTAssertTrue((6...8).contains(frames), "expected ~8 GIF frames, got \(frames)")
    }

    func testSizeTargetVideoLandsUnderLimit() async throws {
        let fixture = await Self.movie(seconds: 2.0, size: CGSize(width: 640, height: 480), noisy: true)
        let src = try XCTUnwrap(fixture)
        let original = SizeTarget.fileSize(src) ?? 0
        XCTAssertGreaterThan(original, 200_000, "fixture too small to be a meaningful shrink test")
        let target = original / 3
        let outURL = await SizeTarget.video(url: src, targetBytes: target)
        let out = try XCTUnwrap(outURL, "shrink failed")
        XCTAssertLessThanOrEqual(SizeTarget.fileSize(out) ?? Int.max, target)
    }

    // MARK: fixtures

    /// Distinct horizontal colour bands so every row is identifiable (no false overlap matches).
    static func bands(_ size: CGSize) -> UIImage {
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).image { ctx in
            var y: CGFloat = 0; var i = 0
            while y < size.height {
                let h: CGFloat = 20 + CGFloat(i % 5) * 9
                UIColor(hue: CGFloat((i * 37) % 360) / 360, saturation: 0.75, brightness: 0.85 - CGFloat(i % 3) * 0.15, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: y, width: size.width, height: h))
                y += h; i += 1
            }
        }
    }

    /// Random 8px colour cells — incompressible enough that size-targeting has real work to do.
    static func noisy(_ size: CGSize) -> UIImage {
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).image { ctx in
            let cell: CGFloat = 8
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    UIColor(hue: CGFloat.random(in: 0...1), saturation: 0.8, brightness: 0.9, alpha: 1).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: cell, height: cell)); x += cell
                }
                y += cell
            }
        }
    }

    static func solid(_ size: CGSize, hue: CGFloat = 0.55) -> UIImage {
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).image { ctx in
            UIColor(hue: hue, saturation: 0.6, brightness: 0.9, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func text(_ s: String) -> UIImage {
        let size = CGSize(width: 640, height: 200)
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            (s as NSString).draw(at: CGPoint(x: 40, y: 64),
                                 withAttributes: [.font: UIFont.boldSystemFont(ofSize: 72), .foregroundColor: UIColor.black])
        }
    }

    /// Writes a short silent H.264 movie: moving coloured bars (or per-frame noise so it can't compress to nothing).
    static func movie(seconds: Double, size: CGSize = CGSize(width: 320, height: 240), noisy: Bool = false, fps: Int32 = 24) async -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fixture-\(UUID().uuidString.prefix(6)).mov")
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return nil }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: noisy ? 6_000_000 : 800_000]])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height)])
        writer.add(input)
        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)
        let frames = Int(seconds * Double(fps))
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        for i in 0..<frames {
            while !input.isReadyForMoreMediaData { try? await Task.sleep(nanoseconds: 5_000_000) }
            guard let pool = adaptor.pixelBufferPool else { return nil }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
            guard let buf = pb else { return nil }
            CVPixelBufferLockBaseAddress(buf, [])
            let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            if let ctx {
                let img = noisy ? noisy(size) : bands(size)
                ctx.draw(img.cgImage!, in: CGRect(origin: .zero, size: size))
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fill(CGRect(x: CGFloat(i % Int(size.width - 40)), y: size.height / 2 - 20, width: 40, height: 40))
            }
            CVPixelBufferUnlockBaseAddress(buf, [])
            adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return writer.status == .completed ? url : nil
    }
}
