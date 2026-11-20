import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

/// Video — one clip in, the six things people actually hunt for across six different apps:
/// shrink to an exact size, trim, convert to MP4, mute, pull the audio out, or make a GIF.
/// Results chain ("Use this as the source") so trim → shrink is two taps, and every export runs
/// under a background task so switching apps for a minute never kills a long job.
struct VideoView: View {
    @EnvironmentObject var store: StoreManager

    private enum Mode: Int, CaseIterable { case shrink, trim, convert, mute, audio, gif, social
        var title: String { ["Shrink", "Trim", "To MP4", "Mute", "Audio only", "GIF", "For social"][rawValue] }
        var icon: String { ["arrow.down.right.and.arrow.up.left", "scissors", "film", "speaker.slash", "waveform", "photo.stack", "rectangle.portrait.on.rectangle.portrait"][rawValue] }
    }
    private struct Output { let url: URL; let bytes: Int; let kind: Kind; enum Kind { case video, audio, gif } }

    @State private var pickedItem: PhotosPickerItem?
    @State private var gifPhotoItems: [PhotosPickerItem] = []
    @State private var source: URL?
    @State private var sourceBytes = 0
    @State private var duration: Double = 0
    @State private var thumb: UIImage?
    @State private var mode: Mode = .shrink
    @ObservedObject private var bus = JobBus.shared
    private let jobKey = "video"
    private var job: JobBus.State { bus.state(jobKey) }
    private var working: Bool { job.working }
    private var progressValue: Double { job.progress }
    @State private var errorText: String?
    @State private var resultNote: String?   // honest "smallest we could do" line when a shrink can't hit the target
    @State private var result: Output?
    @State private var player: AVPlayer?

    // shrink
    @State private var targetBytes = 25_000_000
    @State private var customValue = ""
    @State private var customUnitMB = true
    /// The limits people actually hit with video: email, WhatsApp, Discord, most portals.
    private let videoPresets: [(label: String, bytes: Int)] = [("100 MB", 100_000_000), ("25 MB", 25_000_000), ("16 MB", 16_000_000), ("10 MB", 10_000_000), ("8 MB", 8_000_000), ("5 MB", 5_000_000), ("2 MB", 2_000_000)]
    // trim
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0
    @State private var startThumb: UIImage?
    @State private var endThumb: UIImage?
    @State private var strip: [UIImage] = []
    @State private var keptPreview: AVPlayer?
    // gif
    @State private var gifFrom: Double = 0
    @State private var gifLength: Double = 3
    @State private var gifFPS: Double = 10
    @State private var gifSpeed: Double = 1
    @State private var gifWidthIdx = 1
    private let gifWidths: [(String, CGFloat)] = [("Small 320", 320), ("Medium 480", 480), ("Large 640", 640)]
    @State private var gifPhotoDelay: Double = 0.5
    @State private var gifPhotos: [Data] = []
    @State private var socialFormat: VideoFormat.Spec = VideoFormat.presets[0]
    @State private var socialFit = false
    @State private var sendPlace: SendOn.Place?
    @State private var sendParts: [URL] = []
    @State private var sendSaved: Int?

    private var overQuota: Bool { !Usage.hasRoom("video", limit: Limits.freeVideoPerDay) }

