import SwiftUI

/// One finished run, kept so a result isn't lost when its screen is closed.
struct HistoryItem: Codable, Identifiable, Equatable {
    var id: String
    var tool: String
    var when: Date
    /// File names inside the history folder. Empty for a text result.
    var files: [String] = []
    var text: String?
}

/// The last results your tools made. Kept on this phone only, in the app's own folder; the oldest drop off after
/// twenty, and Clear removes them all.
enum RunHistory {
    static let limit = 20
    /// A result bigger than this is not kept (a long video would fill the phone); it is still shown and shared as usual.
    static let biggest = 150 * 1_048_576

    private static var folder: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("History", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private static var index: URL { folder.appendingPathComponent("index.json") }

    static func all() -> [HistoryItem] {
        guard let d = try? Data(contentsOf: index), let items = try? JSONDecoder().decode([HistoryItem].self, from: d) else { return [] }
        return items
    }
    private static func save(_ items: [HistoryItem]) {
        if let d = try? JSONEncoder().encode(items) { try? d.write(to: index, options: .atomic) }
    }
    static func url(_ item: HistoryItem, _ file: String) -> URL { folder.appendingPathComponent(item.id, isDirectory: true).appendingPathComponent(file) }
    static func urls(_ item: HistoryItem) -> [URL] { item.files.map { url(item, $0) }.filter { FileManager.default.fileExists(atPath: $0.path) } }

    /// The newest first, at most `limit`. Pure, so it is unit-tested.
    static func kept(_ items: [HistoryItem], limit: Int = limit) -> [HistoryItem] {
        Array(items.sorted { $0.when > $1.when }.prefix(max(0, limit)))
    }

    /// Keeps a copy of what a run made. Never fails the run: anything that can't be copied is simply not kept.
    static func add(_ box: Outbox, tool: String) {
        var item = HistoryItem(id: UUID().uuidString, tool: tool.isEmpty ? "Tool" : tool, when: Date())
        let home = folder.appendingPathComponent(item.id, isDirectory: true)
        var total = 0
        for src in box.files {
            let size = (try? src.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            guard total + size <= biggest else { continue }
            try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
            if (try? FileManager.default.copyItem(at: src, to: home.appendingPathComponent(src.lastPathComponent))) != nil { item.files.append(src.lastPathComponent); total += size }
        }
        if let t = box.text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty { item.text = String(t.prefix(50_000)) }
        guard !item.files.isEmpty || item.text != nil else { return }
        let before = all()
        let now = kept(before + [item])
        for gone in before where !now.contains(where: { $0.id == gone.id }) { try? FileManager.default.removeItem(at: folder.appendingPathComponent(gone.id)) }
        save(now)
    }

    static func remove(_ item: HistoryItem) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(item.id))
        save(all().filter { $0.id != item.id })
    }
    static func clear() {
        for i in all() { try? FileManager.default.removeItem(at: folder.appendingPathComponent(i.id)) }
        save([])
    }

    /// "3 files · 2.1 MB", "Photo · 640 KB" or the first words of a text result.
    static func summary(_ item: HistoryItem) -> String {
        let found = urls(item)
        if found.isEmpty { return String((item.text ?? "").replacingOccurrences(of: "\n", with: " ").prefix(80)) }
        let bytes = found.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0) }
        let what = found.count == 1 ? found[0].pathExtension.uppercased() : "\(found.count) files"
        return what + " · " + SizeTarget.format(bytes)
    }
}

/// Recent results: open one again to share or copy it, remove one, or clear them all.
struct HistoryView: View {
    @State private var items = RunHistory.all()
    @State private var clearing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                Text("The last \(RunHistory.limit) things your tools made. They stay on this phone until you clear them.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                if items.isEmpty {
                    Text("Nothing yet. Run a tool and its result appears here.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).cardStyle()
                }
                ForEach(items) { item in card(item) }
            }.padding(HandySpacing.gutter)
        }
        .background(HandyColor.bg)
        .navigationTitle("Recent results").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            ToolbarItem(placement: .cancellationAction) { if !items.isEmpty { Button("Clear") { clearing = true }.accessibilityIdentifier("history-clear") } }
        }
        .confirmationDialog("Clear every recent result?", isPresented: $clearing, titleVisibility: .visible) {
            Button("Clear them all", role: .destructive) { RunHistory.clear(); items = [] }
            Button("Keep them", role: .cancel) {}
        } message: { Text("They are removed from this phone. Anything you already saved or sent is not touched.") }
    }

    private func card(_ item: HistoryItem) -> some View {
        let urls = RunHistory.urls(item)
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(alignment: .top, spacing: HandySpacing.s12) {
                if let first = urls.first, ["jpg", "jpeg", "png", "gif", "heic"].contains(first.pathExtension.lowercased()), let img = UIImage(contentsOfFile: first.path) {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.tool).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    Text(item.when.formatted(date: .abbreviated, time: .shortened)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Text(RunHistory.summary(item)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: HandySpacing.s8) {
                if !urls.isEmpty {
                    ShareLink(items: urls) { Label("Save or share", systemImage: "square.and.arrow.up") }.font(HandyFont.caption)
                } else if let t = item.text {
                    ShareLink(item: t) { Label("Share", systemImage: "square.and.arrow.up") }.font(HandyFont.caption)
                    Button { UIPasteboard.general.string = t } label: { Label("Copy", systemImage: "doc.on.doc") }.font(HandyFont.caption)
                }
                Spacer()
                Button(role: .destructive) { RunHistory.remove(item); items = RunHistory.all() } label: { Label("Remove", systemImage: "trash") }.font(HandyFont.caption)
            }
        }.cardStyle(padding: HandySpacing.s12)
    }
}

/// A tool as a QR code and a link, to hand to someone else. Shown only once the link page is live (`ToolLink.live`).
struct ToolLinkSheet: View {
    let chain: Chain
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let link = ToolLink.link(for: chain)
        return ScrollView {
            VStack(spacing: HandySpacing.s16) {
                Text(chain.name).font(HandyFont.title)
                if let link, let code = ChainText.qr(link) {
                    Image(uiImage: code).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 260).padding(HandySpacing.s12).background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("QR code for this tool")
                    Text("Point another phone's camera at this, or send the link. It opens the tool in Tenzy.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                    ShareLink(item: link) { Label("Send the link", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
                } else {
                    Text("This tool is too big to fit in a QR code. Use Copy to share instead.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                    if let link { ShareLink(item: link) { Label("Send the link", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton() }
                }
                Text("The link never carries your email addresses, phone numbers, reminders or a PDF password.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            }.padding(HandySpacing.gutter)
        }
        .background(HandyColor.bg)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}
