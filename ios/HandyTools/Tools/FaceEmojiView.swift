import SwiftUI
import PhotosUI

/// One face covered by an emoji (or left showing). Normalized, top-left origin.
struct FaceCover: Identifiable, Equatable {
    let id = UUID()
    var rect: CGRect
    var emoji: String?          // nil = this face stays visible
    var manual = false          // added by tapping, not found by the detector
}

enum FaceEmoji {
    static let palette = ["😀", "😎", "🥳", "😇", "🤡", "🐶", "🐱", "🦄", "👽", "🤖", "🙈", "⭐️", "❤️", "🌸"]

    /// Draw the covers over the photo at full resolution. `scale` grows every emoji (1 = just covers the face).
    static func render(_ image: UIImage, covers: [FaceCover], scale: CGFloat) -> UIImage {
        let base = image.normalizedUp()
        let px = CGSize(width: base.size.width * base.scale, height: base.size.height * base.scale)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: px, format: fmt).image { _ in
            base.draw(in: CGRect(origin: .zero, size: px))
            for c in covers {
                guard let e = c.emoji else { continue }
                let f = CGRect(x: c.rect.minX * px.width, y: c.rect.minY * px.height, width: c.rect.width * px.width, height: c.rect.height * px.height)
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: max(f.width, f.height) * 1.2 * scale)]
                let s = (e as NSString).size(withAttributes: attrs)
                (e as NSString).draw(at: CGPoint(x: f.midX - s.width / 2, y: f.midY - s.height / 2), withAttributes: attrs)
            }
        }
    }
}

/// Face Emoji — every face in a photo gets an emoji, and you decide which: tap a face to cover or uncover
/// it (cover just the kids, or everyone but you), pick a different emoji per face, make them bigger, or
/// tap anywhere to add one where the phone missed a face. The saved photo is a fresh copy with no
/// location or camera details. On device.
struct FaceEmojiView: View {
    @State private var photo: UIImage?
    @State private var pick: PhotosPickerItem?
    @State private var covers: [FaceCover] = []
    @State private var current = FaceEmoji.palette[0]
    @State private var scale: Double = 1.15
    @State private var addMode = false
    @State private var finding = false
    @State private var resultURL: URL?
    @State private var working = false
    @State private var errorText: String?

