import SwiftUI
import AVKit
import Photos
import ImageIO

/// What a finished video really is, read back from the file — size, length, shape, whether it has sound.
struct VideoFacts: Equatable {
    var bytes: Int
    var seconds: Double
    var size: CGSize          // as it plays (rotation applied)
    var hasSound: Bool

    static func read(_ url: URL) async -> VideoFacts? {
        let a = AVURLAsset(url: url)
        guard let d = try? await a.load(.duration) else { return nil }
        var size = CGSize.zero
        if let v = try? await a.loadTracks(withMediaType: .video).first,
           let n = try? await v.load(.naturalSize), let t = try? await v.load(.preferredTransform) {
            let r = CGRect(origin: .zero, size: n).applying(t); size = CGSize(width: abs(r.width), height: abs(r.height))
        }
        let sound = ((try? await a.loadTracks(withMediaType: .audio)) ?? []).isEmpty == false
        return VideoFacts(bytes: SizeTarget.fileSize(url) ?? 0, seconds: d.seconds.isFinite ? d.seconds : 0, size: size, hasSound: sound)
    }

    var isTall: Bool { size.height > size.width * 1.5 }

    static func clock(_ s: Double) -> String {
        let t = Int(s.rounded()); return String(format: "%d:%02d", t / 60, t % 60)
    }
}

/// What the tool promised, so the finished screen can check each promise on the file.
struct VideoPromise {
    var underBytes: Int?       // shrink: under this size (counted as the shrink step counts it)
    var maxSeconds: Double?    // trim: at most this long
    var tall = false           // made tall 9:16
    var silent = false         // sound removed
    var speed: String?         // "slow" / "fast"

    init(_ chain: Chain) {
        for s in chain.steps {
            switch s.block {
            case .videoShrink: underBytes = ChainText.videoLimit(s.settings["mb"]) * 1_000_000
            case .videoTrim: maxSeconds = Double(s.settings["secs"] ?? "")
            case .videoVertical: tall = true
            case .videoMute: silent = true
            case .videoSpeed: speed = s.settings["speed"]
            default: break
            }
        }
    }
    init() {}
}

/// The finish for every video job — the same card in the Video tool and in every ready-made video tool: watch it,
/// see what changed against your original (size, length, speed, shape, sound), each promise checked on the file,
/// then Save to Photos or Share.
struct VideoFinishCard: View {
    let url: URL
    var source: URL?
    var promise = VideoPromise()
    var note: String?

