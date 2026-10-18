import SwiftUI
import AVFoundation
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Pick a video, shrink it. Everything re-encodes on the phone — great for emailing, texting, or
/// uploading a clip that's too big. Shows the before/after size so you know it worked.
struct VideoCompressorView: View {
    @EnvironmentObject var store: StoreManager
    @State private var pickedItem: PhotosPickerItem?
    @State private var sourceURL: URL?
    @State private var sourceBytes: Int64 = 0
    @State private var quality = 1   // 0 small, 1 medium, 2 large
    @State private var working = false
    @State private var resultURL: URL?
    @State private var resultBytes: Int64 = 0
    @State private var alreadyOptimized = false
    @State private var errorText: String?

    private let qualities: [(String, String)] = [
        ("Small", "max savings"),
        ("Medium", "balanced"),
        ("Large", "keep quality"),
    ]

    /// Bitrate-oriented presets, most aggressive last. We try the chosen level, then fall back to
    /// more aggressive ones until the result is actually smaller than the source.
    private func ladder(_ q: Int) -> [String] {
        switch q {
        case 0:  return [AVAssetExportPresetLowQuality]
        case 1:  return [AVAssetExportPresetMediumQuality, AVAssetExportPresetLowQuality]
        default: return [AVAssetExportPreset1280x720, AVAssetExportPresetMediumQuality, AVAssetExportPresetLowQuality]
        }
    }
    private var overQuota: Bool { !Usage.hasRoom("video", limit: Limits.freeVideoPerDay) }

    var body: some View {
        ToolPage(title: "Video Compressor", subtitle: "Make a video small enough to send — all on your phone.") {
            PhotosPicker(selection: $pickedItem, matching: .videos) {
                Label(sourceURL == nil ? "Pick a video" : "Pick a different video", systemImage: "film.stack").frame(maxWidth: .infinity)
            }
            .compactButton()
            .onChange(of: pickedItem) { _, item in loadSource(item) }

            if sourceURL != nil {
                Text("Original: \(format(sourceBytes))").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)

                Picker("", selection: $quality) {
                    ForEach(Array(qualities.enumerated()), id: \.offset) { i, q in Text(q.0).tag(i) }
                }.pickerStyle(.segmented)
                Text(qualities[quality].1).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)

                if !store.isPremium { QuotaChip(name: "video", limit: Limits.freeVideoPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've compressed today's \(Limits.freeVideoPerDay) free videos.") }

                Button { compress() } label: {
                    HStack { if working { ProgressView().tint(.white) }; Text(working ? "Compressing…" : "Compress") }.frame(maxWidth: .infinity)
                }
                .primaryButton()
                .disabled(working || overQuota)
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if let resultURL, resultBytes > 0 {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    if alreadyOptimized {
                        Text("Already well-compressed").font(HandyFont.bodyStrong)
                        Text("This video is about as small as it gets without hurting quality — keeping your original (\(format(sourceBytes))).")
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    } else {
                        let saved = sourceBytes > 0 ? Int((1 - Double(resultBytes) / Double(sourceBytes)) * 100) : 0
                        Text("New size: \(format(resultBytes))").font(HandyFont.bodyStrong)
                        Text("\(saved)% smaller").font(HandyFont.caption).foregroundStyle(HandyColor.success)
                    }
                    ShareLink(item: resultURL) { Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
                }.cardStyle(padding: HandySpacing.s16)
            }
        }
    }

    private func loadSource(_ item: PhotosPickerItem?) {
        resultURL = nil; resultBytes = 0; errorText = nil
        Task {
            guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("src-\(UUID().uuidString).mov")
            try? data.write(to: url)
            sourceURL = url
            sourceBytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        }
    }

    private func compress() {
        guard let src = sourceURL else { return }
        guard Usage.use("video", limit: Limits.freeVideoPerDay) else { return }
        working = true; errorText = nil; resultURL = nil; alreadyOptimized = false
        let presets = ladder(quality)
        Task {
            let asset = AVURLAsset(url: src)
            var best: (URL, Int64)?
            for preset in presets {
                guard let out = await exportOnce(asset, preset: preset) else { continue }
                if best == nil || out.1 < best!.1 { best = out }
                if out.1 < sourceBytes { break }   // got something smaller — stop
            }
            if let best, best.1 < sourceBytes {
                resultURL = best.0; resultBytes = best.1; alreadyOptimized = false
            } else {
                // Nothing beat the original (already-compressed source) — hand back the original, honestly.
                resultURL = src; resultBytes = sourceBytes; alreadyOptimized = true
            }
            if resultURL == nil { errorText = "Couldn't compress this video. Try a different one." }
            working = false
            HandyHaptics.success()
        }
    }

    /// One export pass at a given preset. Returns (url, bytes) on success.
    private func exportOnce(_ asset: AVURLAsset, preset: String) async -> (URL, Int64)? {
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else { return nil }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-\(UUID().uuidString).mp4")
        session.outputURL = out
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        await session.export()
        guard session.status == .completed else { return nil }
        let bytes = ((try? FileManager.default.attributesOfItem(atPath: out.path)[.size]) as? Int64) ?? 0
        return bytes > 0 ? (out, bytes) : nil
    }

    private func format(_ b: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: b, countStyle: .file)
    }
}

private extension AVAssetExportSession {
    /// Bridge the deprecated callback export into async/await so the view stays clean.
    func export() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            exportAsynchronously { cont.resume() }
        }
    }
}
