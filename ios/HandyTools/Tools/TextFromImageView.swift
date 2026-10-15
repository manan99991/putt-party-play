import SwiftUI
import PhotosUI
import Vision

/// Pick any screenshot or photo → every line of text, copied in one tap. On-device Vision OCR.
struct TextFromImageView: View {
    @State private var pick: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var text = ""
    @State private var busy = false

    var body: some View {
        ToolPage(title: "Text from Image", subtitle: "Screenshots of chats, slides, menus, error messages — get the words out.") {
            PhotosPicker(selection: $pick, matching: .images) { Label("Choose a screenshot or photo", systemImage: "photo").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
            if let image { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220).clipShape(RoundedRectangle(cornerRadius: 12)) }
            if busy { ProgressView("Reading…") }
            if !text.isEmpty {
                HStack {
                    Button { UIPasteboard.general.string = text; ClipStore.add(text) } label: { Label("Copy all", systemImage: "doc.on.doc") }.buttonStyle(.bordered)
                    ShareLink(item: text) { Label("Share", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
                }
                Text(text).textSelection(.enabled).font(.callout).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .onChange(of: pick) { _, item in Task { await load(item) } }
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data), let cg = img.cgImage else { return }
        image = img; busy = true; text = ""
        let req = VNRecognizeTextRequest { r, _ in
            let lines = (r.results as? [VNRecognizedTextObservation])?.compactMap { $0.topCandidates(1).first?.string } ?? []
            Task { @MainActor in text = lines.joined(separator: "\n"); busy = false; Interstitials.shared.showIfReady() }
        }
        req.recognitionLevel = .accurate; req.usesLanguageCorrection = true
        try? VNImageRequestHandler(cgImage: cg, orientation: CGImagePropertyOrientation(img.imageOrientation)).perform([req])
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up; case .down: self = .down; case .left: self = .left; case .right: self = .right
        case .upMirrored: self = .upMirrored; case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored; case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
