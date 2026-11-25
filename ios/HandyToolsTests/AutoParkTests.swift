import XCTest
@testable import HandyTools

/// Save my spot automatically (25 Nov): the rules that decide a drive ended and where the car is, run over recorded
/// situations. "Always accurate": never a red light, never a traffic jam, never a short shuffle in a car park, never a
/// rough fix when a good one exists, and the spot is where you got out (or the garage entrance when underground).
final class AutoParkTests: XCTestCase {
    typealias R = AutoParkRules
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }
    private func fix(_ s: Double, _ lat: Double, _ acc: Double, speed: Double = 0) -> R.Fix {
        R.Fix(lat: lat, lng: -88.1, accuracy: acc, speed: speed, time: at(s))
    }

    // MARK: When is the car parked?

    func testAWalkAfterARealDriveIsParking() {
        // 10 minutes of driving, then out and walking.
        XCTAssertTrue(R.parked(drivingSince: at(0), lastDriving: at(600), motion: .walking, motionSince: at(610), now: at(616)))
        XCTAssertFalse(R.parked(drivingSince: at(0), lastDriving: at(600), motion: .walking, motionSince: at(610), now: at(612)),
                       "a couple of seconds of 'walking' could be a jolt; wait a few steps")
    }

    func testRedLightsAndTrafficJamsAreNeverParking() {
        // Stopped at a light: the motion chip still says driving.
        XCTAssertFalse(R.parked(drivingSince: at(0), lastDriving: at(600), motion: .driving, motionSince: at(560), now: at(650)))
        // A jam: "still" for two minutes, then moving again.
        XCTAssertFalse(R.parked(drivingSince: at(0), lastDriving: at(600), motion: .still, motionSince: at(600), now: at(720)))
        XCTAssertEqual(R.motion(automotive: true, walking: false, running: false, stationary: true, confident: true), .driving,
                       "in a car and stopped is still a drive")
    }

    func testSittingInTheCarThenParkingCountsAfterThreeMinutes() {
        XCTAssertTrue(R.parked(drivingSince: at(0), lastDriving: at(600), motion: .still, motionSince: at(605), now: at(785)))
    }

    func testAShortShuffleIsNotADrive() {
        // Moving the car 60 seconds across a car park, then walking off.
        XCTAssertFalse(R.parked(drivingSince: at(0), lastDriving: at(60), motion: .walking, motionSince: at(70), now: at(90)))
    }

    func testNoDriveNoParking() {
        XCTAssertFalse(R.parked(drivingSince: nil, lastDriving: nil, motion: .walking, motionSince: at(0), now: at(60)))
    }

    func testFastIsACarWhateverTheChipSays() {
        XCTAssertTrue(R.driving(motion: .unknown, speed: 15))
        XCTAssertFalse(R.driving(motion: .walking, speed: 1.4))
        XCTAssertTrue(R.driving(motion: .driving, speed: 0))
    }

    func testUnsureMotionReadingsAreIgnored() {
        XCTAssertEqual(R.motion(automotive: false, walking: true, running: false, stationary: false, confident: false), .unknown)
        XCTAssertEqual(R.motion(automotive: false, walking: true, running: false, stationary: false, confident: true), .walking)
        XCTAssertEqual(R.motion(automotive: false, walking: false, running: false, stationary: true, confident: true), .still)
    }

    // MARK: Where is the car?

    func testTheSpotIsWhereYouGotOut() {
        let stop = at(600)
        let fixes = [fix(540, 41.700, 8, speed: 12),   // still driving, a block away
                     fix(590, 41.7010, 6, speed: 1),   // pulling in
                     fix(598, 41.7012, 5),             // beside the car as you get out
                     fix(625, 41.7020, 5)]             // already walking away
        XCTAssertEqual(R.spot(stop: stop, fixes: fixes)?.lat, 41.7012, "the fix nearest the moment you got out")
    }

    func testARoughFixNeverBeatsAGoodOne() {
        let stop = at(600)
        let fixes = [fix(599, 41.9, 140), fix(601, 41.7012, 9)]
        XCTAssertEqual(R.spot(stop: stop, fixes: fixes)?.lat, 41.7012)
    }

    func testUndergroundGarageUsesTheEntrance() {
        // Good GPS up to the ramp, then only rough fixes under the concrete.
        let stop = at(600)
        let fixes = [fix(520, 41.6990, 7, speed: 4), fix(540, 41.7000, 9, speed: 2),   // the entrance
                     fix(590, 41.7300, 160), fix(605, 41.7400, 300)]
        XCTAssertEqual(R.spot(stop: stop, fixes: fixes)?.lat, 41.7000)
    }

    func testNothingGoodEnoughMeansKeepListening() {
        let stop = at(600)
        XCTAssertNil(R.spot(stop: stop, fixes: [fix(600, 41.8, 900)]), "never pin a place 900 m out")
        XCTAssertNil(R.spot(stop: stop, fixes: [fix(100, 41.7, 5)]), "a good fix from eight minutes before is not this spot")
    }

    func testOnlyTheLastFiveMinutesAreKept() {
        let kept = R.trim([fix(0, 1, 5), fix(500, 2, 5), fix(700, 3, 5)], now: at(800))
        XCTAssertEqual(kept.map(\.lat), [2, 3])
    }
}
