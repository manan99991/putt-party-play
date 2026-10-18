import SwiftUI
import PhotosUI
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

/// GIF Maker — turn a short video clip, or a handful of photos, into an animated GIF you can send
/// anywhere. Trim, set the speed and size, done. All on the phone, no watermark.
struct GIFMakerView: View {
    @EnvironmentObject var store: StoreManager

    @State private var mode = 0            // 0 video, 1 photos
    @State private var videoItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var videoDuration: Double = 0
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photos: [UIImage] = []

    @State private var start: Double = 0
    @State private var length: Double = 3
    @State private var fpsIdx = 1          // 8 / 12 / 15
    @State private var speedIdx = 1        // 0.5× / 1× / 2×
    @State private var sizeIdx = 1         // 320 / 480 / 640
    @State private var photoDelayIdx = 1   // 0.2 / 0.5 / 1.0 s

    @State private var output: URL?
    @State private var preview: UIImage?
    @State private var working = false
    @State private var errorText: String?

    private let fpsOptions: [Double] = [8, 12, 15]
    private let speedOptions: [Double] = [0.5, 1, 2]
    private let sizeOptions: [(String, CGFloat)] = [("Small", 320), ("Medium", 480), ("Large", 640)]
    private let photoDelays: [(String, Double)] = [("Fast", 0.2), ("Medium", 0.5), ("Slow", 1.0)]
    private var overQuota: Bool { !Usage.hasRoom("gif", limit: Limits.freeGifPerDay) }

