import SwiftUI
import PhotosUI
import AVKit

/// Animate — add photos, get a polished video sized for where you'll post it. Tenzy picks a style that
/// suits how many photos you chose; every change (style, format, framing, pace) re-plays a quick live
/// preview, and "Make video" renders the full-quality MP4 with live progress, finishing in the
/// background if you leave. 26 styles, five real platform formats, all on device.
struct AnimateView: View {
    @State private var photos: [UIImage] = []
    @State private var picks: [PhotosPickerItem] = []
    @State private var loading = false
    @State private var settings = Animate.Settings()
    @State private var styleTouched = false
    @State private var previewURL: URL?
    @State private var previewing = false
    @State private var previewTask: Task<Void, Never>?
    @State private var player = AVPlayer()
    @State private var progress: Double = 0
    @State private var working = false
    @State private var resultURL: URL?
    @State private var errorText: String?
    @State private var gifURL: URL?
    @State private var look: Animate.Look = .original
    @State private var styledPhotos: [UIImage] = []
    @State private var printURL: URL?
    @State private var makingGIF = false
    /// Where it's going (TikTok, Instagram post, YouTube…) — sets the shape, and the finish hands it straight to that app.
    @State private var postTo = "tiktok"
    @State private var choosingPlace = false
    /// The song under the video, if any.
    @State private var music: MusicTrack.Pick?
    @State private var pickingMusic = false
    @State private var readingSong = false
    @State private var musicPlayer = AVPlayer()
    @State private var note: String?
    @State private var stage = ""

    static let maxPhotos = 24
    private let cols = [GridItem(.flexible(), spacing: HandySpacing.s8), GridItem(.flexible(), spacing: HandySpacing.s8),
                        GridItem(.flexible(), spacing: HandySpacing.s8)]

