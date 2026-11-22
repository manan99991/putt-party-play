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
        XCTAssertNotEqual(ResultScreens.screen(for: Chain(id: "x", name: "x", steps: [ChainStep(block: .watermark), ChainStep(block: .cleanText)])), "ID copy")
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

    /// "A video shows everything you can do starting from a video — including taking its sound out — named as video jobs;
    /// audio-only jobs (song info, compress audio) stay under Audio."
    @MainActor func testVideoListIsEveryVideoJobNamedAsOne() {
        let video = ToolHandoff.tools(for: .video)
        XCTAssertEqual(video.first, "video")
        for must in ["audioconvert", "ringtone", "meetingnotes", "audiomix", "fitit"] { XCTAssertTrue(video.contains(must), "\(must) missing for a video") }
        // Song info is about a music file, not a video; everything else that can work on a video is offered (no hidden tools).
        XCTAssertFalse(video.contains("audiotags"))
        for must in ["audioclean", "audioedit", "audiocompress", "celebrate"] { XCTAssertTrue(video.contains(must), "\(must) can work on a video but isn't offered") }
        for id in video where id != "video" && id != "fitit" {
            XCTAssertNotNil(Guide.videoNames[id], "\(id) is offered for a video under its audio name")
        }
        XCTAssertEqual(Guide.title(.tool("audioconvert"), count: 1, kind: .video), "Save the sound as MP3 or M4A")
        XCTAssertEqual(Guide.goal(ofTool: "audioconvert", kind: .video, count: 1), "sound")
        XCTAssertTrue(Guide.goalIDs(for: .video, count: 1).contains("sound"))
        XCTAssertFalse(ToolHandoff.tools(for: .audio).contains("video"))
    }

    /// "Shrink a video" showed a bare 'Working…' for minutes: the shrink now reports one bar that only moves forward.
    func testVideoShrinkReportsProgressThatOnlyMovesForward() async throws {
        let m = await SampleAssets.movie(seconds: 4, size: CGSize(width: 1280, height: 720))
        let src = try XCTUnwrap(m)
        let seen = Locked<[Double]>([])
        let r = await SizeTarget.videoBestEffort(url: src, targetBytes: 150_000) { f in seen.mutate { $0.append(f) } }
        XCTAssertNotNil(r, "a shrink always hands something back")
        let v = seen.value
        XCTAssertFalse(v.isEmpty, "no progress was reported")
        XCTAssertEqual(v, v.sorted(), "progress went backwards")
        XCTAssertGreaterThan(v.last ?? 0, 0.5)
    }

    /// "I can't see what the notification is about": a finished-job alert names what came out, or why it stopped.
    @MainActor func testFinishedJobNotificationSaysWhatCameOut() {
        let two = pdf(["One", "Two"])
        let ok = ChainRunView.notificationLine(ChainRunner.RunReport(lines: [], result: .file(two, ext: "pdf"), completed: true, stopper: nil))
        XCTAssertTrue(ok.contains("PDF") && ok.contains("2"), ok)
        let text = ChainRunView.notificationLine(ChainRunner.RunReport(lines: [], result: .text("Meeting moved to Friday 3pm"), completed: true, stopper: nil))
        XCTAssertTrue(text.contains("Meeting moved to Friday"), text)
        let failed = ChainRunView.notificationLine(ChainRunner.RunReport(lines: [], result: nil, completed: false, stopper: .invalid("That video has no sound to remove.")))
        XCTAssertTrue(failed.contains("no sound to remove"), failed)
    }

    /// "Remove the sound" took minutes: it now copies the picture as it is, so it's quick and keeps the size.
    func testMutingAVideoIsQuickAndKeepsThePicture() async throws {
        let m = await SampleAssets.movie(seconds: 6, size: CGSize(width: 1280, height: 720))
        let src = try XCTUnwrap(m)
        let t0 = Date()
        let out = await VideoEngine.mute(src)
        let took = Date().timeIntervalSince(t0)
        let u = try XCTUnwrap(out, "mute failed")
        let f = await VideoFacts.read(u)
        XCTAssertEqual(try XCTUnwrap(f).size, CGSize(width: 1280, height: 720))
        XCTAssertFalse(try XCTUnwrap(f).hasSound)
        XCTAssertLessThan(took, 15, "muting a 6-second clip took \(took) s — it should copy, not re-encode")
    }

    /// "Write out what was said" heard only "Mama mama mama": with the language on auto it now tries each of the
    /// person's languages on the first stretch and keeps the one the phone is surest about.
    func testAutoTranscriptionTriesEachOfThePersonsLanguages() {
        let c = Transcriber.candidateLocales(["en-US", "hi-IN", "en-GB", "gu-IN", "es-ES", "fr-FR"], current: Locale(identifier: "en_US"))
        // Your language, Indian English (because Hindi/Gujarati are in your list — talk often mixes them), then Hindi and Gujarati.
        XCTAssertEqual(c.map(\.identifier), ["en_US", "en-IN", "hi-IN", "gu-IN"])
        let plain = Transcriber.candidateLocales(["en-US", "es-ES"], current: Locale(identifier: "en_US"))
        XCTAssertEqual(plain.map(\.identifier), ["en_US", "es-ES"])
    }

    /// "Speed a video up" dropped the sound: it now goes through the same path as Join & Speed (sound kept, natural pitch).
    func testSpeedingUpKeepsTheVideoAndHalvesTheLength() async throws {
        let m = await SampleAssets.movie(seconds: 4)
        let src = try XCTUnwrap(m)
        let fast = await ChainMedia.respeed(src, rate: 2)
        let u = try XCTUnwrap(fast)
        let f = await VideoFacts.read(u)
        XCTAssertEqual(try XCTUnwrap(f).seconds, 2, accuracy: 0.35)
    }

    /// Slow-mo "best moment": the busiest stretch is found from frame changes.
    func testBusiestMomentIsWhereTheFramesChangeMost() {
        let still = [UInt8](repeating: 100, count: 16), moved = [UInt8](repeating: 200, count: 16)
        let frames = [still, still, still, moved, still, moved, still, still, still]
        let scores = VideoJoin.motionScores(frames)
        XCTAssertEqual(scores.count, 8)
        XCTAssertEqual(VideoJoin.busiestWindow(scores, window: 3), 2)
        XCTAssertNil(VideoJoin.busiestWindow(VideoJoin.motionScores([still, still, still, still]), window: 2), "a still clip has no best moment")
    }
}

/// A tiny lock box so a progress callback from another thread can be collected in a test.
final class Locked<T>: @unchecked Sendable {
    private var v: T; private let l = NSLock()
    init(_ v: T) { self.v = v }
    var value: T { l.lock(); defer { l.unlock() }; return v }
    func mutate(_ f: (inout T) -> Void) { l.lock(); f(&v); l.unlock() }
}
