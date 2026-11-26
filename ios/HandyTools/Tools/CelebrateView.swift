import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

/// Video Studio (26 Nov: Video Effects grown into one place for everything on a video) — faces and bodies made funny or
/// beautiful (Engines/FaceFun.swift), what's behind the person (or their own photo), the music under it (made by
/// Tenzy, or their own song), then saved or posted straight to TikTok, Reels, Shorts and the rest.
/// Video effects — "Make it stunning". A video (or photo) with a whole vibe in one tap (Cinematic, Golden hour,
/// Party, Dreamy, Love, Retro VHS, Noir, Epic, Night sky), or built up piece by piece: a look, light, motion on the
/// beat, texture, sparkle, animated words, or any festival from every part of the world. One "How much" slider takes
/// all of it from barely there to wild. Every choice shows on a picture of the person's own video; the live preview
/// plays with it on; the saved video keeps its sound and finishes even if you leave the app.
struct CelebrateView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case vibes, funny, background, music, look, light, motion, texture, sparkle, words, celebrate
        var id: String { rawValue }
        var title: String {
            switch self {
            case .vibes: return "Vibes"
            case .look: return "Look"
            case .light: return "Light"
            case .motion: return "Motion"
            case .texture: return "Texture"
            case .sparkle: return "Sparkle"
            case .background: return "Background"
            case .funny: return "Faces"
            case .music: return "Music"
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
            case .background: return "person.crop.rectangle"
            case .funny: return "face.smiling"
            case .music: return "music.note"
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
    /// What the preview box is showing, for the build machine's check (refreshed while the page is open in a test).
    @State private var probe = ""
    /// Kept as a property: a timer made inside `body` restarts on every redraw and could keep missing its beat.
    private let previewTick = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    /// This phone's player couldn't run the effects live (any video composition failed, -11800/-12784, on the build
    /// machine while the saved video played). Then the preview is a quick rendered copy with the effects on.
    @State private var liveFails = false
    /// The rendered copy now playing, removed when the next one replaces it.
    @State private var renderedClip: URL?
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
    /// Their own photo for behind the person, and their own song.
    @State private var backdropPick: PhotosPickerItem?
    @State private var pickingSong = false
    @State private var songName: String?
    /// Where the finished video is being posted (a platform's id), once they tap one.
    @State private var postTo: String?
    @ObservedObject private var prog = RunProgress.shared

    private let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ToolPage(title: "Video Studio",
                 subtitle: "Funny faces, a new background, music, looks and words — then save it or post it anywhere.",
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
        // The still frame stays up until the video has really moved on screen (a "playing" flag alone came before the
        // first picture, and the box showed black — Gold Book review, 24 Nov). Checked until it moves, not once: a
        // single check 0.6 s after "playing" could miss, and the box then kept the plain still for good.
        .onReceive(previewTick) { _ in
            guard source != nil, resultURL == nil else { return }
            let item = player.currentItem
            if item?.status == .failed, !liveFails { liveFails = true; schedulePreview() }
            if !rolling, player.timeControlStatus == .playing, player.currentTime().seconds > 0.25,
               (item?.presentationSize.width ?? 0) > 0 { rolling = true }
            if Launch.uitest {
                probe = "poster \(poster != nil) loading \(poster == nil && !rolling) rendered \(liveFails) rolling \(rolling) playing \(player.timeControlStatus == .playing) item \(item != nil) status \(item?.status.rawValue ?? -1) wait \(player.reasonForWaitingToPlay?.rawValue ?? "-") err \((item?.error as NSError?).map { e in "\(e.domain) \(e.code) \((e.userInfo[NSUnderlyingErrorKey] as? NSError).map { "\($0.domain) \($0.code)" } ?? "-")" } ?? "-") log \(item?.errorLog()?.events.last.map { "\($0.errorDomain) \($0.errorStatusCode)" } ?? "-") size \(Int(item?.presentationSize.width ?? 0)) t \(String(format: "%.1f", player.currentTime().seconds))"
            }
        }
        .onDisappear { player.pause(); previewTask?.cancel(); thumbTask?.cancel() }
        .handoff("celebrate") { p in adopt(p) }
        .onAppear { if Launch.sample, source == nil { sample() } }
        .finishes(working, tool: "Video Studio")
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
            // Or make it now (26 Nov): record the moment, or snap a photo, right here.
            HStack(spacing: HandySpacing.s8) {
                CameraButton(video: true, took: tookWithCamera) { Label(L("Record"), systemImage: "video").frame(maxWidth: .infinity) }
                    .secondaryButton().accessibilityIdentifier("tool-record")
                CameraButton(took: tookWithCamera) { Label(L("Take a photo"), systemImage: "camera").frame(maxWidth: .infinity) }
                    .secondaryButton().accessibilityIdentifier("tool-camera")
            }
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
                // Diagnostics for the Gold Book review (the preview showed black on the build machine): what it's showing.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("celebrate-preview")
                .accessibilityValue(!Launch.uitest ? "" : probe.isEmpty ? "poster \(poster != nil) loading \(poster == nil && !rolling) rolling \(rolling)" : probe)
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
                case .background: backgroundCard
                case .funny: facesCard
                case .music: musicCard
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

    /// Every face and body effect, in its group, each shown on the person's own video.
    private var facesCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            ForEach(FaceFun.Group.allCases) { g in
                Text(L(g.rawValue)).font(HandyFont.bodyStrong)
                HandyFlow(spacing: 10) {
                    if g == FaceFun.Group.allCases.first {
                        Button { recipe.funny = "none" } label: { card(key: "funny-none", emoji: "⚪️", name: "Off", on: recipe.funny == "none") }
                            .buttonStyle(.plain).accessibilityIdentifier("fx-funny-none")
                    }
                    ForEach(FaceFun.effects.filter { $0.group == g }) { e in
                        Button { recipe.funny = e.id } label: { card(key: "funny-\(e.id)", emoji: e.emoji, name: e.name, on: recipe.funny == e.id) }
                            .buttonStyle(.plain).accessibilityIdentifier("fx-funny-\(e.id)")
                    }
                }
            }
            Text(L("Tenzy finds every face on every frame, right on your phone. \"How much\" takes each one from gentle to wild."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// What's behind the person: blurred, colour-popped, a backdrop — or their own photo.
    private var backgroundCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HandyFlow(spacing: 10) {
                ForEach(VideoFX.backgrounds.filter { $0.id != "photo" }) { c in
                    Button { recipe.background = c.id } label: { card(key: "background-\(c.id)", emoji: c.emoji, name: c.name, on: recipe.background == c.id) }
                        .buttonStyle(.plain).accessibilityIdentifier("fx-background-\(c.id)")
                }
                PhotosPicker(selection: $backdropPick, matching: .images) {
                    card(key: "background-photo", emoji: "🖼️", name: "Your photo", on: recipe.background == "photo")
                }
                .buttonStyle(.plain).accessibilityIdentifier("fx-background-photo")
            }
            Text(L("Tenzy finds the person on every frame and changes only what's behind them."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: backdropPick) { _, item in if let item { loadBackdrop(item) } }
    }

    /// The sound: as filmed, none, music Tenzy makes, or their own song — and how much of the video's sound stays.
    private var musicCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(VideoSound.choices) { c in
                    Button { recipe.music = c.id } label: { chip(c.emoji, c.name, on: recipe.music == c.id) }
                        .buttonStyle(.plain).accessibilityIdentifier("fx-music-\(c.id.replacingOccurrences(of: ":", with: "-"))")
                        .accessibilityAddTraits(recipe.music == c.id ? .isSelected : [])
                }
                Button { pickingSong = true } label: { chip("🎵", songName ?? L("Your song"), on: recipe.music == "file", translate: false) }
                    .buttonStyle(.plain).accessibilityIdentifier("fx-music-file")
            }
            if recipe.music.hasPrefix("synth:") || recipe.music == "file" {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Music and the video's own sound")).font(HandyFont.bodyStrong)
                    HStack(spacing: 8) {
                        Text(L("Music")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                        Slider(value: $recipe.keep, in: 0...1).tint(HandyColor.accent).accessibilityIdentifier("fx-music-mix")
                            .accessibilityLabel(L("Music and the video's own sound"))
                        Text(L("Video")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    }
                }
                .cardStyle(padding: HandySpacing.s12)
            }
            Text(L(recipe.music == "file" ? "Your own song, from Files. Post it only where you have the right to use that music — apps can mute videos with music they recognise."
                   : "Tenzy makes this music on your phone. It's yours to post anywhere."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .fileImporter(isPresented: $pickingSong, allowedContentTypes: [.audio]) { r in
            guard case .success(let u) = r else { return }
            Task {
                let copy = await VideoSound.adopt(u)
                await MainActor.run {
                    if let copy { recipe.song = copy; recipe.music = "file"; songName = u.deletingPathExtension().lastPathComponent; errorText = nil }
                    else { errorText = "That song can't be used — it may be protected. Try another file." }
                }
            }
        }
    }

    private func chip(_ emoji: String, _ name: String, on: Bool, translate: Bool = true) -> some View {
        VStack(spacing: 3) {
            Text(emoji).font(.system(size: 24))
            Text(translate ? L(name) : name).font(HandyFont.micro).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 64).padding(.vertical, 4).padding(.horizontal, 4)
        .foregroundStyle(on ? HandyColor.accent : HandyColor.textPrimary)
        .background(on ? HandyColor.accent.opacity(0.15) : HandyColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(on ? HandyColor.accent : HandyColor.border, lineWidth: 1))
    }

    private func loadBackdrop(_ item: PhotosPickerItem) {
        backdropPick = nil
        Task {
            guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d)?.normalizedUp(),
                  let jpg = img.jpegData(compressionQuality: 0.9) else { await MainActor.run { errorText = "Couldn't open that photo — try another." }; return }
            let u = FileManager.default.temporaryDirectory.appendingPathComponent("studio-backdrop-\(UUID().uuidString.prefix(8)).jpg")
            guard (try? jpg.write(to: u)) != nil else { return }
            await MainActor.run { recipe.backdrop = u; recipe.background = "photo"; errorText = nil; thumbs["background-photo"] = nil; scheduleThumbs() }
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
            .frame(width: 84, height: 112).clipped().contentShape(Rectangle())
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
                } else if !rolling {
                    // Never a silent black box (Gold Book): until the first frame is ready, say it's coming.
                    VStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text(L("Getting your preview ready…")).font(HandyFont.caption).foregroundStyle(.white.opacity(0.85))
                    }
                    .accessibilityElement(children: .combine)
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
            if let id = postTo, let p = SocialPost.platform(id) {
                // Made the right shape, length and size for that app, then one tap into it.
                PostReadyCard(source: url, platform: p) { postTo = nil }.id(url.path + id)
            } else {
                VideoFinishCard(url: url, source: source, tool: "Video Studio", offersPost: false).id(url)
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text(L("Post it")).font(HandyFont.title)
                    Text(L("Tap where it's going: Tenzy makes it the right shape, length and size, then opens the app on it."))
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    PlatformGrid(selected: Binding(get: { postTo ?? "" }, set: { postTo = $0 }))
                }
                .accessibilityElement(children: .contain).accessibilityIdentifier("studio-post")
            }
            Button(L("Change the video")) { postTo = nil; resultURL = nil; schedulePreview() }.textButton().frame(maxWidth: .infinity)
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
        // A vibe is the look; what's behind the person and a funny face are theirs to keep (Original clears all).
        if !r.isPlain || r.look != "none" { n.background = recipe.background; n.funny = recipe.funny }
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

    private func tookWithCamera(_ t: CameraTake) {
        errorText = nil
        switch t {
        case .video(let u): Task { await use(u) }
        case .photo(let img):
            loading = 0.5
            Task {
                let v = await Celebrate.videoFromPhoto(img)
                await MainActor.run { loading = nil }
                if let v { await use(v) } else { await MainActor.run { errorText = "Couldn't turn that photo into a video — try another." } }
            }
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
        case .background:
            for c in VideoFX.backgrounds where c.id != "photo" || base.backdrop != nil { add("background-\(c.id)") { r in r.background = c.id; r.sparkle = "none" } }
        case .funny:
            // Each face effect on its own, on the plain picture, so it reads at a glance.
            for c in VideoFX.funnies { add("funny-\(c.id)") { r in r.funny = c.id; r.sparkle = "none"; r.background = "none"; r.motion = "none" } }
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
            if liveFails {
                // The old clip keeps playing while the new one is made, so the box never goes blank.
                guard let clip = await VideoFX.previewClip(url, recipe: r, beats: b), !Task.isCancelled else { return }
                await MainActor.run {
                    guard !Task.isCancelled else { try? FileManager.default.removeItem(at: clip); return }
                    if let old = renderedClip { try? FileManager.default.removeItem(at: old) }
                    renderedClip = clip
                    player.replaceCurrentItem(with: AVPlayerItem(url: clip))
                    player.isMuted = !soundOn
                    player.play()
                }
                return
            }
            // Picture and sound together: the music (and how much of the video's own sound stays) plays in the preview too.
            let built = await VideoSound.build(url, music: r.music, song: r.song, keep: r.keep)
            let comp = await VideoFX.composition(for: built.asset, recipe: r, caption: nil, beats: b.isEmpty ? built.beats : b)
            await MainActor.run {
                guard !Task.isCancelled else { return }
                if let p = built.problem { errorText = p }
                let at = player.currentTime()
                let item = AVPlayerItem(asset: built.asset)
                item.videoComposition = comp
                item.audioMix = built.mix
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
        source = nil; resultURL = nil; errorText = nil; caption.text = ""; poster = nil; thumbs = [:]; postTo = nil
        if let old = renderedClip { try? FileManager.default.removeItem(at: old) }
        renderedClip = nil
    }
}
