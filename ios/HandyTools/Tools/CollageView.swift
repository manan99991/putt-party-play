import SwiftUI
import PhotosUI

/// Collage — pick photos, choose a layout and where it's going (Story, Square, Portrait, wide), tune
/// the spacing, corners and background, and watch the collage update live. Saves full-size (1080-class)
/// ready to post. On device.
struct CollageView: View {
    @State private var photos: [UIImage] = []
    @State private var picks: [PhotosPickerItem] = []
    @State private var loading = false
    @State private var layout: CollageLayout = .grid
    @State private var format: VideoFormat.Spec = VideoFormat.preset("portrait") ?? VideoFormat.presets[0]
    @State private var gap: Double = 0.015
    @State private var corner: Double = 0.02
    @State private var bgIndex = 0
    @State private var preview: UIImage?
    @State private var resultURL: URL?
    @State private var working = false
    @State private var errorText: String?

    private let backgrounds: [(String, UIColor)] = [("White", .white), ("Black", .black),
                                                    ("Cream", UIColor(red: 0.97, green: 0.94, blue: 0.88, alpha: 1)),
                                                    ("Blush", UIColor(red: 0.98, green: 0.88, blue: 0.88, alpha: 1)),
                                                    ("Sage", UIColor(red: 0.83, green: 0.88, blue: 0.80, alpha: 1))]
    private var formats: [VideoFormat.Spec] { VideoFormat.presets.filter { $0.id != "reels" } }

    var body: some View {
        ToolPage(title: "Collage", subtitle: "Photos into one designed picture — sized for Stories, posts or wide.", working: working) {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                if photos.isEmpty { pickCard } else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .onChange(of: picks) { _, items in load(items) }
        .handoffPhotos("collage") { imgs in
            let p = imgs.prefix(12).map { $0.resized(maxDimension: 1600).normalizedUp() }
            photos = p; layout = p.count >= 5 ? .mosaic : (p.count == 3 ? .hero : .grid); refresh()
        }
    }

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "square.grid.3x3.square").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Pick 2 to 12 photos — Grid, Hero, Mosaic or a photo strip, ready for Stories or a post."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            PhotosPicker(selection: $picks, maxSelectionCount: 12, matching: .images) {
                Label(L("Choose photos"), systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
            }.primaryButton()
            if loading { ToolProgressBar(label: "Getting your photos…", showsTime: false) }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
        .frame(maxWidth: .infinity)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            ZStack {
                RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).fill(HandyColor.surface)
                if let p = preview { Image(uiImage: p).resizable().scaledToFit() }
            }
            .aspectRatio(format.size.width / format.size.height, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: 380)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HandySpacing.s8) {
                    ForEach(CollageLayout.allCases) { l in
                        Button { layout = l } label: {
                            VStack(spacing: 4) {
                                Image(systemName: l.icon).font(.system(size: 20))
                                Text(L(l.title)).font(HandyFont.caption).lineLimit(1)
                            }
                            .frame(width: 84, height: 60)
                            .foregroundStyle(layout == l ? HandyColor.accent : HandyColor.textPrimary)
                            .background(layout == l ? HandyColor.accent.opacity(0.15) : HandyColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(layout == l ? HandyColor.accent : HandyColor.border, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }
            }
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(formats) { f in HChip(text: "\(f.name) · \(f.ratio)", selected: format == f) { format = f } }
            }
            HStack {
                Text(L("Spacing")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 70, alignment: .leading)
                Slider(value: $gap, in: 0...0.05).tint(HandyColor.accent)
            }
            HStack {
                Text(L("Corners")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 70, alignment: .leading)
                Slider(value: $corner, in: 0...0.08).tint(HandyColor.accent)
            }
            HStack(spacing: HandySpacing.s8) {
                ForEach(backgrounds.indices, id: \.self) { i in
                    Button { bgIndex = i } label: {
                        Circle().fill(Color(backgrounds[i].1)).frame(width: 32, height: 32)
                            .overlay(Circle().stroke(bgIndex == i ? HandyColor.accent : HandyColor.border, lineWidth: bgIndex == i ? 3 : 1))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(L(backgrounds[i].0))
                    .accessibilityAddTraits(bgIndex == i ? .isSelected : [])
                }
            }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let url = resultURL {
                ShareLink(item: url) {
                    Label(L("Save or share collage"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.primaryButton()
            } else {
                Button { make() } label: {
                    Label(L("Make collage"), systemImage: "checkmark").frame(maxWidth: .infinity)
                }.primaryButton().disabled(working)
            }
            PhotosPicker(selection: $picks, maxSelectionCount: 12, matching: .images) {
                Label(L("Choose different photos"), systemImage: "photo.on.rectangle")
            }.textButton().font(HandyFont.caption).frame(maxWidth: .infinity)
        }
        .onChange(of: layout) { _, _ in refresh() }
        .onChange(of: format) { _, _ in refresh() }
        .onChange(of: gap) { _, _ in refresh() }
        .onChange(of: corner) { _, _ in refresh() }
        .onChange(of: bgIndex) { _, _ in refresh() }
    }

    private func load(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        loading = true; errorText = nil
        Task {
            var imgs: [UIImage] = []
            for item in items.prefix(12) {
                if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    imgs.append(img.resized(maxDimension: 1600).normalizedUp())
                }
            }
            await MainActor.run {
                loading = false
                guard !imgs.isEmpty else { errorText = "Couldn't open those photos — try others."; return }
                photos = imgs
                layout = imgs.count >= 5 ? .mosaic : (imgs.count == 3 ? .hero : .grid)
                refresh()
            }
        }
    }

    /// A quick low-res redraw for the live preview.
    private func refresh() {
        resultURL = nil
        guard !photos.isEmpty else { return }
        let small = CGSize(width: format.size.width / 3, height: format.size.height / 3)
        preview = CollageLayout.render(photos, layout: layout, canvas: small, gapRatio: gap, cornerRatio: corner, background: backgrounds[bgIndex].1)
    }

    private func make() {
        working = true; errorText = nil
        let imgs = photos, l = layout, size = format.size, g = gap, c = corner, bg = backgrounds[bgIndex].1, name = format.ratio
        Task {
            let url: URL? = await Task.detached(priority: .userInitiated) {
                let img = CollageLayout.render(imgs, layout: l, canvas: size, gapRatio: g, cornerRatio: c, background: bg)
                guard let data = img.jpegData(compressionQuality: 0.92) else { return nil }
                let u = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Tenzy collage \(name.replacingOccurrences(of: ":", with: "x")).jpg")
                try? FileManager.default.removeItem(at: u)
                return (try? data.write(to: u)) != nil ? u : nil
            }.value
            await MainActor.run {
                working = false
                guard let url else { errorText = "Couldn't save the collage — try again."; return }
                resultURL = url
                HandyHaptics.success()
            }
        }
    }
}
