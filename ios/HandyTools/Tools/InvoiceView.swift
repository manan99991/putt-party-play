import SwiftUI
import UIKit
import PDFKit

/// Invoices & Quotes (Business tab). One screen: what's still unpaid at the top, then the form — your details (typed
/// once, remembered), who it's for, the lines, tax, notes — with the totals worked out as you type. Make PDF saves it
/// to the unpaid list and hands you a Send button. Free makes 3 a month; Tenzy Pro, unlimited.
struct InvoiceView: View {
    @ObservedObject private var book = InvoiceStore.shared
    @EnvironmentObject private var pro: StoreManager

    private struct Draft: Identifiable, Equatable { var id = UUID(); var what = ""; var qty = "1"; var price = "" }
    private enum DueIn: Int, CaseIterable {
        case now = 0, week = 7, twoWeeks = 14, month = 30
        var label: String {
            switch self {
            case .now: return "On receipt"
            case .week: return "7 days"
            case .twoWeeks: return "14 days"
            case .month: return "30 days"
            }
        }
    }

    @State private var kind: Invoice.Kind = .invoice
    @AppStorage(InvoiceStore.fromKey) private var from = ""
    @AppStorage(InvoiceStore.currencyKey) private var currency = Invoice.localCurrency
    @AppStorage(InvoiceStore.taxKey) private var tax = ""
    @State private var to = ""
    @State private var dueIn: DueIn = .twoWeeks
    @State private var lines: [Draft] = [Draft()]
    @State private var notes = ""
    @State private var ready: Invoice.Doc?
    @State private var readyURL: URL?
    @State private var readyPage: UIImage?
    @State private var seeded = false

    private var premium: Bool { pro.isPremium || Launch.uitest || Launch.screenshots || AppEnv.isTestBuild }
    private var left: Int? { Invoice.left(made: book.madeThisMonth, premium: premium) }

    var body: some View {
        ToolPage(title: "Invoices & Quotes", subtitle: "Make a clean PDF invoice or quote, send it, and see what's still unpaid.") {
            HowTo("invoice", [
                "Type your business details once — Tenzy remembers them.",
                "Add who it's for and what you did or sold. Totals work themselves out.",
                "Make PDF, then Send it by Mail, Messages or any app.",
                "Unpaid invoices stay at the top until you mark them paid. Home tells you when one is overdue.",
            ])
            if !book.unpaid.isEmpty { unpaidList }
            if let ready, let readyURL { readyCard(ready, readyURL) } else { form }
        }
        .onAppear(perform: seedForTests)
    }

    // MARK: Unpaid

