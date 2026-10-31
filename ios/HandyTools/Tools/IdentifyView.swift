import SwiftUI
import PhotosUI
import UIKit

/// Identify — point the camera at something and find out what it is. On-device recognition gives the
/// best guesses with confidence, reads a barcode if there is one, and offers a one-tap web search to
/// confirm the exact species, plant or product.
struct IdentifyView: View {
    @State private var image: UIImage?
    @State private var outcome: Identifier.Outcome?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var busy = false

    private var best: Identifier.Guess? { outcome?.guesses.first }

    var body: some View {
        ToolPage(title: "Identify", subtitle: "Point, snap, know. A best guess at what you're looking at — on-device — with a one-tap way to be sure.") {
            HowTo("identify", [
                "Photograph the thing — a plant, an animal, an object, a barcode.",
                "See the best guesses, most likely first, with how confident each is.",
                "Tap to confirm with a quick web search for the top guess.",
            ])
            HStack(spacing: HandySpacing.s8) {
                Button { showCamera = true } label: { Label("Photograph", systemImage: "camera.fill").frame(maxWidth: .infinity) }.primaryButton()
                PhotosPicker(selection: $pickerItem, matching: .images) { Label("From Photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if busy { HStack(spacing: HandySpacing.s8) { ProgressView(); Text("Looking…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }

            if let image {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                    .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            }

            if let outcome {
                if let code = outcome.barcode {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(outcome.symbology ?? "Barcode", systemImage: "barcode.viewfinder").font(HandyFont.bodyStrong)
                        Text(code).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        Link(destination: searchURL(code)) { Label("Look up this product", systemImage: "magnifyingglass").font(HandyFont.caption) }
                    }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
                }

                if outcome.guesses.isEmpty && outcome.barcode == nil {
                    Text("No confident guess. Try filling the frame with the subject, in good light, against a plain background.")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                } else if !outcome.guesses.isEmpty {
                    Text("Best guess").font(HandyFont.bodyStrong)
                    ForEach(outcome.guesses) { g in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(g.label).font(g.id == best?.id ? HandyFont.bodyStrong : HandyFont.body)
                                Spacer()
                                Text("\(Int(g.confidence * 100))%").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                            }
                            ProgressView(value: g.confidence).tint(g.id == best?.id ? HandyColor.accent : HandyColor.textSecondary)
                        }.padding(.vertical, 2)
                    }
                    if let best {
                        Link(destination: searchURL(best.label)) {
                            Label("Search the web for “\(best.label)”", systemImage: "magnifyingglass").frame(maxWidth: .infinity)
                        }.secondaryButton()
                    }
                    Text("Best guess from on-device recognition — a quick search confirms the exact species or model.")
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
            } else if !busy {
                Text("Works on plants, animals, food, everyday objects and barcodes. Nothing is uploaded to make the guess.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .sheet(isPresented: $showCamera) { CameraShot { img in if let img { run(img) } } }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            busy = true
            Task {
                let img = (try? await item.loadTransferable(type: Data.self)).flatMap(UIImage.init)
                pickerItem = nil
                if let img { run(img) } else { await MainActor.run { busy = false } }
            }
        }
        .onAppear { if Launch.sample, image == nil { run(SampleAssets.receipt()) } }
    }

    private func run(_ img: UIImage) {
        image = img; outcome = nil; busy = true
        Task {
            let result = await Identifier.identify(img)
            await MainActor.run { outcome = result; busy = false }
        }
    }

    private func searchURL(_ q: String) -> URL {
        URL(string: "https://www.google.com/search?q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)") ?? URL(string: "https://www.google.com")!
    }
}

/// Camera capture for Identify — snap the subject. Falls back gracefully where there's no camera.
private struct CameraShot: UIViewControllerRepresentable {
    let done: (UIImage?) -> Void
    func makeCoordinator() -> Coord { Coord(done: done) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) { p.sourceType = .camera }
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { done(info[.originalImage] as? UIImage) }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}
