import SwiftUI

/// The end of "Read a receipt": the receipt as a clean card (shop, date, number, every line with quantity and
/// price, tax, total), a plain check that the numbers add up, and where it should go next — this month's
/// expense sheet, the Receipts vault (with the photo, for warranties and returns), or a real spreadsheet.
struct ReceiptResult: View {
    let photo: UIImage?
    @State private var r: DataGrab.Receipt
    @State private var addedTo: String?
    @State private var kept = false
    @State private var totalText: String

    init(receipt: DataGrab.Receipt, photo: UIImage?) {
        self.photo = photo
        _r = State(initialValue: receipt)
        _totalText = State(initialValue: receipt.total.map { String(format: "%.2f", $0) } ?? "")
    }

    private func money(_ v: Double) -> String { String(format: "%@%.2f", r.currency.isEmpty ? "" : r.currency, v) }
    private var meta: String {
        [r.date.map { $0.formatted(date: .abbreviated, time: .omitted) }, r.number.isEmpty ? nil : "#\(r.number)", r.payment.isEmpty ? nil : r.payment]
            .compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            card
            if let warn = DataGrab.check(r) {
                Label(L(warn), systemImage: "exclamationmark.triangle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.amber)
                    .fixedSize(horizontal: false, vertical: true)
            } else if r.total != nil, !r.lines.isEmpty {
                Label(L("Everything adds up"), systemImage: "checkmark.seal.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success)
            }

            Text(L("Where should it go?")).font(HandyFont.bodyStrong).padding(.top, 4)
            Button { addToExpenses() } label: {
                Label(addedTo == nil ? L("Add to this month's expenses") : L("Added to your expenses"), systemImage: addedTo == nil ? "tablecells.badge.ellipsis" : "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }.primaryButton().disabled(addedTo != nil).accessibilityIdentifier("receipt-add-expenses")
            if let addedTo {
                Text("\(L("Saved as a row in")) \u{201C}\(addedTo)\u{201D}. \(L("Open it any time from My sheets, or share it as a spreadsheet."))")
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            if photo != nil {
                Button { keep() } label: {
                    Label(kept ? L("Kept in Receipts") : L("Keep the receipt (for returns and warranty)"), systemImage: kept ? "checkmark.circle.fill" : "tray.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }.secondaryButton().disabled(kept).accessibilityIdentifier("receipt-keep")
                if kept {
                    Text(L("It's in Warranty & Receipts with the photo. Search it later by shop or item, and set a warranty or return date there."))
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: HandySpacing.s8) {
                ShareLink(item: XLSXFile(data: XLSXWriter.workbook(rows: DataGrab.receiptRows(r), sheetName: r.merchant.isEmpty ? "Receipt" : String(r.merchant.prefix(30))) ?? Data()),
                          preview: SharePreview("\(r.merchant.isEmpty ? "Receipt" : r.merchant).xlsx")) {
                    Label(L("Open in Numbers or Excel"), systemImage: "tablecells").frame(maxWidth: .infinity)
                }.compactButton()
                CopyButton(text: DataGrab.receiptCSV(r), title: "Copy")
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(alignment: .top, spacing: HandySpacing.s12) {
                Image(systemName: "receipt").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 40, height: 40).background(HandyColor.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    TextField(L("Shop"), text: $r.merchant).font(HandyFont.cardTitle).accessibilityIdentifier("receipt-shop")
                    if !meta.isEmpty { Text(meta).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                }
            }
            if !r.lines.isEmpty {
                Divider()
                ForEach(Array(r.lines.enumerated()), id: \.offset) { _, l in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let q = l.qty { Text("\(q == q.rounded() ? String(Int(q)) : String(q))×").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).monospacedDigit() }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(l.name).font(HandyFont.body).fixedSize(horizontal: false, vertical: true)
                            if let q = l.qty, q > 1, let u = l.unit { Text("\(money(u)) \(L("each"))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
                        }
                        Spacer(minLength: 8)
                        Text(money(l.amount)).font(HandyFont.body).monospacedDigit()
                    }
                }
            }
            Divider()
            if let s = r.subtotal { sumRow(L("Subtotal"), s) }
            if let t = r.tax { sumRow(r.taxRate.map { "\(L("Tax")) (\(DataGrab.formatRate($0))%)" } ?? L("Tax"), t) }
            if let t = r.tip { sumRow(L("Tip"), t) }
            HStack {
                Text(L("Total")).font(HandyFont.cardTitle)
                Spacer()
                Text(r.currency).font(HandyFont.cardTitle)
                TextField("0.00", text: $totalText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .font(HandyFont.cardTitle).monospacedDigit().frame(maxWidth: 120)
                    .onChange(of: totalText) { _, v in r.total = Double(v.replacingOccurrences(of: ",", with: ".")) }
                    .accessibilityIdentifier("receipt-total")
            }
            Text(L("Tap the shop or the total to fix them before you file it.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    private func sumRow(_ label: String, _ v: Double) -> some View {
        HStack { Text(label).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary); Spacer(); Text(money(v)).font(HandyFont.caption).monospacedDigit() }
    }

    /// One row in this month's expense sheet (the same sheet the "Receipt into this month's expense sheet" helper fills).
    private func addToExpenses() {
        let name = ChainName.file(pattern: RunningList.defaultName, tool: "List", ext: "csv")
        let merged = RunningList.merged(existing: RunningList.read(name), incoming: DataGrab.expenseRow(r))
        if RunningList.write(name, merged) { addedTo = (name as NSString).deletingPathExtension }
    }

    private func keep() {
        guard let photo else { return }
        let scan = ReceiptScan.Result(store: r.merchant.isEmpty ? "Receipt" : r.merchant, date: r.date,
                                      total: r.total.map { money($0) } ?? "", items: r.lines.map(\.name),
                                      rawText: DataGrab.receiptCSV(r))
        _ = ReceiptStore().add(image: photo, scan: scan, warrantyMonths: nil)
        kept = true
    }
}
