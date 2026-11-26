import SwiftUI
import PhotosUI
import AVKit

/// Beat Reel (26 Nov): pick a few clips and photos (or film them now), pick the music's style, and Tenzy cuts a tall
/// reel to the beat — every cut on a beat, a slow-motion moment where the music drops, a punch on every beat, the
/// style's look on top. Watch it, then keep it, share it or post it.
struct BeatReelView: View {
    private struct Piece: Identifiable { let id = UUID(); let url: URL; let thumb: UIImage? }

    @State private var pieces: [Piece] = []
    @State private var picks: [PhotosPickerItem] = []
    @State private var loading: Double?
    @State private var style = "upbeat"
    @State private var length: Double? = nil
    @State private var working = false
    @State private var progress = 0.0
    @State private var result: URL?
    @State private var player = AVPlayer()
    @State private var errorText: String?
    @State private var runTask: Task<Void, Never>?

    private let grid = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
    private let two = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    private let lengths: [(String, Double?)] = [("Auto", nil), ("15 s", 15), ("30 s", 30), ("60 s", 60)]

    var body: some View {
        ToolPage(title: "Beat Reel", subtitle: "Your clips, cut to the beat of a song made for them.", working: working) {
            if let result {
                VideoPlayer(player: player).aspectRatio(9.0 / 16.0, contentMode: .fit).frame(maxHeight: 480).frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).accessibilityIdentifier("reel-result")
                    .onAppear { player.replaceCurrentItem(with: AVPlayerItem(url: result)); player.play() }
                KeepShare([.file(result)], lead: .share, tool: "Beat Reel")
                Button { ToolHandoff.shared.put(.video(result), for: "post"); NotificationCenter.default.post(name: .openTool, object: "post") } label: {
                    Label(L("Post it"), systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                }.secondaryButton().accessibilityIdentifier("reel-post")
                Button { self.result = nil; player.pause() } label: { Label(L("Change the music or length"), systemImage: "slider.horizontal.3").frame(maxWidth: .infinity) }
                    .textButton()
            } else {
                Text(L("Your clips and photos")).font(HandyFont.cardTitle)
                if !pieces.isEmpty {
                    LazyVGrid(columns: grid, spacing: 6) {
                        ForEach(pieces) { p in
                            ZStack(alignment: .topTrailing) {
                                Color.clear.aspectRatio(9.0 / 16.0, contentMode: .fit)
                                    .overlay { if let t = p.thumb { Image(uiImage: t).resizable().scaledToFill() } else { HandyColor.surface } }
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                Button { pieces.removeAll { $0.id == p.id } } label: {
                                    Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(.white, .black.opacity(0.55))
                                }.buttonStyle(.plain).padding(4).accessibilityLabel(L("Remove"))
                            }
                        }
                    }
                    .accessibilityIdentifier("reel-pieces").accessibilityValue("\(pieces.count)")
                }
                HStack(spacing: HandySpacing.s8) {
                    PhotosPicker(selection: $picks, maxSelectionCount: 12, matching: .any(of: [.videos, .images])) {
                        Label(L(pieces.isEmpty ? "Choose" : "Add more"), systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
                    }.primaryButton().accessibilityIdentifier("reel-pick")
                    CameraButton(video: true, took: { t in if case .video(let u) = t { Task { await add([u]) } } }) {
                        Label(L("Record"), systemImage: "video").frame(maxWidth: .infinity)
                    }.secondaryButton().accessibilityIdentifier("tool-record")
                }
                if let f = loading { ToolProgressBar(value: f, label: "Getting them ready…") }
                if !pieces.isEmpty {
                    Text(L("The music")).font(HandyFont.cardTitle)
                    LazyVGrid(columns: two, spacing: 8) {
                        ForEach(Synth.styles) { s in
                            Button { style = s.id } label: {
                                HStack(spacing: 8) {
                                    Text(s.emoji).font(.system(size: 24))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(L(s.name)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).lineLimit(1)
                                        Text("\(Int(s.bpm)) BPM").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(10).frame(maxWidth: .infinity)
                                .background(style == s.id ? HandyColor.accent.opacity(0.16) : HandyColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(style == s.id ? HandyColor.accent : HandyColor.border, lineWidth: style == s.id ? 2 : 1))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).accessibilityIdentifier("reel-style-\(s.id)").accessibilityAddTraits(style == s.id ? .isSelected : [])
                        }
                    }
                    HStack(spacing: 6) {
                        Text(L("Length")).font(HandyFont.bodyStrong)
                        Spacer()
                        ForEach(lengths, id: \.0) { l in
                            HChip(text: L(l.0), selected: length == l.1) { length = l.1 }.accessibilityIdentifier("reel-length-\(l.0)")
                        }
                    }
                    Button { make() } label: { Label(L("Make my reel"), systemImage: "music.note").frame(maxWidth: .infinity) }
                        .primaryButton().disabled(working || pieces.isEmpty).accessibilityIdentifier("reel-make")
                    if working {
                        ToolProgressBar(value: progress > 0 ? progress : nil, label: "Cutting to the beat…")
                        Button(L("Stop")) { runTask?.cancel() }.textButton().frame(maxWidth: .infinity)
                    }
                }
            }
            if let errorText { Text(L(errorText)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            picks = []; loading = 0; errorText = nil
            Task {
                var urls: [URL] = []
                for (i, item) in items.enumerated() {
                    if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                        if let m = await MovieImport.load(item, progress: { _ in }) { urls.append(m.url) }
                    } else if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d), let v = await BeatReel.clip(from: img) {
                        urls.append(v)
                    }
                    await MainActor.run { loading = Double(i + 1) / Double(items.count) }
                }
                await add(urls)
                await MainActor.run { loading = nil; if urls.isEmpty { errorText = "Those didn't load — try others." } }
            }
        }
        .handoff("beatreel") { p in if case .video(let u) = p { Task { await add([u]) } } }
        .task {
            if Launch.uitest, Launch.sample, pieces.isEmpty {
                let a = await SampleAssets.movie(seconds: 4), b = await SampleAssets.movie(seconds: 3, size: CGSize(width: 360, height: 640))
                await add([a, b].compactMap { $0 })
            }
        }
        .onDisappear { player.pause() }
    }

    private func add(_ urls: [URL]) async {
        var new: [Piece] = []
        for u in urls { new.append(Piece(url: u, thumb: await VideoEngine.thumbnail(u, at: 0.5))) }
        await MainActor.run { pieces.append(contentsOf: new) }
    }

    private func make() {
        working = true; progress = 0; errorText = nil
        let urls = pieces.map(\.url), st = style, len = length
        runTask = Task {
            let out = await BeatReel.make(urls, style: st, seconds: len) { p in Task { @MainActor in progress = p } }
            await MainActor.run {
                working = false
                if Task.isCancelled { errorText = "Stopped."; return }
                guard let out else { errorText = "Couldn't make the reel — try other clips."; return }
                result = out; HandyHaptics.success()
            }
        }
    }
}
