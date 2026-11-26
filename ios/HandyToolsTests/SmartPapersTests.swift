import XCTest
import PDFKit
@testable import HandyTools

/// Paper into PDFs (26 Nov): which photos are paper, which pages belong together, what each PDF is called, and that
/// the PDF really is searchable — its words found in the file, not just in the picture.
final class SmartPapersTests: XCTestCase {
    private func seen(_ text: String, labels: [String] = ["document"], shot: Bool = false) -> PhotoFinder.Seen {
        PhotoFinder.Seen(modified: 0, labels: labels, text: text, faces: 0, codes: 0, screenshot: shot)
    }
    private let letter = """
    Maple Grove Properties LLC
    218 Cedar Lane, Naperville IL 60540
    November 3, 2026
    Dear Jordan,
    NOTICE OF RENT INCREASE
    This letter is to let you know that from January 1, 2027 the monthly rent for your apartment will change from
    $1,850 to $1,925. All other terms of your lease agreement stay the same. Please contact our office with any
    questions about this notice or your account. We appreciate you as a tenant and look forward to another year.
    Sincerely, the Maple Grove team
    """

    func testLettersAreKeptButReceiptsCardsAndScreenshotsAreLeftToTheirOwnAutoruns() {
        XCTAssertTrue(SmartPapers.isPaper(seen(letter)))
        XCTAssertFalse(SmartPapers.isPaper(seen(letter, shot: true)), "a screenshot isn't paper")
        let receipt = "CORNER MARKET\nMilk 4.29\nBread 5.49\nSUBTOTAL 11.64\nTAX 0.73\nTOTAL 12.37\nVISA ****4821\nTHANK YOU FOR SHOPPING"
        XCTAssertFalse(SmartPapers.isPaper(seen(receipt, labels: ["receipt"])), "receipts go to the receipts autorun")
        let card = "Priya Raman\nDirector of Sales\nNorthwind Analytics LLC\n+1 (630) 555-0142\npriya.raman@northwind-analytics.com\nwww.northwind-analytics.com"
        XCTAssertFalse(SmartPapers.isPaper(seen(card, labels: ["business card"])), "cards go to the business cards autorun")
        XCTAssertFalse(SmartPapers.isPaper(seen("lol see you at 6", labels: [])), "a photo with a few words isn't a document")
        let lastPage = "4. Utilities. The Tenant pays electricity and internet. 5. Pets. One cat is allowed with written consent. Signed by the Landlord and the Tenant on the date above."
        XCTAssertFalse(SmartPapers.isPaper(seen(lastPage, labels: [])), "on its own, a short page isn't enough")
        XCTAssertTrue(SmartPapers.isPaper(seen(lastPage, labels: []), afterAPage: true), "moments after a page, it's that letter's last page")
        XCTAssertFalse(SmartPapers.isPaper(seen("lol see you at 6", labels: []), afterAPage: true), "but a photo of a few words never is")
    }

    func testTheNameComesFromWhatThePageIsNeverTheAddressDateOrGreeting() {
        XCTAssertEqual(SmartPapers.title(letter), "Notice of Rent Increase")
        XCTAssertEqual(SmartPapers.title("RESIDENTIAL LEASE AGREEMENT\nThis Lease Agreement is made on November 26, 2026 between"), "Residential Lease Agreement")
        XCTAssertEqual(SmartPapers.title("Riverside Elementary School\nField Trip Permission Form\nStudent name ____"), "Field Trip Permission Form")
        XCTAssertEqual(SmartPapers.title("Quarterly Planning Notes\nWe agreed to move the launch"), "Quarterly Planning Notes", "no kind word: the first heading-like line")
        XCTAssertEqual(SmartPapers.title("12/04/2026\n$ 45.00\n555-123-4567"), "", "nothing usable: the caller names it Document")
    }

    func testPagesTakenTogetherAreOneDocument() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        let pages: [(id: String, taken: Date, text: String)] = [
            ("a1", t, "Lease page 1 of 2"), ("a2", t.addingTimeInterval(25), "Page 2 of 2"),
            ("b1", t.addingTimeInterval(60), "Page 1 of 1 — permission form"),        // a new first page, even seconds later
            ("c1", t.addingTimeInterval(1800), "A letter photographed half an hour later"),
            ("c2", t.addingTimeInterval(1900), "its second page"),
        ]
        XCTAssertEqual(SmartPapers.group(pages), [["a1", "a2"], ["b1"], ["c1", "c2"]])
        XCTAssertEqual(SmartPapers.group(pages.reversed()), [["a1", "a2"], ["b1"], ["c1", "c2"]], "in the order they were taken, whatever order they come in")
    }

    func testFileNamesAreSafeForFiles() {
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        let d = DateFormatter.posixDay.string(from: day)
        XCTAssertEqual(SmartPapers.fileName("Invoice 12/04: \"final\"", day), "Invoice 12 04 final \(d).pdf")
        XCTAssertTrue(SmartPapers.fileName("", day).hasSuffix(" \(d).pdf"))
    }

    /// The real thing on a drawn page photographed on a desk: one page, flattened, and its words in the PDF's text layer.
    func testThePDFIsSearchable() throws {
        let lines = ["RESIDENTIAL LEASE AGREEMENT", "", "This Lease Agreement is made on November 26, 2026 between",
                     "Maple Grove Properties LLC and Jordan Ellis for the apartment", "at 218 Cedar Lane, Unit 4B, Naperville, Illinois.",
                     "The monthly rent is $1,850, due on the first day of each month.", "A security deposit of $1,850 is held by the Landlord."]
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 1400, height: 1900), format: f).image { ctx in
            UIColor(red: 0.42, green: 0.36, blue: 0.30, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1400, height: 1900))
            UIColor(white: 0.96, alpha: 1).setFill(); ctx.fill(CGRect(x: 120, y: 110, width: 1160, height: 1640))
            for (i, t) in lines.enumerated() {
                (t as NSString).draw(at: CGPoint(x: i == 0 ? 330 : 190, y: 200 + CGFloat(i) * 92),
                                     withAttributes: [.font: UIFont.systemFont(ofSize: i == 0 ? 50 : 34, weight: i == 0 ? .bold : .regular), .foregroundColor: UIColor(white: 0.1, alpha: 1)])
            }
        }
        let (data, text, words) = try XCTUnwrap(SmartPapers.build([photo, photo]))
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(pdf.pageCount, 2)
        let found = pdf.string ?? ""
        XCTAssertTrue(found.localizedCaseInsensitiveContains("security deposit"), "the words aren't searchable: \(found.prefix(200))")
        XCTAssertFalse(pdf.findString("Naperville", withOptions: .caseInsensitive).isEmpty, "find doesn't land on the word")
        XCTAssertEqual(SmartPapers.title(text), "Residential Lease Agreement")
        XCTAssertGreaterThan(words, 60)
        // The page was found and the desk cut away: the page is taller than wide, like the paper (1160 x 1640).
        let box = try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(box.height / box.width, 1640.0 / 1160.0, accuracy: 0.06, "the desk around the page was kept")
    }
}
