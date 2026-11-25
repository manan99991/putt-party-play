import SwiftUI

/// The sheets your tools add to (for example "Expenses 2026-11"). See what is in each one, send it as a spreadsheet
/// file, rename it, undo the last entry, or delete it. Sheets stay on this phone.
struct SheetsView: View {
    @State private var sheets: [RunningList.Sheet] = RunningList.all()
    @State private var open: RunningList.Sheet?
    @State private var renaming: RunningList.Sheet?
    @State private var newName = ""
    @State private var deleting: RunningList.Sheet?
    @State private var note: String?
    @State private var period = SheetPeriod.current
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                Text(L("Each sheet opens in Numbers, Excel or Google Sheets. They stay on this phone until you send one."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                periodPicker
                if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
                if sheets.isEmpty {
                    Text(L("No sheets yet. Run \"Receipt into this month's expense sheet\" and it appears here."))
                        .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).cardStyle()
                }
                let now = sheets.filter { RunningList.isCurrent($0.name, period: period) }
                let earlier = sheets.filter { !RunningList.isCurrent($0.name, period: period) }
                if !now.isEmpty {
                    SectionLabel(text: "Being filled now")
                    ForEach(now) { s in card(s, current: true) }
                }
                if !earlier.isEmpty {
                    SectionLabel(text: "Earlier sheets")
                    ForEach(earlier) { s in card(s, current: false) }
                }
            }.padding(HandySpacing.gutter)
        }
        .background(HandyColor.bg)
        .navigationTitle(L("My sheets")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() } } }
        .alert(L("Rename sheet"), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField(L("Name"), text: $newName)
            Button(L("Rename")) {
                if let r = renaming {
                    note = RunningList.rename(r.file, to: newName) == nil ? "That name is empty or already used. The sheet kept its name." : "Renamed."
                    reload()
                }
                renaming = nil
            }
            Button(L("Cancel"), role: .cancel) { renaming = nil }
        } message: { Text(L("Tools that add to this sheet by its old name will start a new one.")) }
        .confirmationDialog(L("Delete this sheet?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete \(deleting?.name ?? "sheet")", role: .destructive) {
                if let d = deleting { RunningList.delete(d.file); note = "Deleted \(d.name)."; if open?.file == d.file { open = nil }; reload() }
                deleting = nil
            }
            Button(L("Keep it"), role: .cancel) { deleting = nil }
        } message: { Text(L("Its entries are removed from this phone. This can't be undone.")) }
    }

    private func reload() { sheets = RunningList.all() }

    /// Weekly, every two weeks, monthly (the default), quarterly or yearly: when a fresh sheet starts.
    private var periodPicker: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Start a new sheet")).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
            Picker(L("Start a new sheet"), selection: $period) {
                ForEach(SheetPeriod.allCases) { p in Text(L(p.title)).tag(p) }
            }
            .pickerStyle(.menu).tint(HandyColor.accent).accessibilityIdentifier("sheets-period")
            .onChange(of: period) { _, p in SheetPeriod.current = p }
            Text("\(L("Next entries go into")) \u{201C}\((RunningList.target(pattern: RunningList.defaultName) as NSString).deletingPathExtension)\u{201D}.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: HandySpacing.s12)
    }

    private func card(_ s: RunningList.Sheet, current: Bool) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Button { open = open?.file == s.file ? nil : s } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(s.name).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                            if current {
                                Text(L("Now")).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2).background(HandyColor.accent, in: Capsule())
                                    .accessibilityIdentifier("sheet-now")
                            }
                        }
                        Text(SheetsView.summary(rows: s.rows, changed: s.changed)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: open?.file == s.file ? "chevron.up" : "chevron.down").foregroundStyle(HandyColor.textSecondary)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("sheet-\(s.name)")
            if open?.file == s.file { rows(s) }
            HStack(spacing: HandySpacing.s12) {
                ShareLink(item: RunningList.url(s.file)) { Label(L("Send"), systemImage: "square.and.arrow.up") }.font(HandyFont.caption)
                Button { newName = s.name; renaming = s } label: { Label(L("Rename"), systemImage: "pencil") }.font(HandyFont.caption)
                if s.rows > 0 {
                    Button { if RunningList.removeLastRow(s.file) { note = "Removed the last entry from \(s.name)."; reload() } } label: { Label(L("Undo last"), systemImage: "arrow.uturn.backward") }.font(HandyFont.caption)
                }
                Spacer()
                Button(role: .destructive) { deleting = s } label: { Label(L("Delete"), systemImage: "trash") }.font(HandyFont.caption)
            }.frame(minHeight: 44)
        }
        .cardStyle(padding: HandySpacing.s12)
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous).stroke(current ? HandyColor.accent : .clear, lineWidth: 1.5))
    }

    /// The entries, newest last, as plain lines. Long sheets show their last 30.
    private func rows(_ s: RunningList.Sheet) -> some View {
        let lines = RunningList.read(s.file).components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let shown = lines.count > 31 ? [lines[0]] + lines.suffix(30) : lines
        return VStack(alignment: .leading, spacing: 4) {
            if lines.count > 31 { Text("Showing the last 30 of \(lines.count - 1) entries.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { i, line in
                        Text(line.replacingOccurrences(of: ",", with: "   ")).font(.system(.caption, design: .monospaced))
                            .fontWeight(i == 0 ? .semibold : .regular).foregroundStyle(i == 0 ? HandyColor.textPrimary : HandyColor.textSecondary)
                    }
                }
            }
        }.padding(HandySpacing.s8).frame(maxWidth: .infinity, alignment: .leading).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
    }

    /// "12 entries · changed today". Pure, so it is tested.
    static func summary(rows: Int, changed: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let count = rows == 0 ? "No entries yet" : rows == 1 ? "1 entry" : "\(rows) entries"
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: changed), to: calendar.startOfDay(for: now)).day ?? 0
        let when = days <= 0 ? "changed today" : days == 1 ? "changed yesterday" : "changed \(days) days ago"
        return count + " · " + when
    }
}
