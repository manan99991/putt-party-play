import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

/// Format Fixer — "the site won't take my iPhone photo / my video won't play on their phone."
/// Select a batch of photos and videos; HEIC → JPG/PNG and MOV/HEVC → MP4 (H.264) in one go,
/// metadata stripped, ready to upload anywhere.
struct FormatFixView: View {
    @EnvironmentObject var store: StoreManager
    @State private var items: [PhotosPickerItem] = []
    @State private var loaded: [(kind: Kind, image: UIImage?, url: URL?)] = []
    @State private var imageFormat = 0     // 0 JPG, 1 PNG
    @State private var outputs: [URL] = []
    @State private var working = false
    @State private var progress = ""
    @State private var errorText: String?

    private enum Kind { case image, video }
    private var overQuota: Bool { !Usage.hasRoom("formatfix", limit: Limits.freeConvertPerDay) }
    private var maxPick: Int { store.isPremium ? 0 : 10 }
    private var imageCount: Int { loaded.filter { $0.kind == .image }.count }
    private var videoCount: Int { loaded.filter { $0.kind == .video }.count }

    var body: some View {
        ToolPage(title: "Format Fixer", subtitle: "HEIC → JPG, MOV → MP4 — a whole batch, so anything you share opens anywhere.") {
            PhotosPicker(selection: $items, maxSelectionCount: maxPick, matching: .any(of: [.images, .videos])) {
                Label(loaded.isEmpty ? "Choose photos & videos" : "Choose a different batch", systemImage: "photo.stack").frame(maxWidth: .infinity)
            }
            .secondaryButton()
            .onChange(of: items) { _, new in load(new) }

            if !loaded.isEmpty {
                HStack(spacing: HandySpacing.s16) {
                    Label("\(imageCount) photo\(imageCount == 1 ? "" : "s")", systemImage: "photo").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Label("\(videoCount) video\(videoCount == 1 ? "" : "s")", systemImage: "film").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                }
                if imageCount > 0 {
                    Picker("Photos become", selection: $imageFormat) { Text("JPG").tag(0); Text("PNG").tag(1) }.pickerStyle(.segmented)
                }
                if videoCount > 0 {
                    Label("Videos become MP4 (H.264) — plays on Windows, Android, and the web.", systemImage: "checkmark.circle")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Text("Location and camera metadata are removed from every file.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)

                if !store.isPremium { QuotaChip(name: "formatfix", limit: Limits.freeConvertPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've converted today's \(Limits.freeConvertPerDay) free batches.") }
                if !store.isPremium { Text("Free converts up to 10 at once. Pro: unlimited.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }

                Button { convert() } label: {
                    HStack { if working { ProgressView().tint(.white) }; Text(working ? "Converting \(progress)" : "Convert \(loaded.count)") }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota)
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if !outputs.isEmpty {
                ShareLink(items: outputs) { Label("Save or share (\(outputs.count))", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            }
        }
    }

    private func load(_ picked: [PhotosPickerItem]) {
        outputs = []; errorText = nil
        Task {
            var out: [(Kind, UIImage?, URL?)] = []
            for item in picked {
                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    if let m = try? await item.loadTransferable(type: MovieImport.self) { out.append((.video, nil, m.url)) }
                } else if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    out.append((.image, img, nil))
                }
            }
            await MainActor.run { loaded = out.map { (kind: $0.0, image: $0.1, url: $0.2) } }
        }
    }

    private func convert() {
        guard Usage.use("formatfix", limit: Limits.freeConvertPerDay) else { return }
        working = true; outputs = []; errorText = nil
        let batch = loaded, fmt = imageFormat
        Task { @MainActor in
            var urls: [URL] = []
            for (i, entry) in batch.enumerated() {
                progress = "\(i + 1)/\(batch.count)…"
                switch entry.kind {
                case .image:
                    guard let img = entry.image?.normalizedUp() else { continue }
                    let data: Data?; let ext: String
                    if fmt == 1 { data = img.pngData(); ext = "png" } else { data = img.jpegData(compressionQuality: 0.9); ext = "jpg" }
                    guard let d = data else { continue }
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-\(i + 1)-\(UUID().uuidString.prefix(4)).\(ext)")
                    try? d.write(to: url); urls.append(url)
                case .video:
                    guard let src = entry.url, let out = await Self.toMP4(src, index: i) else { continue }
                    urls.append(out)
                }
            }
            outputs = urls; working = false; progress = ""
            if urls.isEmpty { errorText = "Nothing could be converted. Try a different batch." } else { HandyHaptics.success() }
        }
    }

    /// Re-wrap/re-encode any movie as an H.264/AAC MP4 the rest of the world can play.
    static func toMP4(_ src: URL, index: Int) async -> URL? {
        let asset = AVURLAsset(url: src)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-\(index + 1)-\(UUID().uuidString.prefix(4)).mp4")
        session.outputURL = out
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        session.metadata = []                       // drop metadata
        await session.export()
        return session.status == .completed ? out : nil
    }
}
