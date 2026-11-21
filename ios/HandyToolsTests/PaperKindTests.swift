import XCTest
@testable import HandyTools

/// "What is this?" on writing named receipts as bills, rota boards as menus, a price-per-line menu as a list and an
/// event poster as a business card (real-photo score 31%, 20 Nov). Each case below has the same shape as one of
/// those photos, in made-up words, and must come back as the right kind.
final class PaperKindTests: XCTestCase {
    private func lines(_ texts: [String]) -> [DocEngine.OCRLine] {
        texts.enumerated().map { i, t in
            DocEngine.OCRLine(text: t, box: CGRect(x: 0.05, y: 0.03 + Double(i) * 0.04, width: min(0.9, 0.04 * Double(t.count) + 0.1), height: 0.03))
        }
    }
    private func kind(_ texts: [String]) -> Paper.Kind? { Paper.classify(lines(texts))?.kind }

    func testReceiptWithBillToAndTotalOnItsOwnLine() {
        let r = Paper.classify(lines(["receipt", "FROM", "Maple Bike Repair", "12 Elm Road", "BILL TO", "4 River Street",
                                      "RECEIPT #", "RECEIPT DATE", "QTY", "DESCRIPTION", "Chain and gears", "Labour 2hrs",
                                      "UNIT PRICE", "80.00", "20.00", "Subtotal", "Sales Tax 6%", "TOTAL", "120.00", "7.20", "$127.20"]))
        XCTAssertEqual(r?.kind, .receipt)
        XCTAssertTrue(r?.gist.contains("127.20") == true, r?.gist ?? "")
    }

    func testBlurryPageThatSaysReceiptTwiceIsStillAReceipt() {
        XCTAssertEqual(kind(["RECEIPT", "Shop name blurred", "Adaess", "RECEIPT", "TOLA", "BALANZE DUE", "$1000", "8000"]), .receipt)
    }

    func testRotaBoardIsAScheduleNotAMenu() {
        XCTAssertEqual(kind(["NAME", "MON", "Sam 512", "Jo 330 -", "TUE", "Kim 440", "Lee 610", "WED", "Pat 220",
                             "THU", "Ana 101", "Job 700", "FRI", "Joe 439-1", "Max 120", "SAT", "SUN"]), .schedule)
    }

    func testMenuWithPricesOnTheirOwnLinesIsAMenu() {
        XCTAssertEqual(kind(["特色篇", "香辣鱼", "50元", "烤虾", "68元", "烤牛蛙", "58元", "烤翅", "55元", "酸菜鱼", "45元", "水煮鱼", "50元"]), .menu)
    }

    func testGardenListWithDearInItIsAList() {
        let k = kind(["GARDEN JOBS", "• fix gate", "• fence lights", "• gutter", "• plant beans", "• water seedlings",
                      "• mulch beds", "• soil test", "• weed peas", "2 dear little lettuces", "• stake tomatoes", "• cut grass"])
        XCTAssertNotEqual(k, .bill)
    }

    func testPosterWithContactDetailsIsAPosterNotACard() {
        XCTAssertEqual(kind(["Book Swap Night", "Bring a book, take a book", "DINNER AND DRINKS", "FRIDAY NOV 14",
                             "6:30PM - 9:00PM", "TICKETS: $10", "TOWN HALL 22 HIGH STREET", "CALL ANA AT 555-0101 OR ANA@EXAMPLE.COM"]), .poster)
        XCTAssertEqual(kind(["UPCOMING", "EVENTS", "Talks and music for everyone.", "WHERE", "THE OLD LIBRARY",
                             "WHEN 7PM • 12 MARCH", "TICKETS WWW.EXAMPLE.COM"]), .poster)
    }

    func testALetterStillReadsAsALetter() {
        XCTAssertEqual(kind(["City Water Services", "Dear Ms Rivera,", "Your statement for March is ready.",
                             "Amount due: 64.20", "Payment due date: 14 April 2026", "Account number 55821"]), .bill)
    }
}

/// The QuickBooks receipt came back with no date: the camera read 08/11/2022 as "0B/11/2022".
final class ReceiptDateOCRTests: XCTestCase {
    func testDateWithALookAlikeLetterIsStillRead() {
        XCTAssertEqual(DataGrab.ocrDigits("0B/11/2022"), "08/11/2022")
        XCTAssertEqual(DataGrab.ocrDigits("Ref BOS-11"), "Ref BOS-11")   // not a date: left alone
        let r = DataGrab.receipt("Maple Bike Repair\nRECEIPT DATE\n0B/11/2022\nTOTAL\n$145.00")
        XCTAssertNotNil(r.date, "no date read from 0B/11/2022")
    }
}
