import SwiftUI
import PhotosUI

/// "From my videos": every audio tool takes the sound from videos in the Photos library, not only from Files —
/// a voice memo filmed on the phone, a screen recording, a lecture. Picked videos are copied in and named
/// "Video 1", "Video 2"… so they read well in the tool's list. Shown beside each audio tool's Files button.
struct FromVideosButton: View {
    var title = "From my videos"
    var multiple = false
    var primary = false
    let onURLs: ([URL]) -> Void

    @State private var items: [PhotosPickerItem] = []
    @State private var loading = false

    var body: some View {
        let label = HStack(spacing: 6) {
            if loading { ProgressView().controlSize(.small) } else { Image(systemName: "video") }
            Text(L(loading ? "Getting the videos…" : title))
        }.frame(maxWidth: .infinity)
        Group {
            if primary {
                PhotosPicker(selection: $items, maxSelectionCount: multiple ? 20 : 1, matching: .videos) { label }.primaryButton()
            } else {
                PhotosPicker(selection: $items, maxSelectionCount: multiple ? 20 : 1, matching: .videos) { label }.secondaryButton()
            }
        }
        .disabled(loading)
        .accessibilityIdentifier("audio-from-videos")
        .onChange(of: items) { _, picked in
            guard !picked.isEmpty else { return }
            items = []; loading = true
            Task {
                var urls: [URL] = []
                for (i, it) in picked.enumerated() {
                    guard let m = try? await it.loadTransferable(type: MovieImport.self) else { continue }
                    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let named = dir.appendingPathComponent("\(L("Video")) \(i + 1).\(m.url.pathExtension.isEmpty ? "mov" : m.url.pathExtension)")
                    if (try? FileManager.default.moveItem(at: m.url, to: named)) != nil { urls.append(named) } else { urls.append(m.url) }
                }
                await MainActor.run { loading = false; if !urls.isEmpty { onURLs(urls) } }
            }
        }
    }
}
