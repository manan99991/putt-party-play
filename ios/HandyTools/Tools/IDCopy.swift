import SwiftUI
import PDFKit
import UIKit

/// The words written across an ID copy, typed by the person, with ready-made choices and a live line showing
/// exactly what will be written. One card, used by every door that makes an ID copy (the ready-made tools and
/// Scan's ID mode), so the feature is the same everywhere.
struct WatermarkWordsCard: View {
    @Binding var words: String
    /// Where the words are remembered between uses.
    let storeKey: String
    var fallback: String = "For verification only"

    static let choices = ["For verification only", "For account opening only", "For rental application only",
                          "For employment check only", "Copy — not valid as ID"]

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Your watermark"), systemImage: "signature").font(HandyFont.bodyStrong)
            TextField(L("e.g. For Chase account opening only"), text: $words)
                .padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("run-watermark-words")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.choices, id: \.self) { w in
                        Button { words = L(w) } label: {
                            Text(L(w)).font(HandyFont.caption).padding(.horizontal, 10).padding(.vertical, 7)
                                .background(words == L(w) ? HandyColor.accent : HandyColor.surface, in: Capsule())
                                .foregroundStyle(words == L(w) ? Color.white : HandyColor.textPrimary)
                        }.buttonStyle(.plain)
                    }
                }
            }
            Text("\(L("Written across it:")) “\(IDCopyCheck.line(words))”")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            Text(L("Name who it's for, so the copy can't be reused anywhere else. Today's date is added.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .cardStyle(padding: HandySpacing.s12)
        .onAppear { if words.isEmpty { words = UserDefaults.standard.string(forKey: storeKey) ?? fallback } }
        .onChange(of: words) { _, v in UserDefaults.standard.set(v, forKey: storeKey) }
    }
}

/// What the finished ID copy really is, read back from the file itself — nothing is assumed.
enum IDCopyCheck {
    struct Facts: Equatable {
        var bytes: Int
        var pages: Int?            // a PDF's page count
        var hasLocation: Bool      // GPS still inside the file
        var hasCamera: Bool        // camera model / time taken still inside the file
        var underTarget: Bool?     // nil when there's no size target
    }

    /// The exact line the watermark step writes.
    static func line(_ words: String, on day: Date = Date()) -> String {
        ChainImage.watermarkLine(words.trimmingCharacters(in: .whitespacesAndNewlines), on: day)
    }

    static func facts(_ data: Data, ext: String, targetBytes: Int?) -> Facts {
        let isPDF = ext.lowercased() == "pdf"
        let meta = isPDF ? nil : Scrubber.metadata(in: data)
        return Facts(bytes: data.count,
                     pages: isPDF ? PDFDocument(data: data)?.pageCount : nil,
                     hasLocation: meta?.hasGPS ?? false,
                     hasCamera: meta.map { $0.device != nil || $0.taken != nil } ?? false,
                     underTarget: targetBytes.map { data.count <= $0 })
    }

    /// The size the tool promises, from its shrink step ("0.5" MB → 500,000 bytes, as upload sites count).
    static func target(_ chain: Chain) -> Int? {
        guard let s = chain.steps.last(where: { $0.block == .shrinkImage })?.settings["mb"], let mb = Double(s) else { return nil }
        return Int(max(0.01, mb) * 1_000_000)
    }

    /// One page holding the copy, for portals that only take PDFs.
    static func onePagePDF(_ image: UIImage) -> Data {
        let page = CGRect(origin: .zero, size: image.size)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in ctx.beginPage(); image.draw(in: page) }
    }
}

/// The finished screen for an ID copy: the copy itself (press and hold to see your original), what was checked in
/// the file — the words written on it, location and camera details gone, the size the upload needs — and
/// Save to Photos, Share, or a one-page PDF.
struct IDCopyResult: View {
    let result: ChainPayload
    let original: Data?
    let words: String
    let chain: Chain
    let fileName: (String) -> String   // file name for an extension

    @State private var comparing = false
    @State private var saved: String?
    @State private var zoom = false

