import SwiftUI
import Photos
import UniformTypeIdentifiers

/// What a tool made, ready to keep: a file already on disk, or bytes with the name and type it should have.
enum KeepItem {
    case file(URL)
    case data(Data, name: String, ext: String)
}

/// Bytes become a real file once (not on every redraw), in a folder of their own, with a clear name.
enum KeepFiles {
    private static var made: [String: URL] = [:]
    private static var recorded = Set<String>()
    private static let lock = NSLock()

    static func url(_ item: KeepItem) -> URL? {
        switch item {
        case .file(let u): return u
        case .data(let d, let name, let ext):
            var h = Hasher(); h.combine(d.count); h.combine(d.prefix(4096)); h.combine(d.suffix(4096)); h.combine(name); h.combine(ext)
            let key = String(h.finalize())
            lock.lock(); defer { lock.unlock() }
            if let u = made[key], FileManager.default.fileExists(atPath: u.path) { return u }
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("keep-\(key.replacingOccurrences(of: "-", with: "m"))", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let clean = name.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespaces)
            let u = dir.appendingPathComponent((clean.isEmpty ? "Tenzy" : clean) + "." + ext)
            guard (try? d.write(to: u)) != nil else { return nil }
            made[key] = u
            return u
        }
    }

    /// True the first time these files are seen, so a result lands in History once however often its screen redraws.
    static func firstSighting(_ urls: [URL]) -> Bool {
        let key = urls.map(\.path).sorted().joined(separator: "|")
        lock.lock(); defer { lock.unlock() }
        return recorded.insert(key).inserted
    }

    /// Pictures and videos go to Photos; everything else to Files.
    static func belongsInPhotos(_ urls: [URL]) -> Bool {
        !urls.isEmpty && urls.allSatisfy { u in
            guard let t = UTType(filenameExtension: u.pathExtension.lowercased()) else { return false }
            return (t.conforms(to: .image) && t != .pdf && !t.conforms(to: .svg)) || t.conforms(to: .movie)
        }
    }
    static func isVideo(_ u: URL) -> Bool { UTType(filenameExtension: u.pathExtension.lowercased())?.conforms(to: .movie) ?? false }
}

/// How every finished result ends, in every tool: **Save** — to Photos for pictures and videos, to Files for anything
/// else (the person picks the folder) — and **Share**, side by side, with a clear "Saved ✓" once it's done. The bigger
/// button follows what the tool is for: a tool for sending leads with Share, everything else with Save. A shrink
/// tool given a Photos item can also save the small copy and delete the big original (iOS asks first). The result is
/// kept in History too, so leaving the screen never loses it.
struct KeepShare: View {
    enum Lead { case save, share }

    let urls: [URL]
    var lead: Lead = .save
    var tool: String = ""
    /// The Photos item this result replaces (shrink tools), and its size — for "Save and delete the original".
    var original: String? = nil
    var originalBytes: Int = 0
    /// Results made inside Build your own are already kept in History by the runner.
    var record = true

    @State private var saved: Where?
    @State private var note: String?
    @State private var exporting = false
    @State private var working = false
    @State private var originalGone = false
    enum Where { case photos, files }

    init(_ items: [KeepItem], lead: Lead = .save, tool: String = "", original: String? = nil, originalBytes: Int = 0, record: Bool = true) {
        self.urls = items.compactMap(KeepFiles.url)
        self.lead = lead; self.tool = tool; self.original = original; self.originalBytes = originalBytes; self.record = record
    }
    init(_ url: URL, lead: Lead = .save, tool: String = "", original: String? = nil, originalBytes: Int = 0, record: Bool = true) {
        self.init([.file(url)], lead: lead, tool: tool, original: original, originalBytes: originalBytes, record: record)
    }

