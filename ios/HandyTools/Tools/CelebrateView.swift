import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

/// Celebrate — a video (or photo) dressed up for any celebration in the world, with your words on it.
/// Pick the moment (festivals coming up are first) or type any celebration in any language; the live preview plays
/// your video with the decorations already on it. Drag the words where you want them, pinch to size them. The saved
/// video keeps its sound and finishes even if you leave the app.
struct CelebrateView: View {
    @State private var source: URL?
    @State private var aspect: CGFloat = 9.0 / 16.0
    @State private var pick: PhotosPickerItem?
    @State private var loading: Double?
    @State private var theme: Celebrate.Theme = Celebrate.comingUp().first ?? Celebrate.themes[0]
    @State private var amount: Double = 1
    @State private var caption = Celebrate.Caption(text: "")
    @State private var showWords = true
    @State private var typed = ""
    @State private var player = AVPlayer()
    @State private var previewTask: Task<Void, Never>?
    @State private var working = false
    @State private var runTask: Task<Void, Never>?
    @State private var resultURL: URL?
    @State private var errorText: String?
    @State private var dragStart: CGPoint?
    @State private var pinchStart: CGFloat?
    @ObservedObject private var prog = RunProgress.shared

    private let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ToolPage(title: "Celebrate",
                 subtitle: "Decorate a video or photo for any celebration — snow, fireworks, diyas, lanterns — and add your words.",
                 working: working) {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                if let url = resultURL { result(url) }
                else if source == nil { pickCard }
                else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .onChange(of: pick) { _, item in if let item { load(item) } }
        .onChange(of: theme) { _, _ in schedulePreview() }
        .onChange(of: amount) { _, _ in schedulePreview() }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { n in
            if (n.object as? AVPlayerItem) == player.currentItem { player.seek(to: .zero); player.play() }
        }
        .onDisappear { player.pause(); previewTask?.cancel() }
        .handoff("celebrate") { p in adopt(p) }
        .onAppear { if Launch.sample, source == nil { sample() } }
        .finishes(working, tool: "Celebrate")
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Text(Celebrate.comingUp().prefix(5).map(\.emoji).joined(separator: " ")).font(.system(size: 40))
            Text(L("Pick a video or a photo. Add snow for Christmas, fireworks for New Year, diyas for Diwali, lanterns for Lunar New Year — or any celebration you type — and your own words."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            PhotosPicker(selection: $pick, matching: .any(of: [.videos, .images])) {
                Label(L("Choose a video or photo"), systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
            }.primaryButton().accessibilityIdentifier("celebrate-pick")
            if let f = loading { ToolProgressBar(value: f, label: "Getting it ready…") }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s16) {
            previewBox
            // Any celebration, any language.
            HStack {
                Image(systemName: "sparkle.magnifyingglass").foregroundStyle(HandyColor.textSecondary)
                TextField("", text: $typed, prompt: Text(L("Type any celebration — Navidad, Eid, दिवाली, 春节…")).foregroundStyle(HandyColor.textSecondary))
                    .submitLabel(.done).onSubmit { useTyped() }
                    .foregroundStyle(HandyColor.textPrimary)
                    .accessibilityIdentifier("celebrate-type")
                if !typed.isEmpty { Button(L("Use")) { useTyped() }.font(HandyFont.bodyStrong) }
            }
            .padding(HandySpacing.s12)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            if theme.custom {
                Label(L("Made from your words — tap a celebration below to switch."), systemImage: "wand.and.stars")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }

            let soon = Celebrate.comingUp()
            if !soon.isEmpty {
                Text(L("Coming up")).font(HandyFont.bodyStrong)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { ForEach(soon) { chip($0, big: true) } }
                }
            }
            Text(L("Every celebration")).font(HandyFont.bodyStrong)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(Celebrate.ordered().filter { t in !soon.contains { $0.id == t.id } }) { chip($0, big: false) }
            }

            Text(L("How much")).font(HandyFont.bodyStrong)
            Picker("", selection: $amount) {
                Text(L("A touch")).tag(0.6); Text(L("Just right")).tag(1.0); Text(L("Lots")).tag(1.6)
            }.pickerStyle(.segmented)

            wordsCard

            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            Button { make() } label: {
                Label(L("Make the video"), systemImage: "sparkles").frame(maxWidth: .infinity)
            }.primaryButton().disabled(working).accessibilityIdentifier("celebrate-make")
            if working {
                ToolProgressBar(value: prog.fraction ?? 0, label: "Decorating every frame…")
                Button(L("Stop")) { runTask?.cancel() }.textButton().frame(maxWidth: .infinity)
            }
            Button(L("Choose another video or photo")) { reset() }.textButton().font(HandyFont.caption).frame(maxWidth: .infinity)
        }
    }

