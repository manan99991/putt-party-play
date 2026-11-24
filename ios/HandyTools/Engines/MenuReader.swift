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
        /// What the menu marks next to the price: "Gluten-free", "Dairy-free", "Vegetarian", "New".
        var tags: [String] = []
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

    /// Marks printed after a price that aren't part of it: GF / DF (gluten- and dairy-free), V / VG, [New], a stray dash.
    private static let trailingMarks = try! NSRegularExpression(
        pattern: #"(?:\s*(?:\b(?:gf|df|v|vg|ve|gf\s*/\s*df|df\s*/\s*gf|new)\b|\[\s*new\s*\]|\(\s*new\s*\)|[*†‡\-–—]))+\s*$"#, options: [.caseInsensitive])
    /// Size words between two prices ("Single $13.99 Family $39.99", "Full 90 / Half 50", "Small / Large").
    private static let sizeWords = try! NSRegularExpression(
        pattern: #"(?:\s*[/|]\s*|\s+)(?:full|half|single|family|small|medium|large|regular|reg|sm|lg|glass|bottle|cup|bowl|pint|1\s?scoop|2\s?scoops?)\s*[/|]?\s*$"#, options: [.caseInsensitive])

    /// The marks after the price (GF, DF, V, New…), as written, upper-cased.
    static func marks(_ raw: String) -> [String] {
        let ns = raw as NSString
        guard let m = trailingMarks.firstMatch(in: raw, range: NSRange(location: 0, length: ns.length)) else { return [] }
        return ns.substring(with: m.range).uppercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { ["GF", "DF", "V", "VG", "VE", "NEW"].contains($0) }
    }

    /// A trailing price on a line: (text before it, the price as shown, its value). `strict` is for menus whose
    /// prices all carry a currency mark or cents ("$ 11.99"): there a bare number is part of the name — "Chicken 65",
    /// "Gobi 65" are dishes, not prices. A second price on the line (Single / Family, Full / Half) is kept in `shown`.
    static func splitPrice(_ raw: String, strict: Bool = false) -> (name: String, shown: String, value: Double)? {
        // "1 0 元" (letter-spaced menus) is 10元 — only on menus written that way, so "Chicken 65 11.99" stays two numbers.
        var line = raw.contains(where: { "元円원块".contains($0) || isCJK($0) })
            ? spacedDigits.stringByReplacingMatches(in: raw, range: NSRange(location: 0, length: (raw as NSString).length), withTemplate: "") : raw
        line = trailingMarks.stringByReplacingMatches(in: line, range: NSRange(location: 0, length: (line as NSString).length), withTemplate: "")
        line = fixPriceReads(line)
        var shownParts: [String] = []
        var value: Double?
        var rest = line
        var firstHasCents: Bool?
        for _ in 0..<3 {
            let ns = rest as NSString
            guard let m = priceRE.firstMatch(in: rest, range: NSRange(location: 0, length: ns.length)) else { break }
            let num = ns.substring(with: m.range(at: 2))
            let hasSymbol = m.range(at: 1).location != NSNotFound || m.range(at: 3).location != NSNotFound
            let hasDecimals = num.contains(".") || num.contains(",")
            // A bare integer is only a price with a currency mark or when it isn't a year/quantity-looking number.
            guard hasSymbol || hasDecimals || (!strict && num.count <= 3 && (Int(num) ?? 0) > 0) else { break }
            // A second price is written like the first ("$ 13.99 $ 39.99", "Full 90 / Half 50"); "Chicken 65 11.99" isn't two.
            if let f = firstHasCents, f != hasDecimals { break }
            firstHasCents = hasDecimals
            guard let v = Double(num.replacingOccurrences(of: ",", with: ".")) else { break }
            shownParts.insert(ns.substring(with: m.range).trimmingCharacters(in: CharacterSet(charactersIn: " .-–—_~·")), at: 0)
            value = v
            rest = ns.substring(to: m.range.location)
            // "… Full 90 / Half 50": the size word stays with its price; a bare "/" between two prices goes.
            let rns = rest as NSString
            if let s = sizeWords.firstMatch(in: rest, range: NSRange(location: 0, length: rns.length)) {
                shownParts[0] = rns.substring(with: s.range).trimmingCharacters(in: CharacterSet(charactersIn: " /|")) + " " + shownParts[0]
                rest = rns.substring(to: s.range.location)
            }
            rest = rest.trimmingCharacters(in: CharacterSet(charactersIn: " /|"))
            // Only another price right before keeps the loop going ("$ 13.99 $ 39.99").
            if priceRE.firstMatch(in: rest, range: NSRange(location: 0, length: (rest as NSString).length)) == nil { break }
            if rest.filter(\.isLetter).isEmpty { break }
        }
        guard let v = value else { return nil }
        let name = rest.trimmingCharacters(in: CharacterSet(charactersIn: " .·-–—_~:|\t"))
        return (name, shownParts.joined(separator: " / "), v)
    }

    /// The camera's usual slips in a price at the end of a line: "S13.99" or "S 6.99" is $13.99 / $6.99, "S4" is 54,
    /// "5o" is 50, "1l" is 11 — only in a short last word that already has a real digit in it.
    static func fixPriceReads(_ line: String) -> String {
        // "9o" is 90 anywhere on the line ("Full 9o / Half 50"); a lone "S" ending a dish line is a 5.
        var line = line.replacingOccurrences(of: #"(?<=\s\d)[oO](?=\s|$)"#, with: "0", options: .regularExpression)
        if let r = line.range(of: #"(?<=\S\s)[Ss]$"#, options: .regularExpression) {
            let before = line[..<r.lowerBound]
            if before.split(separator: " ").count >= 2, before.suffix(6).allSatisfy({ !$0.isNumber }) { line = String(before) + "5" }
        }
        // "S 15 99" (the point lost) is $15.99; "5 18.99" is a $ read as 5; "S13.99" is $13.99.
        var t = line.replacingOccurrences(of: #"(?<=\s)[S$5]\s?(\d{1,3}) (\d{2})(?=\s|$)"#, with: "\\$$1.$2", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?<=\s)5 (?=\d{1,3}[.,]\d{2}(\s|$))"#, with: "\\$", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(^|\s)S\s?(?=\d{1,4}[.,]\d{2}(\s|$))"#, with: "$1\\$", options: .regularExpression)
        // A two-letter last word that's really a price: "SA" is 54, "Si" is 51, "t2" is 12 (only after a dish name).
        if let r = t.range(of: #"(?<=\S\s)[0-9SsOoIiltA]{2}$"#, options: .regularExpression) {
            let before = t[..<r.lowerBound]
            let word = String(t[r])
            if before.split(separator: " ").count >= 2, before.suffix(6).allSatisfy({ !$0.isNumber }),
               word.contains(where: { $0.isNumber || $0 == "S" || $0 == "A" }) {
                let map: [Character: Character] = ["S": "5", "s": "5", "O": "0", "o": "0", "I": "1", "i": "1", "l": "1", "t": "1", "A": "4"]
                return String(before) + String(word.map { map[$0] ?? $0 })
            }
        }
        guard let r = t.range(of: #"(?<=\s)[0-9OoIlS]{1,4}([.,][0-9OoIlS]{2})?$"#, options: .regularExpression) else { return t }
        let word = String(t[r])
        guard word.contains(where: \.isNumber), word.contains(where: { "OoIlS".contains($0) }) else { return t }
        let fixed = String(word.map { c -> Character in
            switch c { case "O", "o": return "0"; case "I", "l": return "1"; case "S": return "5"; default: return c }
        })
        t.replaceSubrange(r, with: fixed)
        return t
    }

    /// True when nearly every price on the menu has a currency mark or cents — then a bare number is never a price.
    static func strictPrices(_ lines: [String]) -> Bool {
        let priced = lines.compactMap { splitPrice($0) }
        guard priced.count >= 8 else { return false }
        let styled = priced.filter { p in p.shown.contains { "$€£¥￥₹₩₺฿元円원".contains($0) } || p.shown.range(of: #"\d[.,]\d{2}\b"#, options: .regularExpression) != nil }
        return Double(styled.count) >= 0.9 * Double(priced.count)
    }

    // MARK: - Reading the photo

    /// One piece of text the camera read, where it sits on the page (0…1, top-left origin) and how sure it was.
    struct Box: Equatable {
        var text: String
        var rect: CGRect
        var confidence: Float = 1
        /// How the line runs across the page (rise per unit of width, top-left origin): a menu photographed at an
        /// angle has rows that slope, and a price is matched to its dish along that slope, not straight across.
        var slope: CGFloat = 0
    }

    /// Text that is only a price ("50元", "-----18元", "12.50").
    static func isPriceOnly(_ t: String) -> Bool {
        guard let p = splitPrice(t) else { return false }
        return p.name.filter(\.isLetter).count < 2
    }

    /// A section of the photo drawn larger, smoothly, so small print reads like a close-up.
    static func enlarge(_ cg: CGImage, by scale: CGFloat) -> CGImage? {
        let w = Int(CGFloat(cg.width) * scale), h = Int(CGFloat(cg.height) * scale)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    /// The height of the writing itself: a sloped line's box is taller than its letters.
    static func lineHeight(_ b: Box) -> CGFloat { max(b.rect.height - abs(b.slope) * b.rect.width, b.rect.height * 0.35) }

    /// Whether two pieces sit on the same printed row, following the row's slope across the gap between them.
    static func sameRow(_ a: Box, _ b: Box) -> Bool {
        let slope = (a.slope + b.slope) / 2
        let expected = a.rect.midY + slope * (b.rect.midX - a.rect.midX)
        return abs(expected - b.rect.midY) < 0.5 * max(lineHeight(a), lineHeight(b))
    }

    /// The menu as lines in reading order (Manan, 23 Nov: a five-screen Indian board came back as 8 "dishes").
    /// 1. Each lone price joins the dish on its row, following the row's slope, and never jumps over other writing
    ///    (a second price on the row — Single / Family — joins too).
    /// 2. The page is cut into its blocks the way a person reads it: at the empty gutters between columns and the
    ///    gaps between sections (an XY cut), so panels, screens and columns are read one at a time.
    /// 3. Inside a block, pieces on the same row become one line, left to right.
    static func lines(from boxes: [Box]) -> [String] {
        var parts = boxes.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let prices = parts.indices.filter { isPriceOnly(parts[$0].text) }.sorted { parts[$0].rect.minX < parts[$1].rect.minX }
        for pi in prices where !parts[pi].text.isEmpty {
            let price = parts[pi]
            var best: (i: Int, gap: CGFloat)?
            for ni in parts.indices where ni != pi && !parts[ni].text.isEmpty && !isPriceOnly(parts[ni].text) {
                let name = parts[ni]
                let gap = price.rect.minX - name.rect.maxX
                guard gap > -0.02, gap < 0.3, sameRow(name, price) else { continue }
                // A dish that already has its price only takes a second one right beside it (Single / Family).
                if splitPrice(name.text) != nil, gap > 0.06 { continue }
                // The row it lines up with best, then the nearest: on a tight board the rows are barely a line apart.
                let slope = (name.slope + price.slope) / 2
                let off = abs(name.rect.midY + slope * (price.rect.midX - name.rect.midX) - price.rect.midY) / max(lineHeight(name), lineHeight(price))
                let key = off + gap * 2
                if best == nil || key < best!.gap { best = (ni, key) }
            }
            guard let b = best else { continue }
            // Nothing else written between them on that row (a price never jumps into the next column's dish).
            let between = parts.indices.contains { k in
                k != pi && k != b.i && !parts[k].text.isEmpty
                    && parts[k].rect.minX > parts[b.i].rect.maxX - 0.002 && parts[k].rect.maxX < price.rect.minX + 0.002
                    && sameRow(parts[b.i], parts[k])
            }
            if between { continue }
            parts[b.i].text += " " + price.text.trimmingCharacters(in: .whitespaces)
            parts[b.i].rect = parts[b.i].rect.union(price.rect)
            parts[pi].text = ""
        }
        parts = parts.filter { !$0.text.isEmpty }
        return xyCut(parts).flatMap(rows)
    }

    /// Pieces on the same row, joined left to right; rows top to bottom.
    private static func rows(_ block: [Box]) -> [String] {
        var out: [[Box]] = []
        for b in block.sorted(by: { $0.rect.midY < $1.rect.midY }) {
            // Same row AND near something already in it: pieces far apart on one row are two columns, not one line.
            if let i = out.indices.last(where: { i in out[i].contains { sameRow($0, b) && b.rect.minX - $0.rect.maxX < 0.12 && $0.rect.minX - b.rect.maxX < 0.12 } }),
               out.count - i <= 2 { out[i].append(b) }
            else { out.append([b]) }
        }
        return out.map { $0.sorted { $0.rect.minX < $1.rect.minX }.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " ") }
    }

    /// Splits a block of the page at its empty gutters (columns) or, when there are none, at its gaps (sections),
    /// and keeps going inside each part. A "column" that is nothing but prices stays with its dishes.
    private static func xyCut(_ bs: [Box], depth: Int = 0) -> [[Box]] {
        guard bs.count > 1, depth < 24 else { return [bs] }
        let heights = bs.map(lineHeight).sorted()
        let h = heights[heights.count / 2]
        // Wide gaps first (the space between two panels, or above a footer), then columns, then the gaps between lines.
        let big = gaps(bs.map { ($0.rect.minY, $0.rect.maxY) }, minGap: h * 2.5)
        if !big.isEmpty {
            var cuts = [-CGFloat.infinity] + big + [CGFloat.infinity]
            cuts.sort()
            let parts = (0..<(cuts.count - 1)).map { i in bs.filter { $0.rect.midY >= cuts[i] && $0.rect.midY < cuts[i + 1] } }.filter { !$0.isEmpty }
            if parts.count > 1 { return parts.flatMap { xyCut($0, depth: depth + 1) } }
        }
        // A few wide pieces (a banner, a garbled read across two screens) mustn't hide the gutter between columns.
        let extent = (bs.map(\.rect.maxX).max() ?? 1) - (bs.map(\.rect.minX).min() ?? 0)
        let widths = bs.map(\.rect.width).sorted()
        let narrow = bs.filter { $0.rect.width <= max(3 * widths[widths.count / 2], 0.2 * extent) }
        let xs = gaps((narrow.isEmpty ? bs : narrow).map { ($0.rect.minX, $0.rect.maxX) }, minGap: max(0.006, h * 0.6))
        if !xs.isEmpty {
            var parts: [[Box]] = []
            var cuts = [-CGFloat.infinity] + xs + [CGFloat.infinity]
            cuts.sort()
            for i in 0..<(cuts.count - 1) {
                let p = bs.filter { $0.rect.midX >= cuts[i] && $0.rect.midX < cuts[i + 1] }
                if p.isEmpty { continue }
                // A part that's only prices (or a stray mark) belongs to the dishes on its left.
                if let last = parts.indices.last, mostlyPrices(p) || p.allSatisfy({ $0.text.filter(\.isLetter).count < 3 && $0.text.count < 5 }) {
                    parts[last] += p
                } else { parts.append(p) }
            }
            if parts.count > 1 { return parts.flatMap { xyCut($0, depth: depth + 1) } }
        }
        let ys = gaps(bs.map { ($0.rect.minY, $0.rect.maxY) }, minGap: h * 0.9)
        if !ys.isEmpty {
            var cuts = [-CGFloat.infinity] + ys + [CGFloat.infinity]
            cuts.sort()
            let parts = (0..<(cuts.count - 1)).map { i in bs.filter { $0.rect.midY >= cuts[i] && $0.rect.midY < cuts[i + 1] } }.filter { !$0.isEmpty }
            if parts.count > 1 { return parts.flatMap { xyCut($0, depth: depth + 1) } }
        }
        return [bs]
    }

    /// The middles of the empty stretches (at least `minGap` wide) between spans on one axis.
    private static func gaps(_ spans: [(CGFloat, CGFloat)], minGap: CGFloat) -> [CGFloat] {
        var out: [CGFloat] = []
        var reach = -CGFloat.infinity
        for (lo, hi) in spans.sorted(by: { $0.0 < $1.0 }) {
            if reach > -CGFloat.infinity, lo - reach >= minGap { out.append((lo + reach) / 2) }
            reach = max(reach, hi)
        }
        return out
    }

    private static func mostlyPrices(_ p: [Box]) -> Bool { Double(p.filter { isPriceOnly($0.text) }.count) >= 0.6 * Double(p.count) }

    /// Menu words the camera is told to expect, so "Cowboy Ribeye" isn't read as "Comboy Ribeye".
    static let menuVocabulary = [
        "ribeye", "wagyu", "cowboy", "porterhouse", "tomahawk", "filet", "sirloin", "tenderloin", "brisket", "bisque", "chorizo",
        "gruyère", "aioli", "béarnaise", "hollandaise", "remoulade", "rockefeller", "scallops", "scallop", "risotto", "poblano",
        "sautéed", "marsala", "alfredo", "linguine", "chutney", "gochujang", "fusilli", "gouda", "crème", "fraîche", "vinaigrette",
        "caesar", "brussels", "asparagus", "maître", "d'hôtel", "horseradish", "maytag", "duroc", "tartare", "carpaccio", "bruschetta",
        "dosa", "dosas", "idly", "idli", "vada", "uttapam", "upma", "pongal", "sambar", "chutney", "biryani", "pulao", "paneer",
        "tikka", "masala", "tandoori", "naan", "roti", "kulcha", "chapati", "paratha", "parotta", "poori", "bhatura", "chole",
        "samosa", "samosas", "pakora", "pakoras", "bajji", "bonda", "tandoor", "kebabs", "tikkas", "idlis", "naans", "rotis", "manchurian", "manchuria", "gobi", "chaat", "bhel", "puri", "pani", "dahi", "pav",
        "bhaji", "frankie", "kebab", "kabab", "korma", "vindaloo", "kadai", "kadhai", "makhani", "dal", "tadka", "palak", "aloo",
        "chana", "bhindi", "mutter", "methi", "malai", "kofta", "navratan", "chettinad", "mughlai", "gongura", "avakai", "ulavacharu", "ulvacharu", "haryali", "malali",
        "kheema", "keema", "lassi", "falooda", "jalebi", "rasmalai", "rasamalai", "gulab", "jamun", "kulfi", "chai", "bournvita",
        "andhra", "hyderabadi", "dum", "tiffin", "tiffins", "thali", "raita", "papad", "schezwan", "hakka", "chilli", "apollo",
        "pho", "banh", "bulgogi", "bibimbap", "ramen", "udon", "tempura", "teriyaki", "gyoza", "edamame", "katsu", "tonkotsu",
        "quesadilla", "enchilada", "burrito", "taco", "tacos", "guacamole", "carnitas", "barbacoa", "al pastor", "churros",
        "margherita", "carbonara", "bolognese", "arrabbiata", "gnocchi", "tiramisu", "panna", "cotta", "prosciutto", "burrata",
    ]

    /// Read a menu photo on the phone, the most careful way it can (23 Nov: a menu board read at 2,400 px lost most of
    /// its dishes and misread the rest). First the whole page — it settles the menu's language and catches the big
    /// headings. Then, when the print is small, the page again in overlapping tiles at full resolution, each tile read
    /// as if it were its own photo, with the menu's words expected; the pieces are put back together on one page.
    static func read(_ image: UIImage, tiles useTiles: Bool = true) -> [Box] {
        let up = image.normalizedUp()
        guard let full = up.resized(maxDimension: 4800).cgImage, let page = up.resized(maxDimension: 2400).cgImage else { return [] }
        // Languages are named, never guessed, once the page's script is known: guessing read a small English menu
        // board as Arabic (24 Nov, Manan's photo). Every text size counts: Vision's default skips anything under
        // about 1/32 of the page, which was every dish on a menu board.
        let latin = ["en-US", "fr-FR", "it-IT", "de-DE", "es-ES", "pt-BR"]
        func pass(_ cg: CGImage, _ languages: [String]?, minHeight: Float = 0) -> [VNRecognizedTextObservation] {
            let req = VNRecognizeTextRequest()
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            if let languages { req.recognitionLanguages = languages; req.customWords = menuVocabulary } else { req.automaticallyDetectsLanguage = true }
            req.minimumTextHeight = minHeight
            try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
            return req.results ?? []
        }
        /// A piece the camera read, placed on the whole page. `tile` is where the read happened, in page pixels.
        func box(_ obs: VNRecognizedTextObservation, tile: CGRect, page size: CGSize) -> Box? {
            // Of the camera's three best guesses, the one made of the most known menu words ("King Cut", not "King Cot").
            let options = obs.topCandidates(3)
            func known(_ t: String) -> Int { t.lowercased().split { !$0.isLetter }.filter { allMenuWords.contains(String($0)) }.count }
            guard var top = options.first else { return nil }
            for o in options.dropFirst() where known(o.string) > known(top.string) && o.confidence > 0.3 { top = o }
            let r = obs.boundingBox
            let rect = CGRect(x: (tile.minX + r.minX * tile.width) / size.width,
                              y: (tile.minY + (1 - r.maxY) * tile.height) / size.height,
                              width: r.width * tile.width / size.width, height: r.height * tile.height / size.height)
            let dx = (obs.bottomRight.x - obs.bottomLeft.x) * tile.width / size.width
            let dy = -(obs.bottomRight.y - obs.bottomLeft.y) * tile.height / size.height
            return Box(text: top.string, rect: rect, confidence: top.confidence, slope: abs(dx) > 0.0001 ? dy / dx : 0)
        }
        func score(_ b: [Box]) -> Double { b.reduce(0) { $0 + Double($1.confidence) * Double($1.text.filter { $0.isLetter || $0.isNumber }.count) } }
        let pageSize = CGSize(width: page.width, height: page.height)
        let whole = CGRect(origin: .zero, size: pageSize)
        // Which script: a quick guess on the whole page, then the page read properly in the languages that fit.
        let guess = pass(page, nil).compactMap { box($0, tile: whole, page: pageSize) }
        var languages: [String]? = latin
        var best = pass(page, latin).compactMap { box($0, tile: whole, page: pageSize) }
        if cjkShare(guess.map(\.text).joined()) > 0.2 || score(best) < score(guess) * 0.8 {
            for langs in [["zh-Hans", "zh-Hant", "en-US"], ["ja-JP", "en-US"], ["ko-KR", "en-US"]] {
                let next = pass(page, langs).compactMap { box($0, tile: whole, page: pageSize) }
                if score(next) > score(best) * 1.15 { best = next; languages = langs }
            }
            // Another script altogether (Thai, Cyrillic, Arabic…): Vision's own pick reads it best.
            if score(guess) > score(best) * 1.15 { best = guess; languages = nil }
        }
        // Small print (many lines, or short ones): read it again in overlapping sections, each enlarged so its
        // letters are as big as a close-up's.
        let heights = best.map(lineHeight).sorted()
        let median = heights.isEmpty ? 1 : heights[heights.count / 2]
        let W = CGFloat(full.width), H = CGFloat(full.height)
        guard useTiles, best.count >= 30 || median < 0.02 || best.isEmpty, max(W, H) > 1200 else { return best }
        let side = min(max(max(W, H) / 3, 700), 1400)
        let cols = max(1, Int(ceil(W / side))), rowsN = max(1, Int(ceil(H / side)))
        let pad = side * 0.22      // so a line cut at one section's edge is whole in the next
        var tiles: [CGRect] = []
        for r in 0..<rowsN { for c in 0..<cols {
            let x0 = max(0, W * CGFloat(c) / CGFloat(cols) - pad), x1 = min(W, W * CGFloat(c + 1) / CGFloat(cols) + pad)
            let y0 = max(0, H * CGFloat(r) / CGFloat(rowsN) - pad), y1 = min(H, H * CGFloat(r + 1) / CGFloat(rowsN) + pad)
            tiles.append(CGRect(x: x0.rounded(), y: y0.rounded(), width: (x1 - x0).rounded(.down), height: (y1 - y0).rounded(.down)))
        } }
        let fullSize = CGSize(width: W, height: H)
        let lock = NSLock()
        var found: [(box: Box, cut: Bool)] = []
        DispatchQueue.concurrentPerform(iterations: tiles.count) { i in
            let t = tiles[i]
            guard let crop = full.cropping(to: t) else { return }
            // ~2,000 px per section reads best: 2,400 made the board worse (run 4: 21/34 against 30/34).
            let scale = min(2.5, max(1, 2000 / max(t.width, t.height)))
            let input = scale > 1.05 ? (enlarge(crop, by: scale) ?? crop) : crop
            let got: [(Box, Bool)] = pass(input, languages, minHeight: 0.004).compactMap { obs in
                guard let b = box(obs, tile: t, page: fullSize) else { return nil }
                // A piece touching an inner edge of its section was cut off there; another section has it whole.
                let r = obs.boundingBox
                let cut = (r.minX < 0.01 && t.minX > 0) || (r.maxX > 0.99 && t.maxX < W - 1) || (r.maxY > 0.99 && t.minY > 0) || (r.minY < 0.01 && t.maxY < H - 1)
                return (b, cut)
            }
            lock.lock(); found += got; lock.unlock()
        }
        // Whole pieces from the tiles first (sharpest), then the page's own read, then pieces cut at a tile edge;
        // each kept only if nothing kept already covers it.
        func quality(_ b: Box) -> Double { Double(b.confidence) * Double(b.text.filter { $0.isLetter || $0.isNumber }.count) }
        let ranked = found.filter { !$0.cut }.map(\.box).sorted { quality($0) > quality($1) }
            + best.sorted { quality($0) > quality($1) }
            + found.filter(\.cut).map(\.box).sorted { quality($0) > quality($1) }
        var kept: [Box] = []
        for b in ranked where !b.text.trimmingCharacters(in: .whitespaces).isEmpty {
            let a = b.rect.width * b.rect.height
            let covered = kept.contains { k in
                let i = k.rect.intersection(b.rect)
                guard !i.isNull else { return false }
                return i.width * i.height > 0.5 * min(a, k.rect.width * k.rect.height)
            }
            if !covered { kept.append(b) }
        }
        return kept.count >= best.count / 2 ? kept : best
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
        // 23 Nov: the dishes that still showed only characters
        "盆盆": "bowl of", "馋嘴": "mouth-watering", "土匪": "bandit-style", "湘西": "West Hunan", "魔芋": "konjac", "川北": "North Sichuan",
        "凉粉": "jelly noodles", "萝卜皮": "radish skin", "萝卜": "radish", "拍": "smashed", "皮蛋": "century egg", "蒜泥": "mashed-garlic",
        "白肉": "sliced pork", "肝尖": "pork liver", "肝": "liver", "香干": "smoked tofu", "河虾": "river shrimp", "小河虾": "small river shrimp",
        "锅包肉": "crispy sweet-and-sour pork", "夫妻肺片": "beef and tripe in chili oil", "肺片": "sliced offal", "腊": "cured",
        "干": "dried", "丝": "shreds", "片": "slices", "丁": "diced", "球": "balls", "丸": "balls", "块": "pieces", "条": "strips",
        "烩饭": "rice with sauce", "套餐": "set meal", "盖饭": "rice bowl", "盖浇饭": "rice bowl", "拌面": "dressed noodles",
        "汤面": "noodle soup", "米粉": "rice noodles", "乌冬面": "udon", "乌冬": "udon", "粉丝": "glass noodles", "豆芽": "bean sprouts",
        "青椒": "green pepper", "辣椒": "chili pepper", "尖椒": "hot pepper", "杂": "mixed", "三鲜": "three delicacies", "什锦": "assorted",
        "老醋": "aged-vinegar", "醋": "vinegar", "红油": "chili-oil", "油": "oil", "葱爆": "scallion-fried", "爆": "flash-fried",
        "扬州": "Yangzhou", "台式": "Taiwanese", "法式": "French-style", "三杯": "three-cup", "猪扒": "pork chop",
        "鸡汁": "chicken broth", "瘦肉": "lean pork", "香滑": "silky", "荔枝": "lychee", "芗城": "Xiangcheng",
        "花蛤": "clams", "干贝": "dried scallops", "羹": "thick soup", "七彩": "seven-colour", "牛柳": "beef fillet",
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

    /// A line that tells you about the section, not a dish ("Includes 16 oz Pulao Rice", "All selections are gluten-free").
    private static let aboutLine = try! NSRegularExpression(
        pattern: #"^(includes?|including|all (selections|entrees|entrées|items|dishes)|served with|items marked|consuming|for parties|choice of|comes with|add\b|substitute|please|ask your server|available)"#,
        options: [.caseInsensitive])

    /// Tidies a dish name: no leading bullets or veg/non-veg marks the camera read as symbols, no "[New]" tags.
    static func cleanName(_ s: String) -> String {
        var t = s.replacingOccurrences(of: #"\[\s*new\s*\]|\(\s*new\s*\)"#, with: " ", options: [.regularExpression, .caseInsensitive])
        while let f = t.first, !(f.isLetter || f.isNumber || "(（【[$€£¥￥₹₩".contains(f)) { t.removeFirst() }
        while let l = t.last, "•·*:|-–—_~.,".contains(l) || l.isWhitespace { t.removeLast() }
        return t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
    }

    /// Two dishes the camera read as one line ("Surf & Turf 30 Maître d'Hôtel Butter 7"): split after a price that is
    /// followed by a new capitalised name which ends in a price of its own.
    static func splitDishes(_ line: String, strict: Bool) -> [String] {
        let price = strict ? #"(?:[€£$¥₹]\s?\d{1,4}(?:[.,]\d{2})?|\d{1,4}[.,]\d{2})"# : #"(?:[€£$¥₹]\s?)?\d{1,4}(?:[.,]\d{2})?"#
        guard let re = try? NSRegularExpression(pattern: #"(?<=[A-Za-z\)]\s)"# + price + #"(?=\s+\p{Lu}\p{Ll})"#) else { return [line] }
        let ns = line as NSString
        var out: [String] = [], start = 0
        for m in re.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
            let end = m.range.location + m.range.length
            let restOfLine = ns.substring(from: end)
            // Only when what follows is a dish with its own price, not "Chicken 65 Biryani".
            guard splitPrice(restOfLine, strict: strict) != nil, splitPrice(ns.substring(with: NSRange(location: start, length: end - start)), strict: strict) != nil else { continue }
            out.append(ns.substring(with: NSRange(location: start, length: end - start)).trimmingCharacters(in: .whitespaces))
            start = end
        }
        out.append(ns.substring(from: start).trimmingCharacters(in: .whitespaces))
        return out.filter { !$0.isEmpty }
    }

    /// Fixes menu words the camera misread ("Steskhouse Baked Potate" → "Steakhouse Baked Potato", "Comboy" → "Cowboy").
    /// Only toward the menu words Tenzy knows, only when exactly one is that close, and never a word that is already
    /// right: a word the phone's English dictionary knows is left alone. Off the main thread (no dictionary), only
    /// one-letter slips to the menu vocabulary are fixed.
    static func fixWords(_ s: String) -> String {
        guard cjkShare(s) < 0.3 else { return s }
        let dictionary = Thread.isMainThread
        let targets = dictionary ? allMenuWords : Set(menuVocabulary)
        return s.split(separator: " ", omittingEmptySubsequences: false).map { tok -> String in
            let w = String(tok)
            let core = w.trimmingCharacters(in: CharacterSet.letters.inverted)
            let low = core.lowercased()
            guard low.count >= 4, core.allSatisfy(\.isLetter), !targets.contains(low), !allMenuWords.contains(low) else { return w }
            if dictionary, isEnglishWord(low) { return w }
            let limit = dictionary ? (low.count <= 4 ? 1 : 2) : 1
            let plain = folded(low)
            var best: (d: Int, word: String)?
            var tie = false
            for k in targets {
                let kf = folded(k)
                guard abs(kf.count - plain.count) <= limit else { continue }
                let d = editDistance(kf, plain)
                guard d <= limit, kf.first == plain.first || d == 1 else { continue }
                if let b = best {
                    if d < b.d { best = (d, k); tie = false } else if d == b.d, folded(b.word) != kf { tie = true }
                } else { best = (d, k) }
            }
            guard let fix = best?.word, !tie else { return w }
            let cased = core.first?.isUppercase == true ? fix.prefix(1).uppercased() + fix.dropFirst() : fix
            return w.replacingOccurrences(of: core, with: cased)
        }.joined(separator: " ")
    }
    static func folded(_ s: String) -> String { s.folding(options: .diacriticInsensitive, locale: nil) }
    /// A real word in English or any of the menu languages Tenzy reads ("pollo", "queso" and "ajillo" are right as they
    /// are). The phone's own dictionaries, main thread only, where UIKit's checker belongs.
    static func isEnglishWord(_ w: String) -> Bool {
        let checker = UITextChecker()
        let wanted = ["en", "es", "fr", "it", "de", "pt"]
        let langs = UITextChecker.availableLanguages.filter { l in wanted.contains { l.hasPrefix($0) } }
        for lang in langs.isEmpty ? ["en"] : langs {
            let r = checker.rangeOfMisspelledWord(in: w, range: NSRange(location: 0, length: (w as NSString).length), startingAt: 0, wrap: false, language: lang)
            if r.location == NSNotFound { return true }
        }
        return false
    }
    static let allMenuWords: Set<String> = Set(menuVocabulary + commonMenuWords + extraMenuWords.split(separator: " ").map(String.init))
    /// More words menus use, so a misread can be put right (steakhouse, Indian and everyday menus).
    static let extraMenuWords = """
    steakhouse potato potatoes whipped charred roasted poblano risotto cabernet mushrooms sautéed brussels sprouts grilled asparagus \
    scallops duroc braised seared salmon alfredo marsala filet porterhouse kansas strip rack lamb horseradish hollandaise béarnaise \
    crumbles cheese butter onions shrimp jumbo oscar bisque chorizo spinach bourbon barrel wedge caesar romaine croutons bacon cheddar \
    gouda pasta meatballs bison cocktail brie crab cakes oysters rockefeller medley shallots gruyère broth salads pecans vinaigrette \
    tomatoes entrées accompaniments saku block tomahawk center plate breast chop carrots mashed pineapple chutney corn ragout cowboy \
    york tail tender juicy hearty classic favorite glaze linguine served topped baked steamed atlantic fresh warm shaved toasted \
    iceberg heirloom pickled ranch dressing parmesan smoky garnished sherry fraîche half full kulcha rumali chapati seekh afghani \
    achari jeera curd sambar rice idly fried noodles kheema goat chicken fish curry gravies vegetable kofta mushroom shakes juice \
    soda water coffee pastries scoop scoops custard sweets desserts beverages specials special family single breads street ragda \
    papdi tikki sandwich grill bombay snack mirchi punugulu puff appetizers burnt garlic egg
    """
    /// Ordinary menu words, so a fix never turns one real word into another.
    static let commonMenuWords = ["salad", "sauce", "steak", "cheese", "chicken", "garlic", "butter", "onion", "onions", "potato",
        "potatoes", "maine", "cream", "creamy", "shrimp", "lobster", "salmon", "spinach", "mushroom", "mushrooms", "grilled", "baked", "fried",
        "roasted", "smoked", "glazed", "braised", "seared", "house", "special", "indiana", "plate", "bread", "breads", "fresh", "juice",
        "sweet", "spicy", "chili", "chilly", "chilli", "pepper", "peppers", "tomato", "tomatoes", "basil", "lemon", "mango", "honey",
        "maple", "apple", "whiskey", "bourbon", "barrel", "wedge", "lettuce", "bacon", "short", "chops", "strip", "queen", "king",
        "porter", "drawn", "tender", "rich", "juicy", "fruit", "shake", "shakes", "coffee", "water", "sweets", "dessert", "desserts",
        "pastry", "pastries", "scoop", "scoops", "custard", "noodles", "fried", "style", "curry", "goat", "fish", "mutton", "veggie",
        "kitchen", "family", "single", "large", "small", "regular", "medium", "market", "price", "sides", "soups", "soup", "starters",
        "mains", "entrees", "appetizers", "beverages", "drinks", "cocktail", "cocktails", "wines", "beers", "spring", "corn", "carrots",
        "mashed", "sautéed", "sauteed", "signature", "premium", "center", "accompaniments", "dragon", "baby", "pepper", "coriander",
        "cashew", "jalapeno", "jalapeño", "crispy", "street", "sandwich", "sandwiches", "grill", "bombay", "burnt", "indian", "chinese",
        "pollo", "ajillo", "queso", "tarta", "gambas", "patatas", "jamón", "croquetas", "paella", "pulpo", "pescado", "poulet",
        "fromage", "frites", "moules", "canard", "pesce", "funghi", "formaggio", "vitello", "würstel", "schnitzel"]
    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var prev = Array(0...b.count)
        for i in 1...max(1, a.count) where !a.isEmpty {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...max(1, b.count) where !b.isEmpty {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return a.isEmpty ? b.count : (b.isEmpty ? a.count : prev[b.count])
    }

    static func parse(_ input: [String]) -> [Item] {
        var items: [Item] = []
        var section = ""
        var heading: (line: String, previous: String)?      // a short line just taken as a section heading
        var headingRun = false                              // the last line was a heading too ("特色篇" then "巫山烤全鱼")
        let strict = strictPrices(input)
        let rawLines = input.flatMap { splitDishes(fixWords($0.trimmingCharacters(in: .whitespacesAndNewlines)), strict: strict) }
        for raw in rawLines {
            let line = cleanName(raw.trimmingCharacters(in: .whitespacesAndNewlines))
            guard line.count >= 2 || (line.count == 1 && line.first.map(isCJK) == true), !isJunk(line) else { continue }
            let cjk = cjkShare(line) > 0.5
            if cjk, splitPrice(line, strict: strict) == nil {
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
            if aboutLine.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil, splitPrice(line, strict: strict) == nil {
                items.append(Item(section: section, name: line, detail: "", price: nil, priceText: "", flags: [], note: true))
                heading = nil
                continue
            }
            // "Maine Lobster Tail  Market Price": a dish whose price is asked at the table.
            if let r = line.range(of: #"\s+(market price|mp|m\.p\.|seasonal price|ask your server)$"#, options: [.regularExpression, .caseInsensitive]),
               line[..<r.lowerBound].filter(\.isLetter).count >= 3 {
                items.append(Item(section: section, name: cleanName(String(line[..<r.lowerBound])), detail: "", price: nil, priceText: "Market price", flags: []))
                heading = nil
                continue
            }
            if let p = splitPrice(line, strict: strict) {
                if p.name.filter(\.isLetter).count >= 2 {
                    var dish = Item(section: section, name: cleanName(p.name), detail: "", price: p.value, priceText: p.shown, flags: [])
                    dish.tags = marks(line).compactMap { ["GF": "Gluten-free", "DF": "Dairy-free", "V": "Vegetarian", "VG": "Vegan", "VE": "Vegan", "NEW": "New"][$0] }
                        + (raw.range(of: #"\[\s*new\s*\]|\(\s*new\s*\)"#, options: [.regularExpression, .caseInsensitive]) != nil && !marks(line).contains("NEW") ? ["New"] : [])
                    items.append(dish)
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
            // A short capitalised line with no price is a section heading ("Tiffins / Dosas", "Tandoor"); if a lone price
            // follows it, it was a dish after all (handled above).
            if looksHeading {
                heading = (line, section)
                section = isCaps ? line.capitalized : line
            } else if let last = items.indices.last, items[last].price != nil, items[last].detail.count < 160,
                      line.first?.isLowercase == true || words >= 4 || items[last].detail.isEmpty {
                items[last].detail += (items[last].detail.isEmpty ? "" : " ") + line
                heading = nil
            } else {
                items.append(Item(section: section, name: line, detail: "", price: nil, priceText: "", flags: []))
                heading = nil
            }
        }
        // On a menu where every dish is priced, a line with no price and nothing under it isn't a dish.
        if strict { items.removeAll { !$0.note && $0.price == nil && $0.detail.isEmpty && $0.priceText.isEmpty } }
        return items.map { i in
            var i = i
            guard !i.note else { return i }
            let words = i.name + " " + i.detail
            i.flags = flags(words)
            // The menu's own marks: "GF" means no gluten whatever the words suggest; "V"/"VG" say meat-free.
            if i.tags.contains("Gluten-free") { i.flags.remove(.gluten) }
            if i.tags.contains("Dairy-free") { i.flags.remove(.dairy) }
            if i.tags.contains("Vegan") { i.flags.formUnion([.vegan, .vegetarian]) } else if i.tags.contains("Vegetarian") { i.flags.insert(.vegetarian) }
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
