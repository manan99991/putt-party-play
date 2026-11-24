import XCTest
import UIKit
@testable import HandyTools

/// Manan, 23 Nov: "prices are clearly incorrect, some are missing most of the dishes" — a five-screen Indian menu
/// board came back as 8 "dishes" (headings and scraps), a steakhouse menu as misread words with descriptions run
/// together, and Chinese dishes stayed in characters. Each test is one of those, as the camera hands it over.
final class MenuBoardTests: XCTestCase {

    /// Two screens of a menu board, photographed at an angle: every row slopes, each dish name and its price are
    /// separate pieces far apart, some rows have two prices (Single / Family), and veg marks read as symbols.
    func testASlopedMenuBoardReadsEveryDishAndItsPrice() {
        let slope: CGFloat = 0.03
        func panel(_ x0: CGFloat, _ rows: [Any]) -> [MenuReader.Box] {
            var out: [MenuReader.Box] = []
            var y: CGFloat = 0.20
            for r in rows {
                if let h = r as? String {
                    out.append(MenuReader.Box(text: h, rect: CGRect(x: x0 + 0.01, y: y, width: 0.08, height: 0.014), slope: slope)); y += 0.022; continue
                }
                guard let row = r as? (String, [String]) else { continue }
                let (name, prices) = row
                out.append(MenuReader.Box(text: name, rect: CGRect(x: x0, y: y, width: 0.07, height: 0.011), slope: slope))
                var px = x0 + 0.105
                for p in prices {
                    out.append(MenuReader.Box(text: p, rect: CGRect(x: px, y: y + slope * (px - x0 - 0.035), width: 0.035, height: 0.011), slope: slope))
                    px += 0.04
                }
                y += 0.017
            }
            return out
        }
        let left = panel(0.05, ["Tiffins/ Dosas", ("■ Idly (3 PCS)", [": $ 6.99"]), ("■ Plain Dosa", [": $ 10.99"]),
                                ("■ Onion Uttapam [New]", [": $ 11.99"]), ("■ Chicken 65 Dosa", [": $ 12.99"]), "Chaat Section",
                                ("■ Pani Puri (7 Pcs)", [": $ 7.99"]), ("■ Samosa Ragda", [": $ 7.99"])])
        let right = panel(0.24, ["Appetizers NonVeg", ("■ Chicken 65", [": $ 11.99"]), ("■ Chilli Chicken", [": $ 11.99"]), "Dum Biryani",
                                 ("■ Veg Biryani", ["$ 13.99", "$ 39.99"]), ("■ Goat Dum", ["$ 17.99", "$ 50.99"]), ("■ Kaju Biriyani", ["$ 14.99", "$ 42.99"])])
        let items = MenuReader.parse(MenuReader.lines(from: left + right)).filter { !$0.note }
        XCTAssertEqual(items.map(\.name), ["Idly (3 PCS)", "Plain Dosa", "Onion Uttapam", "Chicken 65 Dosa", "Pani Puri (7 Pcs)", "Samosa Ragda",
                                           "Chicken 65", "Chilli Chicken", "Veg Biryani", "Goat Dum", "Kaju Biryani"])
        XCTAssertEqual(items.map(\.price), [6.99, 10.99, 11.99, 12.99, 7.99, 7.99, 11.99, 11.99, 13.99, 17.99, 14.99])
        XCTAssertEqual(items.map(\.section), ["Tiffins/ Dosas", "Tiffins/ Dosas", "Tiffins/ Dosas", "Tiffins/ Dosas", "Chaat Section", "Chaat Section",
                                              "Appetizers NonVeg", "Appetizers NonVeg", "Dum Biryani", "Dum Biryani", "Dum Biryani"])
        XCTAssertEqual(items[8].priceText, "$ 13.99 / $ 39.99", "both sizes are kept")
        XCTAssertEqual(items[2].tags, ["New"])
    }

