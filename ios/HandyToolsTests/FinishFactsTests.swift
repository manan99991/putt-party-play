import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import HandyTools

/// The finished screens only say what they read back from the file. These check the readers on real bytes.
final class FinishFactsTests: XCTestCase {
    private func pdf(_ pages: [String]) -> Data {
        let r = CGRect(x: 0, y: 0, width: 612, height: 792)
        return UIGraphicsPDFRenderer(bounds: r).pdfData { c in
            for p in pages { c.beginPage(); (p as NSString).draw(at: CGPoint(x: 72, y: 72), withAttributes: [.font: UIFont.systemFont(ofSize: 18)]) }
        }
    }

    func testPDFFactsCountPagesAndSearchableWords() throws {
        let f = try XCTUnwrap(PDFFacts.read(pdf(["Invoice 1042 total due", "Second page here"])))
        XCTAssertEqual(f.pages, 2)
        XCTAssertGreaterThanOrEqual(f.words, 6)
        XCTAssertFalse(f.locked)
        XCTAssertNil(PDFFacts.read(Data("not a pdf".utf8)))
    }

    func testGIFFactsReadFramesAndLoop() throws {
        let d = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(d, UTType.gif.identifier as CFString, 3, nil))
        for i in 0..<3 {
            let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
            let img = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30), format: fmt).image { c in
                UIColor(hue: CGFloat(i) / 3, saturation: 1, brightness: 1, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
            }
            CGImageDestinationAddImage(dest, img.cgImage!, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: 0.2]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        let f = try XCTUnwrap(GIFFacts.read(d as Data))
        XCTAssertEqual(f.frames, 3)
        XCTAssertEqual(f.seconds, 0.6, accuracy: 0.05)
        XCTAssertEqual(f.size, CGSize(width: 40, height: 30))
    }

    func testIDCopyFactsSeeNoLocationInARedrawnPhotoAndCheckTheLimit() throws {
        let jpg = try XCTUnwrap(SampleAssets.photo().jpegData(compressionQuality: 0.8))
        let f = IDCopyCheck.facts(jpg, ext: "jpg", targetBytes: 500_000)
        XCTAssertFalse(f.hasLocation)
        XCTAssertEqual(f.underTarget, jpg.count <= 500_000)
        let portal = try XCTUnwrap(ChainTemplates.all.first { $0.id == "id-portal" })
        XCTAssertEqual(IDCopyCheck.target(portal), 500_000)
        XCTAssertTrue(IDCopyCheck.line("For Chase only", on: Date(timeIntervalSince1970: 0)).hasPrefix("For Chase only · "))
        XCTAssertTrue(IDCopyCheck.line("  ").hasPrefix("For verification only"))
    }

    func testVideoPromiseReadsWhatEachToolPromised() throws {
        func promise(_ id: String) throws -> VideoPromise { VideoPromise(try XCTUnwrap(ChainTemplates.all.first { $0.id == id })) }
        XCTAssertEqual(try promise("video-chat").underBytes, 16_000_000)
        XCTAssertEqual(try promise("video-story").maxSeconds, 30)
        XCTAssertTrue(try promise("video-story").tall)
        XCTAssertTrue(try promise("video-quiet").silent)
        XCTAssertEqual(try promise("video-fast").speed, "fast")
    }

    func testSampleToneIsAPlayableWav() throws {
        let d = SampleAssets.tone()
        XCTAssertEqual(String(data: d.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertGreaterThan(d.count, 44_100 * 2 * 2)
    }

    func testEachFinishedScreenIsWhereItsJobLands() {
        let screen = { (id: String) in ChainTemplates.all.first { $0.id == id }.flatMap(ResultScreens.screen(for:)) }
        XCTAssertEqual(screen("id-copy-watermarked"), "ID copy")
        XCTAssertEqual(screen("id-both-sides"), "ID copy")
        XCTAssertEqual(screen("doc-portal"), "Scan PDF")
        XCTAssertEqual(screen("pdf-email"), "PDF finish")
        XCTAssertEqual(screen("video-slowmo"), "Video finish")
        XCTAssertEqual(screen("video-gif"), "GIF finish")
        XCTAssertEqual(screen("photos-gif"), "GIF finish")
        XCTAssertEqual(screen("qr-safe"), "Scam verdict")
        XCTAssertEqual(screen("voice-ghost"), "Voice finish")
        XCTAssertEqual(screen("wifi-sign"), "Code finish")
        XCTAssertEqual(screen("whatsapp-no-save"), "Chat link")
        // A watermark at the start of some other job doesn't make it an ID copy.
        XCTAssertNil(ResultScreens.screen(for: Chain(id: "x", name: "x", steps: [ChainStep(block: .watermark), ChainStep(block: .cleanText)])))
    }

    func testVideoJoinTurnsClipsUprightAndKeepsThemVideos() async throws {
        // A phone video stored sideways (1920x1080, turned 90°) fits a 1080x1920 frame exactly.
        let t = CGAffineTransform(rotationAngle: .pi / 2)
        let r = CGRect(x: 0, y: 0, width: 1920, height: 1080).applying(VideoJoin.fit(natural: CGSize(width: 1920, height: 1080), transform: t, into: CGSize(width: 1080, height: 1920)))
        XCTAssertEqual(r.minX, 0, accuracy: 0.5); XCTAssertEqual(r.minY, 0, accuracy: 0.5)
        XCTAssertEqual(r.width, 1080, accuracy: 0.5); XCTAssertEqual(r.height, 1920, accuracy: 0.5)
        XCTAssertEqual(VideoJoin.even(CGSize(width: 641, height: 359)), CGSize(width: 640, height: 358))

        let ma = await SampleAssets.movie(), mb = await SampleAssets.movie()
        let a = try XCTUnwrap(ma), b = try XCTUnwrap(mb)
        let j = await VideoJoin.join([a, b])
        let joined = try XCTUnwrap(j, "two videos must join into a video")
        let jf = await VideoFacts.read(joined)
        let f = try XCTUnwrap(jf)
        XCTAssertEqual(f.seconds, 5, accuracy: 0.4, "both clips, end to end")
        XCTAssertEqual(f.size, CGSize(width: 640, height: 360))
        let fu = await VideoJoin.join([a], rate: 2)
        let fast = try XCTUnwrap(fu)
        let ff = await VideoFacts.read(fast)
        XCTAssertEqual(try XCTUnwrap(ff).seconds, 1.25, accuracy: 0.3, "2x makes it half as long")
    }

    /// "Video shows only video tools; audio only audio tools."
    func testVideoAndAudioListsStayInTheirLane() {
        let audioOnly: Set = ["audiocompress", "audioconvert", "audiotags", "meetingnotes", "audioclean", "audioedit", "ringtone", "soundboard"]
        let video = ToolHandoff.tools(for: .video)
        XCTAssertEqual(video.first, "video", "the Video tool comes first for a video")
        XCTAssertTrue(Set(video).isDisjoint(with: audioOnly), "audio-only tools offered for a video: \(Set(video).intersection(audioOnly))")
        XCTAssertFalse(ToolHandoff.tools(for: .audio).contains("video"))
    }
}
