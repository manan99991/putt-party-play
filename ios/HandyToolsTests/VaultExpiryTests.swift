import XCTest
@testable import HandyTools

final class VaultExpiryTests: XCTestCase {
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 19))!

    func testPassportExpiryIsReadFromTheLabelledLine() {
        let text = "PASSPORT\nUNITED STATES OF AMERICA\nDate of birth 14 Jan 1986\nDate of issue 03 Mar 2021\nDate of expiry\n02 Mar 2031"
        let r = VaultExpiry.read(text, now: now)
        XCTAssertEqual(r.name, "Passport")
        let c = r.expires.map { Calendar.current.dateComponents([.year, .month, .day], from: $0) }
        XCTAssertEqual(c?.year, 2031); XCTAssertEqual(c?.month, 3); XCTAssertEqual(c?.day, 2)
    }

    func testCardMonthYearMeansTheEndOfThatMonth() {
        let d = VaultExpiry.monthYear("EXP 08/29")
        let c = d.map { Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: $0) }
        XCTAssertEqual(c?.year, 2029); XCTAssertEqual(c?.month, 8); XCTAssertEqual(c?.day, 31)
    }

    func testRemindersSixMonthsAndOneMonthBeforeOnlyWhileAhead() {
        let exp = Calendar.current.date(from: DateComponents(year: 2027, month: 6, day: 1))!
        XCTAssertEqual(VaultExpiry.reminders(for: exp, now: now).map(\.months), [6, 1])
        let soon = Calendar.current.date(from: DateComponents(year: 2027, month: 2, day: 1))!
        XCTAssertEqual(VaultExpiry.reminders(for: soon, now: now).map(\.months), [1], "the 6-month moment already passed")
    }
}
