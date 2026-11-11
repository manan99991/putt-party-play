import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// One shared item's outcome.
struct ShareResult: Identifiable {
    let id = UUID()
    let n: Int
    var url: URL?
    var text: String?
    var note: String?
}

@MainActor
final class ShareModel: ObservableObject {
    enum Phase: Equatable { case loading, pick, running(String), done, saved, nothing }

    @Published var phase: Phase = .loading
    @Published var tools: [Chain] = []
    @Published var results: [ShareResult] = []
    @Published var copied = false

    /// Shared photos are copied to a private folder and opened one at a time, so a batch never sits in memory together.
    private(set) var photos: [URL] = []
    private(set) var text: String?
    var finish: () -> Void = {}
    var shareOn: ([Any]) -> Void = { _ in }

    private let dir: URL = {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-share-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    var isText: Bool { photos.isEmpty }
    var summary: String {
        if !photos.isEmpty { return photos.count == 1 ? "1 photo" : "\(photos.count) photos" }
        return text ?? ""
    }

    func load(_ providers: [NSItemProvider], typedText: String?) async {
        var n = 0
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            n += 1
            if let u = await ShareModel.copyImage(p, to: dir, n: n) { photos.append(u) }
        }
        if photos.isEmpty {
            for p in providers {
                if p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let s = try? await p.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String { text = s; break }
                if p.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let u = try? await p.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL { text = u.absoluteString; break }
            }
            if text == nil { text = typedText }
        }
        if photos.isEmpty && (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { phase = .nothing; return }
        tools = ChainStore.offers(for: isText ? .text : .image, mine: ChainStore.load(), last: ChainStore.lastShared)
        phase = .pick
    }

    func saveToClips() {
        guard let text else { return }
        ClipStore.add(text)
        phase = .saved
        Task { try? await Task.sleep(for: .milliseconds(800)); finish() }
    }

    /// Runs the tool on everything that was shared. One item failing never stops the others; it gets its own note.
    func run(_ chain: Chain) {
        ChainStore.lastShared = chain.id
        results = []
        Task {
            var out: [ShareResult] = []
            if isText {
                phase = .running("Working…")
                out.append(await one(chain, input: .text(text ?? ""), n: 1))
            } else {
                for (i, u) in photos.enumerated() {
                    phase = .running(photos.count == 1 ? "Working…" : "Working… \(i + 1) of \(photos.count)")
                    guard let img = ShareModel.downsized(u) else { out.append(ShareResult(n: i + 1, note: "Couldn't open this photo.")); continue }
                    out.append(await one(chain, input: .image(img), n: i + 1))
                }
            }
            results = out
            phase = .done
        }
    }

    private func one(_ chain: Chain, input: ChainPayload, n: Int) async -> ShareResult {
        switch await ChainRunner.run(chain, input: input) {
        case .success(let p): return ShareModel.write(p, n: n, dir: dir)
        case .failure(let f): return ShareResult(n: n, note: ShareModel.words(f))
        }
    }

    var files: [URL] { results.compactMap(\.url) }
    var texts: [String] { results.compactMap(\.text) }
    var okCount: Int { results.filter { $0.note == nil }.count }

    func shareResults() {
        if !files.isEmpty { shareOn(files) } else if !texts.isEmpty { shareOn([texts.joined(separator: "\n\n")]) }
    }
    func copyText() {
        UIPasteboard.general.string = texts.joined(separator: "\n\n")
        copied = true
    }

    // MARK: helpers (static so they are easy to reason about)

    static func write(_ p: ChainPayload, n: Int, dir: URL) -> ShareResult {
        func file(_ d: Data, _ ext: String) -> ShareResult {
            let u = dir.appendingPathComponent("Tenzy-\(n).\(ext)")
            return (try? d.write(to: u)) != nil ? ShareResult(n: n, url: u) : ShareResult(n: n, note: "Couldn't save this result.")
        }
        switch p {
        case .text(let t): return ShareResult(n: n, text: t)
        case .image(let i): return i.jpegData(compressionQuality: 0.92).map { file($0, "jpg") } ?? ShareResult(n: n, note: "Couldn't save this result.")
        case .file(let d, let ext): return file(d, ext)
        }
    }

    static func words(_ f: ChainRunner.Failure) -> String {
        switch f {
        case .invalid(let why): return why
        case .wrongInput(let b): return "\(b.title) can't work with this."
        case .nothingFound(.businessCard): return "Make a contact needs a phone number or an email, and didn't find one."
        case .nothingFound(let b): return b.takes == .text ? "\(b.title) didn't find anything in that text." : "\(b.title) didn't find anything in it."
        case .failed(let b): return "\(b.title) couldn't finish on this one."
        }
    }

    /// Opens a photo at sharing size (longest side up to 3000 px) without ever decoding the full original,
    /// which keeps a 48 MP photo inside the small memory a share sheet is allowed.
    static func downsized(_ url: URL, maxPixel: CGFloat = 3000) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    static func copyImage(_ p: NSItemProvider, to dir: URL, n: Int) async -> URL? {
        await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            _ = p.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                if let url {
                    let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                    let dst = dir.appendingPathComponent("in-\(n).\(ext)")
                    if (try? FileManager.default.copyItem(at: url, to: dst)) != nil { cont.resume(returning: dst); return }
                }
                // Some apps hand over the picture as data instead of a file.
                _ = p.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    let dst = dir.appendingPathComponent("in-\(n).img")
                    if let data, (try? data.write(to: dst)) != nil { cont.resume(returning: dst) } else { cont.resume(returning: nil) }
                }
            }
        }
    }
}

