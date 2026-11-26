import SwiftUI
import PhotosUI
import AVKit

/// Funny Moments (26 Nov): pick or record a video, pick the joke — record-scratch freeze, dramatic zoom, crickets, air
/// horns, boing, ba-dum-tss — and Tenzy finds the moment (the loudest laugh or shout), puts it in with its sound, and
/// shows the result to watch before you keep or share it. The moment can be moved; the freeze's words can be changed.
struct FunnyMomentView: View {
    @State private var source: URL?
    @State private var duration = 0.0
    @State private var pick: PhotosPickerItem?
    @State private var loading: Double?
    @State private var kind = "scratch"
    @State private var moment: Double?
    @State private var autoMoment: Double?
    @State private var words = ""
    @State private var working = false
    @State private var progress = 0.0
    @State private var result: URL?
    @State private var player = AVPlayer()
    @State private var errorText: String?
    @State private var runTask: Task<Void, Never>?

    private let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    private var k: FunnyMoment.Kind { FunnyMoment.kind(kind) }

    var body: some View {
        ToolPage(title: "Funny Moments", subtitle: "One moment, one classic joke — with its sound.", working: working) {
            if source == nil {
                VStack(spacing: HandySpacing.s12) {
                    Text(L("Pick a video with a moment worth a laugh. Tenzy finds it for you.")).font(HandyFont.body)
                        .foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                    PhotosPicker(selection: $pick, matching: .videos) { Label(L("Choose a video"), systemImage: "film").frame(maxWidth: .infinity) }
                        .primaryButton().accessibilityIdentifier("funny-pick")
                    CameraButton(video: true, took: { t in if case .video(let u) = t { Task { await use(u) } } }) {
                        Label(L("Record one now"), systemImage: "video").frame(maxWidth: .infinity)
                    }.secondaryButton().accessibilityIdentifier("tool-record")
                    if let f = loading { ToolProgressBar(value: f, label: "Getting it ready…") }
                }
                .cardStyle(padding: HandySpacing.s16)
            } else if let result {
                VideoPlayer(player: player).aspectRatio(9.0 / 16.0, contentMode: .fit).frame(maxHeight: 460).frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).accessibilityIdentifier("funny-result")
                    .onAppear { player.replaceCurrentItem(with: AVPlayerItem(url: result)); player.play() }
                KeepShare([.file(result)], lead: .share, tool: "Funny Moments")
                HStack(spacing: HandySpacing.s8) {
                    Button { self.result = nil; player.pause() } label: { Label(L("Try another joke"), systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity) }
                        .secondaryButton()
                    Button { reset() } label: { Label(L("Another video"), systemImage: "film").frame(maxWidth: .infinity) }.secondaryButton()
                }
            } else {
                Text(L("Which joke?")).font(HandyFont.cardTitle)
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(FunnyMoment.kinds) { c in
                        Button { kind = c.id; words = c.words; moment = c.id == "rimshot" ? nil : moment } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.emoji).font(.system(size: 28))
                                Text(L(c.name)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).lineLimit(1).minimumScaleFactor(0.85)
                                Text(L(c.line)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading).padding(10)
                            .background(kind == c.id ? HandyColor.accent.opacity(0.16) : HandyColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(kind == c.id ? HandyColor.accent : HandyColor.border, lineWidth: kind == c.id ? 2 : 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("funny-kind-\(c.id)")
                        .accessibilityAddTraits(kind == c.id ? .isSelected : [])
                    }
                }
                if kind != "rimshot", duration > 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(L("The moment")).font(HandyFont.bodyStrong)
                            Spacer()
                            Text(VideoFacts.clock(moment ?? autoMoment ?? duration * 0.6)).font(HandyFont.caption.monospacedDigit()).foregroundStyle(HandyColor.accent)
                        }
                        Slider(value: Binding(get: { moment ?? autoMoment ?? duration * 0.6 }, set: { moment = $0 }), in: 0...max(0.1, duration - 0.1))
                            .tint(HandyColor.accent).accessibilityIdentifier("funny-moment")
                        Text(L(moment == nil ? "Found for you: the loudest moment. Slide to move it." : "Your moment.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    }
                    .cardStyle(padding: HandySpacing.s12)
                }
                if k.freeze > 0, kind != "rimshot" {
                    TextField(L("Words on the freeze (optional)"), text: $words).textFieldStyle(.handy).accessibilityIdentifier("funny-words")
                }
                Button { make() } label: { Label(L("Make it"), systemImage: "theatermasks.fill").frame(maxWidth: .infinity) }
                    .primaryButton().disabled(working).accessibilityIdentifier("funny-make")
                if working {
                    ToolProgressBar(value: progress > 0 ? progress : nil, label: "Putting the joke in…")
                    Button(L("Stop")) { runTask?.cancel() }.textButton().frame(maxWidth: .infinity)
                }
                Button(L("Choose another video")) { reset() }.textButton().font(HandyFont.caption).frame(maxWidth: .infinity)
            }
            if let errorText { Text(L(errorText)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            pick = nil; loading = 0; errorText = nil
            Task {
                let m = await MovieImport.load(item) { f in Task { @MainActor in loading = f } }
                await MainActor.run { loading = nil }
                if let m { await use(m.url) } else { await MainActor.run { errorText = "That video didn't load — try another." } }
            }
        }
        .handoff("funny") { p in if case .video(let u) = p { Task { await use(u) } } }
        .task { if Launch.uitest, Launch.sample, source == nil, let u = await SampleAssets.movie(seconds: 4, withSound: true) { await use(u) } }
        .onDisappear { player.pause() }
    }

    /// A video to work on: how long it is, and the moment found in it.
    private func use(_ url: URL) async {
        let d = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
        let loud = await FunnyMoment.loudness(url)
        await MainActor.run {
            source = url; duration = d; result = nil; moment = nil; errorText = nil
            autoMoment = FunnyMoment.moment(loudness: loud, hop: 0.05, duration: d, kind: "scratch")
            if words.isEmpty { words = k.words }
        }
    }

    private func make() {
        guard let url = source else { return }
        working = true; progress = 0; errorText = nil
        let kindID = kind, at = kind == "rimshot" ? nil : (moment ?? autoMoment), w = words
        runTask = Task {
            let out = await FunnyMoment.make(url, kind: kindID, at: at, words: w) { p in Task { @MainActor in progress = p } }
            await MainActor.run {
                working = false
                if Task.isCancelled { errorText = "Stopped."; return }
                guard let out else { errorText = "Couldn't make it — try another moment or video."; return }
                result = out; HandyHaptics.success()
            }
        }
    }

    private func reset() {
        runTask?.cancel(); player.pause(); player.replaceCurrentItem(with: nil)
        source = nil; result = nil; moment = nil; autoMoment = nil; errorText = nil
    }
}
