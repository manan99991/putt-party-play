import XCTest
@testable import HandyTools

/// Smart autoruns (25 Nov): when they come back, what they look at, what they pick, and the bar a smaller video must
/// clear. The parts that read the phone are proven on real files in the UI suite.
final class SmartRunsTests: XCTestCase {
    typealias S = SmartRuns
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Chicago")!; return c }
    private func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h, minute: m))! }

    func testTwiceADayIsTwelveHoursApart() {
        var p = S.Plan(on: true, twice: true, hour: 20, minute: 30)
        XCTAssertEqual(p.times.map { "\($0.hour):\($0.minute)" }, ["8:30", "20:30"])
        p.twice = false
        XCTAssertEqual(p.times.count, 1)
    }

    func testItComesBackAtTheNextChosenTime() {
        let p = S.Plan(on: true, twice: true, hour: 8)
        XCTAssertEqual(S.nextDue(p, after: at(25, 9), cal: cal), at(25, 20))
        XCTAssertEqual(S.nextDue(p, after: at(25, 21), cal: cal), at(26, 8))
        XCTAssertNil(S.nextDue(S.Plan(on: false), after: at(25, 9), cal: cal), "an autorun that's off never comes back")
    }

    func testDueOnlyOncePerChosenTime() {
        let p = S.Plan(on: true, hour: 20)
        XCTAssertFalse(S.isDue(p, lastRun: nil, now: at(25, 19), cal: cal), "not before the time")
        XCTAssertTrue(S.isDue(p, lastRun: nil, now: at(25, 20, 5), cal: cal))
        XCTAssertFalse(S.isDue(p, lastRun: at(25, 20, 6), now: at(25, 23), cal: cal), "already ran tonight")
        XCTAssertTrue(S.isDue(p, lastRun: at(25, 20, 6), now: at(26, 20, 1), cal: cal), "tomorrow night again")
    }

    func testItLooksAtWhatsNewButNeverAWeekAtOnce() {
        let now = at(25, 20)
        XCTAssertEqual(S.window(lastRun: nil, now: now).duration, 24 * 3600, accuracy: 1, "first run: the last 24 hours")
        XCTAssertEqual(S.window(lastRun: at(25, 8), now: now).start, at(25, 8), "since the last run")
        XCTAssertEqual(S.window(lastRun: at(18, 8), now: now).duration, 36 * 3600, accuracy: 1, "a phone in a drawer for a week")
    }

    private func video(_ id: String, mb: Double, seconds: Double, minute: Int = 0) -> S.Found {
        S.Found(id: id, created: at(25, 12, minute), isVideo: true, bytes: Int(mb * 1_000_000), seconds: seconds, width: 1920, height: 1080)
    }

    func testOnlyHeavyVideosAreResaved() {
        let picks = S.heavy([video("small", mb: 8, seconds: 30), video("long", mb: 180, seconds: 240), video("dense", mb: 40, seconds: 50)])
        XCTAssertEqual(picks.map(\.id), ["long", "dense"], "biggest first; a light clip is left alone")
    }

    func testASmallerVideoMustSaveRealSpace() {
        XCTAssertTrue(S.worthIt(original: 200_000_000, smaller: 90_000_000))
        XCTAssertFalse(S.worthIt(original: 200_000_000, smaller: 185_000_000), "8% isn't worth replacing the original")
        XCTAssertFalse(S.worthIt(original: 30_000_000, smaller: 25_000_000), "5 MB isn't worth it")
        XCTAssertFalse(S.worthIt(original: 30_000_000, smaller: 0))
    }

    func testTheSamePictureBar() {
        let a = (0..<10_000).map { UInt8($0 % 256) }
        XCTAssertEqual(S.psnr(a, a), 99)
        let near = a.map { $0 < 255 ? $0 + 1 : $0 }                       // every pixel off by one shade
        XCTAssertGreaterThan(S.psnr(a, near), S.samePictureDB)
        let soft = a.enumerated().map { i, v in UInt8(clamping: Int(v) + (i % 2 == 0 ? 12 : -12)) }   // visible noise
        XCTAssertLessThan(S.psnr(a, soft), S.samePictureDB)
        XCTAssertEqual(S.psnr(a, Array(a.prefix(10))), 0, "different sizes never pass")
    }

    private func photo(_ id: String, _ second: Double, faces: Int = 1, labels: [String] = [], sharp: Double = 0.9, shot: Bool = false, text: String = "") -> S.Found {
        S.Found(id: id, created: at(25, 9).addingTimeInterval(second), isScreenshot: shot,
                seen: S.PhotoSeen(labels: labels, text: text, faces: faces, sharpness: sharp))
    }

    func testTheCollageKeepsOnePerMomentAndOnlyPeople() {
        let picks = S.collagePicks([
            photo("burst1", 0, sharp: 0.6), photo("burst2", 1, sharp: 0.95), photo("burst3", 2, sharp: 0.7),   // one moment
            photo("later", 600),
            photo("blurry", 900, sharp: 0.1),
            photo("screenshot", 1200, shot: true),
            photo("receipt", 1500, faces: 0, labels: ["document"], text: "total tax visa thank you"),
            photo("menu with a face", 1800, text: String(repeating: "word ", count: 40)),
        ])
        XCTAssertEqual(picks.map(\.id), ["burst2", "later"])
    }

    func testTheCollageFavoursLittleOnesAndSpreadsAcrossTheDay() {
        var items: [S.Found] = []
        for i in 0..<20 { items.append(photo("grownup\(i)", Double(i) * 1800)) }
        for i in 0..<4 { items.append(photo("baby\(i)", Double(i) * 7200 + 60, labels: ["baby"])) }
        let picks = S.collagePicks(items, limit: 10)
        XCTAssertEqual(picks.count, 10)
        XCTAssertEqual(picks.filter { $0.id.hasPrefix("baby") }.count, 4, "every baby photo makes it in")
        let hours = Set(picks.map { cal.component(.hour, from: $0.created) })
        XCTAssertGreaterThanOrEqual(hours.count, 6, "spread across the day, not the first hour")
        XCTAssertEqual(picks.map(\.created), picks.map(\.created).sorted(), "in the order they were taken")
    }

    func testPostPicksAreRealClipsNewestFirst() {
        let picks = S.postPicks([video("tiny", mb: 1, seconds: 2, minute: 1), video("good", mb: 40, seconds: 25, minute: 5),
                                 video("long", mb: 900, seconds: 1200, minute: 9), video("newest", mb: 30, seconds: 15, minute: 30)])
        XCTAssertEqual(picks.map(\.id), ["newest", "good"])
    }

    func testSharpClipsRankAboveBlurryOnes() {
        let w = 40, h = 30
        let flat = Stitcher.Gray(rows: h, width: w, px: Array(repeating: 128, count: w * h))
        let edges = Stitcher.Gray(rows: h, width: w, px: (0..<(w * h)).map { i in ((i % w) / 4 + (i / w) / 4) % 2 == 0 ? 20 : 235 })
        let soft = Stitcher.Gray(rows: h, width: w, px: (0..<(w * h)).map { i in UInt8(100 + (i % w)) })
        XCTAssertEqual(SmartPosts.sharpness(flat), 0, accuracy: 0.001)
        XCTAssertGreaterThan(SmartPosts.sharpness(edges), SmartPosts.sharpness(soft) * 100, "crisp edges score far above a gentle gradient")
    }

    func testHabitsSuggestTheRightAutorun() {
        // Receipts on 4 separate days; video shrink twice; lots of baby photos on the phone.
        let days: [String: Set<Int>] = ["receipts": [1, 3], "scan": [5, 8], "videoshrink": [2, 2, 9]]
        let s = S.suggested(toolDays: days, found: [.dayCollage: 45, .businessCards: 1], on: [], hidden: [])
        XCTAssertEqual(s.first, .dayCollage)
        XCTAssertTrue(s.contains(.receipts))
        XCTAssertFalse(s.contains(.heavyVideos), "two days isn't a habit")
        XCTAssertFalse(s.contains(.businessCards))
        XCTAssertFalse(S.suggested(toolDays: days, found: [.dayCollage: 45], on: [.dayCollage], hidden: [.receipts]).contains(.receipts),
                       "one put off is never offered again")
    }
}
