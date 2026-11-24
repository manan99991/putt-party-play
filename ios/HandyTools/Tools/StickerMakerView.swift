import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers

/// The sticker work that isn't UI: cut out, and save to Photos as a real see-through PNG.
enum StickerMaker {
    /// Photo → the subject on transparency. Nil when no subject is found.
    static func cutout(_ photo: UIImage) -> UIImage? { ImageStudio.cutout(photo.normalizedUp()) }

    /// Legacy one-shot sticker (white edge) — kept for the Build-your-own step and tests.
    static func make(_ photo: UIImage) -> (image: UIImage, png: Data)? {
        guard let cut = cutout(photo), let s = ChainFun.sticker(cut), let png = s.pngData() else { return nil }
        return (s, png)
    }

    /// Save PNGs (keeps the transparency — a JPEG would put it on a white box).
    static func saveToPhotos(_ pngs: [Data]) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for png in pngs { PHAssetCreationRequest.forAsset().addResource(with: .photo, data: png, options: nil) }
            }
            return true
        } catch { return false }
    }
}

/// Sticker Maker — a sticker studio. Pick one photo or a dozen; Tenzy cuts out each subject and shows ten
/// designed sticker styles live on YOUR photo, still or animated (nine moves: StickerMotion) (Classic, Comic, Neon, Holographic, Badge, Pop burst,
/// Retro, Sketch, Noir, Clean). Tap one, then fine-tune anything: the look, edge, edge colour, glow,
/// shadow, a badge/tile/starburst behind it, a caption, sparkles. Copy into any chat, save the whole pack
/// to Photos and add them to the iPhone's sticker drawer, or print a sticker sheet. On device.
struct StickerMakerView: View {
    @State private var picks: [PhotosPickerItem] = []
    @State private var subjects: [UIImage] = []          // cut-outs
    @State private var current = 0
    @State private var style = StickerStudio.presets[0].style
    @State private var thumbs: [String: UIImage] = [:]
    @State private var preview: UIImage?
    @State private var renderTask: Task<Void, Never>?
    @State private var cutting = false
    @State private var cutProgress: Double = 0
    @State private var working = false
    @State private var fineTune = false
    @State private var saved = false
    @State private var copied = false
    @State private var sheetURL: URL?
    @State private var errorText: String?
    @State private var note: String?
    /// Still or animated (Manan, 24 Nov: "can they be animated too — give them both"). The style is the look; the move
    /// is what it does.
    @State private var animated = false
    @State private var motion: StickerMotion = .bounce
    @State private var moving: UIImage?                 // the big preview, playing
    @State private var movingFrames: [UIImage] = []
    @State private var motionThumbs: [String: UIImage] = [:]
    @State private var motionTask: Task<Void, Never>?
    @State private var gifShare: Data?

