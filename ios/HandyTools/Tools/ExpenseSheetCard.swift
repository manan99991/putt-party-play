import SwiftUI

/// The expense sheet as a sheet, not "Photo 1 · 1 KB · CSV": every receipt as a row (date, shop, total, tax), the
/// ones just added highlighted, anything that needs a look flagged, the month's total at the top, and the sheet
/// opened in Numbers or Excel with numbers as numbers.
struct ExpenseSheetCard: View {
    let file: String
    var added: Int = 1
    var skipped: [String] = []
    @State private var text = ""
    @State private var removed = false

    private var rows: [[String]] { text.components(separatedBy: .newlines).filter { !$0.isEmpty }.map(RunningList.fields) }
    private var body_: [[String]] { Array(rows.dropFirst()) }
    private func num(_ s: String) -> Double? { Double(s.filter { $0.isNumber || $0 == "." || $0 == "-" }) }
    private var total: Double { body_.compactMap { $0.count > 2 ? num($0[2]) : nil }.reduce(0, +) }
    private var currency: String { body_.compactMap { $0.count > 4 ? $0[4] : nil }.first { !$0.isEmpty } ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Label((file as NSString).deletingPathExtension, systemImage: "tablecells").font(HandyFont.cardTitle)
                Text("\(body_.count) \(L(body_.count == 1 ? "receipt" : "receipts")) · \(L("total")) \(currency)\(String(format: "%.2f", total))")
                    .font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent)
                if added > 0 { Text("\(added) \(L("just added, highlighted below."))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            }
            ForEach(skipped, id: \.self) { s in
                Label(s, systemImage: "exclamationmark.triangle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.amber).fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                row(["Date", "Shop", "Total", "Tax"], head: true, fresh: false)
                ForEach(Array(body_.enumerated()).reversed(), id: \.offset) { i, r in
                    row([r[safe: 0], r[safe: 1], r[safe: 2], r[safe: 3]], head: false, fresh: i >= body_.count - added)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HandyColor.border, lineWidth: 1))

            if let x = xlsx {
                ShareLink(item: x) { Label(L("Open in Numbers or Excel"), systemImage: "tablecells.badge.ellipsis").frame(maxWidth: .infinity) }.primaryButton()
            }
            ShareLink(item: RunningList.url(file)) { Label(L("Share as CSV"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            if !removed, added > 0 {
                Button { RunningList.removeLastRow(file); removed = true; load() } label: { Label(L("Take the last one back out"), systemImage: "arrow.uturn.backward") }.textButton()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .onAppear(perform: load)
    }

    private func load() { text = RunningList.read(file) }

    @ViewBuilder private func row(_ c: [String], head: Bool, fresh: Bool) -> some View {
        let check = !head && (c[0].isEmpty || c[1].isEmpty || num(c[2]) == nil)
        HStack(spacing: 8) {
            Text(head ? L(c[0]) : c[0]).frame(width: 82, alignment: .leading)
            Text(head ? L(c[1]) : c[1]).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text(head ? L(c[2]) : c[2]).monospacedDigit().frame(width: 70, alignment: .trailing)
            Text(head ? L(c[3]) : c[3]).monospacedDigit().frame(width: 52, alignment: .trailing)
        }
        .font(head ? HandyFont.micro : HandyFont.caption)
        .foregroundStyle(head ? HandyColor.textSecondary : HandyColor.textPrimary)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(fresh ? HandyColor.accentSoft : (check ? HandyColor.amber.opacity(0.12) : Color.clear))
        .overlay(alignment: .trailing) { if check { Image(systemName: "exclamationmark.circle").foregroundStyle(HandyColor.amber).padding(.trailing, 2) } }
        .accessibilityElement(children: .combine)
    }

    /// The sheet as a real spreadsheet (numbers stay numbers), written fresh each time it's opened.
    private var xlsx: URL? {
        guard !rows.isEmpty, let d = XLSXWriter.workbook(rows: rows, sheetName: "Expenses") else { return nil }
        let u = FileManager.default.temporaryDirectory.appendingPathComponent((file as NSString).deletingPathExtension + ".xlsx")
        return (try? d.write(to: u)) != nil ? u : nil
    }
}

private extension Array where Element == String {
    subscript(safe i: Int) -> String { indices.contains(i) ? self[i] : "" }
}
