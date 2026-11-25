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

    /// Your 20 Nov screenshot: a Chinese menu showed only characters. Every dish now has a plain English name even
    /// before (or without) Apple's translation, and 烤翅 (grilled wings) is known to be chicken, not "ask first".
    func testChineseDishesGetEnglishNames() {
        XCTAssertEqual(MenuReader.gloss("香辣鱼"), "Spicy fish")
        XCTAssertEqual(MenuReader.gloss("烤虾"), "Grilled shrimp")
        XCTAssertEqual(MenuReader.gloss("烤牛蛙"), "Grilled bullfrog")
        XCTAssertEqual(MenuReader.gloss("烤翅"), "Grilled wings")
        XCTAssertEqual(MenuReader.gloss("酸菜鱼"), "Pickled-cabbage fish")
        XCTAssertEqual(MenuReader.gloss("水煮鱼"), "Chili-poached fish")
        XCTAssertEqual(MenuReader.gloss("红烧全鱼"), "Soy-braised whole fish")
        XCTAssertEqual(MenuReader.gloss("重庆辣子鸡"), "Chongqing chili chicken")
        XCTAssertEqual(MenuReader.gloss("特色篇"), "House specials")
        XCTAssertNil(MenuReader.gloss("Spicy fish"), "English stays as it is")
        XCTAssertTrue(MenuReader.flags("烤翅").contains(.chicken))
        XCTAssertTrue(MenuReader.flags("鱼翅").contains(.fish))
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

    /// Your 20 Nov screenshot: "Decorate it for a celebration" and "Decorate a video for a celebration" were the
    /// same job listed twice under Make a clip. Each job shows once, for videos and for photos.
    @MainActor func testNoJobIsListedTwice() {
        for kind in [ChainKind.video, .image] {
            let chains = ChainTemplates.all.filter { $0.problem(starting: kind) == nil }
            let tools = ToolHandoff.tools(for: kind)
            let all = Guide.sort(kind: kind, count: 1, tools: tools, chains: chains, voices: false).flatMap(\.options)
            for (chain, tool) in Guide.coveredBy where tools.contains(tool) {
                XCTAssertFalse(all.contains { $0.id == "chain-" + chain }, "\(chain) repeats the \(tool) tool for \(kind)")
            }
            let titles = all.map { Guide.title($0, count: 1, kind: kind).lowercased() }
            XCTAssertEqual(Set(titles).count, titles.count, "two choices with the same name for \(kind): \(titles)")
        }
        let video = Guide.sort(kind: .video, count: 1, tools: ToolHandoff.tools(for: .video),
                               chains: ChainTemplates.all.filter { $0.problem(starting: .video) == nil }, voices: false).flatMap(\.options)
        if ToolHandoff.tools(for: .video).contains("celebrate") {
            XCTAssertTrue(video.contains(.tool("celebrate")))
            XCTAssertFalse(video.contains { $0.id == "chain-video-celebrate" })
        }
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

    /// 25 Nov, the Home camera: whatever is photographed, the first suggestion fits it.
    func testTheGuessKnowsMoreKindsOfPicture() {
        let menu = "Starters\nSamosa 6.50\nPaneer Tikka 11.00\nMains\nButter Chicken 16.00\nBiryani 15.00\nNaan 3.00\nDesserts\nKulfi 5.00"
        XCTAssertEqual(Guide.guess(.init(text: menu), kind: .image)?.tool, "menu")
        let flyer = "Spring Bake Sale\nSaturday, April 12\n10:00 am - 2 pm\nLincoln Elementary Gym\nEveryone welcome"
        XCTAssertEqual(Guide.guess(.init(text: flyer), kind: .image)?.block, .calendarEvent)
        let letter = String(repeating: "Dear Mr Shah, thank you for your letter about the account and the agreement we discussed last week. ", count: 4)
        XCTAssertEqual(Guide.guess(.init(text: letter), kind: .image)?.tool, "scan")
        XCTAssertEqual(Guide.guess(.init(labels: ["plant", "flower"]), kind: .image)?.tool, "identify")
        XCTAssertEqual(Guide.guess(.init(faces: 1, labels: ["dog"]), kind: .image)?.goal, "fun", "a person in it is still about the person")
        // The receipt and the card still win over everything else.
        XCTAssertEqual(Guide.guess(.init(text: "CORNER MARKET\n11/25/2026 12:41 PM\nSUBTOTAL 11.64\nTAX 0.73\nTOTAL 12.37\nVISA"), kind: .image)?.block, .expenseRow)
        // Every tool a suggestion points to really takes the photo it was handed.
        for t in ["menu", "scan", "identify", "cards"] { XCTAssertTrue(ToolHandoff.tools(for: .image).contains(t), "\(t) can't take the photo") }
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

    // MARK: tools brought together

    /// Every tool that moved into another keeps its own full screen and is one tap away inside its new home —
    /// nothing is lost, and the Home grid shows one clear place for each kind of job.
    @MainActor func testMergedToolsAreAllStillReachable() {
        for (tool, home) in Tool.homes {
            XCTAssertNotNil(TOOLS.first { $0.id == tool }, "\(tool) still exists")
            XCTAssertNotNil(TOOLS.first { $0.id == home }, "\(home) exists")
            XCTAssertTrue(ToolHub.jobs(home).contains { $0.id == tool }, "\(tool) is a card inside \(home)")
            XCTAssertFalse((1...9).flatMap { tools(onPage: $0) }.contains { $0.id == tool }, "\(tool) isn't listed twice on Home")
            XCTAssertTrue(searchTools(TOOLS.first { $0.id == tool }!.name).contains { $0.id == tool }, "searching \(tool)'s name still finds it")
        }
        for hub in Set(Tool.homes.values) { XCTAssertTrue((1...9).flatMap { tools(onPage: $0) }.contains { $0.id == hub }, "\(hub) is on Home") }
        XCTAssertTrue(searchTools("ringtone").contains { $0.id == "audiostudio" || $0.id == "ringtone" })
    }

    // MARK: posters → events (the user's two test posters)

    func testSpeedDatingPosterBecomesAFullEvent() {
        let text = """
        Looking for that special someone?
        LET US HELP YOU
        SPEED UP THE PROCESS!
        Speed Dating
        DINNER
        YOU WILL ENJOY COCKTAIL HOUR APPETIZER OR SALAD
        SELECTION FROM 4 MAIN COURSES
        SATURDAY OCT 20
        6:00PM - 8:00PM
        PRE-EVENT PRICE: $80, AT THE DOOR: $100
        DOWNTOWN BALLROOM 1234 BROADWAY AVE
        PLEASE CONTACT SUSAN AT 555-1234 OR SUSAN@SPEEDDATING.COM
        OR VISIT WWW.SPEEDDATING.COM
        """
        let heights: [String: CGFloat] = ["Speed Dating": 0.07, "DINNER": 0.05, "Looking for that special someone?": 0.025, "SATURDAY OCT 20": 0.03]
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 19))!
        let e = DataGrab.event(text, heights: heights, now: now)
        XCTAssertEqual(e.title, "Speed Dating Dinner")
        let s = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: e.start ?? .distantPast)
        XCTAssertEqual(s.month, 10); XCTAssertEqual(s.day, 20); XCTAssertEqual(s.hour, 18); XCTAssertEqual(s.minute, 0)
        XCTAssertGreaterThan(e.start ?? .distantPast, now, "Oct 20 has passed this year, so it's a coming one")
        XCTAssertEqual(Calendar.current.component(.hour, from: e.end ?? .distantPast), 20)
        XCTAssertTrue(e.location.lowercased().contains("broadway"), e.location)
        XCTAssertEqual(e.url, "https://www.speeddating.com")
        XCTAssertTrue(e.notes.contains("$80"), e.notes)
        XCTAssertTrue(e.notes.lowercased().contains("susan"), e.notes)
        let ics = DataGrab.ics(e)
        XCTAssertTrue(ics.contains("DESCRIPTION:")); XCTAssertTrue(ics.contains("URL:https://www.speeddating.com"))
        let back = ICSParse.parse(ics)
        XCTAssertEqual(back.title, e.title); XCTAssertEqual(back.url, e.url); XCTAssertTrue(back.notes.contains("$80"))
    }

    func testStockPosterIgnoresWatermarksAndReadsLabels() {
        let text = """
        VECTOR  EPS 10
        UPCOMING
        EVENTS
        Curabitur arcu erat, accumsan id imperdiet et, porttitor at sem.
        WHERE  LOREM IPSUM AUDITORIUM
        WHEN  9 PM  12 MARCH
        TICKETS  WWW.LOREMIPSUM.COM
        shutterstock
        IMAGE ID: 1072866329
        www.shutterstock.com
        """
        let heights: [String: CGFloat] = ["UPCOMING": 0.1, "EVENTS": 0.1, "shutterstock": 0.04]
        let e = DataGrab.event(text, heights: heights, now: Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 19))!)
        XCTAssertEqual(e.title, "Upcoming Events")
        XCTAssertEqual(e.location, "Lorem Ipsum Auditorium")
        XCTAssertEqual(e.url, "https://www.loremipsum.com")
        let s = Calendar.current.dateComponents([.month, .day, .hour], from: e.start ?? .distantPast)
        XCTAssertEqual(s.month, 3); XCTAssertEqual(s.day, 12); XCTAssertEqual(s.hour, 21)
        XCTAssertFalse(e.notes.lowercased().contains("shutterstock"))
    }
}