    private var unpaidList: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Waiting to be paid")).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary)
            ForEach(book.unpaid) { d in
                HStack(spacing: HandySpacing.s8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.who.isEmpty ? d.number : d.who).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).lineLimit(1)
                        Text(dueLine(d)).font(HandyFont.micro)
                            .foregroundStyle(d.overdue() ? HandyColor.danger : HandyColor.textSecondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(Invoice.money(d.total, currency: d.currency)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Button { withAnimation { book.setPaid(d.id, true) }; HandyHaptics.success() } label: {
                        Text(L("Paid")).font(.system(size: 13, weight: .semibold))
                    }
                    .compactButton()
                    .accessibilityIdentifier("invoice-paid-\(d.number)")
                }
                .contentShape(Rectangle())
                .onTapGesture { show(d) }
                .contextMenu {
                    Button { show(d) } label: { Label(L("Send again"), systemImage: "square.and.arrow.up") }
                    Button(role: .destructive) { book.remove(d.id) } label: { Label(L("Delete"), systemImage: "trash") }
                }
            }
        }
        .cardStyle()
    }

    private func dueLine(_ d: Invoice.Doc) -> String {
        guard let due = d.due else { return d.number }
        let when = due.formatted(.dateTime.month(.abbreviated).day())
        return d.number + " · " + (d.overdue() ? L("Overdue since") : L("Due")) + " " + when
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s8) {
                HChip(text: L("Invoice"), selected: kind == .invoice) { kind = .invoice }.accessibilityIdentifier("invoice-kind-invoice")
                HChip(text: L("Quote"), selected: kind == .quote) { kind = .quote }.accessibilityIdentifier("invoice-kind-quote")
                Spacer()
                Text(Invoice.nextNumber(kind, after: book.docs)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }

            field(L("From — your name or business, phone, email"), text: $from, lines: 3, id: "invoice-from")
            field(kind == .quote ? L("For — customer name and address") : L("Bill to — customer name and address"), text: $to, lines: 3, id: "invoice-to")

            Text(L("What for")).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).padding(.top, 4)
            ForEach($lines) { $l in
                let i = lines.firstIndex(of: l) ?? 0
                VStack(alignment: .leading, spacing: 6) {
                    TextField(L("Work done or item sold"), text: $l.what, axis: .vertical).lineLimit(1...3).invoiceField()
                        .accessibilityIdentifier("invoice-what-\(i)")
                    HStack(spacing: HandySpacing.s8) {
                        TextField(L("Qty"), text: $l.qty).keyboardType(.decimalPad).invoiceField().frame(width: 64)
                            .accessibilityIdentifier("invoice-qty-\(i)")
                        TextField(L("Price each"), text: $l.price).keyboardType(.decimalPad).invoiceField()
                            .accessibilityIdentifier("invoice-price-\(i)")
                        Text(Invoice.money(amount(l), currency: currency)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                            .lineLimit(1).minimumScaleFactor(0.7).frame(minWidth: 70, alignment: .trailing)
                        if lines.count > 1 {
                            Button { lines.removeAll { $0.id == l.id } } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(HandyColor.textSecondary).frame(width: 32, height: 44)
                            }
                            .buttonStyle(.plain).accessibilityLabel(L("Remove line"))
                        }
                    }
                }
            }
            Button { lines.append(Draft()) } label: { Label(L("Add a line"), systemImage: "plus") }
                .textButton().accessibilityIdentifier("invoice-addline")

            HStack(spacing: HandySpacing.s8) {
                TextField(L("Tax %"), text: $tax).keyboardType(.decimalPad).invoiceField().frame(width: 90)
                Menu {
                    ForEach(Array(Set(Invoice.currencies + [Invoice.localCurrency])).sorted(), id: \.self) { c in
                        Button(c) { currency = c }
                    }
                } label: {
                    Label(currency, systemImage: "dollarsign.circle").font(HandyFont.caption).frame(minHeight: 44)
                }
                Spacer()
                if kind == .invoice {
                    Menu {
                        ForEach(DueIn.allCases, id: \.self) { d in Button(L(d.label)) { dueIn = d } }
                    } label: {
                        Label(L("Due") + ": " + L(dueIn.label), systemImage: "calendar").font(HandyFont.caption).frame(minHeight: 44)
                    }
                } else {
                    Text(L("Valid for 30 days")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            Text(L("Use the tax rate that applies to you — check with your accountant if you're not sure."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)

            field(L("Notes — payment details, thank-you (optional)"), text: $notes, lines: 3, id: "invoice-notes")

            totals

            if let left, left == 0 {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text(L("You've made 3 this month")).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    Text(L("Tenzy Pro makes as many invoices and quotes as you need.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Button { NotificationCenter.default.post(name: .showPaywall, object: nil) } label: {
                        Text(L("See Tenzy Pro")).frame(maxWidth: .infinity)
                    }.primaryButton()
                }
                .cardStyle()
            } else {
                Button(action: make) {
                    Label(L("Make PDF"), systemImage: "doc.richtext").frame(maxWidth: .infinity)
                }
                .primaryButton().disabled(!canMake).accessibilityIdentifier("invoice-make")
                if let left {
                    Text(String(format: L("%d of 3 free this month left"), left)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                if !canMake {
                    Text(L("Add who it's from, who it's for, and at least one line with a price."))
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
            }
            Text(L("Stays on your phone. Nothing is uploaded.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private var totals: some View {
        let d = doc()
        return VStack(spacing: 4) {
            row(L("Subtotal"), Invoice.money(d.subtotal, currency: currency))
            if d.taxPercent > 0 { row(L("Tax") + " (\(Invoice.qty(d.taxPercent))%)", Invoice.money(d.tax, currency: currency)) }
            row(L("Total"), Invoice.money(d.total, currency: currency), strong: true)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("invoice-total")
    }

    private func row(_ a: String, _ b: String, strong: Bool = false) -> some View {
        HStack {
            Text(a).font(strong ? HandyFont.bodyStrong : HandyFont.caption).foregroundStyle(strong ? HandyColor.textPrimary : HandyColor.textSecondary)
            Spacer()
            Text(b).font(strong ? .system(size: 20, weight: .bold) : HandyFont.caption).foregroundStyle(HandyColor.textPrimary)
        }
    }

    private func field(_ label: String, text: Binding<String>, lines n: Int, id: String) -> some View {
        TextField(label, text: text, axis: .vertical).lineLimit(1...n).invoiceField().accessibilityIdentifier(id)
    }

    // MARK: Ready to send

    private func readyCard(_ d: Invoice.Doc, _ url: URL) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s12) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 28)).foregroundStyle(HandyColor.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: L(d.kind == .quote ? "Quote %@ is ready" : "Invoice %@ is ready"), d.number))
                        .font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary)
                    Text((d.who.isEmpty ? "" : d.who + " · ") + Invoice.money(d.total, currency: d.currency))
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            // The finished page, before it's sent (every output is previewed before Share).
            if let readyPage {
                Image(uiImage: readyPage).resizable().scaledToFit().frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .accessibilityLabel(L("Preview")).accessibilityIdentifier("invoice-preview")
            }
            ShareLink(item: url, subject: Text(Invoice.fileName(d)), preview: SharePreview(Invoice.fileName(d))) {
                Label(L("Send"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }
            .primaryButton().accessibilityIdentifier("invoice-send")
            if d.kind == .invoice && !d.paid {
                Text(L("It's in your unpaid list until you mark it paid.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            Button {
                withAnimation { ready = nil; readyURL = nil }
            } label: { Text(L("Make another")).frame(maxWidth: .infinity) }
                .secondaryButton().accessibilityIdentifier("invoice-another")
        }
        .cardStyle()
    }

    // MARK: Logic

    private func number(_ s: String) -> Double {
        let t = s.filter { "0123456789.,".contains($0) }
        if t.contains(".") { return Double(t.replacingOccurrences(of: ",", with: "")) ?? 0 }
        return Double(t.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private func amount(_ l: Draft) -> Double { Invoice.round2(number(l.qty) * number(l.price)) }

    private func doc() -> Invoice.Doc {
        let now = Date()
        let due = kind == .quote ? Calendar.current.date(byAdding: .day, value: 30, to: now)
            : Calendar.current.date(byAdding: .day, value: dueIn.rawValue, to: now)
        return Invoice.Doc(kind: kind, number: Invoice.nextNumber(kind, after: book.docs), date: now, due: due,
                           from: from.trimmingCharacters(in: .whitespacesAndNewlines), to: to.trimmingCharacters(in: .whitespacesAndNewlines),
                           lines: lines.filter { !$0.what.trimmingCharacters(in: .whitespaces).isEmpty }
                                .map { Invoice.Line(what: $0.what.trimmingCharacters(in: .whitespacesAndNewlines), qty: number($0.qty), price: number($0.price)) },
                           taxPercent: number(tax), notes: notes, currency: currency)
    }

    private var canMake: Bool {
        let d = doc()
        return !d.from.isEmpty && !d.to.isEmpty && d.lines.contains { $0.amount > 0 }
    }

    private func make() {
        let d = doc()
        guard canMake, let url = InvoiceStore.file(for: d) else { return }
        book.add(d)
        HandyHaptics.success()
        readyPage = Self.firstPage(url)
        withAnimation { ready = d; readyURL = url }
        to = ""; lines = [Draft()]; notes = ""
    }

    private func show(_ d: Invoice.Doc) {
        guard let url = InvoiceStore.file(for: d) else { return }
        readyPage = Self.firstPage(url)
        withAnimation { ready = d; readyURL = url }
    }

    private static func firstPage(_ url: URL) -> UIImage? {
        guard let page = PDFDocument(url: url)?.page(at: 0) else { return nil }
        let box = page.bounds(for: .mediaBox)
        return page.thumbnail(of: CGSize(width: box.width * 1.5, height: box.height * 1.5), for: .mediaBox)
    }

    /// UI tests and store screenshots (`-sample`): a filled-in invoice from a made-up business, so the tool shows its
    /// job working. Never touches a real person's saved details.
    private func seedForTests() {
        guard !seeded, Launch.args.contains("-sample"), Launch.uitest || Launch.screenshots else { return }
        seeded = true
        if from.isEmpty { from = "Rivera Home Repair\n(555) 010-2244" }
        to = "Jordan Lee\n14 Maple Ave"
        lines = [Draft(what: "Fix kitchen faucet", qty: "1", price: "120"), Draft(what: "Replacement cartridge", qty: "2", price: "18.50")]
    }
}

private extension View {
    func invoiceField() -> some View {
        padding(HandySpacing.s8).frame(minHeight: 44)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }
}
