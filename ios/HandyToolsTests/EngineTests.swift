import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
import PDFKit
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
}
