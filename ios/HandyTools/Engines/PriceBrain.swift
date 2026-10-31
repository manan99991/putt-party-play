import Foundation
import Vision
import UIKit

/// The brain behind Price Check: it answers "which one is actually cheaper?" by normalizing every
/// price to a common unit, even when the sizes are written in different units (oz vs g, ct vs kg,
/// "2 x 200 ml"). Pure and deterministic, so the comparison can be trusted and unit-tested.
enum PriceBrain {

    enum Base: String { case mass, volume, count }

    /// A parsed size reduced to a canonical base quantity: grams for mass, millilitres for volume,
    /// pieces for count. "1.5 L" → 1500 ml; "16 oz" → 453.6 g; "2 x 200 ml" → 400 ml.
    struct Size: Equatable { let qty: Double; let base: Base }

    private static let massToG: [String: Double] = ["g": 1, "gram": 1, "grams": 1, "kg": 1000, "kilo": 1000, "kilogram": 1000, "kgs": 1000, "oz": 28.3495, "ounce": 28.3495, "ounces": 28.3495, "lb": 453.592, "lbs": 453.592, "pound": 453.592, "pounds": 453.592]
    private static let volToMl: [String: Double] = ["ml": 1, "milliliter": 1, "millilitre": 1, "l": 1000, "liter": 1000, "litre": 1000, "cl": 10, "floz": 29.5735, "floz.": 29.5735, "pt": 473.176, "pint": 473.176, "qt": 946.353, "quart": 946.353, "gal": 3785.41, "gallon": 3785.41, "cup": 236.588, "cups": 236.588]
    private static let countWords: Set<String> = ["ct", "count", "pk", "pack", "packs", "pc", "pcs", "piece", "pieces", "ea", "each", "rolls", "roll", "sheets", "bars", "bar", "tabs", "capsules", "caps"]

    /// Parse a human size string into a canonical quantity. Handles a leading multipack ("3 x 330ml"),
    /// decimals, and "fl oz" vs "oz". Returns nil if there's no recognisable quantity+unit.
    static func parseSize(_ raw: String) -> Size? {
        let s = raw.lowercased().replacingOccurrences(of: "fl oz", with: "floz").replacingOccurrences(of: "fluid ounce", with: "floz")
        // Optional multipack prefix: "2 x 200ml" or "2x200ml".
        var multiplier = 1.0
        var rest = s
        if let m = try? NSRegularExpression(pattern: #"^\s*(\d+(?:\.\d+)?)\s*[x×]\s*(.+)$"#),
           let hit = m.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
           let mr = Range(hit.range(at: 1), in: s), let rr = Range(hit.range(at: 2), in: s) {
            multiplier = Double(s[mr]) ?? 1; rest = String(s[rr])
        }
        guard let m = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*([a-z.]+)"#),
              let hit = m.firstMatch(in: rest, range: NSRange(rest.startIndex..., in: rest)),
              let nr = Range(hit.range(at: 1), in: rest), let ur = Range(hit.range(at: 2), in: rest),
              let n = Double(rest[nr]) else { return nil }
        let unit = String(rest[ur]).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let value = n * multiplier
        if let g = massToG[unit] { return Size(qty: value * g, base: .mass) }
        if let ml = volToMl[unit] { return Size(qty: value * ml, base: .volume) }
        if countWords.contains(unit) { return Size(qty: value, base: .count) }
        return nil
    }

    struct Entry: Identifiable, Equatable { var id = UUID(); var name: String; var price: Double; var sizeText: String }

    struct Ranked: Identifiable { var id: UUID { entry.id }; let entry: Entry; let perBase: Double?; let label: String; let bestValue: Bool; let savingsPct: Double? }

    /// Rank entries by true unit price. Only entries sharing the most common base are compared head to
    /// head; the cheapest per unit is flagged best, with the percentage it saves against the priciest.
    static func rank(_ entries: [Entry]) -> [Ranked] {
        // Compute per-base unit price where the size parses.
        let parsed = entries.map { e -> (Entry, Size?) in (e, parseSize(e.sizeText)) }
        // The base we compare on = the most frequent parseable base.
        let counts = Dictionary(grouping: parsed.compactMap { $0.1?.base }, by: { $0 }).mapValues(\.count)
        let compareBase = counts.max { $0.value < $1.value }?.key

        func perBase(_ e: Entry, _ size: Size?) -> Double? {
            guard let size, size.qty > 0, let compareBase, size.base == compareBase else { return nil }
            switch size.base {
            case .mass, .volume: return e.price / size.qty * 100   // per 100 g / 100 ml
            case .count: return e.price / size.qty                 // each
            }
        }
        let withUnit: [(entry: Entry, perBase: Double?, base: Base?)] = parsed.map { (entry: $0.0, perBase: perBase($0.0, $0.1), base: $0.1?.base) }
        let comparable = withUnit.compactMap(\.perBase)
        let best = comparable.min()
        let worst = comparable.max()

        let unitLabel: (Base?) -> String = { b in
            switch b { case .mass: return "per 100 g"; case .volume: return "per 100 ml"; case .count: return "each"; case .none: return "" }
        }
        return withUnit.map { (e, pb, base) in
            let isBest = pb != nil && pb == best && (comparable.count > 1)
            let savings = (isBest && (worst ?? 0) > 0 && best != worst) ? ((worst! - best!) / worst! * 100) : nil
            return Ranked(entry: e, perBase: pb, label: pb != nil ? unitLabel(compareBase) : "add a size to compare", bestValue: isBest, savingsPct: savings)
        }
    }

    static func money(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }
    /// A compact per-unit string like "$0.42 per 100 g" or "$1.20 each".
    static func perUnitString(_ r: Ranked) -> String {
        guard let pb = r.perBase else { return r.label }
        if r.label == "each" { return "\(money(pb)) each" }
        return "\(money(pb)) \(r.label)"
    }
}

/// Label decoder — OCR a nutrition or ingredients label and translate the confusing parts into plain
/// language: flag common allergens and additives, and surface the serving math retailers bury.
enum LabelDecode {
    struct Flag: Identifiable { let id = UUID(); let term: String; let note: String }
    struct Result { let flags: [Flag]; let servingNote: String?; let rawText: String }

