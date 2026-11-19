import XCTest
@testable import HandyTools

final class ShieldReportTests: XCTestCase {
    func testForwardGoesTo7726WithTheText() throws {
        let u = try XCTUnwrap(ShieldView.forwardURL("USPS: your parcel is held. Pay $1.99 at usps-redeliver.top"))
        XCTAssertTrue(u.absoluteString.hasPrefix("sms:7726&body="))
        XCTAssertTrue(u.absoluteString.contains("usps-redeliver.top"))
    }
    func testOfficialPlacesByCountry() {
        XCTAssertEqual(ShieldView.officialReport("US")?.name, "the FTC")
        XCTAssertEqual(ShieldView.officialReport("GB")?.name, "Action Fraud")
        XCTAssertNil(ShieldView.officialReport("ZZ"))
    }
    func testFamilyWarningQuotesItAndSaysHowToSpotIt() {
        let w = ShieldView.warning("Your bank account is locked, verify at bit.ly/x", findings: ["Shortened link", "Urgent pressure"])
        XCTAssertTrue(w.contains("bank account is locked")); XCTAssertTrue(w.contains("Shortened link")); XCTAssertTrue(w.contains("don't tap"))
    }
}