struct ShareRunView: View {
    @ObservedObject var model: ShareModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Tenzy")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { model.finish() } label: { Image(systemName: "xmark") }.accessibilityLabel("Close")
                    }
                }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView("Getting it ready…").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .running(let label):
            ProgressView(label).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .saved:
            Label("Saved to Clips", systemImage: "checkmark.circle.fill").font(.title3.bold()).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .nothing:
            VStack(spacing: 12) {
                Text("Tenzy can run your tools on photos and text.").multilineTextAlignment(.center)
                Button("Close") { model.finish() }.buttonStyle(.borderedProminent)
            }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .pick: picker
        case .done: done
        }
    }

    private var picker: some View {
        List {
            Section {
                Text(model.summary).lineLimit(3).foregroundStyle(.secondary)
            } header: { Text("You shared") }
            if model.isText {
                Section {
                    Button { model.saveToClips() } label: { Label("Save to Clips", systemImage: "doc.on.clipboard") }
                }
            }
            Section {
                ForEach(model.tools) { c in
                    Button { model.run(c) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(c.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                            Text(c.steps.map(\.block.title).joined(separator: " → ")).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("share-tool-\(c.id)")
                }
            } header: { Text("Run a tool") } footer: {
                Text(model.isText ? "Make more in Tenzy, under Build your own." : "Photos are sized for sharing (up to 3000 px on the long side). Make more tools in Tenzy, under Build your own.")
            }
        }
    }

    private var done: some View {
        List {
            Section {
                if model.results.count > 1 { Text("\(model.okCount) of \(model.results.count) done").font(.headline) }
                ForEach(model.results) { r in
                    if let note = r.note {
                        Label(model.results.count > 1 ? "Photo \(r.n): \(note)" : note, systemImage: "exclamationmark.circle").foregroundStyle(.secondary)
                    } else if let t = r.text {
                        Text(t).textSelection(.enabled)
                    } else if let u = r.url {
                        Label(model.results.count > 1 ? "Photo \(r.n) is ready" : "Ready: \(u.pathExtension.uppercased()) file", systemImage: "checkmark.circle.fill")
                    }
                }
            }
            Section {
                if !model.files.isEmpty || !model.texts.isEmpty {
                    Button { model.shareResults() } label: { Label(model.files.count > 1 ? "Share all \(model.files.count)" : "Share", systemImage: "square.and.arrow.up") }
                        .accessibilityIdentifier("share-on")
                }
                if !model.texts.isEmpty {
                    Button { model.copyText() } label: { Label(model.copied ? "Copied" : "Copy", systemImage: "doc.on.doc") }
                }
                Button("Done") { model.finish() }
            }
        }
    }
}
