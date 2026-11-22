import XCTest
import AVFoundation
@testable import HandyTools

final class SocialPostTests: XCTestCase {
    private func p(_ id: String) -> SocialPost.Platform { SocialPost.platform(id)! }

    func testThePlanFitsThePlatform() {
        // A sideways 4-minute clip for TikTok: made tall, length fine.
        var pl = SocialPost.plan(p("tiktok"), seconds: 240, bytes: 80_000_000, size: CGSize(width: 1920, height: 1080))
        XCTAssertTrue(pl.makeTall); XCTAssertNil(pl.keepSeconds); XCTAssertNil(pl.underBytes)
        // The same clip for Reels (3 min max): also the liveliest 2:58.
        pl = SocialPost.plan(p("reels"), seconds: 240, bytes: 80_000_000, size: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(pl.keepSeconds, 178)
        // WhatsApp Status: a minute at most, and small.
        pl = SocialPost.plan(p("whatsapp"), seconds: 30, bytes: 40_000_000, size: CGSize(width: 1080, height: 1920))
        XCTAssertFalse(pl.makeTall); XCTAssertNil(pl.keepSeconds); XCTAssertNil(pl.parts); XCTAssertNotNil(pl.underBytes)
        // A longer Status or Story becomes pieces in order (nothing lost), each small enough.
        pl = SocialPost.plan(p("whatsapp"), seconds: 120, bytes: 24_000_000, size: CGSize(width: 1080, height: 1920))
        XCTAssertEqual(pl.parts?.count, 3); XCTAssertNil(pl.keepSeconds); XCTAssertNil(pl.underBytes, "8 MB pieces already fit")
        XCTAssertEqual(pl.parts?.last?.upperBound ?? 0, 120, accuracy: 0.01)
        XCTAssertTrue(pl.parts?.allSatisfy { $0.upperBound - $0.lowerBound <= 59 } ?? false)
        XCTAssertEqual(SocialPost.plan(p("stories"), seconds: 100, bytes: 50_000_000, size: CGSize(width: 1080, height: 1920)).parts?.count, 2)
        // A tall short clip for Shorts: nothing to change, and it says so.
        pl = SocialPost.plan(p("shorts"), seconds: 20, bytes: 9_000_000, size: CGSize(width: 1080, height: 1920))
        XCTAssertTrue(pl.nothingToChange); XCTAssertEqual(pl.steps.count, 1)
        // YouTube takes sideways as it is.
        XCTAssertFalse(SocialPost.plan(p("youtube"), seconds: 900, bytes: 900_000_000, size: CGSize(width: 1920, height: 1080)).makeTall)
        // Every platform has a link and a store page; ids are unique.
        XCTAssertEqual(Set(SocialPost.platforms.map(\.id)).count, SocialPost.platforms.count)
        for x in SocialPost.platforms { XCTAssertNotNil(URL(string: x.app), x.id); XCTAssertNotNil(URL(string: x.store), x.id) }
    }

    func testCaptionAndLinks() {
        XCTAssertEqual(SocialPost.caption("Beach day", for: p("tiktok")), "Beach day\n\n#fyp #foryou")
        XCTAssertEqual(SocialPost.caption("Beach day #FYP", for: p("tiktok")), "Beach day #FYP\n\n#foryou", "a tag already there isn't added twice")
        XCTAssertEqual(SocialPost.caption("", for: p("shorts")), "#shorts")
        XCTAssertEqual(SocialPost.caption("Hi", for: p("youtube")), "Hi")
        XCTAssertEqual(SocialPost.openURL(p("reels"), assetID: "ABC/L0/001")?.absoluteString, "instagram://library?LocalIdentifier=ABC/L0/001")
        XCTAssertEqual(SocialPost.openURL(p("tiktok"), assetID: "x")?.absoluteString, "tiktok://")
    }

    func testTallLayoutKeepsTheWholePicture() {
        let l = SocialPost.tallLayout(CGSize(width: 1920, height: 1080))
        XCTAssertEqual(l.out, CGSize(width: 1080, height: 1920))
        XCTAssertEqual(l.fit.width, 1080, accuracy: 0.5); XCTAssertEqual(l.fit.midY, 960, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(l.fill.width, 1080); XCTAssertGreaterThanOrEqual(l.fill.height, 1920)
        let small = SocialPost.tallLayout(CGSize(width: 640, height: 360))
        XCTAssertEqual(small.out.width / small.out.height, 9.0 / 16.0, accuracy: 0.01)
    }

    /// A real sideways clip made ready for Reels: tall, same length.
    func testARealClipBecomesTall() async throws {
        let made = await SampleAssets.movie(seconds: 2, size: CGSize(width: 640, height: 360))
        let src = try XCTUnwrap(made)
        let out = await SocialPost.prepare(src, for: p("reels"))
        XCTAssertEqual(out.count, 1)
        let u = try XCTUnwrap(out.first)
        let f = await VideoFacts.read(u)
        let facts = try XCTUnwrap(f)
        XCTAssertTrue(facts.isTall, "\(facts.size)")
        XCTAssertEqual(facts.seconds, 2, accuracy: 0.3)
    }
}