    var body: some View {
        ToolPage(title: "Video", subtitle: "Shrink to a size limit, trim, convert, mute, pull the audio, or make a GIF — one clip, one place.") {
            HowTo("video", [
                "Pick a clip and choose what to do — trim, convert, mute, shrink or make a GIF.",
                "Set the options for that mode, like a size limit.",
                "Export, then save or share.",
            ])
            if source == nil {
                PhotosPicker(selection: $pickedItem, matching: .videos) {
                    Label(L("Choose a video"), systemImage: "film").frame(maxWidth: .infinity)
                }.secondaryButton()
                Text(L("Or make a GIF from photos:")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                PhotosPicker(selection: $gifPhotoItems, maxSelectionCount: 30, matching: .images) {
                    Label(L("Choose photos for a GIF"), systemImage: "photo.stack").frame(maxWidth: .infinity)
                }.secondaryButton()
                if !gifPhotos.isEmpty { photoGIFControls }
            }

            if let source {
                sourceCard(source)
                sendOnCard(source)
                Text(L("Or do one thing to it:")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                modeChips
                switch mode {
                case .shrink: shrinkControls
                case .trim: trimControls
                case .convert: note("Re-encodes as H.264 MP4 — the one format Windows, Android, WhatsApp and the web all play. Metadata (location, device) is dropped.")
                case .mute: note("Keeps the picture, removes every audio track. Handy before posting something recorded in a loud room.")
                case .audio: note("Saves just the sound as an M4A you can send, transcribe, or set as a ringtone source.")
                case .gif: gifControls
                case .social: socialControls
                }

                if !store.isPremium { QuotaChip(name: "video", limit: Limits.freeVideoPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freeVideoPerDay) free video jobs.") }

                Button { run() } label: {
                    Text(working ? (progressValue > 0 ? "Working… \(Int(progressValue * 100))%" : "Working…") : actionLabel).frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || overQuota || !canRun)
                if working {
                    ToolProgressBar(value: progressValue > 0 ? progressValue : nil, label: "Keep Tenzy open while this finishes.")
                }

                PhotosPicker(selection: $pickedItem, matching: .videos) { Label(L("Choose a different video"), systemImage: "film") }.textButton()
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let result { resultCard(result) }
        }
        .onChange(of: pickedItem) { _, item in loadVideo(item) }
        .onAppear { if Launch.sample, source == nil { Task { if let url = await SampleAssets.movie() { let d = await VideoEngine.duration(url); let t = await VideoEngine.thumbnail(url, at: 0.5); await MainActor.run { source = url; sourceBytes = SizeTarget.fileSize(url) ?? 0; duration = d; thumb = t; trimStart = 0; trimEnd = d; gifLength = min(3, max(0.5, d)); targetBytes = 2_000_000; refreshTrimThumbs(); refreshStrip() } } } } }
        .onChange(of: gifPhotoItems) { _, items in loadGIFPhotos(items) }
        .onChange(of: trimStart) { _, v in refreshTrimThumbs(); keptPreview?.pause(); if trimEnd < v + 0.5 { trimEnd = min(duration, v + 0.5) } }
        .onChange(of: trimEnd) { _, v in refreshTrimThumbs(); if trimStart > v - 0.5 { trimStart = max(0, v - 0.5) } }
        .onChange(of: job.stamp) { _, _ in syncJob() }
        .onAppear { syncJob() }
        .onDisappear { player?.pause(); keptPreview?.pause() }
        // A video shared in, or picked from "Start with what you have → Video", opens straight here.
        .handoff("video") { p in if let u = ToolHandoff.fileURL(p) { open(u) } }
    }

    // MARK: send on…

    @ViewBuilder private func sendOnCard(_ src: URL) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Where are you sending it?"), systemImage: "paperplane.fill").font(HandyFont.bodyStrong)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(SendOn.places) { p in
                    HChip(text: p.name, selected: sendPlace?.id == p.id) { sendPlace = p; sendParts = []; sendSaved = nil }
                }
            }
            if let p = sendPlace, duration > 0 {
                let plan = SendOn.plan(duration: duration, bytes: sourceBytes, place: p)
                ForEach(plan.lines, id: \.self) { Label(L($0), systemImage: "checkmark").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                if sendParts.isEmpty {
                    Button {
                        guard Usage.hasRoom("video", limit: Limits.freeVideoPerDay) else { return }
                        let d = duration, name = p.name
                        errorText = nil
                        bus.run(jobKey, label: "Making it for \(name)…") { report in
                            let parts = await SendOn.make(src, plan: plan, duration: d, progress: report)
                            return (parts, "sendon", nil, parts.isEmpty ? "Couldn't make it for \(name). Try trimming it shorter first." : nil)
                        }
                    } label: { Label("\(L("Make it for")) \(L(p.name))", systemImage: "wand.and.stars").frame(maxWidth: .infinity) }
                        .primaryButton().disabled(working || overQuota).accessibilityIdentifier("video-sendon-make")
                } else {
                    ForEach(Array(sendParts.enumerated()), id: \.offset) { i, u in
                        Text("\(sendParts.count > 1 ? "\(L("Part")) \(i + 1): " : "")\(SizeTarget.format(SizeTarget.fileSize(u) ?? 0))\(sourceBytes > 0 ? " · \(L("was")) \(SizeTarget.format(sourceBytes))" : "")")
                            .font(HandyFont.caption.weight(.semibold))
                    }
                    ShareLink(items: sendParts) { Label(L(sendParts.count > 1 ? "Send all parts" : "Send it"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                        .primaryButton()
                    Button {
                        Task { var n = 0; for u in sendParts { if await PhotoSaver.saveVideo(u) { n += 1 } }; sendSaved = n }
                    } label: { Label(L(sendSaved == nil ? "Save to Photos" : "Saved \(sendSaved!) to Photos"), systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }
                        .secondaryButton()
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
    }

    // MARK: pieces

    private func sourceCard(_ url: URL) -> some View {
        HStack(spacing: HandySpacing.s12) {
            if let thumb { Image(uiImage: thumb).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)) }
            else { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(HandyColor.surface).frame(width: 64, height: 64).overlay(Image(systemName: "film").foregroundStyle(HandyColor.textSecondary)) }
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Your video")).font(HandyFont.bodyStrong)
                Text("\(Self.clock(duration)) · \(SizeTarget.format(sourceBytes))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Spacer()
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var modeChips: some View {
        HandyFlow(spacing: HandySpacing.s8) {
            ForEach(Mode.allCases, id: \.rawValue) { m in HChip(text: m.title, selected: mode == m) { mode = m; errorText = nil } }
        }
    }

    private func note(_ s: String) -> some View { Text(s).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }

    private var shrinkControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Must be under")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(videoPresets, id: \.bytes) { p in
                    HChip(text: p.label, selected: targetBytes == p.bytes && customValue.isEmpty) { targetBytes = p.bytes; customValue = ""; errorText = nil }
                }
            }
            HStack(spacing: HandySpacing.s8) {
                TextField(L("Custom"), text: $customValue).keyboardType(.decimalPad)
                    .padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .onChange(of: customValue) { _, _ in applyCustom() }
                Picker(L("Unit"), selection: $customUnitMB) { Text(L("MB")).tag(true); Text(L("KB")).tag(false) }.pickerStyle(.segmented).frame(width: 120)
                    .onChange(of: customUnitMB) { _, _ in applyCustom() }
            }
            if duration > 0 {
                let kbps = max(0, (Double(targetBytes) * 8 / duration - 96_000) / 1000)
                Text(kbps < 400 ? "That's about \(Int(kbps)) kbps — expect visible quality loss. Trim it shorter first for a sharper result."
                                : "About \(Int(kbps)) kbps of video — \(kbps > 2500 ? "looks great" : "looks fine on a phone").")
                    .font(HandyFont.caption).foregroundStyle(kbps < 400 ? HandyColor.danger : HandyColor.textSecondary)
            }
        }
    }

    private var trimControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(spacing: HandySpacing.s12) {
                trimFrame(startThumb, label: "Start \(Self.clock(trimStart))")
                trimFrame(endThumb, label: "End \(Self.clock(trimEnd))")
            }
            TrimStrip(frames: strip, duration: max(0.5, duration), start: $trimStart, end: $trimEnd)
            if let keptPreview {
                VideoPlayer(player: keptPreview).frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            }
            Button { playKept() } label: {
                Label(L(keptPreview == nil ? "Play the part you keep" : "Play it again"), systemImage: "play.fill").frame(maxWidth: .infinity)
            }.secondaryButton()
            Text(L("Drag the yellow ends to choose what stays. Original quality — no re-encode when the clip allows it.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func trimFrame(_ img: UIImage?, label: String) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(HandyColor.surface)
                if let img { Image(uiImage: img).resizable().scaledToFit() }
            }
            .frame(height: 90).frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(label).font(HandyFont.caption).monospacedDigit().foregroundStyle(HandyColor.textSecondary)
        }
    }

    private var gifControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack { Text("From \(Self.clock(gifFrom))").font(HandyFont.caption).monospacedDigit().frame(width: 90, alignment: .leading); Slider(value: $gifFrom, in: 0...max(0.5, duration - 0.5)).tint(HandyColor.accent) }
            HStack { Text("Length \(String(format: "%.1fs", gifLength))").font(HandyFont.caption).monospacedDigit().frame(width: 90, alignment: .leading); Slider(value: $gifLength, in: 0.5...max(0.6, min(10, duration))).tint(HandyColor.accent) }
            HStack { Text("Speed \(String(format: "%.1f×", gifSpeed))").font(HandyFont.caption).monospacedDigit().frame(width: 90, alignment: .leading); Slider(value: $gifSpeed, in: 0.5...3, step: 0.5).tint(HandyColor.accent) }
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(0..<gifWidths.count, id: \.self) { i in HChip(text: gifWidths[i].0, selected: gifWidthIdx == i) { gifWidthIdx = i } }
            }
            HStack(spacing: HandySpacing.s8) {
                ForEach([8.0, 10.0, 15.0], id: \.self) { f in HChip(text: "\(Int(f)) fps", selected: gifFPS == f) { gifFPS = f } }
            }
            Text(L("Up to 72 frames. Smaller + fewer fps = a GIF that actually sends in chat.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private var photoGIFControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text("\(gifPhotos.count) photos → one looping GIF").font(HandyFont.bodyStrong)
            HStack { Text("Each frame \(String(format: "%.1fs", gifPhotoDelay))").font(HandyFont.caption).monospacedDigit().frame(width: 110, alignment: .leading); Slider(value: $gifPhotoDelay, in: 0.1...2, step: 0.1).tint(HandyColor.accent) }
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(0..<gifWidths.count, id: \.self) { i in HChip(text: gifWidths[i].0, selected: gifWidthIdx == i) { gifWidthIdx = i } }
            }
            if !store.isPremium { QuotaChip(name: "video", limit: Limits.freeVideoPerDay).environmentObject(store) }
            if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freeVideoPerDay) free video jobs.") }
            Button { runPhotoGIF() } label: {
                HStack { if working { ProgressView().tint(.white) }; Text(working ? "Making GIF…" : "Make GIF from \(gifPhotos.count) photos") }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(working || overQuota)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var socialControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Where will you post it?")).font(HandyFont.bodyStrong)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(VideoFormat.presets) { f in
                    HChip(text: "\(f.name) · \(f.ratio)", selected: socialFormat == f) { socialFormat = f }
                }
            }
            Picker("", selection: $socialFit) {
                Text(L("Fill the frame")).tag(false)
                Text(L("Show whole video")).tag(true)
            }.pickerStyle(.segmented)
            note(socialFit
                 ? "Keeps the whole picture, over a soft blurred copy of itself instead of black bars. \(Int(socialFormat.size.width))×\(Int(socialFormat.size.height)), sound kept."
                 : "Crops to the centre so it fills the screen with no bars. \(Int(socialFormat.size.width))×\(Int(socialFormat.size.height)), sound kept.")
        }
    }

