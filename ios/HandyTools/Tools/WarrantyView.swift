import SwiftUI
import PhotosUI
import UIKit

/// Warranty & Receipts — a shoebox that never loses anything. Snap a receipt and it's filed with the
/// store, date and total read off automatically; find it later by typing roughly what you remember
/// ("cosco tv"); and get a nudge a week before any warranty runs out. All on the phone, no account.
struct WarrantyView: View {
    @StateObject private var store = ReceiptStore()
    @State private var query = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var draft: Draft?
    @State private var open: Receipt?
    @State private var busy = false
    @AppStorage("warranty.remind") private var warrantyOn = true
    @AppStorage("warranty.lead") private var warrantyLead = 7
    @AppStorage("returns.remind") private var returnsOn = true
    @State private var notifOff = false

    private var results: [Receipt] { ReceiptSearch.rank(store.receipts, query: query) }
    private var expiring: [Receipt] { store.expiring(within: 45) }
    private var returnsSoon: [Receipt] { store.returnsClosing(within: 7) }

    var body: some View {
        ToolPage(title: "Warranty & Receipts", subtitle: "Snap a receipt, find it later by typing roughly what you remember, and never miss a warranty.", working: busy) {
            HowTo("warranty", [
                "Add a receipt — photograph it or pick a photo. The store, date and total are read for you.",
                "Search loosely: “cosco tv”, “the drill”, a rough amount — close enough still finds it.",
                "Set a warranty and a return date — Tenzy reminds you before each one (you choose how early under Notify me).",
            ])

            HStack(spacing: HandySpacing.s8) {
                Button { showCamera = true } label: { Label(L("Photograph"), systemImage: "camera.fill").frame(maxWidth: .infinity) }.primaryButton()
                PhotosPicker(selection: $pickerItem, matching: .images) { Label(L("From Photos"), systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if busy { ToolProgressBar(label: "Reading the receipt…") }
            alertsCard
            if !store.receipts.isEmpty { PaperworkExportCard(receipts: store) }

            if store.receipts.isEmpty && !busy {
                emptyState
            } else {
                if !returnsSoon.isEmpty && query.isEmpty { returnsCard }
                if !expiring.isEmpty && query.isEmpty { expiringCard }

                TextField(L("Search receipts — store, item, or a rough amount"), text: $query)
                    .padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .autocorrectionDisabled().textInputAutocapitalization(.never)

                if results.isEmpty {
                    Text("No receipt matches “\(query)”. Try fewer or rougher words — spelling doesn't have to be exact.")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                } else {
                    ForEach(results) { r in
                        Button { open = r } label: { ReceiptRow(receipt: r, thumb: store.thumbnail(r)) }.buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) { CameraCapture { img in if let img { startDraft(img) } } }
        .sheet(item: $draft) { d in DraftSheet(draft: d, store: store) }
        .sheet(item: $open) { r in ReceiptDetail(receipt: r, store: store) }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            busy = true
            Task {
                let img = (try? await item.loadTransferable(type: Data.self)).flatMap(UIImage.init)
                pickerItem = nil
                if let img { startDraft(img) } else { await MainActor.run { busy = false } }
            }
        }
        .onAppear {
            if Launch.sample, store.receipts.isEmpty { startDraft(SampleAssets.receipt()) }
        }
    }

    /// "Notify me": the two receipt alerts in plain words, each with a switch, and the warranty lead time.
    private var alertsCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Toggle(L("Before a return window closes"), isOn: $returnsOn).tint(HandyColor.accent)
                if returnsOn {
                    Text(L("Two days before, at 10 am, and on the last morning, at 9 am.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
                Toggle(L("Before a warranty ends"), isOn: $warrantyOn).tint(HandyColor.accent)
                if warrantyOn {
                    HStack(spacing: HandySpacing.s8) {
                        ForEach(WarrantyReminders.leadChoices, id: \.self) { d in
                            HChip(text: "\(d) \(L("days before"))", selected: warrantyLead == d) { warrantyLead = d }
                        }
                    }
                }
                NotificationsOffCard(isOff: $notifOff)
                Text(L("Alerts are set on your phone for each receipt with a date. Nothing is sent anywhere.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }.padding(.top, HandySpacing.s8)
        } label: { Label(L("Notify me"), systemImage: "bell.badge").font(HandyFont.bodyStrong) }
        .tint(HandyColor.accent)
        .onChange(of: returnsOn) { _, on in settingsChanged(on) }
        .onChange(of: warrantyOn) { _, on in settingsChanged(on) }
        .onChange(of: warrantyLead) { _, _ in settingsChanged(true) }
        .task { if returnsOn || warrantyOn { notifOff = await NotifyPermission.state() == .off } }
    }

    private func settingsChanged(_ turnedOn: Bool) {
        Task {
            if turnedOn { let ok = await NotifyPermission.ensure(); await MainActor.run { notifOff = !ok } }
            await MainActor.run { store.rescheduleAll() }
        }
    }

    private func startDraft(_ img: UIImage) {
        busy = true
        Task {
            let scan = await ReceiptScan.read(img)
            await MainActor.run { busy = false; draft = Draft(image: img, scan: scan) }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Nothing filed yet"), systemImage: "shippingbox").font(HandyFont.bodyStrong)
            Text(L("Add the receipt for anything with a warranty — a TV, a drill, an appliance. When it breaks in month 11, you'll have the proof in two taps instead of tearing the house apart."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }.cardStyle(padding: HandySpacing.s12)
    }

    private var expiringCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label("\(expiring.count) warrant\(expiring.count == 1 ? "y" : "ies") ending soon", systemImage: "alarm.fill")
                .font(HandyFont.bodyStrong).foregroundStyle(HandyColor.danger)
            ForEach(expiring.prefix(3)) { r in
                Button { open = r } label: {
                    HStack {
                        Text(r.store).font(HandyFont.body).lineLimit(1)
                        Spacer()
                        Text(warrantyPhrase(r)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                    }
                }.buttonStyle(.plain)
            }
        }.cardStyle(padding: HandySpacing.s12)
    }

    private var returnsCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label("\(returnsSoon.count) \(returnsSoon.count == 1 ? L("return window closing") : L("return windows closing"))", systemImage: "arrow.uturn.backward.circle.fill")
                .font(HandyFont.bodyStrong).foregroundStyle(HandyColor.amber)
            ForEach(returnsSoon.prefix(3)) { r in
                Button { open = r } label: {
                    HStack {
                        Text(r.store).font(HandyFont.body).lineLimit(1)
                        Spacer()
                        Text(Self.returnPhrase(r)).font(HandyFont.caption).foregroundStyle(HandyColor.amber)
                    }
                }.buttonStyle(.plain)
            }
        }.cardStyle(padding: HandySpacing.s12)
    }

    static func returnPhrase(_ r: Receipt) -> String {
        guard let d = r.daysLeftToReturn else { return "" }
        if d < 0 { return "return window closed" }
        if d == 0 { return "last day to return" }
        if d == 1 { return "1 day to return" }
        return "\(d) days to return"
    }

    private func warrantyPhrase(_ r: Receipt) -> String {
        guard let d = r.daysLeftOnWarranty else { return "" }
        if d == 0 { return "ends today" }
        if d == 1 { return "1 day left" }
        return "\(d) days left"
    }
}

/// A receipt being reviewed before it's filed — editable so a bad OCR guess is a quick fix, not a wall.
struct Draft: Identifiable {
    let id = UUID()
    let image: UIImage
    let scan: ReceiptScan.Result
}

private struct ReceiptRow: View {
    let receipt: Receipt
    let thumb: UIImage?
    var body: some View {
        HStack(spacing: HandySpacing.s12) {
            Group {
                if let thumb { Image(uiImage: thumb).resizable().scaledToFill() }
                else { Image(systemName: "doc.text").foregroundStyle(HandyColor.textSecondary) }
            }
            .frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.store).font(HandyFont.bodyStrong).lineLimit(1)
                HStack(spacing: 6) {
                    if let d = receipt.purchaseDate { Text(d.formatted(date: .abbreviated, time: .omitted)) }
                    if !receipt.total.isEmpty { Text("· \(receipt.total)") }
                }.font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Spacer()
            if let r = receipt.daysLeftToReturn, r >= 0 {
                Label("\(r)d", systemImage: "arrow.uturn.backward").labelStyle(.titleAndIcon)
                    .font(HandyFont.micro).foregroundStyle(r <= 7 ? HandyColor.amber : HandyColor.textSecondary)
                    .accessibilityLabel("\(r) days left to return")
            }
            if let days = receipt.daysLeftOnWarranty {
                Text(days < 0 ? "expired" : "\(days)d")
                    .font(HandyFont.micro).foregroundStyle(days < 0 ? HandyColor.textSecondary : (days <= 45 ? HandyColor.danger : HandyColor.accent))
            }
        }.padding(.vertical, 4)
    }
}

private struct DraftSheet: View {
    let draft: Draft
    @ObservedObject var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss
    @State private var storeName = ""
    @State private var total = ""
    @State private var months: Int? = nil
    @State private var returnDays: Int? = nil
    @State private var foundReturn: Int? = nil
    private let options: [(String, Int?)] = [("No warranty", nil), ("1 year", 12), ("2 years", 24), ("3 years", 36)]
    private var returnOptions: [(String, Int?)] {
        var o: [(String, Int?)] = [("Not tracking", nil), ("14 days", 14), ("30 days", 30), ("60 days", 60), ("90 days", 90)]
        if let f = foundReturn, ![14, 30, 60, 90].contains(f) { o.insert(("\(f) days", f), at: 1) }
        return o
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s12) {
                    Image(uiImage: draft.image).resizable().scaledToFit().frame(maxHeight: 260)
                        .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    field("Store", text: $storeName)
                    field("Total", text: $total)
                    Text(L("Warranty")).font(HandyFont.bodyStrong)
                    HandyFlow(spacing: HandySpacing.s8) {
                        ForEach(options, id: \.0) { o in HChip(text: o.0, selected: months == o.1) { months = o.1 } }
                    }
                    if months != nil { Text(L("We'll remind you a week before it ends.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    Text(L("Return window")).font(HandyFont.bodyStrong).padding(.top, 4)
                    HandyFlow(spacing: HandySpacing.s8) {
                        ForEach(returnOptions, id: \.0) { o in HChip(text: o.0, selected: returnDays == o.1) { returnDays = o.1 } }
                    }
                    if let f = foundReturn {
                        Label("\(L("Found on the receipt")): \(f)-\(L("day returns"))", systemImage: "text.viewfinder")
                            .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                    }
                    if let d = returnDays, let by = Calendar.current.date(byAdding: .day, value: d, to: Calendar.current.startOfDay(for: draft.scan.date ?? Date())) {
                        Text("\(L("Return by")) \(by.formatted(date: .abbreviated, time: .omitted)) — \(L("we'll remind you 2 days before and on the last day."))")
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                }.padding(HandySpacing.gutter)
            }
            .navigationTitle(L("Save receipt")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Save")) {
                        var scan = draft.scan
                        scan = ReceiptScan.Result(store: storeName.isEmpty ? scan.store : storeName, date: scan.date,
                                                  total: total, items: scan.items, rawText: scan.rawText)
                        _ = store.add(image: draft.image, scan: scan, warrantyMonths: months, returnDays: returnDays)
                        HandyHaptics.success(); dismiss()
                    }
                }
            }
            .onAppear {
                storeName = draft.scan.store; total = draft.scan.total
                foundReturn = ReceiptScan.guessReturnDays(draft.scan.rawText, purchase: draft.scan.date)
                returnDays = foundReturn
            }
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            TextField(label, text: text).padding(HandySpacing.s8)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct ReceiptDetail: View {
    let receipt: Receipt
    @ObservedObject var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s12) {
                    if let img = store.image(receipt) {
                        Image(uiImage: img).resizable().scaledToFit()
                            .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    }
                    row("Store", receipt.store)
                    if let d = receipt.purchaseDate { row("Date", d.formatted(date: .abbreviated, time: .omitted)) }
                    if !receipt.total.isEmpty { row("Total", receipt.total) }
                    if let end = receipt.warrantyEnds {
                        let days = receipt.daysLeftOnWarranty ?? 0
                        row("Warranty", days < 0 ? "Ended \(end.formatted(date: .abbreviated, time: .omitted))" : "Until \(end.formatted(date: .abbreviated, time: .omitted)) · \(days) days left")
                    }
                    if let by = receipt.returnBy {
                        row("Return", "By \(by.formatted(date: .abbreviated, time: .omitted)) · \(WarrantyView.returnPhrase(receipt))")
                    }
                    if !receipt.items.isEmpty {
                        Text(L("Items")).font(HandyFont.bodyStrong)
                        ForEach(receipt.items, id: \.self) { Text("• \($0)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    }
                    if let img = store.image(receipt) {
                        ShareLink(item: Image(uiImage: img), preview: SharePreview(receipt.store, image: Image(uiImage: img))) {
                            Label(L("Share receipt"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }.secondaryButton()
                    }
                    Button(role: .destructive) { confirmDelete = true } label: { Label(L("Delete"), systemImage: "trash").frame(maxWidth: .infinity) }.secondaryButton()
                }.padding(HandySpacing.gutter)
            }
            .navigationTitle(receipt.store).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() } } }
            .confirmationDialog(L("Delete this receipt? This can't be undone."), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(L("Delete receipt"), role: .destructive) { store.delete(receipt); dismiss() }
                Button(L("Keep"), role: .cancel) {}
            }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 72, alignment: .leading)
            Text(v).font(HandyFont.body).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Camera capture — snap a receipt. Falls back to nil on a device with no camera (simulator), so the
/// photo picker still covers the user.
private struct CameraCapture: UIViewControllerRepresentable {
    let done: (UIImage?) -> Void
    func makeCoordinator() -> Coord { Coord(done: done) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) { p.sourceType = .camera }
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}
