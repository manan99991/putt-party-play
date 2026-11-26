import XCTest
import AVFoundation
@testable import HandyTools

/// My week, as one short film (26 Nov): it comes back once a week on the chosen day, tells the week day by day, and the
/// film itself is really made — tall, the title first, photos and a clip's liveliest seconds joined into one video.
final class SmartWeekTests: XCTestCase {
    typealias S = SmartRuns
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Chicago")!; return c }
    private func at(_ d: Int, _ h: Int, _ m: Int = 0, month: Int = 11) -> Date { cal.date(from: DateComponents(year: 2026, month: month, day: d, hour: h, minute: m))! }

    func testItComesBackOnSundayEvening() {
        var p = S.Plan.start(.weekFilm)
        XCTAssertEqual(p.weekday, 1); XCTAssertEqual(p.hour, 18)
        XCTAssertNil(S.Plan.start(.receipts).weekday, "daily autoruns stay daily")
        p.on = true; p.twice = true
        XCTAssertEqual(p.times.count, 1, "a weekly film never runs twice a day")
        // 25 Nov 2026 is a Wednesday; the next Sunday is the 29th.
        XCTAssertEqual(S.nextDue(p, after: at(25, 9), cal: cal), at(29, 18))
        XCTAssertFalse(S.isDue(p, lastRun: at(22, 18, 5), now: at(28, 23), cal: cal), "not on Saturday")
        XCTAssertTrue(S.isDue(p, lastRun: at(22, 18, 5), now: at(29, 18, 2), cal: cal), "Sunday at six")
        p.weekday = 6
        XCTAssertEqual(S.nextDue(p, after: at(25, 9), cal: cal), at(27, 18), "or Friday, if that's the day picked")
    }

    private func photo(_ id: String, _ d: Int, _ h: Int) -> S.Found {
        S.Found(id: id, created: at(d, h), seen: S.PhotoSeen(labels: [], text: "", faces: 1, sharpness: 0.9))
    }
    private func clip(_ id: String, _ d: Int, _ h: Int) -> S.Found {
        S.Found(id: id, created: at(d, h), isVideo: true, bytes: 20_000_000, seconds: 20, width: 1920, height: 1080)
    }

    func testTheWeekIsToldDayByDay() {
        let photos = [photo("mon1", 23, 9), photo("mon2", 23, 12), photo("mon3", 23, 15), photo("mon4", 23, 18), photo("mon5", 23, 21),
                      photo("wed1", 25, 10), photo("sat1", 28, 11), photo("sat2", 28, 16)]
        let clips = [clip("wedclip", 25, 19), clip("friclip", 27, 20)]
        let parts = SmartWeek.story(photos: photos.shuffled(), clips: clips, cal: cal)
        XCTAssertEqual(parts, [.photos(["mon1", "mon3", "mon5"]), .photos(["wed1"]), .clip("wedclip"), .clip("friclip"), .photos(["sat1", "sat2"])],
                       "in the order it happened; a busy day gives three photos spread across it")
        XCTAssertTrue(SmartWeek.worthMaking(parts))
        XCTAssertFalse(SmartWeek.worthMaking(SmartWeek.story(photos: Array(photos.prefix(5)), clips: [], cal: cal)), "one day isn't a week")
        XCTAssertFalse(SmartWeek.worthMaking([.photos(["a"]), .clip("b")]), "two moments aren't a film")
    }

    func testTheTitleNamesTheWeek() {
        let t = SmartWeek.title(from: at(20, 0), to: at(26, 20), cal: cal)
        XCTAssertTrue(t.hasPrefix("My week · "), t)
        XCTAssertTrue(t.hasSuffix("26"), "same month: the month once — \(t)")
        let across = SmartWeek.title(from: at(28, 0), to: at(4, 20, month: 12), cal: cal)
        XCTAssertEqual(across.components(separatedBy: " – ").count, 2)
        XCTAssertTrue(across.components(separatedBy: " – ")[1].count > 2, "across two months, both are named — \(across)")
    }

