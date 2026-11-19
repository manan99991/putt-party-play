import SwiftUI
import PhotosUI

/// Data Grabber — a photo of a receipt becomes rows; a business card becomes a contact; a flyer
/// becomes a calendar event; a printed table becomes a CSV. On-device OCR + rules, with an optional
/// on-device AI pass to tidy the result. No typing.
struct DataGrabView: View {
    @State private var photo: UIImage?
    @State private var text = ""
    @State private var kind: DataGrab.Kind = .text
    @State private var autoKind: DataGrab.Kind = .text
    @State private var photoItem: PhotosPickerItem?
    @State private var busy = false
    @State private var errorText: String?
    @State private var receipt = DataGrab.Receipt()
    @State private var card = DataGrab.Card()
    @State private var event = DataGrab.Event()
    @State private var aiText = ""
    @State private var aiBusy = false
    @State private var tableHeader = true

    var body: some View {
        ToolPage(title: "Data Grabber", subtitle: "Receipt → rows, business card → contact, flyer → calendar event, printed table → CSV.", working: busy) {
            HowTo("datagrab", [
                "Snap or pick a photo of a receipt, card, event or table.",
                "The app pulls out the fields and lays them in a table.",
                "Fix the type if it guessed wrong, then copy or export as CSV.",
            ])
            if text.isEmpty {
                PhotosPicker(selection: $photoItem, matching: .images) { Label(L("Choose a photo or screenshot"), systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity) }.secondaryButton()
                Button { if let s = UIPasteboard.general.string { text = s; run() } } label: { Label(L("Paste text instead"), systemImage: "doc.on.clipboard").frame(maxWidth: .infinity) }.secondaryButton()
                if busy { ToolProgressBar(label: "Reading…") }
            } else {
                HandyFlow(spacing: HandySpacing.s8) {
                    ForEach([DataGrab.Kind.receipt, .card, .event, .table], id: \.rawValue) { k in HChip(text: k.rawValue, selected: kind == k) { kind = k; run(detect: false) } }
                }
                if kind != autoKind && autoKind != .text { Text("Detected as \(autoKind.rawValue.lowercased()) — you switched to \(kind.rawValue.lowercased()).").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                switch kind {
                case .receipt: receiptView
                case .card: cardView
                case .event: eventView
                case .table, .text: tableView
                }
                if AIEngine.isAvailable {
                    if aiText.isEmpty {
                        Button { refine() } label: { HStack { if aiBusy { ProgressView() }; Label(L("Tidy with on-device AI"), systemImage: "sparkles") } }.compactButton().disabled(aiBusy)
                    } else {
                        Text(aiText).font(.system(.body, design: .monospaced)).textSelection(.enabled).padding(HandySpacing.s12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    }
                }
                DisclosureGroup("Text that was read") { Text(text).font(HandyFont.caption).textSelection(.enabled).foregroundStyle(HandyColor.textSecondary) }.font(HandyFont.caption)
                HStack { PhotosPicker(selection: $photoItem, matching: .images) { Label(L("Different photo"), systemImage: "photo") }.textButton(); Button { text = ""; aiText = "" } label: { Label(L("Start over"), systemImage: "arrow.counterclockwise") }.textButton(); Spacer() }
            }
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .onAppear { if Launch.sample, text.isEmpty { Task { let s = await AIEngine.recognizeText(SampleAssets.receipt()); await MainActor.run { if !s.isEmpty { text = s; run() } } } } }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            busy = true; errorText = nil
            Task {
                guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) else { await MainActor.run { busy = false }; return }
                await MainActor.run { photo = img }
                // Row by row, so prices stay with their items and a card's two columns stay apart.
                let box = UncheckedImage(img)
                let s = await Task.detached(priority: .userInitiated) { () -> String in
                    let ocr = DocEngine.recognize(box.image.normalizedUp())
                    let t = ChainRunner.rows(ocr).trimmingCharacters(in: .whitespacesAndNewlines)
                    DataGrab.rememberHeights(t, Dictionary(ocr.map { ($0.text, $0.box.height) }, uniquingKeysWith: max))
                    return t
                }.value
                await MainActor.run { busy = false; if s.isEmpty { errorText = "No text found in that image." } else { text = s; run() } }
            }
        }
    }

    private func run(detect: Bool = true) {
        aiText = ""
        if detect { autoKind = DataGrab.detect(text); kind = autoKind == .text ? .table : autoKind }
        switch kind {
        case .receipt: receipt = DataGrab.receipt(text)
        case .card: card = DataGrab.card(text)
        case .event: event = DataGrab.event(text, heights: DataGrab.heights(for: text))
        default: break
        }
        HandyHaptics.light()
    }

    // MARK: receipt

    /// The same rich receipt as "Read a receipt": every line checked, then into this month's expenses, kept with
    /// its photo, or opened as a spreadsheet.
    private var receiptView: some View {
        ReceiptResult(receipt: receipt, photo: photo).id("\(receipt.merchant)|\(receipt.total ?? 0)|\(receipt.items.count)")
    }

    private var cardView: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            field("Name", $card.name); field("Title", $card.title); field("Company", $card.company)
            field("Phone", Binding(get: { card.phones.joined(separator: ", ") }, set: { card.phones = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
            field("Email", Binding(get: { card.emails.joined(separator: ", ") }, set: { card.emails = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
            field("Website", $card.website); field("Address", $card.address)
            ShareLink(item: VCardFile(data: Data(DataGrab.vcard(card).utf8)), preview: SharePreview(card.name.isEmpty ? "Contact" : card.name)) { Label(L("Add to Contacts"), systemImage: "person.crop.circle.badge.plus").frame(maxWidth: .infinity) }.primaryButton()
            Text(L("Opens the share sheet — pick Contacts to save, or send the card on.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }.cardStyle(padding: HandySpacing.s12)
    }

    // MARK: event

    /// The same event card as every other path: everything the poster says, with Apple's own Add to Calendar.
    private var eventView: some View {
        EventCard(event: ICSParse.parse(DataGrab.ics(event)), primary: true)
            .id("\(event.title)|\(event.start?.timeIntervalSince1970 ?? 0)|\(event.location)")
    }

    // MARK: table

    private var tableView: some View {
        let parsed = DataGrab.tableRows(text)
        let rows = parsed.rows
        let csv = DataGrab.tableCSV(text)
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if rows.isEmpty {
                Text(L("No table found — each line becomes a row; columns split on tabs, commas or wide gaps."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            } else {
                Text("\(rows.count) \(L("rows")) × \(rows.first?.count ?? 0) \(L("columns"))" + (parsed.ragged > 0 ? " · \(parsed.ragged) \(L("short rows filled with blanks"))" : ""))
                    .font(HandyFont.caption).foregroundStyle(parsed.ragged > 0 ? HandyColor.amber : HandyColor.textSecondary)
                let check = DataGrab.tableCheck(rows, header: tableHeader)
                if !check.totals.isEmpty {
                    ForEach(check.totals, id: \.column) { t in
                        let ok = abs(t.printed - t.added) < 0.011
                        Label(ok ? "\(L("Adds up")): \(L("the rows make")) \(String(format: "%.2f", t.added)), \(L("as the total says"))"
                                 : "\(L("Check this")): \(L("the total says")) \(String(format: "%.2f", t.printed)), \(L("the rows add to")) \(String(format: "%.2f", t.added))",
                              systemImage: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(HandyFont.caption).foregroundStyle(ok ? HandyColor.success : HandyColor.amber).fixedSize(horizontal: false, vertical: true)
                    }
                } else if !check.sums.isEmpty, rows.count > 2 {
                    Text(check.numberColumns.compactMap { c in check.sums[c].map { "\(tableHeader && rows[0].indices.contains(c) ? rows[0][c] : "\(L("Column")) \(c + 1)"): \(String(format: "%.2f", $0))" } }.joined(separator: " · "))
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                if !check.suspect.isEmpty {
                    Label("\(check.suspect.count) \(L(check.suspect.count == 1 ? "cell may be misread — marked in orange. Tap the photo to compare." : "cells may be misread — marked in orange. Compare with the photo."))", systemImage: "eye.trianglebadge.exclamationmark")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.amber).fixedSize(horizontal: false, vertical: true)
                }
                ScrollView([.horizontal, .vertical]) {
                    Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                        ForEach(rows.indices, id: \.self) { r in
                            GridRow {
                                ForEach(rows[r].indices, id: \.self) { c in
                                    Text(rows[r][c].isEmpty ? " " : rows[r][c])
                                        .font(.system(size: 13, weight: tableHeader && r == 0 ? .semibold : .regular))
                                        .lineLimit(1)
                                        .frame(minWidth: 60, alignment: XLSXWriter.number(rows[r][c]) != nil ? .trailing : .leading)
                                        .padding(.horizontal, 8).padding(.vertical, 6)
                                        .background(check.suspect.contains([r, c]) ? HandyColor.amber.opacity(0.35)
                                                    : (tableHeader && r == 0 ? HandyColor.accent.opacity(0.12) : (r % 2 == 0 ? HandyColor.surface : Color.clear)))
                                        .overlay(Rectangle().stroke(HandyColor.border.opacity(0.6), lineWidth: 0.5))
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
                Toggle(L("First row is the header"), isOn: $tableHeader).font(HandyFont.caption).tint(HandyColor.accent)
                ShareLink(item: XLSXFile(data: XLSXWriter.workbook(rows: rows, sheetName: "Table", header: tableHeader) ?? Data()),
                          preview: SharePreview("Table.xlsx")) {
                    Label(L("Save as Excel (.xlsx)"), systemImage: "tablecells.badge.ellipsis").frame(maxWidth: .infinity)
                }.primaryButton()
                HandyFlow(spacing: HandySpacing.s8) {
                    ShareLink(item: CSVFile(data: Data(csv.utf8)), preview: SharePreview("Table.csv")) { Label(L("Save CSV"), systemImage: "tablecells") }.compactButton()
                    Button { Copier.copy(csv.replacingOccurrences(of: ",", with: "\t")) } label: { Label(L("Copy for a spreadsheet"), systemImage: "doc.on.doc") }.compactButton()
                }
                Text(L("Excel keeps numbers as numbers, so they add up and sort. Opens in Excel, Numbers and Google Sheets."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }.cardStyle(padding: HandySpacing.s12)
    }

    // MARK: bits

    private func field(_ label: String, _ b: Binding<String>) -> some View {
        HStack { Text(label).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 72, alignment: .leading); TextField(label, text: b).font(HandyFont.body) }
    }
    private func row(_ k: String, _ v: String) -> some View { HStack { Text(k).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary); Spacer(); Text(v).font(HandyFont.body).monospacedDigit() } }
    private func money(_ v: Double) -> String { (receipt.currency.isEmpty ? "" : receipt.currency) + String(format: "%.2f", v) }

    private func refine() {
        guard Usage.hasRoom("ai", limit: Limits.freeAiPerDay) else { errorText = "You've used today's \(Limits.freeAiPerDay) free AI actions."; return }
        aiBusy = true
        Task { @MainActor in
            defer { aiBusy = false }
            do {
                aiText = try await AIEngine.run(instructions: "You extract structured data from OCR text of a \(kind.rawValue.lowercased()). Return only a clean 'Label: value' list (one per line). For receipts list each item with its price, then Subtotal, Tax, Tip, Total, Merchant, Date. Fix obvious OCR errors. No commentary.", prompt: text)
                _ = Usage.use("ai", limit: Limits.freeAiPerDay)
            } catch { errorText = error.localizedDescription }
        }
    }
}