    @State private var facts: VideoFacts?
    @State private var before: VideoFacts?
    @State private var player: AVPlayer?
    @State private var saved: String?

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label(L("Your video is ready"), systemImage: "film").font(HandyFont.bodyStrong)
            if let player {
                VideoPlayer(player: player).frame(maxWidth: .infinity).frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
            }
            if let f = facts {
                VStack(alignment: .leading, spacing: HandySpacing.s8) { rows(f) }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
            if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.accent).fixedSize(horizontal: false, vertical: true) }
            ShareLink(item: url) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            Button {
                Task { let ok = await VideoSaver.save(url); saved = L(ok ? "Saved to Photos." : "Couldn't save — allow Tenzy to add photos in Settings.") }
            } label: { Label(L("Save to Photos"), systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }.secondaryButton()
            if let saved { Text(saved).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("video-finish")
        .task(id: url) {
            player?.pause(); player = AVPlayer(url: url)   // always the video this card is about
            facts = await VideoFacts.read(url)
            if let source { before = await VideoFacts.read(source) }
        }
        .onDisappear { player?.pause() }
    }

    @ViewBuilder private func rows(_ f: VideoFacts) -> some View {
        // Size, against the original and against the limit it was made for.
        if let b = before, b.bytes > f.bytes, b.bytes > 0 {
            row(true, "\(SizeTarget.format(f.bytes)) — \(L("down from")) \(SizeTarget.format(b.bytes)) · \(Int((1 - Double(f.bytes) / Double(b.bytes)) * 100))% \(L("smaller"))")
        } else {
            row(true, "\(SizeTarget.format(f.bytes)) · MP4")
        }
        if let limit = promise.underBytes {
            let ok = f.bytes <= limit
            row(ok, ok ? "\(L("Under")) \(SizeTarget.format(limit)) — \(L("fits where you're sending it"))" : "\(L("Still over")) \(SizeTarget.format(limit)) — \(L("trim it shorter to fit"))")
                .accessibilityIdentifier("video-size-check")
        }
        // Length and speed.
        if let s = promise.speed, let b = before, b.seconds > 0, f.seconds > 0 {
            let ratio = b.seconds / f.seconds
            let ok = s == "fast" ? ratio > 1.05 : ratio < 0.95
            row(ok, "\(L("Plays in")) \(VideoFacts.clock(f.seconds)) (\(L("was")) \(VideoFacts.clock(b.seconds))) — " +
                (ratio >= 1 ? String(format: "%.1f× %@", ratio, L("faster")) : String(format: "%.1f× %@", 1 / ratio, L("slower"))))
                .accessibilityIdentifier("video-speed-check")
        } else if let max = promise.maxSeconds {
            row(f.seconds <= max + 0.6, "\(VideoFacts.clock(f.seconds)) \(L("long"))" + (before.map { " (\(L("from")) \(VideoFacts.clock($0.seconds)))" } ?? ""))
        } else {
            row(true, "\(VideoFacts.clock(f.seconds)) \(L("long"))")
        }
        if promise.tall {
            row(f.isTall, f.isTall ? "\(L("Tall 9:16 for Stories and Reels")) · \(Int(f.size.width))×\(Int(f.size.height))" : "\(L("Not tall")) · \(Int(f.size.width))×\(Int(f.size.height))")
        } else if f.size != .zero {
            row(true, "\(Int(f.size.width))×\(Int(f.size.height))")
        }
        if promise.silent {
            row(!f.hasSound, f.hasSound ? L("Sound is still in it") : L("No sound in it — checked"))
                .accessibilityIdentifier("video-sound-check")
        }
    }

    private func row(_ ok: Bool, _ text: String) -> some View {
        Label { Text(text).font(HandyFont.caption).fixedSize(horizontal: false, vertical: true) } icon: {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(ok ? Color.green : Color.orange)
        }
        .accessibilityElement(children: .combine)   // one element per check, so a test (and VoiceOver) reads it once
    }
}

/// Facts about a finished GIF read from the file: how many frames, how long one loop takes, its size.
struct GIFFacts: Equatable {
    var frames: Int, seconds: Double, bytes: Int, size: CGSize
    static func read(_ d: Data) -> GIFFacts? {
        guard let src = CGImageSourceCreateWithData(d as CFData, nil) else { return nil }
        let n = CGImageSourceGetCount(src)
        guard n > 0 else { return nil }
        var total = 0.0
        for i in 0..<n {
            let p = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [String: Any]
            let g = p?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
            let delay = (g?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double) ?? (g?[kCGImagePropertyGIFDelayTime as String] as? Double) ?? 0.1
            total += delay > 0.011 ? delay : 0.1
        }
        let first = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any]
        let w = first?[kCGImagePropertyPixelWidth as String] as? Int ?? 0, h = first?[kCGImagePropertyPixelHeight as String] as? Int ?? 0
        return GIFFacts(frames: n, seconds: total, bytes: d.count, size: CGSize(width: w, height: h))
    }
}

/// The finish for a GIF: it plays, the facts from the file, Save to Photos (it stays animated) or Share.
struct GIFFinishCard: View {
    let data: Data
    let shareURL: URL?
    @State private var saved: String?

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label(L("Your GIF is ready"), systemImage: "photo.stack").font(HandyFont.bodyStrong)
            AnimatedGIFView(data: data).frame(maxWidth: .infinity).frame(maxHeight: 360)
            if let f = GIFFacts.read(data) {
                Text("\(f.frames) \(L("frames")) · \(String(format: "%.1f", f.seconds)) s \(L("a loop")) · \(Int(f.size.width))×\(Int(f.size.height)) · \(SizeTarget.format(f.bytes))")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    .accessibilityIdentifier("gif-facts")
            }
            if let shareURL { ShareLink(item: shareURL) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton() }
            Button {
                Task { let ok = await PhotoSaver.save(data); saved = L(ok ? "Saved to Photos — it plays in the Animated album." : "Couldn't save — allow Tenzy to add photos in Settings.") }
            } label: { Label(L("Save to Photos"), systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }.secondaryButton()
            if let saved { Text(saved).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            Text(L("In Messages and WhatsApp, share it from here so it stays animated.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gif-finish")
    }
}

enum VideoSaver {
    static func save(_ url: URL) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil) }
            return true
        } catch { return false }
    }
}

