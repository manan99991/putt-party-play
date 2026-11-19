import XCTest
@testable import HandyTools

final class MyDetailsTests: XCTestCase {
    func testFieldsAreMatchedByTheirOwnLabels() {
        var me = MyDetails(); me.first = "Jane"; me.last = "Doe"; me.email = "jane@example.com"; me.phone = "630 555 0100"
        me.street = "12 Main St"; me.city = "Naperville"; me.region = "IL"; me.postcode = "60540"; me.country = "USA"; me.birth = "01/14/1986"
        let today = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 19))!
        XCTAssertEqual(me.value(for: "First Name"), "Jane")
        XCTAssertEqual(me.value(for: "Surname"), "Doe")
        XCTAssertEqual(me.value(for: "Applicant_Name"), "Jane Doe")
        XCTAssertEqual(me.value(for: "E-mail address"), "jane@example.com")
        XCTAssertEqual(me.value(for: "Mobile"), "630 555 0100")
        XCTAssertEqual(me.value(for: "Date of birth"), "01/14/1986", "birth before plain date")
        XCTAssertEqual(me.value(for: "ZIP code"), "60540")
        XCTAssertEqual(me.value(for: "Street address"), "12 Main St")
        XCTAssertNotNil(me.value(for: "Date", today: today))
        XCTAssertNil(me.value(for: "Passport expiry date", today: today), "an expiry date is not today")
        XCTAssertNil(me.value(for: "Reason for travel"))
        XCTAssertNil(MyDetails().value(for: "First name"), "nothing saved, nothing filled")
    }
}
