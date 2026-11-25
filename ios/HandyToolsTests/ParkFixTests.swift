import XCTest
@testable import HandyTools

/// Manan, 24 Nov: "I parked the car a couple of times and it still showed me an older address." iPhone's first location
/// after it starts looking is often a remembered one; a parking pin must only use a fix taken after saving began.
final class ParkFixTests: XCTestCase {
    private let tapped = Date(timeIntervalSince1970: 1_800_000_000)

    func testTheRememberedOldFixIsNeverUsed() {
        let hourOld = tapped.addingTimeInterval(-3600)
        XCTAssertFalse(ParkFix.ready(fixTime: hourOld, accuracy: 10, since: tapped, now: tapped.addingTimeInterval(1)),
                       "an accurate but hour-old fix is where the phone was, not where the car is")
        XCTAssertFalse(ParkFix.ready(fixTime: hourOld, accuracy: 10, since: tapped, now: tapped.addingTimeInterval(60)),
                       "not even after the 20 s fallback")
        XCTAssertFalse(ParkFix.ready(fixTime: nil, accuracy: 10, since: tapped, now: tapped.addingTimeInterval(30)))
    }

    func testAFreshGoodFixIsUsedAtOnce() {
        XCTAssertTrue(ParkFix.ready(fixTime: tapped.addingTimeInterval(2), accuracy: 30, since: tapped, now: tapped.addingTimeInterval(2)))
        XCTAssertTrue(ParkFix.ready(fixTime: tapped.addingTimeInterval(-1), accuracy: 30, since: tapped, now: tapped),
                      "a fix taken in the same second as the tap counts")
    }

    func testAFreshRoughFixWaitsThenIsUsed() {
        let fix = tapped.addingTimeInterval(5)
        XCTAssertFalse(ParkFix.ready(fixTime: fix, accuracy: 200, since: tapped, now: tapped.addingTimeInterval(5)),
                       "a rough fix waits for a better one")
        XCTAssertTrue(ParkFix.ready(fixTime: tapped.addingTimeInterval(21), accuracy: 200, since: tapped, now: tapped.addingTimeInterval(21)),
                      "after 20 s the freshest fix there is will do")
    }

    func testParkHereButtonNeedsARecentFix() {
        let now = tapped
        XCTAssertTrue(ParkFix.fresh(now.addingTimeInterval(-3), now: now))
        XCTAssertFalse(ParkFix.fresh(now.addingTimeInterval(-600), now: now), "a ten-minute-old fix isn't where you are")
        XCTAssertFalse(ParkFix.fresh(nil, now: now))
    }
}
