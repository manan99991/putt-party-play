import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Make a Zip — pick files and/or photos, name the archive, and get one .zip to send. Shows each file
/// and the total, live progress while packing, then checks the REAL zip by reading it back (file count
/// and size) before Save or Share. Opens anywhere: Files, Windows, Mac, Gmail. On device.
struct ZipMakerView: View {
    struct Entry: Identifiable { let id = UUID(); var name: String; let url: URL; let bytes: Int }

    @State private var entries: [Entry] = []
    @State private var archiveName = "Files"
    @State private var photoPicks: [PhotosPickerItem] = []
    @State private var loadingPhotos = false
    @State private var progress: Double = 0
    @State private var working = false
    @State private var resultURL: URL?
    @State private var resultBytes = 0
    @State private var resultCount = 0
    @State private var errorText: String?
    @State private var showFiles = false

    private var totalBytes: Int { entries.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        ToolPage(title: "Make a Zip",
                 subtitle: "Bundle files and photos into one .zip to send.",
                 working: working) {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                if let url = resultURL { result(url) } else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { res in
            if case .success(let urls) = res { addFiles(urls) }
        }
        .onChange(of: photoPicks) { _, items in addPhotos(items) }
        .handoff("zipmaker") { p in if let u = ToolHandoff.fileURL(p) { addFiles([u]) } }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if entries.isEmpty {
                Text(L("Add files or photos. Tenzy packs them into one .zip that opens on any phone or computer."))
                    .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
            }
            HStack(spacing: HandySpacing.s8) {
                Button { showFiles = true } label: {
                    Label(L("Add files"), systemImage: "folder").frame(maxWidth: .infinity)
                }.secondaryButton()
                PhotosPicker(selection: $photoPicks, maxSelectionCount: 100, matching: .any(of: [.images, .videos])) {
                    Label(L("Add photos"), systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                }.secondaryButton()
            }
            if loadingPhotos { ToolProgressBar(label: "Adding photos…", showsTime: false) }
            ForEach(entries) { e in
                HStack(spacing: HandySpacing.s8) {
                    Image(systemName: icon(for: e.name)).foregroundStyle(HandyColor.accent).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.name).font(HandyFont.body).lineLimit(1).truncationMode(.middle)
                        Text(AudioCompressView.size(e.bytes)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    }
                    Spacer()
                    Button { entries.removeAll { $0.id == e.id } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(HandyColor.textSecondary).frame(width: 36, height: 36)
                    }.buttonStyle(.plain).accessibilityLabel(L("Remove"))
                }
                .cardStyle(padding: HandySpacing.s8)
            }
            if !entries.isEmpty {
                Text("\(entries.count) \(entries.count == 1 ? L("file") : L("files")) · \(AudioCompressView.size(totalBytes))")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Text(L("Zip name")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                TextField(L("Zip name"), text: $archiveName).textFieldStyle(.roundedBorder)
                if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
                Button { run() } label: {
                    Label(L("Make zip"), systemImage: "doc.zipper").frame(maxWidth: .infinity)
                }.primaryButton().disabled(working || loadingPhotos)
                if working { ToolProgressBar(value: progress, label: "Packing…") }
                Button(L("Clear all")) { entries = []; errorText = nil }.textButton().font(HandyFont.caption)
                    .frame(maxWidth: .infinity)
            } else if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
            }
        }
    }

    private func result(_ url: URL) -> some View {
        VStack(spacing: HandySpacing.s8) {
            Label("\(url.lastPathComponent) — \(resultCount) \(resultCount == 1 ? L("file") : L("files")), \(AudioCompressView.size(resultBytes))",
                  systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            if resultBytes < totalBytes {
                Text("\(L("Packed")) \(AudioCompressView.size(totalBytes)) → \(AudioCompressView.size(resultBytes))")
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(L("Photos and videos are already compressed, so the zip is about the same size — it's one tidy file to send."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ShareLink(item: url) {
                Label(L("Save or share zip"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.primaryButton()
            Button(L("Back to the files")) { resultURL = nil; progress = 0 }.textButton().font(HandyFont.caption)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    // MARK: - Actions

    private func addFiles(_ urls: [URL]) {
        errorText = nil
        var failed = 0
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let local = FileManager.default.temporaryDirectory.appendingPathComponent("zin-\(UUID().uuidString)")
            guard (try? FileManager.default.copyItem(at: url, to: local)) != nil else { failed += 1; continue }
            let bytes = (try? local.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            entries.append(Entry(name: url.lastPathComponent, url: local, bytes: bytes))
        }
        if failed > 0 { errorText = "\(failed) file(s) couldn't be opened — folders can't be added, only files." }
    }

    private func addPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        loadingPhotos = true; errorText = nil
        let start = entries.count
        Task {
            var added: [Entry] = []
            for (i, item) in items.enumerated() {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                let local = FileManager.default.temporaryDirectory.appendingPathComponent("zin-\(UUID().uuidString)")
                guard (try? data.write(to: local)) != nil else { continue }
                added.append(Entry(name: "Photo \(start + i + 1).\(ext)", url: local, bytes: data.count))
            }
            await MainActor.run {
                entries += added
                if added.count < items.count { errorText = "Some photos couldn't be added." }
                photoPicks = []
                loadingPhotos = false
            }
        }
    }

    private func run() {
        guard !entries.isEmpty else { return }
        working = true; errorText = nil; progress = 0
        let list = entries
        let clean = archiveName.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = clean.isEmpty ? "Files" : String(clean.prefix(60))
        Task { @MainActor in
            let out: Result<URL, ZipWriter.Failure> = await Task.detached(priority: .userInitiated) {
                var items: [ZipWriter.Item] = []
                for e in list {
                    guard let d = try? Data(contentsOf: e.url) else { return .failure(.cannotWrite) }
                    items.append(ZipWriter.Item(name: e.name, data: d))
                }
                switch ZipWriter.zip(items, progress: { p in Task { @MainActor in progress = p } }) {
                case .failure(let f): return .failure(f)
                case .success(let zip):
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).zip")
                    try? FileManager.default.removeItem(at: url)
                    guard (try? zip.write(to: url)) != nil else { return .failure(.cannotWrite) }
                    return .success(url)
                }
            }.value
            working = false
            switch out {
            case .failure(let f): errorText = f.message
            case .success(let url):
                // Check the REAL zip by reading it back with the same reader Unzip uses.
                let count = Given.Zip.names(in: url).count
                guard count == list.count else { errorText = "The zip didn't check out — try again."; return }
                resultCount = count
                resultBytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                resultURL = url
                HandyHaptics.success()
            }
        }
    }

    private func icon(for name: String) -> String {
        guard let t = UTType(filenameExtension: (name as NSString).pathExtension) else { return "doc" }
        if t.conforms(to: .image) { return "photo" }
        if t.conforms(to: .movie) { return "film" }
        if t.conforms(to: .audio) { return "waveform" }
        if t.conforms(to: .pdf) { return "doc.richtext" }
        return "doc"
    }
}
