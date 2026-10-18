import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

/// Share‑Ready — the actual job people do before uploading: convert to a format the site accepts,
/// strip location/metadata, and get under the size limit. One tap, as a saved recipe.
struct ShareReadyView: View {
    @EnvironmentObject var store: StoreManager

    struct Recipe: Identifiable, Hashable {
        let id: String; let name: String; let hint: String
        let imageBytes: Int; let pdfBytes: Int; let videoBytes: Int
    }
    static let recipes: [Recipe] = [
        Recipe(id: "portal",  name: "Web form / portal", hint: "JPG · PDF · MP4, each under 2 MB (video 25 MB)", imageBytes: 2_000_000, pdfBytes: 2_000_000, videoBytes: 25_000_000),
        Recipe(id: "email",   name: "Email attachment",  hint: "Everything under 20 MB",                      imageBytes: 20_000_000, pdfBytes: 20_000_000, videoBytes: 20_000_000),
        Recipe(id: "message", name: "Text / WhatsApp",   hint: "Photos 5 MB, videos 16 MB",                   imageBytes: 5_000_000, pdfBytes: 5_000_000, videoBytes: 16_000_000),
        Recipe(id: "govphoto",name: "ID / govt photo",   hint: "JPG under 200 KB",                            imageBytes: 200_000, pdfBytes: 500_000, videoBytes: 10_000_000),
    ]

    private enum Item { case image(UIImage), video(URL), pdf(Data, String) }

    @State private var recipe = recipes[0]
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showFiles = false
    @State private var queue: [Item] = []
    @State private var outputs: [URL] = []
    @State private var skipped: [String] = []
    @State private var working = false
    @State private var progress = ""

    private var overQuota: Bool { !Usage.hasRoom("shareready", limit: Limits.freeFitPerDay) }

    var body: some View {
        ToolPage(title: "Share‑Ready", subtitle: "Pick what you're sending and where. It converts, strips metadata, and fits the size — in one tap.") {
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text("Where is it going?").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                ForEach(Self.recipes) { r in
                    Button { recipe = r } label: {
                        HStack(spacing: HandySpacing.s12) {
                            Image(systemName: recipe == r ? "largecircle.fill.circle" : "circle").foregroundStyle(recipe == r ? HandyColor.accent : HandyColor.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                                Text(r.hint).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(HandySpacing.s12)
                        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(recipe == r ? HandyColor.accent : HandyColor.border, lineWidth: recipe == r ? 2 : 1))
                    }.buttonStyle(.plain)
                }
            }

            HStack(spacing: HandySpacing.s12) {
                PhotosPicker(selection: $photoItems, maxSelectionCount: store.isPremium ? 0 : 10, matching: .any(of: [.images, .videos])) {
                    Label("Photos & videos", systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
                }.secondaryButton()
                Button { showFiles = true } label: { Label("PDFs", systemImage: "doc.fill").frame(maxWidth: .infinity) }.secondaryButton()
            }
            .onChange(of: photoItems) { _, new in loadPhotos(new) }
            .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { res in
                if case .success(let urls) = res { loadPDFs(urls) }
            }

            if !queue.isEmpty {
                Text("\(queue.count) file\(queue.count == 1 ? "" : "s") ready · metadata will be stripped from all").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                if !store.isPremium { QuotaChip(name: "shareready", limit: Limits.freeFitPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've prepared today's \(Limits.freeFitPerDay) free batches.") }
                Button { run() } label: {
                    HStack { if working { ProgressView().tint(.white) }; Text(working ? "Preparing \(progress)" : "Make share‑ready") }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota)
            }

            if !outputs.isEmpty {
                Label("\(outputs.count) ready for \(recipe.name.lowercased())", systemImage: "checkmark.seal.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success)
                ShareLink(items: outputs) { Label("Share them", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            }
            if !skipped.isEmpty {
                Text("Couldn't fit: \(skipped.joined(separator: ", ")). Try a looser recipe for those.").font(HandyFont.caption).foregroundStyle(HandyColor.danger)
            }
        }
    }

    private func loadPhotos(_ picked: [PhotosPickerItem]) {
        outputs = []; skipped = []
        Task {
            var out: [Item] = []
            for item in picked {
                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    if let m = try? await item.loadTransferable(type: MovieImport.self) { out.append(.video(m.url)) }
                } else if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { out.append(.image(img)) }
            }
            await MainActor.run { queue.append(contentsOf: out) }
        }
    }

    private func loadPDFs(_ urls: [URL]) {
        outputs = []; skipped = []
        for u in urls {
            let ok = u.startAccessingSecurityScopedResource()
            if let d = try? Data(contentsOf: u) { queue.append(.pdf(d, u.deletingPathExtension().lastPathComponent)) }
            if ok { u.stopAccessingSecurityScopedResource() }
        }
    }

    private func run() {
        guard Usage.use("shareready", limit: Limits.freeFitPerDay) else { return }
        working = true; outputs = []; skipped = []
        let items = queue, r = recipe
        Task { @MainActor in
            var urls: [URL] = []
            for (i, item) in items.enumerated() {
                progress = "\(i + 1)/\(items.count)…"
                let tmp = FileManager.default.temporaryDirectory
                switch item {
                case .image(let img):
                    if let d = SizeTarget.image(img, targetBytes: r.imageBytes) {
                        let u = tmp.appendingPathComponent("Tenzy-\(i + 1).jpg"); try? d.write(to: u); urls.append(u)
                    } else { skipped.append("photo \(i + 1)") }
                case .pdf(let d, let name):
                    if let out = SizeTarget.pdf(d, targetBytes: r.pdfBytes) {
                        let u = tmp.appendingPathComponent("\(name)-ready.pdf"); try? out.write(to: u); urls.append(u)
                    } else { skipped.append(name) }
                case .video(let src):
                    // MP4 first so it plays anywhere, then fit the size if it's still over.
                    guard let mp4 = await FormatFixView.toMP4(src, index: i) else { skipped.append("video \(i + 1)"); continue }
                    if let fitted = await SizeTarget.video(url: mp4, targetBytes: r.videoBytes) { urls.append(fitted) }
                    else { skipped.append("video \(i + 1)") }
                }
            }
            outputs = urls; working = false; progress = ""
            if !urls.isEmpty { HandyHaptics.success() }
        }
    }
}
