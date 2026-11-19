import XCTest
import UIKit
@testable import HandyTools

/// The guided "What to do with it", Chinese/Japanese/Korean menus, and receipts read into expenses —
/// each checked on what the person actually gets, with the real examples that went wrong.
final class GuideMenuReceiptTests: XCTestCase {

    // MARK: menu — the user's Chinese menus

    /// The second test menu, as the camera reads it: names and prices as separate pieces in three columns.
    private func box(_ t: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 0.14) -> MenuReader.Box {
        MenuReader.Box(text: t, rect: CGRect(x: x, y: y, width: w, height: 0.025), confidence: 0.9)
    }

    func testChineseMenuReadsDishesPricesAndSections() {
        let boxes: [MenuReader.Box] = [
            box("中式套餐", 0.10, 0.08, 0.12),
            box("黑椒牛肉烩饭", 0.06, 0.13), box("-----18元", 0.22, 0.13, 0.06),
            box("鸡腿饭套餐", 0.06, 0.17), box("--------18元", 0.22, 0.17, 0.07),
            box("糖醋排骨饭", 0.06, 0.21), box("-----15元", 0.22, 0.21, 0.06),
            box("以上套餐配送汤、青菜，米饭吃到饱", 0.06, 0.55, 0.22),
            box("铁板类", 0.40, 0.08, 0.08),
            box("铁板田鸡", 0.33, 0.13, 0.1), box("-----18元", 0.45, 0.13, 0.06),
            box("铁板鱿鱼", 0.33, 0.17, 0.1), box("-----15元", 0.45, 0.17, 0.06),
            box("炒饭、面类", 0.68, 0.08, 0.12),
            box("扬州炒饭", 0.60, 0.13, 0.1), box("------8元", 0.74, 0.13, 0.06),
            box("海鲜炒面", 0.60, 0.17, 0.1), box("- - - - 1 0 元", 0.74, 0.17, 0.07),
            box("剁椒鱼头", 0.60, 0.40, 0.1), box("-----20元", 0.74, 0.40, 0.06),
            box("昵图网 www.nipic.com BY:guilan", 0.05, 0.95, 0.3), box("NO:20100817213856871662", 0.75, 0.95, 0.2),
        ]
        let lines = MenuReader.lines(from: boxes)
        XCTAssertTrue(lines.contains("黑椒牛肉烩饭 -----18元"), "\(lines)")
        let items = MenuReader.parse(lines)
        let dishes = items.filter { !$0.note }
        XCTAssertEqual(dishes.map(\.name), ["黑椒牛肉烩饭", "鸡腿饭套餐", "糖醋排骨饭", "铁板田鸡", "铁板鱿鱼", "扬州炒饭", "海鲜炒面", "剁椒鱼头"])
        XCTAssertEqual(dishes.map(\.price), [18, 18, 15, 18, 15, 8, 10, 20])
        XCTAssertEqual(dishes[0].section, "中式套餐"); XCTAssertEqual(dishes[3].section, "铁板类"); XCTAssertEqual(dishes[5].section, "炒饭、面类")
        XCTAssertTrue(items.contains { $0.note && $0.name.hasPrefix("以上套餐") }, "the set-meal line is a note, not a dish")
        XCTAssertFalse(items.contains { $0.name.contains("nipic") || $0.name.contains("NO:") }, "watermarks are dropped")
        XCTAssertEqual(MenuReader.currency(in: lines), "CNY")
        XCTAssertTrue(MenuReader.needsTranslation(lines, reader: "en-US"))
        XCTAssertFalse(MenuReader.needsTranslation(lines, reader: "zh-Hans"))
    }

    func testChineseDishWordsAndTheirTraps() {
        XCTAssertTrue(MenuReader.flags("黑椒牛肉烩饭").contains(.beef))
        XCTAssertFalse(MenuReader.flags("馋嘴牛蛙").contains(.beef), "牛蛙 is bullfrog")
        XCTAssertTrue(MenuReader.flags("馋嘴牛蛙").contains(.meat))
        XCTAssertFalse(MenuReader.flags("铁板田鸡").contains(.chicken), "田鸡 is frog")
        XCTAssertTrue(MenuReader.flags("铁板鱿鱼").contains(.shellfish)); XCTAssertFalse(MenuReader.flags("铁板鱿鱼").contains(.fish))
        let yuxiang = MenuReader.flags("鱼香肉丝")
        XCTAssertFalse(yuxiang.contains(.fish), "鱼香 sauce has no fish"); XCTAssertTrue(yuxiang.contains(.pork))
        XCTAssertTrue(MenuReader.flags("干煸牛肉丝").contains(.beef)); XCTAssertFalse(MenuReader.flags("干煸牛肉丝").contains(.pork), "牛肉丝 is beef, not pork")
        XCTAssertTrue(MenuReader.flags("夫妻肺片").contains(.beef))
        XCTAssertTrue(MenuReader.flags("皮蛋豆腐").isSuperset(of: [.egg, .vegetarian])); XCTAssertFalse(MenuReader.flags("皮蛋豆腐").contains(.vegan))
        XCTAssertTrue(MenuReader.flags("拍黄瓜").contains(.vegan))
        XCTAssertTrue(MenuReader.flags("老醋花生米").contains(.nuts))
        XCTAssertTrue(MenuReader.flags("剁椒鱼头").isSuperset(of: [.fish, .spicy]))
        // Tofu that is usually cooked with meat is never called vegetarian.
        let mapo = MenuReader.parse(["麻婆豆腐 18元", "家常豆腐 18元"])
        for d in mapo { XCTAssertEqual(MenuReader.verdict(d, diets: [.vegetarian]), .ask(d.caution ?? "")) ; XCTAssertNotNil(d.caution) }
        XCTAssertTrue(MenuReader.flags("Stir-fried fish-flavored shredded pork").contains(.pork))
        XCTAssertFalse(MenuReader.flags("Stir-fried fish-flavored shredded pork").contains(.fish))
    }