    var body: some View {
        ToolPage(title: "Animate",
                 subtitle: "Turn photos into a video made for Reels, TikTok, Shorts, Stories and more.",
                 working: working) {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                if let url = resultURL { result(url) }
                else if photos.isEmpty { pickCard }
                else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .onChange(of: picks) { _, items in load(items) }
        .handoffPhotos("animate") { imgs in adopt(imgs.prefix(Self.maxPhotos).map { $0.resized(maxDimension: 1440).normalizedUp() }) }
        .onChange(of: settings) { _, _ in schedulePreview() }
        .onChange(of: look) { _, _ in restyle() }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { n in
            if (n.object as? AVPlayerItem) == player.currentItem, resultURL == nil {
                player.seek(to: .zero); player.play(); startMusic()
            }
        }
        .onChange(of: postTo) { _, id in
            if let p = SocialPost.platform(id) { settings.format = VideoFormat.spec(for: p) }
        }
        .sheet(isPresented: $pickingMusic) { MusicPickerSheet { song in useSong(song) } }
        .onDisappear { player.pause(); musicPlayer.pause(); previewTask?.cancel() }
        .finishes(working, tool: "Animate")
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "sparkles.rectangle.stack").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Pick a few photos. Tenzy turns them into a smooth video — 26 styles: page turn, flipbook, 3D cube, carousel, ripple, heart and more."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            SmartPhotoButton(kind: .any, max: Self.maxPhotos, picked: { imgs in adopt(imgs.prefix(Self.maxPhotos).map { $0.resized(maxDimension: 1440).normalizedUp() }) }) {
                Label(L("Choose photos"), systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
            }.primaryButton()
            if loading { ToolProgressBar(label: "Getting your photos…", showsTime: false) }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s16) {
            previewBox
            HandyFlow(spacing: HandySpacing.s8) {
                    ForEach(photos.indices, id: \.self) { i in
                        Image(uiImage: photos[i]).resizable().scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)).contentShape(Rectangle())
                    }
                    SmartPhotoButton(kind: .any, max: Self.maxPhotos, picked: { imgs in adopt(imgs.prefix(Self.maxPhotos).map { $0.resized(maxDimension: 1440).normalizedUp() }) }) {
                        Image(systemName: "plus").frame(width: 52, height: 52)
                            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }.accessibilityLabel(L("Change photos"))
                }

            musicCard

            section("Style")
            ForEach(Animate.Style.Group.allCases) { g in
                Text(L(g.rawValue)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                LazyVGrid(columns: cols, spacing: HandySpacing.s8) {
                    ForEach(Animate.Style.inGroup(g)) { s in styleTile(s) }
                }
            }

            section("Where will you post it?")
            PlatformGrid(selected: $postTo, showsShape: true)
            section("Look")
            Picker("", selection: $look) {
                ForEach(Animate.Look.allCases) { Text(L($0.title)).tag($0) }
            }.pickerStyle(.segmented)
            Picker("", selection: $settings.framing) {
                ForEach(Animate.Framing.allCases) { Text(L($0.title)).tag($0) }
            }.pickerStyle(.segmented)
            Picker("", selection: $settings.pace) {
                ForEach(Animate.Pace.allCases) { Text(L($0.title)).tag($0) }
            }.pickerStyle(.segmented)

            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            Button { make() } label: {
                Label(L("Make video"), systemImage: "film.stack").frame(maxWidth: .infinity)
            }.primaryButton().disabled(working)
            if working { ToolProgressBar(value: progress, label: stage.isEmpty ? "Making your \(Int(settings.format.size.width))×\(Int(settings.format.size.height)) video…" : stage) }
            Button(L("Start over")) { reset() }.textButton().font(HandyFont.caption).frame(maxWidth: .infinity)
        }
    }

    /// The song under the video: add one, hear it in the preview, change or remove it.
    @ViewBuilder private var musicCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            section("Music")
            if readingSong {
                HStack(spacing: 8) { BusySpinner(); Text(L("Finding the beat and the best part…")).font(HandyFont.caption) }
            } else if let m = music {
                HStack(spacing: HandySpacing.s12) {
                    Image(systemName: "music.note").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 40, height: 40).background(HandyColor.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.song.title).font(HandyFont.bodyStrong).lineLimit(1)
                        Text(musicLine(m)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    Button(L("Change")) { pickingMusic = true }.font(HandyFont.caption.weight(.semibold)).accessibilityIdentifier("animate-music-change")
                    Button { removeMusic() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(HandyColor.textSecondary) }
                        .buttonStyle(.plain).accessibilityLabel(L("Remove the music")).accessibilityIdentifier("animate-music-remove")
                }
            } else {
                Button { pickingMusic = true } label: {
                    Label(L("Add music"), systemImage: "music.note.list").frame(maxWidth: .infinity)
                }.secondaryButton().accessibilityIdentifier("animate-add-music")
                Text(L("Pick a song from your phone — the photos change on its beat.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            if let note { Text(L(note)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private func musicLine(_ m: MusicTrack.Pick) -> String {
        var parts: [String] = []
        if !m.song.artist.isEmpty { parts.append(m.song.artist) }
        if m.start > 1 { parts.append("\(L("starts at")) \(SocialPost.clock(m.start))") }
        if let b = m.beat { parts.append("\(Int((60 / b).rounded())) \(L("beats a minute — photos change on the beat"))") }
        return parts.joined(separator: " · ")
    }

    private var previewBox: some View {
        let ratio = settings.format.size.width / settings.format.size.height
        let tl = Animate.timeline(count: Animate.playCount(photos.count, settings: settings), settings: settings)
        return VStack(spacing: HandySpacing.s4) {
            ZStack {
                RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).fill(Color.black)
                if previewURL != nil {
                    VideoPlayer(player: player).disabled(true)
                } else if let still = Animate.still(animPhotos, settings: settings, at: 0.1) {
                    Image(uiImage: still).resizable().scaledToFit()
                }
                if previewing {
                    BusySpinner().tint(.white).padding(8)
                        .background(.black.opacity(0.4), in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(8)
                }
            }
            .aspectRatio(ratio, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: 360)
            .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            Text("\(L("Live preview")) · \(Int(tl.seconds.rounded())) s · \(photos.count) \(photos.count == 1 ? L("photo") : L("photos"))")
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func styleTile(_ s: Animate.Style) -> some View {
        let enabled = photos.count >= s.minPhotos
        let on = settings.style == s
        return Button { settings.style = s; styleTouched = true } label: {
            VStack(spacing: 4) {
                Image(systemName: s.icon).font(.system(size: 20))
                Text(L(s.title)).font(HandyFont.caption).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .foregroundStyle(on ? HandyColor.accent : HandyColor.textPrimary)
            .background(on ? HandyColor.accent.opacity(0.15) : HandyColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(on ? HandyColor.accent : HandyColor.border, lineWidth: 1))
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityHint(enabled ? L(s.blurb) : L("Needs two or more photos"))
    }

    private func section(_ title: String) -> some View {
        Text(L(title)).font(HandyFont.bodyStrong)
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(spacing: HandySpacing.s12) {
            Label("\(L("Ready")) — \(L(settings.format.name)), \(Int(settings.format.size.width))×\(Int(settings.format.size.height))",
                  systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            if choosingPlace {
                Text(L("Where will you post it?")).font(HandyFont.bodyStrong).frame(maxWidth: .infinity, alignment: .leading)
                PlatformGrid(selected: $postTo)
                Button(L("Done")) { choosingPlace = false }.secondaryButton()
            } else {
                PostReadyCard(source: url, platform: SocialPost.platform(postTo) ?? SocialPost.platforms[0],
                              another: { choosingPlace = true })
                    .id("\(url.lastPathComponent)-\(postTo)")
            }
            if let note { Text(L(note)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading) }
            if let g = gifURL {
                ShareLink(item: g) {
                    Label(L("Save or share GIF"), systemImage: "photo.stack").frame(maxWidth: .infinity)
                }.secondaryButton()
            } else {
                Button { makeGIF(from: url) } label: {
                    Label(makingGIF ? L("Making GIF…") : L("Also make a GIF (for chats)"), systemImage: "photo.stack").frame(maxWidth: .infinity)
                }.secondaryButton().disabled(makingGIF)
            }
            if let p = printURL {
                ShareLink(item: p) { Label(L("Save or print the flipbook"), systemImage: "printer").frame(maxWidth: .infinity) }.secondaryButton()
            } else {
                Button { makePrintable() } label: {
                    Label(L("Print it as a paper flipbook"), systemImage: "book.pages").frame(maxWidth: .infinity)
                }.secondaryButton()
            }
            Button(L("Try another style")) { resultURL = nil; gifURL = nil; printURL = nil; choosingPlace = false; schedulePreview() }.textButton().font(HandyFont.caption)
        }
    }

    // MARK: - Actions

    private func load(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        loading = true; errorText = nil
        Task {
            var imgs: [UIImage] = []
            for item in items.prefix(Self.maxPhotos) {
                if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    imgs.append(img.resized(maxDimension: 1440).normalizedUp())
                }
            }
            await MainActor.run {
                loading = false
                guard !imgs.isEmpty else { errorText = "Couldn't open those photos — try others."; return }
                if imgs.count < items.count { errorText = "Some photos couldn't be opened." }
                photos = imgs
                if !styleTouched || photos.count < settings.style.minPhotos {
                    settings.style = Animate.suggestedStyle(count: photos.count)
                }
                resultURL = nil
                if look == .original { schedulePreview() } else { restyle() }
            }
        }
    }

    /// Use photos handed in from elsewhere (same as picking them here).
    private func adopt(_ imgs: [UIImage]) {
        guard !imgs.isEmpty else { return }
        photos = imgs; errorText = nil; resultURL = nil
        if !styleTouched || photos.count < settings.style.minPhotos { settings.style = Animate.suggestedStyle(count: photos.count) }
        if look == .original { schedulePreview() } else { restyle() }
    }

    /// Re-render a quick, low-res draft whenever something changes (debounced), and loop it.
    private func schedulePreview() {
        previewTask?.cancel()
        guard !photos.isEmpty, resultURL == nil else { return }
        let imgs = animPhotos, s = settings
        previewing = true
        previewTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            let url = await Task.detached(priority: .userInitiated) {
                await Animate.render(imgs, settings: s, scale: 0.4, fps: 24)
            }.value
            if Task.isCancelled { if let url { try? FileManager.default.removeItem(at: url) }; return }
            await MainActor.run {
                previewing = false
                if let old = previewURL { try? FileManager.default.removeItem(at: old) }
                previewURL = url
                if let url {
                    player.replaceCurrentItem(with: AVPlayerItem(url: url))
                    player.isMuted = true
                    player.play()
                    startMusic()
                }
            }
        }
    }

    private func make() {
        guard !photos.isEmpty else { return }
        previewTask?.cancel(); player.pause(); musicPlayer.pause()
        working = true; errorText = nil; progress = 0; note = nil; stage = ""
        let imgs = animPhotos, s = settings, song = music
        Task {
            var url = await Task.detached(priority: .userInitiated) {
                await Animate.render(imgs, settings: s) { p in Task { @MainActor in progress = p * (song == nil ? 1 : 0.92) } }
            }.value
            if let silent = url, let song {
                await MainActor.run { stage = "Adding your song…"; progress = 0.94 }
                if let withSong = await MusicTrack.addMusic(song, to: silent) {
                    try? FileManager.default.removeItem(at: silent)
                    url = withSong
                } else {
                    await MainActor.run { note = "The song couldn't be added, so this one is without it — try another song." }
                }
            }
            await MainActor.run {
                stage = ""
                working = false
                guard let url else { errorText = "Couldn't make the video — try again, or fewer photos."; return }
                let named = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Tenzy \(s.style.title) \(s.format.ratio.replacingOccurrences(of: ":", with: "x")).mp4")
                try? FileManager.default.removeItem(at: named)
                let final = (try? FileManager.default.moveItem(at: url, to: named)) != nil ? named : url
                resultURL = final
                player.replaceCurrentItem(with: nil)
                HandyHaptics.success()
            }
        }
    }

    /// The photos with the chosen look applied (drawn once, reused by preview and render).
    private var animPhotos: [UIImage] { look == .original || styledPhotos.count != photos.count ? photos : styledPhotos }

    private func restyle() {
        resultURL = nil; gifURL = nil; printURL = nil
        guard look != .original, !photos.isEmpty else { styledPhotos = []; schedulePreview(); return }
        let src = photos, l = look
        previewing = true
        Task {
            let out = await Task.detached(priority: .userInitiated) { Animate.applyLook(l, to: src) }.value
            await MainActor.run { if look == l { styledPhotos = out; schedulePreview() } }
        }
    }

    private func makePrintable() {
        let imgs = animPhotos, s = settings
        Task {
            let data = await Task.detached(priority: .userInitiated) { Animate.flipbookPDF(imgs, settings: s) }.value
            await MainActor.run {
                guard let data else { errorText = "Couldn't make the printable flipbook."; return }
                let u = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy flipbook to print.pdf")
                try? FileManager.default.removeItem(at: u)
                if (try? data.write(to: u)) != nil { printURL = u; HandyHaptics.success() }
            }
        }
    }

    /// A small looping GIF of the finished video — chats and email show GIFs where they won't play video.
    private func makeGIF(from url: URL) {
        makingGIF = true
        let s = settings
        Task {
            let secs = await VideoEngine.duration(url)
            let g = await tenzyGIFFromVideo(url: url, start: 0, duration: min(max(1, secs), 12), fps: 12, speed: 1,
                                            maxDim: s.format.size.width >= s.format.size.height ? 640 : 540)
            await MainActor.run {
                makingGIF = false
                if let g { gifURL = g; HandyHaptics.success() } else { errorText = "Couldn't make the GIF — the video is still ready above." }
            }
        }
    }

    /// A song was picked: find its beat and its liveliest part, then the preview plays with it.
    private func useSong(_ song: MusicTrack.Song) {
        readingSong = true; note = nil
        let length = Animate.timeline(count: Animate.playCount(photos.count, settings: settings), settings: settings).seconds
        Task {
            let pick = await MusicTrack.prepare(song, videoLength: length)
            await MainActor.run {
                readingSong = false
                guard let pick else { note = "That song couldn't be read — try another."; return }
                music = pick
                if pick.beat == nil { note = "No steady beat in this song, so the photos keep their own pace." }
                musicPlayer.replaceCurrentItem(with: AVPlayerItem(url: pick.file))
                if settings.beat != pick.beat { settings.beat = pick.beat } else { schedulePreview() }
            }
        }
    }

    private func removeMusic() {
        musicPlayer.pause(); musicPlayer.replaceCurrentItem(with: nil)
        music = nil; note = nil
        settings.beat = nil
    }

    /// Play the song from its start point alongside the preview (they loop together).
    private func startMusic() {
        guard let m = music, resultURL == nil else { musicPlayer.pause(); return }
        if musicPlayer.currentItem == nil { musicPlayer.replaceCurrentItem(with: AVPlayerItem(url: m.file)) }
        musicPlayer.seek(to: CMTime(seconds: m.start, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        musicPlayer.play()
    }

    private func reset() {
        previewTask?.cancel(); player.pause()
        photos = []; picks = []; previewURL = nil; resultURL = nil; errorText = nil; styleTouched = false
        styledPhotos = []; look = .original; gifURL = nil; printURL = nil
        musicPlayer.pause(); music = nil; note = nil; choosingPlace = false; postTo = "tiktok"
        settings = Animate.Settings()
    }
}