    /// A 6-second landscape clip with something moving, the way a phone video would be.
    private func makeClip() async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("week-\(UUID().uuidString).mp4")
        let w = 640, h = 360, frames = 180
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
        writer.add(input)
        XCTAssertTrue(writer.startWriting()); writer.startSession(atSourceTime: .zero)
        for i in 0..<frames {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 2_000_000) }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
            let buf = try XCTUnwrap(pb)
            CVPixelBufferLockBaseAddress(buf, [])
            let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: w, height: h, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
            ctx.setFillColor(UIColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1).cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.setFillColor(UIColor.orange.cgColor); ctx.fillEllipse(in: CGRect(x: (i * 3) % w, y: 120, width: 120, height: 120))
            CVPixelBufferUnlockBaseAddress(buf, [])
            adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return url
    }

    private func picture(_ hue: CGFloat) -> UIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 900), format: f).image { c in
            UIColor(hue: hue, saturation: 0.6, brightness: 0.85, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 1200, height: 900))
            UIColor.white.setFill(); c.cgContext.fillEllipse(in: CGRect(x: 450, y: 300, width: 300, height: 300))
        }
    }

    func testTheFilmIsReallyMade() async throws {
        let card = SmartWeek.card("My week · Nov 20 – 26", size: CGSize(width: 1080, height: 1920))
        XCTAssertEqual(card.size, CGSize(width: 1080, height: 1920))
        func mean(_ img: UIImage) -> Double { let px = Stitcher.grayscale(img, width: 40).px; return Double(px.reduce(0) { $0 + Int($1) }) / Double(max(1, px.count)) }
        func frameMeans(_ u: URL) async -> String {
            let g = AVAssetImageGenerator(asset: AVURLAsset(url: u)); g.appliesPreferredTrackTransform = true
            g.requestedTimeToleranceBefore = .zero; g.requestedTimeToleranceAfter = .zero
            var out: [String] = []
            for t in [0.0, 0.2, 0.6, 1.5, 3.0] {
                if let cg = try? await g.image(at: CMTime(seconds: t, preferredTimescale: 600)).image { out.append(String(format: "%.1fs=%.0f", t, mean(UIImage(cgImage: cg)))) }
                else { out.append(String(format: "%.1fs=none", t)) }
            }
            return out.joined(separator: " ")
        }
        let cardMean = mean(card), pictureMean = mean(picture(0.1))
        XCTAssertGreaterThan(cardMean, 60, "the title card itself is dark (\(cardMean))")
        let glided = await SmartWeek.glide([picture(0.1), picture(0.4), picture(0.7)], opening: card)
        let glide = try XCTUnwrap(glided, "the photos didn't become video")
        let glideFrames = await frameMeans(glide)
        let clip = try await makeClip()
        let cut = await SmartWeek.moment(clip)
        let moment = try XCTUnwrap(cut, "the clip's moment wasn't cut")
        let momentLength = await VideoEngine.duration(moment)
        XCTAssertEqual(momentLength, 3, accuracy: 0.4, "three seconds of the clip")
        let joined = await VideoJoin.join([glide, moment])
        let film = try XCTUnwrap(joined)
        let total = await VideoEngine.duration(film), glideLength = await VideoEngine.duration(glide)
        XCTAssertEqual(total, glideLength + momentLength, accuracy: 0.5)
        let tracks = try await AVURLAsset(url: film).loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let size = try await track.load(.naturalSize).applying(try await track.load(.preferredTransform))
        XCTAssertEqual(abs(size.height) / abs(size.width), 16.0 / 9.0, accuracy: 0.02, "tall 9:16")
        // The first frame is the title card (warm orange), not black.
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: film)); gen.appliesPreferredTrackTransform = true
        let first = try await gen.image(at: CMTime(seconds: 0.2, preferredTimescale: 600)).image
        let px = Stitcher.grayscale(UIImage(cgImage: first), width: 40).px
        let filmFrames = await frameMeans(film)
        XCTAssertGreaterThan(Double(px.reduce(0) { $0 + Int($1) }) / Double(px.count), 60,
                             "the film opens on black, not on its title — card \(Int(cardMean)), picture \(Int(pictureMean)), glide [\(glideFrames)], film [\(filmFrames)]")
        for u in [glide, clip, moment, film] { try? FileManager.default.removeItem(at: u) }
    }
}
