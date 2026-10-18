import SwiftUI
import PhotosUI
import PDFKit
import UIKit

/// Pick photos, get one tidy PDF — for receipts, forms, or anything you need to send as a document
/// instead of a camera roll dump. Built on the phone, no upload.
struct ImagePDFView: View {
    @EnvironmentObject var store: StoreManager
    @State private var items: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var pdfURL: URL?
    @State private var working = false
    private var overQuota: Bool { !Usage.hasRoom("imgpdf", limit: Limits.freeImagePdfPerDay) }

    var body: some View {
        ToolPage(title: "Image → PDF", subtitle: "Turn photos into one clean PDF to send or file.") {
            PhotosPicker(selection: $items, maxSelectionCount: store.isPremium ? 0 : 10, matching: .images) {
                Label(images.isEmpty ? "Pick photos" : "Pick different photos", systemImage: "photo.stack").frame(maxWidth: .infinity)
            }
            .compactButton()
            .onChange(of: items) { _, new in loadImages(new) }

            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HandySpacing.s8) {
                        ForEach(Array(images.enumerated()), id: \.offset) { _, img in
                            Image(uiImage: img).resizable().scaledToFill().frame(width: 72, height: 96).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                Text("\(images.count) page\(images.count == 1 ? "" : "s")").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)

                if !store.isPremium { QuotaChip(name: "imgpdf", limit: Limits.freeImagePdfPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've made today's \(Limits.freeImagePdfPerDay) free PDFs.") }

                Button { makePDF() } label: {
                    HStack { if working { ProgressView().tint(.white) }; Text("Make PDF") }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota)
            }

            if let pdfURL {
                ShareLink(item: pdfURL) { Label("Save or share PDF", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                    .primaryButton()
            }
        }
    }

    private func loadImages(_ picked: [PhotosPickerItem]) {
        pdfURL = nil
        Task {
            var out: [UIImage] = []
            for item in picked {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { out.append(img) }
            }
            images = out
        }
    }

    private func makePDF() {
        guard Usage.use("imgpdf", limit: Limits.freeImagePdfPerDay) else { return }
        working = true; pdfURL = nil
        let imgs = images
        // Rendering a handful of images is quick; keep it on the main actor to stay data-race-safe.
        Task { @MainActor in
            let page = CGRect(x: 0, y: 0, width: 612, height: 792)   // US Letter @72dpi
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-\(UUID().uuidString.prefix(6)).pdf")
            let renderer = UIGraphicsPDFRenderer(bounds: page)
            try? renderer.writePDF(to: url) { ctx in
                for img in imgs {
                    ctx.beginPage()
                    let fit = AVFit(img.size, in: page.insetBy(dx: 24, dy: 24))
                    img.draw(in: fit)
                }
            }
            pdfURL = url; working = false; HandyHaptics.success()
        }
    }
}

/// Aspect-fit a size inside a rect, centered.
private func AVFit(_ size: CGSize, in rect: CGRect) -> CGRect {
    guard size.width > 0, size.height > 0 else { return rect }
    let scale = min(rect.width / size.width, rect.height / size.height)
    let w = size.width * scale, h = size.height * scale
    return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
}
