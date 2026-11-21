import XCTest
import EventKit
@testable import HandyTools

/// An event Tenzy adds has to remind you: a return deadline 3 days ahead and on the day, anything else an hour before.
final class EventAlarmsTests: XCTestCase {
    func testReturnDeadlineIsNudgedThreeDaysAheadAndOnTheDay() {
        XCTAssertEqual(EventAlarms.offsets(title: ChainText.returnTitle("Harbor Home Goods")), [-3 * 86_400, 0])
        XCTAssertEqual(EventAlarms.offsets(title: ChainText.returnTitle("")), [-3 * 86_400, 0])
    }
    func testAnEventIsNudgedAnHourBefore() {
        XCTAssertEqual(EventAlarms.offsets(title: "Book Swap Night"), [-3_600])
    }
    func testAlarmsLandOnTheEvent() {
        let e = EKEvent(eventStore: EKEventStore())
        e.title = ChainText.returnTitle("Harbor Home Goods")
        EventAlarms.apply(to: e)
        XCTAssertEqual(e.alarms?.map(\.relativeOffset), [-3 * 86_400, 0])
    }
}
