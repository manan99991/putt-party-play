import SwiftUI
import PhotosUI
import AVKit
import UIKit

/// Media Studio — one photo or video at the top, seven jobs under it: shrink to a size, cut the
/// background out, redact, passport crop, strip location, convert, or make it share-ready.
/// Composes the existing engines (ImageStudio, SizeTarget, VideoEngine, Scrubber, Share-Ready
/// recipes); the picked asset is shared across every tab. Free quotas are charged only on success.
struct MediaHub: View {
    @EnvironmentObject var store: StoreManager

    private static let tabs = ["Shrink", "Remove bg", "Redact", "Passport", "Strip location", "Convert", "Share-ready"]
    private enum Kind { case photo, video }
    private enum Output { case jpg(Data), png(Data), heic(Data), file(URL) }
    private struct Target { let label: String; var bytes: Int? = nil; var px: CGFloat? = nil }
    private static let photoTargets = [Target(label: "Under 500 KB", bytes: 500_000), Target(label: "Under 1 MB", bytes: 1_000_000), Target(label: "Under 2 MB", bytes: 2_000_000), Target(label: "Under 5 MB", bytes: 5_000_000), Target(label: "1080p", px: 1080), Target(label: "720p", px: 720)]
    private static let videoTargets = [Target(label: "Under 100 MB", bytes: 100_000_000), Target(label: "Under 25 MB", bytes: 25_000_000), Target(label: "Under 16 MB", bytes: 16_000_000), Target(label: "Under 10 MB", bytes: 10_000_000), Target(label: "Under 5 MB", bytes: 5_000_000), Target(label: "1080p", px: 1080), Target(label: "720p", px: 720)]
    private static let bgOptions = ["Transparent", "White", "Blur", "Colour"]

    @State private var tab = 0
    @State private var photoItem: PhotosPickerItem?
    @State private var videoItem: PhotosPickerItem?
    @State private var kind: Kind?
    @State private var image: UIImage?
    @State private var imageData: Data?
    @State private var videoURL: URL?
    @State private var videoDuration: Double = 0
    @State private var videoThumb: UIImage?
    @State private var origBytes = 0
    @State private var origDims = "—"
    @State private var preview: UIImage?
    @State private var player: AVPlayer?
    @State private var output: Output?
    @State private var resultBytes: Int?
    @State private var resultDims: String?
    @State private var working = false
    @State private var errorText: String?
    @State private var note: String?
    @State private var saved = false
    @State private var saving = false
    // per-tab options
    @State private var shrinkIdx = 1
    @State private var bgIdx = 0
    @State private var bgColor: Color = Color(red: 0.84, green: 0.9, blue: 0.97)
    @State private var boxes: [RedactBox] = []
    @State private var detecting = false
    @State private var specIdx = 0
    @State private var passportWhite = true
    @State private var sheet: Data?
    @State private var meta = Scrubber.Metadata()
    @State private var stripped = false
    @State private var convIdx = 0
    @State private var recipeIdx = 0

    private var hasAsset: Bool { kind != nil }
    private var isPhoto: Bool { kind == .photo }
    private var srcFormat: String { imageData.map { MediaKit.format(of: $0) } ?? "Image" }
    private var videoExt: String { videoURL?.pathExtension.uppercased() ?? "MOV" }

    /// Which free counter each tab draws on (same keys as the legacy tools, so limits stay honest).
    private var quota: (name: String, limit: Int) {
        switch tab {
        case 0: return isPhoto ? ("fitit", Limits.freeFitPerDay) : ("video", Limits.freeVideoPerDay)
        case 1, 3: return ("studio", Limits.freeStudioPerDay)
        case 2: return ("scrub", Limits.freeScrubPerDay)
        case 4: return isPhoto ? ("scrub", Limits.freeScrubPerDay) : ("video", Limits.freeVideoPerDay)
        case 5: return isPhoto ? ("formatfix", Limits.freeConvertPerDay) : ("video", Limits.freeVideoPerDay)
        default: return ("shareready", Limits.freeFitPerDay)
        }
    }
    private var overQuota: Bool { !Usage.hasRoom(quota.name, limit: quota.limit) }

