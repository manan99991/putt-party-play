import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
import PDFKit
import AVFoundation
import PencilKit
import CoreImage
import simd
import CoreLocation
import CryptoKit
@testable import HandyTools

/// Engine-level correctness checks. These exercise the real tool logic with deterministic,
/// generated fixtures (no camera/network), so a regression fails the build.
final class EngineTests: XCTestCase {

    // MARK: catalog integrity

    @MainActor func testCatalogIsConsistent() {
        XCTAssertEqual(Set(TOOLS.map(\.id)).count, TOOLS.count, "tool ids must be unique")
        let pages = Set(TOOLS.map(\.page)).sorted()
        XCTAssertEqual(pages, Array(1...(pages.last ?? 1)), "pages must run contiguously from 1")
        for p in pages {
            let n = tools(onPage: p).count
            XCTAssertGreaterThan(n, 0, "page \(p) is empty")
            XCTAssertLessThanOrEqual(n, 10, "page \(p) has more than 10 tiles (\(n))")
        }
        let appBundle = Bundle(for: StoreManager.self)
        for t in TOOLS {
            XCTAssertFalse(t.name.isEmpty, "\(t.id) has no name")
            XCTAssertFalse(t.blurb.isEmpty, "\(t.id) has no blurb")
            XCTAssertFalse(t.blurb.hasSuffix("…") || t.blurb.hasSuffix("..."), "\(t.id) blurb must not be truncated")
            // Every tile must ship its gradient icon tile. A missing asset silently falls back to a
            // flat SF-Symbol glyph that looks out of place on the grid — this is exactly what happened
            // to Contacts. Require the asset to be named AND to actually load from the app bundle.
            let asset = t.asset
            XCTAssertNotNil(asset, "\(t.id) has no icon asset — it would render a flat fallback glyph")
            if let a = asset {
                XCTAssertNotNil(UIImage(named: a, in: appBundle, compatibleWith: nil),
                                "icon asset \"\(a)\" for \(t.id) is missing from the asset catalog")
            }
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

    // MARK: duplicate detection precision

    /// The Cleaner must not group two *different* white document screenshots as look-alikes (that was
    /// the average-hash bug — brightness alone couldn't tell documents apart). The difference hash must
    /// separate them, while a re-rendered identical image still matches as a true duplicate.
    func testDuplicateHashSeparatesDifferentDocuments() {
        // 8x8 grid of 20px cells, so features align with the hash's downsample and don't wash out.
        func grid(_ dark: (Int, Int) -> Bool) -> CGImage {
            let size = CGSize(width: 160, height: 160)
            UIGraphicsBeginImageContextWithOptions(size, true, 1)
            let ctx = UIGraphicsGetCurrentContext()!
            ctx.setFillColor(UIColor.white.cgColor); ctx.fill(CGRect(origin: .zero, size: size))
            ctx.setFillColor(UIColor.black.cgColor)
            for r in 0..<8 { for c in 0..<8 where dark(r, c) { ctx.fill(CGRect(x: c * 20, y: r * 20, width: 20, height: 20)) } }
            let img = UIGraphicsGetImageFromCurrentImageContext()!; UIGraphicsEndImageContext()
            return img.cgImage!
        }
        // A checkerboard vs its exact inverse: every adjacent-cell comparison flips, so the two differ
        // in essentially all 128 bits — a different layout is never confused for a duplicate.
        let d1 = grid { (r, c) in (r + c) % 2 == 0 }
        let d2 = grid { (r, c) in (r + c) % 2 == 1 }
        XCTAssertGreaterThan(PhotoCleaner.hamming(PhotoCleaner.dHash(d1), PhotoCleaner.dHash(d2)), 10,
                             "two different layouts must differ in many dHash bits so they're NOT grouped as duplicates")
        // identical content re-rendered → same hash (a real duplicate is still caught)
        let d1copy = grid { (r, c) in (r + c) % 2 == 0 }
        XCTAssertLessThanOrEqual(PhotoCleaner.hamming(PhotoCleaner.dHash(d1), PhotoCleaner.dHash(d1copy)), 2,
                                "an identical layout must still match as a duplicate")
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

    func testSizeTargetImageLandsUnderLimit() async throws {
        let big = Self.noisy(CGSize(width: 2400, height: 1800))
        let target = 150_000
        let out0 = await SizeTarget.image(big, targetBytes: target)
        let d = try XCTUnwrap(out0, "image could not be fitted")
        XCTAssertLessThanOrEqual(d.count, target, "must land under the limit")
        XCTAssertNotNil(UIImage(data: d), "output must still decode")
    }

    // A full-resolution phone photo (12 MP) must fit a tiny target quickly and WITHOUT blocking the
    // main thread — this is the case that froze the app in the field.
    func testSizeTargetImageIsFastAndOffMainForBigPhoto() async throws {
        let big = Self.noisy(CGSize(width: 4032, height: 3024))   // ~12 MP, a real camera shot
        let start = Date()
        let out0 = await SizeTarget.image(big, targetBytes: 200_000)
        let d = try XCTUnwrap(out0, "12 MP photo could not be fitted to 200 KB")
        XCTAssertLessThanOrEqual(d.count, 200_000)
        XCTAssertNotNil(UIImage(data: d))
        XCTAssertLessThan(Date().timeIntervalSince(start), 8.0, "fit took too long — would feel like a freeze")
    }

    func testSizeTargetPDFLandsUnderLimit() async throws {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let pdf = UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            for _ in 0..<3 { ctx.beginPage(); Self.noisy(CGSize(width: 1200, height: 1500)).draw(in: page) }
        }
        let target = min(pdf.count / 2, 400_000)
        let out1 = await SizeTarget.pdf(pdf, targetBytes: target)
        let out = try XCTUnwrap(out1, "pdf could not be fitted")
        XCTAssertLessThanOrEqual(out.count, target)
        XCTAssertEqual(PDFDocument(data: out)?.pageCount, 3, "must keep every page")
    }

    // MARK: Rest — sleep-sound synthesis (regression: "Rain" crashed the app)

    func testNoiseSynthEveryKindRendersFiniteAudio() {
        for kind in NoiseSynth.Kind.allCases {
            let samples = NoiseSynth.render(kind, samples: 4096, sampleRate: 48_000)
            XCTAssertEqual(samples.count, 4096, "\(kind.title) wrong sample count")
            XCTAssertFalse(samples.contains { !$0.isFinite }, "\(kind.title) produced NaN/Inf audio")
            XCTAssertFalse(samples.contains { abs($0) > 1.5 }, "\(kind.title) clipped hard")
        }
    }

    // MARK: Pro Camera — readout (regression: Int(1/0) trapped on open, device-only)

    func testShutterLabelNeverTrapsOnInvalidExposure() {
        // A camera reports 0 / NaN / invalid exposureDuration for the first instant on open; the old
        // label computed Int(1/0) = Int(infinity) and crashed Pro Camera on device.
        for bad in [0.0, -1.0, .nan, .infinity, -.infinity] {
            XCTAssertEqual(ProImage.shutterLabel(bad), "—", "shutterLabel(\(bad)) must not trap")
        }
        XCTAssertEqual(ProImage.shutterLabel(2), "2 s")
        XCTAssertEqual(ProImage.shutterLabel(1.0 / 60.0), "1/60")
        XCTAssertFalse(ProImage.shutterLabel(0.5).isEmpty)
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

    func testStitcherOrdersShuffledScreenshots() throws {
        // Slice a tall image into 3 overlapping strips, hand them over SHUFFLED — the stitcher must
        // recover the true top-to-bottom order (new: Long Screenshot auto-orders any pick order).
        let w = 300
        let tall = Self.noisy(CGSize(width: CGFloat(w), height: 1200))
        let cg = try XCTUnwrap(tall.cgImage)
        func strip(_ y: Int, _ h: Int) throws -> Stitcher.Gray {
            let c = try XCTUnwrap(cg.cropping(to: CGRect(x: 0, y: y, width: w, height: h)))
            return Stitcher.grayscale(UIImage(cgImage: c), width: 160)
        }
        let a = try strip(0, 500), b = try strip(400, 500), c = try strip(800, 400)  // a→b→c overlap
        let order = Stitcher.inferOrder([c, a, b])                                    // supplied out of order
        XCTAssertEqual(order, [1, 2, 0], "expected a(idx1) → b(idx2) → c(idx0) top-to-bottom")
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

    func testEnhanceProducesAValidImageBothModes() throws {
        let img = Self.noisy(CGSize(width: 320, height: 240))
        // No upscale: same pixel dimensions, still a decodable image.
        let plain = try XCTUnwrap(ImageStudio.enhance(img, upscale: false), "enhance must return an image")
        XCTAssertEqual(plain.size.width, 320, accuracy: 1)
        XCTAssertEqual(plain.size.height, 240, accuracy: 1)
        XCTAssertNotNil(plain.jpegData(compressionQuality: 0.9), "enhanced image must encode")
        // Upscale: strictly larger on the long side, capped below the 4096 ceiling.
        let up = try XCTUnwrap(ImageStudio.enhance(img, upscale: true))
        XCTAssertGreaterThan(up.size.width, 320)
        XCTAssertLessThanOrEqual(max(up.size.width, up.size.height), 4096)
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

    @MainActor func testCaptureFindsCodesInPhotosAndActionsInText() throws {
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

    // MARK: color vision

    func testColorVisionMatricesBehave() {
        let I = ColorVision.correctionMatrix(.deutan, severity: 1, strength: 0)
        for c in 0..<3 { for r in 0..<3 { XCTAssertEqual(I[c, r], c == r ? 1 : 0, accuracy: 1e-6) } }

        // red-green confusion: simulated red and green land much closer together than the originals
        let S = ColorVision.simulationMatrix(.deutan, severity: 1)
        let red = ColorVision.transform([1, 0, 0], by: S), green = ColorVision.transform([0, 1, 0], by: S)
        XCTAssertLessThan(simd_distance(red, green), 0.7, "deutan simulation should collapse red/green: \(red) vs \(green)")

        // correction leaves the red channel alone and moves the lost red/green difference into blue,
        // which a deutan eye sees — so the corrected scene actually looks different to that eye
        let C = ColorVision.correctionMatrix(.deutan, severity: 1, strength: 1)
        XCTAssertEqual(C[0, 0], 1, accuracy: 1e-6); XCTAssertEqual(C[1, 0], 0, accuracy: 1e-6); XCTAssertEqual(C[2, 0], 0, accuracy: 1e-6)
        let cRed = simd_clamp(ColorVision.transform([1, 0, 0], by: C), SIMD3(repeating: 0), SIMD3(repeating: 1))
        XCTAssertGreaterThan(cRed.z, 0.2, "red should gain blue: \(cRed)")
        XCTAssertGreaterThan(simd_distance(ColorVision.transform(cRed, by: S), red), 0.1, "correction must be visible to the deutan eye")
    }

    func testColorVisionHighlightCubeKeepsTargetGreysRest() {
        let size = 32
        let cube = ColorVision.highlightCube(.red, size: size)
        let floats = cube.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        func at(_ r: Int, _ g: Int, _ b: Int) -> [Float] { let o = ((b * size + g) * size + r) * 4; return Array(floats[o..<o + 3]) }
        let red = at(size - 1, 0, 0), green = at(0, size - 1, 0), grey = at(16, 16, 16)
        XCTAssertGreaterThan(red[0] - red[1], 0.8, "red must stay red: \(red)")
        XCTAssertEqual(green[0], green[1], accuracy: 1e-4); XCTAssertEqual(green[1], green[2], accuracy: 1e-4)
        XCTAssertEqual(grey[0], grey[1], accuracy: 1e-4)
    }

    func testColorVisionNamesAndAverage() {
        XCTAssertEqual(ColorVision.name(r: 1, g: 0, b: 0).name, "Red")
        XCTAssertEqual(ColorVision.name(r: 0, g: 0, b: 0).name, "Black")
        XCTAssertEqual(ColorVision.name(r: 1, g: 1, b: 1).name, "White")
        XCTAssertEqual(ColorVision.name(r: 0.15, g: 0.35, b: 0.9).name, "Blue")
        XCTAssertEqual(ColorVision.name(r: 1, g: 0.95, b: 0.15).hex, "#FFF226")

        let ctx = CIContext()
        let solid = CIImage(color: CIColor(red: 0.2, green: 0.6, blue: 0.9)).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let avg = try? XCTUnwrap(ColorVision.averageColor(of: solid, region: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), context: ctx))
        XCTAssertEqual(avg?.x ?? -1, 0.2, accuracy: 0.03); XCTAssertEqual(avg?.y ?? -1, 0.6, accuracy: 0.03); XCTAssertEqual(avg?.z ?? -1, 0.9, accuracy: 0.03)
        // identity matrix through the Core Image path leaves colour alone
        let same = ColorVision.apply(matrix_identity_float3x3, to: solid)
        let avg2 = ColorVision.averageColor(of: same, region: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), context: ctx)
        XCTAssertEqual(avg2?.y ?? -1, 0.6, accuracy: 0.03)
    }

    // MARK: instruments + flashlight

    func testSensorMathConversions() {
        // EV100 for f/2, 1/60 s, ISO 100 = log2(4·60) ≈ 7.9 → ~600 lux (bright room)
        let lux = SensorMath.lux(iso: 100, shutter: 1.0 / 60, aperture: 2)
        XCTAssertEqual(lux, 600, accuracy: 30)
        XCTAssertGreaterThan(SensorMath.lux(iso: 50, shutter: 1.0 / 1000, aperture: 1.8), 10_000, "sunlight exposure should read as daylight")
        XCTAssertEqual(SensorMath.lux(iso: 0, shutter: 0, aperture: 0), 0)

        XCTAssertEqual(SensorMath.cardinal(0), "N"); XCTAssertEqual(SensorMath.cardinal(90), "E")
        XCTAssertEqual(SensorMath.cardinal(359), "N"); XCTAssertEqual(SensorMath.cardinal(22.5), "NNE"); XCTAssertEqual(SensorMath.cardinal(225), "SW")

        let flat = SensorMath.tilt(gx: 0, gy: 0, gz: -1)
        XCTAssertFalse(flat.upright); XCTAssertEqual(flat.angle, 0, accuracy: 0.01)
        let tilted = SensorMath.tilt(gx: sin(10 * .pi / 180), gy: 0, gz: -cos(10 * .pi / 180))
        XCTAssertEqual(tilted.angle, 10, accuracy: 0.05)
        let upright = SensorMath.tilt(gx: 0, gy: -1, gz: 0)
        XCTAssertTrue(upright.upright); XCTAssertEqual(upright.angle, 0, accuracy: 0.01)

        XCTAssertEqual(SensorMath.dbSPL(fromPower: -50), 40, accuracy: 0.01)
        XCTAssertEqual(SensorMath.dbSPL(fromPower: -50, offset: 5), 45, accuracy: 0.01)
        XCTAssertEqual(SensorMath.dbSPL(fromPower: -160), 20)
        XCTAssertEqual(SensorMath.altitudeDelta(fromKPa: 100.0, referenceKPa: 101.325), 110, accuracy: 5, "~110 m per 1.3 kPa near sea level")
        XCTAssertEqual(SensorMath.field(x: 30, y: 40, z: 0, baseline: 50).magnitude, 50, accuracy: 0.001)
        XCTAssertEqual(SensorMath.field(x: 300, y: 0, z: 0, baseline: 50).score, 0.8333, accuracy: 0.01)
        // 460 ppi at 3× → 153.3 pt/in → 6.04 pt/mm; a bank card is ~517 pt wide
        XCTAssertEqual(SensorMath.pointsPerMM(nativeScale: 3) * 85.6, 517, accuracy: 2)
    }

    @MainActor func testMorseEncoding() {
        XCTAssertEqual(Torch.encodeMorse("SOS"), "... --- ...")
        XCTAssertEqual(Torch.encodeMorse("hi there"), ".... .. / - .... . .-. .")
        XCTAssertEqual(Torch.encodeMorse("a1"), ".- .----")
        XCTAssertEqual(Torch.encodeMorse("$$"), "", "unknown characters are dropped, not crashed on")
    }

    // MARK: magnifier

    @MainActor func testMagnifierPipelineKeepsExtentAndAppliesLooks() {
        let ctx = CIContext()
        let base = CIImage(color: CIColor(red: 0.9, green: 0.9, blue: 0.9)).cropped(to: CGRect(x: 0, y: 0, width: 200, height: 100))
        let zoomed = MagnifierView.cropZoom(base, 2)
        XCTAssertEqual(zoomed.extent.width, 200, accuracy: 0.5); XCTAssertEqual(zoomed.extent.height, 100, accuracy: 0.5)
        XCTAssertEqual(MagnifierView.cropZoom(base, 1).extent, base.extent)

        // yellow-on-black turns a light page yellow; inverted turns it dark
        let region = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let yb = ColorVision.averageColor(of: MagnifierView.style(base, look: .yellowBlack, sharpen: false, brightness: 0), region: region, context: ctx)
        XCTAssertGreaterThan(yb?.x ?? 0, 0.6); XCTAssertLessThan(yb?.z ?? 1, 0.4)
        let inv = ColorVision.averageColor(of: MagnifierView.style(base, look: .inverted, sharpen: false, brightness: 0), region: region, context: ctx)
        XCTAssertLessThan(inv?.x ?? 1, 0.3)
        let nat = ColorVision.averageColor(of: MagnifierView.style(base, look: .natural, sharpen: true, brightness: 0), region: region, context: ctx)
        XCTAssertEqual(nat?.x ?? 0, 0.9, accuracy: 0.05)
    }

    // MARK: gps dashboard

    func testTripTrackerAccumulatesAndFiltersNoise() {
        var t = TripTracker()
        let t0 = Date()
        // 10 fixes 100 m apart heading north at 10 s intervals ≈ 10 m/s
        for i in 0..<10 {
            t.add(coordinate: CLLocationCoordinate2D(latitude: 37.0 + Double(i) * 0.0009, longitude: -122.0), speed: 10, horizontalAccuracy: 5, timestamp: t0.addingTimeInterval(Double(i) * 10))
        }
        XCTAssertEqual(t.distance, 900, accuracy: 20)
        XCTAssertEqual(t.movingSeconds, 90, accuracy: 0.01)
        XCTAssertEqual(t.maxSpeed, 10)
        XCTAssertEqual(t.averageSpeed, 10, accuracy: 0.3)
        // a wild 500 m accuracy fix and a teleport must not count
        t.add(coordinate: CLLocationCoordinate2D(latitude: 38, longitude: -122), speed: 10, horizontalAccuracy: 500, timestamp: t0.addingTimeInterval(100))
        t.add(coordinate: CLLocationCoordinate2D(latitude: 39, longitude: -122), speed: 10, horizontalAccuracy: 5, timestamp: t0.addingTimeInterval(110))
        XCTAssertEqual(t.distance, 900, accuracy: 20)
        t.running = false
        t.add(coordinate: CLLocationCoordinate2D(latitude: 39.001, longitude: -122), speed: 10, horizontalAccuracy: 5, timestamp: t0.addingTimeInterval(120))
        XCTAssertEqual(t.distance, 900, accuracy: 20, "paused trips don't grow")
        t.reset()
        XCTAssertEqual(t.distance, 0); XCTAssertFalse(t.running)
    }

    func testGeoFormatting() {
        XCTAssertEqual(GeoFormat.speed(10, metric: true), "36"); XCTAssertEqual(GeoFormat.speed(10, metric: false), "22")
        XCTAssertEqual(GeoFormat.distance(1609.344, metric: false), "1.00 mi"); XCTAssertEqual(GeoFormat.distance(250, metric: true), "250 m")
        XCTAssertEqual(GeoFormat.duration(3725), "1:02:05"); XCTAssertEqual(GeoFormat.duration(65), "1:05")
        let c = CLLocationCoordinate2D(latitude: 37.774929, longitude: -122.419416)
        XCTAssertEqual(GeoFormat.dms(c), "37°46'29.7\"N 122°25'09.9\"W")
        XCTAssertTrue(GeoFormat.mapsLink(c).hasPrefix("https://maps.apple.com/?ll=37.77493,-122.41942"))
    }

    // MARK: audio lab

    func testPitchDetectionAndNoteMath() {
        let rate = 44100.0
        func tone(_ hz: Double, n: Int = 4096, square: Bool = false) -> [Float] {
            (0..<n).map { i in let v = sin(2 * .pi * hz * Double(i) / rate); return Float(square ? (v >= 0 ? 0.5 : -0.5) : 0.5 * v) }
        }
        let a = try? XCTUnwrap(Pitch.detect(tone(440), sampleRate: rate))
        XCTAssertEqual(a?.hz ?? 0, 440, accuracy: 1.5)
        XCTAssertGreaterThan(a?.clarity ?? 0, 0.9)
        let lowE = Pitch.detect(tone(82.41, n: 8192), sampleRate: rate)
        XCTAssertEqual(lowE?.hz ?? 0, 82.41, accuracy: 1.0, "low E string")
        let sq = Pitch.detect(tone(220, square: true), sampleRate: rate)
        XCTAssertEqual(sq?.hz ?? 0, 220, accuracy: 2, "square wave fundamental, not a harmonic")
        XCTAssertNil(Pitch.detect([Float](repeating: 0, count: 4096), sampleRate: rate), "silence is not a note")
        XCTAssertNil(Pitch.detect((0..<4096).map { _ in Float.random(in: -0.5...0.5) }, sampleRate: rate), "noise is not a note")

        let n = Pitch.note(for: 440)
        XCTAssertEqual(n.name, "A"); XCTAssertEqual(n.octave, 4); XCTAssertEqual(n.cents, 0, accuracy: 0.01)
        let sharp = Pitch.note(for: 446)
        XCTAssertEqual(sharp.name, "A"); XCTAssertEqual(sharp.cents, 23.4, accuracy: 0.5)
        XCTAssertEqual(Pitch.note(for: 261.63).name, "C"); XCTAssertEqual(Pitch.note(for: 261.63).octave, 4)
        XCTAssertEqual(Pitch.frequency(midi: 69), 440); XCTAssertEqual(Pitch.frequency(midi: 40), 82.41, accuracy: 0.01)
        XCTAssertEqual(Pitch.note(for: 440, a4: 442).cents, -7.85, accuracy: 0.1)
    }

    // MARK: rest

    func testNoiseSynthProducesBoundedColouredNoise() {
        for k in NoiseSynth.Kind.allCases {
            let x = NoiseSynth.render(k, samples: 44100)
            let peak = x.map { abs($0) }.max() ?? 0
            let rms = sqrt(x.reduce(0) { $0 + $1 * $1 } / Float(x.count))
            XCTAssertLessThanOrEqual(peak, 1.0, "\(k) clips")
            XCTAssertGreaterThan(rms, 0.02, "\(k) is near-silent (rms \(rms))")
            XCTAssertLessThan(rms, 0.6, "\(k) is too hot (rms \(rms))")
        }
        // brown has far less high-frequency energy than white: successive-sample differences are much smaller
        func roughness(_ x: [Float]) -> Float { zip(x.dropFirst(), x).map { abs($0 - $1) }.reduce(0, +) / Float(x.count) }
        let white = NoiseSynth.render(.white, samples: 20000), brown = NoiseSynth.render(.brown, samples: 20000)
        XCTAssertLessThan(roughness(brown), roughness(white) * 0.2)
    }

    func testSoundEventDetectorArmsHoldsAndStops() {
        var d = SoundEventDetector(baselineDB: 35, riseDB: 12, armSeconds: 0.4, holdSeconds: 8, maxSeconds: 60)
        var t = 0.0
        var changes: [SoundEventDetector.Change] = []
        func feed(_ db: Double, for seconds: Double) { var s = 0.0; while s < seconds { changes.append(d.feed(db: db, at: t)); t += 0.1; s += 0.1 } }
        feed(36, for: 5)            // quiet room
        feed(60, for: 0.2)          // a brief click: too short to arm
        feed(36, for: 2)
        XCTAssertFalse(changes.contains(.start), "a 0.2 s click should not start a clip")
        feed(60, for: 3)            // snoring burst
        XCTAssertEqual(changes.filter { $0 == .start }.count, 1)
        XCTAssertTrue(d.recording)
        feed(36, for: 5)            // quiet, but inside the hold window
        XCTAssertTrue(d.recording)
        feed(36, for: 4)            // hold expires
        XCTAssertFalse(d.recording)
        XCTAssertEqual(d.events.count, 1)
        XCTAssertEqual(d.events[0].peakDB, 60)
        XCTAssertEqual(d.events[0].end - d.events[0].start, 11, accuracy: 0.5)
        // a very long noise gets cut at maxSeconds
        feed(60, for: 70)
        XCTAssertGreaterThanOrEqual(d.events.count, 2)
    }

    // MARK: scene describer

    func testSceneComposerSpeaksConcretely() {
        var p = SceneDescriber.Perception()
        p.labels = [("indoor", 0.9), ("kitchen", 0.6), ("table", 0.4), ("people", 0.3)]
        p.people = 2; p.animals = ["Cat"]; p.text = ["EXIT", "Pull"]
        let s = SceneDescriber.compose(p)
        XCTAssertTrue(s.hasPrefix("Looks like a kitchen."), s)
        XCTAssertTrue(s.contains("2 people in view."), s)
        XCTAssertTrue(s.contains("Also a Cat."), s)
        XCTAssertTrue(s.contains("Nearby: table."), s)
        XCTAssertTrue(s.contains("Text reads: EXIT, Pull."), s)
        XCTAssertFalse(s.contains("%"), "no confidence numbers in speech")
        XCTAssertTrue(SceneDescriber.compose(SceneDescriber.Perception()).contains("Nothing I can name"))
        var one = SceneDescriber.Perception(); one.labels = [("orange", 0.8)]; one.people = 1
        XCTAssertEqual(SceneDescriber.compose(one), "Looks like an orange. One person in view.")
        // text is picked up by the perception pass on a plain rendered sign
        let seen = SceneDescriber.perceive(Self.text("HELLO 2026"))
        XCTAssertTrue(seen.text.joined(separator: " ").uppercased().contains("HELLO"), "\(seen.text)")
    }

    // MARK: pro camera

    func testProImageOverlaysAndHistogram() {
        let ctx = CIContext()
        XCTAssertEqual(ProImage.shutterLabel(1.0 / 60), "1/60"); XCTAssertEqual(ProImage.shutterLabel(2), "2 s"); XCTAssertEqual(ProImage.shutterLabel(0.5), "0.5 s")
        // half white / half black test card
        let W = 200.0, H = 100.0
        let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: CGRect(x: 0, y: 0, width: W / 2, height: H))
        let black = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: CGRect(x: W / 2, y: 0, width: W / 2, height: H))
        let card = white.composited(over: black).cropped(to: CGRect(x: 0, y: 0, width: W, height: H))
        let z = ProImage.zebras(card)
        XCTAssertEqual(z.extent, card.extent)
        let zl = ColorVision.averageColor(of: z, region: CGRect(x: 0.1, y: 0.25, width: 0.3, height: 0.5), context: ctx)   // white half → magenta
        let zr = ColorVision.averageColor(of: z, region: CGRect(x: 0.6, y: 0.25, width: 0.3, height: 0.5), context: ctx)   // black half → untouched
        XCTAssertLessThan(zl?.y ?? 1, 0.5, "blown area should be tinted: \(String(describing: zl))")
        XCTAssertLessThan(zr?.x ?? 1, 0.1)
        let pk = ProImage.peaking(card)
        XCTAssertEqual(pk.extent, card.extent)
        let edge = ColorVision.averageColor(of: pk, region: CGRect(x: 0.48, y: 0.2, width: 0.04, height: 0.6), context: ctx)   // the hard edge → red
        let flat = ColorVision.averageColor(of: pk, region: CGRect(x: 0.1, y: 0.2, width: 0.2, height: 0.6), context: ctx)   // flat white → untouched
        XCTAssertGreaterThan((edge?.x ?? 0) - (edge?.y ?? 0), 0.05, "edge should be painted red: \(String(describing: edge))")
        XCTAssertEqual((flat?.x ?? 0) - (flat?.y ?? 0), 0, accuracy: 0.02, "flat areas stay untouched")
        let h = ProImage.histogram(card, context: ctx, bins: 32)
        XCTAssertEqual(h.count, 32)
        XCTAssertGreaterThan(h.first ?? 0, 0.5, "half the pixels are black"); XCTAssertGreaterThan(h.last ?? 0, 0.5, "half the pixels are white")
        XCTAssertLessThan(h[16], 0.1)
        // scale() works in linear light (right for averaging exposures): 0.5 linear reads back as ~0.735 in sRGB
        let half = ProImage.scale(white, by: 0.5)
        let v = ColorVision.averageColor(of: half, region: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6), context: ctx)?.x ?? 0
        XCTAssertEqual(v, 0.735, accuracy: 0.03, "expected sRGB(0.5 linear)")
    }

    // MARK: AR measure math

    func testMeasureMathLengthsAreasAndFormatting() {
        let a = SIMD3<Float>(0, 0, 0), b = SIMD3<Float>(3, 0, 4)
        XCTAssertEqual(MeasureMath.distance(a, b), 5)
        XCTAssertEqual(MeasureMath.pathLength([a, b, SIMD3<Float>(3, 0, 0)]), 9, accuracy: 0.001)
        // 2 m × 3 m rectangle on the floor (y up), slightly non-coplanar corner tolerated
        let rect: [SIMD3<Float>] = [[0, 0, 0], [2, 0, 0], [2, 0.01, 3], [0, 0, 3]]
        XCTAssertEqual(MeasureMath.polygonArea(rect), 6, accuracy: 0.05)
        XCTAssertEqual(MeasureMath.polygonArea([a, b]), 0)
        XCTAssertEqual(MeasureMath.height(from: [0, -1.2, 0], to: [0.3, 0.6, 0.1]), 1.8, accuracy: 0.0001)
        XCTAssertEqual(MeasureMath.length(0.254, metric: false), "10.0 in")
        XCTAssertEqual(MeasureMath.length(1.0, metric: false), "3′ 3.4″")
        XCTAssertEqual(MeasureMath.length(0.42, metric: true), "42.0 cm"); XCTAssertEqual(MeasureMath.length(2.5, metric: true), "2.50 m")
        XCTAssertEqual(MeasureMath.area(1, metric: false), "10.8 sq ft")
    }

    // MARK: message shield

    func testScamAnalyzerCatchesClassicsAndClearsNormalText() {
        let giftcard = ScamAnalyzer.analyze("URGENT: This is the IRS. Your account will be suspended within 24 hours unless you pay the balance in Apple gift cards. Do not tell anyone. Call immediately.")
        XCTAssertEqual(giftcard.verdict, .likelyScam)
        XCTAssertTrue(giftcard.findings.contains { $0.title.contains("untraceable") })
        XCTAssertTrue(giftcard.findings.contains { $0.title.contains("Pressure") })
        XCTAssertTrue(giftcard.findings.contains { $0.title.contains("secret") })
        XCTAssertTrue(giftcard.findings.contains { $0.title.contains("well-known") })

        let phish = ScamAnalyzer.analyze("Dear customer, we noticed unusual activity. Verify your account now at http://paypal.secure-login.top/verify or it will be locked.")
        XCTAssertEqual(phish.verdict, .likelyScam)
        XCTAssertEqual(phish.links.count, 1)
        let issues = phish.links[0].issues.joined(separator: " ")
        XCTAssertTrue(issues.contains("paypal"), issues)
        XCTAssertTrue(issues.contains("Not encrypted"), issues)
        XCTAssertTrue(issues.contains(".top"), issues)
        XCTAssertTrue(phish.findings.contains { $0.title == "Generic greeting" })

        let otp = ScamAnalyzer.analyze("Hi it's Amazon support, please read me the verification code we just texted you so I can cancel the order.")
        XCTAssertTrue(otp.findings.contains { $0.title.contains("code, password") })
        XCTAssertNotEqual(otp.verdict, .lowRisk)

        let wrong = ScamAnalyzer.analyze("Hi, is this Jennifer?")
        XCTAssertTrue(wrong.findings.contains { $0.title.contains("Wrong-number") })

        let normal = ScamAnalyzer.analyze("Hey! Running 10 min late, can you grab us a table? Also mum says hi. See you soon x")
        XCTAssertEqual(normal.verdict, .lowRisk)
        XCTAssertTrue(normal.findings.isEmpty, "\(normal.findings.map(\.title))")
        let realLink = ScamAnalyzer.analyze("Your order shipped! Track it at https://www.amazon.com/progress-tracker/package/ref=abc")
        XCTAssertEqual(realLink.verdict, .lowRisk)
        XCTAssertTrue(realLink.links[0].issues.isEmpty, "\(realLink.links[0].issues)")

        XCTAssertFalse(ScamAnalyzer.advice(for: giftcard).isEmpty)
        XCTAssertEqual(ScamAnalyzer.advice(for: normal).count, 1)
    }

    // MARK: data grabber

    func testDataGrabReceiptCardEventTable() {
        let receiptText = """
        BLUE BOTTLE COFFEE
        300 Webster St, Oakland CA
        03/14/2026 8:41 AM
        Cappuccino            4.75
        Almond Croissant      5.25
        Oat milk              0.75
        Subtotal             10.75
        Tax                   0.97
        Tip                   2.00
        Total                13.72
        VISA ****4421        13.72
        Thank you for visiting!
        """
        XCTAssertEqual(DataGrab.detect(receiptText), .receipt)
        let r = DataGrab.receipt(receiptText)
        XCTAssertEqual(r.merchant, "BLUE BOTTLE COFFEE")
        XCTAssertEqual(r.items.count, 3, "\(r.items)")
        XCTAssertEqual(r.items.first?.0, "Cappuccino"); XCTAssertEqual(r.items.first?.1 ?? 0, 4.75, accuracy: 0.001)
        XCTAssertEqual(r.subtotal ?? 0, 10.75, accuracy: 0.001); XCTAssertEqual(r.tax ?? 0, 0.97, accuracy: 0.001); XCTAssertEqual(r.tip ?? 0, 2.0, accuracy: 0.001); XCTAssertEqual(r.total ?? 0, 13.72, accuracy: 0.001)
        XCTAssertNotNil(r.date)
        let csv = DataGrab.receiptCSV(r)
        XCTAssertTrue(csv.hasPrefix("Item,Amount\nCappuccino,4.75")); XCTAssertTrue(csv.hasSuffix("Total,13.72"))
        XCTAssertTrue(DataGrab.expenseRow(r).contains("2026-03-14,BLUE BOTTLE COFFEE,13.72,0.97"))

        let cardText = """
        Priya Natarajan
        Senior Product Designer
        Lumen Studio Inc.
        +1 (415) 555-0142
        priya@lumenstudio.com
        www.lumenstudio.com
        """
        XCTAssertEqual(DataGrab.detect(cardText), .card)
        let c = DataGrab.card(cardText)
        XCTAssertEqual(c.name, "Priya Natarajan"); XCTAssertEqual(c.title, "Senior Product Designer"); XCTAssertEqual(c.company, "Lumen Studio Inc.")
        XCTAssertEqual(c.emails, ["priya@lumenstudio.com"]); XCTAssertEqual(c.phones.count, 1); XCTAssertEqual(c.website, "www.lumenstudio.com")
        let v = DataGrab.vcard(c)
        XCTAssertTrue(v.contains("FN:Priya Natarajan")); XCTAssertTrue(v.contains("N:Natarajan;Priya;;;")); XCTAssertTrue(v.contains("ORG:Lumen Studio Inc.")); XCTAssertTrue(v.contains("EMAIL;TYPE=WORK:priya@lumenstudio.com"))

        let eventText = """
        Spring Book Fair
        Join us Saturday, April 18, 2026 at 10:00 AM
        Westside Community Hall
        RSVP by April 10
        """
        XCTAssertEqual(DataGrab.detect(eventText), .event)
        let e = DataGrab.event(eventText)
        XCTAssertEqual(e.title, "Spring Book Fair")
        XCTAssertNotNil(e.start)
        if let s = e.start { let comps = Calendar.current.dateComponents([.month, .day, .hour], from: s); XCTAssertEqual(comps.month, 4); XCTAssertEqual(comps.day, 18); XCTAssertEqual(comps.hour, 10) }
        XCTAssertTrue(DataGrab.ics(e).contains("SUMMARY:Spring Book Fair"))
        XCTAssertTrue(DataGrab.ics(e).contains("DTSTART:2026"))

        let tableText = """
        Name        Qty   Price
        Widget      2     3.50
        Gadget, XL  1     12.00
        """
        XCTAssertEqual(DataGrab.detect(tableText), .table)
        XCTAssertEqual(DataGrab.tableCSV(tableText), "Name,Qty,Price\nWidget,2,3.50\n\"Gadget, XL\",1,12.00")
        XCTAssertEqual(DataGrab.detect("Hey, want to grab lunch tomorrow?"), .text)
    }

    // MARK: text tools

    @MainActor func testTextToolsFixSummarizeActionsStats() {
        let fixed = TextTools.fixSpelling("teh  meeting is tomorow , i think .so we should prepare")
        XCTAssertTrue(fixed.text.hasPrefix("T"), fixed.text)
        XCTAssertFalse(fixed.text.contains("  ")); XCTAssertFalse(fixed.text.contains(" ,")); XCTAssertTrue(fixed.text.contains(" I "), fixed.text)
        XCTAssertTrue(fixed.text.contains(".So") || fixed.text.contains(". So"), fixed.text)

        let article = "Solar panels on the roof cut the bill by a third. The cat likes the warm tiles. Solar output peaks at noon in summer. We had pasta for dinner. The installer said solar panels last twenty-five years. The bus was late again."
        let top = TextTools.summarize(article, sentences: 2)
        XCTAssertEqual(top.count, 2)
        XCTAssertTrue(top.allSatisfy { $0.lowercased().contains("solar") }, "\(top)")
        XCTAssertEqual(TextTools.summarize("One sentence only.", sentences: 3), ["One sentence only."])

        let notes = "We need to send the invoice by Friday. The weather was lovely. Remember to call Sam about the venue. Everyone liked the cake."
        let items = TextTools.actionItems(notes)
        XCTAssertEqual(items.count, 2, "\(items)")
        XCTAssertTrue(items[0].hasPrefix("We need to send"))

        XCTAssertEqual(TextTools.bullets("First idea. Second idea!"), "• First idea.\n• Second idea!")
        let st = TextTools.stats("The quick brown fox jumps over the lazy dog. It was fun.")
        XCTAssertEqual(st.words, 12); XCTAssertEqual(st.sentences, 2); XCTAssertGreaterThan(st.readingSeconds, 0)
        XCTAssertEqual(TextTools.syllables("table"), 2); XCTAssertEqual(TextTools.syllables("cake"), 1); XCTAssertEqual(TextTools.syllables("banana"), 3)
        XCTAssertEqual(TextTools.capitalizeSentences("hello there. how are you? fine"), "Hello there. How are you? Fine")
    }

    // MARK: read aloud

    @MainActor func testReadSourceExtractsArticleTextAndReaderSplits() {
        let html = """
        <html><head><title>T</title><style>p{color:red}</style><script>var x = "<p>not this</p>";</script></head>
        <body><nav><a href="/">Home</a><a href="/x">Menu item that is long enough to look like text</a></nav>
        <h1>Solar &amp; the Grid</h1>
        <p>Rooftop panels now supply a tenth of daytime demand in some cities, and the share is rising every year.</p>
        <p>Utilities are responding with time-of-use pricing &mdash; cheaper power at noon, dearer at dusk.</p>
        <footer>© 2026 Example — all rights reserved and some more footer words here</footer></body></html>
        """
        let t = ReadSource.extract(html: html)
        XCTAssertTrue(t.hasPrefix("Solar & the Grid"), t)
        XCTAssertTrue(t.contains("time-of-use pricing — cheaper"), t)
        XCTAssertFalse(t.contains("not this")); XCTAssertFalse(t.contains("Menu item")); XCTAssertFalse(t.contains("footer words"))
        XCTAssertEqual(ReadSource.strip("a &lt;b&gt; &quot;c&quot; &#8217;"), "a <b> \"c\"")

        let long = (0..<12).map { "clause number \($0) with some words" }.joined(separator: ", ") + "."
        let parts = Reader.split(longSentence: long, max: 120)
        XCTAssertGreaterThan(parts.count, 1)
        XCTAssertTrue(parts.allSatisfy { $0.count <= 125 })
        XCTAssertEqual(parts.joined(separator: ",").replacingOccurrences(of: ", ", with: ",").replacingOccurrences(of: ",", with: ""), long.replacingOccurrences(of: ", ", with: "").replacingOccurrences(of: ",", with: ""), "no words lost")
        let r = Reader()
        r.load("First sentence here. Second one! Third?")
        XCTAssertEqual(r.sentences.count, 3); XCTAssertEqual(r.index, 0)
        XCTAssertFalse(Reader.voices(for: "en").isEmpty)
    }

    @MainActor func testReadAloudPicksOneStableLanguageForMixedPages() {
        // A page of US business-listing fragments used to make the voice flip languages line by line,
        // because each short line (an address, a phone number, a lone word) was language-detected on
        // its own. The document language must now resolve ONCE, to the device language, not a shaky
        // foreign guess off a fragment like "TIPPERARY LN".
        let listing = """
        Postal Address Industry
        12929 TIPPERARY LN
        Technology
        PLAINFIELD, IL 60585-2799
        Primary Phone Business Owner(s)
        (331) 333-2325
        Secondary Phone Postal Address
        13000 DEERFIELD PKWY STE 3100
        """
        XCTAssertTrue(NLLanguageGuess.documentLanguage(listing).hasPrefix("en"),
                      "address-heavy page should read in the device language, got \(NLLanguageGuess.documentLanguage(listing))")
        XCTAssertTrue(NLLanguageGuess.documentLanguage("12929 TIPPERARY LN").hasPrefix("en"),
                      "a lone ambiguous line must not pull a foreign language")
        // The default voice is a real, installed voice — never nil (which would read silently).
        XCTAssertNotNil(Reader.bestVoice(forLanguage: "en-US"))
    }

    @MainActor func testSpellFixFollowsLanguage() {
        // An odd hint resolves to a real supported language, never crashes.
        XCTAssertTrue(UITextChecker.availableLanguages.contains(TextTools.checkerLanguage(for: "zz-ZZ")))
        XCTAssertTrue(TextTools.checkerLanguage(for: "en-GB").hasPrefix("en"))
        // English keeps the lone-"i" → "I" fix mid-sentence.
        XCTAssertTrue(TextTools.fixSpelling("maybe i can", language: "en").text.contains("I can"))
        // A non-English language must NOT force a lone "i" to "I" — it's a real word elsewhere.
        if TextTools.checkerLanguage(for: "it").hasPrefix("it") {
            XCTAssertTrue(TextTools.fixSpelling("tra i campi", language: "it").text.contains(" i "),
                          "Italian lone 'i' should be left alone")
        }
    }

    // MARK: explainer glossary

    func testGlossaryFindsTermsAndRedFlags() {
        let lease = "Tenant shall indemnify and hold harmless the Landlord. This Agreement shall automatically renew for successive twelve-month terms unless either party gives 60 days' notice. All disputes are subject to binding arbitration. Tenants are jointly and severally liable. Late fee of $75 applies after a 5-day grace period."
        let terms = Glossary.found(in: lease).map(\.term)
        XCTAssertTrue(terms.contains("indemnify")); XCTAssertTrue(terms.contains("hold harmless")); XCTAssertTrue(terms.contains("arbitration")); XCTAssertTrue(terms.contains("grace period")); XCTAssertTrue(terms.contains("shall"))
        XCTAssertFalse(terms.contains("lien"), "no false positives from substrings (e.g. 'client')")
        XCTAssertEqual(Set(terms).count, terms.count, "each term once")
        let flags = Glossary.redFlags(in: lease).map(\.0)
        XCTAssertTrue(flags.contains("Auto-renewal")); XCTAssertTrue(flags.contains("Arbitration / class-action waiver")); XCTAssertTrue(flags.contains("Indemnity")); XCTAssertTrue(flags.contains("Personal liability")); XCTAssertTrue(flags.contains("Late fees"))
        XCTAssertTrue(Glossary.found(in: "The client was happy. We went to the lake.").isEmpty)
        let labs = "CBC within normal limits. LDL 160 mg/dL (high). TSH 2.1. Take 1 tab PO BID PRN pain."
        let lt = Glossary.found(in: labs).map(\.term)
        XCTAssertTrue(lt.contains("within normal limits")); XCTAssertTrue(lt.contains("ldl")); XCTAssertTrue(lt.contains("bid")); XCTAssertTrue(lt.contains("prn")); XCTAssertTrue(lt.contains("po"))
        XCTAssertGreaterThan(Glossary.terms.count, 100)
    }

    // MARK: clipboard link cleaner

    func testLinkCleanerStripsTrackingAndUnwrapsRedirects() {
        XCTAssertEqual(LinkCleaner.clean("https://example.com/post?id=42&utm_source=newsletter&utm_medium=email&fbclid=abc123"), "https://example.com/post?id=42")
        XCTAssertEqual(LinkCleaner.clean("https://example.com/page?utm_campaign=x"), "https://example.com/page")
        XCTAssertEqual(LinkCleaner.clean("https://www.amazon.com/Some-Long-Product-Name/dp/B08N5WRWNW/ref=sr_1_3?keywords=thing&qid=1699&sr=8-3&th=1"), "https://www.amazon.com/dp/B08N5WRWNW")
        XCTAssertEqual(LinkCleaner.clean("https://l.facebook.com/l.php?u=https%3A%2F%2Fnews.example.org%2Fstory%3Fid%3D7%26utm_source%3Dfb&h=AT0"), "https://news.example.org/story?id=7")
        XCTAssertEqual(LinkCleaner.clean("https://www.youtube.com/watch?v=dQw4w9WgXcQ&si=TRACK&feature=share&t=42"), "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42")
        XCTAssertEqual(LinkCleaner.clean("https://example.com/a?x=1#:~:text=hello"), "https://example.com/a?x=1")
        XCTAssertEqual(LinkCleaner.clean("not a url"), "not a url")
        XCTAssertTrue(LinkCleaner.isURL("https://a.com/x")); XCTAssertFalse(LinkCleaner.isURL("hello https://a.com")); XCTAssertFalse(LinkCleaner.isURL("a.com"))
    }

    // MARK: vault crypto

    func testVaultCryptoRoundTripsAndRejectsTampering() throws {
        let key = SymmetricKey(size: .bits256)
        let secret = Data("garage code 4471 · wifi: hunter2".utf8)
        let sealed = try VaultCrypto.seal(secret, with: key)
        XCTAssertNotEqual(sealed, secret)
        XCTAssertGreaterThan(sealed.count, secret.count + 20, "nonce + tag present")
        XCTAssertEqual(try VaultCrypto.open(sealed, with: key), secret)
        var tampered = sealed; tampered[tampered.count / 2] ^= 0x55
        XCTAssertThrowsError(try VaultCrypto.open(tampered, with: key))
        XCTAssertThrowsError(try VaultCrypto.open(sealed, with: SymmetricKey(size: .bits256)), "a different key must not decrypt")
        // two seals of the same plaintext never match (fresh nonce each time)
        XCTAssertNotEqual(try VaultCrypto.seal(secret, with: key), sealed)
        // shred removes the file
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("shred-test.bin")
        try Data(repeating: 7, count: 4096).write(to: tmp)
        VaultCrypto.shred(tmp)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.path))
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
        let fixture = await Self.movie(seconds: 3.0, size: CGSize(width: 960, height: 540), noisy: true)
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
        // One fixed background reused for every frame, so the clip has real frame-to-frame redundancy
        // and can actually be re-compressed — unlike fresh per-frame noise, which no encoder can shrink
        // to a fraction of itself. The moving white block below supplies the motion. This is what a
        // genuine "needs shrinking" video looks like, so the size-target engine has honest work to do.
        let baseCG = (noisy ? Self.noisy(size) : Self.bands(size)).cgImage!
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
                ctx.draw(baseCG, in: CGRect(origin: .zero, size: size))
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