    var body: some View {
        ToolPage(title: "Face Emoji", subtitle: "Cover faces with emoji — you choose which ones.", working: working || finding) {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                if let img = photo { editor(img) } else { pickCard }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .onChange(of: pick) { _, item in load(item) }
        .handoffPhotos("faceemoji") { imgs in if let img = imgs.first { use(img) } }
    }

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Text("🙈").font(.system(size: 52))
            Text(L("Pick a photo. Tenzy finds the faces — tap to choose which get an emoji. Great for kids' photos before posting."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            PhotosPicker(selection: $pick, matching: .images) {
                Label(L("Choose a photo"), systemImage: "photo").frame(maxWidth: .infinity)
            }.primaryButton()
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
        .frame(maxWidth: .infinity)
    }

    private func editor(_ img: UIImage) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            GeometryReader { g in
                let fit = VideoFormat.fitRect(source: img.size, target: g.size)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: img).resizable().scaledToFit().frame(width: g.size.width, height: g.size.height)
                    ForEach(covers) { c in
                        let r = CGRect(x: fit.minX + c.rect.minX * fit.width, y: fit.minY + c.rect.minY * fit.height,
                                       width: c.rect.width * fit.width, height: c.rect.height * fit.height)
                        Button { tap(c) } label: {
                            ZStack {
                                if let e = c.emoji {
                                    Text(e).font(.system(size: max(r.width, r.height) * 1.2 * scale))
                                } else {
                                    RoundedRectangle(cornerRadius: 6).stroke(Color.white, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                                        .shadow(radius: 2)
                                }
                            }
                            .frame(width: max(r.width, 44), height: max(r.height, 44))
                        }
                        .buttonStyle(.plain)
                        .position(x: r.midX, y: r.midY)
                        .accessibilityLabel(c.emoji == nil ? L("Face showing — tap to cover") : L("Face covered — tap to change"))
                    }
                }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { v in
                    guard addMode, fit.contains(v.location) else { return }
                    add(at: CGPoint(x: (v.location.x - fit.minX) / fit.width, y: (v.location.y - fit.minY) / fit.height))
                })
            }
            .aspectRatio(img.size.width / max(img.size.height, 1), contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: 420)
            .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))

            let shown = covers.filter { $0.emoji == nil }.count
            Text(finding ? L("Finding faces…")
                 : (covers.isEmpty ? L("No faces found — turn on 'Add by tapping' and tap where a face is.")
                    : "\(covers.count - shown) \(L("covered")) · \(shown) \(L("showing")) — \(L("tap a face to change it"))"))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)

            HandyFlow(spacing: 6) {
                    ForEach(FaceEmoji.palette, id: \.self) { e in
                        Button { current = e } label: {
                            Text(e).font(.system(size: 28)).frame(width: 44, height: 44)
                                .background(current == e ? HandyColor.accent.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(current == e ? HandyColor.accent : Color.clear, lineWidth: 2))
                        }.buttonStyle(.plain)
                    }
                }
            HStack {
                Text(L("Size")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 44, alignment: .leading)
                Slider(value: $scale, in: 0.9...1.9).tint(HandyColor.accent)
            }
            HStack(spacing: HandySpacing.s8) {
                Button(L("Cover all")) { for i in covers.indices { covers[i].emoji = covers[i].emoji ?? current }; resultURL = nil }
                    .buttonStyle(.bordered).font(HandyFont.caption)
                Button(L("Same emoji on all")) { for i in covers.indices where covers[i].emoji != nil { covers[i].emoji = current }; resultURL = nil }
                    .buttonStyle(.bordered).font(HandyFont.caption)
                Toggle(L("Add by tapping"), isOn: $addMode).toggleStyle(.button).font(HandyFont.caption)
            }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let url = resultURL {
                KeepShare(url, tool: "Emoji faces")
            } else {
                Button { make(img) } label: { Label(L("Done — make the photo"), systemImage: "checkmark").frame(maxWidth: .infinity) }
                    .primaryButton().disabled(working || covers.allSatisfy { $0.emoji == nil })
            }
            PhotosPicker(selection: $pick, matching: .images) { Label(L("Choose a different photo"), systemImage: "photo") }
                .textButton().font(HandyFont.caption).frame(maxWidth: .infinity)
            Text(L("The phone can't tell ages, so you choose which faces to cover. Saved as a fresh copy with no location data."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .onChange(of: scale) { _, _ in resultURL = nil }
    }

    /// Covered with a different emoji → switch to the chosen one; covered with this one → uncover; showing → cover.
    private func tap(_ c: FaceCover) {
        guard let i = covers.firstIndex(where: { $0.id == c.id }) else { return }
        if covers[i].emoji == nil { covers[i].emoji = current }
        else if covers[i].emoji != current { covers[i].emoji = current }
        else if covers[i].manual { covers.remove(at: i) }
        else { covers[i].emoji = nil }
        resultURL = nil
    }

    private func add(at p: CGPoint) {
        let sizes = covers.filter { !$0.manual }.map(\.rect.width).sorted()
        let w = sizes.isEmpty ? 0.18 : sizes[sizes.count / 2]
        let h = w * (photo.map { $0.size.width / max($0.size.height, 1) } ?? 1)
        covers.append(FaceCover(rect: CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h), emoji: current, manual: true))
        resultURL = nil
    }

    private func load(_ item: PhotosPickerItem?) {
        guard let item else { return }
        errorText = nil; resultURL = nil; covers = []
        Task {
            guard let d = try? await item.loadTransferable(type: Data.self), let raw = UIImage(data: d) else {
                await MainActor.run { errorText = "Couldn't open that photo." }; return
            }
            await MainActor.run { use(raw) }
        }
    }

    /// Show the photo and find its faces (shared by picking here and a hand-off).
    private func use(_ raw: UIImage) {
        errorText = nil; resultURL = nil; covers = []
        let img = raw.resized(maxDimension: 3000).normalizedUp()
        photo = img; finding = true
        Task {
            let found: [CGRect] = await Task.detached(priority: .userInitiated) {
                guard let cg = img.cgImage else { return [] }
                return Scrubber.thoroughFaces(cg).map { $0.insetBy(dx: -$0.width * 0.08, dy: -$0.height * 0.1) }
            }.value
            await MainActor.run {
                finding = false
                covers = found.map { FaceCover(rect: $0, emoji: current) }
                addMode = found.isEmpty
            }
        }
    }

    private func make(_ img: UIImage) {
        working = true
        let cs = covers, sc = CGFloat(scale)
        Task {
            let url: URL? = await Task.detached(priority: .userInitiated) {
                let out = FaceEmoji.render(img, covers: cs, scale: sc)
                guard let data = out.jpegData(compressionQuality: 0.92) else { return nil }
                let u = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy face emoji.jpg")
                try? FileManager.default.removeItem(at: u)
                return (try? data.write(to: u)) != nil ? u : nil
            }.value
            await MainActor.run {
                working = false
                if let url { resultURL = url; HandyHaptics.success() } else { errorText = "Couldn't save the photo — try again." }
            }
        }
    }
}
