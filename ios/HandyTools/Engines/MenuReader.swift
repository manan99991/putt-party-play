import Foundation
import NaturalLanguage
import UIKit
import Vision

/// Reads a photographed menu into dishes — section, name, description, price — and flags what's in each
/// dish from the words on the menu (meat, pork, fish, shellfish, dairy, egg, nuts, gluten, spicy), in
/// English, Spanish, French, Italian, German, Portuguese, Chinese, Japanese and Korean. Multi-column
/// menus are read column by column, with each price joined to the dish on its row. Pure text rules, on
/// device; it can only know what the menu says, and the screen says so.
enum MenuReader {
    enum Flag: String, CaseIterable, Codable {
        case meat, pork, beef, chicken, fish, shellfish, dairy, egg, nuts, gluten, spicy, vegetarian, vegan
        var title: String {
            switch self {
            case .meat: return "Meat"
            case .pork: return "Pork"
            case .beef: return "Beef"
            case .chicken: return "Chicken"
            case .fish: return "Fish"
            case .shellfish: return "Shellfish"
            case .dairy: return "Dairy"
            case .egg: return "Egg"
            case .nuts: return "Nuts"
            case .gluten: return "Gluten"
            case .spicy: return "Spicy"
            case .vegetarian: return "Vegetarian"
            case .vegan: return "Vegan"
            }
        }
    }

    enum Diet: String, CaseIterable, Identifiable {
        case vegetarian, vegan, noPork, noBeef, noShellfish, noNuts, glutenFree, dairyFree
        var id: String { rawValue }
        var title: String {
            switch self {
            case .vegetarian: return "Vegetarian"
            case .vegan: return "Vegan"
            case .noPork: return "No pork"
            case .noBeef: return "No beef"
            case .noShellfish: return "No shellfish"
            case .noNuts: return "No nuts"
            case .glutenFree: return "Gluten-free"
            case .dairyFree: return "Dairy-free"
            }
        }
        var avoids: Set<Flag> {
            switch self {
            case .vegetarian: return [.meat, .pork, .beef, .chicken, .fish, .shellfish]
            case .vegan: return [.meat, .pork, .beef, .chicken, .fish, .shellfish, .dairy, .egg]
            case .noPork: return [.pork]
            case .noBeef: return [.beef]
            case .noShellfish: return [.shellfish]
            case .noNuts: return [.nuts]
            case .glutenFree: return [.gluten]
            case .dairyFree: return [.dairy]
            }
        }
    }

    struct Item: Identifiable, Equatable {
        let id = UUID()
        var section: String
        var name: String
        var detail: String
        var price: Double?
        var priceText: String
        var flags: Set<Flag>
        /// A line about the section rather than a dish ("rice and soup come with the sets above").
        var note = false
        /// When the name alone can't settle it: a dish that's usually cooked with something it doesn't name.
        var caution: String? = nil
        static func == (a: Item, b: Item) -> Bool { a.name == b.name && a.detail == b.detail && a.priceText == b.priceText && a.section == b.section && a.note == b.note }
    }

    /// What to tell the person about one dish and their diet.
    enum Verdict: Equatable {
        case fits                    // the menu's words name what's in it, and none of it clashes
        case clash([Flag])           // it names something they avoid
        case ask(String)             // nothing clashes on paper, but the name doesn't settle it
    }

    static func verdict(_ item: Item, diets: Set<Diet>) -> Verdict {
        let c = conflicts(item, diets: diets)
        if !c.isEmpty { return .clash(c) }
        let meatFree = !diets.isDisjoint(with: [.vegetarian, .vegan])
        if let why = item.caution, meatFree { return .ask(why) }
        // "Fits" needs the menu's own words to say so — a dish that names no ingredients isn't assumed safe.
        if diets.contains(.vegan) { return item.flags.contains(.vegan) ? .fits : .ask("The name doesn't say it's free of meat, egg and dairy — ask before ordering") }
        if meatFree { return item.flags.contains(.vegetarian) ? .fits : .ask("The name doesn't say it's meat-free — ask before ordering") }
        if item.flags.subtracting([.spicy]).isEmpty { return .ask("The name doesn't say what's in it — ask before ordering") }
        return .fits
    }

    /// What in `item` clashes with the chosen diets.
    static func conflicts(_ item: Item, diets: Set<Diet>) -> [Flag] {
        let avoid = diets.reduce(into: Set<Flag>()) { $0.formUnion($1.avoids) }
        return Flag.allCases.filter { avoid.contains($0) && item.flags.contains($0) }
    }

