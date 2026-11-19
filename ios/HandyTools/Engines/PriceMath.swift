import Foundation

/// The shop-and-eat-out sums people get wrong: stacked discounts and splitting a bill. Pure, unit-tested.
enum PriceMath {
    struct Sale: Equatable { let final: Double; let saved: Double; let realPercent: Double; let tax: Double }

    /// Each discount comes off the price left after the one before ("30% then 20%" = 44% off, not 50%).
    static func sale(price: Double, discounts: [Double], taxPercent: Double = 0) -> Sale {
        guard price > 0 else { return Sale(final: 0, saved: 0, realPercent: 0, tax: 0) }
        var p = price
        for d in discounts where d > 0 { p *= max(0, 1 - min(d, 100) / 100) }
        p = (p * 100).rounded() / 100
        let tax = ((p * max(0, taxPercent) / 100) * 100).rounded() / 100
        return Sale(final: p + tax, saved: price - p, realPercent: (1 - p / price) * 100, tax: tax)
    }

    static func percent(_ v: Double) -> String {
        let r = (v * 10).rounded() / 10
        return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
    }

    struct Split: Equatable { let tip: Double; let total: Double; let each: Double; let extra: Double }

    /// Tip, tax and people → what each pays. Rounding up never leaves anyone short; what it adds is shown.
    static func split(subtotal: Double, taxAmount: Double, tipPercent: Double, people: Int, roundUp: Bool, tipOnPreTax: Bool = true) -> Split {
        let n = Double(max(1, people))
        let tipBase = tipOnPreTax ? subtotal : subtotal + taxAmount
        let tip = ((tipBase * max(0, tipPercent) / 100) * 100).rounded() / 100
        let total = subtotal + taxAmount + tip
        let exact = total / n
        let each = roundUp ? exact.rounded(.up) : (exact * 100).rounded(.up) / 100
        return Split(tip: tip, total: total, each: each, extra: max(0, each * n - total))
    }

    static func splitText(_ s: Split, people: Int, tip: Double) -> String {
        "Bill \(PriceBrain.money(s.total)) with \(Int(tip))% tip, split \(people) ways: \(PriceBrain.money(s.each)) each."
    }
}
