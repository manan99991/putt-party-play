import SwiftUI
import UniformTypeIdentifiers

/// The cut-out, finished: see it against a checkerboard (so "see-through" is visible) next to your photo, pick
/// which subject when there are several, put something behind it, add a shadow, choose the shape, and send it
/// where it's going — Photos as a see-through PNG, pasted straight into a chat, a sticker, a profile picture or
/// a product listing. Says plainly when the subject runs off the photo's edge.
struct CutoutResult: View {
    let original: UIImage?
    let firstCut: UIImage

    @State private var subjects: [UIImage] = []
    @State private var pick = -1                 // -1 = everything the phone found
    @State private var backdrop: CutoutStudio.Backdrop = .clear
    @State private var colour = Color(red: 0.36, green: 0.62, blue: 0.95)
    @State private var shadow = false
    @State private var fit: CutoutStudio.Fit = .tight
    @State private var shown: UIImage?
    @State private var note: String?
    @State private var saved: String?
    @State private var compare = false

    private var cut: UIImage { pick >= 0 && pick < subjects.count ? subjects[pick] : firstCut }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            preview
            if let note { Label(note, systemImage: "exclamationmark.triangle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.amber).fixedSize(horizontal: false, vertical: true) }
            if subjects.count > 1 { subjectPicker }
            chips(L("Behind it"), CutoutStudio.Backdrop.allCases, selected: backdrop, label: { L($0.label) }) { backdrop = $0 }
            if backdrop == .colour { ColorPicker(L("Colour"), selection: $colour, supportsOpacity: false).font(HandyFont.caption) }
            chips(L("Shape"), CutoutStudio.Fit.allCases, selected: fit, label: { L($0.label) }) { fit = $0 }
            Toggle(L("Soft shadow under it"), isOn: $shadow).font(HandyFont.body).tint(HandyColor.accent)
            landings
            if let saved { Label(saved, systemImage: "checkmark.circle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success) }
        }
        .task {
            render()
            note = CutoutStudio.edgeNote(CutoutStudio.cutOffEdges(firstCut)).map(L)
            if let o = original { let s = await Task.detached { CutoutStudio.subjects(o) }.value; subjects = s }
        }
        .onChange(of: pick) { _, _ in render(); note = CutoutStudio.edgeNote(CutoutStudio.cutOffEdges(cut)).map(L) }
        .onChange(of: backdrop) { _, _ in render() }
        .onChange(of: shadow) { _, _ in render() }
        .onChange(of: fit) { _, _ in render() }
        .onChange(of: colour) { _, _ in if backdrop == .colour { render() } }
    }

    private func render() {
        shown = CutoutStudio.render(cut, original: original, backdrop: backdrop, colour: UIColor(colour), shadow: shadow, fit: fit)
        saved = nil
    }

    // MARK: preview

    private var preview: some View {
        VStack(spacing: 6) {
            ZStack {
                Checkerboard().clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                if let s = compare ? original : shown { Image(uiImage: s).resizable().scaledToFit().padding(6).opensFullSize(shown) }
            }
            .frame(height: 340).frame(maxWidth: .infinity)
            .onLongPressGesture(minimumDuration: 0.05, pressing: { compare = $0 }, perform: {})
            .accessibilityLabel(L("The cut-out. Press and hold to see your photo."))
            Text(L(compare ? "Your photo" : "Press and hold to see your photo")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private var subjectPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Keep")).font(HandyFont.bodyStrong)
            HandyFlow(spacing: 8) {
                    thumb(firstCut, L("Everything"), on: pick == -1) { pick = -1 }
                    ForEach(subjects.indices, id: \.self) { i in thumb(subjects[i], "\(L("Only")) \(i + 1)", on: pick == i) { pick = i } }
                }
        }
    }

    private func thumb(_ img: UIImage, _ label: String, on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            VStack(spacing: 4) {
                ZStack { Checkerboard(); Image(uiImage: CutoutStudio.render(img, original: nil, backdrop: .clear, shadow: false, fit: .tight) ?? img).resizable().scaledToFit().padding(4) }
                    .frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(on ? HandyColor.accent : HandyColor.border, lineWidth: on ? 2.5 : 1))
                Text(label).font(HandyFont.micro).foregroundStyle(on ? HandyColor.accent : HandyColor.textSecondary)
            }
        }.buttonStyle(.plain)
    }

    private func chips<T: Hashable & Identifiable>(_ title: String, _ all: [T], selected: T, label: @escaping (T) -> String, _ set: @escaping (T) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(HandyFont.bodyStrong)
            HandyFlow(spacing: 8) {
                    ForEach(all) { v in
                        Button { set(v) } label: {
                            Text(label(v)).font(HandyFont.caption).padding(.horizontal, 12).padding(.vertical, 8)
                                .background(v == selected ? HandyColor.accent : HandyColor.surface, in: Capsule())
                                .foregroundStyle(v == selected ? Color.white : HandyColor.textPrimary)
                        }.buttonStyle(.plain)
                    }
                }
        }
    }

    // MARK: where it goes

    private var png: Data? { shown?.pngData() }

    @ViewBuilder private var landings: some View {
        VStack(spacing: HandySpacing.s8) {
            // A see-through PNG, so the cut-out keeps no background in Photos too.
            if let d = png { KeepShare([.data(d, name: "Cut-out", ext: "png")], tool: "Cut out") }
            Button {
                guard let d = png else { return }
                UIPasteboard.general.setData(d, forPasteboardType: UTType.png.identifier)
                saved = L("Copied — paste it into Messages, WhatsApp or a document.")
            } label: { Label(L("Copy"), systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.secondaryButton()
            if let original {
                HStack(spacing: HandySpacing.s8) {
                    Button { open("sticker", original) } label: { Label(L("Make a sticker"), systemImage: "face.smiling").frame(maxWidth: .infinity) }.secondaryButton()
                    Button { open("studio", original) } label: { Label(L("Profile picture"), systemImage: "person.crop.circle").frame(maxWidth: .infinity) }.secondaryButton()
                }
            }
        }
    }

    private func open(_ tool: String, _ img: UIImage) {
        ToolHandoff.shared.put(.image(img), for: tool)
        NotificationCenter.default.post(name: .openTool, object: tool)
    }

    private func tempPNG(_ img: UIImage) -> URL? {
        guard let d = img.pngData() else { return nil }
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("Cut-out.png")
        return (try? d.write(to: u)) != nil ? u : nil
    }
}