    func testFitsOnlyWhenTheMenuSaysSo() {
        let d = MenuReader.parse(["拍黄瓜 8元", "扬州炒饭 8元", "回锅肉 22元"])
        XCTAssertEqual(MenuReader.verdict(d[0], diets: [.vegetarian]), .fits)
        if case .ask = MenuReader.verdict(d[1], diets: [.vegetarian]) {} else { XCTFail("fried rice doesn't say it's meat-free") }
        XCTAssertEqual(MenuReader.verdict(d[2], diets: [.vegetarian]), .clash([.meat, .pork]))
        XCTAssertEqual(MenuReader.verdict(d[2], diets: [.noBeef]), .fits)
    }

    func testPricesInMoreCurrenciesAndNoSpaces() {
        XCTAssertEqual(MenuReader.splitPrice("香辣鱼50元")?.value, 50)
        XCTAssertEqual(MenuReader.splitPrice("香辣鱼50元")?.name, "香辣鱼")
        XCTAssertEqual(MenuReader.splitPrice("ラーメン 850円")?.value, 850)
        XCTAssertEqual(MenuReader.splitPrice("비빔밥 ₩12000")?.value, 12000)
        XCTAssertEqual(MenuReader.currency(in: ["ラーメン 850円"]), "JPY")
        XCTAssertEqual(MenuReader.currency(in: ["拉面 ¥25"]), "CNY")
        XCTAssertTrue(MenuReader.isJunk("www.nipic.com BY:guilan"))
        XCTAssertTrue(MenuReader.isJunk("** tx *"))
    }

    // MARK: receipts — the user's test receipts

    private let eastRepair = """
    East Repair Inc.
    1912 Harvest Lane
    New York, NY 12210
    Bill To  Ship To  Receipt Date  11/02/2019
    John Smith  John Smith  P.O.#  2312/2019
    2 Court Square  3787 Pineview Drive  Due Date  26/02/2019
    Receipt #  US-001
    QTY  DESCRIPTION  UNIT PRICE  AMOUNT
    1  Front and rear brake cables  100.00  100.00
    2  New set of pedal arms  15.00  30.00
    3  Labor 3hrs  5.00  15.00
    Subtotal  145.00
    Sales Tax 6.25%  9.06
    RECEIPT TOTAL  $154.06
    Terms & Conditions
    Payment is due within 15 days
    """

    func testReceiptReadsShopDateNumberLinesAndTax() {
        let r = DataGrab.receipt(eastRepair)
        XCTAssertEqual(r.merchant, "East Repair Inc.")
        XCTAssertEqual(r.number, "US-001")
        XCTAssertNotNil(r.date)
        XCTAssertEqual(r.lines.map(\.name), ["Front and rear brake cables", "New set of pedal arms", "Labor 3hrs"])
        XCTAssertEqual(r.lines.map(\.qty), [1, 2, 3])
        XCTAssertEqual(r.lines.map(\.unit), [100, 15, 5])
        XCTAssertEqual(r.lines.map(\.amount), [100, 30, 15])
        XCTAssertEqual(r.subtotal, 145); XCTAssertEqual(r.tax, 9.06); XCTAssertEqual(r.taxRate, 6.25); XCTAssertEqual(r.total, 154.06)
        XCTAssertNil(DataGrab.check(r), "it adds up")
        XCTAssertEqual(DataGrab.receiptRows(r).first, ["Item", "Qty", "Unit price", "Amount"])
        XCTAssertTrue(DataGrab.receiptRows(r).contains(["Tax (6.25%)", "", "", "9.06"]))
    }

    func testReceiptTotalBeatsAZeroBalanceAndMisreadsAreFlagged() {
        let xero = """
        RECEIPT
        Yeehaw Posters and Stickers
        Cartoon mouse poster - framed  $100.00  2  7.25  $214.50
        President poster - framed  $150.00  1  7.25  $160.88
        Dancing sheriff poster - framed  $100.00  1  7.25  $107.25
        TOTAL  $482.63
        TOTAL PAID  $482.63
        BALANCE DUE  $0.00
        PAYMENT METHOD: Check
        """
        let r = DataGrab.receipt(xero)
        XCTAssertEqual(r.total, 482.63, "a $0.00 balance is never the total")
        XCTAssertEqual(r.merchant, "Yeehaw Posters and Stickers")
        XCTAssertEqual(r.payment, "Check")
        XCTAssertEqual(r.lines.count, 3)
        // 214.50 + 160.88 + 107.25 = 482.63 — adds up. A misread line is called out instead of filed silently.
        XCTAssertNil(DataGrab.check(r))
        var bad = r; bad.lines[1].amount = 16.88
        XCTAssertNotNil(DataGrab.check(bad))
    }

