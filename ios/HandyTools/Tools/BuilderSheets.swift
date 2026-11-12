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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                Text("Each sheet opens in Numbers, Excel or Google Sheets. They stay on this phone until you send one.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
                if sheets.isEmpty {
                    Text("No sheets yet. Run \"Receipt into this month's expense sheet\" and it appears here.")
                        .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).cardStyle()
                }
                ForEach(sheets) { s in card(s) }
            }.padding(HandySpacing.gutter)
        }
        .background(HandyColor.bg)
        .navigationTitle("My sheets").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .alert("Rename sheet", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") {
                if let r = renaming {
                    note = RunningList.rename(r.file, to: newName) == nil ? "That name is empty or already used. The sheet kept its name." : "Renamed."
                    reload()
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: { Text("Tools that add to this sheet by its old name will start a new one.") }
        .confirmationDialog("Delete this sheet?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete \(deleting?.name ?? "sheet")", role: .destructive) {
                if let d = deleting { RunningList.delete(d.file); note = "Deleted \(d.name)."; if open?.file == d.file { open = nil }; reload() }
                deleting = nil
            }
            Button("Keep it", role: .cancel) { deleting = nil }
        } message: { Text("Its entries are removed from this phone. This can't be undone.") }
    }

    private func reload() { sheets = RunningList.all() }

    private func card(_ s: RunningList.Sheet) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Button { open = open?.file == s.file ? nil : s } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                        Text(SheetsView.summary(rows: s.rows, changed: s.changed)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: open?.file == s.file ? "chevron.up" : "chevron.down").foregroundStyle(HandyColor.textSecondary)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("sheet-\(s.name)")
            if open?.file == s.file { rows(s) }
            HStack(spacing: HandySpacing.s12) {
                ShareLink(item: RunningList.url(s.file)) { Label("Send", systemImage: "square.and.arrow.up") }.font(HandyFont.caption)
                Button { newName = s.name; renaming = s } label: { Label("Rename", systemImage: "pencil") }.font(HandyFont.caption)
                if s.rows > 0 {
                    Button { if RunningList.removeLastRow(s.file) { note = "Removed the last entry from \(s.name)."; reload() } } label: { Label("Undo last", systemImage: "arrow.uturn.backward") }.font(HandyFont.caption)
                }
                Spacer()
                Button(role: .destructive) { deleting = s } label: { Label("Delete", systemImage: "trash") }.font(HandyFont.caption)
            }.frame(minHeight: 44)
        }.cardStyle(padding: HandySpacing.s12)
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