    private func chip(_ t: Celebrate.Theme, big: Bool) -> some View {
        let on = theme.id == t.id && !theme.custom
        return Button { choose(t) } label: {
            VStack(spacing: 2) {
                Text(t.emoji).font(.system(size: big ? 28 : 22))
                Text(L(t.name)).font(HandyFont.micro).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: big ? nil : .infinity, minHeight: 62)
            .frame(width: big ? 96 : nil)
            .padding(.vertical, 6)
            .foregroundStyle(on ? HandyColor.accent : HandyColor.textPrimary)
            .background(on ? HandyColor.accent.opacity(0.15) : HandyColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(on ? HandyColor.accent : HandyColor.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("celebrate-\(t.id)")
    }

    private var wordsCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Toggle(isOn: $showWords) { Label(L("Your words on the video"), systemImage: "textformat").font(HandyFont.bodyStrong) }
                .tint(HandyColor.accent)
            if showWords {
                TextField("", text: $caption.text, prompt: Text(L("Happy Diwali from all of us")).foregroundStyle(HandyColor.textSecondary), axis: .vertical)
                    .lineLimit(1...3)
                    .foregroundStyle(HandyColor.textPrimary)
                    .padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .accessibilityIdentifier("celebrate-words")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Celebrate.Font.allCases) { f in
                            Button { caption.font = f } label: {
                                Text(L(f.title)).font(Font(f.ui(15) as CTFont))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(caption.font == f ? HandyColor.accent : HandyColor.surface, in: Capsule())
                                    .foregroundStyle(caption.font == f ? Color.white : HandyColor.textPrimary)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                HStack(spacing: 10) {
                    ForEach(Celebrate.captionColors, id: \.self) { c in
                        Button { caption.color = c } label: {
                            Circle().fill(Color(hex: c)).frame(width: 24, height: 24)
                                .overlay(Circle().stroke(caption.color == c ? HandyColor.accent : HandyColor.border, lineWidth: caption.color == c ? 3 : 1).padding(-3))
                        }.buttonStyle(.plain).accessibilityLabel(L("Colour"))
                    }
                }
                HStack {
                    Image(systemName: "textformat.size.smaller").foregroundStyle(HandyColor.textSecondary)
                    Slider(value: $caption.scale, in: 0.04...0.16).tint(HandyColor.accent)
                    Image(systemName: "textformat.size.larger").foregroundStyle(HandyColor.textSecondary)
                }
                Text(L("Drag the words on the video to move them; pinch to make them bigger or smaller. They start where they won't cover faces."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    /// The video playing with the decorations on it; the words sit on top and follow your finger.
    private var previewBox: some View {
        GeometryReader { g in
            ZStack {
                Color.black
                VideoPlayer(player: player).disabled(true)
                if showWords, let img = Celebrate.captionImage(caption, frame: g.size) {
                    Image(uiImage: img)
                        .position(x: caption.center.x * g.size.width, y: caption.center.y * g.size.height)
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    if dragStart == nil { dragStart = caption.center }
                                    let s = dragStart ?? caption.center
                                    caption.center = CGPoint(x: min(0.95, max(0.05, s.x + v.translation.width / g.size.width)),
                                                             y: min(0.95, max(0.05, s.y + v.translation.height / g.size.height)))
                                }
                                .onEnded { _ in dragStart = nil }
                                .simultaneously(with: MagnificationGesture()
                                    .onChanged { m in
                                        if pinchStart == nil { pinchStart = caption.scale }
                                        caption.scale = min(0.2, max(0.03, (pinchStart ?? caption.scale) * m))
                                    }
                                    .onEnded { _ in pinchStart = nil })
                        )
                        .accessibilityIdentifier("celebrate-caption")
                }
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: 440)
        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        .accessibilityIdentifier("celebrate-preview")
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label("\(theme.emoji) \(L(theme.custom ? "Your celebration" : theme.name))", systemImage: "checkmark.circle.fill")
                .font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success)
            VideoFinishCard(url: url, source: source).id(url)
            Button(L("Try another celebration")) { resultURL = nil; schedulePreview() }.textButton().frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("celebrate-result")
    }

    // MARK: - Actions

    private func choose(_ t: Celebrate.Theme) {
        let oldGreeting = theme.greeting
        theme = t
        // Swap the words too, unless the person wrote their own.
        if caption.text.isEmpty || caption.text == oldGreeting || caption.text == L(oldGreeting) { caption.text = L(t.greeting) }
    }

    private func useTyped() {
        let t = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        choose(Celebrate.resolve(t))
    }

    private func load(_ item: PhotosPickerItem) {
        pick = nil; errorText = nil; loading = 0
        Task {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }),
               let m = await MovieImport.load(item, progress: { f in Task { @MainActor in loading = f } }) {
                await MainActor.run { loading = nil }
                await use(m.url)
                return
            }
            if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                await MainActor.run { loading = 0.5 }
                let v = await Celebrate.videoFromPhoto(img)
                await MainActor.run { loading = nil }
                if let v { await use(v) } else { await MainActor.run { errorText = "Couldn't turn that photo into a video — try another." } }
                return
            }
            await MainActor.run { loading = nil; errorText = "Couldn't open that — try another video or photo." }
        }
    }

    private func adopt(_ p: ChainPayload) {
        Task {
            if case .video(let u) = p { await use(u); return }
            if let img = ToolHandoff.image(p), let v = await Celebrate.videoFromPhoto(img) { await use(v) }
        }
    }

    private func sample() {
        Task {
            if let v = await Celebrate.videoFromPhoto(SampleAssets.photo()) { await use(v) }
        }
    }

    /// Take a video: learn its shape, put the words where no face is, start the preview.
    private func use(_ url: URL) async {
        let asset = AVURLAsset(url: url)
        var shape: CGFloat = 9.0 / 16.0
        if let tr = try? await asset.loadTracks(withMediaType: .video).first,
           let n = try? await tr.load(.naturalSize), let t = try? await tr.load(.preferredTransform) {
            let r = CGRect(origin: .zero, size: n).applying(t)
            if r.height != 0 { shape = abs(r.width) / abs(r.height) }
        }
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true; gen.maximumSize = CGSize(width: 640, height: 640)
        let secs = (try? await asset.load(.duration).seconds) ?? 1
        let frame = try? await gen.image(at: CMTime(seconds: min(1, secs / 3), preferredTimescale: 600)).image
        let spot = Celebrate.clearSpot(in: frame)
        await MainActor.run {
            source = url; aspect = shape; resultURL = nil
            caption.center = spot
            if caption.text.isEmpty { caption.text = L(theme.greeting) }
            schedulePreview()
        }
    }

    /// Rebuild the live preview (debounced) whenever the celebration or amount changes.
    private func schedulePreview() {
        previewTask?.cancel()
        guard let url = source, resultURL == nil else { return }
        let t = theme, a = amount
        previewTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            let asset = AVURLAsset(url: url)
            let comp = await Celebrate.composition(for: asset, theme: t, amount: a, caption: nil)
            await MainActor.run {
                guard !Task.isCancelled else { return }
                let item = AVPlayerItem(asset: asset)
                item.videoComposition = comp
                player.replaceCurrentItem(with: item)
                player.isMuted = true
                player.play()
            }
        }
    }

    private func make() {
        guard let url = source else { return }
        player.pause(); working = true; errorText = nil
        RunProgress.shared.begin()
        let t = theme, a = amount, c: Celebrate.Caption? = showWords && !caption.text.trimmingCharacters(in: .whitespaces).isEmpty ? caption : nil
        runTask = Task {
            let out = await Celebrate.export(url, theme: t, amount: a, caption: c)
            await MainActor.run {
                RunProgress.shared.end(); working = false
                if Task.isCancelled { errorText = "Stopped."; player.play(); return }
                guard let out else { errorText = "Couldn't make the video — try again."; player.play(); return }
                let name = FileManager.default.temporaryDirectory.appendingPathComponent("\(t.custom ? "Celebration" : t.name) video.mp4")
                try? FileManager.default.removeItem(at: name)
                resultURL = (try? FileManager.default.moveItem(at: out, to: name)) != nil ? name : out
                HandyHaptics.success()
            }
        }
    }

    private func reset() {
        previewTask?.cancel(); runTask?.cancel(); player.pause(); player.replaceCurrentItem(with: nil)
        source = nil; resultURL = nil; errorText = nil; caption.text = ""
    }
}
