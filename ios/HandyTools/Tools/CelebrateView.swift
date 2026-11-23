import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

/// Video effects — "Make it stunning". A video (or photo) with a whole vibe in one tap (Cinematic, Golden hour,
/// Party, Dreamy, Love, Retro VHS, Noir, Epic, Night sky), or built up piece by piece: a look, light, motion on the
/// beat, texture, sparkle, animated words, or any festival from every part of the world. One "How much" slider takes
/// all of it from barely there to wild. Every choice shows on a picture of the person's own video; the live preview
/// plays with it on; the saved video keeps its sound and finishes even if you leave the app.
struct CelebrateView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case vibes, look, light, motion, texture, sparkle, words, celebrate
        var id: String { rawValue }
        var title: String {
            switch self {
            case .vibes: return "Vibes"
            case .look: return "Look"
            case .light: return "Light"
            case .motion: return "Motion"
            case .texture: return "Texture"
            case .sparkle: return "Sparkle"
            case .words: return "Words"
            case .celebrate: return "Celebrate"
            }
        }
        var icon: String {
            switch self {
            case .vibes: return "sparkles"
            case .look: return "camera.filters"
            case .light: return "sun.max.fill"
            case .motion: return "move.3d"
            case .texture: return "film"
            case .sparkle: return "wand.and.stars"
            case .words: return "textformat"
            case .celebrate: return "party.popper.fill"
            }
        }
    }

    @State private var source: URL?
    @State private var aspect: CGFloat = 9.0 / 16.0
    @State private var pick: PhotosPickerItem?
    @State private var loading: Double?
    @State private var tab: Tab = .vibes
    @State private var recipe: VideoFX.Recipe = VideoFX.vibes[0].recipe
    @State private var theme: Celebrate.Theme = Celebrate.comingUp().first ?? Celebrate.themes[0]
    @State private var caption = Celebrate.Caption(text: "")
    @State private var showWords = false
    @State private var typed = ""
    @State private var player = AVPlayer()
    /// The preview's sound: on, and it stays the way you set it when you try another effect.
    @State private var soundOn = true
    @State private var poster: CGImage?
    /// False until the preview's first frame is on screen — till then the still frame shows, never a black box.
    @State private var rolling = false
    @State private var duration: Double = 4
    @State private var beats: [Double] = []
    @State private var thumbs: [String: UIImage] = [:]
    @State private var thumbTask: Task<Void, Never>?
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
        ToolPage(title: "Video Effects",
                 subtitle: "Make it stunning — looks, light, motion, sparkle and words, as subtle or as wild as you like.",
                 working: working) {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                if let url = resultURL { result(url) }
                else if source == nil { pickCard }
                else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .onChange(of: recipe) { _, _ in schedulePreview() }
        .onChange(of: recipe.amount) { _, _ in scheduleThumbs() }
        .onChange(of: tab) { _, _ in scheduleThumbs() }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { n in
            if (n.object as? AVPlayerItem) == player.currentItem { player.seek(to: .zero); player.play() }
        }
        .onReceive(player.publisher(for: \.timeControlStatus)) { if $0 == .playing { rolling = true } }
        .onDisappear { player.pause(); previewTask?.cancel(); thumbTask?.cancel() }
        .handoff("celebrate") { p in adopt(p) }
        .onAppear { if Launch.sample, source == nil { sample() } }
        .finishes(working, tool: "Video Effects")
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            HStack(spacing: 10) {
                ForEach(VideoFX.vibes.prefix(5)) { v in
                    Text(v.emoji).font(.system(size: 30))
                        .frame(width: 52, height: 52)
                        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            Text(L("Pick a video or a photo. Give it a whole vibe in one tap — Cinematic, Golden hour, Party, Retro VHS — or build your own with looks, light, motion, sparkle and words. Any festival too."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            PhotosPicker(selection: $pick, matching: .any(of: [.videos, .images])) {
                Label(L("Choose a video or photo"), systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
            }.primaryButton().accessibilityIdentifier("celebrate-pick")
            if let f = loading { ToolProgressBar(value: f, label: "Getting it ready…") }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
        .frame(maxWidth: .infinity)
        .onChange(of: pick) { _, item in if let item { load(item) } }
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            previewBox
            howMuch
            tabs
            Group {
                switch tab {
                case .vibes: vibesRow
                case .look: pictures(VideoFX.looks, current: recipe.look) { recipe.look = $0 }
                case .light: pictures(VideoFX.lights, current: recipe.light) { recipe.light = $0 }
                case .motion: chips(VideoFX.motions, current: recipe.motion) { recipe.motion = $0; if $0 == "pulse", beats.isEmpty { loadBeats() } }
                case .texture: pictures(VideoFX.textures, current: recipe.texture) { recipe.texture = $0 }
                case .sparkle: chips(VideoFX.sparkles, current: recipe.sparkle) { recipe.sparkle = $0 }
                case .words: wordsCard
                case .celebrate: celebrateCard
                }
            }
            .transition(.opacity)

            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            Button { make() } label: {
                Label(L("Make my video"), systemImage: "sparkles").frame(maxWidth: .infinity)
            }.primaryButton().disabled(working).accessibilityIdentifier("celebrate-make")
            if working {
                ToolProgressBar(value: prog.fraction ?? 0, label: "Putting the effects on every frame…")
                Button(L("Stop")) { runTask?.cancel() }.textButton().frame(maxWidth: .infinity)
            }
            Button(L("Choose another video or photo")) { reset() }.textButton().font(HandyFont.caption).frame(maxWidth: .infinity)
        }
    }

    /// One slider for everything: from barely there to wild.
    private var howMuch: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L("How much")).font(HandyFont.bodyStrong)
                Spacer()
                Text(L(Self.strength(recipe.amount))).font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.accent)
                    .accessibilityIdentifier("fx-strength")
            }
            HStack(spacing: 8) {
                Text(L("Subtle")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                Slider(value: $recipe.amount, in: 0...1).tint(HandyColor.accent).accessibilityIdentifier("fx-amount")
                    .accessibilityLabel(L("How much"))
                Text(L("Dramatic")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    static func strength(_ a: Double) -> String {
        switch a {
        case ..<0.15: return "Barely there"
        case ..<0.4: return "Subtle"
        case ..<0.7: return "Just right"
        case ..<0.9: return "Bold"
        default: return "Wild"
        }
    }

    private var tabs: some View {
        HandyFlow(spacing: 6) {
                ForEach(Tab.allCases) { t in
                    Button { withAnimation(.easeOut(duration: 0.18)) { tab = t } } label: {
                        Label(L(t.title), systemImage: t.icon).font(HandyFont.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(tab == t ? HandyColor.accent : HandyColor.surface, in: Capsule())
                            .foregroundStyle(tab == t ? Color.white : HandyColor.textPrimary)
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("fx-tab-\(t.rawValue)")
                    .accessibilityAddTraits(tab == t ? .isSelected : [])
                }
            }
    }

    /// Whole looks in one tap, each shown on the person's own video. The next festival is one of them.
    private var vibesRow: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HandyFlow(spacing: 10) {
                    ForEach(VideoFX.vibes) { v in
                        let on = VideoFX.vibe(of: recipe)?.id == v.id
                        Button { apply(v.recipe) } label: { card(key: "vibes-\(v.id)", emoji: v.emoji, name: v.name, on: on) }
                            .buttonStyle(.plain).accessibilityIdentifier("fx-vibe-\(v.id)")
                    }
                    if let next = Celebrate.comingUp().first {
                        Button { choose(next); tab = .celebrate } label: { card(key: "vibes-fest", emoji: next.emoji, name: next.name, on: recipe.sparkle == "fest:" + next.id) }
                            .buttonStyle(.plain).accessibilityIdentifier("fx-vibe-festival")
                    }
                }
            Text(L(VideoFX.vibe(of: recipe).map { _ in "Tap a vibe, then make it yours in the other tabs." } ?? "Your own mix — tap a vibe to start again."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func pictures(_ list: [VideoFX.Choice], current: String, set: @escaping (String) -> Void) -> some View {
        HandyFlow(spacing: 10) {
                ForEach(list) { c in
                    Button { set(c.id) } label: { card(key: "\(tab.rawValue)-\(c.id)", emoji: c.emoji, name: c.name, on: current == c.id) }
                        .buttonStyle(.plain).accessibilityIdentifier("fx-\(tab.rawValue)-\(c.id)")
                }
            }
    }

    private func chips(_ list: [VideoFX.Choice], current: String, set: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(list) { c in
                Button { set(c.id) } label: {
                    VStack(spacing: 3) {
                        Text(c.emoji).font(.system(size: 24))
                        Text(L(c.name)).font(HandyFont.micro).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64).padding(.vertical, 4)
                    .foregroundStyle(current == c.id ? HandyColor.accent : HandyColor.textPrimary)
                    .background(current == c.id ? HandyColor.accent.opacity(0.15) : HandyColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(current == c.id ? HandyColor.accent : HandyColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain).accessibilityIdentifier("fx-\(tab.rawValue)-\(c.id)")
            }
        }
    }

    /// A choice shown on a frame of the person's own video.
    private func card(key: String, emoji: String, name: String, on: Bool) -> some View {
        VStack(spacing: 5) {
            ZStack {
                if let img = thumbs[key] { Image(uiImage: img).resizable().scaledToFill() }
                else if let p = poster { Image(decorative: p, scale: 1).resizable().scaledToFill().opacity(0.5) }
                else { HandyColor.surface }
                if thumbs[key] == nil { Text(emoji).font(.system(size: 26)) }
            }
            .frame(width: 84, height: 112).clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(on ? HandyColor.accent : HandyColor.border, lineWidth: on ? 3 : 1))
            Text("\(emoji) \(L(name))").font(HandyFont.micro).foregroundStyle(on ? HandyColor.accent : HandyColor.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.75).frame(width: 90)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L(name)))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private var wordsCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Toggle(isOn: $showWords) { Label(L("Your words on the video"), systemImage: "textformat").font(HandyFont.bodyStrong) }
                .tint(HandyColor.accent).accessibilityIdentifier("fx-words-on")
            if showWords {
                TextField("", text: $caption.text, prompt: Text(L("Best day ever")).foregroundStyle(HandyColor.textSecondary), axis: .vertical)
                    .lineLimit(1...3)
                    .foregroundStyle(HandyColor.textPrimary)
                    .padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .accessibilityIdentifier("celebrate-words")
                Text(L("How they arrive")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                HStack(spacing: 8) {
                    ForEach(VideoFX.wordStyles) { w in
                        Button { recipe.words = w.id } label: {
                            Text("\(w.emoji) \(L(w.name))").font(HandyFont.caption)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(recipe.words == w.id ? HandyColor.accent : HandyColor.surface, in: Capsule())
                                .foregroundStyle(recipe.words == w.id ? Color.white : HandyColor.textPrimary)
                        }.buttonStyle(.plain).accessibilityIdentifier("fx-words-\(w.id)")
                    }
                }
                HandyFlow(spacing: 8) {
                        ForEach(Celebrate.Font.allCases) { f in
                            Button { caption.font = f } label: {
                                Text(L(f.title)).font(Font(f.ui(15) as CTFont))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(caption.font == f ? HandyColor.accent : HandyColor.surface, in: Capsule())
                                    .foregroundStyle(caption.font == f ? Color.white : HandyColor.textPrimary)
                            }.buttonStyle(.plain)
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

    /// Any festival in the world, or one typed in any language: its decorations and its greeting.
    private var celebrateCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
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
            if theme.custom, recipe.sparkle.hasPrefix("fest:") {
                Label(L("Made from your words — tap a celebration below to switch."), systemImage: "wand.and.stars")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            let soon = Celebrate.comingUp()
            if !soon.isEmpty {
                Text(L("Coming up")).font(HandyFont.bodyStrong)
                HandyFlow(spacing: 8) { ForEach(soon) { festival($0, big: true) } }
            }
            Text(L("Every celebration")).font(HandyFont.bodyStrong)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(Celebrate.ordered().filter { t in !soon.contains { $0.id == t.id } }) { festival($0, big: false) }
            }
        }
    }

    private func festival(_ t: Celebrate.Theme, big: Bool) -> some View {
        let on = recipe.sparkle == "fest:" + t.id && theme.id == t.id && !theme.custom
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

    /// The video playing with the effects on it; the words sit on top and follow your finger.
    private var previewBox: some View {
        GeometryReader { g in
            ZStack {
                Color.black
                VideoPlayer(player: player).disabled(true)
                if !rolling, let p = poster {
                    Image(decorative: p, scale: 1).resizable().scaledToFit().allowsHitTesting(false)
                }
                Button {
                    soundOn.toggle(); player.isMuted = !soundOn
                } label: {
                    Image(systemName: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 40, height: 40).background(.black.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(8)
                .accessibilityLabel(L(soundOn ? "Sound off" : "Sound on"))
                .accessibilityIdentifier("celebrate-sound")
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
                        .accessibilityElement()
                        .accessibilityLabel(caption.text)
                        .accessibilityHint(L("Drag to move, pinch to resize"))
                        .accessibilityIdentifier("celebrate-caption")
                }
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: 420)
        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("celebrate-preview")
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label(resultTitle, systemImage: "checkmark.circle.fill")
                .font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success)
            VideoFinishCard(url: url, source: source, tool: "Video Effects").id(url)
            Button(L("Try another look")) { resultURL = nil; schedulePreview() }.textButton().frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("celebrate-result")
    }

    private var resultTitle: String {
        if recipe.sparkle.hasPrefix("fest:") { return "\(theme.emoji) \(L(theme.custom ? "Your celebration" : theme.name))" }
        if let v = VideoFX.vibe(of: recipe) { return "\(v.emoji) \(L(v.name))" }
        return L("Your own mix")
    }

    // MARK: - Actions

    private func apply(_ r: VideoFX.Recipe) {
        var n = r; n.amount = recipe.amount; n.words = recipe.words
        recipe = n
        if n.motion == "pulse", beats.isEmpty { loadBeats() }
    }

    private func choose(_ t: Celebrate.Theme) {
        let oldGreeting = theme.greeting
        theme = t
        recipe.sparkle = "fest:" + t.id
        // A celebration is a whole scene: its own colour grade and light, a slow cinematic push, and nothing (like
        // cinema bars) covering its decorations. Every part can still be changed in its tab.
        if let l = t.look { recipe.look = l } else if recipe.look == "none" || recipe.look == "noir" { recipe.look = "golden" }
        if let l = t.light { recipe.light = l }
        if recipe.texture == "bars" { recipe.texture = "none" }
        if recipe.motion == "none" { recipe.motion = "zoom" }
        // Swap the words too, unless the person wrote their own.
        if caption.text.isEmpty || caption.text == oldGreeting || caption.text == L(oldGreeting) { caption.text = L(t.greeting) }
        showWords = true
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

    /// Take a video: learn its shape, grab a frame for the pictures, put the words where no face is, start the preview.
    private func use(_ url: URL) async {
        let asset = AVURLAsset(url: url)
        var shape: CGFloat = 9.0 / 16.0
        if let tr = try? await asset.loadTracks(withMediaType: .video).first,
           let n = try? await tr.load(.naturalSize), let t = try? await tr.load(.preferredTransform) {
            let r = CGRect(origin: .zero, size: n).applying(t)
            if r.height != 0 { shape = abs(r.width) / abs(r.height) }
        }
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true; gen.maximumSize = CGSize(width: 360, height: 360)
        let secs = (try? await asset.load(.duration).seconds) ?? 1
        let frame = try? await gen.image(at: CMTime(seconds: min(1, secs / 3), preferredTimescale: 600)).image
        let spot = Celebrate.clearSpot(in: frame)
        await MainActor.run {
            source = url; aspect = shape; resultURL = nil; poster = frame; rolling = false; duration = max(1, secs); thumbs = [:]; beats = []
            caption.center = spot
            schedulePreview(); scheduleThumbs()
            if recipe.motion == "pulse" { loadBeats() }
        }
    }

    private func loadBeats() {
        guard let u = source else { return }
        Task {
            let b = await VideoFX.beats(u)
            await MainActor.run { beats = b; schedulePreview() }
        }
    }

    /// The pictures for the open tab, made from the person's own frame (again when "How much" moves).
    private func scheduleThumbs() {
        thumbTask?.cancel()
        guard let p = poster else { return }
        let base = recipe, t = tab, d = duration
        var jobs: [(String, VideoFX.Recipe)] = []
        func add(_ key: String, _ change: (inout VideoFX.Recipe) -> Void) { var r = base; change(&r); jobs.append((key, r)) }
        switch t {
        case .vibes:
            for v in VideoFX.vibes { add("vibes-\(v.id)") { r in r = v.recipe; r.amount = base.amount } }
            if let f = Celebrate.comingUp().first { add("vibes-fest") { r in r.sparkle = "fest:" + f.id; if r.look == "none" { r.look = "golden" } } }
        case .look:
            for c in VideoFX.looks { add("look-\(c.id)") { r in r.look = c.id; r.light = "none"; r.motion = "none"; r.texture = "none"; r.sparkle = "none" } }
        case .light:
            for c in VideoFX.lights { add("light-\(c.id)") { r in r.light = c.id; r.sparkle = "none" } }
        case .texture:
            for c in VideoFX.textures { add("texture-\(c.id)") { r in r.texture = c.id; r.sparkle = "none" } }
        default: break
        }
        let work = jobs
        guard !work.isEmpty else { return }
        thumbTask = Task.detached(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 120_000_000)
            for (key, r) in work {
                if Task.isCancelled { return }
                let img = VideoFX.still(p, recipe: r, t: min(1.4, d * 0.4), duration: d)
                await MainActor.run { if let img { thumbs[key] = img } }
            }
        }
    }

    /// Rebuild the live preview (debounced) whenever the recipe changes, carrying on from the same moment.
    private func schedulePreview() {
        previewTask?.cancel()
        guard let url = source, resultURL == nil else { return }
        let r = recipe, b = beats
        previewTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            let asset = AVURLAsset(url: url)
            let comp = await VideoFX.composition(for: asset, recipe: r, caption: nil, beats: b)
            await MainActor.run {
                guard !Task.isCancelled else { return }
                let at = player.currentTime()
                let item = AVPlayerItem(asset: asset)
                item.videoComposition = comp
                player.replaceCurrentItem(with: item)
                player.isMuted = !soundOn
                if at.isValid, at.seconds > 0 { player.seek(to: at, toleranceBefore: .zero, toleranceAfter: .zero) }
                player.play()
            }
        }
    }

    private func make() {
        guard let url = source else { return }
        player.pause(); working = true; errorText = nil
        RunProgress.shared.begin()
        let r = recipe, c: Celebrate.Caption? = showWords && !caption.text.trimmingCharacters(in: .whitespaces).isEmpty ? caption : nil
        let name = resultTitle.drop { !$0.isLetter }
        runTask = Task {
            let out = await VideoFX.export(url, recipe: r, caption: c)
            await MainActor.run {
                RunProgress.shared.end(); working = false
                if Task.isCancelled { errorText = "Stopped."; player.play(); return }
                guard let out else { errorText = "Couldn't make the video — try again."; player.play(); return }
                let named = FileManager.default.temporaryDirectory.appendingPathComponent("\(name.isEmpty ? "Tenzy" : String(name)) video.mp4")
                try? FileManager.default.removeItem(at: named)
                resultURL = (try? FileManager.default.moveItem(at: out, to: named)) != nil ? named : out
                HandyHaptics.success()
            }
        }
    }

    private func reset() {
        previewTask?.cancel(); runTask?.cancel(); thumbTask?.cancel(); player.pause(); player.replaceCurrentItem(with: nil)
        source = nil; resultURL = nil; errorText = nil; caption.text = ""; poster = nil; thumbs = [:]
    }
}
