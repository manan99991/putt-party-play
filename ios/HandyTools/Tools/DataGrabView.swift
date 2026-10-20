import SwiftUI
import PhotosUI

/// Data Grabber — a photo of a receipt becomes rows; a business card becomes a contact; a flyer
/// becomes a calendar event; a printed table becomes a CSV. On-device OCR + rules, with an optional
/// on-device AI pass to tidy the result. No typing.
struct DataGrabView: View {
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

    var body: some View {
        ToolPage(title: "Data Grabber", subtitle: "Receipt → rows, business card → contact, flyer → calendar event, printed table → CSV.") {
            if text.isEmpty {
                PhotosPicker(selection: $photoItem, matching: .images) { Label("Choose a photo or screenshot", systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity) }.secondaryButton()
                Button { if let s = UIPasteboard.general.string { text = s; run() } } label: { Label("Paste text instead", systemImage: "doc.on.clipboard").frame(maxWidth: .infinity) }.secondaryButton()
                if busy { HStack { ProgressView(); Text("Reading…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
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
                        Button { refine() } label: { HStack { if aiBusy { ProgressView() }; Label("Tidy with on-device AI", systemImage: "sparkles") } }.compactButton().disabled(aiBusy)
                    } else {
                        Text(aiText).font(.system(.body, design: .monospaced)).textSelection(.enabled).padding(HandySpacing.s12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    }
                }
                DisclosureGroup("Text that was read") { Text(text).font(HandyFont.caption).textSelection(.enabled).foregroundStyle(HandyColor.textSecondary) }.font(HandyFont.caption)
                HStack { PhotosPicker(selection: $photoItem, matching: .images) { Label("Different photo", systemImage: "photo") }.textButton(); Button { text = ""; aiText = "" } label: { Label("Start over", systemImage: "arrow.counterclockwise") }.textButton(); Spacer() }
            }
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .onAppear { if Launch.sample, text.isEmpty { Task { let s = await AIEngine.recognizeText(SampleAssets.receipt()); await MainActor.run { if !s.isEmpty { text = s; run() } } } } }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            busy = true; errorText = nil
            Task {
                guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) else { await MainActor.run { busy = false }; return }
                let s = await AIEngine.recognizeText(img)
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
        case .event: event = DataGrab.event(text)
        default: break
        }
        HandyHaptics.light()
    }

    // MARK: receipt

    private var receiptView: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            field("Merchant", $receipt.merchant)
            if let d = receipt.date { row("Date", d.formatted(date: .abbreviated, time: .omitted)) }
            ForEach(Array(receipt.items.enumerated()), id: \.offset) { i, it in
                HStack { Text(it.0).font(HandyFont.body).lineLimit(1); Spacer(); Text(money(it.1)).font(HandyFont.body).monospacedDigit() }
            }
            Divider()
            if let s = receipt.subtotal { row("Subtotal", money(s)) }
            if let t = receipt.tax { row("Tax", money(t)) }
            if let t = receipt.tip { row("Tip", money(t)) }
            HStack { Text("Total").font(HandyFont.bodyStrong); Spacer(); Text(money(receipt.total ?? 0)).font(HandyFont.bodyStrong).monospacedDigit() }
            HStack(spacing: HandySpacing.s8) {
                ShareLink(item: CSVFile(data: Data(DataGrab.receiptCSV(receipt).utf8)), preview: SharePreview("Receipt.csv")) { Label("Items as CSV", systemImage: "tablecells") }.compactButton()
                Button { UIPasteboard.general.string = DataGrab.expenseRow(receipt); HandyHaptics.success() } label: { Label("Copy expense row", systemImage: "doc.on.doc") }.compactButton()
                Spacer()
            }
            Text("The expense row pastes straight into a Numbers/Excel/Google Sheets expense log.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }.cardStyle(padding: HandySpacing.s12)
    }

    // MARK: card

    private var cardView: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            field("Name", $card.name); field("Title", $card.title); field("Company", $card.company)
            field("Phone", Binding(get: { card.phones.joined(separator: ", ") }, set: { card.phones = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
            field("Email", Binding(get: { card.emails.joined(separator: ", ") }, set: { card.emails = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
            field("Website", $card.website); field("Address", $card.address)
            ShareLink(item: VCardFile(data: Data(DataGrab.vcard(card).utf8)), preview: SharePreview(card.name.isEmpty ? "Contact" : card.name)) { Label("Add to Contacts", systemImage: "person.crop.circle.badge.plus").frame(maxWidth: .infinity) }.primaryButton()
            Text("Opens the share sheet — pick Contacts to save, or send the card on.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }.cardStyle(padding: HandySpacing.s12)
    }

    // MARK: event

    private var eventView: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            field("Title", $event.title)
            DatePicker("Starts", selection: Binding(get: { event.start ?? Date() }, set: { event.start = $0 })).font(HandyFont.body)
            DatePicker("Ends", selection: Binding(get: { event.end ?? (event.start ?? Date()).addingTimeInterval(3600) }, set: { event.end = $0 })).font(HandyFont.body)
            field("Location", $event.location)
            ShareLink(item: ICSFile(data: Data(DataGrab.ics(event).utf8)), preview: SharePreview(event.title.isEmpty ? "Event" : event.title)) { Label("Add to Calendar", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }.primaryButton()
            Text("Share → Calendar adds it; or send the invite file to someone else.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }.cardStyle(padding: HandySpacing.s12)
    }

    // MARK: table

    private var tableView: some View {
        let csv = DataGrab.tableCSV(text)
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            ScrollView(.horizontal) { Text(csv).font(.system(size: 12, design: .monospaced)).textSelection(.enabled) }.frame(maxHeight: 220)
            HStack(spacing: HandySpacing.s8) {
                ShareLink(item: CSVFile(data: Data(csv.utf8)), preview: SharePreview("Table.csv")) { Label("Save CSV", systemImage: "tablecells") }.compactButton()
                Button { UIPasteboard.general.string = csv.replacingOccurrences(of: ",", with: "\t"); HandyHaptics.success() } label: { Label("Copy for a spreadsheet", systemImage: "doc.on.doc") }.compactButton()
                Spacer()
            }
            Text("Copy pastes as columns into Numbers, Excel or Sheets.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }.cardStyle(padding: HandySpacing.s12)
    }

    // MARK: bits

    private func field(_ label: String, _ b: Binding<String>) -> some View {
        HStack { Text(label).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 72, alignment: .leading); TextField(label, text: b).font(HandyFont.body) }
    }
    private func row(_ k: String, _ v: String) -> some View { HStack { Text(k).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary); Spacer(); Text(v).font(HandyFont.body).monospacedDigit() } }
    private func money(_ v: Double) -> String { (receipt.currency.isEmpty ? "" : receipt.currency) + String(format: "%.2f", v) }

    private func refine() {
        guard Usage.use("ai", limit: Limits.freeAiPerDay) else { errorText = "You've used today's \(Limits.freeAiPerDay) free AI actions."; return }
        aiBusy = true
        Task { @MainActor in
            defer { aiBusy = false }
            do {
                aiText = try await AIEngine.run(instructions: "You extract structured data from OCR text of a \(kind.rawValue.lowercased()). Return only a clean 'Label: value' list (one per line). For receipts list each item with its price, then Subtotal, Tax, Tip, Total, Merchant, Date. Fix obvious OCR errors. No commentary.", prompt: text)
            } catch { errorText = error.localizedDescription }
        }
    }
}