    var body: some View {
        ToolPage(title: "GIF Maker", subtitle: "A short clip or a few photos → an animated GIF, ready to share.") {
            Picker("Source", selection: $mode) { Text("From video").tag(0); Text("From photos").tag(1) }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, _ in output = nil; preview = nil; errorText = nil }

            if mode == 0 { videoSection } else { photoSection }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            if let preview {
                Image(uiImage: preview).resizable().scaledToFit().frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                Text("Preview — the saved GIF animates.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            if let output {
                ShareLink(item: output) { Label("Save or share the GIF", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            }
        }
        .onChange(of: videoItem) { _, item in loadVideo(item) }
        .onChange(of: photoItems) { _, items in loadPhotos(items) }
    }

    // MARK: video

    private var videoSection: some View {
        VStack(spacing: HandySpacing.s12) {
            PhotosPicker(selection: $videoItem, matching: .videos) {
                Label(videoURL == nil ? "Choose a video" : "Choose a different video", systemImage: "film").frame(maxWidth: .infinity)
            }.secondaryButton()

            if videoURL != nil {
                SliderRow(label: "Start", valueText: String(format: "%.1fs", start), value: $start, range: 0...max(0.1, videoDuration - 0.5), step: 0.1)
                SliderRow(label: "Length", valueText: String(format: "%.1fs", length), value: $length, range: 0.5...min(6, max(0.5, videoDuration)), step: 0.1)
                labeledPicker("Frame rate", options: fpsOptions.map { "\(Int($0)) fps" }, idx: $fpsIdx)
                labeledPicker("Speed", options: ["0.5×", "1×", "2×"], idx: $speedIdx)
                labeledPicker("Size", options: sizeOptions.map { $0.0 }, idx: $sizeIdx)
                makeButton
            }
        }
    }

    // MARK: photos

    private var photoSection: some View {
        VStack(spacing: HandySpacing.s12) {
            PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .images) {
                Label(photos.isEmpty ? "Choose photos" : "Choose different photos", systemImage: "photo.stack").frame(maxWidth: .infinity)
            }.secondaryButton()

            if !photos.isEmpty {
                Text("\(photos.count) frame\(photos.count == 1 ? "" : "s"), in the order picked").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                labeledPicker("Frame speed", options: photoDelays.map { $0.0 }, idx: $photoDelayIdx)
                labeledPicker("Size", options: sizeOptions.map { $0.0 }, idx: $sizeIdx)
                makeButton
            }
        }
    }

    private var makeButton: some View {
        VStack(spacing: HandySpacing.s8) {
            if !store.isPremium { QuotaChip(name: "gif", limit: Limits.freeGifPerDay).environmentObject(store) }
            if overQuota { LimitReachedBanner(message: "You've made today's \(Limits.freeGifPerDay) free GIFs.") }
            Button { build() } label: {
                HStack { if working { ProgressView().tint(.white) }; Text(working ? "Building…" : "Make GIF") }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(working || overQuota)
        }
    }

    private func labeledPicker(_ label: String, options: [String], idx: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s4) {
            Text(label).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Picker(label, selection: idx) { ForEach(0..<options.count, id: \.self) { Text(options[$0]).tag($0) } }.pickerStyle(.segmented)
        }
    }

    // MARK: loading

    private func loadVideo(_ item: PhotosPickerItem?) {
        output = nil; preview = nil; errorText = nil
        Task {
            guard let movie = try? await item?.loadTransferable(type: MovieImport.self) else { return }
            let dur = (try? await AVURLAsset(url: movie.url).load(.duration).seconds) ?? 0
            await MainActor.run {
                videoURL = movie.url; videoDuration = dur
                start = 0; length = min(3, max(0.5, dur))
            }
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        output = nil; preview = nil; errorText = nil
        Task {
            var out: [UIImage] = []
            for item in items { if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { out.append(img.normalizedUp()) } }
            await MainActor.run { photos = out }
        }
    }

    // MARK: build

    private func build() {
        guard Usage.use("gif", limit: Limits.freeGifPerDay) else { return }
        working = true; errorText = nil; output = nil; preview = nil
        let maxDim = sizeOptions[sizeIdx].1
        if mode == 0 {
            guard let url = videoURL else { working = false; return }
            let s = start, l = length, fps = fpsOptions[fpsIdx], speed = speedOptions[speedIdx]
            Task {
                let made = await tenzyGIFFromVideo(url: url, start: s, duration: l, fps: fps, speed: speed, maxDim: maxDim)
                await finish(made)
            }
        } else {
            let delay = photoDelays[photoDelayIdx].1
            let datas = photos.compactMap { $0.jpegData(compressionQuality: 0.9) }
            Task.detached {
                let made = tenzyGIFFromImageData(datas, delay: delay, maxDim: maxDim)
                await finish(made)
            }
        }
    }

    @MainActor private func finish(_ url: URL?) {
        working = false
        guard let url else { errorText = "Couldn't build a GIF from that. Try a shorter clip or fewer frames."; return }
        output = url
        if let data = try? Data(contentsOf: url), let src = CGImageSourceCreateWithData(data as CFData, nil),
           let first = CGImageSourceCreateImageAtIndex(src, 0, nil) { preview = UIImage(cgImage: first) }
        HandyHaptics.success()
    }
}

// MARK: - GIF encoding (nonisolated; CGImages never cross an actor boundary)

/// Extract frames across a trim range and write them as a looping GIF.
func tenzyGIFFromVideo(url: URL, start: Double, duration: Double, fps: Double, speed: Double, maxDim: CGFloat) async -> URL? {
    let asset = AVURLAsset(url: url)
    let gen = AVAssetImageGenerator(asset: asset)
    gen.appliesPreferredTrackTransform = true
    gen.requestedTimeToleranceBefore = .zero
    gen.requestedTimeToleranceAfter = .zero
    gen.maximumSize = CGSize(width: maxDim, height: maxDim)

    let total = max(0.2, duration)
    let count = min(Int(total * fps), 72)                 // cap frames so the file stays sane
    guard count > 0 else { return nil }
    var frames: [CGImage] = []
    for i in 0..<count {
        let t = start + (Double(i) / Double(count)) * total
        if let cg = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) { frames.append(cg) }
    }
    guard !frames.isEmpty else { return nil }
    let delay = (1.0 / fps) / speed
    return tenzyWriteGIF(frames: frames, delay: delay)
}

/// Each photo becomes one frame.
func tenzyGIFFromImageData(_ datas: [Data], delay: Double, maxDim: CGFloat) -> URL? {
    var frames: [CGImage] = []
    for d in datas {
        guard let src = CGImageSourceCreateWithData(d as CFData, nil) else { continue }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDim,
        ]
        if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) { frames.append(cg) }
    }
    guard !frames.isEmpty else { return nil }
    return tenzyWriteGIF(frames: frames, delay: delay)
}

private func tenzyWriteGIF(frames: [CGImage], delay: Double) -> URL? {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-\(UUID().uuidString.prefix(6)).gif")
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { return nil }
    let fileProps = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]]
    CGImageDestinationSetProperties(dest, fileProps as CFDictionary)
    let frameProps = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFUnclampedDelayTime as String: delay]]
    for f in frames { CGImageDestinationAddImage(dest, f, frameProps as CFDictionary) }
    guard CGImageDestinationFinalize(dest) else { return nil }
    return url
}

/// Imports a picked video into a stable temp file we can read frames from.
struct MovieImport: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-src-\(UUID().uuidString.prefix(6)).mov")
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return MovieImport(url: copy)
        }
    }
}
