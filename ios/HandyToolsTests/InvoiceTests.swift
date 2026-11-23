import XCTest
import PDFKit
@testable import HandyTools

/// Invoices & Quotes (Business tab, 23 Nov): the sums are right to the cent, numbers count up, the free allowance is
/// 3 a month, an unpaid invoice past its day is overdue (and Home says so), and the PDF really holds what was typed.
final class InvoiceTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Chicago")!; return c }
    private let now = Date(timeIntervalSince1970: 1_795_460_400)

    private func doc(_ kind: Invoice.Kind = .invoice, number: String = "INV-0001", date: Date? = nil, due: Date? = nil,
                     lines: [Invoice.Line] = [Invoice.Line(what: "Fix kitchen faucet", qty: 1, price: 120),
                                              Invoice.Line(what: "Replacement cartridge", qty: 2, price: 18.5)],
                     tax: Double = 0, paid: Bool = false) -> Invoice.Doc {
        Invoice.Doc(kind: kind, number: number, date: date ?? now, due: due, from: "Rivera Home Repair", to: "Jordan Lee\n14 Maple Ave",
                    lines: lines, taxPercent: tax, notes: "Thank you", currency: "USD", paid: paid)
    }

    func testTotalsAreRightToTheCent() {
        let d = doc(tax: 8.25)
        XCTAssertEqual(d.subtotal, 157)
        XCTAssertEqual(d.tax, 12.95, "8.25% of 157 is 12.9525, rounded to the cent")
        XCTAssertEqual(d.total, 169.95)
        let hours = doc(lines: [Invoice.Line(what: "Hours", qty: 2.5, price: 40), Invoice.Line(what: "Parts", qty: 3, price: 0.1)])
        XCTAssertEqual(hours.subtotal, 100.3, "half hours and cents add up without drift")
        XCTAssertEqual(Invoice.qty(2.5), "2.5"); XCTAssertEqual(Invoice.qty(3), "3")
    }

    func testNumbersCountUpPerKind() {
        XCTAssertEqual(Invoice.nextNumber(.invoice, after: []), "INV-0001")
        let docs = [doc(number: "INV-0006"), doc(number: "INV-0002"), doc(.quote, number: "Q-0009")]
        XCTAssertEqual(Invoice.nextNumber(.invoice, after: docs), "INV-0007")
        XCTAssertEqual(Invoice.nextNumber(.quote, after: docs), "Q-0010")
    }

    func testThreeFreeAMonthAndProHasNoLimit() {
        let thisMonth = (0..<3).map { doc(number: "INV-000\($0)", date: now.addingTimeInterval(Double(-$0) * 3600)) }
        let lastMonth = doc(number: "INV-0009", date: cal.date(byAdding: .month, value: -1, to: now))
        XCTAssertEqual(Invoice.left([], premium: false, now: now, cal: cal), 3)
        XCTAssertEqual(Invoice.left([lastMonth], premium: false, now: now, cal: cal), 3, "last month's don't count")
        XCTAssertEqual(Invoice.left(Array(thisMonth.prefix(2)), premium: false, now: now, cal: cal), 1)
        XCTAssertEqual(Invoice.left(thisMonth, premium: false, now: now, cal: cal), 0)
        XCTAssertNil(Invoice.left(thisMonth, premium: true, now: now, cal: cal))
        XCTAssertFalse(TOOLS.first { $0.id == "invoice" }!.pro, "open to everyone; the tool counts the allowance itself")
    }

    func testOverdueOnlyForUnpaidInvoicesPastTheirDay() {
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        XCTAssertTrue(doc(due: yesterday).overdue(now: now, cal: cal))
        XCTAssertFalse(doc(due: now).overdue(now: now, cal: cal), "due today isn't overdue yet")
        XCTAssertFalse(doc(due: yesterday, paid: true).overdue(now: now, cal: cal))
        XCTAssertFalse(doc(.quote, due: yesterday).overdue(now: now, cal: cal), "a quote is never overdue")
    }

    func testHomeSaysWhenACustomerHasntPaid() {
        var f = ForYou.Facts(now: now)
        f.invoices = [doc(due: cal.date(byAdding: .day, value: -3, to: now), tax: 0)]
        let c = ForYou.cards(f, cal: cal)
        XCTAssertEqual(c.first?.kind, .invoice)
        XCTAssertEqual(c.first?.title, "Jordan Lee hasn't paid yet")
        XCTAssertEqual(c.first?.action, .open("invoice"))
        f.invoices = [doc(due: cal.date(byAdding: .day, value: -3, to: now), paid: true)]
        XCTAssertEqual(ForYou.cards(f, cal: cal), [], "paid: nothing to say")
    }

    func testThePDFHoldsWhatWasTyped() throws {
        let d = doc(tax: 10)
        let pdf = try XCTUnwrap(PDFDocument(data: Invoice.pdf(d, page: CGSize(width: 612, height: 792), locale: Locale(identifier: "en_US"))))
        let text = pdf.string ?? ""
        for s in ["INVOICE", "INV-0001", "Rivera Home Repair", "Jordan Lee", "Fix kitchen faucet", "Replacement cartridge", "$172.70", "Thank you"] {
            XCTAssertTrue(text.contains(s), "the PDF is missing \"\(s)\". It reads: \(text.prefix(600))")
        }
        XCTAssertEqual(pdf.pageCount, 1)
        let long = doc(lines: (1...60).map { Invoice.Line(what: "Item \($0)", qty: 1, price: 1) })
        let many = try XCTUnwrap(PDFDocument(data: Invoice.pdf(long, page: CGSize(width: 612, height: 792), locale: Locale(identifier: "en_US"))))
        XCTAssertGreaterThan(many.pageCount, 1, "a long list goes on to a second page")
        XCTAssertTrue((many.string ?? "").contains("Item 60"), "the last line isn't lost")
        XCTAssertEqual(Invoice.fileName(d), "Invoice INV-0001.pdf")
    }

    func testPaperFollowsTheRegion() {
        XCTAssertEqual(Invoice.pageSize(region: "US"), CGSize(width: 612, height: 792))
        XCTAssertEqual(Invoice.pageSize(region: "DE"), CGSize(width: 595, height: 842))
    }

    @MainActor func testTheUnpaidListIsKeptAndMarkedPaid() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let s = InvoiceStore(folder: dir)
        s.add(doc(number: "INV-0001", due: now)); s.add(doc(.quote, number: "Q-0001"))
        XCTAssertEqual(s.unpaid.map(\.number), ["INV-0001"], "quotes aren't waiting to be paid")
        s.setPaid(s.unpaid[0].id, true)
        XCTAssertEqual(InvoiceStore(folder: dir).unpaid, [], "marked paid, and it stays that way")
        XCTAssertEqual(InvoiceStore(folder: dir).docs.count, 2)
    }
}