    // A small, plain-language dictionary of things people actually wonder about on a label.
    private static let dictionary: [(terms: [String], note: String)] = [
        (["high fructose corn syrup", "hfcs"], "A cheap liquid sweetener — a form of added sugar."),
        (["aspartame"], "Artificial sweetener; avoid if you have PKU."),
        (["monosodium glutamate", "msg", "e621"], "Flavour enhancer (umami). Safe for most people."),
        (["sodium nitrite", "e250"], "Preserves cured meats and keeps them pink; limit for heart health."),
        (["red 40", "allura red", "e129"], "Synthetic food dye; some parents limit it for kids."),
        (["partially hydrogenated"], "Source of trans fat — the kind to avoid."),
        (["palm oil"], "Saturated fat; also an environmental concern for some shoppers."),
        (["carrageenan"], "Thickener from seaweed; a few people find it hard on digestion."),
        (["xanthan gum", "guar gum"], "Common thickener; generally well tolerated."),
        (["natural flavors", "natural flavours"], "A catch-all — the exact ingredients aren't disclosed."),
        (["maltodextrin"], "A starch-based filler/sweetener with a high glycaemic index."),
        (["soy", "soya"], "Common allergen."),
        (["milk", "whey", "casein", "lactose"], "Contains dairy — an allergen and not vegan."),
        (["wheat", "gluten", "barley", "rye"], "Contains gluten."),
        (["peanut", "tree nut", "almond", "cashew", "hazelnut"], "Nut allergen."),
        (["egg", "albumen"], "Contains egg — an allergen."),
        (["shellfish", "crustacean", "shrimp", "crab"], "Shellfish allergen."),
    ]

    static func decode(_ text: String) -> Result {
        let low = text.lowercased()
        var flags: [Flag] = []
        for entry in dictionary {
            if let hit = entry.terms.first(where: { low.contains($0) }) {
                flags.append(Flag(term: hit, note: entry.note))
            }
        }
        return Result(flags: flags, servingNote: servingMath(low), rawText: text)
    }

    /// "6 servings per container" + "150 calories per serving" → the number people actually eat.
    private static func servingMath(_ low: String) -> String? {
        func num(_ pattern: String) -> Double? {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: low, range: NSRange(low.startIndex..., in: low)),
                  let r = Range(m.range(at: 1), in: low) else { return nil }
            return Double(low[r])
        }
        let servings = num(#"(\d+(?:\.\d+)?)\s*servings?\s*per\s*container"#)
        let perServ = num(#"(\d+(?:\.\d+)?)\s*(?:cal|calories)"#)
        guard let s = servings, s > 1, let c = perServ else { return nil }
        return "Heads up: \(Int(s)) servings per container. If you finish it, that's \(Int(s * c)) calories, not \(Int(c))."
    }
}
