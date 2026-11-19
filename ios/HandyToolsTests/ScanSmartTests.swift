import XCTest
@testable import HandyTools

final class ScanSmartTests: XCTestCase {
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 19))!

    func testABillIsNamedAndItsDueDateAndAmountRead() {
        let text = """
        COMCAST
        Account Number 8499 1234 5678
        Statement Date 11/05/2026
        Amount Due $84.20
        Payment Due Date Dec 3, 2026
        """
        let r = ScanSmart.read(text, now: now)
        XCTAssertEqual(r.kind, .bill)
        XCTAssertEqual(r.from, "Comcast")
        XCTAssertEqual(r.amount, 84.20)
        XCTAssertEqual(r.due.map { Calendar.current.component(.day, from: $0) }, 3)
        XCTAssertTrue(r.name.hasPrefix("Comcast bill"), r.name)
    }

    func testALetterAFormAndAnID() {
        XCTAssertEqual(ScanSmart.read("City of Naperville\nDear resident,\nPlease reply by 12 December.\nYours sincerely", now: now).kind, .letter)
        XCTAssertEqual(ScanSmart.read("Library card application\nName ____________\nSignature ____________", now: now).kind, .form)
        let id = ScanSmart.read("DRIVER'S LICENSE\nDOB 01/02/1985", now: now)
        XCTAssertEqual(id.kind, .id); XCTAssertTrue(id.name.hasPrefix("ID copy"))
    }

    func testFileNamesAreSafe() {
        XCTAssertEqual(ScanSmart.safeFileName("A/B: \"C\""), "A B C")
        XCTAssertEqual(ScanSmart.safeFileName("   "), "Scan")
    }
}

final class SortedTwoRemindersTests: XCTestCase {
    func testThreeDaysBeforeAndAgainOnTheDay() {
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 8))!
        let due = cal.date(from: DateComponents(year: 2026, month: 12, day: 3))!
        var i = SortedLetters.Item(kind: "Bill", title: "Comcast bill", amount: "$84.20", due: due, summary: "", remindDays: 3)
        XCTAssertEqual(SortedLetters.remindAt(i, now: now).map { cal.component(.day, from: $0) }, 30, "3 days before")
        XCTAssertEqual(SortedLetters.onTheDay(i, now: now).map { cal.component(.day, from: $0) }, 3, "and on the day")
        i.alsoOnDay = false
        XCTAssertNil(SortedLetters.onTheDay(i, now: now))
        i.alsoOnDay = nil; i.remindDays = 0
        XCTAssertNil(SortedLetters.onTheDay(i, now: now), "an on-the-day reminder isn't doubled")
    }

    func testMonthsAddUpWhatsDue() {
        let cal = Calendar.current
        let d1 = cal.date(from: DateComponents(year: 2026, month: 12, day: 3))!, d2 = cal.date(from: DateComponents(year: 2026, month: 12, day: 20))!
        let items = [SortedLetters.Item(kind: "Bill", title: "A", amount: "$84.20", due: d1, summary: ""),
                     SortedLetters.Item(kind: "Bill", title: "B", amount: "$15.80", due: d2, summary: ""),
                     SortedLetters.Item(kind: "Bill", title: "C", amount: "$99", due: d2, summary: "", done: true)]
        let m = SortedLetters.months(items)
        XCTAssertEqual(m.count, 1); XCTAssertEqual(m[0].count, 2); XCTAssertEqual(m[0].total, 100, accuracy: 0.001)
    }
}