    private var actionLabel: String {
        switch mode {
        case .shrink: return "Shrink under \(SizeTarget.format(targetBytes))"
        case .trim: return "Trim to \(Self.clock(max(0, trimEnd - trimStart)))"
        case .convert: return "Convert to MP4"
        case .mute: return "Remove the sound"
        case .audio: return "Save audio only"
        case .gif: return "Make GIF"
        case .social: return "Make \(socialFormat.ratio) video"
        }
    }

    private var canRun: Bool {
        switch mode {
        case .shrink: return targetBytes > 0 && targetBytes < sourceBytes
        case .trim: return trimEnd - trimStart >= 0.5 && (trimStart > 0.05 || trimEnd < duration - 0.05)
        default: return true
        }
    }

    /// What this run promised, so the shared finish card checks it on the file.
    private var toolPromise: VideoPromise {
        var p = VideoPromise()
        switch mode {
        case .shrink: p.underBytes = targetBytes
        case .trim: p.maxSeconds = max(0.5, trimEnd - trimStart)
        case .mute: p.silent = true
        default: break
        }
        return p
    }

    @ViewBuilder private func resultCard(_ r: Output) -> some View {
        if r.kind == .video {
            // The same finish as every ready-made video tool: what changed, each promise checked on the file.
            VideoFinishCard(url: r.url, source: source, promise: toolPromise, note: resultNote)
            Button { adopt(r) } label: { Label(L("Use this as the source (e.g. trim, then shrink)"), systemImage: "arrow.uturn.down").frame(maxWidth: .infinity) }.secondaryButton()
        } else if r.kind == .gif, let d = try? Data(contentsOf: r.url) {
            GIFFinishCard(data: d, shareURL: r.url)
        } else {
            oldResultCard(r)
        }
    }