    /// "Chicken 65" is a dish, not a $65 chicken, on a menu whose prices all have cents.
    func testANumberInADishNameIsNotItsPrice() {
        let lines = ["Appetizers NonVeg", "Chicken 65 $ 11.99", "Gobi 65 $ 10.99", "Chicken 65", "Paneer 65 : $ 10.99", "Chilli Chicken $ 11.99",
                     "Apollo Fish $ 12.99", "Fish 65 $ 12.99", "Chilli Shrimp $ 13.99", "Pepper Shrimp $ 13.99", "Egg 65 $ 10.99"]
        XCTAssertTrue(MenuReader.strictPrices(lines))
        let items = MenuReader.parse(lines).filter { !$0.note }
        XCTAssertEqual(items.first?.name, "Chicken 65"); XCTAssertEqual(items.first?.price, 11.99)
        XCTAssertFalse(items.contains { $0.price == 65 }, "65 is never a price here")
        XCTAssertEqual(items.count, 9, "the lone 'Chicken 65' with no price (a label on the counter) isn't a dish")
        XCTAssertEqual(MenuReader.splitPrice("Chicken 65 11.99")?.name, "Chicken 65")
        XCTAssertEqual(MenuReader.splitPrice("Chicken 65 11.99")?.value, 11.99)
    }

    /// The steakhouse menu: GF marks after prices, a misread word, Full / Half, Market Price, a stray dash, a note
    /// about the section, two dishes read as one line, and descriptions that stay with their dish.
    func testASteakhouseMenuKeepsEachDishWithItsOwnPriceAndWords() {
        let lines = """
        SOUPS
        Lobster Bisque 18 GF
        Our House-Made Lobster Bisque flavored with Sherry and garnished
        with Sweet Atlantic Lobster and House-Made Crème Fraîche
        Potato Chorizo Soup 14 GF
        Hearty Potatoes and Chorizo in a Savory Cream Broth
        SIDES
        All selections are gluten-free except Baked Mac & Cheese
        Baked Mac & Cheese 18
        Sautéed Brussels Sprouts 12-
        Grilled Asparagus 11
        PREMIUM WAGYU
        A5 Snow-Aged Wagru Saku Block 158
        CENTER OF THE PLATE
        Comboy Ribeye 95
        24 oz. short bone ribeye.
        Rack of Lamb Full 90 / Half 50
        Maine Lobster Tail Market Price
        ACCOMPANIMENTS
        Surf & Turf 30 Maître d'Hôtel Butter 7
        """.components(separatedBy: "\n")
        let all = MenuReader.parse(lines)
        let items = all.filter { !$0.note }
        XCTAssertEqual(items.map(\.name), ["Lobster Bisque", "Potato Chorizo Soup", "Baked Mac & Cheese", "Sautéed Brussels Sprouts", "Grilled Asparagus",
                                           "A5 Snow-Aged Wagyu Saku Block", "Cowboy Ribeye", "Rack of Lamb", "Maine Lobster Tail", "Surf & Turf", "Maître d'Hôtel Butter"])
        XCTAssertEqual(items.map(\.price), [18, 14, 18, 12, 11, 158, 95, 90, nil, 30, 7])
        XCTAssertEqual(items[7].priceText, "Full 90 / Half 50")
        XCTAssertEqual(items[8].priceText, "Market price")
        XCTAssertEqual(items[0].tags, ["Gluten-free"]); XCTAssertFalse(items[0].flags.contains(.gluten))
        XCTAssertTrue(items[0].detail.hasPrefix("Our House-Made Lobster Bisque"))
        XCTAssertEqual(items[6].detail, "24 oz. short bone ribeye")
        XCTAssertTrue(items[8].detail.isEmpty, "the next dish never becomes the last one's description")
        XCTAssertTrue(all.contains { $0.note && $0.name.hasPrefix("All selections") })
        XCTAssertEqual(items[6].section, "Center Of The Plate")
    }

    /// The camera's usual slips in a price (24 Nov, on Manan's real photos): "S13.99" is $13.99, "S4" is 54, "5o" is 50.
    func testCommonPriceMisreadsAreFixed() {
        XCTAssertEqual(MenuReader.splitPrice("Veg Biryanl S13.99 $ 39.99")?.value, 13.99)
        XCTAssertEqual(MenuReader.splitPrice("Diver Seallops S4")?.value, 54)
        XCTAssertEqual(MenuReader.splitPrice("Braised Short Rib 5o")?.value, 50)
        XCTAssertEqual(MenuReader.splitPrice("Water S 0.99")?.value, 0.99)
        XCTAssertNil(MenuReader.splitPrice("Since 1998"))
        // From the real board and steakhouse: a lost point, a $ read as 5, letters read for digits.
        XCTAssertEqual(MenuReader.splitPrice("Chicken Dum Biryani : S 15 99 $ 44.09")?.value, 15.99)
        XCTAssertEqual(MenuReader.splitPrice("Avakai Goat Dum • 5 18.99 S 52.99")?.value, 18.99)
        XCTAssertEqual(MenuReader.splitPrice("Diver Scallops SA")?.value, 54)
        XCTAssertEqual(MenuReader.splitPrice("Cabernet Mushrooms t2")?.value, 12)
        XCTAssertEqual(MenuReader.fixWords("Gorlie Whipped Potetoer"), "Garlic Whipped Potatoes")
        XCTAssertEqual(MenuReader.fixWords("Pollo al ajillo"), "Pollo al ajillo")
    }