    private var data: (Data, String)? {
        switch result {
        case .file(let d, let e): return (d, e)
        case .image(let i): return i.jpegData(compressionQuality: 0.92).map { ($0, "jpg") }
        default: return nil
        }
    }

    var body: some View {
        if let p = data { content(p.0, p.1) }
    }

    @ViewBuilder private func content(_ d: Data, _ ext: String) -> some View {
            let f = IDCopyCheck.facts(d, ext: ext, targetBytes: IDCopyCheck.target(chain))
            let hadLocation = original.map { Scrubber.metadata(in: $0).hasGPS } ?? false
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                Label(L(chain.id.hasPrefix("id-") ? "Your ID copy is ready" : "Your marked copy is ready"), systemImage: "person.text.rectangle").font(HandyFont.bodyStrong)
                preview(d, ext)
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    row(true, "\(L("Marked:")) “\(IDCopyCheck.line(words))”")
                    if let p = f.pages {
                        row(true, chain.onePage == true && p == 1 ? L("Both sides on one page") : "PDF · \(p) \(L(p == 1 ? "page" : "pages"))")
                    } else {
                        row(!f.hasLocation, f.hasLocation ? L("Location is still in the file") :
                                (hadLocation ? L("Your photo's location was removed") : L("No location in the file")))
                        row(!f.hasCamera, f.hasCamera ? L("Camera details are still in the file") : L("No camera or time-taken details in the file"))
                    }
                    if let under = f.underTarget, let t = IDCopyCheck.target(chain) {
                        row(under, "\(SizeTarget.format(f.bytes)) — \(L(under ? "under" : "over")) \(SizeTarget.format(t))")
                    } else {
                        row(true, "\(SizeTarget.format(f.bytes)) · \(ext.uppercased())")
                    }
                }
                Text(L("Send it only to the place named on it. If a copy turns up anywhere else, the words show where it came from."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                actions(d, ext)
            }
            .cardStyle(padding: HandySpacing.s12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("idcopy-result")
    }

    @ViewBuilder private func preview(_ d: Data, _ ext: String) -> some View {
        if ext.lowercased() == "pdf" {
            PDFPreview(data: d).frame(height: 420).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else if let img = UIImage(data: d) {
            let shown = comparing ? (original.flatMap(UIImage.init(data:)) ?? img) : img
            Image(uiImage: shown).resizable().scaledToFit().frame(maxWidth: .infinity).frame(maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onTapGesture { zoom = true }
                .onLongPressGesture(minimumDuration: 0.15, maximumDistance: 40, pressing: { comparing = $0 && original != nil }, perform: {})
                .sheet(isPresented: $zoom) { ZoomPhoto(image: img) }
            if original != nil {
                Text(L(comparing ? "Your original" : "Press and hold to see your original. Tap to zoom."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }
    }

    @ViewBuilder private func actions(_ d: Data, _ ext: String) -> some View {
        let isPDF = ext.lowercased() == "pdf"
        if let u = write(d, ext) {
            ShareLink(item: u) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        }
        if !isPDF {
            HStack(spacing: HandySpacing.s8) {
                Button {
                    Task { let ok = await PhotoSaver.save(d); saved = L(ok ? "Saved to Photos." : "Couldn't save — allow Tenzy to add photos in Settings.") }
                } label: { Label(L("Save to Photos"), systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }.secondaryButton()
                if let img = UIImage(data: d), let u = write(IDCopyCheck.onePagePDF(img), "pdf") {
                    ShareLink(item: u) { Label(L("As a PDF"), systemImage: "doc.richtext").frame(maxWidth: .infinity) }.secondaryButton()
                }
            }
            if let saved { Text(saved).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
        }
    }

    private func row(_ ok: Bool, _ text: String) -> some View {
        Label { Text(text).font(HandyFont.caption).fixedSize(horizontal: false, vertical: true) } icon: {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(ok ? Color.green : Color.orange)
        }
        .accessibilityElement(children: .combine)   // one element per check, so a test (and VoiceOver) reads it once
    }

    private func write(_ d: Data, _ ext: String) -> URL? {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(ext))
        try? FileManager.default.removeItem(at: u)
        return (try? d.write(to: u)) != nil ? u : nil
    }
}
