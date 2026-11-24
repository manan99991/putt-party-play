import XCTest
@testable import HandyTools

/// "What if they want a reminder tool, can't they make it from here?" (Manan, 23 Nov). A reminder the person writes
/// becomes exactly the reminders the phone holds: once, every day, or on the days picked, opening the tool they chose.
final class OwnRemindersTests: XCTestCase {
    private let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    private func date(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }

    func testOnceIsLaterTodayOrTomorrow() {
        let now = date("2026-11-23T10:00:00Z")
        XCTAssertEqual(OwnReminders.next(hour: 18, minute: 0, after: now, calendar: cal), date("2026-11-23T18:00:00Z"))
        XCTAssertEqual(OwnReminders.next(hour: 9, minute: 30, after: now, calendar: cal), date("2026-11-24T09:30:00Z"))
    }

    func testThePhoneHoldsOneReminderPerTime() {
        let now = date("2026-11-23T10:00:00Z")
        let daily = OwnReminder(text: "Water the plants", schedule: ChainSchedule(hour: 8, minute: 0, days: []))
        let weekdays = OwnReminder(text: "Scan receipts", schedule: ChainSchedule(hour: 18, minute: 0, days: [2, 6]), opens: "scan")
        let once = OwnReminder(text: "Call Mum", schedule: ChainSchedule(hour: 19, minute: 0), once: true, onceAt: date("2026-11-23T19:00:00Z"))
        let past = OwnReminder(text: "Gone", once: true, onceAt: date("2026-11-22T19:00:00Z"))
        let plan = OwnReminders.plan([daily, weekdays, once, past], now: now, calendar: cal)
        XCTAssertEqual(plan.map(\.reminder.text), ["Water the plants", "Scan receipts", "Scan receipts", "Call Mum"], "a one-off that's past is dropped")
        XCTAssertEqual(plan.filter(\.repeats).count, 3)
        XCTAssertEqual(plan[1].when.weekday, 2); XCTAssertEqual(plan[2].when.weekday, 6)
        XCTAssertEqual(plan[3].when.day, 23); XCTAssertEqual(plan[3].when.hour, 19)
        XCTAssertTrue(plan.allSatisfy { $0.id.hasPrefix(OwnReminders.prefix) })
        XCTAssertEqual(OwnReminders.content(weekdays).userInfo["open"] as? String, "scan", "tapping it opens Scan")
        XCTAssertNil(OwnReminders.content(daily).userInfo["open"])
        XCTAssertEqual(AutomationGroups.group(id: plan[0].id).key, "own", "it shows in My stuff as My reminders")
    }

    func testNeverMoreThanTheLimit() {
        let many = (0..<30).map { OwnReminder(text: "R\($0)", schedule: ChainSchedule(hour: 9, minute: 0, days: [2, 3, 4])) }
        XCTAssertEqual(OwnReminders.plan(many).count, OwnReminders.limit)
    }
}
