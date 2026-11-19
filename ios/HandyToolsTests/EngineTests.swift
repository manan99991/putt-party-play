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
        // The Audio Editor (item 6) must not elbow past the obvious tool for its neighbours' queries…
        XCTAssertEqual(searchTools("audio convert").first?.id, "audioconvert")
        XCTAssertEqual(searchTools("ringtone").first?.id, "ringtone")
        // …but it should own its own territory.
        XCTAssertEqual(searchTools("fade").first?.id, "audioedit")
        XCTAssertEqual(searchTools("dead air").first?.id, "audioedit")
        // Audio Cleanup (item 7) owns the noise/hiss/hum queries without stealing its neighbours'.
        XCTAssertEqual(searchTools("hiss").first?.id, "audioclean")
        XCTAssertEqual(searchTools("hum").first?.id, "audioclean")
        // (Not "noise reduction": the bare word "noise" belongs to the Rest / white-noise tool's
        //  territory via the sleep synonym cluster — Audio Cleanup owns the distinctive hiss/hum instead.)
        XCTAssertEqual(searchTools("audio convert").first?.id, "audioconvert")
        XCTAssertEqual(searchTools("fade").first?.id, "audioedit")
        // Meeting Notes (item 8) owns the meeting queries; Voice → Notes still answers plain "voice".
        XCTAssertEqual(searchTools("meeting notes").first?.id, "meetingnotes")
        XCTAssertEqual(searchTools("minutes").first?.id, "meetingnotes")
        XCTAssertFalse(searchTools("voice").isEmpty)
        // Soundboard (item 9) owns its own name + the distinctive character queries, without stealing
        // Voice → Notes' plain "voice" (its name prefixes "voice", so it keeps the lead there).
        XCTAssertEqual(searchTools("soundboard").first?.id, "soundboard")
        XCTAssertEqual(searchTools("chipmunk").first?.id, "soundboard")
        XCTAssertEqual(searchTools("watermark").first?.id, "pdfprotect")
        XCTAssertEqual(searchTools("pdf").first?.id, "scan")
        XCTAssertEqual(searchTools("searchable").first?.id, "pdfsearchable")
        XCTAssertEqual(searchTools("fill a form").first?.id, "pdfform")
        XCTAssertEqual(searchTools("sign").first?.id, "pdfsign")
        XCTAssertEqual(searchTools("pdf").first?.id, "scan", "Organize Pages must not steal 'pdf' from Scan")
        XCTAssertEqual(searchTools("reorder pages").first?.id, "pdfpages")
        XCTAssertEqual(searchTools("compress audio").first?.id, "audiocompress")
        XCTAssertEqual(searchTools("join audio").first?.id, "audiomix")
        XCTAssertEqual(searchTools("extract audio").first?.id, "audioconvert")
        XCTAssertEqual(searchTools("album art").first?.id, "audiotags")
        XCTAssertEqual(searchTools("zip files").first?.id, "zipmaker")
        XCTAssertEqual(searchTools("animate").first?.id, "animate")
        XCTAssertEqual(searchTools("ken burns").first?.id, "animate")
        XCTAssertEqual(searchTools("pill reminder").first?.id, "medreminder")
        XCTAssertEqual(searchTools("collage").first?.id, "collage")
        XCTAssertEqual(searchTools("hide kids faces").first?.id, "faceemoji")
        XCTAssertEqual(searchTools("menu").first?.id, "menu")
        XCTAssertEqual(searchTools("comic strip").first?.id, "comicstrip")
        // Every "Open in a tool" target is a real tool, and a hand-off is used exactly once (fresh slate).
        for k in [ChainKind.pdf, .image, .photoFile, .audio, .video, .file] {
            for id in ToolHandoff.tools(for: k) { XCTAssertNotNil(TOOLS.first { $0.id == id }, "\(id) is in the catalog") }
        }
        XCTAssertTrue(ToolHandoff.tools(for: .pdf).contains("pdfsign"))
        XCTAssertTrue(ToolHandoff.tools(for: .image).contains("animate"))
        XCTAssertEqual(ToolHandoff.tools(for: .image).first, "sticker")
        XCTAssertEqual(searchTools("sticker maker").first?.id, "sticker")
        ToolHandoff.shared.put(.file(Data("%PDF".utf8), ext: "pdf"), for: "pdfsign")
        let handed = ToolHandoff.shared.take("pdfsign")
        XCTAssertNotNil(handed); XCTAssertNil(ToolHandoff.shared.take("pdfsign"), "consumed once")
        if let h = handed, let u = ToolHandoff.fileURL(h) { XCTAssertEqual(u.pathExtension, "pdf"); try? FileManager.default.removeItem(at: u) }
        else { XCTFail("hand-off writes a file") }
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
        // Regression guard for the "one long white image" bug: the composite must actually contain the
        // pages, not come back blank. (A GPU-backed renderer silently blanked very tall stitches.)
        let ctx = CIContext()
        let ci = CIImage(cgImage: try XCTUnwrap(out.cgImage))
        let avg = try XCTUnwrap(ColorVision.averageColor(of: ci, region: CGRect(x: 0, y: 0, width: 1, height: 1), context: ctx))
        XCTAssertLessThan((avg.x + avg.y + avg.z) / 3, 0.95, "stitched output must contain the pages, not be a blank white image")
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

    // MARK: Contacts — health categorisation

    func testContactsCategorize() {
        func rec(_ id: String, _ name: String, nums: [String] = [], mails: [String] = []) -> ContactRec {
            ContactRec(id: id, name: name, numbers: nums, emails: mails)
        }
        let recs = [
            rec("a", "Alice", nums: ["5551234567"]),   // complete
            rec("b", "Bob", mails: ["bob@x.com"]),      // named, email only, no number
            rec("c", "Carla"),                          // named, no number, no email
            rec("d", "", nums: ["5559999999"]),         // no name, has number
            rec("e", "", mails: ["x@y.com"]),           // no name, email only
            rec("f", ""),                               // empty
        ]
        let r = ContactsReport.categorize(total: recs.count, recs: recs, groups: [], sources: [])
        XCTAssertEqual(Set(r.noPhone.map(\.id)), ["b", "c"])
        XCTAssertEqual(Set(r.emailOnly.map(\.id)), ["b", "e"])
        XCTAssertEqual(Set(r.noName.map(\.id)), ["d", "e"])
        XCTAssertEqual(r.empty.map(\.id), ["f"])
    }

    // MARK: Memory — visual + text search

    func testMemorySynonymAndColorSearch() {
        let red = MemoryEngine.Entry(id: "1", date: Date(), text: "", modified: Date(), readOK: true,
                                     labels: ["clothing", "person"], colors: ["red", "black"], isScreenshot: false, isVideo: false)
        let plain = MemoryEngine.Entry(id: "2", date: Date(), text: "Wi-Fi password hunter2", modified: Date(), readOK: true,
                                       labels: ["document"], colors: ["white"], isScreenshot: true, isVideo: false)
        // "red dress" → colour red + 'dress' expands to clothing/person labels.
        XCTAssertEqual(MemoryEngine.search("red dress", in: [red, plain]).first?.id, "1")
        // text search still works.
        XCTAssertEqual(MemoryEngine.search("wifi password", in: [red, plain]).first?.id, "2")
        // no false positive for something absent.
        XCTAssertTrue(MemoryEngine.search("blue car", in: [red, plain]).isEmpty)
    }

    // MARK: Privacy Scrubber — irreversible redaction + metadata strip

    func testScrubberClassifiesPersonalTextForAutoHiding() {
        // Personal → hidden by default: plates, phone/card/ID numbers, emails, DOBs.
        for s in ["7XYZ123", "ABC 1234", "(312) 555-0148", "3125550148", "4111 1111 1111 1111",
                  "priya@northwind.io", "DOB 09/14/1986", "SSN 078-05-1120"] {
            XCTAssertTrue(Scrubber.looksPersonal(s), "\(s) should auto-hide")
        }
        // Ordinary prose → left off so a document isn't blacked out wholesale.
        for s in ["Whole Foods Market", "Total", "Agreement", "Summer Block Party", "the", "Receipt"] {
            XCTAssertFalse(Scrubber.looksPersonal(s), "\(s) should NOT auto-hide")
        }
    }

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

    // MARK: PDF annotate — marks baked in, page count kept, text preserved

    /// Annotate must bake highlighter + freehand marks into the raster, keep every page, and — unlike
    /// redaction — leave the underlying text selectable (the rebuilt pages are re-OCR'd).
    func testAnnotateBakesMarksKeepsPagesAndText() throws {
        let src = try XCTUnwrap(DocEngine.pdf([DocEngine.Page(source: Self.text("REPORT 2026"), filter: .enhance)],
                                              options: .init(searchable: false)))
        // Highlight sits in the top white band (above the text at y≈0.32); a red pen stroke crosses the page.
        let hl = DocEngine.Annotation(kind: .highlight(CGRect(x: 0.08, y: 0.05, width: 0.6, height: 0.15)), color: .yellow)
        let pen = DocEngine.Annotation(kind: .stroke(points: [CGPoint(x: 0.1, y: 0.9), CGPoint(x: 0.9, y: 0.9)], width: 0.02), color: .red)
        let out = try XCTUnwrap(DocEngine.annotate(src, marks: [[hl, pen]]))
        let doc = try XCTUnwrap(PDFDocument(data: out))
        XCTAssertEqual(doc.pageCount, 1, "annotate must keep the page count")
        XCTAssertFalse(doc.findString("REPORT", withOptions: .caseInsensitive).isEmpty, "text layer lost after annotate")
        // The highlight is genuinely in the pixels: a point inside the (previously white) rect is now yellow-ish.
        let page = try XCTUnwrap(doc.page(at: 0))
        let b = page.bounds(for: .mediaBox)
        let img = page.thumbnail(of: CGSize(width: b.width * 2, height: b.height * 2), for: .mediaBox)
        let c = try XCTUnwrap(Self.pixelRGB(img, 0.3, 0.1), "could not sample pixel")
        XCTAssertLessThan(c.b, 215, "highlight should drop the blue channel (yellow), got \(c)")
        XCTAssertGreaterThan(c.r - c.b, 25, "highlighted pixel should read yellow (r ≫ b), got \(c)")
    }

    /// Edge cases: no marks on a page is a no-op that still returns every page; garbage in → nil, never a crash.
    func testAnnotateHandlesEmptyMarksAndBadInput() throws {
        let src = try XCTUnwrap(DocEngine.pdf((1...3).map { DocEngine.Page(source: Self.text("P\($0)"), filter: .color) },
                                              options: .init(searchable: false)))
        let out = try XCTUnwrap(DocEngine.annotate(src, marks: [[], [], []]))
        XCTAssertEqual(PDFDocument(data: out)?.pageCount, 3, "empty marks must still return every page")
        XCTAssertNil(DocEngine.annotate(Data("not a pdf".utf8), marks: []), "unreadable input returns nil")
    }

    /// Sample one pixel of an image at a normalized top-left point. Returns nil if the image has no bitmap.
    private static func pixelRGB(_ img: UIImage, _ fx: CGFloat, _ fy: CGFloat) -> (r: Int, g: Int, b: Int)? {
        guard let cg = img.cgImage else { return nil }
        let x = min(max(Int(fx * CGFloat(cg.width)), 0), cg.width - 1)
        let y = min(max(Int(fy * CGFloat(cg.height)), 0), cg.height - 1)
        let px = Self.rgba(cg, width: 1, height: 1, in: CGRect(x: -CGFloat(x), y: -CGFloat(cg.height - 1 - y), width: CGFloat(cg.width), height: CGFloat(cg.height)))
        return (Int(px[0]), Int(px[1]), Int(px[2]))
    }

    /// Draw `cg` into a fresh w×h RGBA (premultiplied) bitmap and return its bytes, top row first.
    /// The buffer pointer is only used inside withUnsafeMutableBytes, so the read is well-defined.
    static func rgba(_ cg: CGImage, width w: Int, height h: Int, in rect: CGRect) -> [UInt8] {
        var px = [UInt8](repeating: 0, count: w * h * 4)
        px.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?
                .draw(cg, in: rect)
        }
        return px
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
        let fixture = await Self.movie(seconds: 3.0, size: CGSize(width: 1920, height: 1080), noisy: true)
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

    // MARK: File Opener

    /// The file-kind classifier drives the icon, label and text-peek decision, so it must sort the
    /// everyday extensions correctly, stay case-insensitive, and never crash on a blank/odd extension.
    func testFileKindClassifier() {
        XCTAssertEqual(FileKind.of(ext: "pdf"), .document)
        XCTAssertEqual(FileKind.of(ext: "DOCX"), .document)      // case-insensitive
        XCTAssertEqual(FileKind.of(ext: "pages"), .document)
        XCTAssertEqual(FileKind.of(ext: "HEIC"), .image)
        XCTAssertEqual(FileKind.of(ext: "mov"), .video)
        XCTAssertEqual(FileKind.of(ext: "m4a"), .audio)
        XCTAssertEqual(FileKind.of(ext: "zip"), .archive)
        XCTAssertEqual(FileKind.of(ext: "swift"), .code)
        XCTAssertEqual(FileKind.of(ext: "json"), .code)
        XCTAssertEqual(FileKind.of(ext: "txt"), .text)
        XCTAssertEqual(FileKind.of(ext: "csv"), .text)
        XCTAssertEqual(FileKind.of(ext: "sqlite"), .data)
        XCTAssertEqual(FileKind.of(ext: ""), .other)            // no extension — never crashes
        XCTAssertEqual(FileKind.of(ext: "wat"), .other)         // unknown — falls through
        // Every kind must map to a non-empty SF Symbol so the info card never shows a blank icon.
        for k in [FileKind.document, .image, .video, .audio, .archive, .code, .text, .data, .other] {
            XCTAssertFalse(k.icon.isEmpty)
        }
    }

    // MARK: Warranty & Receipts

    private func receipt(store: String, items: [String], raw: String = "", months: Int? = nil, purchased: Date? = nil) -> Receipt {
        Receipt(imageFile: "x.jpg", store: store, purchaseDate: purchased, total: "", rawText: raw.isEmpty ? (store + " " + items.joined(separator: " ")) : raw, items: items, warrantyMonths: months)
    }

    /// The promise of this tool is forgiving search: a misspelt store and a loose word still find it.
    func testReceiptFuzzySearchFindsTypoAndVagueWords() {
        let costco = receipt(store: "Costco Wholesale", items: ["Samsung 55\" TV", "Rotisserie Chicken"])
        let depot = receipt(store: "Home Depot", items: ["DeWalt Cordless Drill", "Screws"])
        let all = [costco, depot]

        // Misspelt store + loose item word.
        XCTAssertEqual(ReceiptSearch.rank(all, query: "cosco tv").first?.store, "Costco Wholesale")
        // Vague item recall, no store named.
        XCTAssertEqual(ReceiptSearch.rank(all, query: "the drill").first?.store, "Home Depot")
        // Unrelated query returns nothing rather than a false match.
        XCTAssertTrue(ReceiptSearch.rank(all, query: "airplane ticket").isEmpty)
        // Empty query lists everything (most recent first), never filters to zero.
        XCTAssertEqual(ReceiptSearch.rank(all, query: "   ").count, 2)
    }

    func testReceiptSimilarityIsBoundedAndSane() {
        XCTAssertEqual(ReceiptSearch.sim("tv", "tv"), 1, accuracy: 0.0001)
        XCTAssertGreaterThan(ReceiptSearch.sim("cosco", "costco"), 0.6)   // one edit
        XCTAssertEqual(ReceiptSearch.sim("cat", "elephant"), 0)           // nothing in common → zeroed
    }

    /// Warranty countdown must be correct — it's what the reminder and the "expiring soon" list rely on.
    func testWarrantyCountdown() {
        let cal = Calendar.current
        let elevenMonthsAgo = cal.date(byAdding: .month, value: -11, to: Date())!
        let r = receipt(store: "Best Buy", items: ["Laptop"], months: 12, purchased: elevenMonthsAgo)
        XCTAssertNotNil(r.warrantyEnds)
        let days = r.daysLeftOnWarranty ?? -999
        XCTAssertTrue((20...40).contains(days), "expected ~1 month left, got \(days)")
        // No warranty tracked → no end date, no countdown.
        let none = receipt(store: "Cafe", items: ["Coffee"])
        XCTAssertNil(none.warrantyEnds)
        XCTAssertNil(none.daysLeftOnWarranty)
    }

    // MARK: Price Check

    func testUnitPriceComparesAcrossDifferentUnits() {
        // $3 for 500 g = $0.60/100g; $5 for 1 kg = $0.50/100g → the kilo is the better deal.
        let a = PriceBrain.Entry(name: "Jar", price: 3.00, sizeText: "500 g")
        let b = PriceBrain.Entry(name: "Tub", price: 5.00, sizeText: "1 kg")
        let ranked = PriceBrain.rank([a, b])
        let best = ranked.first { $0.bestValue }
        XCTAssertEqual(best?.entry.name, "Tub")
        XCTAssertEqual(best?.savingsPct.map { Int($0) }, 16)   // (0.60-0.50)/0.60

        // Mixed system: 16 oz (=453.6 g) vs 500 g at the same price → the 500 g wins per 100 g.
        let oz = PriceBrain.Entry(name: "US", price: 4.00, sizeText: "16 oz")
        let g = PriceBrain.Entry(name: "Metric", price: 4.00, sizeText: "500 g")
        XCTAssertEqual(PriceBrain.rank([oz, g]).first { $0.bestValue }?.entry.name, "Metric")
    }

    func testTroyOunceForPreciousMetals() {
        // A plain "oz" is a standard ounce unless troy is requested; "ozt" is always troy.
        XCTAssertEqual(PriceBrain.parseSize("1 oz")?.qty ?? 0, 28.3495, accuracy: 0.01)
        XCTAssertEqual(PriceBrain.parseSize("1 oz", troyOunce: true)?.qty ?? 0, 31.1035, accuracy: 0.01)
        XCTAssertEqual(PriceBrain.parseSize("1 ozt")?.qty ?? 0, 31.1035, accuracy: 0.01)

        // Precious-metal names are detected so the Best-deal screen defaults troy on.
        XCTAssertTrue(PriceBrain.looksPrecious(["1 oz Sunshine Minting Gold Bar", "50 gram Gold Bar"]))
        XCTAssertFalse(PriceBrain.looksPrecious(["Peanut butter", "Olive oil"]))

        // The exact screenshot case: 1 oz gold bar $4,039.99 vs 50 g $6,469.99.
        let bar1oz = PriceBrain.Entry(name: "1 oz Sunshine Gold Bar", price: 4039.99, sizeText: "1 oz")
        let bar50g = PriceBrain.Entry(name: "50 gram Gold Bar", price: 6469.99, sizeText: "50 g")
        // With troy ounces the two are within ~0.5% per gram — the 50 g is the (marginally) better deal.
        let troyRanked = PriceBrain.rank([bar1oz, bar50g], troyOunce: true)
        XCTAssertEqual(troyRanked.first { $0.bestValue }?.entry.name, "50 gram Gold Bar")
        XCTAssertEqual(troyRanked.first { $0.bestValue }?.savingsPct.map { Int($0) }, 0, "per-gram gap should round to 0% with troy oz")
        // The standard ounce would wrongly inflate that gap to ~9% — proving the fix matters.
        let avoirRanked = PriceBrain.rank([bar1oz, bar50g], troyOunce: false)
        XCTAssertGreaterThan(avoirRanked.first { $0.bestValue }?.savingsPct ?? 0, 5)
    }

    func testPriceExtractionFromListingText() {
        // Mimics the OCR of a store listing: name+size on one line, price a line or two below.
        let text = """
        1 oz Sunshine Minting Breakaway Gold Bar (New in Assay)
        Online Price
        $4,039.99
        50 gram Gold Bar Argor-Heraeus Lunar Year of the Goat (New in Assay)
        Online Price
        $6,469.99
        """
        let found = PriceBrain.extract(from: text)
        XCTAssertEqual(found.count, 2)
        XCTAssertTrue(found[0].size.lowercased().contains("oz"))
        XCTAssertTrue(found[0].price.contains("4,039"))
        XCTAssertTrue(found[1].size.lowercased().contains("gram") || found[1].size.contains("50"))
        XCTAssertTrue(found[1].price.contains("6,469"))
    }

    func testSizeParserHandlesMultipacksAndJunk() {
        XCTAssertEqual(PriceBrain.parseSize("2 x 200ml"), PriceBrain.Size(qty: 400, base: .volume))
        XCTAssertEqual(PriceBrain.parseSize("1.5 L"), PriceBrain.Size(qty: 1500, base: .volume))
        XCTAssertEqual(PriceBrain.parseSize("12 ct"), PriceBrain.Size(qty: 12, base: .count))
        XCTAssertEqual(PriceBrain.parseSize("1 kg"), PriceBrain.Size(qty: 1000, base: .mass))
        XCTAssertNil(PriceBrain.parseSize("family size"))
    }

    func testLabelDecodeFlagsAndServingMath() {
        let r = LabelDecode.decode("Ingredients: water, high fructose corn syrup, red 40. 6 servings per container. 150 calories per serving.")
        XCTAssertTrue(r.flags.contains { $0.note.contains("sugar") })        // HFCS flagged
        XCTAssertTrue(r.flags.contains { $0.term.contains("red 40") })        // dye flagged
        XCTAssertNotNil(r.servingNote)
        XCTAssertTrue(r.servingNote?.contains("900") ?? false)               // 6 × 150
    }

    // MARK: Identify

    func testIdentifierCleansLabels() {
        XCTAssertEqual(Identifier.cleanLabel("golden_retriever"), "Golden Retriever")
        XCTAssertEqual(Identifier.cleanLabel("espresso"), "Espresso")
        XCTAssertEqual(Identifier.cleanLabel("coffee_mug"), "Coffee Mug")
    }

    // MARK: Contacts auto-backup

    func testContactsBackupDueLogic() {
        let now = Date()
        let fortyDaysAgo = now.addingTimeInterval(-40 * 86_400)
        // Never backed up → due (for any live cadence).
        XCTAssertTrue(ContactsBackup.isDue(last: nil, frequency: .monthly, now: now))
        // Just backed up → not due.
        XCTAssertFalse(ContactsBackup.isDue(last: now, frequency: .monthly, now: now))
        // 40 days on a monthly (30-day) cadence → due.
        XCTAssertTrue(ContactsBackup.isDue(last: fortyDaysAgo, frequency: .monthly, now: now))
        // 40 days on a quarterly cadence → not yet.
        XCTAssertFalse(ContactsBackup.isDue(last: fortyDaysAgo, frequency: .quarterly, now: now))
        // Off → never due, even if never backed up.
        XCTAssertFalse(ContactsBackup.isDue(last: nil, frequency: .off, now: now))
    }

    // MARK: transcription — the "one line from a 22-minute memo" bug class
    //
    // The real on-device recogniser can't run in the simulator, so the full audio→text path is
    // asserted on a real device by the mobileqa gate. What CAN regress silently in code — and what
    // actually shipped — is the WHOLE-FILE coverage: reading only one window, or losing windows when
    // stitching. These lock that down deterministically on every build.

    func testTranscriptionCoversTheWholeRecording() {
        // A 22-minute recording at 16 kHz must be split across many windows, never transcribed as one.
        let sr = 16_000.0
        let frames22min = AVAudioFramePosition(sr * 22 * 60)
        let n = Transcriber.windowCount(frames: frames22min, sampleRate: sr)
        XCTAssertEqual(n, 33, "a 22-minute file must cover the whole recording in ~33 windows, not one")
        XCTAssertGreaterThan(n, 1, "regression guard: long recordings must never collapse to a single window")

        // Scales with length and sample rate; a short clip is one window; empty/invalid is none.
        XCTAssertEqual(Transcriber.windowCount(frames: AVAudioFramePosition(sr * 10), sampleRate: sr), 1)
        XCTAssertEqual(Transcriber.windowCount(frames: AVAudioFramePosition(sr * 80), sampleRate: sr), 2)
        XCTAssertEqual(Transcriber.windowCount(frames: AVAudioFramePosition(44_100 * 60), sampleRate: 44_100), 2)
        XCTAssertEqual(Transcriber.windowCount(frames: 0, sampleRate: sr), 0)
        XCTAssertEqual(Transcriber.windowCount(frames: 1000, sampleRate: 0), 0)
    }

    func testTranscriptionStitchKeepsEveryWindow() {
        // Every window's words survive, in order, joined with a single space — nothing dropped.
        XCTAssertEqual(Transcriber.stitch(["Hello there.", "How are you?", "Goodbye."]),
                       "Hello there. How are you? Goodbye.")
        // Empty/whitespace windows (a silent stretch) are skipped, not turned into double spaces.
        XCTAssertEqual(Transcriber.stitch(["first", "   ", "", "second"]), "first second")
        // A result that trims to the same thing it started as is unchanged.
        XCTAssertEqual(Transcriber.stitch([" padded "]), "padded")
        XCTAssertEqual(Transcriber.stitch([]), "")
        // The failure mode we shipped: if only the first window were kept, the transcript would be one
        // line. Stitching 33 non-empty windows must yield 33 pieces of text, not one.
        let many = (1...33).map { "window\($0)" }
        XCTAssertEqual(Transcriber.stitch(many).split(separator: " ").count, 33)
    }

    func testTranscriptionProgressIsHonest() {
        let total = AVAudioFramePosition(16_000 * 60 * 22)
        XCTAssertEqual(Transcriber.fraction(0, of: total), 0, accuracy: 0.0001)
        XCTAssertEqual(Transcriber.fraction(total / 2, of: total), 0.5, accuracy: 0.0001)
        XCTAssertEqual(Transcriber.fraction(total, of: total), 1, accuracy: 0.0001)
        // Monotonic and clamped — never jumps backward, never exceeds 1, never NaN on an empty file.
        var last = 0.0
        for pos in stride(from: AVAudioFramePosition(0), through: total, by: Int(total / 20)) {
            let f = Transcriber.fraction(pos, of: total)
            XCTAssertGreaterThanOrEqual(f, last); XCTAssertLessThanOrEqual(f, 1); last = f
        }
        XCTAssertEqual(Transcriber.fraction(100, of: 0), 0, "no divide-by-zero on an empty file")
    }

    // MARK: Route planner (Phase 1) — places → one-tap map links + order, offline
    func testRoutePlanLinksPlacesAndOrders() {
        let tasks = ["Get the food from Walmart first", "Drop food at the cats and dogs shelter", "Take Dion to the temple"]
        let plan = RoutePlan.plan(from: tasks)
        XCTAssertTrue(plan.contains("maps.apple.com"), "a task with a place must get an Apple Maps link")
        XCTAssertTrue(plan.contains("google.com/maps"), "…and a Google Maps link")
        XCTAssertTrue(plan.hasPrefix("1. Get the food from Walmart first"), "a 'first' task leads the plan")
        for t in ["Walmart", "shelter", "temple"] { XCTAssertTrue(plan.contains(t), "lost task mentioning '\(t)'") }
    }

    func testRoutePlanNeverGuessesANameAndStaysGraceful() {
        // A person's name is never turned into a map search; a task with no destination gets no link.
        XCTAssertNil(RoutePlan.destination(in: "Email Ana the budget by Thursday"))
        XCTAssertNil(RoutePlan.destination(in: "Call the vendor about the invoice"))
        XCTAssertNil(RoutePlan.destination(in: "Finish it before I leave"))
        XCTAssertNil(RoutePlan.destination(in: "Send the budget to Ana by Thursday"), "'to Ana' is a person, not a place")
        XCTAssertEqual(RoutePlan.destination(in: "Pick up milk from Costco"), "Costco")
        XCTAssertEqual(RoutePlan.destination(in: "Drive to the Oak Street Clinic"), "Oak Street Clinic", "a real place type is kept")
        // A list with no places is a clean numbered list — no links, no crash.
        let plain = RoutePlan.plan(from: ["Call the vendor", "Review the checklist"])
        XCTAssertFalse(plain.contains("maps"), "no place → no link")
        XCTAssertTrue(plain.hasPrefix("1. Call the vendor"))
        // Empty in → empty out.
        XCTAssertEqual(RoutePlan.plan(from: []), "")
    }

    func testRoutePlanRoutesEmailAndCallTasksToTheRightApp() {
        // "Email … about X" → a Mail draft with the subject; a call with a number → a tel link.
        let mail = RoutePlan.emailDraft(for: "Email Ana about the Q3 budget")
        XCTAssertNotNil(mail)
        XCTAssertTrue(mail!.absoluteString.hasPrefix("mailto:?subject="))
        XCTAssertTrue(mail!.absoluteString.contains("Q3"), "the subject should carry what it's about")
        XCTAssertNil(RoutePlan.emailDraft(for: "Buy milk and eggs"), "a non-email task gets no draft")

        XCTAssertEqual(RoutePlan.callLink(for: "Call the vendor on (312) 555-0147")?.absoluteString, "tel:3125550147")
        XCTAssertNil(RoutePlan.callLink(for: "Call the vendor about the invoice"), "no number → no call link, not a wrong one")

        // A mixed day plans each task to its own action.
        let plan = RoutePlan.plan(from: ["Take the dog out", "Buy water from Costco", "Email the landlord about the lease", "Call mom at 555-123-4567"])
        XCTAssertTrue(plan.contains("google.com/maps"))   // Costco → directions
        XCTAssertTrue(plan.contains("mailto:"))           // landlord → draft email
        XCTAssertTrue(plan.contains("tel:5551234567"))    // mom → call
    }

    func testPDFProtectLockUnlockWatermark() throws {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 500)).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 400, height: 500)) }
        let line = DocEngine.OCRLine(text: "INVOICE", box: CGRect(x: 0.1, y: 0.1, width: 0.6, height: 0.1))
        var opts = DocEngine.PDFOptions(); opts.searchable = true
        guard let src = DocEngine.pdf(images: [img], ocr: [[line]], options: opts) else { return XCTFail("no source") }
        // Lock
        XCTAssertNil(PDFSecure.protect(src, password: ""), "empty password must be refused")
        guard let locked = PDFSecure.protect(src, password: "tenzy123") else { return XCTFail("protect nil") }
        XCTAssertTrue(PDFSecure.isLocked(locked), "the saved file must ask for a password")
        // Unlock: wrong password refused, right one gives a free-opening copy with the content intact.
        XCTAssertNil(PDFSecure.unlock(locked, password: "nope"))
        guard let opened = PDFSecure.unlock(locked, password: "tenzy123"), let doc = PDFDocument(data: opened)
        else { return XCTFail("unlock nil") }
        XCTAssertFalse(doc.isLocked)
        XCTAssertEqual(doc.pageCount, 1)
        // Watermark: on the page, original text kept, locked input refused.
        guard let wm = PDFOverlay.watermark(src, text: "CONFIDENTIAL"), let wdoc = PDFDocument(data: wm)
        else { return XCTFail("watermark nil") }
        let t = wdoc.string ?? ""
        XCTAssertTrue(t.contains("CONFIDENTIAL")); XCTAssertTrue(t.contains("INVOICE"))
        XCTAssertNil(PDFOverlay.watermark(src, text: "   "), "blank watermark refused")
    }

    func testMakeSearchableAddsRealTextLayer() async throws {
        // An image-only "scan": two pages, no text layer.
        var opts = DocEngine.PDFOptions(); opts.searchable = false
        let scan = try XCTUnwrap(DocEngine.pdf(images: [Self.text("HELLO 2026"), Self.text("INVOICE 4471")], ocr: [nil, nil], options: opts))
        XCTAssertFalse(PDFSearchable.hasText(scan), "fixture starts with no text")
        var seen: [Double] = []
        let made = await PDFSearchable.make(scan) { seen.append($0) }
        let out = try XCTUnwrap(made, "searchable PDF built")
        let doc = try XCTUnwrap(PDFDocument(data: out.data))
        XCTAssertEqual(doc.pageCount, 2, "every page kept")
        let text = (doc.string ?? "").uppercased()
        XCTAssertTrue(text.contains("HELLO"), "page 1 text now findable: \(text)")
        XCTAssertTrue(text.contains("INVOICE"), "page 2 text now findable: \(text)")
        XCTAssertGreaterThan(out.words, 1)
        XCTAssertEqual(seen.last ?? 0, 1, accuracy: 0.001, "progress reaches 100%")
        let junk = await PDFSearchable.make(Data("nope".utf8))
        XCTAssertNil(junk, "garbage refused")
    }

    func testFillFormWritesRealFields() throws {
        // A one-page form with a text box, a checkbox and a dropdown, made the way real forms are.
        let doc = PDFDocument()
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 612, height: 792)).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 612, height: 792)) }
        let page = try XCTUnwrap(PDFPage(image: blank)); doc.insert(page, at: 0)
        let name = PDFAnnotation(bounds: CGRect(x: 72, y: 680, width: 300, height: 24), forType: .widget, withProperties: nil)
        name.widgetFieldType = .text; name.fieldName = "Full name"; page.addAnnotation(name)
        let agree = PDFAnnotation(bounds: CGRect(x: 72, y: 600, width: 18, height: 18), forType: .widget, withProperties: nil)
        agree.widgetFieldType = .button; agree.widgetControlType = .checkBoxControl; agree.fieldName = "Agree"
        page.addAnnotation(agree)
        let pick = PDFAnnotation(bounds: CGRect(x: 72, y: 640, width: 200, height: 24), forType: .widget, withProperties: nil)
        pick.widgetFieldType = .choice; pick.fieldName = "Country"; pick.choices = ["India", "USA"]; page.addAnnotation(pick)
        let form = try XCTUnwrap(doc.dataRepresentation())

        let fields = PDFForm.fields(form)
        XCTAssertEqual(fields.map(\.name), ["Full name", "Country", "Agree"], "reading order, top to bottom")
        XCTAssertEqual(fields.map(\.kind), [.text, .choice, .checkbox])
        var vals: [String: String] = [:]
        for f in fields {
            switch f.kind {
            case .text: vals[f.id] = "Jane Doe"
            case .choice: vals[f.id] = "USA"
            case .checkbox: vals[f.id] = "1"
            }
        }
        let filled = try XCTUnwrap(PDFForm.fill(form, values: vals))
        let back = PDFForm.fields(filled)
        XCTAssertEqual(back.first { $0.name == "Full name" }?.value, "Jane Doe")
        XCTAssertEqual(back.first { $0.name == "Country" }?.value, "USA")
        XCTAssertEqual(back.first { $0.name == "Agree" }?.value, "1", "checkbox ticked")
        XCTAssertEqual(PDFForm.fields(PDFDocument(data: filled)?.dataRepresentation() ?? Data()).count, 3, "still a working form")

        // A flat PDF has no fields (the view points to Sign → Add text instead).
        var opts = DocEngine.PDFOptions(); opts.searchable = false
        let flat = try XCTUnwrap(DocEngine.pdf(images: [blank], ocr: [nil], options: opts))
        XCTAssertTrue(PDFForm.fields(flat).isEmpty)
        XCTAssertNil(PDFForm.fill(Data("nope".utf8), values: [:]))
    }

    func testSignPDFStampsAndKeepsOriginalText() throws {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 500)).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 400, height: 500)) }
        let line = DocEngine.OCRLine(text: "CONTRACT", box: CGRect(x: 0.1, y: 0.1, width: 0.6, height: 0.1))
        var opts = DocEngine.PDFOptions(); opts.searchable = true
        guard let src = DocEngine.pdf(images: [img], ocr: [[line]], options: opts) else { return XCTFail("no source") }
        var st = DocEngine.Stamp(kind: .text("SIGNED HERE")); st.center = CGPoint(x: 0.5, y: 0.8); st.width = 0.5
        guard let outData = PDFOverlay.stamp(src, stamps: [0: [st]]), let out = PDFDocument(data: outData)
        else { return XCTFail("stamp returned nil") }
        XCTAssertEqual(out.pageCount, 1)
        let text = out.string ?? ""
        XCTAssertTrue(text.contains("SIGNED"), "the stamp must be on the page")
        XCTAssertTrue(text.contains("CONTRACT"), "the original page must stay vector — its text still there")
        let a = PDFDocument(data: src)!.page(at: 0)!.bounds(for: .mediaBox).size
        let b = out.page(at: 0)!.bounds(for: .mediaBox).size
        XCTAssertEqual(a.width, b.width, accuracy: 1); XCTAssertEqual(a.height, b.height, accuracy: 1)
    }

    func testPDFPagesReorderRotateRemove() throws {
        // Three pages of different heights so the output order is checkable from page bounds.
        func page(_ h: CGFloat) -> UIImage {
            UIGraphicsImageRenderer(size: CGSize(width: 400, height: h)).image { c in
                UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 400, height: h)) }
        }
        var opts = DocEngine.PDFOptions(); opts.searchable = false
        guard let src = DocEngine.pdf(images: [page(300), page(500), page(700)], ocr: [nil, nil, nil], options: opts)
        else { return XCTFail("could not build source PDF") }
        // Keep page 3 then page 1 (drop page 2), turning page 3 a quarter clockwise.
        let plan = [PDFPages.Item(index: 2, rotation: 90), PDFPages.Item(index: 0)]
        guard let outData = PDFPages.build(src, items: plan), let out = PDFDocument(data: outData)
        else { return XCTFail("build returned nil") }
        XCTAssertEqual(out.pageCount, 2, "the removed page must be gone")
        let h0 = out.page(at: 0)!.bounds(for: .mediaBox).height, h1 = out.page(at: 1)!.bounds(for: .mediaBox).height
        XCTAssertGreaterThan(h0, h1, "the tall page 3 must now come first")
        XCTAssertEqual(out.page(at: 0)!.rotation, 90)
        XCTAssertEqual(out.page(at: 1)!.rotation, 0)
        XCTAssertEqual(PDFPages.normalized(-90), 270)
        XCTAssertNil(PDFPages.build(src, items: [PDFPages.Item(index: 9)]), "nothing usable → nil, never an empty file")
    }

    func testVideoFormatFillAndFit() throws {
        let src = CGSize(width: 1920, height: 1080)      // a landscape video
        let reels = CGSize(width: 1080, height: 1920)    // into a 9:16 canvas
        // Aspect-fill crop: fills 9:16 with no bars → keeps full height, trims width, centered.
        let crop = VideoFormat.fillCrop(source: src, target: reels)
        XCTAssertEqual(crop.height, 1080, accuracy: 0.5, "fill keeps the full source height")
        XCTAssertEqual(crop.width, 607.5, accuracy: 0.5, "fill trims width to the 9:16 slice")
        XCTAssertEqual(crop.midX, src.width / 2, accuracy: 0.5, "crop is centered")
        // Aspect-fit: whole frame kept, letterboxed top/bottom, centered.
        let fit = VideoFormat.fitRect(source: src, target: reels)
        XCTAssertEqual(fit.width, 1080, accuracy: 0.5, "fit keeps the full width")
        XCTAssertEqual(fit.height, 607.5, accuracy: 0.5, "fit scales height down, no crop")
        XCTAssertEqual(fit.midY, reels.height / 2, accuracy: 0.5, "fit is centered vertically")
        XCTAssertNotNil(VideoFormat.preset("reels"))
    }

    func testPdfTextExtractsEmbeddedLayer() throws {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300)).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let line = DocEngine.OCRLine(text: "INVOICE 2026", box: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.2))
        var opts = DocEngine.PDFOptions(); opts.searchable = true
        guard let data = DocEngine.pdf(images: [img], ocr: [[line]], options: opts) else { return XCTFail("could not build source PDF") }
        let extracted = DocEngine.pdfText(data)
        XCTAssertTrue(extracted.contains("INVOICE"), "should pull the embedded text layer out of the PDF")
    }

    /// PDF → image converter: one decodable image per page, both JPEG and PNG, garbage in → empty.
    func testPdfToImagesRendersEveryPage() throws {
        let pages = (1...3).map { DocEngine.Page(source: Self.text("PAGE \($0)"), filter: .color) }
        let data = try XCTUnwrap(DocEngine.pdf(pages, options: .init(searchable: false)))
        let jpgs = DocEngine.pdfToImages(data)
        XCTAssertEqual(jpgs.count, 3, "one JPEG per page")
        for d in jpgs { XCTAssertNotNil(UIImage(data: d), "each exported page must decode as an image") }
        let pngs = DocEngine.pdfToImages(data, png: true)
        XCTAssertEqual(pngs.count, 3, "one PNG per page")
        XCTAssertNotNil(UIImage(data: try XCTUnwrap(pngs.first)))
        XCTAssertTrue(DocEngine.pdfToImages(Data("not a pdf".utf8)).isEmpty, "garbage in → empty, never a crash")
    }

    func testRedactionTrulyRemovesHiddenText() throws {
        // A searchable PDF carrying an invisible, selectable text layer that reads "SECRET".
        let img = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300)).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let line = DocEngine.OCRLine(text: "SECRET", box: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.2))
        var opts = DocEngine.PDFOptions(); opts.searchable = true
        guard let src = DocEngine.pdf(images: [img], ocr: [[line]], options: opts),
              let srcDoc = PDFDocument(data: src) else { return XCTFail("could not build source PDF") }
        XCTAssertTrue((srcDoc.string ?? "").contains("SECRET"), "sanity: the source has a selectable text layer")

        // Redact the whole page — the hidden text must be destroyed, not merely covered.
        guard let redacted = DocEngine.redact(src, boxes: [[CGRect(x: 0, y: 0, width: 1, height: 1)]]),
              let outDoc = PDFDocument(data: redacted) else { return XCTFail("redaction returned nil") }
        XCTAssertEqual(outDoc.pageCount, 1)
        XCTAssertFalse((outDoc.string ?? "").contains("SECRET"),
                       "redaction must flatten the page so the hidden text is gone, not sit a box over selectable text")
    }

    // MARK: Audio Convert — format conversion (item 4)

    /// Write a short real audio file (a 440 Hz tone) to disk so the converter has genuine samples to
    /// chew on, not an empty container.
    private func makeToneFile(seconds: Double = 1.0, sampleRate: Double = 44_100) throws -> URL {
        let fmt = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let frames = AVAudioFrameCount(seconds * sampleRate)
        let buf = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames))
        buf.frameLength = frames
        let ch = try XCTUnwrap(buf.floatChannelData?[0])
        for i in 0..<Int(frames) { ch[i] = Float(sin(2 * Double.pi * 440 * Double(i) / sampleRate)) * 0.3 }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tone-\(UUID().uuidString.prefix(6)).caf")
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        try file.write(from: buf)
        return url
    }

    /// Every output format the tool offers must produce a non-empty file that is a real, playable audio
    /// asset of roughly the original length — a true end-to-end output assertion, not "did it open".
    func testAudioConvertProducesPlayableFilesEveryFormat() async throws {
        let src = try makeToneFile(seconds: 1.0)
        defer { try? FileManager.default.removeItem(at: src) }
        for format in AudioConvert.Format.allCases {
            let outcome = await AudioConvert.convert(src, to: format)
            guard case .success(let out) = outcome else {
                XCTFail("\(format.title) conversion failed"); continue
            }
            defer { try? FileManager.default.removeItem(at: out) }
            XCTAssertEqual(out.pathExtension, format.ext, "\(format.title) wrong extension")
            let size = ((try? FileManager.default.attributesOfItem(atPath: out.path))?[.size] as? Int) ?? 0
            XCTAssertGreaterThan(size, 1_000, "\(format.title) output is empty/tiny")
            let outAsset = AVURLAsset(url: out)
            let tracks = try await outAsset.loadTracks(withMediaType: .audio)
            XCTAssertFalse(tracks.isEmpty, "\(format.title) output has no audio track")
            let dur = try await outAsset.load(.duration).seconds
            XCTAssertEqual(dur, 1.0, accuracy: 0.25, "\(format.title) duration drifted from the source")
        }
    }

    /// A file with no audio must fail cleanly with a message, never crash or hang.
    func testAudioCompressShrinksAndStaysPlayable() async throws {
        let src = try makeToneFile(seconds: 4.0)
        defer { try? FileManager.default.removeItem(at: src) }
        var sizes: [AudioConvert.Level: Int] = [:]
        for l in [AudioConvert.Level.high, .smallest] {
            let outcome = await AudioConvert.compress(src, level: l)
            guard case .success(let made) = outcome else { XCTFail("\(l.title) compress failed"); continue }
            defer { try? FileManager.default.removeItem(at: made.url) }
            XCTAssertEqual(made.url.pathExtension, "m4a")
            let size = ((try? FileManager.default.attributesOfItem(atPath: made.url.path))?[.size] as? Int) ?? 0
            XCTAssertGreaterThan(size, 1_000, "\(l.title) output is empty")
            let dur = (try? await AVURLAsset(url: made.url).load(.duration))?.seconds ?? 0
            XCTAssertEqual(dur, 4.0, accuracy: 0.3, "\(l.title) keeps the full length")
            sizes[made.level] = size
        }
        if let hi = sizes[.high], let lo = sizes[.smallest] { XCTAssertLessThan(lo, hi, "smallest really is smaller") }
        // Fit-under picks the best level that fits, and says honestly when nothing fits.
        XCTAssertEqual(AudioConvert.level(fitting: 25_000_000, seconds: 600).level, .high)
        XCTAssertEqual(AudioConvert.level(fitting: 3_000_000, seconds: 600).level, .smallest)
        XCTAssertTrue(AudioConvert.level(fitting: 3_000_000, seconds: 600).fits)
        XCTAssertFalse(AudioConvert.level(fitting: 1_000_000, seconds: 3600).fits)
        let junk = FileManager.default.temporaryDirectory.appendingPathComponent("junk-\(UUID().uuidString.prefix(6)).caf")
        try Data("not audio".utf8).write(to: junk)
        defer { try? FileManager.default.removeItem(at: junk) }
        if case .success = await AudioConvert.compress(junk, level: .balanced) { XCTFail("garbage should fail") }
    }

    func testAudioJoinAndSpeedKeepRealLengths() async throws {
        let a = try makeToneFile(seconds: 1.0), b = try makeToneFile(seconds: 2.0)
        defer { try? FileManager.default.removeItem(at: a); try? FileManager.default.removeItem(at: b) }
        guard case .success(let joined) = await AudioMix.merge([a, b], gap: 0.5) else { return XCTFail("join failed") }
        defer { try? FileManager.default.removeItem(at: joined) }
        let jd = (try? await AVURLAsset(url: joined).load(.duration))?.seconds ?? 0
        XCTAssertEqual(jd, 3.5, accuracy: 0.3, "1s + 0.5s pause + 2s")
        guard case .success(let fast) = await AudioMix.speed(b, rate: 2) else { return XCTFail("speed failed") }
        defer { try? FileManager.default.removeItem(at: fast) }
        let fd = (try? await AVURLAsset(url: fast).load(.duration))?.seconds ?? 0
        XCTAssertEqual(fd, 1.0, accuracy: 0.25, "2s at 2x is 1s")
        let one = await AudioMix.merge([a])
        if case .failure(let f) = one { XCTAssertEqual(f, .tooFew) } else { XCTFail("one clip can't be joined") }
    }

    func testAudioTagsWriteMP3AndM4AWithoutTouchingAudio() async throws {
        // MP3: an old tag is replaced, the audio bytes after it are copied untouched.
        let audio = Data((0..<500).map { UInt8($0 % 251) })
        let oldTag = Data([0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05]) + Data(repeating: 0, count: 5)
        let art = try XCTUnwrap(AudioTags.coverJPEG(from: Self.text("ART")))
        let tags = AudioTags.Tags(title: "Café Song", artist: "Manan", album: "Tenzy", artwork: art)
        let tagged = ID3.retag(oldTag + audio, with: tags)
        XCTAssertEqual(Data(tagged.suffix(audio.count)), audio, "audio untouched")
        XCTAssertEqual(tagged.count, ID3.tagLength(tagged) + audio.count, "old tag gone")
        XCTAssertEqual(ID3.parse(tagged), tags, "title/artist/album/cover read back")
        let mp3 = FileManager.default.temporaryDirectory.appendingPathComponent("tag-\(UUID().uuidString.prefix(6)).mp3")
        try (oldTag + audio).write(to: mp3)
        defer { try? FileManager.default.removeItem(at: mp3) }
        guard case .success(let outMP3) = await AudioTags.write(mp3, tags: tags) else { return XCTFail("mp3 write failed") }
        defer { try? FileManager.default.removeItem(at: outMP3) }
        let backMP3 = await AudioTags.read(outMP3)
        XCTAssertEqual(backMP3.title, "Café Song")

        // M4A: re-wrapped with iTunes tags, still plays at full length.
        let tone = try makeToneFile(seconds: 1.0)
        defer { try? FileManager.default.removeItem(at: tone) }
        guard case .success(let m4a) = await AudioConvert.convert(tone, to: .m4a) else { return XCTFail("fixture") }
        defer { try? FileManager.default.removeItem(at: m4a) }
        guard case .success(let out) = await AudioTags.write(m4a, tags: tags) else { return XCTFail("m4a write failed") }
        defer { try? FileManager.default.removeItem(at: out) }
        let back = await AudioTags.read(out)
        XCTAssertEqual(back.title, "Café Song")
        XCTAssertEqual(back.artist, "Manan")
        XCTAssertEqual(back.album, "Tenzy")
        XCTAssertNotNil(back.artwork, "cover art embedded")
        let d = (try? await AVURLAsset(url: out).load(.duration))?.seconds ?? 0
        XCTAssertEqual(d, 1.0, accuracy: 0.2)
        XCTAssertEqual(AudioTags.route(for: URL(fileURLWithPath: "/a.wav")), .convert)
    }

    func testZipMakerBuildsArchiveTheUnzipReaderOpens() throws {
        XCTAssertEqual(ZipWriter.crc32(Data("123456789".utf8)), 0xCBF43926, "standard CRC-32 check value")
        let text = Data(String(repeating: "Tenzy zips files. ", count: 200).utf8)
        let noise = Data((0..<3000).map { UInt8(($0 * 7919) % 256) })
        let items = [ZipWriter.Item(name: "notes.txt", data: text),
                     ZipWriter.Item(name: "photo.jpg", data: noise),
                     ZipWriter.Item(name: "notes.txt", data: Data("second".utf8)),
                     ZipWriter.Item(name: "café/ü.txt", data: Data("x".utf8))]
        var seen: [Double] = []
        guard case .success(let zip) = ZipWriter.zip(items, progress: { seen.append($0) }) else { return XCTFail("zip failed") }
        XCTAssertLessThan(zip.count, text.count + noise.count, "text really compressed")
        XCTAssertEqual(seen.last ?? 0, 1, accuracy: 0.001)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString.prefix(6)).zip")
        try zip.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(Given.Zip.names(in: url), ["notes.txt", "photo.jpg", "notes (2).txt", "café-ü.txt"])
        XCTAssertEqual(Given.Zip.entryData(in: url, named: "notes.txt"), text, "deflated file round-trips")
        XCTAssertEqual(Given.Zip.entryData(in: url, named: "photo.jpg"), noise)
        XCTAssertEqual(Given.Zip.entryData(in: url, named: "notes (2).txt"), Data("second".utf8))
        if case .success = ZipWriter.zip([]) { XCTFail("empty zip refused") }
    }

    func testTranscriptTidyRemovesFillersAndBuildsParagraphs() {
        XCTAssertEqual(TranscriptTidy.clean("um so the the meeting uh is friday"), "so the meeting is friday")
        XCTAssertEqual(TranscriptTidy.clean("I had had enough"), "I had had enough", "real doubles kept")
        // Raw recognizer output with no punctuation gets real sentences back.
        let raw = "um so the the meeting is on friday and uh we need to send the deck to priya by thursday uh I think the budget is fine but we should check with finance anyway the other thing is the launch date which um might slip to march so let's plan for that and also book the venue"
        let paras = TranscriptTidy.paragraphs(raw)
        XCTAssertEqual(paras.count, 2, "\(paras)")
        XCTAssertTrue(paras[0].hasPrefix("So the meeting is on Friday"), paras[0])
        XCTAssertTrue(paras[0].contains("Thursday. I think"), "sentence restored before 'I think': \(paras[0])")
        XCTAssertTrue(paras[1].hasPrefix("Anyway"), "new paragraph at the topic change")
        XCTAssertTrue(paras[1].contains("and also book the venue."), "never split after 'and'")
        XCTAssertFalse(paras.joined().lowercased().contains(" um "))
        // Already-punctuated dictation keeps its own sentences.
        let p2 = TranscriptTidy.paragraphs("Okay, um, so I had had a long day. The the client called twice. Anyway, we need to fix the login bug.")
        XCTAssertEqual(p2, ["Okay, so I had had a long day. The client called twice.", "Anyway, we need to fix the login bug."])
    }

    func testAnimateRendersEveryStyleAtTheRealFormat() async throws {
        let photos = [Self.text("ONE"), Self.text("TWO"), Self.text("THREE")]
        // Timeline math: 5 photos, normal pace, Ken Burns = 5×2.0 s holds + 4×0.7 s moves = 12.8 s.
        var five = Animate.Settings(); five.style = .kenBurns
        let tl5 = Animate.timeline(count: 5, settings: five)
        XCTAssertEqual(tl5.seconds, 12.8, accuracy: 0.05)
        XCTAssertEqual(Animate.phase(frame: 0, in: tl5), .hold(k: 0, u: 0))
        if case .move(let k, let v) = Animate.phase(frame: Int(2.35 * 30), in: tl5) {
            XCTAssertEqual(k, 0); XCTAssertEqual(v, 0.5, accuracy: 0.05)
        } else { XCTFail("2.35 s should be mid-transition") }
        XCTAssertEqual(Animate.suggestedStyle(count: 1), .kenBurns)
        XCTAssertEqual(Animate.suggestedStyle(count: 12), .zoomPulse)

        for style in Animate.Style.allCases {
            var s = Animate.Settings(); s.style = style
            s.format = try XCTUnwrap(VideoFormat.preset(style == .cube ? "youtube" : "reels"))
            s.framing = style == .crossfade ? .fit : .fill
            s.pace = .quick
            guard let url = await Animate.render(photos, settings: s, scale: 0.1, fps: 10) else {
                XCTFail("\(style.title) failed to render"); continue
            }
            defer { try? FileManager.default.removeItem(at: url) }
            let asset = AVURLAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            let track = try XCTUnwrap(tracks.first, "\(style.title) has video")
            let size = try await track.load(.naturalSize)
            XCTAssertEqual(size, Animate.evenSize(CGSize(width: s.format.size.width * 0.1, height: s.format.size.height * 0.1)),
                           "\(style.title) is exactly the platform's shape")
            let secs = try await asset.load(.duration).seconds
            XCTAssertEqual(secs, Animate.timeline(count: 3, settings: s, fps: 10).seconds, accuracy: 0.25, "\(style.title) length")
        }
        // A one-photo video works (styles that need two are disabled in the UI).
        var one = Animate.Settings(); one.style = .polaroid
        let still = try XCTUnwrap(Animate.still([photos[0]], settings: one, at: 0.9))
        XCTAssertEqual(still.size, Animate.evenSize(CGSize(width: 270, height: 480)))
        XCTAssertEqual(Animate.Style.cube.minPhotos, 2)
    }

    func testVideoReframeMakesExactPlatformSizes() async throws {
        let fixture = await Self.movie(seconds: 1.5)
        let src = try XCTUnwrap(fixture, "fixture")
        defer { try? FileManager.default.removeItem(at: src) }
        for (id, fit) in [("reels", true), ("square", false)] {
            let spec = try XCTUnwrap(VideoFormat.preset(id))
            guard let out = await VideoReframe.reframe(src, to: spec, fit: fit) else { XCTFail("\(id) reframe failed"); continue }
            defer { try? FileManager.default.removeItem(at: out) }
            let asset = AVURLAsset(url: out)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            let track = try XCTUnwrap(tracks.first)
            let size = try await track.load(.naturalSize)
            XCTAssertEqual(size, spec.size, "\(id) is the platform's exact size")
            let secs = try await asset.load(.duration).seconds
            XCTAssertEqual(secs, 1.5, accuracy: 0.3, "\(id) keeps the full length")
        }
    }

    func testMedicineScheduleRules() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let mon = cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 7))!   // a Monday, 7 am
        var m = Med(); m.name = "Vitamin D"; m.dose = "1 tablet"; m.start = cal.startOfDay(for: mon)
        m.times = [TimeOfDay(hour: 20, minute: 0), TimeOfDay(hour: 8, minute: 30), TimeOfDay(hour: 8, minute: 30)]
        XCTAssertEqual(MedSchedule.clockTimes(m).map(\.hour), [8, 20], "sorted, duplicates merged")
        XCTAssertEqual(MedSchedule.doses(m, on: mon, cal: cal).count, 2)
        // Open-ended daily → one repeating alert per time.
        var r = MedSchedule.plans([m], now: mon, cal: cal)
        XCTAssertEqual(r.plans.count, 2); XCTAssertTrue(r.plans.allSatisfy(\.repeats)); XCTAssertEqual(r.dropped, 0)
        // Weekdays: Mon/Wed/Fri only, one repeating alert per time per day.
        m.pattern = .weekdays; m.weekdays = [2, 4, 6]
        XCTAssertTrue(MedSchedule.isDue(m, on: mon, cal: cal))
        XCTAssertFalse(MedSchedule.isDue(m, on: cal.date(byAdding: .day, value: 1, to: mon)!, cal: cal), "not Tuesday")
        XCTAssertEqual(MedSchedule.plans([m], now: mon, cal: cal).plans.count, 6)
        // Every 6 hours from 8 to 22 → 8, 14, 20.
        m.pattern = .everyHours; m.everyHours = 6; m.firstHour = 8; m.lastHour = 22
        XCTAssertEqual(MedSchedule.clockTimes(m).map(\.hour), [8, 14, 20])
        // An end date → dated one-off alerts only up to the last day, none in the past.
        m.pattern = .daily; m.times = [TimeOfDay(hour: 9, minute: 0)]
        m.end = cal.date(byAdding: .day, value: 2, to: mon)
        r = MedSchedule.plans([m], now: mon, cal: cal)
        XCTAssertEqual(r.plans.count, 3, "Mon, Tue, Wed at 9")
        XCTAssertTrue(r.plans.allSatisfy { !$0.repeats && ($0.at ?? mon) > mon })
        // Starting next week → nothing due today.
        m.end = nil; m.start = cal.date(byAdding: .day, value: 7, to: mon)!
        XCTAssertTrue(MedSchedule.doses(m, on: mon, cal: cal).isEmpty)
        // A follow-up in 3 months is its own alert; paused meds schedule nothing.
        m.start = cal.startOfDay(for: mon); m.followUp = cal.date(byAdding: .month, value: 3, to: mon)
        XCTAssertTrue(MedSchedule.plans([m], now: mon, cal: cal).plans.contains { $0.id.hasSuffix("-follow") })
        m.paused = true
        XCTAssertTrue(MedSchedule.plans([m], now: mon, cal: cal).plans.isEmpty)
        // The 64-alert limit: many meds × many times stay within budget, soonest kept.
        var many: [Med] = []
        for i in 0..<10 {
            var x = Med(); x.name = "Med \(i)"; x.start = cal.startOfDay(for: mon)
            x.pattern = .weekdays; x.weekdays = Set(1...7); x.times = [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)]
            many.append(x)
        }
        let big = MedSchedule.plans(many, now: mon, cal: cal)
        XCTAssertEqual(big.plans.count, MedSchedule.budget)
        XCTAssertEqual(big.dropped, 140 - MedSchedule.budget)
        XCTAssertTrue(MedSchedule.summary(many[0]).contains("at"))
    }

    func testExcelWorkbookKeepsNumbersAsNumbers() throws {
        XCTAssertEqual(XLSXWriter.column(0), "A"); XCTAssertEqual(XLSXWriter.column(25), "Z"); XCTAssertEqual(XLSXWriter.column(26), "AA")
        XCTAssertEqual(XLSXWriter.number("$4.50"), "4.50")
        XCTAssertEqual(XLSXWriter.number("1,234.50"), "1234.50")
        XCTAssertNil(XLSXWriter.number("00123"), "IDs and ZIP codes keep their zeros")
        XCTAssertNil(XLSXWriter.number("8%"))
        XCTAssertNil(XLSXWriter.number("12 Main St"))
        let rows = [["Item", "Qty", "Price"], ["Coffee & cake", "2", "$4.50"], ["Bagel <plain>", "1", "1,234.50"]]
        let data = try XCTUnwrap(XLSXWriter.workbook(rows: rows, sheetName: "Receipt"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString.prefix(6)).xlsx")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let names = Set(Given.Zip.names(in: url))
        XCTAssertTrue(names.isSuperset(of: ["[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/_rels/workbook.xml.rels",
                                            "xl/worksheets/sheet1.xml", "xl/styles.xml"]))
        let sheet = try XCTUnwrap(Given.Zip.entryText(in: url, named: "xl/worksheets/sheet1.xml"))
        XCTAssertTrue(sheet.contains("<c r=\"B2\"><v>2</v></c>"), "Qty is a number")
        XCTAssertTrue(sheet.contains("<c r=\"C3\"><v>1234.50</v></c>"), "thousands separator understood")
        XCTAssertTrue(sheet.contains("Coffee &amp; cake") && sheet.contains("Bagel &lt;plain&gt;"), "text escaped")
        XCTAssertTrue(sheet.contains("<c r=\"A1\" t=\"inlineStr\" s=\"1\">"), "bold header")
        XCTAssertTrue(sheet.contains("state=\"frozen\""), "header row frozen")
        let t = DataGrab.tableRows("Name\tQty\tPrice\nTea\t2\nMilk\t1\t0.99")
        XCTAssertEqual(t.rows.count, 3); XCTAssertEqual(t.rows[1].count, 3); XCTAssertEqual(t.ragged, 1)
    }

    func testQRLinkVerdictNamesTheRealOwner() throws {
        let fake = ScamAnalyzer.verdict(for: try XCTUnwrap(URL(string: "https://paypal.secure-login.xyz/login")))
        XCTAssertEqual(fake.owner, "secure-login.xyz"); XCTAssertTrue(fake.risky)
        let disguised = ScamAnalyzer.verdict(for: try XCTUnwrap(URL(string: "https://paypal.com@evil.top/pay")))
        XCTAssertEqual(disguised.owner, "evil.top")
        XCTAssertTrue(disguised.issues.contains { $0.contains("@") }, "\(disguised.issues)")
        let real = ScamAnalyzer.verdict(for: try XCTUnwrap(URL(string: "https://www.apple.com/iphone/")))
        XCTAssertEqual(real.owner, "apple.com"); XCTAssertFalse(real.risky); XCTAssertTrue(real.knownSafe)
        let short = ScamAnalyzer.verdict(for: try XCTUnwrap(URL(string: "https://bit.ly/3abc")))
        XCTAssertTrue(short.risky, "shortened links hide the destination")
    }

    func testReturnWindowIsReadOffTheReceipt() throws {
        XCTAssertEqual(ReceiptScan.guessReturnDays("RETURNS ACCEPTED WITHIN 30 DAYS WITH RECEIPT", purchase: nil), 30)
        XCTAssertEqual(ReceiptScan.guessReturnDays("30-Day Return Policy", purchase: nil), 30)
        XCTAssertEqual(ReceiptScan.guessReturnDays("Refund or exchange within 14 days of purchase", purchase: nil), 14)
        XCTAssertNil(ReceiptScan.guessReturnDays("Store hours 9-5, 7 days a week\nTOTAL 45.99", purchase: nil), "no false hit")
        let bought = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        XCTAssertEqual(ReceiptScan.guessReturnDays("Return by 11/15/2026", purchase: bought), 14, "explicit date counted from purchase")
        var r = Receipt(imageFile: "x.jpg", store: "Shop", purchaseDate: bought, total: "$10", rawText: "")
        XCTAssertNil(r.returnBy)
        r.returnDays = 30
        XCTAssertEqual(r.returnBy, Calendar.current.date(byAdding: .day, value: 30, to: bought))
    }

    func testCollageLayoutsTileTheCanvasExactly() {
        let canvas = CGSize(width: 1080, height: 1350), gap: CGFloat = 16
        for layout in CollageLayout.allCases {
            for n in 1...9 {
                let f = layout.frames(count: n, canvas: canvas, gap: gap)
                XCTAssertEqual(f.count, n, "\(layout.title) gives one frame per photo (\(n))")
                for (i, a) in f.enumerated() {
                    XCTAssertGreaterThanOrEqual(a.minX, gap - 0.5); XCTAssertGreaterThanOrEqual(a.minY, gap - 0.5)
                    XCTAssertLessThanOrEqual(a.maxX, canvas.width - gap + 0.5); XCTAssertLessThanOrEqual(a.maxY, canvas.height - gap + 0.5)
                    XCTAssertGreaterThan(a.width, 20); XCTAssertGreaterThan(a.height, 20)
                    for b in f[(i + 1)...] { XCTAssertFalse(a.insetBy(dx: 0.5, dy: 0.5).intersects(b), "\(layout.title) tiles never overlap") }
                }
            }
        }
        // The hero tile really is the biggest.
        let hero = CollageLayout.hero.frames(count: 4, canvas: canvas, gap: gap)
        XCTAssertTrue(hero.dropFirst().allSatisfy { $0.width * $0.height < hero[0].width * hero[0].height })
        let img = CollageLayout.render([Self.text("A"), Self.text("B"), Self.text("C")], layout: .mosaic,
                                       canvas: CGSize(width: 360, height: 640), gapRatio: 0.02, cornerRatio: 0.03, background: .white)
        XCTAssertEqual(img.size, CGSize(width: 360, height: 640))
    }

    func testFaceEmojiCoversOnlyChosenFacesAndMergesDetections() throws {
        // Two passes seeing the same face become one box (the larger); a separate face stays separate.
        let a = CGRect(x: 0.10, y: 0.10, width: 0.20, height: 0.20)
        let aSmall = CGRect(x: 0.12, y: 0.12, width: 0.15, height: 0.15)
        let b = CGRect(x: 0.60, y: 0.50, width: 0.10, height: 0.10)
        XCTAssertEqual(Scrubber.mergeFaces([aSmall, b, a]), [a, b])
        // A plain picture has no faces (no false hits from the tiles or the mirror).
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 900)).image { c in
            UIColor.systemTeal.setFill(); c.fill(CGRect(x: 0, y: 0, width: 1200, height: 900)) }
        XCTAssertTrue(Scrubber.thoroughFaces(try XCTUnwrap(blank.cgImage)).isEmpty)
        // Only covered faces are drawn: an uncovered one leaves the photo untouched there.
        let one = UIGraphicsImageRendererFormat(); one.scale = 1
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: one).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 400, height: 400)) }
        let out = FaceEmoji.render(photo, covers: [FaceCover(rect: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.3), emoji: "😀"),
                                                   FaceCover(rect: CGRect(x: 0.6, y: 0.6, width: 0.3, height: 0.3), emoji: nil)], scale: 1)
        XCTAssertEqual(out.size, CGSize(width: 400, height: 400))
        func brightness(_ img: UIImage, _ p: CGPoint) -> CGFloat {
            // Average of a 9×9 patch around p, read straight from a bitmap.
            guard let cg = img.cgImage, let patch = cg.cropping(to: CGRect(x: p.x - 4, y: p.y - 4, width: 9, height: 9)) else { return -1 }
            let px = Self.rgba(patch, width: 9, height: 9, in: CGRect(x: 0, y: 0, width: 9, height: 9))
            var sum = 0
            for i in stride(from: 0, to: px.count, by: 4) { sum += Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2]) }
            return CGFloat(sum) / CGFloat(81 * 3 * 255)
        }
        XCTAssertLessThan(brightness(out, CGPoint(x: 100, y: 100)), 0.97, "covered face has the emoji drawn on it")
        XCTAssertGreaterThan(brightness(out, CGPoint(x: 300, y: 300)), 0.99, "the face left showing is untouched")
    }

    func testMenuReaderFindsDishesPricesAndWhatsInThem() {
        let menu = """
        STARTERS
        Garlic Bread ........ 5.50
        toasted sourdough, garlic butter
        Calamari Fritti 8.90
        crispy squid, lemon aioli
        Grilled Salmon
        14.50
        MAINS
        Margherita Pizza (v) €12
        tomato, mozzarella, basil
        Pad Thai with Prawns 15
        rice noodles, peanuts, egg
        POSTRES
        Tarta de queso 6,50 €
        Pollo al ajillo 11
        """.components(separatedBy: "\n")
        let items = MenuReader.parse(menu)
        XCTAssertEqual(items.map(\.name), ["Garlic Bread", "Calamari Fritti", "Grilled Salmon", "Margherita Pizza (v)",
                                            "Pad Thai with Prawns", "Tarta de queso", "Pollo al ajillo"])
        XCTAssertEqual(items.map(\.price), [5.5, 8.9, 14.5, 12, 15, 6.5, 11])
        XCTAssertEqual(items[0].section, "Starters"); XCTAssertEqual(items[3].section, "Mains")
        XCTAssertTrue(items[1].flags.contains(.shellfish), "squid")
        XCTAssertTrue(items[2].flags.contains(.fish))
        XCTAssertTrue(items[3].flags.contains(.vegetarian) && items[3].flags.contains(.dairy) && items[3].flags.contains(.gluten))
        XCTAssertTrue(items[4].flags.isSuperset(of: [.shellfish, .nuts, .egg, .gluten]))
        XCTAssertTrue(items[5].flags.contains(.dairy), "queso is cheese")
        XCTAssertTrue(items[6].flags.contains(.chicken) && items[6].flags.contains(.meat), "pollo is chicken")
        XCTAssertEqual(MenuReader.conflicts(items[4], diets: [.noNuts]), [.nuts])
        XCTAssertTrue(MenuReader.conflicts(items[3], diets: [.vegetarian]).isEmpty, "margherita fits a vegetarian")
        XCTAssertFalse(MenuReader.conflicts(items[3], diets: [.vegan]).isEmpty, "but not a vegan (cheese)")
        XCTAssertFalse(MenuReader.flags("Paneer tikka").contains(.gluten), "'paneer' isn't bread")
        XCTAssertEqual(MenuReader.currency(in: menu), "EUR")
        XCTAssertNil(MenuReader.splitPrice("Since 1998"), "a year isn't a price")
    }

    func testPassportCheckGradesPhotos() throws {
        // No face → one clear failing check, nothing else invented.
        let noFace = PassportCheck.run(original: Self.text("HELLO"), finished: nil)
        XCTAssertEqual(noFace.map(\.id), ["one"]); XCTAssertFalse(noFace[0].pass)
        // Background: a plain white border passes, a busy dark one fails.
        let white = UIGraphicsImageRenderer(size: CGSize(width: 413, height: 531)).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 413, height: 531)) }
        let w = try XCTUnwrap(PassportCheck.borderStats(try XCTUnwrap(white.cgImage)))
        XCTAssertGreaterThan(w.mean, 0.95); XCTAssertLessThan(w.spread, 0.02)
        let busy = UIGraphicsImageRenderer(size: CGSize(width: 413, height: 531)).image { c in
            for i in 0..<20 { (i % 2 == 0 ? UIColor.black : UIColor.darkGray).setFill()
                c.fill(CGRect(x: CGFloat(i) * 21, y: 0, width: 21, height: 531)) } }
        let b = try XCTUnwrap(PassportCheck.borderStats(try XCTUnwrap(busy.cgImage)))
        XCTAssertLessThan(b.mean, 0.72)
        // Lighting: a face box lit on one side only is uneven.
        let px1 = UIGraphicsImageRendererFormat(); px1.scale = 1     // the box is in pixels, so draw 1 point = 1 pixel
        let split = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200), format: px1).image { c in
            UIColor.black.setFill(); c.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
            UIColor.white.setFill(); c.fill(CGRect(x: 100, y: 0, width: 100, height: 200)) }
        let h = try XCTUnwrap(PassportCheck.halves(try XCTUnwrap(split.cgImage), CGRect(x: 0, y: 0, width: 200, height: 200)))
        XCTAssertLessThan(h.0, 0.1); XCTAssertGreaterThan(h.1, 0.9)
    }

    func testCutoutEdgesArePulledInAndFeathered() throws {
        let one = UIGraphicsImageRendererFormat(); one.scale = 1
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 1400, height: 1400), format: one).image { c in
            UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 1400, height: 1400)) }
        // Mask: a white square in the middle (the "subject"), black elsewhere — at a quarter resolution,
        // like Vision's masks, so the scale-up is exercised too.
        let maskImg = UIGraphicsImageRenderer(size: CGSize(width: 350, height: 350), format: one).image { c in
            UIColor.black.setFill(); c.fill(CGRect(x: 0, y: 0, width: 350, height: 350))
            UIColor.white.setFill(); c.fill(CGRect(x: 100, y: 100, width: 150, height: 150)) }
        let out = try XCTUnwrap(ImageStudio.refinedCutout(try XCTUnwrap(photo.cgImage), mask: CIImage(cgImage: try XCTUnwrap(maskImg.cgImage))))
        let cg = try XCTUnwrap(out.cgImage)
        XCTAssertEqual(cg.width, 1400); XCTAssertEqual(cg.height, 1400)
        func alpha(_ x: Int, _ y: Int) -> Int {
            return Int(Self.rgba(cg, width: 1, height: 1, in: CGRect(x: -x, y: -(cg.height - 1 - y), width: cg.width, height: cg.height))[3])
        }
        XCTAssertGreaterThan(alpha(700, 700), 250, "subject solid")
        XCTAssertLessThan(alpha(50, 50), 5, "background fully clear")
        // Right at the original edge (x = 400) the edge has been pulled in and softened: partly see-through.
        XCTAssertLessThan(alpha(400, 700), 200, "edge pulled in — no halo of background")
        XCTAssertGreaterThan(alpha(410, 700), 0, "but a soft blend, not a hard scissor cut")
    }

    func testComicStripInksPanelsAndLaysThemOut() throws {
        // A photo with a hard edge gets real ink lines.
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200)).image { c in
            UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
            UIColor.systemBlue.setFill(); c.fill(CGRect(x: 100, y: 40, width: 120, height: 120)) }
        let inked = try XCTUnwrap(ChainFun.art(photo, style: "comic", long: 300))
        XCTAssertEqual(inked.size, CGSize(width: 300, height: 200))
        XCTAssertEqual(ComicStrip.layout(for: 4), .grid); XCTAssertEqual(ComicStrip.layout(for: 3), .strip)
        let strip = ComicStrip.render(panels: [inked, inked, inked], words: ["Hello!", "", "A much longer line of dialogue that has to wrap"],
                                      title: "Monday", canvas: CGSize(width: 540, height: 675))
        XCTAssertEqual(strip.size, CGSize(width: 540, height: 675))
    }

    func testStickerStudioEveryPresetIsATrimmedSeeThroughSticker() throws {
        // A cut-out: a red disc on clear, with empty margin around it (the studio trims that away).
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        let cut = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: fmt).image { _ in
            UIColor.red.setFill(); UIBezierPath(ovalIn: CGRect(x: 80, y: 80, width: 240, height: 240)).fill() }
        func alpha(_ img: UIImage, _ x: Int, _ y: Int) -> Int {
            guard let cg = img.cgImage else { return -1 }
            return Int(Self.rgba(cg, width: 1, height: 1, in: CGRect(x: -x, y: -(cg.height - 1 - y), width: cg.width, height: cg.height))[3])
        }
        XCTAssertEqual(StickerStudio.presets.count, 10)
        XCTAssertEqual(Set(StickerStudio.presets.map(\.id)).count, 10, "unique preset ids")
        for p in StickerStudio.presets {
            let st = try XCTUnwrap(StickerStudio.render(cut, style: p.style, side: 240), p.id)
            let cg = try XCTUnwrap(st.cgImage, p.id)
            XCTAssertGreaterThan(cg.width, 240, "\(p.id): the edge/backdrop adds room around the subject")
            XCTAssertLessThan(cg.width, 600, "\(p.id): trimmed, no wasted canvas")
            let corners = [alpha(st, 0, 0), alpha(st, cg.width - 1, 0), alpha(st, 0, cg.height - 1), alpha(st, cg.width - 1, cg.height - 1)]
            XCTAssertLessThan(corners.min() ?? 255, 40, "\(p.id): shaped, not a box — corners see-through")
            XCTAssertGreaterThan(alpha(st, cg.width / 2, cg.height / 2), 250, "\(p.id): subject is solid")
        }
        // The look really changes the art; a caption adds a line below.
        var plain = StickerStudio.Style(); plain.shadow = false
        var worded = plain; worded.caption = "Yay"
        let a = try XCTUnwrap(StickerStudio.render(cut, style: plain, side: 240))
        let b = try XCTUnwrap(StickerStudio.render(cut, style: worded, side: 240))
        XCTAssertGreaterThan(b.size.height, a.size.height + 5, "the caption sits over the bottom edge and adds a line below it")
        // Empty cut-out → nil, never a blank sticker.
        let empty = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50), format: fmt).image { _ in }
        XCTAssertNil(StickerStudio.render(empty, style: plain, side: 100))
        // Printable sheet: a short pack fills one page; 13 stickers run onto a second.
        let one = try XCTUnwrap(PDFDocument(data: try XCTUnwrap(StickerStudio.sheetPDF([a]))))
        XCTAssertEqual(one.pageCount, 1)
        XCTAssertTrue((one.string ?? "").contains("sticker paper"))
        let many = try XCTUnwrap(PDFDocument(data: try XCTUnwrap(StickerStudio.sheetPDF(Array(repeating: a, count: 13)))))
        XCTAssertEqual(many.pageCount, 2)
        XCTAssertNil(StickerStudio.sheetPDF([]))
    }

    @MainActor func testUntanglePlanBecomesAPictureToShare() throws {
        let p = UntanglePlan.make(from: "Shower, groceries: milk, eggs, bread, call mum, office work", start: Date())
        let img = try XCTUnwrap(UntanglePlanCard.image(p), "the plan renders as a picture")
        XCTAssertEqual(img.size.width, 390, accuracy: 1)
        XCTAssertGreaterThan(img.size.height, 300, "the timeline is on the card")
        XCTAssertEqual(UntanglePlanCard.duration(45), "45 min"); XCTAssertEqual(UntanglePlanCard.duration(120), "2 h"); XCTAssertEqual(UntanglePlanCard.duration(95), "1 h 35 min")
    }

    func testUntanglePlansAroundHowYouFeel() throws {
        let cal = Calendar(identifier: .gregorian)
        let nine = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 9)))
        // The real dump from a user: the feeling shapes the plan but is not a step.
        let p = UntanglePlan.make(from: "Shower, groceries, office work, not feeling well,", start: nine)
        XCTAssertTrue(p.situation.unwell); XCTAssertEqual(p.energy, .low)
        let real = p.steps.filter { !$0.isRest }
        XCTAssertFalse(real.contains { $0.title.lowercased().contains("feeling") }, "a feeling isn't a task")
        XCTAssertEqual(real.map(\.kind), [.getUp, .care, .hygiene, .groceries, .work], "gentle start, care first, trip out before work")
        XCTAssertTrue(p.steps.contains { $0.isRest }, "low energy gets rests built in")
        let g = try XCTUnwrap(real.first { $0.kind == .groceries })
        XCTAssertEqual(g.tripMinutes, 30, "travel counted, there and back")
        XCTAssertTrue(g.items.contains { $0.contains("pharmacy") }, "unwell → pick up medicine on the same trip")
        XCTAssertNotNil(p.careNote); XCTAssertFalse(p.encouragement.isEmpty)
        // Times chain with no gaps; total and finish line agree.
        for (a, b) in zip(p.steps, p.steps.dropFirst()) { XCTAssertEqual(a.end, b.start) }
        XCTAssertEqual(p.finishAt, nine.addingTimeInterval(TimeInterval(p.totalMinutes * 60)))
        XCTAssertTrue(p.steps.allSatisfy { !$0.why.isEmpty && !$0.feel.isEmpty }, "every step says why and how it'll feel")

        // Keeping up: done early pulls everything in; more time pushes it out; skip drops it.
        var q = p
        let first = q.steps[0].id
        UntanglePlan.markDone(&q, first, now: nine)
        XCTAssertEqual(q.steps[1].start, nine)
        let before = q.finishAt
        UntanglePlan.extend(&q, q.steps[1].id, by: 10, now: nine)
        XCTAssertEqual(q.finishAt, before.addingTimeInterval(600))
        let work = try XCTUnwrap(q.steps.first { $0.kind == .work })
        UntanglePlan.skip(&q, work.id, now: nine)
        XCTAssertLessThan(q.finishAt, before)
        XCTAssertGreaterThan(q.progress, 0)

        // Detail levels, a normal-energy day, lists that stay together, and no false alarms.
        let quick = UntanglePlan.make(from: "groceries: milk, eggs, bread\nclean the kitchen", detail: .quick, start: nine)
        XCTAssertEqual(quick.energy, .normal)
        XCTAssertFalse(quick.steps.contains { $0.kind == .getUp || $0.isRest || $0.kind == .care })
        XCTAssertEqual(quick.steps.first { $0.kind == .groceries }?.items, ["milk", "eggs", "bread"])
        XCTAssertTrue(quick.steps.allSatisfy { $0.substeps.isEmpty })
        XCTAssertGreaterThan(UntanglePlan.make(from: "clean the kitchen", detail: .detailed, start: nine).steps[0].substeps.count, 1)
        XCTAssertFalse(UntanglePlan.situation(of: "follow up with Sam, buy a pillow").unwell)
        XCTAssertFalse(UntanglePlan.situation(of: "follow up with Sam").lowEnergy)
        XCTAssertTrue(UntanglePlan.make(from: "can't get out of bed, laundry", start: nine).steps.first?.kind == .getUp)
        XCTAssertEqual(UntanglePlan.kind(of: "great report"), .work, "'eat' inside 'great' isn't food")
        XCTAssertTrue(UntanglePlan.text(p).contains("done by"))
    }

    func testWeatherWearSaysWhatToWear() {
        var s = WeatherWear.Snapshot(tempC: 5, feelsC: 3, highC: 8, lowC: 1, rainChance: 0.7, windKph: 10, uv: 1, condition: "Rain", symbol: "cloud.rain")
        var a = WeatherWear.advice(s)
        XCTAssertTrue(a[0].hasPrefix("Cold")); XCTAssertTrue(a.contains { $0.contains("umbrella") && $0.contains("70%") })
        s.feelsC = 15; s.rainChance = 0.1; s.uv = 8; s.highC = 26; s.lowC = 12
        a = WeatherWear.advice(s)
        XCTAssertTrue(a[0].hasPrefix("Mild")); XCTAssertFalse(a.contains { $0.contains("umbrella") })
        XCTAssertTrue(a.contains { $0.contains("sunscreen") }); XCTAssertTrue(a.contains { $0.contains("layers") })
        XCTAssertFalse(WeatherWear.advice(s, goingOut: false).contains { $0.contains("sunscreen") })
        XCTAssertTrue(WeatherWear.advice(s, unwell: true)[0].hasPrefix("Cool"), "unwell feels 3° colder")
        let now = Date()
        let hours = (0..<8).map { (now.addingTimeInterval(Double($0) * 3600), $0 < 3 ? 0.8 : 0.1) }
        XCTAssertEqual(WeatherWear.bestTripHour(hours, now: now), hours[3].0)
        XCTAssertNil(WeatherWear.bestTripHour(hours.map { ($0.0, 0.9) }, now: now))
    }

    func testDescribeItBuildsWhatWasAskedOrSaysWhatsMissing() throws {
        // The real request: reminders for the day must never become a photo/receipt tool.
        let ask = "I want to organize my day better with reminders for things I need to do"
        let g = try XCTUnwrap(ChainPlanner.guess(ask))
        XCTAssertEqual(g.chain.steps.first?.block, .actionItems, "a to-do list, from what you type")
        XCTAssertEqual(g.chain.steps.first?.block.takes, .text, "no photo was mentioned")
        XCTAssertFalse(PlanCheck.startConflict(ask, g.chain))
        XCTAssertEqual(Set(PlanCheck.needs(ask)), [.tasks, .reminders])
        XCTAssertTrue(PlanCheck.missing(ask, g.chain).isEmpty)
        XCTAssertEqual(PlanCheck.builtIn(ask)?.id, "untangle", "the full tool is offered first")

        // The plan the model once made for it is recognised as wrong and scored below the right one.
        let wrong = Chain(id: "w", name: "Reminder Organizer", steps: [ChainStep(block: .readText), ChainStep(block: .summarize), ChainStep(block: .makeTable)])
        XCTAssertTrue(PlanCheck.startConflict(ask, wrong))
        XCTAssertLessThan(PlanCheck.score(ask, wrong), PlanCheck.score(ask, g.chain))
        XCTAssertEqual(Set(PlanCheck.report(ask, wrong).gaps), ["a to-do list", "reminders"])

        // Things a custom tool can't do are said out loud, not dropped.
        let w = "summarize my notes and tell me the weather"
        let wc = try XCTUnwrap(ChainPlanner.guess(w)).chain
        XCTAssertEqual(PlanCheck.report(w, wc).good, ["a summary"])
        XCTAssertEqual(PlanCheck.report(w, wc).gaps, ["weather"])

        // Photo requests still start from a photo; meds go to Med Reminders; no false matches.
        let r = "turn my receipt photo into an expense row"
        XCTAssertFalse(PlanCheck.startConflict(r, try XCTUnwrap(ChainPlanner.guess(r)).chain))
        XCTAssertEqual(PlanCheck.builtIn("remind me to take my meds at 8")?.id, "medreminder")
        XCTAssertNil(PlanCheck.builtIn("shrink a photo under 2 mb"))
        XCTAssertFalse(PlanCheck.needs("a brainstorm about trains").contains(.weather), "'rain' inside 'brain'/'trains' isn't weather")
    }

    func testCameraReadsTheSceneAndCoaches() {
        typealias S = SceneSense
        var s = S.Signals(); s.labels = ["sunset_sunrise": 0.8, "sky": 0.7]; s.hour = 18; s.warmth = 0.2; s.meanLuma = 0.4
        XCTAssertEqual(S.scene(s), .sunset)
        s.tilt = 5; XCTAssertEqual(S.coach(s, scene: .sunset), "Tilt left a little — the horizon is crooked.")
        s.tilt = 0; s.highlights = 0.3; XCTAssertTrue(S.coach(s, scene: .sunset)!.contains("darkened"))
        // Warm light at golden hour over the sea reads as a sunset even without the label.
        var g = S.Signals(); g.labels = ["sea": 0.5]; g.hour = 19; g.warmth = 0.18; g.meanLuma = 0.35
        XCTAssertEqual(S.scene(g), .sunset)
        g.hour = 13; XCTAssertNotEqual(S.scene(g), .sunset, "not at midday")
        var p = S.Signals(); p.faces = 1; p.faceArea = 0.08; p.faceCenter = CGPoint(x: 0.5, y: 0.4)
        XCTAssertEqual(S.scene(p), .portrait)
        p.faceArea = 0.5; XCTAssertTrue(S.coach(p, scene: .portrait)!.contains("Step back"))
        p.faces = 3; XCTAssertEqual(S.scene(p), .group)
        var n = S.Signals(); n.meanLuma = 0.05; n.iso = 3200; n.shutter = 1.0 / 4; n.hour = 23; n.labels = ["sky": 0.4]
        XCTAssertEqual(S.scene(n), .stars)
        n.shake = 1.2; XCTAssertTrue(S.coach(n, scene: .stars)!.hasPrefix("Hold still"))
        n.labels = [:]; n.hour = 14; n.iso = 1200; n.meanLuma = 0.12; XCTAssertEqual(S.scene(n), .night)
        var d = S.Signals(); d.labels = ["document": 0.7]; XCTAssertEqual(S.scene(d), .document)
        var f = S.Signals(); f.labels = ["food": 0.6]; XCTAssertEqual(S.scene(f), .food)
        var m = S.Signals(); m.motion = 0.2; XCTAssertEqual(S.scene(m), .action)
        XCTAssertEqual(S.scene(S.Signals()), .everyday); XCTAssertNil(S.coach(S.Signals(), scene: .everyday))
        // Tones, motion and tilt helpers.
        let white = [UInt8](repeating: 255, count: 4 * 4 * 4)
        XCTAssertEqual(S.tones(white, w: 4, h: 4).mean, 1, accuracy: 0.01)
        XCTAssertEqual(S.tones(white, w: 4, h: 4).highlights, 1, accuracy: 0.01)
        XCTAssertEqual(S.motion([0, 0], [255, 255]), 1, accuracy: 0.001)
        XCTAssertEqual(S.tilt(gravityX: 0, gravityY: -1), 0, accuracy: 0.01)
        XCTAssertGreaterThan(S.tilt(gravityX: 0.1, gravityY: -0.99), 4)
        // Every scene has a button, a reason and looks that start with "As shot"; every look renders.
        let img = CIImage(color: CIColor(red: 0.8, green: 0.5, blue: 0.3)).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        for sc in S.Scene.allCases {
            XCTAssertFalse(sc.button.isEmpty); XCTAssertFalse(sc.why.isEmpty); XCTAssertEqual(sc.looks.first, .natural)
        }
        for l in S.Look.allCases { XCTAssertEqual(S.apply(l, to: img).extent, img.extent, l.rawValue) }
    }

    func testMyDayDiaryLogsLocksAndRemembers() throws {
        var cal = Calendar(identifier: .gregorian); cal.firstWeekday = 1; cal.timeZone = TimeZone(identifier: "UTC")!
        // November 2026 starts on a Sunday: 30 days → 5 weeks, first cell is the 1st.
        let nov = DayDiary.monthGrid(year: 2026, month: 11, cal: cal)
        XCTAssertEqual(nov.count, 5); XCTAssertEqual(nov[0][0], 1); XCTAssertTrue(nov.allSatisfy { $0.count == 7 })
        XCTAssertEqual(nov.flatMap { $0 }.compactMap { $0 }.count, 30)
        // Streak counts back from today (or yesterday if today isn't logged yet).
        let today = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 21)))
        let keys: Set<String> = ["2026-11-15", "2026-11-16", "2026-11-17"]
        XCTAssertEqual(DayDiary.streak(keys, today: today, cal: cal), 3)
        XCTAssertEqual(DayDiary.streak(keys.union(["2026-11-18"]), today: today, cal: cal), 4)
        XCTAssertEqual(DayDiary.streak(["2026-11-10"], today: today, cal: cal), 0)
        // PIN rules and hashing: same secret + salt → same hash; capitals/spaces in answers don't matter.
        XCTAssertNotNil(DayDiary.pinProblem("12")); XCTAssertNotNil(DayDiary.pinProblem("1111")); XCTAssertNotNil(DayDiary.pinProblem("1234"))
        XCTAssertNotNil(DayDiary.pinProblem("98a7")); XCTAssertNil(DayDiary.pinProblem("2580"))
        let salt = Data(repeating: 7, count: 16)
        XCTAssertEqual(DayDiary.hash(" Elm Street ", salt: salt), DayDiary.hash("elm street", salt: salt))
        XCTAssertNotEqual(DayDiary.hash("2580", salt: salt), DayDiary.hash("2581", salt: salt))
        XCTAssertEqual(DayDiary.hash("x", salt: salt).count, 32)
        // The store: one tap saves today's mood (latest wins), notes add up, files are encrypted on disk.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("diary-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = DiaryStore(folder: dir)
        let day = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 21)))
        store.log(.bad, at: day)
        let saved = try XCTUnwrap(store.log(.good, at: day, note: DayDiary.Note(at: day, mood: .good, transcript: "Lunch with Sam")))
        XCTAssertEqual(saved.mood, .good); XCTAssertEqual(saved.notes.count, 1)
        let k = DayDiary.key(day)
        XCTAssertEqual(store.day(k)?.notes.first?.transcript, "Lunch with Sam")
        XCTAssertTrue(store.allKeys().contains(k))
        let c = Calendar.current.dateComponents([.year, .month], from: day)
        XCTAssertEqual(store.days(inMonthOf: c.year!, c.month!).count, 1)
        let raw = try Data(contentsOf: dir.appendingPathComponent(k + ".day"))
        XCTAssertNil(String(data: raw, encoding: .utf8)?.range(of: "Lunch with Sam"), "never stored as plain text")
        XCTAssertEqual(DayDiary.tally([saved]).good, 1)
        XCTAssertTrue(DayDiary.message(for: .good).contains("tomorrow")); XCTAssertTrue(DayDiary.message(for: .bad).contains("tomorrow"))
    }

    func testSmartAlertsFireOnlyWhenTrueAndOnceADay() {
        typealias A = SmartAlerts
        let now = Date()
        var shots = A.Rule(kind: .screenshots, limit: 100)
        XCTAssertFalse(A.shouldFire(shots, value: 100, now: now), "at the limit isn't past it")
        XCTAssertTrue(A.shouldFire(shots, value: 152, now: now))
        shots.lastFired = now.addingTimeInterval(-3600)
        XCTAssertFalse(A.shouldFire(shots, value: 152, now: now), "never twice in a day")
        shots.lastFired = now.addingTimeInterval(-21 * 3600)
        XCTAssertTrue(A.shouldFire(shots, value: 152, now: now))
        shots.on = false; XCTAssertFalse(A.shouldFire(shots, value: 999, now: now), "off means off")
        let space = A.Rule(kind: .lowSpace, limit: 5)
        XCTAssertTrue(A.shouldFire(space, value: 3.2, now: now)); XCTAssertFalse(A.shouldFire(space, value: 12, now: now), "free space fires below")
        // The words carry the person's own numbers.
        let m = A.message(.screenshots, value: 152, limit: 100)
        XCTAssertEqual(m.title, "You have 152 screenshots"); XCTAssertTrue(m.body.contains("newest 100"))
        XCTAssertTrue(A.message(.lowSpace, value: 3.24, limit: 5).title.contains("3.2 GB"))
        // Saving from the card keeps what the checks recorded, but a new limit re-arms the alert.
        let key = "smartalerts.rules"; let saved = UserDefaults.standard.data(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }
        AlertStore.save([A.Rule(kind: .screenshots, limit: 100, lastFired: now, lastChecked: now, lastValue: 140)])
        AlertStore.upsert(A.Rule(kind: .screenshots, limit: 100))
        XCTAssertEqual(AlertStore.rule(.screenshots)?.lastFired, now)
        AlertStore.upsert(A.Rule(kind: .screenshots, limit: 150))
        XCTAssertNil(AlertStore.rule(.screenshots)?.lastFired)
        XCTAssertEqual(AlertStore.rule(.screenshots)?.lastValue, 140)
        // Free space is always readable (no permission needed) and positive.
        XCTAssertGreaterThan(A.read(.lowSpace) ?? 0, 0)
    }

    func testMedicinePillCountWarnsOnceAtTheRefillPoint() throws {
        var m = Med(); m.name = "Vitamin D"; m.times = [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)]
        XCTAssertNil(MedSchedule.daysLeft(m), "not counting until asked")
        m.supply = 9; m.perDose = 1; m.refillAt = 7
        XCTAssertEqual(MedSchedule.daysLeft(m), 4, "two a day, nine left")
        let a = MedSchedule.counted(m, taken: true)
        XCTAssertEqual(a.supply, 8); XCTAssertFalse(MedSchedule.crossedRefill(from: m, to: a))
        let b = MedSchedule.counted(a, taken: true)
        XCTAssertEqual(b.supply, 7); XCTAssertTrue(MedSchedule.crossedRefill(from: a, to: b), "fires on reaching the number")
        let c = MedSchedule.counted(b, taken: true)
        XCTAssertFalse(MedSchedule.crossedRefill(from: b, to: c), "and only once")
        XCTAssertEqual(MedSchedule.counted(c, taken: false).supply, 7, "undo puts the dose back")
        var z = m; z.supply = 1; z.perDose = 2
        XCTAssertEqual(MedSchedule.counted(z, taken: true).supply, 0, "never below zero")
        XCTAssertTrue(MedSchedule.refillMessage(b).body.hasPrefix("7 left."))
        XCTAssertFalse(MedSchedule.refillMessage(b).body.lowercased().contains("take"), "no dosing advice")
        // A medicine saved before counting existed still loads.
        let old = #"{"id":"6B0A5D6E-3F3C-4C59-9E7B-3D2C1B0A9F8E","name":"Old","dose":"","note":"","pattern":"daily","times":[{"hour":8,"minute":0}],"weekdays":[2],"everyHours":8,"firstHour":8,"lastHour":22,"start":0,"followUpNote":"x","paused":false}"#
        XCTAssertNoThrow(try JSONDecoder().decode(Med.self, from: Data(old.utf8)))
    }

    func testWarrantyNudgeComesWhenYouChose() throws {
        let cal = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 12)))
        let end = try XCTUnwrap(cal.date(from: DateComponents(year: 2027, month: 1, day: 31)))
        let a = try XCTUnwrap(WarrantyReminders.fireDate(end: end, lead: 30, now: now, cal: cal))
        XCTAssertEqual(cal.dateComponents([.month, .day, .hour], from: a), DateComponents(month: 1, day: 1, hour: 10))
        let soon = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 25)))
        XCTAssertNil(WarrantyReminders.fireDate(end: soon, lead: 14, now: now, cal: cal), "never an alert in the past")
        XCTAssertNotNil(WarrantyReminders.fireDate(end: soon, lead: 3, now: now, cal: cal))
    }

    func testSortedFindsWaysToActAndRemindsBeforeTheDate() throws {
        let bill = "City Water Utility\nAccount 55-2910\nQuestions? Call (555) 201-3344 or email billing@citywater.gov\nPay online at https://pay.citywater.gov/bill\nAmount due: $84.20\nPayment due by December 15, 2026"
        let a = SortedLetters.actions(in: bill)
        XCTAssertEqual(a.reference, "55-2910")
        XCTAssertEqual(a.emails, ["billing@citywater.gov"])
        XCTAssertEqual(a.links.first?.host(), "pay.citywater.gov")
        XCTAssertTrue(a.phones.contains { $0.filter(\.isNumber) == "5552013344" }, "\(a.phones)")
        XCTAssertNil(SortedLetters.reference(in: "Account Holder: Jane Smith"), "a word is not an account number")

        let cal = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 12)))
        let due = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 12, day: 15)))
        var i = SortedLetters.Item(kind: "Bill", title: "Water bill", amount: "$84.20", due: due, summary: "", remindDays: 3)
        let at = try XCTUnwrap(SortedLetters.remindAt(i, now: now, cal: cal))
        XCTAssertEqual(cal.dateComponents([.day, .hour], from: at), DateComponents(day: 12, hour: 9))
        XCTAssertEqual(SortedLetters.message(i, now: at, cal: cal).title, "Water bill — due in 3 days")
        i.done = true; XCTAssertNil(SortedLetters.remindAt(i, now: now, cal: cal), "done means no reminder")
        i.done = false; i.remindDays = nil; XCTAssertNil(SortedLetters.remindAt(i, now: now, cal: cal))
        i.remindDays = 30; XCTAssertNil(SortedLetters.remindAt(i, now: now, cal: cal), "never a reminder in the past")

        let late = SortedLetters.Item(kind: "Bill", title: "A", due: due, summary: "")
        let undated = SortedLetters.Item(kind: "Notice", title: "B", summary: "")
        var paid = SortedLetters.Item(kind: "Bill", title: "C", due: now, summary: ""); paid.done = true
        let soon = SortedLetters.Item(kind: "Bill", title: "D", due: now, summary: "")
        XCTAssertEqual(SortedLetters.ordered([paid, undated, late, soon]).map(\.title), ["D", "A", "B", "C"])
    }

    func testLongScreenshotFindsTheLatestScrollAndCutsPages() {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let run = [t0, t0 - 20, t0 - 45, t0 - 70, t0 - 3600, t0 - 3620]   // newest first: 4 in a row, then an old pair
        XCTAssertEqual(StitchExtras.burstCount(run), 4)
        XCTAssertEqual(StitchExtras.burstCount(run, limit: 3), 3)
        XCTAssertEqual(StitchExtras.burstCount([]), 0)
        XCTAssertEqual(StitchExtras.burstCount([t0, t0 - 600]), 1, "an old screenshot isn't part of this scroll")
        let cuts = StitchExtras.pageSlices(height: 5000, pageHeight: 1600)
        XCTAssertEqual(cuts.map(\.height), [1600, 1600, 1600, 200])
        XCTAssertEqual(cuts.last?.maxY, 5000)
        XCTAssertTrue(StitchExtras.pageSlices(height: 0, pageHeight: 100).isEmpty)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let tall = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 400), format: fmt).image { c in UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 100, height: 400)) }
        let pdf = StitchExtras.pdf(tall)
        XCTAssertNotNil(pdf); XCTAssertEqual(pdf.flatMap { PDFDocument(data: $0) }?.pageCount, 3)
    }

    func testArrivalAlertShowsMyListAtTheStore() {
        let m = ArrivalAlert.message(place: "Jewel-Osco", task: "Groceries", items: ["milk", " eggs ", "", "bread"])
        XCTAssertEqual(m.title, "You're at Jewel-Osco")
        XCTAssertEqual(m.body, "Your list: milk, eggs, bread.")
        let long = ArrivalAlert.message(place: "Aldi", task: "Groceries", items: (1...11).map { "item \($0)" })
        XCTAssertTrue(long.body.hasSuffix("item 8 and 3 more."))
        XCTAssertEqual(ArrivalAlert.message(place: "CVS", task: "Pick up prescription", items: []).body, "Time for: Pick up prescription.")
        let step = UUID()
        XCTAssertEqual(ArrivalAlert.id("Jewel-Osco", step: step), ArrivalAlert.id("Jewel-Osco", step: step), "same place, same alert — never doubled")
        XCTAssertNotEqual(ArrivalAlert.id("Jewel-Osco", step: step), ArrivalAlert.id("Aldi", step: step))
    }

    func testRingtoneStartsOnTheBestPartAndReadsTheSong() async throws {
        // A quiet intro, a loud chorus at 60–90 s, quiet again: the tone starts on the chorus.
        let lv: [Float] = (0..<120).map { i in (60..<90).contains(i) ? 1.0 : 0.2 }   // one value per second
        XCTAssertEqual(RingtoneSmart.bestStart(lv, total: 120, length: 30), 60, accuracy: 1.01)
        XCTAssertEqual(RingtoneSmart.bestStart(lv, total: 20, length: 30), 0, "a clip shorter than the tone starts at 0")
        XCTAssertEqual(RingtoneSmart.bestStart([], total: 100, length: 30), 0)
        let flat = [Float](repeating: 0.5, count: 50)
        XCTAssertEqual(RingtoneSmart.bestStart(flat, total: 50, length: 10), 0, "no clear peak → the start, never a random spot")
        XCTAssertLessThanOrEqual(RingtoneSmart.bestStart(lv, total: 120, length: 30) + 30, 120.0001)
        let src = try makeToneFile(seconds: 2.0)
        defer { try? FileManager.default.removeItem(at: src) }
        let read = await RingtoneSmart.levels(src, buckets: 40)
        let levels = try XCTUnwrap(read)
        XCTAssertEqual(levels.count, 40); XCTAssertEqual(levels.max() ?? 0, 1, accuracy: 0.001)
        if case .success(let u) = await AudioConvert.ringtone(src, start: 0, length: 1.5, fade: 0.5) {
            let d = (try? await AVURLAsset(url: u).load(.duration))?.seconds ?? 0
            XCTAssertEqual(d, 1.5, accuracy: 0.2, "the faded tone is the length chosen")
        } else { XCTFail("ringtone with a fade should export") }
    }

    func testZipPhotosGetSmallerAndLoseTheirLocation() throws {
        XCTAssertTrue(ZipPrep.isPhoto("IMG_0042.HEIC")); XCTAssertTrue(ZipPrep.isPhoto("a.jpg"))
        XCTAssertFalse(ZipPrep.isPhoto("party.gif"), "a GIF keeps its animation")
        XCTAssertFalse(ZipPrep.isPhoto("notes.pdf"))
        XCTAssertEqual(ZipPrep.jpegName("IMG_0042.HEIC"), "IMG_0042.jpg")
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let big = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 3000), format: fmt).image { c in
            UIColor.systemTeal.setFill(); c.fill(CGRect(x: 0, y: 0, width: 4000, height: 3000))
            UIColor.orange.setFill(); c.fill(CGRect(x: 500, y: 500, width: 1500, height: 900))
        }
        // A photo carrying a GPS location, like one from the camera.
        let withGPS = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(withGPS, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, try XCTUnwrap(big.cgImage), [kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 41.7, kCGImagePropertyGPSLongitude: 88.2]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        let small = try XCTUnwrap(ZipPrep.prepared(withGPS as Data, shrink: true))
        let src = try XCTUnwrap(CGImageSourceCreateWithData(small as CFData, nil))
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] ?? [:]
        XCTAssertNil(props[kCGImagePropertyGPSDictionary], "no location left in the zipped photo")
        XCTAssertLessThanOrEqual(max(props[kCGImagePropertyPixelWidth] as? Int ?? 0, props[kCGImagePropertyPixelHeight] as? Int ?? 0), 2560)
        XCTAssertNil(ZipPrep.emailNote(bytes: 10_000_000)); XCTAssertNotNil(ZipPrep.emailNote(bytes: 30_000_000))
    }

    func testStyledQRCodesStillScan() throws {
        let url = "https://tenzy.app/menu?table=12"
        let grid = try XCTUnwrap(QRStyle.matrix(url, correction: "M"))
        XCTAssertEqual(grid.count, grid.first?.count, "a square grid")
        XCTAssertTrue(QRStyle.inEye(1, 1, n: grid.count, margin: 1) && QRStyle.inEye(grid.count - 2, 1, n: grid.count, margin: 1))
        XCTAssertFalse(QRStyle.inEye(grid.count / 2, grid.count / 2, n: grid.count, margin: 1))
        XCTAssertNil(QRStyle.matrix("   ", correction: "M"))
        // Each look: what it renders reads back as exactly the link (or it falls back to plain, which does).
        let looks = [QRStyle.Look(ink: 0x5B2BB5, dots: true), QRStyle.Look(ink: 0x0B7A75, center: "☕️"),
                     QRStyle.Look(ink: 0x1B2A6B, dots: true, center: "🍕", caption: "Scan for our menu")]
        for l in looks {
            let r = try XCTUnwrap(QRStyle.safeRender(url, look: l))
            // The simulator's code reader isn't dependable: a wrong read fails, a missed one doesn't.
            if let read = QRStyle.reads(r.image) { XCTAssertEqual(read, url, "\(l) must scan") }
        }
        let captioned = try XCTUnwrap(QRStyle.render(url, look: QRStyle.Look(caption: "Hi")))
        XCTAssertGreaterThan(captioned.size.height, captioned.size.width, "room for the caption")
    }

    func testContactsProSearchesFiltersExportsAndPlans() throws {
        typealias P = ContactBook.Person
        let doc = P(id: "1", given: "Priya", family: "Shah", company: "Lakeview Clinic", title: "Doctor",
                    phones: [.init(label: "Work", value: "(630) 555-0142")], emails: [.init(label: "Work", value: "priya@lakeview.org")],
                    addresses: [.init(label: "Work", value: "12 Main St\nNaperville IL")],
                    birthday: DateComponents(year: 1980, month: 3, day: 14), hasPhoto: true, account: "iCloud")
        let mom = P(id: "2", given: "Asha", family: "Shah", phones: [.init(label: "Mobile", value: "+1 630 555 0199")],
                    socials: [.init(label: "Facebook", value: "asha.shah")], birthday: DateComponents(month: 11, day: 20), account: "Gmail")
        let plumber = P(id: "3", company: "Joe's Plumbing", emails: [.init(label: "Home", value: "joe@pipes.com")], account: "iCloud")
        let all = [plumber, mom, doc]
        // Search: any part of a name, company, email, or the digits of a number.
        XCTAssertEqual(all.filter { ContactBook.matches($0, query: "lakeview") }.map(\.id), ["1"])
        XCTAssertEqual(all.filter { ContactBook.matches($0, query: "555-0199") }.map(\.id), ["2"])
        XCTAssertEqual(all.filter { ContactBook.matches($0, query: "shah") }.count, 2)
        XCTAssertEqual(plumber.name, "Joe's Plumbing", "no name → the company")
        // Filters, together.
        let tags: [String: Set<ContactBook.Tag>] = ["1": [.important, .emergency]]
        func ids(_ f: Set<ContactBook.Filter>) -> [String] { ContactBook.filtered(all, query: "", filters: f, group: nil, account: nil, tags: tags).map(\.id) }
        XCTAssertEqual(ids([.noPhone]), ["3"])
        XCTAssertEqual(ids([.noEmail]), ["2"])
        XCTAssertEqual(ids([.work]), ["3", "1"], "a company or a work number/email counts as work (A–Z: Joe's, then Shah)")
        XCTAssertEqual(ids([.social]), ["2"]); XCTAssertEqual(ids([.mobile]), ["2"])
        XCTAssertEqual(ids([.emergency]), ["1"]); XCTAssertEqual(ids([.birthday, .noPhoto]), ["2"])
        XCTAssertEqual(ContactBook.filtered(all, query: "", filters: [], group: nil, account: "Gmail", tags: [:]).map(\.id), ["2"])
        // Spreadsheet: header, one row each, commas and quotes kept safe.
        let csv = ContactBook.csv([doc, plumber], tags: tags)
        let lines = csv.split(separator: "\r\n").map(String.init)
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[0].hasPrefix("Name,First name,Last name,Company"))
        XCTAssertTrue(lines[1].contains("(630) 555-0142") && lines[1].contains("1980-03-14") && lines[1].contains("Emergency; Important"))
        XCTAssertTrue(lines[1].contains("\"12 Main St, Naperville IL\""), "an address with a comma is quoted")
        XCTAssertTrue(lines[2].contains("Joe's Plumbing"))
        // Birthdays: the next one, Feb 29, and the message.
        let cal = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 10)))
        XCTAssertEqual(ContactBook.nextBirthday(DateComponents(month: 11, day: 20), after: now, cal: cal).map { cal.component(.year, from: $0) }, 2026)
        XCTAssertEqual(ContactBook.nextBirthday(DateComponents(month: 3, day: 14), after: now, cal: cal).map { cal.component(.year, from: $0) }, 2027)
        XCTAssertEqual(ContactBook.nextBirthday(DateComponents(month: 2, day: 29), after: now, cal: cal).map { cal.component(.year, from: $0) }, 2028)
        XCTAssertEqual(ContactBook.upcoming(all, now: now, cal: cal).map { $0.person.id }, ["2", "1"])
        let m = ContactBook.birthdayMessage(doc, on: try XCTUnwrap(cal.date(from: DateComponents(year: 2027, month: 3, day: 14))), cal: cal)
        XCTAssertEqual(m.title, "Priya Shah's birthday is tomorrow — turning 47"); XCTAssertTrue(m.body.contains("(630) 555-0142"))
        // Plans: leave-by time, and alerts that carry the number and address.
        let eight = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 8)))
        XCTAssertEqual(ContactBook.leaveBy(start: eight, travelMinutes: 25), eight.addingTimeInterval(-35 * 60))
        XCTAssertNil(ContactBook.leaveBy(start: eight, travelMinutes: nil))
        let call = ContactBook.planMessage(doc, kind: .call, start: eight, travelMinutes: nil, note: "Test results", leaving: false)
        XCTAssertEqual(call.title, "Time to call Priya Shah"); XCTAssertTrue(call.body.contains("(630) 555-0142") && call.body.contains("Test results"))
        let go = ContactBook.planMessage(doc, kind: .visit, start: eight, travelMinutes: 25, note: "", leaving: true)
        XCTAssertTrue(go.title.hasPrefix("Leave now for Priya Shah — 25 min drive")); XCTAssertTrue(go.body.contains("12 Main St, Naperville IL"))
        XCTAssertEqual(ContactPlans.telURL("(630) 555-0142")?.absoluteString, "tel:6305550142")
        XCTAssertNotNil(ContactPlans.mapsURL("12 Main St\nNaperville IL"))
        XCTAssertEqual(ContactPlans.handle(action: ContactPlans.callAction, info: ["tel": "tel:6305550142"])?.absoluteString, "tel:6305550142")
        XCTAssertEqual(ContactBook.kind("_$!<Mobile>!$_"), "mobile"); XCTAssertEqual(ContactBook.safe("A/B: group"), "A-B- group")
    }

    func testDailyBriefSaysWhatMattersToday() throws {
        let cal = Calendar(identifier: .gregorian)
        let day = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 7)))
        var f = DailyBrief.Facts()
        f.doses = [("Vitamin D", day.addingTimeInterval(3600)), ("Metformin", day.addingTimeInterval(12 * 3600))]
        f.due = [("Water bill", day.addingTimeInterval(86400), "$84.20"), ("Car insurance", day.addingTimeInterval(-86400), nil)]
        f.birthdays = [("Asha Shah", true)]
        f.screenshots = 140; f.screenshotLimit = 100
        let b = DailyBrief.compose(f, for: day, cal: cal)
        XCTAssertTrue(b.title.hasPrefix("Your day · "))
        XCTAssertTrue(b.lines[0].hasPrefix("💊 2 doses: Vitamin D"))
        XCTAssertTrue(b.lines.contains("📄 Car insurance — overdue"), "\(b.lines)")
        XCTAssertTrue(b.lines.contains("📄 Water bill ($84.20) — due tomorrow"))
        XCTAssertTrue(b.lines.contains("🎂 Asha Shah's birthday is today"))
        XCTAssertTrue(b.lines.contains("🧹 140 screenshots — tidy up to your 100"))
        XCTAssertLessThanOrEqual(b.body.split(separator: "\n").count, 4, "the notification stays short")
        let quiet = DailyBrief.compose(DailyBrief.Facts(), for: day, cal: cal)
        XCTAssertTrue(quiet.lines.isEmpty); XCTAssertTrue(quiet.body.hasPrefix("Nothing pressing today"))
        let six = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 6)))
        XCTAssertEqual(cal.component(.day, from: DailyBrief.nextFire(after: six, hour: 7, minute: 0, cal: cal)), 20, "later today")
        XCTAssertEqual(cal.component(.day, from: DailyBrief.nextFire(after: day.addingTimeInterval(60), hour: 7, minute: 0, cal: cal)), 21, "tomorrow once it's passed")
    }

    func testPaperworkPackForTheYear() throws {
        let cal = Calendar(identifier: .gregorian)
        func d(_ y: Int, _ m: Int, _ dd: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: dd, hour: 12))! }
        var a = Receipt(imageFile: "a.jpg", store: "Costco", purchaseDate: d(2026, 3, 14), total: "$129.99", rawText: "")
        a.warrantyMonths = 12
        let b = Receipt(imageFile: "b.jpg", store: "Costco", purchaseDate: d(2026, 3, 14), total: "$5.00", rawText: "")
        let old = Receipt(imageFile: "c.jpg", store: "Target", purchaseDate: d(2025, 7, 1), total: "$20", rawText: "")
        var bill = SortedLetters.Item(kind: "Bill", title: "Water, sewer", amount: "$84.20", due: d(2026, 12, 15), summary: ""); bill.done = true
        XCTAssertEqual(PaperworkExport.years(receipts: [a, b, old], letters: [bill]), [2026, 2025])
        var taken = Set<String>()
        XCTAssertEqual(PaperworkExport.photoName(a, taken: &taken), "2026-03-14 Costco.jpg")
        XCTAssertEqual(PaperworkExport.photoName(b, taken: &taken), "2026-03-14 Costco 2.jpg", "same day, same store → numbered")
        let rows = PaperworkExport.receiptRows([b, a], photoNames: [a.id: "2026-03-14 Costco.jpg"])
        XCTAssertEqual(rows.count, 3); XCTAssertEqual(rows[0][0], "Date")
        XCTAssertTrue(rows.contains { $0[2] == "$129.99" && $0[4] == "2027-03-14" && $0[7] == "Receipt photos/2026-03-14 Costco.jpg" })
        let csv = PaperworkExport.csv(PaperworkExport.letterRows([bill]))
        XCTAssertTrue(csv.contains("2026-12-15,Bill,\"Water, sewer\",$84.20,Paid / done"), csv)
        let pack = try XCTUnwrap(PaperworkExport.make(year: 2026, receipts: [a, b, old], letters: [bill]) { _ in Data([0xFF, 0xD8, 0xFF]) })
        XCTAssertEqual(pack.receipts, 2); XCTAssertEqual(pack.letters, 1); XCTAssertEqual(pack.photos, 2)
        let names = Given.Zip.names(in: pack.url)
        XCTAssertTrue(names.contains("Receipts 2026.csv") && names.contains("Bills and letters 2026.csv") && names.contains("Read me.txt"), "\(names)")
        XCTAssertTrue(names.contains("Receipt photos/2026-03-14 Costco 2.jpg"))
        XCTAssertNil(PaperworkExport.make(year: 2020, receipts: [a], letters: []) { _ in nil }, "an empty year makes nothing")
    }

    func testCaregiverFollowUpsSummaryAndSharing() throws {
        let cal = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 7, minute: 50)))
        var m = Med(); m.name = "Metformin"; m.times = [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)]
        m.start = cal.startOfDay(for: now.addingTimeInterval(-86400))
        let all = MedCare.followUps([m], taken: { _, _ in false }, minutes: 30, now: now, cal: cal)
        XCTAssertEqual(all.count, 4, "today and tomorrow, both doses")
        XCTAssertEqual(cal.dateComponents([.hour, .minute], from: all[0].at), DateComponents(hour: 8, minute: 30))
        let eight = all[0].dose
        let afterTaken = MedCare.followUps([m], taken: { _, d in d == eight }, minutes: 30, now: now, cal: cal)
        XCTAssertEqual(afterTaken.count, 3, "a taken dose gets no follow-up")
        XCTAssertTrue(MedCare.followUps([m], taken: { _, _ in false }, minutes: 0, now: now, cal: cal).isEmpty, "off is off")
        XCTAssertEqual(MedCare.followUpMessage(m, dose: eight, caregiver: "Ravi").title, "Did you take your Metformin?")
        XCTAssertTrue(MedCare.followUpMessage(m, dose: eight, caregiver: "Ravi").body.hasSuffix("or let Ravi know."))
        XCTAssertEqual(MedCare.weekSummary(taken: 13, due: 14, missed: ["Metformin Tue 8 PM"]),
                       "This week: 13 of 14 doses taken (93%). Missed: Metformin Tue 8 PM. — from Tenzy Medicine Reminders")
        XCTAssertEqual(MedCare.weekSummary(taken: 0, due: 0, missed: []), "No doses were due this week.")
        XCTAssertNotNil(MedCare.smsURL("+1 (630) 555-0199", body: "13 of 14"))
        // A list set up on one phone, added on another: same medicines, new ids, nothing else carried over.
        let text = MedCare.shareText([m])
        XCTAssertTrue(text.hasPrefix("tenzy-meds:"))
        let back = try XCTUnwrap(MedCare.imported("Here you go Mom: " + text + " love you"))
        XCTAssertEqual(back.map(\.name), ["Metformin"]); XCTAssertEqual(back[0].times, m.times); XCTAssertNotEqual(back[0].id, m.id)
        XCTAssertNil(MedCare.imported("hello")); XCTAssertNil(MedCare.imported("tenzy-meds:notbase64!!"))
    }

    func testKeepOnlyMyNewestScreenshots() {
        let shots = Array(1...130)                                   // newest first
        XCTAssertEqual(PhotoCleaner.beyondNewest(shots, keep: 100), Array(101...130), "the 30 oldest go")
        XCTAssertEqual(PhotoCleaner.beyondNewest(shots, keep: 100, protect: { $0 == 120 }).count, 29, "a favourite stays even when old")
        XCTAssertTrue(PhotoCleaner.beyondNewest(shots, keep: 150).isEmpty, "under the limit, nothing goes")
        XCTAssertTrue(PhotoCleaner.beyondNewest(shots, keep: -1).isEmpty, "a bad number never selects everything")
        XCTAssertEqual(PhotoCleaner.beyondNewest(shots, keep: 0).count, 130)
    }

    func testBusinessCardsReadMergeAndNeverMistakeAChat() throws {
        let front = "JANE R. DOE\nSenior Product Manager\nACME ROBOTICS INC\n+1 (312) 555-0147\njane.doe@acme.io"
        let back = "www.acme.io\n200 Main Street, Chicago\nMobile 312 555 0199\njane.doe@acme.io"
        XCTAssertTrue(CardKit.looksLikeCard(front))
        // The real screenshot that was wrongly read as a card: a Teams chat.
        let chat = "Bechara, Bernard\nthanks Manan, can we actually remove\nthe other attendees for Friday? I worry\nthat people will still call in even the\nmeeting is optional to them.\nUpdated.\nToday 10:09 AM\nHi Manan, I can't attend the meeting on Friday, can you move it to next week please"
        XCTAssertFalse(CardKit.looksLikeCard(chat))
        let m = CardKit.merge(DataGrab.card(front), DataGrab.card(back))
        XCTAssertEqual(m.emails.count, 1, "same email on both sides is kept once")
        XCTAssertEqual(m.phones.count, 2, "the back's mobile is added")
        XCTAssertFalse(m.website.isEmpty)
        let url = try XCTUnwrap(CardKit.linkedIn(m))
        XCTAssertTrue(url.absoluteString.hasPrefix("https://www.linkedin.com/search/results/people/"))
        XCTAssertTrue(CardKit.metNote(where: "HIMSS, Chicago").hasPrefix("Met at HIMSS, Chicago"))
        XCTAssertTrue(CardKit.metNote(where: "").hasPrefix("Met "))
        let c = CardKit.contact(CardKit.Entry(card: m))
        XCTAssertEqual(c.emailAddresses.count, 1); XCTAssertEqual(c.phoneNumbers.count, 2)
        XCTAssertEqual(m.company, "ACME ROBOTICS INC", "the company word wins, not the all-caps name")
        XCTAssertEqual(m.name, "JANE R. DOE"); XCTAssertEqual(c.givenName, "JANE")
        XCTAssertNotNil(CardKit.qr(m))
        XCTAssertNil(CardKit.linkedIn(DataGrab.Card()))
    }

    func testAnimateLooksAndPrintableFlipbook() throws {
        let photos = [Self.text("ONE"), Self.text("TWO"), Self.text("THREE")]
        XCTAssertEqual(Animate.applyLook(.original, to: photos).count, 3)
        let comic = Animate.applyLook(.comic, to: photos)
        XCTAssertEqual(comic.count, 3)
        XCTAssertFalse(comic[0].pngData() == photos[0].pngData(), "the look really changes the picture")
        var s = Animate.Settings(); s.style = .crossfade
        let pdf = try XCTUnwrap(Animate.flipbookPDF(photos, settings: s, frames: 16))
        let doc = try XCTUnwrap(PDFDocument(data: pdf))
        XCTAssertEqual(doc.pageCount, 2, "16 frames at 8 a page")
        XCTAssertTrue((doc.string ?? "").contains("16"), "frames are numbered")
    }

    func testAudioConvertRejectsNonAudioGracefully() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("junk-\(UUID().uuidString.prefix(6)).caf")
        try Data("not audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let outcome = await AudioConvert.convert(url, to: .m4a)
        guard case .failure(let f) = outcome else { return XCTFail("garbage input should fail, not succeed") }
        XCTAssertFalse(f.message.isEmpty, "a failure must carry a human message")
    }

    // MARK: Ringtone maker (item 5)

    /// A ringtone must be a real .m4r audio file clamped to ≤30s, cut from the chosen start.
    func testRingtoneClampsToThirtySecondsAndCutsFromStart() async throws {
        let src = try makeToneFile(seconds: 40.0)   // longer than the 30s ceiling on purpose
        defer { try? FileManager.default.removeItem(at: src) }

        // Ask for 60s from 5s in — must clamp to 30s (not 35s to the end, not 60s).
        let outcome = await AudioConvert.ringtone(src, start: 5, length: 60)
        guard case .success(let out) = outcome else { return XCTFail("ringtone export failed") }
        defer { try? FileManager.default.removeItem(at: out) }
        XCTAssertEqual(out.pathExtension, "m4r", "a ringtone must be a .m4r file")
        let size = ((try? FileManager.default.attributesOfItem(atPath: out.path))?[.size] as? Int) ?? 0
        XCTAssertGreaterThan(size, 1_000, "ringtone output is empty/tiny")
        let asset = AVURLAsset(url: out)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)   // hoisted: await can't live inside an XCTAssert autoclosure
        XCTAssertFalse(audioTracks.isEmpty, "ringtone has no audio")
        let dur = try await asset.load(.duration).seconds
        XCTAssertLessThanOrEqual(dur, 30.3, "ringtone must be clamped to 30 seconds")
        XCTAssertEqual(dur, 30.0, accuracy: 0.6, "a 60s request should fill the 30s ceiling")
    }

    // MARK: Audio Editor — trim / fades / dead-air (item 6)

    /// Fades must ramp the first and last stretch from silence, leaving the middle untouched.
    func testAudioEditFadesRampTheEdgesToSilence() {
        var x = [Float](repeating: 1.0, count: 1000)      // 1 s at 1000 Hz
        AudioEdit.applyFades(&x, rate: 1000, fadeIn: 0.1, fadeOut: 0.1)   // 100 samples each
        XCTAssertEqual(x.first ?? 1, 0, accuracy: 0.0001, "fade-in starts at silence")
        XCTAssertEqual(x.last ?? 1, 0, accuracy: 0.0001, "fade-out ends at silence")
        XCTAssertEqual(x[50], 0.5, accuracy: 0.02, "fade-in is about half-way at its midpoint")
        XCTAssertEqual(x[500], 1.0, accuracy: 0.0001, "the middle is left untouched")
    }

    /// A loud / silent / loud buffer must yield exactly one dead-air region covering the silent second,
    /// and the kept segments must be the two loud seconds.
    func testAudioEditFindsDeadAirAndKeepsTheRest() {
        let rate = 1000.0
        let loud = [Float](repeating: 0.5, count: 1000)
        let quiet = [Float](repeating: 0.0, count: 1000)
        let mono = loud + quiet + loud                    // 3 s: loud, 1 s silence, loud
        let regions = AudioEdit.silentRegions(mono, rate: rate, thresholdDB: -40, minSilence: 0.5)
        XCTAssertEqual(regions.count, 1, "exactly one dead-air gap")
        if let r = regions.first {
            XCTAssertEqual(Double(r.lowerBound), 1000, accuracy: 40, "gap starts at the silence")
            XCTAssertEqual(Double(r.upperBound), 2000, accuracy: 40, "gap ends where the loud audio returns")
        }
        let kept = AudioEdit.keepSegments(total: mono.count, cut: regions)
        let keptCount = kept.reduce(0) { $0 + ($1.upperBound - $1.lowerBound) }
        XCTAssertEqual(Double(keptCount), 2000, accuracy: 60, "keeps the two loud seconds, drops the silent one")
    }

    /// End-to-end on in-memory channels: trimming keeps exactly the window, and dead-air removal shortens.
    func testAudioEditProcessTrimsAndRemovesSilence() {
        let rate = 1000.0
        let loud = [Float](repeating: 0.5, count: 1000)
        let quiet = [Float](repeating: 0.0, count: 1000)
        let channel = loud + quiet + loud                 // 3 s

        var silence = AudioEdit.Options()
        silence.removeSilence = true
        let cut = AudioEdit.process(channels: [channel], rate: rate, options: silence)
        XCTAssertEqual(cut.count, 1, "channel count preserved")
        XCTAssertEqual(Double(cut[0].count), 2000, accuracy: 60, "dead air removed → two loud seconds remain")

        var trim = AudioEdit.Options()
        trim.start = 0.5; trim.end = 2.5
        let t = AudioEdit.process(channels: [channel], rate: rate, options: trim)
        XCTAssertEqual(Double(t[0].count), 2000, accuracy: 2, "trim keeps exactly the 2 s window")
    }

    /// Writing a real file: a 3 s tone trimmed to [0.5, 2.5] must produce a playable ~2 s M4A — a true
    /// end-to-end output assertion, not "did it open".
    func testAudioEditFileTrimProducesPlayableShorterClip() async throws {
        let src = try makeToneFile(seconds: 3.0)
        defer { try? FileManager.default.removeItem(at: src) }
        var opts = AudioEdit.Options()
        opts.start = 0.5; opts.end = 2.5; opts.fadeIn = 0.1; opts.fadeOut = 0.1
        let outcome = await AudioEdit.edit(src, options: opts, format: .m4a)
        guard case .success(let out) = outcome else { return XCTFail("audio edit failed") }
        defer { try? FileManager.default.removeItem(at: out) }
        XCTAssertEqual(out.pathExtension, "m4a", "edited clip should be the chosen format")
        let size = ((try? FileManager.default.attributesOfItem(atPath: out.path))?[.size] as? Int) ?? 0
        XCTAssertGreaterThan(size, 1_000, "edited output is empty/tiny")
        let asset = AVURLAsset(url: out)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertFalse(tracks.isEmpty, "edited output has no audio track")
        let dur = try await asset.load(.duration).seconds
        XCTAssertEqual(dur, 2.0, accuracy: 0.3, "trimming 0.5–2.5 s of a 3 s clip should leave ~2 s")
    }

    /// Garbage input must fail cleanly with a human message, never crash or hang.
    func testAudioEditRejectsNonAudioGracefully() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("junk-\(UUID().uuidString.prefix(6)).caf")
        try Data("not audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let outcome = await AudioEdit.edit(url, options: AudioEdit.Options())
        guard case .failure(let f) = outcome else { return XCTFail("garbage input should fail, not succeed") }
        XCTAssertFalse(f.message.isEmpty, "a failure must carry a human message")
    }

    // MARK: Audio Cleanup — noise reduction / high-pass / normalize (item 7)

    /// The high-pass must kill DC (0 Hz, the ultimate low frequency): a constant input decays to silence.
    func testAudioCleanHighPassRemovesDC() {
        var x = [Float](repeating: 0.5, count: 4000)
        AudioClean.highPass(&x, rate: 44_100, cutoff: 90)
        XCTAssertEqual(x[3999], 0, accuracy: 0.02, "DC is removed by the high-pass once settled")
    }

    /// …but a tone well above the cutoff passes through largely intact (most of its energy survives).
    func testAudioCleanHighPassKeepsHighTone() {
        let rate = 44_100.0
        var x = (0..<4410).map { Float(sin(2 * Double.pi * 1000 * Double($0) / rate)) }
        let before = x
        AudioClean.highPass(&x, rate: rate, cutoff: 90)
        let e0 = before.reduce(Float(0)) { $0 + $1 * $1 }
        let e1 = x.reduce(Float(0)) { $0 + $1 * $1 }
        XCTAssertGreaterThan(e1, e0 * 0.8, "a 1 kHz tone passes the 90 Hz high-pass largely intact")
    }

    /// The noise floor is measured from the quiet windows, not the loud ones.
    func testAudioCleanNoiseFloorTracksTheQuietParts() {
        let rate = 1000.0
        let loud = [Float](repeating: 0.5, count: 2000)
        let quiet = [Float](repeating: 0.01, count: 2000)
        let floor = AudioClean.noiseFloor(loud + quiet + loud, rate: rate)
        XCTAssertEqual(floor, 0.01, accuracy: 0.004, "floor reflects the quiet background, not the peaks")
    }

    /// The gate pushes down a quiet, noisy passage while leaving loud passages at full level.
    func testAudioCleanGateAttenuatesQuietKeepsLoud() {
        let rate = 1000.0
        let loud = [Float](repeating: 0.5, count: 2000)
        let quiet = [Float](repeating: 0.01, count: 2000)
        var buf = loud + quiet + loud
        let floor = AudioClean.noiseFloor(quiet, rate: rate)
        AudioClean.gate(&buf, rate: rate, floor: floor, strength: 0.8)
        XCTAssertEqual(buf[1500], 0.5, accuracy: 0.05, "loud passage preserved")
        XCTAssertEqual(buf[5000], 0.5, accuracy: 0.05, "second loud passage preserved")
        XCTAssertLessThan(abs(buf[3000]), 0.005, "the quiet noisy middle is clearly reduced")
    }

    /// Normalize scales the loudest peak to the target, shares one gain across channels, and never blows
    /// up on silence.
    func testAudioCleanNormalizeRaisesPeakAndKeepsBalance() {
        var chans: [[Float]] = [[0.1, 0.2, 0.1], [0.05, 0.1, 0.05]]
        AudioClean.normalize(&chans, targetPeak: 0.9)
        let peak = chans.flatMap { $0 }.map { abs($0) }.max() ?? 0
        XCTAssertEqual(peak, 0.9, accuracy: 0.01, "loudest peak hits the target")
        XCTAssertEqual(chans[0][1] / chans[1][1], 2.0, accuracy: 0.01, "stereo balance preserved (one shared gain)")
    }

    func testAudioCleanNormalizeLeavesSilenceAlone() {
        var chans: [[Float]] = [[0, 0, 0]]
        AudioClean.normalize(&chans, targetPeak: 0.9)
        XCTAssertEqual(chans[0].map { abs($0) }.max() ?? 0, 0, "silence stays silent, no divide-by-zero blow-up")
    }

    /// clean(channels:) preserves channel count and length.
    func testAudioCleanProcessPreservesShape() {
        let rate = 1000.0
        let channel = (0..<3000).map { Float(sin(2 * Double.pi * 200 * Double($0) / rate)) * 0.4 }
        let out = AudioClean.clean(channels: [channel, channel], rate: rate, options: AudioClean.Options())
        XCTAssertEqual(out.count, 2, "channel count preserved")
        XCTAssertEqual(out[0].count, channel.count, "length preserved — cleanup doesn't trim")
    }

    /// End-to-end on a real file: a 2 s tone comes back as a playable ~2 s M4A — a true output assertion.
    func testAudioCleanFileProducesPlayableResult() async throws {
        let src = try makeToneFile(seconds: 2.0)
        defer { try? FileManager.default.removeItem(at: src) }
        let outcome = await AudioClean.clean(src, options: AudioClean.Options(), format: .m4a)
        guard case .success(let out) = outcome else { return XCTFail("audio cleanup failed") }
        defer { try? FileManager.default.removeItem(at: out) }
        XCTAssertEqual(out.pathExtension, "m4a", "cleaned clip should be the chosen format")
        let size = ((try? FileManager.default.attributesOfItem(atPath: out.path))?[.size] as? Int) ?? 0
        XCTAssertGreaterThan(size, 1_000, "cleaned output is empty/tiny")
        let asset = AVURLAsset(url: out)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertFalse(tracks.isEmpty, "cleaned output has no audio track")
        let dur = try await asset.load(.duration).seconds
        XCTAssertEqual(dur, 2.0, accuracy: 0.3, "cleanup keeps the clip length")
    }

    /// Garbage input must fail cleanly with a human message, never crash or hang.
    func testAudioCleanRejectsNonAudioGracefully() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("junkc-\(UUID().uuidString.prefix(6)).caf")
        try Data("not audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let outcome = await AudioClean.clean(url, options: AudioClean.Options())
        guard case .failure(let f) = outcome else { return XCTFail("garbage input should fail, not succeed") }
        XCTAssertFalse(f.message.isEmpty, "a failure must carry a human message")
    }

    // MARK: Meeting Notes — turns / names / follow-up email (item 8)

    /// Turns start a fresh block only where the talking pauses longer than the gap; words close together
    /// stay in one turn. Timestamps and 1-based indexes come through for the turn headers.
    func testMeetingTurnsSplitAtPauses() {
        let words = [
            MeetingNotes.Timed(text: "hello", start: 0.0, end: 0.5),
            MeetingNotes.Timed(text: "there", start: 0.6, end: 1.0),   // 0.1s gap → same turn
            MeetingNotes.Timed(text: "yes",   start: 3.0, end: 3.4),   // 2.0s gap → new turn
            MeetingNotes.Timed(text: "indeed", start: 3.5, end: 3.9),  // 0.1s gap → same turn
        ]
        let turns = MeetingNotes.turns(from: words, gap: 1.2)
        XCTAssertEqual(turns.count, 2, "a long pause starts a new turn")
        XCTAssertEqual(turns[0].text, "hello there")
        XCTAssertEqual(turns[0].index, 1)
        XCTAssertEqual(turns[0].start, 0.0, accuracy: 0.001)
        XCTAssertEqual(turns[1].text, "yes indeed")
        XCTAssertEqual(turns[1].index, 2)
        XCTAssertEqual(turns[1].start, 3.0, accuracy: 0.001)
    }

    func testMeetingTurnsEmptyIsEmpty() {
        XCTAssertTrue(MeetingNotes.turns(from: []).isEmpty)
    }

    /// No big pause anywhere → it all stays one turn (a monologue isn't chopped into fake speakers).
    func testMeetingTurnsSingleWhenNoBigGap() {
        let words = (0..<6).map { MeetingNotes.Timed(text: "w\($0)", start: Double($0) * 0.5, end: Double($0) * 0.5 + 0.3) }
        let turns = MeetingNotes.turns(from: words, gap: 1.2)
        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].text, "w0 w1 w2 w3 w4 w5")
    }

    /// The draft email greets the named people and carries the recap and next steps verbatim.
    func testMeetingEmailAddressesNamedPeopleWithTodos() {
        let email = MeetingNotes.followUpEmail(people: ["John", "Sarah"],
                                               summary: ["Agreed on the Q3 plan"],
                                               todos: ["Send the slides by Friday"])
        XCTAssertTrue(email.hasPrefix("Hi John, Sarah,"), "greets the named attendees")
        XCTAssertTrue(email.contains("Agreed on the Q3 plan"), "recaps the summary")
        XCTAssertTrue(email.contains("Send the slides by Friday"), "lists the next steps")
    }

    /// With nobody named it still produces a usable draft that greets everyone.
    func testMeetingEmailGreetsAllWhenNoNames() {
        let email = MeetingNotes.followUpEmail(people: [], summary: ["Covered the roadmap"], todos: [])
        XCTAssertTrue(email.contains("Hi all,"))
        XCTAssertTrue(email.contains("Covered the roadmap"))
    }

    /// The name finder never invents names and never returns junk: empty in → empty out, and any result is
    /// de-duplicated, capped and non-empty. (It doesn't assert specific detections, which depend on the
    /// on-device name model that may be absent in CI.)
    func testMeetingPeopleIsCleanAndSafe() {
        XCTAssertTrue(MeetingNotes.people(in: "").isEmpty, "no text → no names")
        let ppl = MeetingNotes.people(in: "Thanks everyone. Priya and Marcus will own the rollout; Priya, send the deck.", limit: 8)
        XCTAssertLessThanOrEqual(ppl.count, 8, "respects the cap")
        XCTAssertEqual(Set(ppl.map { $0.lowercased() }).count, ppl.count, "no duplicate names")
        XCTAssertTrue(ppl.allSatisfy { !$0.isEmpty }, "no empty names")
    }

    // MARK: Soundboard — voice changer (item 9)

    /// Every voice card must turn a real recording into a non-empty, playable WAV — a true end-to-end
    /// output assertion that the proven voice-change DSP is wired through every Soundboard card. (robot/
    /// alien/monster render via offline DSP; chipmunk/helium/giant/deep via varispeed — and a DSP voice
    /// safely falls back to varispeed, so every card produces sound.)
    func testSoundboardEveryVoiceProducesPlayableWAV() async throws {
        let src = try makeToneFile(seconds: 1.0)
        defer { try? FileManager.default.removeItem(at: src) }
        for voice in ChainText.voices.map({ $0.id }) {
            let data = try XCTUnwrap(ChainMedia.soundboardVoice(src, voice: voice), "\(voice) produced no audio")
            XCTAssertGreaterThan(data.count, 44, "\(voice) WAV is header-only/empty")
            XCTAssertEqual(Array(data.prefix(4)), Array("RIFF".utf8), "\(voice) output isn't a WAV")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("sb-\(voice)-\(UUID().uuidString.prefix(6)).wav")
            try data.write(to: url)
            defer { try? FileManager.default.removeItem(at: url) }
            let tracks = try await AVURLAsset(url: url).loadTracks(withMediaType: .audio)
            XCTAssertFalse(tracks.isEmpty, "\(voice) WAV has no audio track")
        }
    }

    /// Every voice is its own sound: pitch shifted without garbling the words, small voices a touch quicker,
    /// big ones slower and roomier — so no two voices give the same file. And a preview renders only the
    /// opening seconds, so tapping a voice plays almost at once.
    func testEveryVoiceSoundsDifferentAndPreviewsAreShort() throws {
        let src = try makeToneFile(seconds: 2.0)
        defer { try? FileManager.default.removeItem(at: src) }
        let chip = try XCTUnwrap(ChainMedia.soundboardVoice(src, voice: "chipmunk"))
        let giant = try XCTUnwrap(ChainMedia.soundboardVoice(src, voice: "giant"))
        XCTAssertLessThan(chip.count, giant.count, "chipmunk is quicker; giant is slower with a room tail")
        let outs = try ChainText.voices.map { try XCTUnwrap(ChainMedia.soundboardVoice(src, voice: $0.id), $0.id) }
        XCTAssertEqual(Set(outs).count, outs.count, "every voice gives its own sound")
        let preview = try XCTUnwrap(ChainMedia.previewVoice(src, voice: "robot", seconds: 0.5))
        let full = try XCTUnwrap(ChainMedia.soundboardVoice(src, voice: "robot"))
        XCTAssertLessThan(preview.count, full.count / 2, "a preview is just the opening")
        for v in ChainText.voices { XCTAssertNotNil(ChainText.voiceLooks[v.id], "\(v.id) has a picture and a line") }
    }

    /// A file with no audio must fail cleanly (nil), never crash or hang.
    func testSoundboardRejectsNonAudioGracefully() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sbjunk-\(UUID().uuidString.prefix(6)).caf")
        try Data("not audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNil(ChainMedia.soundboardVoice(url, voice: "robot"), "garbage input should return nil, not crash")
    }
}
