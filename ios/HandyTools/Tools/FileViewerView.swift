import SwiftUI
import QuickLook
import UniformTypeIdentifiers

/// File Opener — hand it almost anything (PDF, Office/iWork, images, text, code, archives, more) and it
/// opens right here. Permission-safe by design: you pick the file through the system document picker
/// (as a copy we own), so there's no broad Files/Photos access and nothing to grant. QuickLook — Apple's
/// own engine — renders the common types; for the rest we still show the details and let you share it on,
/// so it never dead-ends on "no app can open this".
struct FileViewerView: View {
    @State private var info: FileInfo?
    @State private var showPicker = false
    @State private var textPeek: String?
    @State private var errorText: String?

    struct FileInfo: Identifiable {
        let id = UUID()
        let name: String
        let kind: FileKind
        let typeLabel: String
        let size: String
        let url: URL
    }

    var body: some View {
        ToolPage(title: "File Opener", subtitle: "Open almost any file — PDFs, Office & iWork docs, images, text, code, archives and more. You pick it, it opens; nothing leaves your phone.") {
            HowTo("fileviewer", [
                "Tap Choose a file and pick anything — from Files, iCloud or a download.",
                "It opens right here: read it, flip through pages, zoom.",
                "Share or save it on. No permissions to grant — you chose the file.",
            ])
            Button { showPicker = true } label: {
                Label(info == nil ? "Choose a file" : "Open a different file", systemImage: "doc.badge.plus").frame(maxWidth: .infinity)
            }.secondaryButton()

            if info == nil && errorText == nil {
                Text("Works offline and on files other apps choke on — if something can't preview, you still get its details and a way to share it, never a dead end.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }

            if let info {
                HStack(spacing: HandySpacing.s12) {
                    Image(systemName: info.kind.icon).font(.system(size: 22)).foregroundStyle(HandyColor.accent).frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.name).font(HandyFont.bodyStrong).lineLimit(2)
                        Text("\(info.typeLabel) · \(info.size)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                    Spacer()
                }.cardStyle(padding: HandySpacing.s12)

                QuickLookPreview(url: info.url)
                    .frame(height: 460)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))

                if let textPeek {
                    DisclosureGroup("Text in this file") {
                        ScrollView { Text(textPeek).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                            .frame(maxHeight: 200)
                    }.font(HandyFont.caption)
                }

                ShareLink(item: info.url) { Label("Share or save", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            }

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .sheet(isPresented: $showPicker) { DocumentPicker { url in handlePicked(url) } }
    }

    private func handlePicked(_ url: URL) {
        // The picker is configured asCopy, so `url` is a copy we own in our temp dir — no security-scoped
        // juggling, and we can read it freely.
        guard FileManager.default.fileExists(atPath: url.path) else { errorText = "That file couldn't be read. Try another."; return }
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? Int64) ?? 0
        let ext = url.pathExtension
        let kind = FileKind.of(ext: ext)
        let typeLabel = UTType(filenameExtension: ext)?.localizedDescription ?? (ext.isEmpty ? "File" : ext.uppercased())
        info = FileInfo(name: url.lastPathComponent, kind: kind, typeLabel: typeLabel.capitalized,
                        size: ByteCountFormatter.string(fromByteCount: size, countStyle: .file), url: url)
        errorText = nil
        // For text-like files, surface the content too (QuickLook shows it, but this makes it copyable).
        textPeek = (kind == .code || kind == .text) ? (try? String(contentsOf: url, encoding: .utf8)).map { String($0.prefix(20_000)) } : nil
    }
}

/// Everyday file categories — drives the icon, the friendly label, and whether we offer a text peek.
enum FileKind: String {
    case document, image, video, audio, archive, code, text, data, other

    static func of(ext raw: String) -> FileKind {
        let e = raw.lowercased()
        if ["pdf", "doc", "docx", "pages", "rtf", "key", "keynote", "ppt", "pptx", "xls", "xlsx", "numbers", "epub", "odt"].contains(e) { return .document }
        if ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tiff", "bmp", "svg", "raw", "dng", "cr2", "nef", "arw"].contains(e) { return .image }
        if ["mp4", "mov", "m4v", "avi", "mkv", "webm", "hevc", "3gp"].contains(e) { return .video }
        if ["mp3", "m4a", "wav", "aac", "flac", "aiff", "ogg", "caf"].contains(e) { return .audio }
        if ["zip", "rar", "7z", "tar", "gz", "bz2", "xz"].contains(e) { return .archive }
        if ["swift", "js", "ts", "py", "java", "kt", "c", "cpp", "h", "m", "cs", "go", "rb", "php", "rs", "sh", "html", "css", "json", "xml", "yml", "yaml", "sql"].contains(e) { return .code }
        if ["txt", "md", "csv", "log", "tsv"].contains(e) { return .text }
        if ["sqlite", "db", "sqlite3", "plist", "bin", "dat"].contains(e) { return .data }
        return .other
    }

    var icon: String {
        switch self {
        case .document: return "doc.richtext"
        case .image:    return "photo"
        case .video:    return "film"
        case .audio:    return "waveform"
        case .archive:  return "archivebox"
        case .code:     return "chevron.left.forwardslash.chevron.right"
        case .text:     return "doc.plaintext"
        case .data:     return "cylinder.split.1x2"
        case .other:    return "doc"
        }
    }
}

/// QuickLook preview, embedded — Apple's own renderer, so it handles PDFs, Office/iWork, images, text,
/// CSV and many more for free, in the UI the user already knows.
private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let c = QLPreviewController(); c.dataSource = context.coordinator; return c
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url; controller.reloadData()
    }
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}

/// The system document picker in copy mode — the user picks any file and we get an owned copy, so there's
/// no entitlement, no broad access, and nothing to approve beyond choosing the file.
private struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let p = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        p.delegate = context.coordinator; p.allowsMultipleSelection = false
        return p
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let u = urls.first { onPick(u) }
        }
    }
}
