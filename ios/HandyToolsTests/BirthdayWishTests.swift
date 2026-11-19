import XCTest
@testable import HandyTools

final class BirthdayWishTests: XCTestCase {
    func testWishUsesTheirNameAndTheMilestone() {
        let cal = Calendar.current
        var p = ContactBook.Person(id: "1"); p.given = "Priya"; p.family = "Shah"
        p.phones = [ContactBook.Labeled(label: "home", value: "630 555 0100"), ContactBook.Labeled(label: "mobile", value: "+1 (630) 555-0142")]
        p.birthday = DateComponents(year: 1986, month: 12, day: 4)
        let on = cal.date(from: DateComponents(year: 2026, month: 12, day: 4))!
        XCTAssertTrue(ContactBook.birthdayWish(p, on: on).hasPrefix("Happy 40th birthday, Priya!"))
        p.birthday = DateComponents(month: 12, day: 4)
        XCTAssertEqual(ContactBook.birthdayWish(p, on: on), "Happy birthday, Priya! 🎂 Hope you have a wonderful day.")
        let u = ContactBook.wishURL(p, wish: "Hi")
        XCTAssertEqual(u?.absoluteString, "sms:+16305550142&body=Hi", "goes to the mobile")
        XCTAssertEqual(ContactBook.ordinal(21), "21st"); XCTAssertEqual(ContactBook.ordinal(12), "12th"); XCTAssertEqual(ContactBook.ordinal(33), "33rd")
    }
}
