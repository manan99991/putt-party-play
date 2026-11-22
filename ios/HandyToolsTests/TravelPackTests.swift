import XCTest
@testable import HandyTools

/// Vault's travel pack: the right papers are in it by what they are, a choice overrides that, and a passport with
/// under 6 months left is flagged before the trip.
final class TravelPackTests: XCTestCase {
    func testPapersForTravelAreInThePack() {
        XCTAssertTrue(TravelPack.belongs(title: "Passport", expires: nil, chosen: nil))
        XCTAssertTrue(TravelPack.belongs(title: "Travel insurance card", expires: nil, chosen: nil))
        XCTAssertTrue(TravelPack.belongs(title: "Boarding pass LHR", expires: nil, chosen: nil))
        XCTAssertFalse(TravelPack.belongs(title: "Garage code", expires: nil, chosen: nil))
        XCTAssertTrue(TravelPack.belongs(title: "Garage code", expires: nil, chosen: true))
        XCTAssertFalse(TravelPack.belongs(title: "Passport", expires: nil, chosen: false))
    }

    func testPassportUnderSixMonthsIsFlagged() {
        let now = Date()
        let four = Calendar.current.date(byAdding: .month, value: 4, to: now)!
        let two = Calendar.current.date(byAdding: .year, value: 2, to: now)!
        XCTAssertNotNil(TravelPack.warning(title: "Passport", expires: four, now: now))
        XCTAssertNil(TravelPack.warning(title: "Passport", expires: two, now: now))
        XCTAssertNil(TravelPack.warning(title: "Visa", expires: four, now: now))
        XCTAssertNotNil(TravelPack.warning(title: "Visa", expires: Calendar.current.date(byAdding: .day, value: -1, to: now)!, now: now))
    }
}
