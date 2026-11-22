import SwiftUI

/// The finish for a fun photo — sticker, emoji faces, meme, emoji art, pencil sketch, comic — the same for the
/// ready-made tools and any built tool ending in one of those steps: the result big; other looks tried on the same
/// photo with one tap; Copy (paste straight into a chat), Save to Photos, Share; and the way into the full tool
/// (Sticker studio's ten looks, an emoji per face, a comic strip) carrying the photo over.
struct FunFinishCard: View {
    let block: Block
    let original: UIImage?
    @State var result: UIImage
    @State var look: String

    @State private var busy: String?
    @State private var note: String?

    /// The looks offered on the result, per kind of fun step: (setting value, label).
    static func looks(_ b: Block) -> [(id: String, name: String)] {
        switch b {
        case .artFilter: return PixelArt.styles
        case .sticker: return StickerStudio.presets.map { ($0.id, $0.name) }
        case .emojiFaces: return ChainText.faceEmojis.map { ($0, $0) }
        default: return []
        }
    }
    /// The full tool for this job, when it does more than the finish card.
    static func fullTool(_ b: Block) -> (id: String, label: String)? {
        switch b {
        case .sticker: return ("sticker", "Fine-tune it in Sticker studio")
        case .emojiFaces: return ("faceemoji", "A different emoji for each face")
        case .artFilter: return ("comicstrip", "Make a comic strip")
        default: return nil
        }
    }

    private var isSticker: Bool { block == .sticker }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if block == .artFilter, let o = original, o.size.width > 0 {
                // An art style changes the whole photo: the before/after slider shows exactly what it did.
                let h = min(380, max(220, 340 * o.size.height / o.size.width))
                CompareSlider(before: o.normalizedUp(), after: result, height: h)
                    .frame(height: h)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("fun-compare")
            } else {
                ZStack {
                    if isSticker { Checkerboard().clipShape(RoundedRectangle(cornerRadius: 12)) }
                    Image(uiImage: result).resizable().scaledToFit().padding(isSticker ? 12 : 0).opensFullSize(result)
                }
                .frame(maxWidth: .infinity).frame(maxHeight: 380)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            let options = Self.looks(block)
            if !options.isEmpty, original != nil {
                Text(L(block == .emojiFaces ? "Try another emoji" : "Try another look")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                HandyFlow(spacing: 8) {
                        ForEach(options, id: \.id) { o in
                            Button { restyle(o.id) } label: {
                                HStack(spacing: 4) {
                                    if busy == o.id { ProgressView().controlSize(.mini) }
                                    Text(block == .emojiFaces ? o.name : L(o.name)).font(block == .emojiFaces ? .title3 : HandyFont.caption)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(look == o.id ? HandyColor.accent : HandyColor.surface, in: Capsule())
                                .foregroundStyle(look == o.id ? Color.white : HandyColor.textPrimary)
                            }.buttonStyle(.plain).disabled(busy != nil)
                        }
                    }
                .accessibilityIdentifier("fun-looks")
            }

            Button {
                UIPasteboard.general.image = result
                CopyToast.shared.flash(L("Copied — paste it into any chat"))
            } label: { Label(L("Copy — paste into any chat"), systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.primaryButton()
            // A sticker stays a see-through PNG so Photos can lift it; other pictures save as JPEG.
            if let d = isSticker ? result.pngData() : result.jpegData(compressionQuality: 0.92) {
                KeepShare([.data(d, name: isSticker ? "Sticker" : "Picture", ext: isSticker ? "png" : "jpg")], tool: "Picture", record: false)
            }
            if isSticker {
                VStack(alignment: .leading, spacing: 4) {
                    Label(L("Keep it in your sticker drawer"), systemImage: "face.smiling").font(HandyFont.caption.weight(.semibold))
                    Text(L("Save to Photos, open it in Photos, touch and hold the sticker, then tap Add Sticker. It's then in Messages, WhatsApp and any app's emoji keyboard."))
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let full = Self.fullTool(block), let o = original {
                Button {
                    ToolHandoff.shared.put(.image(o), for: full.id)
                    NotificationCenter.default.post(name: .openTool, object: full.id)
                } label: { Label(L(full.label), systemImage: "arrow.up.forward.app").frame(maxWidth: .infinity) }.textButton()
            }
            if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fun-finish")
    }

    private func restyle(_ id: String) {
        guard id != look, let o = original else { return }
        busy = id
        let key = block == .emojiFaces ? "emoji" : "style"
        Task {
            let r = await ChainRunner.apply(ChainStep(block: block, settings: [key: id]), to: .image(o))
            await MainActor.run {
                busy = nil
                switch r {
                case .success(.image(let img)): result = img; look = id
                case .success(.file(let d, _)): if let img = UIImage(data: d) { result = img; look = id }   // a sticker comes back as a see-through PNG
                default: note = L("That look couldn't be made from this photo.")
                }
            }
        }
    }
}

/// Where a finished photo usually goes: straight into Photos, or pasted into a chat. Under every photo result.
struct PhotoLandingRow: View {
    let data: Data
    let image: UIImage
    @State private var note: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: HandySpacing.s8) {
                // Save and Share sit in the bar above; this row adds Copy, for pasting straight into a chat.
                Button {
                    UIPasteboard.general.image = image
                    CopyToast.shared.flash(L("Copied — paste it into any chat"))
                } label: { Label(L("Copy"), systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
        }
        .accessibilityIdentifier("photo-landing")
    }
}
