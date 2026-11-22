import SwiftUI
import PhotosUI
import AVKit

/// Post it — pick where the video is going; Tenzy shows exactly what it will do (tall with soft sides, the
/// liveliest part if it's too long, small enough), makes it, then one tap saves it, copies the caption with the
/// platform's tags, and opens the app on it. Reached from the video page ("Post it"), from every finished video,
/// and from Video effects.
struct PostItView: View {
    var startURL: URL? = nil
    @State private var source: URL?
    @State private var facts: VideoFacts?
    @State private var poster: UIImage?
    @State private var pick: PhotosPickerItem?
    @State private var loading: Double?
    @AppStorage("post.platform") private var platformID = "tiktok"
    @State private var caption = ""
    @State private var working = false
    @State private var step = ""
    @State private var ready: URL?
    @State private var readyFor: String?
    @State private var player: AVPlayer?
    @State private var note: String?
    @State private var problem: String?
    @ObservedObject private var prog = RunProgress.shared

    private let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    private var platform: SocialPost.Platform { SocialPost.platform(platformID) ?? SocialPost.platforms[0] }

    var body: some View {
        ToolPage(title: "Post it", subtitle: "Ready for TikTok, Reels, Shorts and more — the right shape, length and size, then straight into the app.", working: working) {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                if source == nil { pickCard } else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter).padding(.vertical, HandySpacing.s12)
        }
        .onChange(of: pick) { _, item in if let item { load(item) } }
        .handoff("post") { p in if case .video(let u) = p { Task { await use(u) } } }
        .task { if let u = startURL, source == nil { await use(u) } else if Launch.sample, source == nil, let u = await SampleAssets.movie(seconds: 3, size: CGSize(width: 640, height: 360)) { await use(u) } }
        .onDisappear { player?.pause() }
        .finishes(working, tool: "Post it")
    }

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            platformGrid(pickFirst: true)
            Text(L("Pick a video. Tenzy makes it the right shape, length and size for where it's going, then opens the app with it ready to post."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            PhotosPicker(selection: $pick, matching: .videos) {
                Label(L("Choose a video"), systemImage: "film").frame(maxWidth: .infinity)
            }.primaryButton().accessibilityIdentifier("post-pick")
            if let f = loading { ToolProgressBar(value: f, label: "Getting it ready…") }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if let ready, readyFor == platformID {
                done(ready)
            } else {
                HStack(spacing: HandySpacing.s12) {
                    ZStack {
                        if let poster { Image(uiImage: poster).resizable().scaledToFill() } else { HandyColor.surface }
                    }
                    .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("Your video")).font(HandyFont.bodyStrong)
                        if let f = facts {
                            Text("\(VideoFacts.clock(f.seconds)) · \(SizeTarget.format(f.bytes)) · \(L(f.isTall ? "Tall" : f.size.width > f.size.height ? "Sideways" : "Square"))")
                                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    PhotosPicker(selection: $pick, matching: .videos) { Text(L("Change")) }.font(HandyFont.caption)
                }
                Text(L("Where is it going?")).font(HandyFont.title)
                platformGrid(pickFirst: false)
                plan
                captionCard
                if let problem { Text(L(problem)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
                Button { make() } label: {
                    Label("\(L("Get it ready for")) \(L(platform.name))", systemImage: "sparkles").frame(maxWidth: .infinity)
                }.primaryButton().disabled(working).accessibilityIdentifier("post-make")
                if working { ToolProgressBar(value: prog.fraction, label: step.isEmpty ? "Getting it ready…" : step) }
            }
        }
    }

    private func platformGrid(pickFirst: Bool) -> some View {
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(SocialPost.platforms) { p in
                let on = p.id == platformID && !pickFirst
                Button { platformID = p.id; problem = nil } label: {
                    VStack(spacing: 5) {
                        Image(systemName: p.icon).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: p.tint), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(.white.opacity(0.25), lineWidth: 1))
                        Text(L(p.name)).font(HandyFont.micro).foregroundStyle(HandyColor.textPrimary).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 84).padding(.vertical, 4)
                    .background(on ? HandyColor.accentSoft : HandyColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? HandyColor.accent : HandyColor.border, lineWidth: on ? 2 : 1))
                }
                .buttonStyle(.plain).disabled(pickFirst)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("post-\(p.id)")
            }
        }
    }

    /// Exactly what will happen to this video for this platform.
    @ViewBuilder private var plan: some View {
        if let f = facts {
            let pl = SocialPost.plan(platform, seconds: f.seconds, bytes: f.bytes, size: f.size)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(L("For")) \(L(platform.name))").font(HandyFont.bodyStrong)
                ForEach(pl.steps, id: \.self) { s in
                    Label { Text(s).font(HandyFont.caption).fixedSize(horizontal: false, vertical: true) } icon: {
                        Image(systemName: pl.nothingToChange ? "checkmark.circle.fill" : "wand.and.stars").foregroundStyle(pl.nothingToChange ? HandyColor.success : HandyColor.accent)
                    }
                }
                Label { Text(L("Then: saved to Photos, caption copied, and the app opens on it — you tap Post.")).font(HandyFont.caption).fixedSize(horizontal: false, vertical: true) } icon: {
                    Image(systemName: "arrow.up.forward.app.fill").foregroundStyle(HandyColor.accent)
                }
            }
            .cardStyle(padding: HandySpacing.s12)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("post-plan")
        }
    }

    private var captionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Caption (copied for you)")).font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.textSecondary)
            TextField("", text: $caption, prompt: Text(L("Say something about it…")).foregroundStyle(HandyColor.textSecondary), axis: .vertical)
                .lineLimit(1...4).foregroundStyle(HandyColor.textPrimary)
                .padding(HandySpacing.s12)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                .accessibilityIdentifier("post-caption")
            if !platform.tags.isEmpty {
                Text("\(L("Adds")) \(platform.tags.joined(separator: " "))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }
    }

    /// Ready: watch it, then one tap into the app (or save / share it any other way).
    private func done(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label("\(L("Ready for")) \(L(platform.name))", systemImage: "checkmark.circle.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success)
            if let player {
                VideoPlayer(player: player).frame(maxWidth: .infinity).frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
            }
            Button { Task { await post(url) } } label: {
                Label("\(L("Open")) \(L(platform.name))", systemImage: "arrow.up.forward.app.fill").frame(maxWidth: .infinity)
            }.primaryButton().accessibilityIdentifier("post-open")
            Text(L("Saves it to Photos, copies your caption, and opens the app — pick the video if it asks, paste the caption, tap Post."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            if let note { Label(note, systemImage: "info.circle").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
            KeepShare(url, lead: .share, tool: "Post it")
            Button(L("Post it somewhere else")) { ready = nil; readyFor = nil; player?.pause() }.textButton().frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("post-ready")
    }

    // MARK: actions

    private func load(_ item: PhotosPickerItem) {
        pick = nil; loading = 0
        Task {
            let m = await MovieImport.load(item, progress: { f in Task { @MainActor in loading = f } })
            await MainActor.run { loading = nil }
            if let m { await use(m.url) }
        }
    }

    private func use(_ u: URL) async {
        let f = await VideoFacts.read(u)
        let img = await VideoEngine.thumbnail(u, at: min(1, (f?.seconds ?? 0) / 3), maxDim: 240)
        await MainActor.run { source = u; facts = f; poster = img; ready = nil; readyFor = nil; problem = nil }
    }

    private func make() {
        guard let u = source else { return }
        working = true; problem = nil; step = ""
        RunProgress.shared.begin()
        let p = platform
        Task {
            let out = await SocialPost.prepare(u, for: p) { s in Task { @MainActor in step = s } }
            await MainActor.run {
                RunProgress.shared.end(); working = false
                guard let out else { problem = "That couldn't be made from this video — try another."; return }
                ready = out; readyFor = p.id; player?.pause(); player = AVPlayer(url: out); player?.play()
                HandyHaptics.success()
            }
        }
    }

    /// Save, copy the caption, open the app (or its App Store page if it isn't on the phone).
    private func post(_ url: URL) async {
        let p = platform
        let saved = await SocialPost.saveToPhotos(url)
        let words = SocialPost.caption(caption, for: p)
        await MainActor.run {
            if !words.isEmpty { UIPasteboard.general.string = words }
            note = saved.ok ? L(words.isEmpty ? "Saved to Photos." : "Saved to Photos · caption copied — paste it in.")
                            : L("Tenzy isn't allowed to add to Photos, so share it from the button below instead.")
        }
        guard saved.ok, let target = SocialPost.openURL(p, assetID: saved.id) else { return }
        let opened = await UIApplication.shared.open(target)
        if !opened, let store = URL(string: p.store) {
            await MainActor.run { note = "\(L(p.name)) — \(L("isn't on this phone, so the App Store opens. The video is in Photos when you're ready."))" }
            await UIApplication.shared.open(store)
        }
    }
}
