import XCTest
@testable import HandyTools

/// The photo index works hard only when someone is waiting, and is gentle on the battery otherwise.
final class PhotoIndexPacerTests: XCTestCase {
    func testTheIndexIsGentleUnlessSomeoneIsWaiting() {
        // In Search My Photos: full speed (only a critically hot phone stops it).
        XCTAssertEqual(PhotoIndexPacer.plan(urgent: true, lowPower: true, thermal: .serious, charging: false).restMs, 0)
        XCTAssertTrue(PhotoIndexPacer.plan(urgent: true, lowPower: true, thermal: .serious, charging: false).go)
        XCTAssertFalse(PhotoIndexPacer.plan(urgent: true, lowPower: false, thermal: .critical, charging: true).go)
        // Quietly: stops on Low Power Mode or a warm phone.
        XCTAssertFalse(PhotoIndexPacer.plan(urgent: false, lowPower: true, thermal: .nominal, charging: true).go)
        XCTAssertFalse(PhotoIndexPacer.plan(urgent: false, lowPower: false, thermal: .serious, charging: true).go)
        // Otherwise it rests between photos, longer on battery than on the charger, longer still when a little warm.
        let battery = PhotoIndexPacer.plan(urgent: false, lowPower: false, thermal: .nominal, charging: false)
        let charger = PhotoIndexPacer.plan(urgent: false, lowPower: false, thermal: .nominal, charging: true)
        let warm = PhotoIndexPacer.plan(urgent: false, lowPower: false, thermal: .fair, charging: false)
        XCTAssertTrue(battery.go && charger.go && warm.go)
        XCTAssertGreaterThan(battery.restMs, charger.restMs)
        XCTAssertGreaterThan(warm.restMs, battery.restMs)
    }
}