    func testReceiptResultIsRememberedForTheResultScreen() async {
        let out = await ChainRunner.apply(ChainStep(block: .pullReceipt), to: .text(eastRepair))
        guard case .success(.text(let csv)) = out else { return XCTFail("no receipt") }
        XCTAssertEqual(DataGrab.recalled(csv)?.merchant, "East Repair Inc.")
        XCTAssertTrue(csv.hasPrefix("Item,Qty,Unit price,Amount\nFront and rear brake cables,1,100.00,100.00"), csv)
    }

    // MARK: the guided chooser

    func testPhotoChoicesSortIntoAFewPlainGoals() {
        let chains = ChainTemplates.all.filter { $0.problem(starting: .image) == nil }
        let tools = ToolHandoff.tools(for: .image)
        let one = Guide.sort(kind: .image, count: 1, tools: tools, chains: chains, voices: false)
        XCTAssertLessThanOrEqual(one.count, 7)
        XCTAssertEqual(Set(one.map(\.goal)).count, one.count, "each goal once")
        func goal(_ id: String) -> String? { one.first { $0.options.contains { $0.id == "chain-" + id } }?.goal }
        XCTAssertEqual(goal("receipt-to-row"), "save", "reading a receipt is about saving it, not reading")
        XCTAssertNil(goal("photo-under-2mb"), "Fit It does that job, so it's offered once, as the tool")
        XCTAssertEqual(one.first { $0.options.contains(.tool("fitit")) }?.goal, "share")
        XCTAssertEqual(one.first { $0.options.contains(.tool("scrub")) }?.goal, "share")
        XCTAssertEqual(goal("passport-photo"), "share")
        XCTAssertEqual(one.first { $0.options.contains(.tool("sticker")) }?.goal, "fun")
        XCTAssertEqual(one.first { $0.options.contains(.tool("cards")) }?.goal, "save")
        XCTAssertEqual(Guide.keyBlock(chains.first { $0.id == "receipt-to-row" }!, kind: .image), .pullReceipt, "its icon is the receipt, not the text scanner")
        // Several photos: "put them together" comes first, with collage and the reel.
        let many = Guide.sort(kind: .image, count: 3, tools: tools, chains: chains, voices: false)
        XCTAssertEqual(many.first?.goal, "together")
        XCTAssertTrue(many.first?.options.contains(.tool("collage")) == true)
        // Every option that was on the old list is still reachable.
        XCTAssertEqual(one.flatMap(\.options).count, tools.count + chains.filter { c in
            !(c.collage == true || c.gif == true || c.flipbook == true || c.versus == true) && !(Guide.coveredBy[c.id].map(tools.contains) ?? false)
        }.count)
    }

    func testTheGuessReadsWhatsInThePhoto() {
        XCTAssertEqual(Guide.guess(.init(count: 3), kind: .image)?.goal, "together")
        XCTAssertEqual(Guide.guess(.init(text: "SUBTOTAL 12.00\nTAX 1.00\nTOTAL 13.00\nVISA"), kind: .image)?.goal, "save")
        XCTAssertEqual(Guide.guess(.init(text: "Priya Natarajan\npriya@lumen.com\n+1 415 555 0142"), kind: .image)?.tool, "cards")
        XCTAssertEqual(Guide.guess(.init(faces: 2), kind: .image)?.goal, "fun")
        XCTAssertEqual(Guide.guess(.init(barcode: true), kind: .image)?.block, .readCode)
        XCTAssertEqual(Guide.guess(.init(), kind: .image)?.goal, "share")
        XCTAssertNil(Guide.guess(.init(), kind: .pdf))
    }

    @MainActor func testRequestNamesBecomePlainTitles() {
        let c = Chain(id: "x", name: "I want an image to convert to pdf", steps: [ChainStep(block: .stripLocation), ChainStep(block: .convertImage), ChainStep(block: .photoPdf)])
        let t = Guide.title(.chain(c), count: 1)
        XCTAssertFalse(t.lowercased().hasPrefix("i want"), t)
        XCTAssertTrue(t.contains("PDF"), t)
        XCTAssertEqual(Guide.keyBlock(c, kind: .image), .photoPdf)
    }

    @MainActor func testHandOffCarriesEveryPhoto() {
        let a = UIImage(systemName: "star")!, b = UIImage(systemName: "heart")!
        ToolHandoff.shared.put(.image(a), for: "collage", others: [b, b])
        XCTAssertEqual(ToolHandoff.shared.takePhotos("collage").count, 3)
        XCTAssertTrue(ToolHandoff.shared.takePhotos("collage").isEmpty, "used once")
    }
}
