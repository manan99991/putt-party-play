import SwiftUI
import PDFKit

/// Price List (Business tab): what you sell or charge, with prices, in one place. Send a clean PDF to a customer, and
/// pick from the list in Invoices & Quotes so nothing is typed twice. Stays on the phone.
struct PriceListView: View {
    @ObservedObject private var list = PriceListStore.shared
    @AppStorage(InvoiceStore.fromKey) private var from = ""
    @AppStorage(InvoiceStore.currencyKey) private var currency = Invoice.localCurrency
    @State private var name = ""
    @State private var price = ""
    @State private var unit = ""
    @State private var editing: PriceList.Item?
    @State private var note = ""
    @State private var sendURL: URL?
    @State private var sendPage: UIImage?
    @State private var seeded = false

    var body: some View {
        ToolPage(title: "Price List", subtitle: "What you sell or charge, with prices. Send it as a PDF, and pick from it on an invoice.") {
            HowTo("pricelist", [
                "Add what you sell or charge and its price — each, per hour, per visit.",
                "Send the list to a customer as a clean PDF.",
                "In Invoices & Quotes, tap From price list to add a line in one tap.",
            ])
            addCard
            if !list.items.isEmpty { itemsCard; sendCard }
            Text(L("Stays on your phone. Nothing is uploaded.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear(perform: seedForTests)
        .onChange(of: list.items) { _, _ in sendURL = nil; sendPage = nil }
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L(editing == nil ? "Add an item" : "Change this item")).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary)
            TextField(L("What — e.g. Faucet repair, Logo design"), text: $name).bizField().accessibilityIdentifier("price-name")
            HStack(spacing: HandySpacing.s8) {
                TextField(L("Price"), text: $price).keyboardType(.decimalPad).bizField().frame(width: 110).accessibilityIdentifier("price-price")
                Menu {
                    Button(L("No unit")) { unit = "" }
                    ForEach(PriceList.units, id: \.self) { u in Button(L(u)) { unit = u } }
                } label: {
                    Label(unit.isEmpty ? L("Unit (optional)") : L(unit), systemImage: "ruler").font(HandyFont.caption).frame(minHeight: 44)
                }
                Spacer(minLength: 0)
                Text(currency).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            HStack(spacing: HandySpacing.s8) {
                Button(action: save) { Label(L(editing == nil ? "Add to list" : "Save"), systemImage: "plus.circle.fill").frame(maxWidth: .infinity) }
                    .primaryButton().disabled(!canSave).accessibilityIdentifier("price-add")
                if editing != nil {
                    Button(L("Cancel")) { editing = nil; name = ""; price = ""; unit = "" }.secondaryButton()
                }
            }
        }
        .cardStyle()
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(String(format: L("Your list (%d)"), list.items.count)).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary)
            ForEach(list.items) { i in
                HStack(spacing: HandySpacing.s8) {
                    Text(i.label).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary).lineLimit(2)
                    Spacer(minLength: 4)
                    Text(Invoice.money(i.price, currency: currency)).font(HandyFont.bodyStrong).monospacedDigit().foregroundStyle(HandyColor.textPrimary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture { editing = i; name = i.name; price = String(format: "%g", i.price); unit = i.unit }
                .contextMenu {
                    Button { editing = i; name = i.name; price = String(format: "%g", i.price); unit = i.unit } label: { Label(L("Change"), systemImage: "pencil") }
                    Button(role: .destructive) { list.remove(i.id) } label: { Label(L("Delete"), systemImage: "trash") }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAction(named: L("Delete")) { list.remove(i.id) }
                .accessibilityIdentifier("price-item-\(i.name)")
            }
            Text(L("Tap an item to change it; touch and hold to delete.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .cardStyle()
    }

    private var sendCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Send to a customer")).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary)
            TextField(L("A note at the bottom (optional) — e.g. Prices valid until March"), text: $note, axis: .vertical).lineLimit(1...3).bizField()
            if let sendURL {
                // The page as the customer will see it, before it's sent.
                if let sendPage {
                    Image(uiImage: sendPage).resizable().scaledToFit().frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                        .accessibilityLabel(L("Preview")).accessibilityIdentifier("price-preview")
                }
                ShareLink(item: sendURL, preview: SharePreview("Price list.pdf")) {
                    Label(L("Send"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.primaryButton().accessibilityIdentifier("price-send")
            } else {
                Button(action: makePDF) { Label(L("Make PDF"), systemImage: "doc.richtext").frame(maxWidth: .infinity) }
                    .secondaryButton().accessibilityIdentifier("price-make")
            }
            if from.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(L("Your business name goes at the top: type it once in Invoices & Quotes.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .cardStyle()
    }

    private func number(_ s: String) -> Double {
        let t = s.filter { "0123456789.,".contains($0) }
        if t.contains(".") { return Double(t.replacingOccurrences(of: ",", with: "")) ?? 0 }
        return Double(t.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && number(price) > 0 }

    private func save() {
        guard canSave else { return }
        let n = name.trimmingCharacters(in: .whitespaces)
        if var e = editing { e.name = n; e.price = number(price); e.unit = unit; list.update(e); editing = nil }
        else { list.add(PriceList.Item(name: n, price: number(price), unit: unit)) }
        HandyHaptics.success()
        name = ""; price = ""; unit = ""
    }

    private func makePDF() {
        guard let u = list.file(from: from, currency: currency, note: note) else { return }
        if let page = PDFDocument(url: u)?.page(at: 0) {
            let box = page.bounds(for: .mediaBox)
            sendPage = page.thumbnail(of: CGSize(width: box.width * 1.5, height: box.height * 1.5), for: .mediaBox)
        }
        withAnimation { sendURL = u }
        HandyHaptics.success()
    }

    private func seedForTests() {
        guard !seeded, Launch.args.contains("-sample"), Launch.uitest || Launch.screenshots, list.items.isEmpty else { return }
        seeded = true
        list.add(PriceList.Item(name: "Faucet repair", price: 120, unit: "each"))
        list.add(PriceList.Item(name: "Call-out", price: 65, unit: "per visit"))
        list.add(PriceList.Item(name: "Labour", price: 85, unit: "per hour"))
    }
}