    var body: some View {
        ToolPage(title: "Sticker Maker", subtitle: "Turn photos into designed stickers for Messages, WhatsApp and more.", working: cutting || working) {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                if subjects.isEmpty { pickCard } else { studio }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .onChange(of: picks) { _, items in load(items) }
        .onChange(of: style) { _, _ in rerender(); resetActions() }
        .onChange(of: current) { _, _ in rerender(thumbsToo: true); resetActions() }
        .onChange(of: preview) { _, _ in rerenderMotion(thumbsToo: true) }
        .onChange(of: motion) { _, _ in rerenderMotion(); resetActions() }
        .onChange(of: animated) { _, on in resetActions(); if on { rerenderMotion(thumbsToo: true) } }
        .handoffPhotos("sticker") { imgs in cut(Array(imgs.prefix(12))) }
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Text("✂️").font(.system(size: 52))
            Text(L("Pick one photo or a few — people, pets, food, anything. Tenzy cuts them out and shows you ten sticker styles to choose from."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            SmartPhotoButton(kind: .any, max: 12, picked: { imgs in cut(Array(imgs.prefix(12))) }) {
                Label(L("Choose photos"), systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
            }.primaryButton()
            if cutting { ToolProgressBar(value: cutProgress, label: "Cutting out your stickers…") }
            if let n = note { Text(L(n)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Studio

    private var studio: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            ZStack {
                Checkerboard().clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                if animated {
                    if let m = moving { PlayingImage(image: m).padding(HandySpacing.s8).accessibilityLabel("\(L("Animated sticker")): \(L(motion.title))") }
                    else { BusySpinner() }
                } else if let p = preview { Image(uiImage: p).resizable().scaledToFit().padding(HandySpacing.s12).opensFullSize(p) }
                else { BusySpinner() }
            }
            .frame(maxWidth: .infinity).frame(height: 320)

            Picker(L("Kind"), selection: $animated) {
                Label(L("Still"), systemImage: "photo").tag(false)
                Label(L("Animated"), systemImage: "sparkles.rectangle.stack").tag(true)
            }
            .pickerStyle(.segmented).accessibilityIdentifier("sticker-kind")

            if animated { motionPicker }

            if subjects.count > 1 {
                HandyFlow(spacing: HandySpacing.s8) {
                        ForEach(subjects.indices, id: \.self) { i in
                            Button { current = i } label: {
                                Image(uiImage: subjects[i]).resizable().scaledToFit().frame(width: 52, height: 52)
                                    .padding(4)
                                    .background(current == i ? HandyColor.accent.opacity(0.18) : HandyColor.surface, in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(current == i ? HandyColor.accent : Color.clear, lineWidth: 2))
                            }.buttonStyle(.plain).accessibilityLabel("\(L("Sticker")) \(i + 1)")
                        }
                    }
                Text(L("Your style applies to the whole pack.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }

            Text(L("Style")).font(HandyFont.bodyStrong)
            HandyFlow(spacing: HandySpacing.s8) {
                    ForEach(StickerStudio.presets) { p in
                        Button { style = keepCaption(p.style) } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Checkerboard()
                                    if let t = thumbs[p.id] { Image(uiImage: t).resizable().scaledToFit().padding(6) } else { BusySpinner() }
                                }
                                .frame(width: 92, height: 92)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isOn(p) ? HandyColor.accent : HandyColor.border, lineWidth: isOn(p) ? 3 : 1))
                                Text(L(p.name)).font(HandyFont.caption).foregroundStyle(isOn(p) ? HandyColor.accent : HandyColor.textPrimary)
                            }
                        }.buttonStyle(.plain)
                    }
                }

            TextField(L("Add words (optional) — e.g. LOL, Yay, Miss you"), text: Binding(get: { style.caption }, set: { style.caption = String($0.prefix(24)) }))
                .textFieldStyle(.handy)

            DisclosureGroup(isExpanded: $fineTune) { fineTunePanel } label: {
                Label(L("Fine-tune"), systemImage: "slider.horizontal.3").font(HandyFont.bodyStrong)
            }

            actions
        }
    }

    /// The moves, each playing on your own sticker, three across.
    private var motionPicker: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Move")).font(HandyFont.bodyStrong)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: HandySpacing.s8), count: 3), spacing: HandySpacing.s8) {
                ForEach(StickerMotion.allCases) { m in
                    let on = m == motion
                    Button { motion = m } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Checkerboard()
                                if let t = motionThumbs[m.id] { PlayingImage(image: t).padding(4) }
                                else { Image(systemName: m.icon).font(.system(size: 22, weight: .bold)).foregroundStyle(HandyColor.accent) }
                            }
                            .frame(height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(on ? HandyColor.accent : HandyColor.border, lineWidth: on ? 3 : 1))
                            Label(L(m.title), systemImage: m.icon).font(HandyFont.caption.weight(on ? .bold : .regular))
                                .foregroundStyle(on ? HandyColor.accent : HandyColor.textPrimary).lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("motion-\(m.id)")
                    .accessibilityLabel(L(m.title))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var fineTunePanel: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            chips("Look", StickerStudio.Look.allCases, selected: style.look, name: { $0.title }) { style.look = $0 }
            chips("Edge", StickerStudio.Edge.allCases, selected: style.edge, name: { $0.title }) { style.edge = $0 }
            swatches("Edge colour", selected: style.edgeColor) { style.edgeColor = $0 }
            chips("Behind it", StickerStudio.Backdrop.allCases, selected: style.backdrop, name: { $0.title }) { style.backdrop = $0 }
            if style.backdrop != .none { swatches("Backdrop colour", selected: style.backdropColor, rainbow: false) { style.backdropColor = $0 } }
            Toggle(L("Comic outline"), isOn: $style.outline).tint(HandyColor.accent)
            Toggle(L("Neon glow"), isOn: $style.glow).tint(HandyColor.accent)
            Toggle(L("Drop shadow"), isOn: $style.shadow).tint(HandyColor.accent)
            Toggle(L("Sparkles"), isOn: $style.sparkles).tint(HandyColor.accent)
        }
        .font(HandyFont.body)
        .padding(.top, HandySpacing.s8)
    }

    private func chips<T: Hashable>(_ title: String, _ all: [T], selected: T, name: @escaping (T) -> String,
                                    set: @escaping (T) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L(title)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(all, id: \.self) { v in HChip(text: L(name(v)), selected: v == selected) { set(v) } }
            }
        }
    }

    private func swatches(_ title: String, selected: StickerStudio.EdgeColor, rainbow: Bool = true,
                          set: @escaping (StickerStudio.EdgeColor) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L(title)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HStack(spacing: HandySpacing.s8) {
                ForEach(StickerStudio.EdgeColor.allCases.filter { rainbow || $0 != .rainbow }) { c in
                    Button { set(c) } label: {
                        Group {
                            if c == .rainbow {
                                Circle().fill(AngularGradient(colors: [.pink, .yellow, .mint, .blue, .purple, .pink], center: .center))
                            } else { Circle().fill(Color(c.color)) }
                        }
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(selected == c ? HandyColor.accent : HandyColor.border, lineWidth: selected == c ? 3 : 1))
                    }
                    .buttonStyle(.plain).frame(width: 40, height: 44)
                    .accessibilityLabel(L(c.rawValue.capitalized)).accessibilityAddTraits(selected == c ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder private var actions: some View {
        if animated { animatedActions } else { stillActions }
    }

    /// Animated: copy it (plays in Messages), save the pack to Photos as GIFs, or share the GIF.
    private var animatedActions: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Button { copyMoving() } label: {
                Label(copied ? L("Copied — paste it into any chat") : L("Copy animated sticker"), systemImage: copied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }.primaryButton().disabled(movingFrames.isEmpty).accessibilityIdentifier("sticker-copy-animated")
            Button { saveAllMoving() } label: {
                Label(saved ? L("Saved to Photos") : (subjects.count > 1 ? "\(L("Save all to Photos")) (\(subjects.count))" : L("Save to Photos")),
                      systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down").frame(maxWidth: .infinity)
            }.secondaryButton().disabled(working || saved || movingFrames.isEmpty)
            if working { ToolProgressBar(label: "Making your animated stickers…", showsTime: false) }
            HStack(spacing: HandySpacing.s8) {
                if let g = gifShare, let m = moving {
                    ShareLink(item: GIFFile(data: g), preview: SharePreview("Sticker", image: Image(uiImage: m.images?.first ?? m))) { Label(L("Share"), systemImage: "square.and.arrow.up") }.compactButton()
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Label(L("Where it plays"), systemImage: "play.circle").font(HandyFont.bodyStrong)
                step(1, "Tap Copy, then paste it into Messages — it plays there, with its soft see-through edge.")
                step(2, "WhatsApp, Instagram and others: paste or share it — it sends as a moving GIF.")
                step(3, "Saved to Photos, it's in the Animated album, ready to send any time.")
            }
            .cardStyle(padding: HandySpacing.s12)
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let n = note { Text(L(n)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            SmartPhotoButton(kind: .any, max: 12, picked: { imgs in cut(Array(imgs.prefix(12))) }) { Label(L("Make more"), systemImage: "photo") }
                .textButton().font(HandyFont.caption).frame(maxWidth: .infinity)
        }
    }

    private var stillActions: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Button { copyCurrent() } label: {
                Label(copied ? L("Copied — paste it into any chat") : L("Copy sticker"), systemImage: copied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }.primaryButton().disabled(preview == nil)
            Button { saveAll() } label: {
                Label(saved ? L("Saved to Photos") : (subjects.count > 1 ? "\(L("Save all to Photos")) (\(subjects.count))" : L("Save to Photos")),
                      systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down").frame(maxWidth: .infinity)
            }.secondaryButton().disabled(working || saved)
            if working { ToolProgressBar(label: "Finishing your stickers…", showsTime: false) }

            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Label(L("Keep them in your sticker drawer"), systemImage: "face.smiling").font(HandyFont.bodyStrong)
                step(1, saved ? "Open Photos and tap a sticker (they're your newest photos)." : "Tap Save to Photos above, then open Photos and tap a sticker.")
                step(2, "Touch and hold the sticker, then tap Add Sticker.")
                step(3, "It's now in your stickers — in Messages, WhatsApp and any app, from the emoji keyboard.")
            }
            .cardStyle(padding: HandySpacing.s12)

            HStack(spacing: HandySpacing.s8) {
                if let s = sheetURL {
                    ShareLink(item: s) { Label(L("Print sticker sheet"), systemImage: "printer") }.compactButton()
                } else {
                    Button { makeSheet() } label: { Label(L("Sticker sheet to print"), systemImage: "printer") }.compactButton().disabled(working)
                }
                if let p = preview, let d = p.pngData() {
                    ShareLink(item: PNGFile(data: d), preview: SharePreview("Sticker", image: Image(uiImage: p))) { Label(L("Share"), systemImage: "square.and.arrow.up") }.compactButton()
                }
                Spacer()
            }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let n = note { Text(L(n)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            SmartPhotoButton(kind: .any, max: 12, picked: { imgs in cut(Array(imgs.prefix(12))) }) { Label(L("Make more"), systemImage: "photo") }
                .textButton().font(HandyFont.caption).frame(maxWidth: .infinity)
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HandySpacing.s8) {
            Text("\(n)").font(HandyFont.caption.weight(.bold)).foregroundStyle(.white)
                .frame(width: 22, height: 22).background(HandyColor.accent, in: Circle())
            Text(L(text)).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func keepCaption(_ s: StickerStudio.Style) -> StickerStudio.Style { var x = s; x.caption = style.caption; return x }
    /// A preset stays highlighted only while the style still matches it (fine-tuning un-highlights it).
    private func isOn(_ p: StickerStudio.Preset) -> Bool { keepCaption(p.style) == style }
    private func resetActions() { saved = false; copied = false; sheetURL = nil }

    /// Play the chosen move on the sticker as it looks now (and, when the look changed, every move's small preview).
    private func rerenderMotion(thumbsToo: Bool = false) {
        guard animated, let still = preview else { return }
        motionTask?.cancel()
        let m = motion
        if thumbsToo { motionThumbs = [:] }
        motionTask = Task {
            let frames = await Task.detached(priority: .userInitiated) { StickerMotion.frames(still, motion: m) }.value
            if Task.isCancelled { return }
            let loop = Double(frames.count) * StickerMotion.delay
            await MainActor.run {
                movingFrames = frames
                moving = UIImage.animatedImage(with: frames, duration: loop)
                gifShare = nil
            }
            let gif = await Task.detached(priority: .utility) { StickerMotion.gif(frames) }.value
            if Task.isCancelled { return }
            await MainActor.run { gifShare = gif }
            guard thumbsToo else { return }
            let small = still.resized(maxDimension: 220)
            for mm in StickerMotion.allCases {
                if Task.isCancelled { return }
                let t = await Task.detached(priority: .utility) { StickerMotion.frames(small, motion: mm, side: 140) }.value
                await MainActor.run { motionThumbs[mm.id] = UIImage.animatedImage(with: t, duration: Double(t.count) * StickerMotion.delay) }
            }
        }
    }

    /// Both kinds go on the clipboard: an animated PNG (Messages plays it, soft edge kept) and a GIF for every other app.
    private func copyMoving() {
        let frames = movingFrames
        guard !frames.isEmpty else { return }
        Task {
            let made = await Task.detached(priority: .userInitiated) { (StickerMotion.apng(frames), StickerMotion.gif(frames)) }.value
            await MainActor.run {
                var item: [String: Any] = [:]
                if let a = made.0 { item[UTType.png.identifier] = a }
                if let g = made.1 { item[UTType.gif.identifier] = g }
                guard !item.isEmpty else { errorText = "Couldn't make the animated sticker. Try another move."; return }
                UIPasteboard.general.setItems([item])
                copied = true; HandyHaptics.success()
            }
        }
    }

    /// Every sticker in the pack, moving the same way, saved to Photos as GIFs (Photos plays GIFs in its Animated album).
    private func saveAllMoving() {
        working = true; errorText = nil
        let m = motion
        Task {
            let pack = await renderPack()
            let gifs = await Task.detached(priority: .userInitiated) { pack.compactMap { StickerMotion.gif(StickerMotion.frames($0, motion: m)) } }.value
            var ok = false
            if !gifs.isEmpty { ok = await StickerMaker.saveToPhotos(gifs) }
            await MainActor.run {
                working = false
                if ok { saved = true; HandyHaptics.success() }
                else { errorText = "Tenzy needs permission to add to Photos — allow it in Settings → Privacy → Photos → Tenzy, or use Copy." }
            }
        }
    }

    private func load(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var raws: [UIImage] = []
            for item in items.prefix(12) {
                if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { raws.append(img) }
            }
            await MainActor.run {
                picks = []      // so picking the same photos again still works
                if raws.isEmpty { errorText = "Couldn't open those photos — try others." } else { cut(raws) }
            }
        }
    }

    /// Cut out every photo (with progress), keep the ones with a clear subject, say honestly if some had none.
    private func cut(_ raws: [UIImage]) {
        cutting = true; cutProgress = 0; errorText = nil; note = nil; resetActions()
        Task {
            var found: [UIImage] = []
            for (i, r) in raws.enumerated() {
                let src = r.resized(maxDimension: 2000)
                if let c = await Task.detached(priority: .userInitiated, operation: { StickerMaker.cutout(src).flatMap(StickerStudio.trim) }).value {
                    found.append(c)
                }
                await MainActor.run { cutProgress = Double(i + 1) / Double(raws.count) }
            }
            await MainActor.run {
                cutting = false
                guard !found.isEmpty else {
                    errorText = "Couldn't find a person, pet or thing to cut out. Try a photo where it stands clear of the background."
                    return
                }
                if found.count < raws.count { note = "\(raws.count - found.count) \(L("photo(s) skipped — no clear subject found."))" }
                subjects = found; current = 0; preview = nil
                rerender(thumbsToo: true)
                HandyHaptics.success()
            }
        }
    }

    /// Redraw the big preview (debounced) and, when the subject changes, the style gallery.
    private func rerender(thumbsToo: Bool = false) {
        guard subjects.indices.contains(current) else { return }
        renderTask?.cancel()
        let subj = subjects[current], s = style
        if thumbsToo { thumbs = [:] }
        renderTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            if Task.isCancelled { return }
            let big = await Task.detached(priority: .userInitiated) { StickerStudio.render(subj, style: s, side: 700) }.value
            if Task.isCancelled { return }
            await MainActor.run { preview = big }
            guard thumbsToo else { return }
            for p in StickerStudio.presets {
                if Task.isCancelled { return }
                var ps = p.style; ps.caption = s.caption
                let t = await Task.detached(priority: .utility) { StickerStudio.render(subj, style: ps, side: 180) }.value
                await MainActor.run { thumbs[p.id] = t }
            }
        }
    }

    private func copyCurrent() {
        guard let p = preview, let d = p.pngData() else { return }
        UIPasteboard.general.setData(d, forPasteboardType: UTType.png.identifier)
        copied = true; HandyHaptics.success()
    }

    /// Full-size (1024) render of every sticker in the pack.
    private func renderPack() async -> [UIImage] {
        let subs = subjects, s = style
        return await Task.detached(priority: .userInitiated) { subs.compactMap { StickerStudio.render($0, style: s, side: 1024) } }.value
    }

    private func saveAll() {
        working = true; errorText = nil
        Task {
            let pack = await renderPack()
            let ok = await StickerMaker.saveToPhotos(pack.compactMap { $0.pngData() })
            await MainActor.run {
                working = false
                if ok { saved = true; HandyHaptics.success() }
                else { errorText = "Tenzy needs permission to add to Photos — allow it in Settings → Privacy → Photos → Tenzy, or use Copy." }
            }
        }
    }

    private func makeSheet() {
        working = true
        Task {
            let pack = await renderPack()
            let data = await Task.detached(priority: .userInitiated) { StickerStudio.sheetPDF(pack) }.value
            await MainActor.run {
                working = false
                guard let data else { errorText = "Couldn't make the sticker sheet."; return }
                let u = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy sticker sheet.pdf")
                try? FileManager.default.removeItem(at: u)
                if (try? data.write(to: u)) != nil { sheetURL = u; HandyHaptics.success() }
            }
        }
    }
}

/// A looping animated picture (an animated sticker). SwiftUI's Image shows only the first frame of one.
struct PlayingImage: UIViewRepresentable {
    let image: UIImage
    func makeUIView(context: Context) -> UIImageView {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.clipsToBounds = true
        for axis in [NSLayoutConstraint.Axis.vertical, .horizontal] {
            v.setContentHuggingPriority(.defaultLow, for: axis)
            v.setContentCompressionResistancePriority(.defaultLow, for: axis)
        }
        v.image = image
        v.startAnimating()
        return v
    }
    func updateUIView(_ v: UIImageView, context: Context) {
        if v.image !== image { v.image = image; v.startAnimating() }
    }
}
