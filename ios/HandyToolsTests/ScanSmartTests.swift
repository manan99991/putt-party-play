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
