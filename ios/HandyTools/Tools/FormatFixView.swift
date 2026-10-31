import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import ImageIO
import UniformTypeIdentifiers
import UIKit

/// Format Fixer — "the site won't take my iPhone photo / my video won't play on their phone."
/// Pick a batch of photos and videos; choose a target format PER TYPE (photos → JPG/PNG/HEIC/TIFF/
/// GIF/PDF, videos → MP4/MOV/M4V/GIF/Audio) and convert the whole batch at once, metadata stripped.
/// Results are labelled with their new format and videos play back inline before you save or share.
struct FormatFixView: View {
    @EnvironmentObject var store: StoreManager
    @State private var items: [PhotosPickerItem] = []
    @State private var loaded: [(kind: Kind, image: UIImage?, url: URL?)] = []
    @State private var imageOut: ImageOut = .jpg
    @State private var videoOut: VideoOut = .mp4
    @State private var outputs: [URL] = []
    @State private var working = false
    @State private var progress = ""
    @State private var progressValue = 0.0
    @State private var skippedNote: String?
    @State private var errorText: String?
    @State private var playing: PlayerItem?

    private enum Kind { case image, video }
    private var overQuota: Bool { !Usage.hasRoom("formatfix", limit: Limits.freeConvertPerDay) }
    private var maxPick: Int { store.isPremium ? 0 : 10 }
    private var imageCount: Int { loaded.filter { $0.kind == .image }.count }
    private var videoCount: Int { loaded.filter { $0.kind == .video }.count }

    // MARK: output formats

    /// Photo output formats — every one has a real on-device encoder below (never a dead option).
    private enum ImageOut: String, CaseIterable, Identifiable {
        case jpg = "JPG", png = "PNG", heic = "HEIC", tiff = "TIFF", gif = "GIF", pdf = "PDF"
        var id: String { rawValue }
        var ext: String { self == .jpg ? "jpg" : rawValue.lowercased() }
        var note: String {
            switch self {
            case .jpg:  return "smallest, opens anywhere"
            case .png:  return "lossless, keeps transparency"
            case .heic: return "Apple's compact format"
            case .tiff: return "uncompressed, for print/editing"
            case .gif:  return "simple, widely shareable"
            case .pdf:  return "a document page"
            }
        }
    }
    /// Video output formats — MP4/MOV/M4V re-container (H.264/AAC), GIF makes a silent loop, Audio pulls
    /// out the sound as M4A.
    private enum VideoOut: String, CaseIterable, Identifiable {
        case mp4 = "MP4", mov = "MOV", m4v = "M4V", gif = "GIF", audio = "Audio"
        var id: String { rawValue }
        var ext: String { self == .audio ? "m4a" : rawValue.lowercased() }
        var note: String {
            switch self {
            case .mp4:   return "plays on Windows, Android, the web"
            case .mov:   return "Apple-native video"
            case .m4v:   return "Apple/iTunes video"
            case .gif:   return "short silent loop"
            case .audio: return "pull out just the sound (M4A)"
            }
        }
    }
    private struct PlayerItem: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        ToolPage(title: "Format Fixer", subtitle: "Convert photos and videos to the format you need — a whole batch at once, so anything you share opens anywhere.") {
            HowTo("formatfix", [
                "Pick the photos and videos whose format you want to change.",
                "Choose a target format for each type — photos and videos are set separately.",
                "Convert, preview the results, then save or share.",
            ])
            PhotosPicker(selection: $items, maxSelectionCount: maxPick, matching: .any(of: [.images, .videos])) {
                Label(loaded.isEmpty ? "Choose photos & videos" : "Choose a different batch", systemImage: "photo.stack").frame(maxWidth: .infinity)
            }
            .secondaryButton()
            .onAppear { if Launch.sample, loaded.isEmpty { loaded = [(kind: .image, image: SampleAssets.photo(), url: nil)] } }
            .onChange(of: items) { _, new in load(new) }