    /// Only one-letter misreads of real menu words are fixed, and never a word that's right already.
    func testMisreadMenuWordsAreFixedAndRealWordsLeftAlone() {
        XCTAssertEqual(MenuReader.fixWords("Comboy Ribeye"), "Cowboy Ribeye")
        XCTAssertEqual(MenuReader.fixWords("Wagru Tomahawk"), "Wagyu Tomahawk")
        XCTAssertEqual(MenuReader.fixWords("Maine Lobster Tail"), "Maine Lobster Tail")
        XCTAssertEqual(MenuReader.fixWords("Chicken Marsala"), "Chicken Marsala")
        XCTAssertEqual(MenuReader.fixWords("Paneer Tikka Masala"), "Paneer Tikka Masala")
        XCTAssertEqual(MenuReader.fixWords("Pollo al ajillo"), "Pollo al ajillo")
        XCTAssertEqual(MenuReader.fixWords("香辣鱼"), "香辣鱼")
    }

    /// Every dish on Manan's Chinese menus has an English name with nothing downloaded (23 Nov: 盆盆虾, 馋嘴肥肠,
    /// 馋嘴牛蛙 and 湘西土匪鸭 showed only characters).
    func testEveryChineseDishHasAnEnglishName() {
        XCTAssertEqual(MenuReader.gloss("盆盆虾"), "Bowl of shrimp")
        XCTAssertEqual(MenuReader.gloss("馋嘴肥肠"), "Mouth-watering pork intestines")
        XCTAssertEqual(MenuReader.gloss("馋嘴牛蛙"), "Mouth-watering bullfrog")
        XCTAssertEqual(MenuReader.gloss("湘西土匪鸭"), "West Hunan bandit-style duck")
        XCTAssertEqual(MenuReader.gloss("泡椒魔芋鸭"), "Pickled-chili konjac duck")
        let dishes = ["香辣鱼", "烤虾", "烤牛蛙", "烤翅", "酸菜鱼", "红烧全鱼", "重庆辣子鸡", "香辣鸡翅", "川北凉粉", "口水鸡", "夫妻肺片", "拌萝卜皮",
                      "拍黄瓜", "皮蛋豆腐", "泡椒凤爪", "蒜泥白肉", "干煸牛肉丝", "红烧排骨", "糖醋排骨", "孜然羊肉", "锅包肉", "香辣小河虾", "鱼香肝尖",
                      "水煮肉", "水煮牛肉", "鱼香肉丝", "回锅肉", "家常豆腐", "香干腊肉", "黑椒牛肉烩饭", "鸡腿饭套餐", "台式三杯鸡饭", "法式猪扒饭",
                      "扬州炒饭", "青椒牛肉炒饭", "咖喱炒饭", "牛柳炒乌冬面", "海鲜炒米粉", "川味回锅肉", "剁椒鱼头", "花蛤豆腐汤", "鱼头豆腐汤",
                      "七彩干贝羹", "皮蛋瘦肉粥", "香滑田鸡粥", "鸡汁汤面", "铁板田鸡", "铁板鱿鱼"]
        let missing = dishes.filter { MenuReader.gloss($0) == nil }
        XCTAssertEqual(missing, [], "no English name for \(missing)")
    }

