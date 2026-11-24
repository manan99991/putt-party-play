import SwiftUI

/// Business Miles (Business tab): log a drive in a few seconds, see the month and the year at a glance with a rough
/// deduction at the IRS standard rate, and send the year to an accountant as a spreadsheet. Stays on the phone.
struct MileageView: View {
    @ObservedObject private var log = MileageStore.shared
    @State private var from = ""
    @State private var to = ""
    @State private var why = ""
    @State private var miles = ""
    @State private var roundTrip = false
    @State private var purpose: Mileage.Purpose = .business
    @State private var date = Date()
    @State private var justAdded: UUID?
    @State private var showExport = false
    @State private var seeded = false

    private var year: Int { Calendar.current.component(.year, from: Date()) }

    var body: some View {
        ToolPage(title: "Business Miles", subtitle: "Log a drive in seconds. See your miles and a rough deduction, and send the year to your accountant.") {
            HowTo("mileage", [
                "Type where you went, why, and how far — or tap one of your usual trips.",
                "Round trip counts the drive both ways.",
                "See this month and this year, with a rough deduction at the IRS standard rate.",
                "Send the year as a spreadsheet (Numbers or Excel) to your accountant.",
            ])
            summary
            form
            if !log.trips.isEmpty { list }
            Text(L("Stays on your phone. Nothing is uploaded.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .sheet(isPresented: $showExport) { NavigationStack { exportSheet } }
        .onAppear(perform: seedForTests)
    }

    // MARK: Summary

    private var summary: some View {
        let month = Mileage.totals(log.trips, in: .month, of: Date())
        let yr = Mileage.totals(log.trips, in: .year, of: Date())
        let r = Mileage.rate(.business, year: year)
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(spacing: 0) {
                stat(month.total, L("miles this month"))
                Rectangle().fill(HandyColor.border).frame(width: 1, height: 34)
                stat(yr.total, String(format: L("miles in %d"), year))
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Rough deduction this year")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Text(Invoice.money(yr.estimate, currency: "USD", locale: Locale(identifier: "en_US")))
                        .font(.system(size: 24, weight: .bold)).monospacedDigit().foregroundStyle(HandyColor.textPrimary)
                        .accessibilityIdentifier("mileage-estimate")
                }
                Spacer()
                if !log.trips.isEmpty {
                    Button { showExport = true } label: { Label(L("Send to accountant"), systemImage: "tablecells") }
                        .compactButton().accessibilityIdentifier("mileage-export")
                }
            }
            Text(String(format: L("At the IRS standard rate for %d: %@ a business mile. An estimate, not tax advice — your accountant decides what you can claim."),
                        r.year, String(format: "$%.3f", r.rate)))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    private func stat(_ v: Double, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(String(format: "%.1f", v)).font(.system(size: 22, weight: .bold)).monospacedDigit().foregroundStyle(HandyColor.textPrimary)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(HandyColor.textSecondary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Add a drive

    private var form: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Add a drive")).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary)
            let usual = Mileage.usual(log.trips)
            if !usual.isEmpty {
                Text(L("Your usual trips — tap to fill in")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                HandyFlow(spacing: 6) {
                    ForEach(usual) { t in
                        HChip(text: "\(t.to.isEmpty ? t.why : t.to) · \(String(format: "%g", t.miles)) mi", selected: false) {
                            from = t.from; to = t.to; why = t.why; miles = String(format: "%g", t.miles); roundTrip = t.roundTrip; purpose = t.purpose
                        }
                    }
                }
            }
            HStack(spacing: HandySpacing.s8) {
                TextField(L("From"), text: $from).bizField().frame(maxWidth: .infinity).accessibilityIdentifier("mileage-from")
                Image(systemName: "arrow.right").foregroundStyle(HandyColor.textSecondary).accessibilityHidden(true)
                TextField(L("To"), text: $to).bizField().frame(maxWidth: .infinity).accessibilityIdentifier("mileage-to")
            }
            TextField(L("Why — e.g. client visit, supplies run"), text: $why).bizField().accessibilityIdentifier("mileage-why")
            HStack(spacing: HandySpacing.s8) {
                TextField(L("Miles"), text: $miles).keyboardType(.decimalPad).bizField().frame(width: 100).accessibilityIdentifier("mileage-miles")
                Toggle(L("Round trip"), isOn: $roundTrip).tint(HandyColor.accent).font(HandyFont.caption).accessibilityIdentifier("mileage-round")
            }
            // Purpose chips wrap, and the date has its own row, so nothing ever pushes the page wider than the screen.
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(Mileage.Purpose.allCases) { p in HChip(text: L(p.title), selected: purpose == p) { purpose = p } }
            }
            DatePicker(L("When"), selection: $date, in: ...Date(), displayedComponents: .date)
                .font(HandyFont.caption).tint(HandyColor.accent)
            Button(action: add) { Label(L("Add drive"), systemImage: "plus.circle.fill").frame(maxWidth: .infinity) }
                .primaryButton().disabled(number(miles) <= 0).accessibilityIdentifier("mileage-add")
            if number(miles) <= 0 {
                Text(L("Type how many miles the drive was.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .cardStyle()
    }

    // MARK: The log

    private var list: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Your drives")).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary)
            ForEach(log.trips.prefix(30)) { t in
                HStack(spacing: HandySpacing.s8) {
                    Image(systemName: t.purpose == .business ? "briefcase.fill" : t.purpose == .medical ? "cross.case.fill" : "heart.fill")
                        .foregroundStyle(HandyColor.accent).frame(width: 26).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text([t.from, t.to].filter { !$0.isEmpty }.joined(separator: " → ").isEmpty ? L(t.purpose.title) : [t.from, t.to].filter { !$0.isEmpty }.joined(separator: " → "))
                            .font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).lineLimit(1)
                        Text(t.date.formatted(.dateTime.month(.abbreviated).day()) + (t.why.isEmpty ? "" : " · " + t.why) + (t.roundTrip ? " · " + L("round trip") : ""))
                            .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(String(format: "%.1f mi", t.counted)).font(HandyFont.bodyStrong).monospacedDigit().foregroundStyle(HandyColor.textPrimary)
                }
                .padding(.vertical, 4)
                .background(justAdded == t.id ? HandyColor.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 8))
                .contextMenu { Button(role: .destructive) { log.remove(t.id) } label: { Label(L("Delete"), systemImage: "trash") } }
                .accessibilityElement(children: .combine)
                .accessibilityAction(named: L("Delete")) { log.remove(t.id) }
            }
            if log.trips.count > 30 {
                Text(String(format: L("And %d more in the spreadsheet."), log.trips.count - 30)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            Text(L("Touch and hold a drive to delete it.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .cardStyle()
    }

    // MARK: Send the year (previewed first)

    private var exportSheet: some View {
        let rows = log.trips.filter { Calendar.current.component(.year, from: $0.date) == year }.sorted { $0.date < $1.date }
        let t = Mileage.totals(log.trips, in: .year, of: Date())
        return ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                Text(String(format: L("%d drives · %@ miles · about %@"), t.trips, String(format: "%.1f", t.total),
                            Invoice.money(t.estimate, currency: "USD", locale: Locale(identifier: "en_US"))))
                    .font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                // The spreadsheet as it will open: the first rows, before it's sent.
                VStack(spacing: 0) {
                    previewRow(["Date", "To", "Why", "Miles"], head: true)
                    ForEach(rows.prefix(8)) { r in
                        previewRow([r.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits)), r.to, r.why, String(format: "%.1f", r.counted)])
                    }
                    if rows.count > 8 { previewRow(["…", "", "", ""]) }
                    previewRow(["Total", "", "", String(format: "%.1f", t.total)], head: true)
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(HandyColor.border, lineWidth: 1))
                .accessibilityIdentifier("mileage-preview")
                if let u = log.file(year: year) {
                    ShareLink(item: u, preview: SharePreview(Mileage.fileName(year: year))) {
                        Label(L("Send spreadsheet"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }.primaryButton().accessibilityIdentifier("mileage-send")
                }
                Text(L("Opens in Numbers, Excel or Google Sheets. Each drive is a row, with the rate and estimate beside it."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            .padding(HandySpacing.gutter)
        }
        .navigationTitle(String(format: L("Mileage %d"), year)).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { showExport = false } } }
    }

    private func previewRow(_ cells: [String], head: Bool = false) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, c in
                Text(i == 0 || i == 3 ? c : L(c)).font(.system(size: 12, weight: head ? .semibold : .regular)).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: i == 3 ? .trailing : .leading)
            }
        }
        .foregroundStyle(HandyColor.textPrimary)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(head ? HandyColor.surface : .clear)
    }

    // MARK: Logic

    private func number(_ s: String) -> Double {
        let t = s.filter { "0123456789.,".contains($0) }
        if t.contains(".") { return Double(t.replacingOccurrences(of: ",", with: "")) ?? 0 }
        return Double(t.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func add() {
        let m = number(miles)
        guard m > 0 else { return }
        let t = Mileage.Trip(date: date, from: from.trimmingCharacters(in: .whitespaces), to: to.trimmingCharacters(in: .whitespaces),
                             why: why.trimmingCharacters(in: .whitespaces), miles: m, roundTrip: roundTrip, purpose: purpose)
        withAnimation { log.add(t); justAdded = t.id }
        HandyHaptics.success()
        from = ""; to = ""; why = ""; miles = ""; roundTrip = false; date = Date()
    }

    /// UI tests and screenshots (`-sample`): a filled-in drive from a made-up business.
    private func seedForTests() {
        guard !seeded, Launch.args.contains("-sample"), Launch.uitest || Launch.screenshots else { return }
        seeded = true
        from = "Shop"; to = "Jordan Lee, 14 Maple Ave"; why = "Fix kitchen faucet"; miles = "12.4"; roundTrip = true
    }
}

extension View {
    /// A text box on the Business tools: the same look as Invoices & Quotes.
    func bizField() -> some View {
        padding(HandySpacing.s8).frame(minHeight: 44)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }
}
