import SwiftUI
import PhotosUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

/// The PDF jobs people pay other apps for — photos → PDF, merge several PDFs, and compress a big
/// one — all on the phone, no watermark.
struct PDFToolkitView: View {
    @EnvironmentObject var store: StoreManager
    @State private var mode = 0   // 0 images→pdf, 1 merge, 2 compress
    @State private var items: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var pdfURLs: [URL] = []
    @State private var importing = false
    @State private var result: URL?
    @State private var resultBytes: Int64 = 0
    @State private var working = false
    @State private var errorText: String?

    private var overQuota: Bool { !Usage.hasRoom("pdftools", limit: Limits.freePdfOpsPerDay) }

    var body: some View {
        ToolPage(title: "PDF Toolkit", subtitle: "Photos → PDF, merge, and compress — no watermark.") {
            Picker("", selection: $mode) {
                Text("Photos → PDF").tag(0); Text("Merge").tag(1); Text("Compress").tag(2)
            }.pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in reset() }

            if mode == 0 {
                PhotosPicker(selection: $items, maxSelectionCount: store.isPremium ? 0 : 15, matching: .images) {
                    Label(images.isEmpty ? "Pick photos" : "Pick different photos", systemImage: "photo.stack").frame(maxWidth: .infinity)
                }.compactButton().onChange(of: items) { _, new in loadImages(new) }
                if !images.isEmpty { Text("\(images.count) page\(images.count == 1 ? "" : "s")").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            } else {
                Button { importing = true } label: {
                    Label(pdfURLs.isEmpty ? "Pick PDFs" : "\(pdfURLs.count) PDF\(pdfURLs.count == 1 ? "" : "s") chosen", systemImage: "doc.fill").frame(maxWidth: .infinity)
                }.compactButton()
                .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf], allowsMultipleSelection: mode == 1) { res in
                    switch res {
                    case .success(let urls): pdfURLs = urls
                    case .failure(let e): errorText = e.localizedDescription
                    }
                }
            }

            if !store.isPremium { QuotaChip(name: "pdftools", limit: Limits.freePdfOpsPerDay).environmentObject(store) }
            if overQuota { LimitReachedBanner(message: "You've done today's \(Limits.freePdfOpsPerDay) free PDF jobs.") }

            Button { run() } label: {
                HStack { if working { ProgressView().tint(.white) }; Text(working ? "Working…" : actionTitle) }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(working || overQuota || !canRun)

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if let result {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text("Done · \(ByteCountFormatter.string(fromByteCount: resultBytes, countStyle: .file))").font(HandyFont.bodyStrong)
                    ShareLink(item: result) { Label("Save or share PDF", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
                }.cardStyle(padding: HandySpacing.s16)
            }
        }
    }

    private var actionTitle: String { ["Make PDF", "Merge PDFs", "Compress PDF"][mode] }
    private var canRun: Bool { mode == 0 ? !images.isEmpty : (mode == 1 ? pdfURLs.count >= 2 : pdfURLs.count == 1) }

    private func reset() { images = []; items = []; pdfURLs = []; result = nil; errorText = nil }

    private func loadImages(_ picked: [PhotosPickerItem]) {
        result = nil
        Task { var out: [UIImage] = []; for i in picked { if let d = try? await i.loadTransferable(type: Data.self), let img = UIImage(data: d) { out.append(img) } }; images = out }
    }

    private func run() {
        guard Usage.use("pdftools", limit: Limits.freePdfOpsPerDay) else { return }
        working = true; errorText = nil; result = nil
        let m = mode, imgs = images, urls = pdfURLs
        Task { @MainActor in
            let out: URL?
            switch m {
            case 0: out = Self.imagesToPDF(imgs)
            case 1: out = Self.merge(urls)
            default: out = Self.compress(urls.first)
            }
            if let out { result = out; resultBytes = ((try? FileManager.default.attributesOfItem(atPath: out.path)[.size]) as? Int64) ?? 0; HandyHaptics.success() }
            else { errorText = "Couldn't complete that. Check the files and try again." }
            working = false
        }
    }

    // MARK: operations

    private static func temp() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-\(UUID().uuidString.prefix(6)).pdf") }

    private static func imagesToPDF(_ images: [UIImage]) -> URL? {
        guard !images.isEmpty else { return nil }
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let url = temp()
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        try? renderer.writePDF(to: url) { ctx in
            for img in images {
                ctx.beginPage()
                let box = page.insetBy(dx: 24, dy: 24)
                let scale = min(box.width / img.size.width, box.height / img.size.height)
                let w = img.size.width * scale, h = img.size.height * scale
                img.draw(in: CGRect(x: box.midX - w / 2, y: box.midY - h / 2, width: w, height: h))
            }
        }
        return url
    }

    private static func merge(_ urls: [URL]) -> URL? {
        guard urls.count >= 2 else { return nil }
        let merged = PDFDocument()
        for u in urls {
            let access = u.startAccessingSecurityScopedResource()
            defer { if access { u.stopAccessingSecurityScopedResource() } }
            guard let doc = PDFDocument(url: u) else { continue }
            for i in 0..<doc.pageCount { if let p = doc.page(at: i) { merged.insert(p, at: merged.pageCount) } }
        }
        guard merged.pageCount > 0 else { return nil }
        let url = temp(); return merged.write(to: url) ? url : nil
    }

    private static func compress(_ src: URL?) -> URL? {
        guard let src else { return nil }
        let access = src.startAccessingSecurityScopedResource()
        defer { if access { src.stopAccessingSecurityScopedResource() } }
        guard let doc = PDFDocument(url: src) else { return nil }
        let out = PDFDocument()
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1.5
            let img = UIGraphicsImageRenderer(size: bounds.size, format: fmt).image { c in
                UIColor.white.set(); c.fill(CGRect(origin: .zero, size: bounds.size))
                c.cgContext.translateBy(x: 0, y: bounds.size.height)
                c.cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: c.cgContext)
            }
            if let jpeg = img.jpegData(compressionQuality: 0.5), let small = UIImage(data: jpeg), let newPage = PDFPage(image: small) {
                out.insert(newPage, at: out.pageCount)
            }
        }
        guard out.pageCount > 0 else { return nil }
        let url = temp(); return out.write(to: url) ? url : nil
    }
}