/// Shown while a video job runs: a frame from the video, its length and size, and what it's being made into.
struct RunningOnVideoCard: View {
    let url: URL
    let goal: String
    @State private var thumb: UIImage?
    @State private var facts: VideoFacts?

    var body: some View {
        HStack(spacing: HandySpacing.s12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(HandyColor.surface)
                if let thumb { Image(uiImage: thumb).resizable().scaledToFill() }
            }
            .frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Your video")).font(HandyFont.bodyStrong)
                if let f = facts {
                    Text("\(VideoFacts.clock(f.seconds)) · \(SizeTarget.format(f.bytes)) · \(Int(f.size.width))×\(Int(f.size.height))")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).monospacedDigit()
                }
                Text(L(goal)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("running-on-video")
        .task(id: url) {
            facts = await VideoFacts.read(url)
            thumb = await VideoEngine.thumbnail(url, at: 0.5)
        }
    }
}

/// The finish for a speed change: the video at the chosen speed, with the sound kept at natural pitch, and every
/// other speed one tap away on the same clip — so you can find the one that feels right without starting over.
struct SpeedFinishCard: View {
    let source: URL?
    @State var url: URL
    @State var rate: Double
    @State private var busy: Double?
    @State private var problem: String?
    @ObservedObject private var prog = RunProgress.shared
    static let rates: [Double] = [0.25, 0.5, 0.75, 1.5, 2, 4]

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            VideoFinishCard(url: url, source: source, promise: { var p = VideoPromise(); p.speed = rate > 1 ? "fast" : "slow"; return p }()).id(url)
            if source != nil {
                Text(L("Try another speed — sound stays natural")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.rates, id: \.self) { r in
                            Button { change(r) } label: {
                                HStack(spacing: 4) {
                                    if busy == r { ProgressView().controlSize(.mini) }
                                    Text(r < 1 ? "\(r.formatted())× \(L("slow"))" : "\(r.formatted())×").font(HandyFont.caption)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(rate == r ? HandyColor.accent : HandyColor.surface, in: Capsule())
                                .foregroundStyle(rate == r ? Color.white : HandyColor.textPrimary)
                            }.buttonStyle(.plain).disabled(busy != nil)
                        }
                    }
                }
                .accessibilityIdentifier("speed-choices")
                if rate < 1 {
                    // The slow-mo ramp phones do: normal, then the busiest moment slowed right down, then normal.
                    Button { slowMoment() } label: {
                        Label(moment.map { "\(L("Slow just the best moment")) (\(VideoFacts.clock($0.lowerBound))–\(VideoFacts.clock($0.upperBound)))" } ?? L("Slow just the best moment"),
                              systemImage: "sparkles").frame(maxWidth: .infinity)
                    }.secondaryButton().disabled(busy != nil).accessibilityIdentifier("speed-moment")
                }
                if busy != nil { ToolProgressBar(value: prog.fraction, label: "Changing the speed…") }
            }
            if let problem { Text(L(problem)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
    }

    @State private var moment: ClosedRange<Double>?

    private func slowMoment() {
        guard let s = source else { return }
        busy = -1; problem = nil
        Task {
            let m = await VideoJoin.busiestMoment(s)
            guard let m else { await MainActor.run { busy = nil; problem = "Nothing stands out as moving in this clip — the whole clip is slowed instead." }; return }
            await MainActor.run { moment = m }
            let out = await VideoJoin.ramp(s, moment: m, rate: rate < 1 ? rate : 0.25)
            await MainActor.run { busy = nil; if let out { url = out } else { problem = "That couldn't be made from this video." } }
        }
    }

    private func change(_ r: Double) {
        guard r != rate, let s = source else { return }
        busy = r; problem = nil
        Task {
            let out = await ChainMedia.respeed(s, rate: r)
            await MainActor.run {
                busy = nil
                if let out { url = out; rate = r } else { problem = "That speed couldn't be made from this video." }
            }
        }
    }
}