    private func oldResultCard(_ r: Output) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s12) {
                Image(systemName: resultNote == nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill").foregroundStyle(resultNote == nil ? HandyColor.success : HandyColor.accent).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(resultTitle(r)).font(HandyFont.bodyStrong)
                    if sourceBytes > 0, r.kind == .video, r.bytes < sourceBytes {
                        Text("Down from \(SizeTarget.format(sourceBytes)) · \(Int((1 - Double(r.bytes) / Double(sourceBytes)) * 100))% smaller").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                    if let resultNote { Text(resultNote).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
                }
                Spacer()
            }
            if r.kind == .video, let player {
                VideoPlayer(player: player).frame(height: 200).clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            } else if r.kind == .gif, let img = UIImage(contentsOfFile: r.url.path) {
                Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 200).frame(maxWidth: .infinity)
            }
            ShareLink(item: r.url) { Label(L("Save or share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            if r.kind == .video {
                Button { adopt(r) } label: { Label(L("Use this as the source (e.g. trim, then shrink)"), systemImage: "arrow.uturn.down").frame(maxWidth: .infinity) }.secondaryButton()
            }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    private func resultTitle(_ r: Output) -> String {
        switch r.kind {
        case .video: return "Ready — \(SizeTarget.format(r.bytes)) MP4"
        case .audio: return "Audio saved — \(SizeTarget.format(r.bytes)) M4A"
        case .gif: return "GIF ready — \(SizeTarget.format(r.bytes))"
        }
    }

    // MARK: loading

    private func loadVideo(_ item: PhotosPickerItem?) {
        guard let item else { return }
        bus.clear(jobKey); result = nil; errorText = nil; resultNote = nil; player?.pause(); player = nil
        Task {
            guard let movie = try? await item.loadTransferable(type: MovieImport.self) else { await MainActor.run { errorText = "Couldn't load that video." }; return }
            let d = await VideoEngine.duration(movie.url)
            let t = await VideoEngine.thumbnail(movie.url, at: min(0.5, d / 2))
            await MainActor.run {
                source = movie.url; sourceBytes = SizeTarget.fileSize(movie.url) ?? 0; duration = d; thumb = t
                trimStart = 0; trimEnd = d; gifFrom = 0; gifLength = min(3, max(0.5, d))
                if targetBytes >= sourceBytes { targetBytes = videoPresets.first(where: { $0.bytes < sourceBytes })?.bytes ?? max(1_000_000, sourceBytes / 2) }
                refreshTrimThumbs(); refreshStrip(); keptPreview?.pause(); keptPreview = nil
            }
        }
    }

    /// Load a video from a file (hand-off), the same way a picked one loads.
    private func open(_ url: URL) {
        bus.clear(jobKey); result = nil; errorText = nil; resultNote = nil; player?.pause(); player = nil
        Task {
            let d = await VideoEngine.duration(url)
            let t = await VideoEngine.thumbnail(url, at: min(0.5, d / 2))
            await MainActor.run {
                source = url; sourceBytes = SizeTarget.fileSize(url) ?? 0; duration = d; thumb = t
                trimStart = 0; trimEnd = d; gifFrom = 0; gifLength = min(3, max(0.5, d))
                if targetBytes >= sourceBytes { targetBytes = videoPresets.first(where: { $0.bytes < sourceBytes })?.bytes ?? max(1_000_000, sourceBytes / 2) }
                refreshTrimThumbs(); refreshStrip(); keptPreview?.pause(); keptPreview = nil
            }
        }
    }

    private func adopt(_ r: Output) {
        guard r.kind == .video else { return }
        bus.clear(jobKey); player?.pause(); player = nil; result = nil
        Task {
            let d = await VideoEngine.duration(r.url)
            let t = await VideoEngine.thumbnail(r.url, at: min(0.5, d / 2))
            await MainActor.run {
                source = r.url; sourceBytes = r.bytes; duration = d; thumb = t
                trimStart = 0; trimEnd = d; gifFrom = 0; gifLength = min(3, max(0.5, d))
                if targetBytes >= sourceBytes { targetBytes = max(1_000_000, sourceBytes / 2) }
                refreshTrimThumbs(); refreshStrip(); keptPreview?.pause(); keptPreview = nil; HandyHaptics.light()
            }
        }
    }

    private func loadGIFPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var out: [Data] = []
            for it in items { if let d = try? await it.loadTransferable(type: Data.self) { out.append(d) } }
            await MainActor.run { gifPhotos = out; result = nil }
        }
    }

    /// Plays only the kept range, so you hear and see exactly where the cut lands before you export.
    private func playKept() {
        guard let source else { return }
        keptPreview?.pause()
        let item = AVPlayerItem(url: source)
        item.forwardPlaybackEndTime = CMTime(seconds: trimEnd, preferredTimescale: 600)
        let p = AVPlayer(playerItem: item)
        p.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { _ in p.play() }
        keptPreview = p
    }

    private func refreshStrip() {
        guard let source else { strip = []; return }
        Task { let f = await VideoEngine.filmstrip(source); await MainActor.run { strip = f } }
    }

    @State private var thumbTask: Task<Void, Never>?
    private func refreshTrimThumbs() {
        guard let source else { return }
        thumbTask?.cancel()
        let s = trimStart, e = trimEnd
        thumbTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            let a = await VideoEngine.thumbnail(source, at: s, maxDim: 320)
            let b = await VideoEngine.thumbnail(source, at: max(0, e - 0.05), maxDim: 320)
            guard !Task.isCancelled else { return }
            await MainActor.run { startThumb = a; endThumb = b }
        }
    }

    private func applyCustom() {
        let cleaned = customValue.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(cleaned), v > 0 else { return }
        targetBytes = Int(v * (customUnitMB ? 1_000_000 : 1_000))
        errorText = nil
    }

    // MARK: run

    private func run() {
        guard let src = source else { return }
        guard Usage.hasRoom("video", limit: Limits.freeVideoPerDay) else { return }   // gate only — charge on success
        result = nil; player?.pause(); player = nil; resultNote = nil; errorText = nil
        let m = mode, target = targetBytes, s = trimStart, e = trimEnd
        let gFrom = gifFrom, gLen = gifLength, gFPS = gifFPS, gSpeed = gifSpeed, gW = gifWidths[gifWidthIdx].1
        let fmt = socialFormat, fit = socialFit
        let failMsg = failureText(m)
        let tooBigNote = "This is the smallest I can make it without wrecking it. To get under \(SizeTarget.format(target)), trim it shorter first, then shrink."
        // Runs in JobBus so the job and its result survive leaving the tool; the charge + the on-screen
        // result are built once in syncJob() when it finishes (a failed attempt never costs a free job).
        bus.run(jobKey, label: "Processing video…") { report in
            if m == .shrink {
                let r = await VideoEngine.backgrounded("tenzy.video") { await SizeTarget.videoBestEffort(url: src, targetBytes: target, progress: report) }
                guard let r else { return ([], "", nil, failMsg) }
                return ([r.url], "video", r.fits ? nil : tooBigNote, nil)
            }
            let out: URL? = await VideoEngine.backgrounded("tenzy.video") { () async -> URL? in
                switch m {
                case .shrink: return nil
                case .trim: return await VideoEngine.trim(src, start: s, end: e)
                case .convert: return await VideoEngine.toMP4(src, progress: report)
                case .mute: return await VideoEngine.mute(src)
                case .audio: return await VideoEngine.extractAudio(src)
                case .gif: return await tenzyGIFFromVideo(url: src, start: gFrom, duration: gLen, fps: gFPS, speed: gSpeed, maxDim: gW)
                case .social: return await VideoReframe.reframe(src, to: fmt, fit: fit, progress: report)
                }
            }
            guard let out else { return ([], "", nil, failMsg) }
            return ([out], m == .audio ? "audio" : (m == .gif ? "gif" : "video"), nil, nil)
        }
    }

    /// Turn a finished JobBus result into the view's display and charge quota, exactly once per job —
    /// so returning to the tool after leaving shows the completed video instead of losing it.
    private func syncJob() {
        let j = bus.state(jobKey)
        guard !j.working, j.stamp > 0, j.stamp != j.consumedStamp else { return }
        bus.markConsumed(jobKey)
        if let err = j.error { errorText = err; return }
        if j.kind == "sendon" {
            sendParts = j.outputs; sendSaved = nil
            if !j.outputs.isEmpty { _ = Usage.use("video", limit: Limits.freeVideoPerDay); HandyHaptics.success() }
            return
        }
        guard let url = j.outputs.first else { return }
        _ = Usage.use("video", limit: Limits.freeVideoPerDay)
        let kind: Output.Kind = j.kind == "audio" ? .audio : (j.kind == "gif" ? .gif : .video)
        result = Output(url: url, bytes: SizeTarget.fileSize(url) ?? 0, kind: kind)
        resultNote = j.note
        if kind == .video { player = AVPlayer(url: url) }
        HandyHaptics.success()
    }

    private func runPhotoGIF() {
        guard !gifPhotos.isEmpty, Usage.hasRoom("video", limit: Limits.freeVideoPerDay) else { return }
        result = nil; player?.pause(); player = nil; resultNote = nil; errorText = nil
        let datas = gifPhotos, delay = gifPhotoDelay, w = gifWidths[gifWidthIdx].1
        bus.run(jobKey, label: "Making GIF…") { _ in
            let url = await Task.detached(priority: .userInitiated) { tenzyGIFFromImageData(datas, delay: delay, maxDim: w) }.value
            guard let url else { return ([], "", nil, "Couldn't build a GIF from those photos.") }
            return ([url], "gif", nil, nil)
        }
    }

    private func failureText(_ m: Mode) -> String {
        switch m {
        case .shrink: return "Couldn't get it under \(SizeTarget.format(targetBytes)) without wrecking it. Trim it shorter or pick a larger limit."
        case .trim: return "Couldn't trim this clip. Try a slightly different range."
        case .convert: return "Couldn't convert this video. It may be DRM-protected or damaged."
        case .mute: return "Couldn't remove the audio from this clip."
        case .audio: return "This clip has no audio track to save."
        case .gif: return "Couldn't read frames from this video. Try a different range."
        case .social: return "Couldn't reshape this clip. It may be DRM-protected or damaged."
        }
    }

    static func clock(_ s: Double) -> String {
        let t = Int(s.rounded()); return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }
}
