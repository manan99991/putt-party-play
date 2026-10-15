import SwiftUI
import PhotosUI
import Vision

/// Pick any screenshot or photo → every line of text, copied in one tap. On-device Vision OCR.
struct TextFromImageView: View {
    @State private var pick: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var text = ""
    @State private var boxes: [CGRect] = [] // Vision normalized line boxes (origin bottom-left)
    @State private var busy = false

    var body: some View {
        ToolPage(title: "Text from Image", subtitle: "Screenshots of chats, slides, menus, error messages — get the words out.") {
            PhotosPicker(selection: $pick, matching: .images) { Label("Choose a screenshot or photo", systemImage: "photo").frame(maxWidth: .infinity) }
                .primaryButton()
            // Hero: the picked image with translucent accent highlight boxes over detected lines.
            if let image {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = min(geo.size.height, w * image.size.height / image.size.width)
                    Image(uiImage: image).resizable().scaledToFit().frame(width: w, height: h)
                        .overlay(alignment: .topLeading) {
                            ForEach(boxes.indices, id: \.self) { i in
                                let b = boxes[i]
                                Rectangle().fill(HandyColor.accent.opacity(0.28))
                                    .frame(width: w * b.width, height: h * b.height)
                                    .offset(x: w * b.minX, y: h * (1 - b.maxY))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }.frame(height: 220)
            }
            if busy { ProgressView("Reading…") }
            if !text.isEmpty {
                HStack {
                    Button { UIPasteboard.general.string = text; ClipStore.add(text) } label: { Label("Copy all", systemImage: "doc.on.doc") }.secondaryButton()
                    ShareLink(item: text) { Label("Share", systemImage: "square.and.arrow.up") }.secondaryButton()
                }
                Text(text).textSelection(.enabled).font(HandyFont.body).cardStyle(padding: HandySpacing.s12)
            }
        }
        .onChange(of: pick) { _, item in Task { await load(item) } }
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data), let cg = img.cgImage else { return }
        image = img; busy = true; text = ""; boxes = []
        let req = VNRecognizeTextRequest { r, _ in
            let obs = r.results as? [VNRecognizedTextObservation] ?? []
            let lines = obs.compactMap { $0.topCandidates(1).first?.string }
            Task { @MainActor in
                text = lines.joined(separator: "\n")
                boxes = obs.map(\.boundingBox)
                busy = false
                Interstitials.shared.showIfReady()
            }
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
