import Foundation

/// Reads a photographed menu into dishes — section, name, description, price — and flags what's in each
/// dish from the words on the menu (meat, pork, fish, shellfish, dairy, egg, nuts, gluten, spicy), in
/// English, Spanish, French, Italian, German and Portuguese. Pure text rules, on device; it can only
/// know what the menu says, and the screen says so.
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
        static func == (a: Item, b: Item) -> Bool { a.name == b.name && a.detail == b.detail && a.priceText == b.priceText && a.section == b.section }
    }

    /// What in `item` clashes with the chosen diets.
    static func conflicts(_ item: Item, diets: Set<Diet>) -> [Flag] {
        let avoid = diets.reduce(into: Set<Flag>()) { $0.formUnion($1.avoids) }
        return Flag.allCases.filter { avoid.contains($0) && item.flags.contains($0) }
    }

    // MARK: - Parse

    private static let priceRE = try! NSRegularExpression(
        pattern: #"(?:\.{2,}|\s|^)((?:[€£$¥₹]|usd|eur|gbp|chf)\s?)?(\d{1,4}(?:[.,]\d{1,2})?)\s?(€|£|\$|¥|₹|eur|usd|chf|kr|zł)?\s*$"#,
        options: [.caseInsensitive])

    /// A trailing price on a line: (text before it, the price as shown, its value).
    static func splitPrice(_ line: String) -> (name: String, shown: String, value: Double)? {
        let ns = line as NSString
        guard let m = priceRE.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let num = ns.substring(with: m.range(at: 2))
        let hasSymbol = m.range(at: 1).location != NSNotFound || m.range(at: 3).location != NSNotFound
        let hasDecimals = num.contains(".") || num.contains(",")
        // A bare integer is only a price with a currency mark or when it isn't a year/quantity-looking number.
        guard hasSymbol || hasDecimals || (num.count <= 3 && (Int(num) ?? 0) > 0) else { return nil }
        let name = ns.substring(to: m.range.location).trimmingCharacters(in: CharacterSet(charactersIn: " .·-–—:|\t"))
        guard let v = Double(num.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return (name, ns.substring(with: m.range).trimmingCharacters(in: CharacterSet(charactersIn: " .")), v)
    }

    static func parse(_ rawLines: [String]) -> [Item] {
        var items: [Item] = []
        var section = ""
        var heading: (line: String, previous: String)?      // a short line just taken as a section heading
        for raw in rawLines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.count >= 2 else { continue }
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
        return items.map { var i = $0; i.flags = flags(i.name + " " + i.detail); return i }
    }

    /// The menu's currency mark, if it shows one.
    static func currency(in lines: [String]) -> String? {
        let all = lines.joined(separator: " ").lowercased()
        for (mark, code) in [("€", "EUR"), ("£", "GBP"), ("¥", "JPY"), ("₹", "INR"), ("chf", "CHF"), ("zł", "PLN"), (" kr", "SEK"), ("$", "USD")]
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

    static func flags(_ text: String) -> Set<Flag> {
        let lower = text.lowercased()
        let tokens = Set(lower.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty })
        var out = Set<Flag>()
        for (flag, list) in words where list.contains(where: { w in w.count <= 4 ? tokens.contains(w) : (tokens.contains(w) || lower.contains(w)) }) {
            out.insert(flag)
        }
        if out.contains(.pork) || out.contains(.beef) || out.contains(.chicken) { out.insert(.meat) }
        // Menu markers: (v) vegetarian, (vg)/(ve) vegan.
        if lower.range(of: #"\((vg|ve|vegan)\)|\bvegan\b|🌱"#, options: .regularExpression) != nil { out.insert(.vegan); out.insert(.vegetarian) }
        if lower.range(of: #"\(v\)|\bvegetarian\b|\bvegetariano\b|\bvégétarien\b|\bvegetarisch\b"#, options: .regularExpression) != nil { out.insert(.vegetarian) }
        return out
    }
}