            if !loaded.isEmpty {
                // One row per file type present, each with its own format picker.
                if imageCount > 0 { typeRow(icon: "photo", count: imageCount, noun: "photo") { imageMenu } }
                if videoCount > 0 { typeRow(icon: "film", count: videoCount, noun: "video") { videoMenu } }

                Text("Location and camera metadata are removed from every file.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)

                if !store.isPremium { QuotaChip(name: "formatfix", limit: Limits.freeConvertPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've converted today's \(Limits.freeConvertPerDay) free batches.") }
                if !store.isPremium { Text("Free converts up to 10 at once. Pro: unlimited.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }

                Button { convert() } label: {
                    Text(working ? (progressValue > 0 ? "Converting… \(Int(progressValue * 100))%" : "Converting…") : "Convert \(loaded.count)").frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota)
                if working { ToolProgressBar(value: progressValue > 0 ? progressValue : nil, label: progress) }
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let skippedNote { Label(skippedNote, systemImage: "info.circle").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true) }

            if !outputs.isEmpty {
                Text("Converted").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HandySpacing.s8) {
                        ForEach(outputs, id: \.self) { url in
                            ResultTile(url: url) { v in playing = PlayerItem(url: v) }
                        }
                    }
                }
                ShareLink(items: outputs) { Label("Save or share (\(outputs.count))", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            }
        }
        .sheet(item: $playing) { item in
            VideoPlayerSheet(url: item.url)
        }
    }

    // MARK: pickers

    private func typeRow<M: View>(icon: String, count: Int, noun: String, @ViewBuilder menu: () -> M) -> some View {
        HStack(spacing: HandySpacing.s8) {
            Label("\(count) \(noun)\(count == 1 ? "" : "s")", systemImage: icon).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(HandyColor.textSecondary)
            menu()
            Spacer()
        }
    }

    private var imageMenu: some View {
        Menu {
            Picker("Photos become", selection: $imageOut) {
                ForEach(ImageOut.allCases) { Text("\($0.rawValue) — \($0.note)").tag($0) }
            }
        } label: { formatPill(imageOut.rawValue) }
    }
    private var videoMenu: some View {
        Menu {
            Picker("Videos become", selection: $videoOut) {
                ForEach(VideoOut.allCases) { Text("\($0.rawValue) — \($0.note)").tag($0) }
            }
        } label: { formatPill(videoOut.rawValue) }
    }
    private func formatPill(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text).font(HandyFont.micro).foregroundStyle(HandyColor.textPrimary)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundStyle(HandyColor.accent)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(HandyColor.surface, in: Capsule())
        .overlay(Capsule().stroke(HandyColor.border, lineWidth: 1))
    }

    // MARK: load

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

    // MARK: convert

    private func convert() {
        guard Usage.hasRoom("formatfix", limit: Limits.freeConvertPerDay) else { return }
        working = true; progressValue = 0; outputs = []; errorText = nil; skippedNote = nil
        let batch = loaded, ifmt = imageOut, vfmt = videoOut
        Task {
            var urls: [URL] = []
            let total = Double(batch.count)
            for (i, entry) in batch.enumerated() {
                let base = Double(i)
                await MainActor.run { progress = batch.count == 1 ? "Converting your file…" : "Converting \(i + 1) of \(batch.count)…" }
                switch entry.kind {
                case .image:
                    if let img = entry.image, let u = await Self.encodeImage(img, as: ifmt, index: i) { urls.append(u) }
                case .video:
                    guard let src = entry.url else { break }
                    let out: URL?
                    switch vfmt {
                    case .mp4:   out = await VideoEngine.toMP4(src, progress: { f in Task { @MainActor in progressValue = (base + f) / total } })
                    case .mov:   out = await VideoEngine.convertContainer(src, type: .mov, ext: "mov")
                    case .m4v:   out = await VideoEngine.convertContainer(src, type: .m4v, ext: "m4v")
                    case .gif:   let dur = await VideoEngine.duration(src)
                                 out = await tenzyGIFFromVideo(url: src, start: 0, duration: dur, fps: 12, speed: 1, maxDim: 480)
                    case .audio: out = await VideoEngine.extractAudio(src)
                    }
                    if let u = out { urls.append(u) }
                }
                await MainActor.run { progressValue = (base + 1) / total }
            }
            let done = urls
            await MainActor.run {
                outputs = done; working = false; progress = ""
                if done.isEmpty { errorText = "Nothing could be converted. Try a different batch or format." }
                else {
                    _ = Usage.use("formatfix", limit: Limits.freeConvertPerDay); HandyHaptics.success()
                    if done.count < batch.count { skippedNote = "Converted \(done.count) of \(batch.count). \(batch.count - done.count) couldn't be read in that format and were skipped." }
                }
            }
        }
    }

    /// Re-encode a photo off the main thread into the chosen format (no metadata).
    private static func encodeImage(_ img: UIImage, as fmt: ImageOut, index: Int) async -> URL? {
        nonisolated(unsafe) let src = img
        return await Task.detached(priority: .userInitiated) {
            let data: Data?
            switch fmt {
            case .jpg:  data = ImageStudio.encode(src, as: .jpg,  quality: 0.9)
            case .png:  data = ImageStudio.encode(src, as: .png,  quality: 1)
            case .heic: data = ImageStudio.encode(src, as: .heic, quality: 0.9)
            case .tiff: data = imageIOData(src, UTType.tiff)
            case .gif:  data = imageIOData(src, UTType.gif)
            case .pdf:  data = pdfData(src)
            }
            guard let d = data else { return nil }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-\(index + 1)-\(UUID().uuidString.prefix(4)).\(fmt.ext)")
            try? d.write(to: url); return url
        }.value
    }
    private static func imageIOData(_ img: UIImage, _ type: UTType) -> Data? {
        guard let cg = img.normalizedUp().cgImage else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, nil)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }
    private static func pdfData(_ img: UIImage) -> Data? {
        let up = img.normalizedUp()
        guard up.size.width > 0, up.size.height > 0 else { return nil }
        let bounds = CGRect(origin: .zero, size: up.size)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { ctx in ctx.beginPage(); up.draw(in: bounds) }
    }
}

/// One converted result: thumbnail, its new format label, and tap-to-play for videos.
private struct ResultTile: View {
    let url: URL
    let onPlay: (URL) -> Void
    @State private var image: UIImage?
    private var ext: String { url.pathExtension.uppercased() }
    private var isVideo: Bool { ["MP4", "MOV", "M4V"].contains(ext) }
    private var isAudio: Bool { ext == "M4A" }
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                HandyColor.surface
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: isAudio ? "waveform" : isVideo ? "film" : "doc.fill").foregroundStyle(HandyColor.textSecondary)
                }
                if isVideo {
                    Image(systemName: "play.circle.fill").font(.system(size: 24)).foregroundStyle(.white.opacity(0.95)).shadow(radius: 2)
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { if isVideo { onPlay(url) } }
            Text(ext).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .task(id: url) { image = await Self.thumbnail(url) }
    }
    private static func thumbnail(_ url: URL) async -> UIImage? {
        let ext = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "heic", "heif", "gif", "tiff"].contains(ext) {
            return await Task.detached { UIImage(contentsOfFile: url.path)?.resized(maxDimension: 240) }.value
        }
        if ext == "pdf" {
            return await Task.detached { () -> UIImage? in
                guard let doc = CGPDFDocument(url as CFURL), let page = doc.page(at: 1) else { return nil }
                let rect = page.getBoxRect(.mediaBox)
                guard rect.width > 0, rect.height > 0 else { return nil }
                let scale = 240 / max(rect.width, rect.height)
                let size = CGSize(width: rect.width * scale, height: rect.height * scale)
                let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
                return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
                    UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
                    c.cgContext.translateBy(x: 0, y: size.height); c.cgContext.scaleBy(x: scale, y: -scale)
                    c.cgContext.drawPDFPage(page)
                }
            }.value
        }
        if ext == "m4a" { return nil }
        return await Task.detached { () -> UIImage? in
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 240, height: 240)
            guard let cg = try? gen.copyCGImage(at: CMTime(seconds: 0.1, preferredTimescale: 600), actualTime: nil) else { return nil }
            return UIImage(cgImage: cg)
        }.value
    }
}

/// A plain player sheet that autoplays the converted clip so the user can check it before sharing.
private struct VideoPlayerSheet: View {
    let url: URL
    @State private var player = AVPlayer()
    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .onAppear { player.replaceCurrentItem(with: AVPlayerItem(url: url)); player.play() }
            .onDisappear { player.pause() }
    }
}