    private var toPhotos: Bool { KeepFiles.belongsInPhotos(urls) }
    private var many: Bool { urls.count > 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(spacing: HandySpacing.s8) {
                if lead == .share { share.primaryButton(); save.secondaryButton() }
                else { save.primaryButton(); share.secondaryButton() }
            }
            if let o = original, !o.isEmpty, toPhotos, !originalGone, originalBytes > 0 {
                Button { Task { await saveAndDeleteOriginal() } } label: {
                    Label("\(L("Save and delete the big original")) · \(L("frees")) \(SizeTarget.format(max(0, originalBytes - totalBytes)))", systemImage: "trash.slash")
                        .font(HandyFont.caption).frame(maxWidth: .infinity)
                }
                .textButton().disabled(working).accessibilityIdentifier("keep-replace")
            }
            if let saved {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(HandyColor.success)
                    Text(saved == .photos ? (originalGone ? L("Saved to Photos — the big original was deleted") : L("Saved to Photos")) : L("Saved to Files"))
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary)
                    Spacer(minLength: 0)
                    if saved == .photos, let u = URL(string: "photos-redirect://") {
                        Button(L("Open Photos")) { UIApplication.shared.open(u) }.font(HandyFont.caption)
                    }
                }
                .accessibilityIdentifier("keep-saved")
            }
            if let note {
                Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: urls.map(\.path).joined()) {
            if record, !urls.isEmpty, KeepFiles.firstSighting(urls) {
                let files = urls, name = tool
                Task.detached(priority: .utility) { RunHistory.add(Outbox(files: files), tool: name) }
            }
        }
        .sheet(isPresented: $exporting) {
            FilesExporter(urls: urls) { ok in exporting = false; if ok { saved = .files; note = nil; RatingAsk.keptSomething() } }.ignoresSafeArea()
        }
    }

    private var totalBytes: Int { urls.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0) } }

    private var save: some View {
        Button {
            if toPhotos { Task { await saveToPhotos() } } else { exporting = true }
        } label: {
            Label(toPhotos ? (many ? "\(L("Save all to Photos")) (\(urls.count))" : L("Save to Photos")) : (many ? "\(L("Save all to Files")) (\(urls.count))" : L("Save to Files")),
                  systemImage: toPhotos ? "photo.on.rectangle" : "folder")
                .lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity)
        }
        .disabled(urls.isEmpty || working)
        .accessibilityIdentifier("keep-save")
    }

    private var share: some View {
        ShareLink(items: urls) { Label(L("Share"), systemImage: "square.and.arrow.up").lineLimit(1).frame(maxWidth: .infinity) }
            .disabled(urls.isEmpty)
            .accessibilityIdentifier("keep-share")
    }

    @MainActor private func saveToPhotos() async {
        working = true; defer { working = false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            note = L("Tenzy isn't allowed to add to Photos. Turn it on in Settings › Apps › Tenzy › Photos — or save to Files instead.")
            exporting = true
            return
        }
        do {
            let files = urls
            try await PHPhotoLibrary.shared().performChanges {
                for u in files {
                    PHAssetCreationRequest.forAsset().addResource(with: KeepFiles.isVideo(u) ? .video : .photo, fileURL: u, options: nil)
                }
            }
            saved = .photos; note = nil
            RatingAsk.keptSomething()
        } catch {
            note = L("Photos couldn't take this file, so it's offered as a file instead.")
            exporting = true
        }
    }

    /// The small copy goes into Photos first; only then is the original deleted, and iOS asks the person to confirm.
    @MainActor private func saveAndDeleteOriginal() async {
        if saved != .photos { await saveToPhotos() }
        guard saved == .photos, let id = original else { return }
        working = true; defer { working = false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let found = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard status == .authorized || status == .limited, found.count > 0 else {
            note = L("The small copy is in Photos. Tenzy can't reach the original from here — delete it in Photos; it's just before the new one.")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(found) }
            originalGone = true
            note = L("It's in Recently Deleted for 30 days if you change your mind.")
        } catch {
            note = L("The original was kept.")
        }
    }
}

/// The system "Save to Files" picker: the person chooses the folder; the file is copied there.
struct FilesExporter: UIViewControllerRepresentable {
    let urls: [URL]
    var done: (Bool) -> Void
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let p = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(done: done) }
    final class Coord: NSObject, UIDocumentPickerDelegate {
        let done: (Bool) -> Void
        init(done: @escaping (Bool) -> Void) { self.done = done }
        func documentPicker(_ c: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { done(true) }
        func documentPickerWasCancelled(_ c: UIDocumentPickerViewController) { done(false) }
    }
}

extension Chain {
    /// A ready-made or built tool whose job is sending (shrink to a size, make it easy to send, chat-ready) ends with
    /// Share as the big button; every other tool leads with Save.
    var keepLead: KeepShare.Lead {
        let sending: Set<Block> = [.shrinkImage, .videoShrink, .pdfShrink, .chatLink]
        return steps.contains { sending.contains($0.block) } ? .share : .save
    }
}
