import SwiftUI
import PhotosUI

/// Comic Strip — pick 1 to 4 photos; each becomes an inked comic panel with a speech bubble you type,
/// framed like a newspaper strip, with an optional title. Square, Portrait or Story sized. On device.
struct ComicStripView: View {
    @State private var picks: [PhotosPickerItem] = []
    @State private var panels: [UIImage] = []           // already inked
    @State private var words: [String] = []
    @State private var title = ""
    @State private var format: VideoFormat.Spec = VideoFormat.preset("portrait") ?? VideoFormat.presets[0]
    @State private var preview: UIImage?
    @State private var inking = false
    @State private var working = false
    @State private var resultURL: URL?
    @State private var errorText: String?

    private var formats: [VideoFormat.Spec] { VideoFormat.presets.filter { ["square", "portrait", "story"].contains($0.id) } }

    var body: some View {
        ToolPage(title: "Comic Strip", subtitle: "Photos into inked comic panels with speech bubbles.", working: inking || working) {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                if panels.isEmpty { pickCard } else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .onChange(of: picks) { _, items in load(items) }
        .handoffPhotos("comicstrip") { imgs in ink(imgs.prefix(4).map { $0.resized(maxDimension: 1400).normalizedUp() }) }
    }

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Text("💥").font(.system(size: 52))
            Text(L("Pick 1 to 4 photos. Tenzy inks them like a comic and you add what everyone's saying."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            PhotosPicker(selection: $picks, maxSelectionCount: 4, matching: .images) {
                Label(L("Choose photos"), systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
            }.primaryButton()
            if inking { ToolProgressBar(label: "Inking your panels…", showsTime: false) }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
        .frame(maxWidth: .infinity)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            ZStack {
                RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).fill(Color.white)
                if let p = preview { Image(uiImage: p).resizable().scaledToFit().opensFullSize(p) }
            }
            .aspectRatio(format.size.width / format.size.height, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: 420)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(formats) { f in HChip(text: "\(f.name) · \(f.ratio)", selected: format == f) { format = f } }
            }
            TextField(L("Title (optional)"), text: $title).textFieldStyle(.handy)
            ForEach(words.indices, id: \.self) { i in
                TextField("\(L("Panel")) \(i + 1) — \(L("what are they saying?"))",
                          text: Binding(get: { words[i] }, set: { words[i] = String($0.prefix(90)) }))
                    .textFieldStyle(.handy)
            }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let url = resultURL {
                KeepShare(url, tool: "Comic strip")
            } else {
                Button { make() } label: { Label(L("Make comic"), systemImage: "checkmark").frame(maxWidth: .infinity) }
                    .primaryButton().disabled(working)
            }
            PhotosPicker(selection: $picks, maxSelectionCount: 4, matching: .images) { Label(L("Choose different photos"), systemImage: "photo") }
                .textButton().font(HandyFont.caption).frame(maxWidth: .infinity)
        }
        .onChange(of: words) { _, _ in refresh() }
        .onChange(of: title) { _, _ in refresh() }
        .onChange(of: format) { _, _ in refresh() }
    }

    private func load(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        inking = true; errorText = nil; resultURL = nil
        Task {
            var raw: [UIImage] = []
            for item in items.prefix(4) {
                if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { raw.append(img.resized(maxDimension: 1400).normalizedUp()) }
            }
            await MainActor.run { ink(raw) }
        }
    }

    /// Ink the photos into panels (shared by picking here and a hand-off).
    private func ink(_ raw: [UIImage]) {
        inking = true; errorText = nil; resultURL = nil
        Task {
            let inked: [UIImage] = await Task.detached(priority: .userInitiated) {
                raw.compactMap { ChainFun.art($0, style: "comic", long: 1100) }
            }.value
            await MainActor.run {
                inking = false
                guard !inked.isEmpty else { errorText = "Couldn't open those photos — try others."; return }
                panels = inked
                words = Array(repeating: "", count: inked.count)
                refresh()
            }
        }
    }

    private func refresh() {
        resultURL = nil
        guard !panels.isEmpty else { return }
        preview = ComicStrip.render(panels: panels, words: words, title: title,
                                    canvas: CGSize(width: format.size.width / 2, height: format.size.height / 2))
    }

    private func make() {
        working = true
        let p = panels, w = words, t = title, size = format.size
        Task {
            let url: URL? = await Task.detached(priority: .userInitiated) {
                let img = ComicStrip.render(panels: p, words: w, title: t, canvas: size)
                guard let d = img.jpegData(compressionQuality: 0.92) else { return nil }
                let u = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy comic.jpg")
                try? FileManager.default.removeItem(at: u)
                return (try? d.write(to: u)) != nil ? u : nil
            }.value
            await MainActor.run {
                working = false
                if let url { resultURL = url; HandyHaptics.success() } else { errorText = "Couldn't save the comic — try again." }
            }
        }
    }
}