/// "PDF under 5 MB (mine)", "… copy", "… copy copy" were all offered side by side (20 Nov). The same tool saved
/// several times — or copied from a ready-made one — is offered once, in the guide and the Share sheet.
final class SameToolOnceTests: XCTestCase {
    @MainActor func testCopiesOfOneToolAreOfferedOnce() throws {
        let base = try XCTUnwrap(ChainTemplates.all.first { $0.id == "pdf-email" })
        var mine = base; mine.id = "mine-1"; mine.name = "PDF under 5 MB for email (mine)"
        var copy = mine; copy.id = "mine-2"; copy.name = mine.name + " copy"
        var copy2 = copy; copy2.id = "mine-3"; copy2.name = copy.name + " copy"
        var different = mine; different.id = "mine-4"; different.steps[0].settings["mb"] = "2"

        let offered = ChainStore.offers(for: .pdf, mine: [mine, copy, copy2, different], last: nil)
        let names = offered.map(\.name)
        XCTAssertEqual(names.filter { $0.hasPrefix("PDF under 5 MB for email (mine)") }.count, 2, "copies offered again: \(names)")
        XCTAssertFalse(offered.contains { $0.id == "pdf-email" }, "the ready-made it was copied from is offered too")
        XCTAssertTrue(offered.contains { $0.id == "mine-4" }, "a tool with different settings is a different tool")

        let sorted = Guide.sort(kind: .pdf, count: 1, tools: [], chains: [mine, copy, copy2] + ChainTemplates.all, voices: false)
        let chains = sorted.flatMap(\.options).compactMap { o -> String? in if case .chain(let c) = o { return c.id }; return nil }
        XCTAssertEqual(chains.filter { ["mine-1", "mine-2", "mine-3", "pdf-email"].contains($0) }, ["mine-1"])
    }
}

/// The home box finds what already exists as the person types: tools and ready-made tools, before anything is built.
final class ReadyNowTests: XCTestCase {
    @MainActor func testTypingANeedFindsTheReadyMadeToolAndTheTool() {
        let flows = BuilderView.searchChains("shrink a pdf to email it", in: ChainTemplates.all).map(\.id)
        XCTAssertTrue(flows.contains("pdf-email"), "\(flows.prefix(5))")
        XCTAssertTrue(searchTools("sign a pdf").prefix(3).contains { $0.id == "pdfsign" })
        XCTAssertTrue(BuilderView.searchChains("please help", in: ChainTemplates.all).isEmpty, "filler words alone match nothing")
    }
}
