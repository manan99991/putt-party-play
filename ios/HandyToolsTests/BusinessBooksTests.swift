import XCTest
import PDFKit
@testable import HandyTools

/// Business Miles and Price List (24 Nov). The rate is the IRS's published one, round trips count both ways, the
/// month and year add up by purpose, the spreadsheet opens cleanly (commas and quotes in a place name survive), and the
/// price list PDF holds every item.
final class BusinessBooksTests: XCTestCase {
    private let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    private func day(_ s: String) -> Date { ISO8601DateFormatter().date(from: s + "T12:00:00Z")! }

    func testIRSRates() {
        XCTAssertEqual(Mileage.rate(.business, year: 2026).rate, 0.725)
        XCTAssertEqual(Mileage.rate(.medical, year: 2026).rate, 0.205)
        XCTAssertEqual(Mileage.rate(.charity, year: 2026).rate, 0.14)
        XCTAssertEqual(Mileage.rate(.business, year: 2025).rate, 0.70)
        let later = Mileage.rate(.business, year: 2027)
        XCTAssertEqual(later.year, 2026, "a year we don't know yet uses the newest published rate, and says which year")
    }

    func testTotalsByMonthYearAndPurpose() {
        let trips = [
            Mileage.Trip(date: day("2026-11-03"), from: "Shop", to: "Client", why: "Repair", miles: 10, roundTrip: true),
            Mileage.Trip(date: day("2026-11-20"), from: "Shop", to: "Supplier", why: "Parts", miles: 7.25),
            Mileage.Trip(date: day("2026-10-02"), from: "Home", to: "Clinic", why: "", miles: 5, purpose: .medical),
            Mileage.Trip(date: day("2025-12-30"), from: "Shop", to: "Client", why: "Old year", miles: 100),
        ]
        let nov = Mileage.totals(trips, in: .month, of: day("2026-11-24"), cal: cal)
        XCTAssertEqual(nov.trips, 2)
        XCTAssertEqual(nov.total, 27.3, accuracy: 0.001, "20 (round trip) + 7.25 → 27.3")
        let yr = Mileage.totals(trips, in: .year, of: day("2026-11-24"), cal: cal)
        XCTAssertEqual(yr.trips, 3)
        XCTAssertEqual(yr.miles[.medical], 5)
        XCTAssertEqual(yr.estimate, 0.725 * 20 + 0.725 * 7.3 + 0.205 * 5, accuracy: 0.02)
    }

    func testUsualTripsComeFirst() {
        let a = Mileage.Trip(date: day("2026-11-01"), from: "Shop", to: "Client A", why: "Visit", miles: 4)
        var b = a; b.id = UUID(); b.date = day("2026-11-05")
        let c = Mileage.Trip(date: day("2026-11-10"), from: "Shop", to: "Bank", why: "Deposit", miles: 2)
        let u = Mileage.usual([c, b, a])
        XCTAssertEqual(u.first?.to, "Client A", "the trip made twice leads")
        XCTAssertEqual(u.count, 2, "the same trip is offered once")
    }

    func testSpreadsheetOpensCleanly() {
        let trips = [
            Mileage.Trip(date: day("2026-11-03"), from: "Shop", to: "Lee, Jordan \"JJ\"", why: "Faucet, kitchen", miles: 12.4, roundTrip: true),
            Mileage.Trip(date: day("2026-11-01"), from: "Shop", to: "Bank", why: "Deposit", miles: 2),
        ]
        let csv = Mileage.csv(trips)
        let rows = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(rows.count, 4, "header, two drives, total")
        XCTAssertTrue(rows[0].hasPrefix("Date,From,To,Purpose"))
        XCTAssertTrue(rows[1].hasPrefix("2026-11-01"), "oldest first")
        XCTAssertTrue(rows[2].contains("\"Lee, Jordan \"\"JJ\"\"\""), "a comma or quote in a name is escaped: \(rows[2])")
        XCTAssertTrue(rows[2].contains(",24.8,"), "a round trip counts both ways: \(rows[2])")
        XCTAssertTrue(rows[3].hasPrefix("Total"))
        XCTAssertTrue(rows[3].contains("26.8"), "the miles add up: \(rows[3])")
    }

    func testPriceListPDFHoldsEveryItem() throws {
        let items = [PriceList.Item(name: "Faucet repair", price: 120, unit: "each"),
                     PriceList.Item(name: "Labour", price: 85, unit: "per hour"),
                     PriceList.Item(name: "   ", price: 5)]
        let data = PriceList.pdf(items, from: "Rivera Home Repair", currency: "USD", note: "Valid until March", locale: Locale(identifier: "en_US"))
        let doc = try XCTUnwrap(PDFDocument(data: data))
        let text = doc.string ?? ""
        for want in ["PRICE LIST", "Rivera Home Repair", "Faucet repair (each)", "$120.00", "Labour (per hour)", "$85.00", "Valid until March"] {
            XCTAssertTrue(text.contains(want), "the PDF is missing \(want)")
        }
        XCTAssertFalse(text.contains("$5.00"), "a blank item is left out")
        let many = (1...80).map { PriceList.Item(name: "Item \($0)", price: Double($0)) }
        XCTAssertGreaterThan(PDFDocument(data: PriceList.pdf(many, from: "", currency: "USD"))?.pageCount ?? 0, 1, "a long list runs onto more pages")
    }
}