    /// On a menu whose dishes all have prices, unpriced short lines are sections, and a section line ("Includes 16 oz
    /// Pulao Rice") is a note, never a dish.
    func testSectionsAndNotesOnABoard() {
        let lines = ["Veg Gravies •", "Includes 16 oz Pulao Rice", "Yellow Dal Tadka : $ 11.99", "Mix Vegetable Curry : $ 12.99",
                     "Kadai Veg Curry : $ 12.99", "Breads", "Plain Naan : $ 2.99", "Butter Naan : $ 3.49", "Garlic Naan : $ 3.49",
                     "Tandoor", "Paneer Tikka Kebab(8 PCS) : $ 12.99", "Malai Tikka (7 PCS) : $ 12.99"]
        let all = MenuReader.parse(lines)
        let items = all.filter { !$0.note }
        XCTAssertEqual(items.count, 8)
        XCTAssertEqual(items.map(\.section), ["Veg Gravies", "Veg Gravies", "Veg Gravies", "Breads", "Breads", "Breads", "Tandoor", "Tandoor"])
        XCTAssertTrue(all.contains { $0.note && $0.name == "Includes 16 oz Pulao Rice" })
        XCTAssertFalse(items.contains { ["Breads", "Tandoor", "Veg Gravies"].contains($0.name) })
    }

    // MARK: Manan's own menu photos (decrypted by CI into $REAL_PHOTOS/private; skipped elsewhere)

    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Reads each photo exactly as Menu Assistant does and checks the listed dishes come back with their price.
    /// Prints every miss, so a failure says what was read instead.
    func testManansMenuBoardAndSteakhouse() throws {
        guard let root = ProcessInfo.processInfo.environment["REAL_PHOTOS"],
              let gpath = ProcessInfo.processInfo.environment["GOLDEN"],
              let gdata = try? Data(contentsOf: URL(fileURLWithPath: gpath)),
              let g = try? JSONSerialization.jsonObject(with: gdata) as? [String: Any] else { throw XCTSkip("private photos not decrypted") }
        let dir = URL(fileURLWithPath: root).appendingPathComponent("private")
        // What the camera read, piece by piece, for working out a failure off the build machine. Written only where
        // the workflow asks for it, and published only encrypted (it's text from a private photo).
        var dump: [String: Any] = [:]
        func pieces(_ b: [MenuReader.Box]) -> [[String: Any]] {
            b.map { ["t": $0.text, "x": $0.rect.minX, "y": $0.rect.minY, "w": $0.rect.width, "h": $0.rect.height, "s": $0.slope, "c": $0.confidence] }
        }
        defer {
            if let path = ProcessInfo.processInfo.environment["MENU_DUMP"], let d = try? JSONSerialization.data(withJSONObject: dump) {
                try? d.write(to: URL(fileURLWithPath: path))
            }
        }
        for case let e as [String: Any] in g["menus"] as? [Any] ?? [] {
            let file = e["file"] as? String ?? ""
            guard ["menu-indian-board.jpg", "menu-steakhouse.jpg"].contains(file) else { continue }
            guard let img = UIImage(contentsOfFile: dir.appendingPathComponent(file).path) else { XCTFail("missing \(file)"); continue }
            let started = Date()
            let boxes = MenuReader.read(img)
            let lines = MenuReader.lines(from: boxes)
            dump[file] = ["tiled": pieces(boxes), "page": pieces(MenuReader.read(img, tiles: false)), "lines": lines,
                          "size": [img.size.width * img.scale, img.size.height * img.scale]]
            let items = MenuReader.parse(lines).filter { !$0.note }
            let want = e["dishes"] as? [[Any]] ?? []
            var missed: [String] = []
            for w in want {
                let name = w[0] as? String ?? "", price = (w[1] as? NSNumber)?.doubleValue ?? -1
                let hit = items.contains { i in
                    guard let p = i.price, abs(p - price) < 0.005 else { return false }
                    let a = Self.fold(i.name), b = Self.fold(name)
                    return a == b || a.contains(b) || RealPhotoAccuracyTests.overlap(i.name, name) >= 0.75
                }
                if !hit { missed.append("\(name) \(price)") }
            }
            let found = Double(want.count - missed.count) / Double(max(1, want.count))
            print("MENU| \(file): \(items.count) dishes, \(items.filter { $0.price != nil }.count) priced, listed found \(want.count - missed.count)/\(want.count) in \(Int(Date().timeIntervalSince(started)))s")
            print("MENU| missed: \(missed.joined(separator: "; "))")
            // What was read stays in the local log only (it's text from a private photo).
            print("MENUREAD| \(items.prefix(40).map { "\($0.section) > \($0.name)=\($0.priceText)" }.joined(separator: " | "))")
            XCTAssertGreaterThanOrEqual(found, 0.8, "\(file): missed \(missed)")
        }
    }
}
