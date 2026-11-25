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

    // MARK: How far was the drive? (drives into the mileage log)

    func testADrivesLengthFollowsItsFixes() {
        // Due north along a road, a fix every 100 m for 5 km (lat step ≈ 100 m).
        let step = 100.0 / 111_195
        let route = (0...50).map { i in R.Fix(lat: 41.7 + Double(i) * step, lng: -88.1, accuracy: 8, speed: 14, time: at(Double(i) * 7)) }
        XCTAssertEqual(R.driveMetres(route), 5000, accuracy: 25)
    }

    func testRoughFixesAndGlitchesAddNoMiles() {
        let step = 100.0 / 111_195
        var route = (0...20).map { i in R.Fix(lat: 41.7 + Double(i) * step, lng: -88.1, accuracy: 8, speed: 14, time: at(Double(i) * 7)) }
        route.insert(R.Fix(lat: 42.5, lng: -88.1, accuracy: 9, speed: 14, time: at(70.5)), at: 11)   // a jump of 85 km in half a second
        route.append(R.Fix(lat: 41.9, lng: -88.1, accuracy: 900, speed: 0, time: at(150)))           // a cell-tower guess
        XCTAssertEqual(R.driveMetres(route), 2000, accuracy: 20)
    }

    func testTheStretchBeforeGPSCountsOnlyBeyondItsUncertainty() {
        // A rough fix (300 m) 2 km before GPS turned up, then 1 km of precise fixes.
        let step = 100.0 / 111_195
        let rough = R.Fix(lat: 41.7 - 20 * step, lng: -88.1, accuracy: 300, speed: 0, time: at(0))
        let precise = (0...10).map { i in R.Fix(lat: 41.7 + Double(i) * step, lng: -88.1, accuracy: 8, speed: 14, time: at(120 + Double(i) * 7)) }
        XCTAssertEqual(R.driveMetres([rough] + precise), 1000 + 2000 - 300, accuracy: 20, "never more than the road could have been")
    }

    func testDrivesKeptAndWaiting() {
        let now = at(100 * 86_400)
        func d(_ endDaysAgo: Double, m: Double, reviewed: Bool = false) -> DriveStore.Drive {
            DriveStore.Drive(start: now.addingTimeInterval(-endDaysAgo * 86_400 - 600), end: now.addingTimeInterval(-endDaysAgo * 86_400),
                             fromLat: 0, fromLng: 0, toLat: 0, toLng: 0, metres: m, reviewed: reviewed)
        }
        let kept = DriveStore.kept([d(1, m: 5000), d(70, m: 5000), d(2, m: 90)], now: now)
        XCTAssertEqual(kept.count, 1, "older than 60 days and shorter than a tenth of a mile are dropped")
        let w = DriveStore.waiting([d(0.2, m: 5000), d(0.1, m: 3000, reviewed: true), d(3, m: 4000)], in: DateInterval(start: now.addingTimeInterval(-86_400), end: now))
        XCTAssertEqual(w.map(\.metres), [5000], "only today's, and never one already looked at")
        XCTAssertEqual(DriveStore.Drive(start: now, end: now, fromLat: 0, fromLng: 0, toLat: 0, toLng: 0, metres: 6760).miles, 4.2)
    }

    func testOnlyTheLastFiveMinutesAreKept() {
        let kept = R.trim([fix(0, 1, 5), fix(500, 2, 5), fix(700, 3, 5)], now: at(800))
        XCTAssertEqual(kept.map(\.lat), [2, 3])
    }
}
