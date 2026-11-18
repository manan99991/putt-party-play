import SwiftUI

/// Opens a ZIP in the app instead of sending you to the Files app. It lists every file inside; opening one
/// either hands it straight to Tenzy's tools (when there's a tool for that kind of file) or lets you save or
/// share it. The archive is read on the phone — nothing leaves it.
struct UnzipTarget: Identifiable { let id = UUID(); let url: URL }

struct UnzipView: View {
    let url: URL
    /// Called when a file inside is opened and Tenzy has a tool for it — the parent continues into the tools.
    let onOpen: (Given) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var share: ShareFile?

    private var names: [String] { Given.Zip.names(in: url) }

    var body: some View {
        NavigationStack {
            Group {
                if names.isEmpty {
                    ContentUnavailableView(L("Nothing to open"), systemImage: "doc.zipper",
                                           description: Text(L("This archive is empty or couldn't be read.")))
                } else {
                    List(names, id: \.self) { name in
                        Button { open(name) } label: {
                            HStack(spacing: HandySpacing.s12) {
                                Image(systemName: icon(for: name)).foregroundStyle(HandyColor.accent).frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(base(name)).foregroundStyle(HandyColor.textPrimary)
                                    if name.contains("/") {
                                        Text(name).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(names.isEmpty ? L("Archive") : "\(names.count) " + (names.count == 1 ? L("file") : L("files")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Close")) { dismiss() } } }
            .sheet(item: $share) { s in
                NavigationStack {
                    VStack(spacing: HandySpacing.s16) {
                        Image(systemName: "doc").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
                        Text(s.url.lastPathComponent).font(HandyFont.bodyStrong).lineLimit(2).multilineTextAlignment(.center)
                        Text(L("Tenzy has no tool for this kind of file yet — save or share it.")).font(HandyFont.caption)
                            .foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                        ShareLink(item: s.url) { Label(L("Save or share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
                        Spacer()
                    }
                    .padding(HandySpacing.gutter)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { share = nil } } }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func open(_ name: String) {
        guard let data = Given.Zip.entryData(in: url, named: name) else { return }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-unzip-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let out = dir.appendingPathComponent((name as NSString).lastPathComponent)
        guard (try? data.write(to: out)) != nil else { return }
        if let g = Given.from(file: out) {
            onOpen(g)                 // Tenzy has a tool for it → parent dismisses us and continues
        } else {
            share = ShareFile(url: out)   // no tool → let them save/share the extracted file
        }
    }

    private func base(_ name: String) -> String { (name as NSString).lastPathComponent }
    private func icon(for name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "jpg", "jpeg", "png", "heic", "gif", "webp": return "photo"
        case "mp4", "mov", "m4v": return "film"
        case "mp3", "m4a", "wav", "aiff", "aac", "flac": return "waveform"
        case "txt", "md", "rtf", "csv", "json", "html", "xml": return "doc.text"
        case "zip", "zipx": return "doc.zipper"
        default: return "doc"
        }
    }
}

private struct ShareFile: Identifiable { let id = UUID(); let url: URL }
