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

    private var results: [Receipt] { ReceiptSearch.rank(store.receipts, query: query) }
    private var expiring: [Receipt] { store.expiring(within: 45) }

    var body: some View {
        ToolPage(title: "Warranty & Receipts", subtitle: "Snap a receipt, find it later by typing roughly what you remember, and never miss a warranty.") {
            HowTo("warranty", [
                "Add a receipt — photograph it or pick a photo. The store, date and total are read for you.",
                "Search loosely: “cosco tv”, “the drill”, a rough amount — close enough still finds it.",
                "Set a warranty and we'll remind you a week before it ends.",
            ])

            HStack(spacing: HandySpacing.s8) {
                Button { showCamera = true } label: { Label("Photograph", systemImage: "camera.fill").frame(maxWidth: .infinity) }.primaryButton()
                PhotosPicker(selection: $pickerItem, matching: .images) { Label("From Photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if busy { HStack(spacing: HandySpacing.s8) { ProgressView(); Text("Reading the receipt…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }

            if store.receipts.isEmpty && !busy {
                emptyState
            } else {
                if !expiring.isEmpty && query.isEmpty { expiringCard }

                TextField("Search receipts — store, item, or a rough amount", text: $query)
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

    private func startDraft(_ img: UIImage) {
        busy = true
        Task {
            let scan = await ReceiptScan.read(img)
            await MainActor.run { busy = false; draft = Draft(image: img, scan: scan) }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label("Nothing filed yet", systemImage: "shippingbox").font(HandyFont.bodyStrong)
            Text("Add the receipt for anything with a warranty — a TV, a drill, an appliance. When it breaks in month 11, you'll have the proof in two taps instead of tearing the house apart.")
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
    private let options: [(String, Int?)] = [("No warranty", nil), ("1 year", 12), ("2 years", 24), ("3 years", 36)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s12) {
                    Image(uiImage: draft.image).resizable().scaledToFit().frame(maxHeight: 260)
                        .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    field("Store", text: $storeName)
                    field("Total", text: $total)
                    Text("Warranty").font(HandyFont.bodyStrong)
                    HandyFlow(spacing: HandySpacing.s8) {
                        ForEach(options, id: \.0) { o in HChip(text: o.0, selected: months == o.1) { months = o.1 } }
                    }
                    if months != nil { Text("We'll remind you a week before it ends.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                }.padding(HandySpacing.gutter)
            }
            .navigationTitle("Save receipt").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var scan = draft.scan
                        scan = ReceiptScan.Result(store: storeName.isEmpty ? scan.store : storeName, date: scan.date,
                                                  total: total, items: scan.items, rawText: scan.rawText)
                        _ = store.add(image: draft.image, scan: scan, warrantyMonths: months)
                        HandyHaptics.success(); dismiss()
                    }
                }
            }
            .onAppear { storeName = draft.scan.store; total = draft.scan.total }
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
                    if !receipt.items.isEmpty {
                        Text("Items").font(HandyFont.bodyStrong)
                        ForEach(receipt.items, id: \.self) { Text("• \($0)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    }
                    if let img = store.image(receipt) {
                        ShareLink(item: Image(uiImage: img), preview: SharePreview(receipt.store, image: Image(uiImage: img))) {
                            Label("Share receipt", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }.secondaryButton()
                    }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash").frame(maxWidth: .infinity) }.secondaryButton()
                }.padding(HandySpacing.gutter)
            }
            .navigationTitle(receipt.store).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Delete this receipt? This can't be undone.", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete receipt", role: .destructive) { store.delete(receipt); dismiss() }
                Button("Keep", role: .cancel) {}
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