    var body: some View {
        PowerToolPage(id: "media", tabs: Self.tabs, selected: $tab) {
            previewBox
            HStack(spacing: HandySpacing.s8) {
                PhotosPicker(selection: $photoItem, matching: .images) { Label("Choose photo", systemImage: "photo").frame(maxWidth: .infinity) }.secondaryButton()
                PhotosPicker(selection: $videoItem, matching: .videos) { Label("Video", systemImage: "film").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if hasAsset { statsRow }
            Group {
                switch tab {
                case 0: shrinkPanel
                case 1: bgPanel
                case 2: redactPanel
                case 3: passportPanel
                case 4: stripPanel
                case 5: convertPanel
                default: sharePanel
                }
            }
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
            if output != nil { exportCard }
        }
        .onChange(of: photoItem) { _, item in loadPhoto(item) }
        .onChange(of: videoItem) { _, item in loadVideo(item) }
        .onChange(of: tab) { _, _ in resetResult() }
        .onAppear { if Launch.sample, kind == nil { useSample() } }
        .onDisappear { player?.pause() }
    }

    // MARK: preview + stats

    private var previewBox: some View {
        HubPreviewBox(minHeight: 280) {
            Group {
                if kind == .photo, let image {
                    if tab == 2, output == nil {
                        RedactCanvas(image: image, boxes: $boxes, busy: detecting)
                    } else {
                        ZStack {
                            if case .png = output { Checkerboard() }
                            Image(uiImage: preview ?? image).resizable().scaledToFit()
                        }
                    }
                } else if kind == .video {
                    if let player { VideoPlayer(player: player) }
                    else if let preview { Image(uiImage: preview).resizable().scaledToFit() }
                    else if let videoThumb { Image(uiImage: videoThumb).resizable().scaledToFit().overlay(Image(systemName: "play.circle.fill").font(.system(size: 44)).foregroundStyle(.white.opacity(0.9))) }
                    else { ProgressView() }
                } else {
                    VStack(spacing: HandySpacing.s8) {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 30)).foregroundStyle(HandyColor.accent)
                        Text("Pick a photo or video to get it ready to send, post or print.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                    }.padding(HandySpacing.s16)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var statsRow: some View {
        HStack(spacing: HandySpacing.s8) {
            stat(SizeTarget.format(origBytes), "original")
            stat(resultBytes.map { SizeTarget.format($0) } ?? "—", "result")
            stat(resultDims ?? origDims, "size")
        }
    }
    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 15, weight: .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(l).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 10).cardStyle(padding: 6)
    }

    // MARK: panels

    private var shrinkPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HubSection("Target")
            let targets = isPhoto ? Self.photoTargets : Self.videoTargets
            FlowLayout(spacing: 6) {
                ForEach(Array(targets.enumerated()), id: \.offset) { i, t in HubChip(t.label, selected: shrinkIdx == i) { shrinkIdx = i; errorText = nil } }
            }
            if kind == .video, let b = targets[min(shrinkIdx, targets.count - 1)].bytes, videoDuration > 0 {
                let kbps = max(0, (Double(b) * 8 / videoDuration - 96_000) / 1000)
                HubNote(kbps < 400 ? "That's about \(Int(kbps)) kbps — expect visible quality loss. Trim it shorter first for a sharper result." : "About \(Int(kbps)) kbps of video — \(kbps > 2500 ? "looks great" : "looks fine on a phone").")
            }
            actionButton("Shrink") { await runShrink(targets[min(shrinkIdx, targets.count - 1)]) }
        }
    }

    private var bgPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HubPill("Runs on your phone · Vision subject lift", tone: .native)
            FlowLayout(spacing: 6) {
                ForEach(Array(Self.bgOptions.enumerated()), id: \.offset) { i, o in HubChip(o, selected: bgIdx == i) { bgIdx = i } }
            }
            if bgIdx == 3 { ColorPicker("Background colour", selection: $bgColor, supportsOpacity: false).font(HandyFont.body) }
            photoOnly("Remove background") { await runCutout() }
        }
    }

    private var redactPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HubNote("Drag on the photo to black out faces, names, card numbers. Faces and text are found on the phone — tap a box to toggle it.")
            if isPhoto {
                FlowLayout(spacing: 6) {
                    HubChip("Faces (\(boxes.filter { $0.kind == .face }.count))", selected: boxes.contains { $0.kind == .face && $0.on }) { setAll(.face, on: !boxes.contains { $0.kind == .face && $0.on }) }
                    HubChip("Text (\(boxes.filter { $0.kind == .text }.count))", selected: boxes.contains { $0.kind == .text && $0.on }) { setAll(.text, on: !boxes.contains { $0.kind == .text && $0.on }) }
                    HubChip("Undo", selected: false) { if let i = boxes.lastIndex(where: { $0.kind == .manual }) { boxes.remove(at: i) } else if !boxes.isEmpty { boxes.removeLast() } }
                }
            }
            HubNote("Blocks are permanent: the pixels underneath are gone in the copy, and metadata is stripped too.")
            photoOnly("Save redacted") { await runRedact() }
        }
    }

    private var passportPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            FlowLayout(spacing: 6) {
                ForEach(Array(ImageStudio.passportSpecs.enumerated()), id: \.offset) { i, s in HubChip(s.name, selected: specIdx == i) { specIdx = i } }
            }
            Toggle("Clean white background", isOn: $passportWhite).tint(HandyColor.accent).font(HandyFont.body)
            photoOnly("Crop to passport size") { await runPassport() }
            if sheet == nil, case .jpg = output, tab == 3, let p = preview {
                Button { sheet = ImageStudio.printSheet(p); if sheet != nil { HandyHaptics.success() } } label: { Label("Make a 4×6 print sheet", systemImage: "squareshape.split.3x3").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if let sheet { ShareLink(item: JPEGFile(data: sheet), preview: SharePreview("Print sheet")) { Label("Save the print sheet (4×6)", systemImage: "printer").frame(maxWidth: .infinity) }.secondaryButton() }
            HubNote("Centres the face and crops to the exact ratio; prints 4 or 6 on a 4×6 sheet. Check your country's exact rules before submitting.")
        }
    }

    private var stripPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            VStack(spacing: 0) {
                metaRow("GPS location", meta.hasGPS ? "Present" : "None", danger: meta.hasGPS)
                metaRow("Camera / device", meta.device ?? "—", danger: false)
                metaRow("Date taken", meta.taken ?? "—", danger: false)
            }.cardStyle(padding: 0)
            actionButton("Strip metadata & save") { await runStrip() }
            HubNote(isPhoto ? "Re-encodes the image so nothing hidden travels with it." : "Re-wraps the video as MP4 with every metadata tag dropped.")
        }
    }
    private func metaRow(_ k: String, _ v: String, danger: Bool) -> some View {
        HStack {
            Text(k).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary); Spacer()
            Text(stripped ? "Removed" : v).font(HandyFont.bodyStrong).foregroundStyle(stripped ? HandyColor.success : (danger ? HandyColor.danger : HandyColor.textPrimary)).lineLimit(1)
        }.padding(.horizontal, HandySpacing.s12).padding(.vertical, 10)
    }

    private var convertOptions: [String] {
        if isPhoto { return ["JPG", "PNG", "HEIC"].filter { $0 != srcFormat }.map { "\(srcFormat) → \($0)" } }
        return ["\(videoExt) → MP4", "Video → GIF", "Video → audio (M4A)"]
    }
    private var convertPanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            FlowLayout(spacing: 6) {
                ForEach(Array(convertOptions.enumerated()), id: \.offset) { i, o in HubChip(o, selected: convIdx == i) { convIdx = i } }
            }
            actionButton("Convert") { await runConvert() }
            HubPill("Runs on your phone · the phone's own codecs", tone: .native)
            HubNote("HEIC and video use the phone's own codecs. Audio comes out as M4A — iOS has no MP3 encoder, and M4A plays everywhere.")
        }
    }

    private var sharePanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HubSection("Where is it going?")
            FlowLayout(spacing: 6) {
                ForEach(Array(ShareReadyView.recipes.enumerated()), id: \.offset) { i, r in HubChip(r.name, selected: recipeIdx == i) { recipeIdx = i } }
            }
            HubNote(ShareReadyView.recipes[recipeIdx].hint + " · metadata stripped")
            actionButton("Make share-ready") { await runShareReady(ShareReadyView.recipes[recipeIdx]) }
        }
    }

    // MARK: buttons

    /// Primary action with the free-quota chip/banner; disabled until something is picked.
    private func actionButton(_ label: String, _ job: @escaping @MainActor () async -> Bool) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if hasAsset && !store.isPremium { QuotaChip(name: quota.name, limit: quota.limit).environmentObject(store) }
            if hasAsset && overQuota { LimitReachedBanner(message: "You've used today's \(quota.limit) free \(Self.tabs[tab].lowercased()) jobs.") }
            Button { perform(job) } label: {
                HStack { if working { ProgressView().tint(.white) }; Text(working ? "Working… you can switch apps" : label) }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(!hasAsset || working || overQuota)
        }
    }

    /// Photo-only tabs: with a video picked, offer the photo picker right there instead of a dead button.
    @ViewBuilder private func photoOnly(_ label: String, _ job: @escaping @MainActor () async -> Bool) -> some View {
        if kind == .video {
            HubNote("This one works on photos.")
            PhotosPicker(selection: $photoItem, matching: .images) { Label("Choose a photo", systemImage: "photo").frame(maxWidth: .infinity) }.primaryButton()
        } else {
            actionButton(label, job)
        }
    }

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(spacing: HandySpacing.s8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(HandyColor.success)
                Text(readyLine).font(HandyFont.bodyStrong)
            }
            HStack(spacing: HandySpacing.s8) {
                if canSaveToPhotos {
                    Button { saveToPhotos() } label: {
                        HStack { if saving { ProgressView() }; Label(saved ? "Saved to Photos" : "Save to Photos", systemImage: saved ? "checkmark" : "square.and.arrow.down") }.frame(maxWidth: .infinity)
                    }.secondaryButton().disabled(saving || saved)
                }
                shareLink
            }
        }.cardStyle(padding: HandySpacing.s12)
    }
    private var readyLine: String {
        var s = "Ready"
        if let b = resultBytes {
            s += " — \(SizeTarget.format(b))"
            if origBytes > 0, b < origBytes { s += " · \(Int((1 - Double(b) / Double(origBytes)) * 100))% smaller" }
        }
        return s
    }
    private var canSaveToPhotos: Bool {
        switch output {
        case .jpg, .png, .heic: return true
        case .file(let u): return ["mp4", "mov", "gif"].contains(u.pathExtension.lowercased())
        case .none: return false
        }
    }
    @ViewBuilder private var shareLink: some View {
        switch output {
        case .jpg(let d): ShareLink(item: JPEGFile(data: d), preview: SharePreview("Media Studio")) { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        case .png(let d): ShareLink(item: PNGFile(data: d), preview: SharePreview("Media Studio")) { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        case .heic(let d): ShareLink(item: HEICFile(data: d), preview: SharePreview("Media Studio")) { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        case .file(let u): ShareLink(item: u) { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        case .none: EmptyView()
        }
    }

    // MARK: loading

    private func resetResult() { output = nil; preview = nil; resultBytes = nil; resultDims = nil; errorText = nil; note = nil; saved = false; sheet = nil; stripped = false; player?.pause(); player = nil }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) else { await MainActor.run { errorText = "Couldn't load that photo." }; return }
            await MainActor.run { setPhoto(img.normalizedUp(), data: d) }
        }
    }
    private func setPhoto(_ img: UIImage, data: Data) {
        resetResult(); boxes = []; stripped = false; videoURL = nil; videoThumb = nil
        kind = .photo; image = img; imageData = data; origBytes = data.count; origDims = MediaKit.dims(img)
        meta = Scrubber.metadata(in: data); detecting = true; convIdx = 0
        Task {
            let found = await Task.detached(priority: .userInitiated) { Scrubber.detect(img) }.value
            await MainActor.run {
                boxes = found.faces.map { RedactBox(rect: $0, kind: .face, on: true) } + found.text.map { RedactBox(rect: $0, kind: .text, on: false) }
                detecting = false
            }
        }
    }
    private func loadVideo(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let movie = try? await item.loadTransferable(type: MovieImport.self) else { await MainActor.run { errorText = "Couldn't load that video." }; return }
            let d = await VideoEngine.duration(movie.url)
            let t = await VideoEngine.thumbnail(movie.url, at: min(0.5, d / 2))
            let dims = await MediaKit.videoDims(movie.url)
            let m = await MediaKit.videoMetadata(movie.url)
            await MainActor.run {
                resetResult(); boxes = []; stripped = false; image = nil; imageData = nil
                kind = .video; videoURL = movie.url; videoDuration = d; videoThumb = t
                origBytes = SizeTarget.fileSize(movie.url) ?? 0; origDims = "\(dims ?? "video") · \(VideoView.clock(d))"
                meta = m; convIdx = 0; shrinkIdx = 1
            }
        }
    }
    private func useSample() {
        let img = SampleAssets.photo()
        if let d = img.jpegData(compressionQuality: 0.95) { setPhoto(img, data: d) }
    }

    // MARK: run

    private func perform(_ job: @escaping @MainActor () async -> Bool) {
        let q = quota
        guard hasAsset, Usage.hasRoom(q.name, limit: q.limit) else { return }   // gate only — charge on success
        working = true; errorText = nil; note = nil; output = nil; resultBytes = nil; resultDims = nil; saved = false; sheet = nil; player?.pause(); player = nil
        Task { @MainActor in
            let ok = await VideoEngine.backgrounded("tenzy.media") { await job() }
            working = false
            if ok { _ = Usage.use(q.name, limit: q.limit); HandyHaptics.success() }
        }
    }
    private func finishImage(_ img: UIImage?, _ out: Output, bytes: Int) {
        preview = img; output = out; resultBytes = bytes; resultDims = img.map { MediaKit.dims($0) }
    }
    @MainActor private func finishVideo(_ url: URL) async {
        let bytes = SizeTarget.fileSize(url) ?? 0
        let ext = url.pathExtension.lowercased()
        if ext == "gif" { preview = UIImage(contentsOfFile: url.path); resultDims = "GIF" }
        else if ext == "m4a" { preview = videoThumb; resultDims = "Audio · M4A" }
        else {
            let dims = await MediaKit.videoDims(url)
            player = AVPlayer(url: url); resultDims = "\(dims ?? "MP4") · MP4"
        }
        output = .file(url); resultBytes = bytes
    }

    @MainActor private func runShrink(_ t: Target) async -> Bool {
        if let img = image, isPhoto {
            if let b = t.bytes {
                guard let d = await SizeTarget.image(img, targetBytes: b) else { errorText = "Couldn't get this photo under \(SizeTarget.format(b)) without ruining it. Try a larger limit."; return false }
                finishImage(UIImage(data: d), .jpg(d), bytes: d.count); return true
            }
            let px = t.px ?? 1080
            let r = await Task.detached(priority: .userInitiated) { () -> (UIImage, Data?) in let i = img.resized(maxDimension: px); return (i, i.jpegData(compressionQuality: 0.9)) }.value
            guard let d = r.1 else { errorText = "Couldn't resize this photo."; return false }
            finishImage(r.0, .jpg(d), bytes: d.count); return true
        }
        guard let src = videoURL else { return false }
        if let b = t.bytes {
            guard let r = await SizeTarget.videoBestEffort(url: src, targetBytes: b) else { errorText = "Couldn't process this video — it may be DRM-protected or damaged."; return false }
            await finishVideo(r.url)
            if !r.fits { note = "This is the smallest I can make it without wrecking it. To get under \(SizeTarget.format(b)), trim it shorter first." }
            return true
        }
        guard let out = await VideoEngine.transcodeH264(AVURLAsset(url: src), maxDimension: t.px ?? 1080) else { errorText = "Couldn't shrink this video. It may be DRM-protected or damaged."; return false }
        await finishVideo(out); return true
    }

    @MainActor private func runCutout() async -> Bool {
        guard let img = image else { return false }
        guard let cut = await Task.detached(priority: .userInitiated) { ImageStudio.cutout(img) }.value else { errorText = "Couldn't find a clear subject. Try a photo with a distinct foreground."; return false }
        let mode = bgIdx, colour = UIColor(bgColor)
        let r = await Task.detached(priority: .userInitiated) { () -> (UIImage, Data?, Bool) in
            switch mode {
            case 1: let c = ImageStudio.composite(cut, on: .white); return (c, c.jpegData(compressionQuality: 0.92), false)
            case 2: let c = MediaKit.blurBackground(subject: cut, original: img); return (c, c.jpegData(compressionQuality: 0.92), false)
            case 3: let c = ImageStudio.composite(cut, on: colour); return (c, c.jpegData(compressionQuality: 0.92), false)
            default: return (cut, cut.pngData(), true)
            }
        }.value
        guard let d = r.1 else { errorText = "Couldn't save the cut-out."; return false }
        finishImage(r.0, r.2 ? .png(d) : .jpg(d), bytes: d.count); return true
    }

    @MainActor private func runRedact() async -> Bool {
        guard let img = image else { return false }
        let rects = boxes.filter { $0.on }.map { $0.rect }
        guard let d = await Task.detached(priority: .userInitiated) { Scrubber.render(img, rects: rects) }.value else { errorText = "Couldn't make the redacted copy. Try another photo."; return false }
        finishImage(UIImage(data: d), .jpg(d), bytes: d.count); stripped = true; return true
    }

    @MainActor private func runPassport() async -> Bool {
        guard let img = image else { return false }
        let spec = ImageStudio.passportSpecs[min(specIdx, ImageStudio.passportSpecs.count - 1)], white = passportWhite
        guard let out = await Task.detached(priority: .userInitiated) { ImageStudio.passport(img, spec: spec, background: white ? .white : nil) }.value,
              let d = out.jpegData(compressionQuality: 0.95) else { errorText = "Couldn't find a clear face. Use a straight-on portrait with the whole head visible."; return false }
        finishImage(out, .jpg(d), bytes: d.count); resultDims = "\(spec.name) @300dpi"; return true
    }

    @MainActor private func runStrip() async -> Bool {
        if let img = image, isPhoto {
            guard let d = await Task.detached(priority: .userInitiated) { Scrubber.render(img, rects: []) }.value else { errorText = "Couldn't make the clean copy."; return false }
            finishImage(UIImage(data: d), .jpg(d), bytes: d.count); stripped = true; return true
        }
        guard let src = videoURL, let out = await VideoEngine.toMP4(src) else { errorText = "Couldn't re-wrap this video. It may be DRM-protected or damaged."; return false }
        await finishVideo(out); stripped = true; return true
    }

    @MainActor private func runConvert() async -> Bool {
        if let img = image, isPhoto {
            let targets: [ImageStudio.Format] = [.jpg, .png, .heic].filter { $0.rawValue != srcFormat }
            let fmt = targets[min(convIdx, targets.count - 1)]
            guard let d = await Task.detached(priority: .userInitiated) { ImageStudio.encode(img, as: fmt, quality: 0.9) }.value else { errorText = "This device can't write \(fmt.rawValue)."; return false }
            switch fmt { case .jpg: finishImage(img, .jpg(d), bytes: d.count); case .png: finishImage(img, .png(d), bytes: d.count); case .heic: finishImage(img, .heic(d), bytes: d.count) }
            return true
        }
        guard let src = videoURL else { return false }
        let out: URL?
        switch convIdx {
        case 1: out = await tenzyGIFFromVideo(url: src, start: 0, duration: min(3, max(0.5, videoDuration)), fps: 10, speed: 1, maxDim: 480)
        case 2: out = await VideoEngine.extractAudio(src)
        default: out = await VideoEngine.toMP4(src)
        }
        guard let out else { errorText = convIdx == 2 ? "This clip has no audio track to save." : "Couldn't convert this video. It may be DRM-protected or damaged."; return false }
        await finishVideo(out)
        if convIdx == 1 { note = "First 3 seconds at 10 fps — a GIF that actually sends in chat." }
        return true
    }

    @MainActor private func runShareReady(_ r: ShareReadyView.Recipe) async -> Bool {
        if let img = image, isPhoto {
            guard let d = await SizeTarget.image(img, targetBytes: r.imageBytes) else { errorText = "Couldn't fit this photo under \(SizeTarget.format(r.imageBytes)). Try a looser recipe."; return false }
            finishImage(UIImage(data: d), .jpg(d), bytes: d.count); note = "Ready for \(r.name.lowercased())"; return true
        }
        guard let src = videoURL, let mp4 = await VideoEngine.toMP4(src) else { errorText = "Couldn't convert this video. It may be DRM-protected or damaged."; return false }
        guard let fit = await SizeTarget.videoBestEffort(url: mp4, targetBytes: r.videoBytes) else { errorText = "Couldn't shrink this video."; return false }
        await finishVideo(fit.url)
        note = fit.fits ? "Ready for \(r.name.lowercased())" : "Smallest without wrecking it — still over \(SizeTarget.format(r.videoBytes)). Trim it shorter first."
        return true
    }

    private func setAll(_ k: RedactBox.Kind, on: Bool) { for i in boxes.indices where boxes[i].kind == k { boxes[i].on = on } }

    private func saveToPhotos() {
        guard let output else { return }
        saving = true
        Task { @MainActor in
            let ok: Bool
            switch output {
            case .jpg(let d), .png(let d), .heic(let d): ok = await MediaKit.saveImage(d)
            case .file(let u):
                if u.pathExtension.lowercased() == "gif" { ok = await MediaKit.saveImage((try? Data(contentsOf: u)) ?? Data()) }
                else { ok = await MediaKit.saveVideo(u) }
            }
            saving = false; saved = ok
            if ok { HandyHaptics.success() } else { errorText = "Couldn't save to Photos — allow photo access in Settings, or use Share." }
        }
    }
}
