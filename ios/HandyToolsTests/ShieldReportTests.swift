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

final class StrongPasswordTests: XCTestCase {
    func testPasswordsAreWordsAndDigitsAndDiffer() {
        let a = PDFProtectView.strongPassword(), b = PDFProtectView.strongPassword()
        XCTAssertEqual(a.split(separator: "-").count, 4)
        XCTAssertEqual(a.split(separator: "-").last?.count, 4)
        XCTAssertNotEqual(a, b)
        XCTAssertGreaterThanOrEqual(Set(PDFProtectView.words).count, 64, "64 words × 3 + 4 digits ≈ 31 bits of words + 13 of digits")
    }
}
