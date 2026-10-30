import SwiftUI
import PhotosUI
import VisionKit
import UIKit

#if canImport(Translation)
import Translation
#endif

/// Capture — point at anything, act on it. Tab 1 is the live reader (CaptureView) with the prototype's
/// photo / sample flow: Tenzy works out whether it's a receipt, card, flyer or document, shows the
/// fields, and offers the next step (save, calendar, contacts, CSV, maps, PDF, read aloud, translate).
/// The other tabs embed Data Grabber, Sorted and Lens as they are.
struct CaptureHub: View {
    @EnvironmentObject var store: StoreManager
    @StateObject private var reader = Reader()
    @State private var tab = 0
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var busy = false
    @State private var result: CaptureFlow.Result?
    @State private var showReminder = false
    @State private var reminderDays = 30
    @State private var reminderURL: URL?
    @State private var translating = false
    @State private var note: String?
    @State private var errorText: String?

    private var cameraOK: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    var body: some View {
        PowerToolPage(id: "capture", tabs: ["Capture", "Receipt & data", "Bills → calendar", "Read & simplify"], selected: $tab) {
            switch tab {
            case 0: captureTab
            case 1: DataGrabView().environment(\.embeddedInHub, true)
            case 2: SortedView().environment(\.embeddedInHub, true)
            default: LensView().environment(\.embeddedInHub, true)
            }
        }
        .onChange(of: photoItem) { _, item in readPhoto(item) }
        .onChange(of: tab) { _, _ in reader.pause() }
        .onDisappear { reader.stop() }
        .onAppear { if Launch.sample, result == nil { runSample(.receipt) } }
        .fullScreenCover(isPresented: $showCamera) {
            CaptureCamera { img in showCamera = false; if let img { process(img, forced: nil, fallback: nil) } }.ignoresSafeArea()
        }
        .modifier(CaptureTranslateSheet(isPresented: $translating, text: result?.text ?? ""))
    }

    // MARK: Capture tab

    @ViewBuilder private var captureTab: some View {
        if let r = result {
            Image(uiImage: r.image).resizable().scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 320)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            resultCard(r)
            HStack { Button { clear() } label: { Label("Scan something else", systemImage: "arrow.counterclockwise") }.textButton(); Spacer() }
        } else if cameraOK {
            CaptureView().environment(\.embeddedInHub, true)
        } else {
            HubPreviewBox(minHeight: 170) {
                VStack(spacing: HandySpacing.s8) {
                    Text("Point the camera at a receipt, card, flyer, sign or document.").font(HandyFont.body).multilineTextAlignment(.center)
                    Text("Tenzy works out what it is and offers the next step.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }.padding(HandySpacing.s16)
            }
            HubPill("Live camera reader runs on a real iPhone — photos and samples work everywhere", tone: .native)
        }

        HStack(spacing: HandySpacing.s8) {
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true } else { errorText = "No camera here — pick from the library or try a sample." }
            } label: { Label("Take photo", systemImage: "camera").frame(maxWidth: .infinity) }.primaryButton()
            PhotosPicker(selection: $photoItem, matching: .images) { Label("Library", systemImage: "photo").frame(maxWidth: .infinity) }.secondaryButton()
        }
        if busy { HStack { ProgressView(); Text("Reading…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
        if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

        HubSection("Or try a sample")
        FlowLayout(spacing: 8) {
            ForEach(CaptureSamples.Kind.allCases) { k in HubChip(k.rawValue, selected: result?.sample == k) { runSample(k) } }
        }
        HubNote("Text recognition runs on the phone — nothing is uploaded. Your own photos get the same flow; the samples show it end to end.")
    }

    // MARK: result card

    private func resultCard(_ r: CaptureFlow.Result) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if let k = r.kind { HubPill("✓ Detected: \(k.rawValue)", tone: .ok) }
            else { HubPill("No text found — try more light or get closer", tone: .native) }
            if !r.fields.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(r.fields.enumerated()), id: \.offset) { _, f in
                        HStack(alignment: .top) {
                            Text(f.0).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 76, alignment: .leading)
                            Text(f.1).font(HandyFont.bodyStrong).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            HubSection(r.kind == nil ? "Available for any photo" : "What next?")
            switch r.kind {
            case .receipt: receiptActions(r)
            case .card: cardActions(r)
            case .flyer: flyerActions(r)
            case .doc: docActions(r)
            case nil: noTextActions(r)
            }
            if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
        }.cardStyle()
    }

