import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers

/// The sticker work that isn't UI: make one, and save it to Photos as a real see-through PNG.
enum StickerMaker {
    /// Photo → subject cut out → white-edged sticker (see-through PNG). Nil when no subject is found.
    static func make(_ photo: UIImage) -> (image: UIImage, png: Data)? {
        guard let cut = ImageStudio.cutout(photo.normalizedUp()), let s = ChainFun.sticker(cut), let png = s.pngData() else { return nil }
        return (s, png)
    }

    /// Save as a PNG (keeps the transparency — a JPEG would put it on a white box).
    static func saveToPhotos(_ png: Data) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: png, options: nil)
            }
            return true
        } catch { return false }
    }
}

/// Sticker Maker — pick a photo of a person, pet or thing; Tenzy cuts it out with a white sticker edge.
/// Copy it straight into any chat, or save it to Photos and add it to the iPhone's own sticker drawer in
/// two taps — then it's there in Messages, WhatsApp and every app with the emoji keyboard. No extra
/// apps, nothing uploaded.
struct StickerMakerView: View {
    @State private var pick: PhotosPickerItem?
    @State private var sticker: UIImage?
    @State private var png: Data?
    @State private var working = false
    @State private var saved = false
    @State private var copied = false
    @State private var errorText: String?

    var body: some View {
        ToolPage(title: "Sticker Maker", subtitle: "Turn any photo into a sticker for Messages, WhatsApp and more.", working: working) {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                if let s = sticker, let data = png { result(s, data) } else { pickCard }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .onChange(of: pick) { _, item in load(item) }
        .handoff("sticker") { p in if let img = ToolHandoff.image(p) { make(img) } }
    }

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Text("✂️").font(.system(size: 52))
            Text(L("Pick a photo of a person, pet or thing. Tenzy cuts it out and gives it a sticker edge."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            PhotosPicker(selection: $pick, matching: .images) {
                Label(L("Choose a photo"), systemImage: "photo").frame(maxWidth: .infinity)
            }.primaryButton()
            if working { ToolProgressBar(label: "Cutting it out…", showsTime: false) }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
        .frame(maxWidth: .infinity)
    }

    private func result(_ s: UIImage, _ data: Data) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            // Checkerboard behind it, so the see-through edges are obvious.
            ZStack {
                Checkerboard().clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                Image(uiImage: s).resizable().scaledToFit().padding(HandySpacing.s16)
            }
            .frame(maxWidth: .infinity).frame(height: 300)

            Button {
                UIPasteboard.general.setData(data, forPasteboardType: UTType.png.identifier)
                copied = true; HandyHaptics.success()
            } label: {
                Label(copied ? L("Copied — paste it into any chat") : L("Copy sticker"), systemImage: copied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }.primaryButton()

            Button { save(data) } label: {
                Label(saved ? L("Saved to Photos") : L("Save to Photos"), systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }.secondaryButton().disabled(saved)

            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Label(L("Keep it in your sticker drawer"), systemImage: "face.smiling").font(HandyFont.bodyStrong)
                step(1, saved ? "Open Photos and tap this sticker (it's your newest photo)." : "Tap Save to Photos above, then open Photos and tap the sticker.")
                step(2, "Touch and hold the cut-out, then tap Add Sticker.")
                step(3, "It's now in your stickers — in Messages, WhatsApp and any app, from the emoji keyboard.")
            }
            .cardStyle(padding: HandySpacing.s12)

            ShareLink(item: PNGFile(data: data), preview: SharePreview("Sticker", image: Image(uiImage: s))) {
                Label(L("Share"), systemImage: "square.and.arrow.up")
            }.textButton()
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            PhotosPicker(selection: $pick, matching: .images) { Label(L("Make another"), systemImage: "photo") }
                .textButton().font(HandyFont.caption).frame(maxWidth: .infinity)
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HandySpacing.s8) {
            Text("\(n)").font(HandyFont.caption.weight(.bold)).foregroundStyle(.white)
                .frame(width: 22, height: 22).background(HandyColor.accent, in: Circle())
            Text(L(text)).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func load(_ item: PhotosPickerItem?) {
        guard let item else { return }
        errorText = nil
        Task {
            guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) else {
                await MainActor.run { errorText = "Couldn't open that photo." }; return
            }
            await MainActor.run { make(img) }
        }
    }

    private func make(_ photo: UIImage) {
        working = true; errorText = nil; saved = false; copied = false; sticker = nil; png = nil
        let src = photo.resized(maxDimension: 2400)
        Task {
            let made = await Task.detached(priority: .userInitiated) { StickerMaker.make(src) }.value
            await MainActor.run {
                working = false
                guard let made else {
                    errorText = "Couldn't find a person, pet or thing to cut out. Try a photo where it stands clear of the background."
                    return
                }
                sticker = made.image; png = made.png; HandyHaptics.success()
            }
        }
    }

    private func save(_ data: Data) {
        Task {
            let ok = await StickerMaker.saveToPhotos(data)
            await MainActor.run {
                if ok { saved = true; HandyHaptics.success() }
                else { errorText = "Tenzy needs permission to add to Photos — allow it in Settings → Privacy → Photos → Tenzy, or use Copy." }
            }
        }
    }
}

/// A light grey checkerboard — the universal "this part is see-through" backdrop.
private struct Checkerboard: View {
    var body: some View {
        Canvas { ctx, size in
            let s: CGFloat = 12
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.96)))
            for y in stride(from: 0, to: size.height, by: s) {
                for x in stride(from: 0, to: size.width, by: s) where (Int(x / s) + Int(y / s)) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: x, y: y, width: s, height: s)), with: .color(Color(white: 0.86)))
                }
            }
        }
    }
}
