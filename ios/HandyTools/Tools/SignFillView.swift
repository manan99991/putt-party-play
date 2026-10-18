import SwiftUI
import PencilKit
import PhotosUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

/// Sign or mark up a document or photo with your finger, then export a clean PDF — no printing,
/// scanning, or third-party account.
struct SignFillView: View {
    @EnvironmentObject var store: StoreManager
    @State private var base: UIImage?
    @State private var canvas = PKCanvasView()
    @State private var pickItem: PhotosPickerItem?
    @State private var importing = false
    @State private var result: URL?
    @State private var working = false
    @State private var errorText: String?

    private var overQuota: Bool { !Usage.hasRoom("signfill", limit: Limits.freeSignPerDay) }

    var body: some View {
        ToolPage(title: "Sign & Fill", subtitle: "Draw your signature on a doc or photo, export a PDF.") {
            HStack(spacing: HandySpacing.s12) {
                PhotosPicker(selection: $pickItem, matching: .images) { Label("Photo", systemImage: "photo").frame(maxWidth: .infinity) }
                    .compactButton().onChange(of: pickItem) { _, item in loadPhoto(item) }
                Button { importing = true } label: { Label("PDF", systemImage: "doc").frame(maxWidth: .infinity) }.compactButton()
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { res in
                if case .success(let url) = res { loadPDF(url) }
            }

            if let base {
                ZStack {
                    Image(uiImage: base).resizable().scaledToFit()
                    SignatureCanvas(canvas: canvas)
                }
                .aspectRatio(base.size.width / base.size.height, contentMode: .fit)
                .frame(maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))

                HStack {
                    Button { canvas.drawing = PKDrawing() } label: { Label("Clear ink", systemImage: "eraser") }.textButton()
                    Spacer()
                }
                Text("Draw your signature anywhere on the document.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)

                if !store.isPremium { QuotaChip(name: "signfill", limit: Limits.freeSignPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've signed today's \(Limits.freeSignPerDay) free docs.") }

                Button { export() } label: {
                    HStack { if working { ProgressView().tint(.white) }; Text(working ? "Exporting…" : "Export PDF") }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota)
            } else {
                Text("Pick a photo or PDF to sign.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity).padding(.top, HandySpacing.s24)
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let result {
                ShareLink(item: result) { Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        result = nil; canvas.drawing = PKDrawing()
        Task { if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) { base = img.normalizedUp() } }
    }

    private func loadPDF(_ url: URL) {
        result = nil; canvas.drawing = PKDrawing()
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let doc = PDFDocument(url: url), let page = doc.page(at: 0) else { errorText = "Couldn't open that PDF."; return }
        let bounds = page.bounds(for: .mediaBox)
        let img = UIGraphicsImageRenderer(size: bounds.size).image { c in
            UIColor.white.set(); c.fill(CGRect(origin: .zero, size: bounds.size))
            c.cgContext.translateBy(x: 0, y: bounds.size.height); c.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: c.cgContext)
        }
        base = img
    }

    private func export() {
        guard let base else { return }
        guard Usage.use("signfill", limit: Limits.freeSignPerDay) else { return }
        working = true; errorText = nil; result = nil
        let drawing = canvas.drawing
        let canvasBounds = canvas.bounds
        Task { @MainActor in
            let size = base.size
            let flat = UIGraphicsImageRenderer(size: size).image { _ in
                base.draw(in: CGRect(origin: .zero, size: size))
                let inkRect = canvasBounds.isEmpty ? CGRect(origin: .zero, size: size) : canvasBounds
                let ink = drawing.image(from: inkRect, scale: 1)
                ink.draw(in: CGRect(origin: .zero, size: size))
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-signed-\(UUID().uuidString.prefix(6)).pdf")
            let page = CGRect(origin: .zero, size: size)
            try? UIGraphicsPDFRenderer(bounds: page).writePDF(to: url) { ctx in ctx.beginPage(); flat.draw(in: page) }
            result = url; working = false; HandyHaptics.success()
        }
    }
}

/// A transparent PencilKit canvas laid over the document for drawing a signature.
struct SignatureCanvas: UIViewRepresentable {
    let canvas: PKCanvasView
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        return canvas
    }
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