    // MARK: - Parse

    // A price at the end of a line: an optional mark before (€ $ ¥ RMB…), the number, an optional mark after
    // (元 円 원 € kr…). It may follow a space, a run of dots or dashes, or sit straight after a Chinese/Japanese
    // dish name with no space at all ("香辣鱼50元").
    private static let priceRE = try! NSRegularExpression(
        pattern: #"(?:[.\-–—·_~]{2,}|\s|^|(?<=[^\x00-\x7F]))((?:[€£$¥￥₹₩₺฿]|usd|eur|gbp|chf|rmb|cny|rs\.?)\s?)?(\d{1,5}(?:[.,]\d{1,2})?)\s?(€|£|\$|¥|￥|₹|₩|₺|฿|元|円|원|块|eur|usd|chf|kr|zł|rmb|yuan|tl)?\s*$"#,
        options: [.caseInsensitive])
    private static let spacedDigits = try! NSRegularExpression(pattern: #"(?<=\d) (?=\d)"#)

    /// A trailing price on a line: (text before it, the price as shown, its value).
    static func splitPrice(_ raw: String) -> (name: String, shown: String, value: Double)? {
        // "1 0 元" (letter-spaced menus) is 10元.
        let line = spacedDigits.stringByReplacingMatches(in: raw, range: NSRange(location: 0, length: (raw as NSString).length), withTemplate: "")
        let ns = line as NSString
        guard let m = priceRE.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let num = ns.substring(with: m.range(at: 2))
        let hasSymbol = m.range(at: 1).location != NSNotFound || m.range(at: 3).location != NSNotFound
        let hasDecimals = num.contains(".") || num.contains(",")
        // A bare integer is only a price with a currency mark or when it isn't a year/quantity-looking number.
        guard hasSymbol || hasDecimals || (num.count <= 3 && (Int(num) ?? 0) > 0) else { return nil }
        let name = ns.substring(to: m.range.location).trimmingCharacters(in: CharacterSet(charactersIn: " .·-–—_~:|\t"))
        guard let v = Double(num.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return (name, ns.substring(with: m.range).trimmingCharacters(in: CharacterSet(charactersIn: " .")), v)
    }

    // MARK: - Reading the photo

    /// One piece of text the camera read, where it sits on the page (0…1, top-left origin) and how sure it was.
    struct Box: Equatable {
        var text: String
        var rect: CGRect
        var confidence: Float = 1
    }

    /// Text that is only a price ("50元", "-----18元", "12.50").
    static func isPriceOnly(_ t: String) -> Bool {
        guard let p = splitPrice(t) else { return false }
        return p.name.filter(\.isLetter).count < 2
    }

    /// The menu as lines in reading order: each price joined to the dish on its row (menus often print them far
    /// apart, and the camera reads them as two pieces), then column by column, top to bottom.
    static func lines(from boxes: [Box]) -> [String] {
        var parts = boxes.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        var used = Set<Int>()
        // 1. Join each lone price to the nearest text on its left that shares its row.
        for (pi, price) in parts.enumerated() where isPriceOnly(price.text) {
            var best: (i: Int, gap: CGFloat)?
            for (ni, name) in parts.enumerated() where ni != pi && !used.contains(ni) && !isPriceOnly(name.text) {
                let overlap = min(name.rect.maxY, price.rect.maxY) - max(name.rect.minY, price.rect.minY)
                guard overlap > 0.5 * min(name.rect.height, price.rect.height) else { continue }
                let gap = price.rect.minX - name.rect.maxX
                guard gap > -0.02, gap < 0.3 else { continue }
                if best == nil || gap < best!.gap { best = (ni, gap) }
            }
            if let b = best {
                parts[b.i].text += " " + price.text.trimmingCharacters(in: .whitespaces)
                parts[b.i].rect = parts[b.i].rect.union(price.rect)
                used.insert(b.i); parts[pi].text = ""
            }
        }
        parts = parts.filter { !$0.text.isEmpty }
        // 2. Columns: pieces whose left-to-right spans overlap belong together; read each column top to bottom.
        var columns: [(span: ClosedRange<CGFloat>, items: [Box])] = []
        for b in parts.sorted(by: { $0.rect.minX < $1.rect.minX }) {
            if let i = columns.firstIndex(where: { c in
                let o = min(c.span.upperBound, b.rect.maxX) - max(c.span.lowerBound, b.rect.minX)
                return o > 0.3 * b.rect.width
            }) {
                columns[i].items.append(b)
                columns[i].span = min(columns[i].span.lowerBound, b.rect.minX)...max(columns[i].span.upperBound, b.rect.maxX)
            } else {
                columns.append((b.rect.minX...b.rect.maxX, [b]))
            }
        }
        return columns.sorted { $0.span.lowerBound < $1.span.lowerBound }
            .flatMap { $0.items.sorted { $0.rect.midY < $1.rect.midY }.map(\.text) }
    }

    /// Read a menu photo on the phone. Vision picks the menu's language itself; when that read looks weak, it
    /// tries again as Chinese, Japanese and Korean and keeps whichever read the page best.
    static func read(_ image: UIImage) -> [Box] {
        guard let cg = image.resized(maxDimension: 2400).normalizedUp().cgImage else { return [] }
        func pass(_ languages: [String]?) -> [Box] {
            let req = VNRecognizeTextRequest()
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            if let languages { req.recognitionLanguages = languages } else { req.automaticallyDetectsLanguage = true }
            try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
            return (req.results ?? []).compactMap { obs in
                guard let top = obs.topCandidates(1).first else { return nil }
                let r = obs.boundingBox
                return Box(text: top.string, rect: CGRect(x: r.minX, y: 1 - r.maxY, width: r.width, height: r.height), confidence: top.confidence)
            }
        }
        func score(_ b: [Box]) -> Double { b.reduce(0) { $0 + Double($1.confidence) * Double($1.text.filter { $0.isLetter || $0.isNumber }.count) } }
        func meanConfidence(_ b: [Box]) -> Double { b.isEmpty ? 0 : b.reduce(0) { $0 + Double($1.confidence) } / Double(b.count) }
        var best = pass(nil)
        if meanConfidence(best) < 0.6 || score(best) < 40 {
            for langs in [["zh-Hans", "zh-Hant", "en-US"], ["ja-JP", "en-US"], ["ko-KR", "en-US"]] {
                let next = pass(langs)
                if score(next) > score(best) * 1.15 { best = next }
            }
        }
        return best
    }

    /// True when the menu is written in a script the person probably can't read (Chinese, Japanese, Korean,
    /// Cyrillic, Arabic, Thai…), so the dish names are translated straight away.
    /// A plain-English name for a Chinese dish, from the menu words it's built of ("香辣鱼" → "Spicy fish",
    /// "红烧全鱼" → "Soy-braised whole fish"). Works with no download and no network, so a menu never shows only
    /// characters the person can't read; Apple's full translation replaces it when it arrives. nil when too few of
    /// the characters are known to say anything honest.
    static func gloss(_ name: String) -> String? {
        let chars = Array(name.filter { isCJK($0) })
        guard chars.count >= 1, cjkShare(name) > 0.5 else { return nil }
        var parts: [String] = [], known = 0, i = 0
        while i < chars.count {
            var hit: (Int, String)?
            for len in stride(from: min(4, chars.count - i), through: 1, by: -1) {
                if let e = glossary[String(chars[i..<i + len])] { hit = (len, e); break }
            }
            if let (len, e) = hit { if !e.isEmpty, parts.last != e { parts.append(e) }; known += len; i += len } else { i += 1 }
        }
        guard !parts.isEmpty, Double(known) / Double(chars.count) >= 0.6 else { return nil }
        let text = parts.joined(separator: " ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Common Chinese menu words. Longer entries win over the characters inside them (牛蛙 is bullfrog, not beef + frog).
    static let glossary: [String: String] = [
        // places and styles
        "重庆": "Chongqing", "四川": "Sichuan", "川味": "Sichuan-style", "湖南": "Hunan", "湘": "Hunan-style", "北京": "Beijing",
        "巫山": "Wushan", "东北": "Northeastern", "广式": "Cantonese", "粤式": "Cantonese", "新疆": "Xinjiang", "家常": "home-style",
        "特色": "house special", "特色篇": "House specials", "招牌": "signature", "篇": "", "类": "",
        // ways of cooking
        "烤": "grilled", "炸": "fried", "炒": "stir-fried", "爆炒": "flash-fried", "小炒": "wok-fried", "蒸": "steamed", "清蒸": "steamed",
        "煮": "boiled", "水煮": "chili-poached", "红烧": "soy-braised", "焖": "braised", "炖": "stewed", "卤": "marinated",
        "干锅": "dry-pot", "干煸": "dry-fried", "铁板": "sizzling", "凉拌": "cold dressed", "拌": "dressed", "煎": "pan-fried",
        "回锅": "twice-cooked", "糖醋": "sweet and sour", "泼辣": "hot-oil", "烧": "braised", "熏": "smoked", "白切": "poached",
        "铁锅": "iron-pot", "石锅": "stone-pot", "火锅": "hot pot", "麻辣烫": "spicy hot pot",
        // flavours
        "香辣": "spicy", "麻辣": "numbing-spicy", "辣": "chili", "辣子": "chili", "泡椒": "pickled-chili", "酸辣": "hot and sour",
        "酸菜": "pickled-cabbage", "鱼香": "garlic-chili sauce", "宫保": "kung pao", "椒盐": "salt and pepper", "孜然": "cumin",
        "蒜蓉": "garlic", "葱": "scallion", "姜": "ginger", "豆豉": "black bean", "豆鼓": "black bean", "黑椒": "black pepper",
        "咖喱": "curry", "番茄": "tomato", "西红柿": "tomato", "酱": "sauce", "甜": "sweet", "酸": "sour", "香": "fragrant",
        "麻婆": "mapo", "口水": "mouth-watering", "剁椒": "chopped-chili", "酸汤": "sour-broth",
        // fish and seafood
        "鱼": "fish", "全鱼": "whole fish", "鱼头": "fish head", "鱼片": "fish slices", "虾": "shrimp", "大虾": "prawns", "龙虾": "lobster",
        "小龙虾": "crayfish", "蟹": "crab", "螃蟹": "crab", "鱿鱼": "squid", "墨鱼": "cuttlefish", "章鱼": "octopus", "贝": "shellfish",
        "扇贝": "scallops", "蛤蜊": "clams", "花甲": "clams", "生蚝": "oysters", "海鲜": "seafood", "鳝鱼": "eel", "鲈鱼": "sea bass",
        "鱼翅": "shark fin", "鲍鱼": "abalone", "牛蛙": "bullfrog", "田鸡": "frog",
        // meat
        "鸡": "chicken", "童子鸡": "young chicken", "鸡翅": "chicken wings", "翅": "wings", "鸡腿": "chicken leg", "鸡爪": "chicken feet",
        "凤爪": "chicken feet", "鸭": "duck", "烤鸭": "roast duck", "鹅": "goose", "牛": "beef", "牛肉": "beef", "肥牛": "sliced beef",
        "羊": "lamb", "羊肉": "lamb", "羊排": "lamb ribs", "猪": "pork", "猪肉": "pork", "肉": "meat", "肉丝": "shredded pork",
        "排骨": "spare ribs", "五花肉": "pork belly", "肘子": "pork knuckle", "腊肉": "cured pork", "香肠": "sausage", "兔": "rabbit",
        "肚": "tripe", "毛肚": "beef tripe", "肥肠": "pork intestines", "腰花": "kidney", "串": "skewers",
        // plants, staples and the rest
        "豆腐": "tofu", "豆": "beans", "土豆": "potato", "土豆丝": "shredded potato", "茄子": "eggplant", "青菜": "greens",
        "白菜": "napa cabbage", "包菜": "cabbage", "西兰花": "broccoli", "菠菜": "spinach", "蘑菇": "mushrooms", "香菇": "shiitake",
        "木耳": "wood-ear mushroom", "藕": "lotus root", "黄瓜": "cucumber", "花生": "peanuts", "蛋": "egg", "鸡蛋": "egg",
        "饭": "rice", "米饭": "rice", "炒饭": "fried rice", "面": "noodles", "面条": "noodles", "粉": "rice noodles", "饺子": "dumplings",
        "包子": "buns", "馒头": "steamed bun", "饼": "pancake", "粥": "congee", "汤": "soup", "锅": "pot", "全": "whole",
        "小": "small", "大": "large", "份": "portion", "例": "regular", "啤酒": "beer", "茶": "tea", "可乐": "cola", "饮料": "drinks",
        "凉菜": "cold dishes", "热菜": "hot dishes", "主食": "staples", "素菜": "vegetable dishes", "荤菜": "meat dishes",
    ]

    static func needsTranslation(_ lines: [String], reader: String = Localizer.shared.language) -> Bool {
        let letters = lines.joined().filter(\.isLetter)
        guard !letters.isEmpty else { return false }
        let foreign = letters.filter { c in c.unicodeScalars.contains { $0.value > 0x24F } }.count
        guard Double(foreign) / Double(letters.count) > 0.3 else { return false }
        let lang = String(reader.prefix(2))
        if ["zh", "ja", "ko"].contains(lang) { return cjkShare(lines.joined()) < 0.3 }
        return true
    }

    /// The menu's language, so the translation never fails on "couldn't tell what language this is" with short names.
    static func language(of lines: [String]) -> Locale.Language? {
        let r = NLLanguageRecognizer()
        r.processString(lines.joined(separator: "\n"))
        guard let l = r.dominantLanguage, l != .undetermined else { return nil }
        return Locale.Language(identifier: l.rawValue)
    }

    /// Chinese, Japanese or Korean writing — no spaces between words, no capital letters.
    static func isCJK(_ c: Character) -> Bool {
        c.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x3400...0x9FFF).contains($0.value) || (0xAC00...0xD7AF).contains($0.value) || (0xF900...0xFAFF).contains($0.value) }
    }
    static func cjkShare(_ s: String) -> Double {
        let letters = s.filter(\.isLetter)
        return letters.isEmpty ? 0 : Double(letters.filter(isCJK).count) / Double(letters.count)
    }

    /// A line that isn't part of the menu: a web address, a photo-site watermark, a stray scrap of OCR noise.
    static func isJunk(_ line: String) -> Bool {
        let low = line.lowercased()
        if low.contains("www.") || low.contains("http") || low.range(of: #"\.(com|net|cn|org)\b"#, options: .regularExpression) != nil { return true }
        if low.range(of: #"^(by|no)\s*[:：]"#, options: .regularExpression) != nil || low.range(of: #"\bno[:：]\s*\d{6,}"#, options: .regularExpression) != nil { return true }
        let useful = line.filter { $0.isLetter || $0.isNumber }.count
        let all = line.filter { !$0.isWhitespace }.count
        return all == 0 || Double(useful) / Double(all) < 0.5
    }

    static func parse(_ rawLines: [String]) -> [Item] {
        var items: [Item] = []
        var section = ""
        var heading: (line: String, previous: String)?      // a short line just taken as a section heading
        var headingRun = false                              // the last line was a heading too ("特色篇" then "巫山烤全鱼")
        for raw in rawLines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.count >= 2 || (line.count == 1 && line.first.map(isCJK) == true), !isJunk(line) else { continue }
            let cjk = cjkShare(line) > 0.5
            if cjk, splitPrice(line) == nil {
                let core = line.trimmingCharacters(in: CharacterSet(charactersIn: "()（）[]【】 "))
                if line.first.map({ "(（【[".contains($0) }) == true || core.hasPrefix("以上") || core.count > 9 {
                    // "(泡椒、香辣、麻辣、豆鼓)" or "以上套餐配送汤…": about the section, not a dish.
                    items.append(Item(section: section, name: core, detail: "", price: nil, priceText: "", flags: [], note: true))
                } else {
                    let previous = section
                    section = headingRun && !section.isEmpty ? section + " · " + core : core
                    heading = (core, previous); headingRun = true
                }
                continue
            }
            headingRun = false
            if let p = splitPrice(line) {
                if p.name.filter(\.isLetter).count >= 2 {
                    items.append(Item(section: section, name: p.name, detail: "", price: p.value, priceText: p.shown, flags: []))
                } else if let h = heading {
                    // "Grilled Salmon" then "14.50" on the next line: that heading was really a dish.
                    section = h.previous
                    items.append(Item(section: section, name: h.line, detail: "", price: p.value, priceText: p.shown, flags: []))
                } else if let last = items.indices.last, items[last].price == nil {
                    items[last].price = p.value; items[last].priceText = p.shown
                }
                heading = nil
                continue
            }
            let letters = line.filter(\.isLetter).count
            guard letters >= 2 else { continue }
            let words = line.split(separator: " ").count
            let isCaps = line == line.uppercased() && letters >= 3
            let looksHeading = (isCaps || words <= 3) && !line.hasSuffix(",") && line.first?.isUppercase == true && words <= 4
            if looksHeading && (items.last?.price != nil || items.isEmpty || isCaps) {
                heading = (line, section)
                section = isCaps ? line.capitalized : line
            } else if let last = items.indices.last, items[last].price != nil,
                      line.first?.isLowercase == true || words >= 4 || items[last].detail.isEmpty {
                items[last].detail += (items[last].detail.isEmpty ? "" : " ") + line
                heading = nil
            } else {
                items.append(Item(section: section, name: line, detail: "", price: nil, priceText: "", flags: []))
                heading = nil
            }
        }
        return items.map { i in
            var i = i
            guard !i.note else { return i }
            let words = i.name + " " + i.detail
            i.flags = flags(words)
            if cjkShare(words) > 0.3 { i.caution = cjkFlags(words).caution }
            return i
        }
    }

    /// The menu's currency mark, if it shows one.
    static func currency(in lines: [String]) -> String? {
        let all = lines.joined(separator: " ").lowercased()
        let kana = all.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) }
        let han = all.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
        let hangul = all.unicodeScalars.contains { (0xAC00...0xD7AF).contains($0.value) }
        if all.contains("元") || all.contains("rmb") || all.contains("cny") || all.contains("块") { return "CNY" }
        if all.contains("円") { return "JPY" }
        if all.contains("₩") || all.contains("원") { return "KRW" }
        if all.contains("¥") || all.contains("￥") { return kana || !han ? "JPY" : "CNY" }   // ¥ is yen in Japan, yuan in China
        if hangul, all.range(of: #"\d{4,}"#, options: .regularExpression) != nil { return "KRW" }
        if all.contains("₺") || all.range(of: #"\d\s?tl\b"#, options: .regularExpression) != nil { return "TRY" }
        for (mark, code) in [("€", "EUR"), ("£", "GBP"), ("₹", "INR"), ("฿", "THB"), ("chf", "CHF"), ("zł", "PLN"), (" kr", "SEK"), ("$", "USD")]
        where all.contains(mark) { return code }
        return nil
    }

    // MARK: - What's in it

    static let words: [Flag: [String]] = [
        .pork: ["pork", "ham", "bacon", "prosciutto", "pancetta", "chorizo", "salami", "sausage", "pepperoni", "lardon", "guanciale",
                "cerdo", "jamón", "jamon", "tocino", "lomo", "porc", "jambon", "lardons", "maiale", "speck", "schwein", "schinken",
                "speck", "porco", "presunto", "linguiça"],
        .beef: ["beef", "steak", "veal", "brisket", "burger", "ternera", "res", "vacuno", "bœuf", "boeuf", "veau", "entrecôte",
                "manzo", "vitello", "bistecca", "rind", "rindfleisch", "kalb", "vaca", "bife"],
        .chicken: ["chicken", "poultry", "pollo", "poulet", "volaille", "huhn", "hähnchen", "hühnchen", "frango", "galinha"],
        .meat: ["lamb", "duck", "turkey", "goat", "venison", "rabbit", "meat", "mutton", "cordero", "pato", "carne", "pavo", "agneau",
                "canard", "viande", "dinde", "lapin", "agnello", "anatra", "tacchino", "lamm", "ente", "fleisch", "pute", "borrego", "pato"],
        .fish: ["fish", "salmon", "tuna", "cod", "anchovy", "anchovies", "sardine", "trout", "bass", "halibut", "haddock", "mackerel",
                "pescado", "salmón", "atún", "bacalao", "merluza", "poisson", "saumon", "thon", "cabillaud", "pesce", "salmone", "tonno",
                "merluzzo", "acciughe", "fisch", "lachs", "thunfisch", "kabeljau", "peixe", "atum", "bacalhau"],
        .shellfish: ["shrimp", "prawn", "prawns", "crab", "lobster", "scallop", "clam", "clams", "mussel", "mussels", "oyster", "oysters",
                     "squid", "calamari", "octopus", "gambas", "langostino", "cangrejo", "mejillones", "almejas", "calamar", "pulpo",
                     "crevettes", "crabe", "homard", "moules", "huîtres", "gamberi", "gamberetti", "cozze", "vongole", "polpo",
                     "garnelen", "krabbe", "hummer", "muscheln", "camarão", "camarões", "lagosta", "lula", "polvo"],
        .dairy: ["cheese", "cream", "butter", "milk", "yogurt", "yoghurt", "parmesan", "mozzarella", "feta", "ricotta", "paneer",
                 "queso", "nata", "mantequilla", "leche", "fromage", "crème", "beurre", "lait", "formaggio", "panna", "burro", "latte",
                 "käse", "sahne", "butter", "milch", "queijo", "natas", "manteiga", "leite"],
        .egg: ["egg", "eggs", "omelette", "omelet", "mayonnaise", "mayo", "aioli", "huevo", "huevos", "tortilla", "œuf", "oeuf", "oeufs",
               "uovo", "uova", "frittata", "ei", "eier", "ovo", "ovos"],
        .nuts: ["nut", "nuts", "peanut", "peanuts", "almond", "almonds", "walnut", "cashew", "pistachio", "hazelnut", "pecan", "pesto",
                "satay", "praline", "cacahuete", "maní", "almendra", "nuez", "nueces", "arachide", "cacahuète", "amande", "noix",
                "noisette", "arachidi", "mandorle", "noci", "nocciole", "pistacchio", "erdnuss", "mandel", "walnuss", "haselnuss",
                "amendoim", "amêndoa", "noz"],
        .gluten: ["bread", "pasta", "noodle", "noodles", "flour", "wheat", "breaded", "batter", "crumb", "couscous", "pizza", "toast",
                  "croutons", "tempura", "empanado", "rebozado", "fideos", "pain", "pâtes", "pané", "pane", "impanato",
                  "brot", "nudeln", "paniert", "pão", "massa", "spaghetti", "penne", "lasagna", "lasagne", "ravioli", "gnocchi"],
        .spicy: ["spicy", "chili", "chilli", "jalapeño", "jalapeno", "sriracha", "harissa", "nduja", "picante", "piquant",
                 "épicé", "piccante", "scharf", "apimentado", "🌶", "🌶️"],
    ]

    // Chinese, Japanese and Korean dish words. Matched inside the name (these scripts have no spaces), after the
    // well-known traps are taken out first: 牛蛙 is bullfrog (not beef), 田鸡 is frog (not chicken), 鸡蛋 is egg,
    // 鱼香 is a sauce with no fish in it, 鱿鱼/墨鱼/章鱼 are squid, cuttlefish and octopus.
    static let cjkTraps: [(String, String)] = [("牛蛙", "蛙"), ("蜗牛", "螺"), ("田鸡", "蛙"), ("鸡蛋", "蛋"), ("鱼香", "※"),
                                               ("鱿鱼", "鱿"), ("墨鱼", "鱿"), ("章鱼", "鱿"), ("夫妻肺片", "牛肺片"), ("宫保", "花生辣"),
                                               ("蛋炒饭", "蛋饭"), ("凤爪", "鸡爪"), ("鱼翅", "鱼")]
    static let cjkWords: [Flag: [String]] = [
        .pork: ["猪", "排骨", "肥肠", "腊肉", "火腿", "培根", "腰花", "肝尖", "猪肝", "耳丝", "肚丝", "丸子", "叉烧", "回锅", "锅包肉",
                "东坡", "狮子头", "卤肉", "红烧肉", "白肉", "豚", "ポーク", "とんかつ", "チャーシュー", "돼지", "삼겹살", "제육", "족발"],
        .beef: ["牛", "ビーフ", "소고기", "불고기", "쇠고기"],
        .chicken: ["鸡", "翅", "鶏", "鳥", "チキン", "唐揚げ", "닭", "치킨"],
        .meat: ["羊", "鸭", "鹅", "兔", "蛙", "驴", "鹿", "鴨", "양고기", "오리"],
        .fish: ["鱼", "鲈", "鳕", "鲑", "鳝", "鳗", "鱼头", "魚", "鮭", "鮪", "まぐろ", "サーモン", "刺身", "생선", "연어", "참치"],
        .shellfish: ["虾", "蟹", "贝", "蛤", "蚝", "牡蛎", "鱿", "螺", "蚌", "海鲜", "三鲜", "海参", "海老", "えび", "エビ", "かに", "カニ",
                     "イカ", "タコ", "새우", "게살", "조개", "오징어", "낙지", "해물"],
        .egg: ["蛋", "卵", "玉子", "たまご", "계란", "달걀"],
        .dairy: ["奶", "芝士", "奶酪", "黄油", "乳", "チーズ", "バター", "クリーム", "치즈", "우유"],
        .nuts: ["花生", "腰果", "核桃", "杏仁", "坚果", "ナッツ", "ピーナッツ", "くるみ", "アーモンド", "땅콩", "호두", "견과"],
        .gluten: ["面", "饺", "包子", "馒头", "饼", "面包", "烤麸", "麺", "うどん", "ラーメン", "そば", "パン", "天ぷら", "면", "국수", "라면", "만두", "빵", "튀김"],
        .spicy: ["辣", "剁椒", "泡椒", "尖椒", "椒麻", "水煮", "口水", "红油", "川味", "重庆", "辛", "キムチ", "매운", "김치", "고추"],
    ]
    /// Vegetables, tofu and the like: when a dish names one of these and nothing from an animal, it's meat-free on paper.
    static let cjkPlants = ["豆腐", "素", "青菜", "白菜", "菠菜", "黄瓜", "茄子", "土豆", "豆角", "苦瓜", "冬瓜", "西红柿", "番茄", "萝卜", "蘑菇",
                            "香菇", "金针菇", "海带", "笋", "花生米", "凉粉", "拉皮", "粉丝", "蕨根粉", "豆花", "老虎菜", "西兰花", "豆芽",
                            "泡菜", "やさい", "野菜", "두부", "야채", "채소"]
    /// Dishes usually cooked with meat their names don't mention.
    static let cjkCautions: [(String, String)] = [
        ("麻婆", "Mapo dishes are usually made with minced beef or pork"),
        ("家常", "Home-style dishes are often cooked with pork"),
        ("※", "Yu-xiang (\u{201C}fish-fragrant\u{201D}) sauce has no fish, but it's usually cooked with pork"),
        ("合菜", "Usually stir-fried with pork"),
        ("干煸", "Dry-fried dishes often include minced pork"),
        ("豆花", "Sometimes topped with minced meat"),
    ]

    /// What the name says is in it, in Chinese, Japanese or Korean; plus why to ask, when the name hides something.
    static func cjkFlags(_ text: String) -> (flags: Set<Flag>, caution: String?) {
        var t = text
        for (trap, swap) in cjkTraps { t = t.replacingOccurrences(of: trap, with: swap) }
        var out = Set<Flag>()
        for (flag, list) in cjkWords where list.contains(where: { t.contains($0) }) { out.insert(flag) }
        // In Chinese dish names a bare 肉 ("meat") means pork, once the other meats are taken out.
        var rest = t
        for m in ["牛肉", "羊肉", "鸡肉", "鸭肉", "鱼肉", "兔肉", "蟹肉", "虾肉"] { rest = rest.replacingOccurrences(of: m, with: "") }
        if rest.contains("肉") { out.insert(.pork) }
        if !out.isDisjoint(with: [.pork, .beef, .chicken]) { out.insert(.meat) }
        let animal: Set<Flag> = [.meat, .pork, .beef, .chicken, .fish, .shellfish]
        if out.isDisjoint(with: animal), cjkPlants.contains(where: { t.contains($0) }) {
            out.insert(.vegetarian)
            if out.isDisjoint(with: [.egg, .dairy]) { out.insert(.vegan) }
        }
        let caution = out.isDisjoint(with: animal) ? cjkCautions.first { t.contains($0.0) }?.1 : nil
        if caution != nil { out.remove(.vegetarian); out.remove(.vegan) }
        return (out, caution)
    }

    static func flags(_ text: String) -> Set<Flag> {
        if cjkShare(text) > 0.3 { return cjkFlags(text).flags.union(latinFlags(text)) }
        return latinFlags(text)
    }

    private static func latinFlags(_ text: String) -> Set<Flag> {
        // "Fish-fragrant" / "fish-flavored" (yu-xiang) sauce has no fish in it.
        let lower = text.lowercased().replacingOccurrences(of: #"fish[- ](fragrant|flavou?red|flavou?r)"#, with: "yuxiang", options: .regularExpression)
        let tokens = Set(lower.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty })
        var out = Set<Flag>()
        for (flag, list) in words where list.contains(where: { w in w.count <= 4 ? tokens.contains(w) : (tokens.contains(w) || lower.contains(w)) }) {
            out.insert(flag)
        }
        if out.contains(.pork) || out.contains(.beef) || out.contains(.chicken) { out.insert(.meat) }
        // Menu markers: (v) vegetarian, (vg)/(ve) vegan.
        if lower.range(of: #"\((vg|ve|vegan)\)|\bvegan\b|🌱"#, options: .regularExpression) != nil { out.insert(.vegan); out.insert(.vegetarian) }
        // Plant dishes: named vegetables, pulses or tofu with nothing from an animal.
        let plants = ["vegetable", "vegetables", "veggie", "veggies", "tofu", "mushroom", "mushrooms", "spinach", "falafel", "hummus",
                      "lentil", "lentils", "chickpea", "chickpeas", "dal", "dhal", "aubergine", "eggplant", "verduras", "légumes", "verdure", "gemüse"]
        let animal: Set<Flag> = [.meat, .pork, .beef, .chicken, .fish, .shellfish]
        if out.isDisjoint(with: animal), plants.contains(where: { tokens.contains($0) }) {
            out.insert(.vegetarian)
            if out.isDisjoint(with: [.egg, .dairy]) { out.insert(.vegan) }
        }
        if lower.range(of: #"\(v\)|\bvegetarian\b|\bvegetariano\b|\bvégétarien\b|\bvegetarisch\b"#, options: .regularExpression) != nil { out.insert(.vegetarian) }
        return out
    }
}
