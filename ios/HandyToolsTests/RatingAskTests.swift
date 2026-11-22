import XCTest
@testable import HandyTools

/// The rating ask comes only at a happy moment, and never nags.
final class RatingAskTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testNeverOnTheFirstFewResults() {
        XCTAssertFalse(RatingAsk.shouldAsk(wins: 1, firstSeen: start, lastAsked: nil, now: start.addingTimeInterval(10 * day)))
        XCTAssertFalse(RatingAsk.shouldAsk(wins: 2, firstSeen: start, lastAsked: nil, now: start.addingTimeInterval(10 * day)))
    }

    func testNeverOnTheFirstDay() {
        XCTAssertFalse(RatingAsk.shouldAsk(wins: 9, firstSeen: start, lastAsked: nil, now: start.addingTimeInterval(3600)))
    }

    func testAsksAfterAFewKeptResultsOverTwoDays() {
        XCTAssertTrue(RatingAsk.shouldAsk(wins: 3, firstSeen: start, lastAsked: nil, now: start.addingTimeInterval(2 * day)))
    }

    func testNotAgainForTwoMonths() {
        let asked = start.addingTimeInterval(3 * day)
        XCTAssertFalse(RatingAsk.shouldAsk(wins: 10, firstSeen: start, lastAsked: asked, now: asked.addingTimeInterval(30 * day)))
        XCTAssertTrue(RatingAsk.shouldAsk(wins: 10, firstSeen: start, lastAsked: asked, now: asked.addingTimeInterval(61 * day)))
    }
}
