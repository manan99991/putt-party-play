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
    @State private var asking = false
    @State private var override = false
    @State private var dateTouched = false

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
            if let warn = DataGrab.entryProblems(r).block {
                Label(L(warn), systemImage: "exclamationmark.triangle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.amber)
                    .fixedSize(horizontal: false, vertical: true)
            } else if r.total != nil, !r.lines.isEmpty {
                Label(L("Everything adds up"), systemImage: "checkmark.seal.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success)
            }

            Text(L("Where should it go?")).font(HandyFont.bodyStrong).padding(.top, 4)
            let problems = DataGrab.entryProblems(r)
            Button { askThenAdd() } label: {
                Label(addedTo == nil ? L("Add to my expense sheet") : L("Added to your expenses"), systemImage: addedTo == nil ? "tablecells.badge.ellipsis" : "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }.primaryButton().disabled(addedTo != nil || (problems.block != nil && !override)).accessibilityIdentifier("receipt-add-expenses")
            if addedTo == nil, problems.block != nil {
                // Blocked until fixed, but never a dead end: a misread line can't be typed over, so the person can
                // say the receipt really reads this way.
                Toggle(isOn: $override) { Text(L("I've checked it against the receipt, add it as shown")).font(HandyFont.caption) }
                    .tint(HandyColor.amber).accessibilityIdentifier("receipt-override")
            }
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
        .confirmationDialog(L("Add to this sheet?"), isPresented: $asking, titleVisibility: .visible) {
            let file = RunningList.target(pattern: RunningList.defaultName)
            Button("\(L("Add to")) \((file as NSString).deletingPathExtension)") { addToExpenses() }
            Button(L("Start a new sheet")) { RunningList.startNew(from: file); addToExpenses() }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            let file = RunningList.target(pattern: RunningList.defaultName)
            let n = RunningList.rowCount(RunningList.read(file))
            Text("\((file as NSString).deletingPathExtension) · \(n) \(L(n == 1 ? "entry so far" : "entries so far"))")
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(alignment: .top, spacing: HandySpacing.s12) {
                Image(systemName: "receipt").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 40, height: 40).background(HandyColor.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    TextField(L("Shop"), text: $r.merchant).font(HandyFont.cardTitle).accessibilityIdentifier("receipt-shop")
                        .padding(.horizontal, 4).background(unsure("shop") ? HandyColor.amber.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    if !meta.isEmpty { Text(meta).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    if r.date == nil || dateTouched {
                        // No date on the receipt: pick it (today until changed), marked until looked at.
                        DatePicker(L("Date"), selection: Binding(get: { r.date ?? Date() }, set: { r.date = $0; dateTouched = true }), displayedComponents: .date)
                            .font(HandyFont.caption).padding(.horizontal, 4)
                            .background(dateTouched ? .clear : HandyColor.amber.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
                            .accessibilityIdentifier("receipt-date")
                    }
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
                    .padding(.horizontal, 4).background(unsure("total") ? HandyColor.amber.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    .onChange(of: totalText) { _, v in r.total = Double(v.replacingOccurrences(of: ",", with: ".")) }
                    .accessibilityIdentifier("receipt-total")
            }
            Text(L("Tap the shop or the total to fix them before you file it.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    private func unsure(_ field: String) -> Bool { DataGrab.entryProblems(r).unsure.contains(field) }

    private func sumRow(_ label: String, _ v: Double) -> some View {
        HStack { Text(label).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary); Spacer(); Text(money(v)).font(HandyFont.caption).monospacedDigit() }
    }

    /// One row in this month's expense sheet (the same sheet the "Receipt into this month's expense sheet" helper fills).
    private func addToExpenses() {
        if r.date == nil { r.date = Date() }   // the date shown in the picker, today unless changed
        let name = RunningList.target(pattern: RunningList.defaultName)
        let merged = RunningList.merged(existing: RunningList.read(name), incoming: DataGrab.expenseRow(r))
        if RunningList.write(name, merged) { addedTo = (name as NSString).deletingPathExtension }
    }

    /// "Add to Expenses 2026-11 (12 entries so far)? / Start a new sheet". A sheet that doesn't exist yet just starts.
    private func askThenAdd() {
        let file = RunningList.target(pattern: RunningList.defaultName)
        if RunningList.rowCount(RunningList.read(file)) == 0 { addToExpenses() } else { asking = true }
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
