import SwiftUI
import PhotosUI
import UIKit

/// Price Check — three things a shopper needs in the aisle: which size is actually the better deal
/// (true unit price across mixed units), whether the cart still fits the budget, and what the scary
/// words on a label really mean. All instant and on-device.
struct PriceCheckView: View {
    enum Mode: String, CaseIterable { case compare = "Best deal", cart = "Cart vs budget", label = "Decode label" }
    @State private var mode: Mode = .compare

    var body: some View {
        ToolPage(title: "Price Check", subtitle: "Spot the real bargain, keep the cart under budget, and decode any label — right in the aisle.") {
            HowTo("pricecheck", [
                "Best deal: enter a couple of prices and sizes — it shows the true cost per unit.",
                "Cart vs budget: tap items in as you shop and watch what's left.",
                "Decode label: snap an ingredients or nutrition label for a plain-language read.",
            ])
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(Mode.allCases, id: \.rawValue) { m in HChip(text: m.rawValue, selected: mode == m) { mode = m } }
            }
            switch mode {
            case .compare: ComparePanel()
            case .cart: CartPanel()
            case .label: LabelPanel()
            }
        }
    }
}

// MARK: Best deal

private struct CompareRow: Identifiable, Equatable { var id = UUID(); var name = ""; var price = ""; var size = "" }

private struct ComparePanel: View {
    @State private var rows: [CompareRow] = [CompareRow(), CompareRow()]

    private var ranked: [PriceBrain.Ranked] {
        PriceBrain.rank(rows.map { PriceBrain.Entry(id: $0.id, name: $0.name, price: Double($0.price) ?? 0, sizeText: $0.size) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            ForEach($rows) { $row in
                VStack(spacing: HandySpacing.s8) {
                    TextField("Name (optional) — e.g. Store brand", text: $row.name).priceField()
                    HStack(spacing: HandySpacing.s8) {
                        TextField("Price", text: $row.price).keyboardType(.decimalPad).priceField()
                        TextField("Size — 500g, 1.5L, 12 ct", text: $row.size).autocorrectionDisabled().priceField()
                    }
                    if let r = ranked.first(where: { $0.entry.id == row.id }) {
                        HStack {
                            Text(PriceBrain.perUnitString(r)).font(HandyFont.caption)
                                .foregroundStyle(r.perBase == nil ? HandyColor.textSecondary : HandyColor.textPrimary)
                            Spacer()
                            if r.bestValue {
                                Label(r.savingsPct.map { "Best — saves \(Int($0))%" } ?? "Best value", systemImage: "checkmark.seal.fill")
                                    .font(HandyFont.micro).foregroundStyle(HandyColor.accent)
                            }
                        }
                    }
                }.cardStyle(padding: HandySpacing.s12)
            }
            HStack {
                Button { rows.append(CompareRow()) } label: { Label("Add item", systemImage: "plus") }.textButton()
                Spacer()
                if rows.count > 2 { Button(role: .destructive) { rows.removeLast() } label: { Label("Remove", systemImage: "minus") }.textButton() }
            }
            Text("Tip: works across units — compare a 16 oz jar against a 500 g one and it still tells you which is cheaper per 100 g.")
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
    }
}

// MARK: Cart vs budget

private struct CartLine: Identifiable, Equatable { var id = UUID(); var name = ""; var price = "" }

private struct CartPanel: View {
    @State private var budget = ""
    @State private var lines: [CartLine] = [CartLine()]

    private var total: Double { lines.reduce(0) { $0 + (Double($1.price) ?? 0) } }
    private var budgetValue: Double? { Double(budget) }
    private var remaining: Double? { budgetValue.map { $0 - total } }
    private var progress: Double {
        guard let b = budgetValue, b > 0 else { return 0 }
        return min(max(total / b, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            TextField("Budget (optional)", text: $budget).keyboardType(.decimalPad).priceField()

            VStack(spacing: HandySpacing.s8) {
                HStack {
                    Text("Running total").font(HandyFont.bodyStrong)
                    Spacer()
                    Text(PriceBrain.money(total)).font(HandyFont.bodyStrong)
                }
                if let remaining {
                    HStack {
                        Text(remaining < 0 ? "Over budget by" : "Left to spend").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        Spacer()
                        Text(PriceBrain.money(abs(remaining))).font(HandyFont.body).foregroundStyle(remaining < 0 ? HandyColor.danger : HandyColor.accent)
                    }
                    ProgressView(value: progress)
                        .tint(remaining < 0 ? HandyColor.danger : HandyColor.accent)
                }
            }.cardStyle(padding: HandySpacing.s12)

            ForEach($lines) { $line in
                HStack(spacing: HandySpacing.s8) {
                    TextField("Item", text: $line.name).priceField()
                    TextField("Price", text: $line.price).keyboardType(.decimalPad).priceField().frame(width: 100)
                }
            }
            HStack {
                Button { lines.append(CartLine()) } label: { Label("Add item", systemImage: "plus") }.textButton()
                Spacer()
                if lines.count > 1 { Button(role: .destructive) { lines.removeLast() } label: { Label("Remove", systemImage: "minus") }.textButton() }
            }
        }
    }
}

// MARK: Decode label

private struct LabelPanel: View {
    @State private var photoItem: PhotosPickerItem?
    @State private var result: LabelDecode.Result?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Snap or choose a label", systemImage: "text.viewfinder").frame(maxWidth: .infinity)
            }.secondaryButton()
            if busy { HStack(spacing: HandySpacing.s8) { ProgressView(); Text("Reading the label…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }

            if let result {
                if let note = result.servingNote {
                    Label(note, systemImage: "exclamationmark.triangle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
                }
                if result.flags.isEmpty {
                    Text(result.rawText.isEmpty ? "Couldn't read that — try a straight, well-lit shot of the ingredients list." : "Nothing on our watch-list stood out. Here's what we read below.")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                } else {
                    Text("On this label").font(HandyFont.bodyStrong)
                    ForEach(result.flags) { f in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.term.capitalized).font(HandyFont.body)
                            Text(f.note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s8)
                    }
                    Text("Guidance, not medical advice. Always check the label itself for allergens.")
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
                if !result.rawText.isEmpty {
                    DisclosureGroup("Text we read") { Text(result.rawText).font(HandyFont.caption).textSelection(.enabled).foregroundStyle(HandyColor.textSecondary) }.font(HandyFont.caption)
                }
            } else if !busy {
                Text("Confused by an ingredients list? Snap it and get a plain-language read of the additives, allergens and the serving-size math.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            busy = true; result = nil
            Task {
                let img = (try? await item.loadTransferable(type: Data.self)).flatMap(UIImage.init)
                photoItem = nil
                guard let img else { await MainActor.run { busy = false }; return }
                let text = await AIEngine.recognizeText(img)
                await MainActor.run { result = LabelDecode.decode(text); busy = false }
            }
        }
    }
}

private extension View {
    func priceField() -> some View {
        padding(HandySpacing.s8)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }
}