    // MARK: actions per kind

    @ViewBuilder private func receiptActions(_ r: CaptureFlow.Result) -> some View {
        let total = r.receipt.total.map { CaptureFlow.money($0, r.receipt.currency) } ?? "—"
        Button {
            if CaptureFlow.saveReceipt(r.receipt) != nil {
                ClipStore.add(DataGrab.expenseRow(r.receipt))
                note = "Saved to Receipts · \(total) · \(r.receipt.merchant.isEmpty ? "receipt" : r.receipt.merchant)"; HandyHaptics.success()
            } else { note = "Couldn't write the file — the CSV share below still works." }
        } label: { Label("Save receipt + total", systemImage: "tray.and.arrow.down").frame(maxWidth: .infinity) }.primaryButton()
        Button { showReminder.toggle(); if showReminder { reminderURL = makeReminder(r, days: reminderDays) } } label: { Label("Set return / warranty reminder", systemImage: "calendar.badge.clock").frame(maxWidth: .infinity) }.secondaryButton()
        if showReminder {
            HubSection("Remind me on")
            FlowLayout(spacing: 8) {
                HubChip("30 days (return)", selected: reminderDays == 30) { reminderDays = 30; reminderURL = makeReminder(r, days: 30) }
                HubChip("1 year (warranty)", selected: reminderDays == 365) { reminderDays = 365; reminderURL = makeReminder(r, days: 365) }
            }
            if let url = reminderURL {
                ShareLink(item: url) { Label("Set reminder · \(reminderDate(r, days: reminderDays))", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }.primaryButton()
                HubNote("Opens the share sheet — pick Calendar to add it with an alert the day before.")
            }
        }
        ShareLink(item: CSVFile(data: Data(DataGrab.receiptCSV(r.receipt).utf8)), preview: SharePreview("Receipt.csv")) { Label("Export items to spreadsheet (CSV)", systemImage: "tablecells").frame(maxWidth: .infinity) }.secondaryButton()
        readAloudButton(CaptureFlow.spoken(r))
    }

    @ViewBuilder private func cardActions(_ r: CaptureFlow.Result) -> some View {
        ShareLink(item: VCardFile(data: Data(DataGrab.vcard(r.card).utf8)), preview: SharePreview(r.card.name.isEmpty ? "Contact" : r.card.name)) { Label("Save to Contacts (vCard)", systemImage: "person.crop.circle.badge.plus").frame(maxWidth: .infinity) }.primaryButton()
        HubNote("Opens the share sheet — pick Contacts to save, or send the card on.")
        if let p = r.card.phones.first, let tel = URL(string: "tel:" + p.filter { "+0123456789".contains($0) }) {
            Link(destination: tel) { Label("Call \(p)", systemImage: "phone").frame(maxWidth: .infinity) }.secondaryButton()
        }
        if let e = r.card.emails.first, let mail = URL(string: "mailto:\(e)") {
            Link(destination: mail) { Label("Email \(e)", systemImage: "envelope").frame(maxWidth: .infinity) }.secondaryButton()
        }
        readAloudButton(CaptureFlow.spoken(r))
    }

    @ViewBuilder private func flyerActions(_ r: CaptureFlow.Result) -> some View {
        ShareLink(item: ICSFile(data: Data(DataGrab.ics(r.event).utf8)), preview: SharePreview(r.event.title.isEmpty ? "Event" : r.event.title)) { Label("Add to calendar (.ics)", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }.primaryButton()
        if r.event.start == nil { HubNote("No clear date was read — the invite opens in Calendar so you can set it there.") }
        if !r.event.location.isEmpty, let q = r.event.location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let maps = URL(string: "maps://?q=\(q)") {
            Link(destination: maps) { Label("Open in Maps", systemImage: "map").frame(maxWidth: .infinity) }.secondaryButton()
        }
        ShareLink(item: CaptureFlow.spoken(r)) { Label("Share event", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
        readAloudButton(CaptureFlow.spoken(r))
    }

    @ViewBuilder private func docActions(_ r: CaptureFlow.Result) -> some View {
        Button { UIPasteboard.general.string = r.text; ClipStore.add(r.text); note = "Copied \(r.words) words"; HandyHaptics.success() } label: { Label("Copy all text", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.primaryButton()
        Button { translating = true } label: { Label("Translate this", systemImage: "character.bubble").frame(maxWidth: .infinity) }.secondaryButton()
        if let pdf = r.pdf {
            ShareLink(item: PDFFile(data: pdf), preview: SharePreview("Scan.pdf")) { Label("Save as searchable PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity) }.secondaryButton()
        }
        readAloudButton(r.text)
        DisclosureGroup("Text that was read") { Text(r.text).font(HandyFont.caption).textSelection(.enabled).foregroundStyle(HandyColor.textSecondary) }.font(HandyFont.caption)
    }

    @ViewBuilder private func noTextActions(_ r: CaptureFlow.Result) -> some View {
        if let pdf = r.pdf {
            ShareLink(item: PDFFile(data: pdf), preview: SharePreview("Photo.pdf")) { Label("Save as PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity) }.primaryButton()
        }
        if let jpg = r.image.jpegData(compressionQuality: 0.9) {
            ShareLink(item: JPEGFile(data: jpg), preview: SharePreview("Photo")) { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
        }
    }

    private func readAloudButton(_ text: String) -> some View {
        Button {
            if reader.playing { reader.pause() } else { reader.load(text); reader.play() }
        } label: { Label(reader.playing ? "Stop reading" : "Read aloud", systemImage: reader.playing ? "stop.fill" : "speaker.wave.2").frame(maxWidth: .infinity) }
            .secondaryButton().disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: flow

    private func runSample(_ k: CaptureSamples.Kind) {
        process(CaptureSamples.image(k), forced: k, fallback: CaptureSamples.text(k))
    }

    private func readPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        busy = true; errorText = nil
        Task {
            guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) else { await MainActor.run { busy = false; errorText = "Couldn't load that photo." }; return }
            await MainActor.run { photoItem = nil; process(img, forced: nil, fallback: nil) }
        }
    }

    /// OCR + PDF off the main thread, then the fields and actions for what it turned out to be.
    private func process(_ raw: UIImage, forced: CaptureSamples.Kind?, fallback: String?) {
        busy = true; errorText = nil; note = nil; showReminder = false; reminderURL = nil; reader.stop()
        let img = raw.normalizedUp().resized(maxDimension: 2000)
        Task {
            let (lines, pdf) = await Task.detached(priority: .userInitiated) { () -> ([DocEngine.OCRLine], Data?) in
                let l = DocEngine.recognize(img)
                let p = DocEngine.pdf(images: [img], ocr: [l.isEmpty ? nil : l], options: DocEngine.PDFOptions())
                return (l, p)
            }.value
            var text = DocEngine.text(lines)
            if text.trimmingCharacters(in: .whitespacesAndNewlines).count < 12, let fallback { text = fallback }
            let r = CaptureFlow.build(image: img, text: text, forced: forced, pdf: pdf)
            await MainActor.run { busy = false; result = r; HandyHaptics.success() }
        }
    }

    private func clear() { result = nil; note = nil; errorText = nil; showReminder = false; reminderURL = nil; reader.stop() }

    private func reminderDue(_ r: CaptureFlow.Result, days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: r.receipt.date ?? Date()) ?? Date()
    }
    private func reminderDate(_ r: CaptureFlow.Result, days: Int) -> String { reminderDue(r, days: days).formatted(date: .abbreviated, time: .omitted) }
    private func makeReminder(_ r: CaptureFlow.Result, days: Int) -> URL? {
        let what = days == 30 ? "Return window ends" : "Warranty check"
        let merchant = r.receipt.merchant.isEmpty ? "receipt" : r.receipt.merchant
        let p = SortedEngine.Parsed(kind: "Reminder", title: "\(what) — \(merchant)", amount: r.receipt.total.map { CaptureFlow.money($0, r.receipt.currency) }, due: reminderDue(r, days: days), summary: "Receipt from \(merchant). Set by Tenzy Capture.")
        return SortedEngine.icsURL(p)
    }
}

// MARK: - helpers (file-private so other hubs can name theirs freely)

/// Plain camera that hands back the photo without touching the camera roll.
private struct CaptureCamera: UIViewControllerRepresentable {
    let done: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) { p.sourceType = .camera }
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(done: done) }
    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done((info[.originalImage] as? UIImage)?.normalizedUp())
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}

/// System translation sheet, compiled out on SDKs without the framework.
private struct CaptureTranslateSheet: ViewModifier {
    @Binding var isPresented: Bool
    let text: String
    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(iOS 17.4, *) { content.translationPresentation(isPresented: $isPresented, text: text) } else { content }
        #else
        content
        #endif
    }
}
