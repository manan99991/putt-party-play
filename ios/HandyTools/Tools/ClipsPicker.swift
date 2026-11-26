import SwiftUI
import PhotosUI

/// One clip (or photo turned into a clip) picked for a reel or a trailer, with its thumbnail.
struct ClipPiece: Identifiable {
    let id = UUID()
    let url: URL
    let thumb: UIImage?

    static func make(_ urls: [URL]) async -> [ClipPiece] {
        var out: [ClipPiece] = []
        for u in urls { out.append(ClipPiece(url: u, thumb: await VideoEngine.thumbnail(u, at: 0.5))) }
        return out
    }
}

/// "Your clips and photos" for Beat Reel and the trailer maker: the picked pieces in a grid (each can be removed),
/// Choose / Add more from Photos (videos and photos, up to 12 at a time; photos become short clips), and Record.
struct ClipsPicker: View {
    @Binding var pieces: [ClipPiece]
    /// The start of every accessibility id here ("reel" → reel-pieces, reel-pick).
    let prefix: String
    @State private var picks: [PhotosPickerItem] = []
    @State private var loading: Double?
    @State private var errorText: String?

    private let grid = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Your clips and photos")).font(HandyFont.cardTitle)
            if !pieces.isEmpty {
                LazyVGrid(columns: grid, spacing: 6) {
                    ForEach(pieces) { p in
                        ZStack(alignment: .topTrailing) {
                            Color.clear.aspectRatio(9.0 / 16.0, contentMode: .fit)
                                .overlay { if let t = p.thumb { Image(uiImage: t).resizable().scaledToFill() } else { HandyColor.surface } }
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Button { pieces.removeAll { $0.id == p.id } } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(.white, .black.opacity(0.55))
                            }.buttonStyle(.plain).padding(4).accessibilityLabel(L("Remove"))
                        }
                    }
                }
                .accessibilityIdentifier("\(prefix)-pieces").accessibilityValue("\(pieces.count)")
            }
            HStack(spacing: HandySpacing.s8) {
                PhotosPicker(selection: $picks, maxSelectionCount: 12, matching: .any(of: [.videos, .images])) {
                    Label(L(pieces.isEmpty ? "Choose" : "Add more"), systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
                }.primaryButton().accessibilityIdentifier("\(prefix)-pick")
                CameraButton(video: true, took: { t in if case .video(let u) = t { Task { await add([u]) } } }) {
                    Label(L("Record"), systemImage: "video").frame(maxWidth: .infinity)
                }.secondaryButton().accessibilityIdentifier("tool-record")
            }
            if let f = loading { ToolProgressBar(value: f, label: "Getting them ready…") }
            if let errorText { Text(L(errorText)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            picks = []; loading = 0; errorText = nil
            Task {
                var urls: [URL] = []
                for (i, item) in items.enumerated() {
                    if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                        if let m = await MovieImport.load(item, progress: { _ in }) { urls.append(m.url) }
                    } else if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d), let v = await BeatReel.clip(from: img) {
                        urls.append(v)
                    }
                    await MainActor.run { loading = Double(i + 1) / Double(items.count) }
                }
                await add(urls)
                await MainActor.run { loading = nil; if urls.isEmpty { errorText = "Those didn't load — try others." } }
            }
        }
    }

    private func add(_ urls: [URL]) async {
        let new = await ClipPiece.make(urls)
        await MainActor.run { pieces.append(contentsOf: new) }
    }
}
