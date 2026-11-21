import QuickLookThumbnailing
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
    /// The tool that was run, so its own ending (email it, message it) can be offered on the result screen.
    @Published private(set) var ran: Chain?

    /// Shared photos are copied to a private folder and opened one at a time, so a batch never sits in memory together.
    private(set) var photos: [URL] = []
    /// Shared PDFs, copied the same way. A share is photos, or PDFs, or text; never a mix.
    private(set) var pdfs: [URL] = []
    private(set) var text: String?
    var finish: () -> Void = {}
    var shareOn: ([Any]) -> Void = { _ in }

    private let dir: URL = {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-share-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    var isText: Bool { photos.isEmpty && pdfs.isEmpty }
    /// What each result is called in the list.
    var noun: String { pdfs.isEmpty ? "Photo" : "PDF" }
    var summary: String {
        if !photos.isEmpty { return photos.count == 1 ? "1 photo" : "\(photos.count) photos" }
        if !pdfs.isEmpty { return pdfs.count == 1 ? "1 PDF" : "\(pdfs.count) PDFs" }
        return text ?? ""
    }

    func load(_ providers: [NSItemProvider], typedText: String?) async {
        var n = 0
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            n += 1
            if let u = await ShareModel.copyImage(p, to: dir, n: n) { photos.append(u) }
        }
        if photos.isEmpty {
            for p in providers where p.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                n += 1
                if let u = await ShareModel.copyFile(p, type: UTType.pdf, to: dir, name: "in-\(n).pdf") { pdfs.append(u) }
            }
        }
        if photos.isEmpty && pdfs.isEmpty {
            for p in providers {
                if p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let s = try? await p.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String { text = s; break }
                if p.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let u = try? await p.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL, !u.isFileURL { text = u.absoluteString; break }   // a file's own address is not a link
            }
            if text == nil { text = typedText }
        }
        if isText && (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { phase = .nothing; return }
        tools = ChainStore.offers(for: isText ? .text : pdfs.isEmpty ? .image : .pdf, mine: ChainStore.load(), last: ChainStore.lastShared)
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
        ran = chain
        results = []; joined = nil
        Task {
            var out: [ShareResult] = []
            if isText {
                phase = .running("Working…")
                out.append(await one(chain, input: .text(text ?? ""), n: 1))
            } else if !pdfs.isEmpty {
                for (i, u) in pdfs.enumerated() {
                    phase = .running(pdfs.count == 1 ? "Working…" : "Working… \(i + 1) of \(pdfs.count)")
                    guard let d = try? Data(contentsOf: u) else { out.append(ShareResult(n: i + 1, note: "Couldn't open this PDF.")); continue }
                    out.append(await one(chain, input: .file(d, ext: "pdf"), n: i + 1))
                }
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
        case .success(let p): return ShareModel.write(p, n: n, dir: dir, named: chain.fileName, tool: chain.name, many: photos.count + pdfs.count > 1)
        case .failure(let f): return ShareResult(n: n, note: ShareModel.words(f))
        }
    }

    /// Several PDFs made at once can go out as one file (the same choice as in the app).
    @Published var joinPDFs = true
    private var joined: URL?   // made once, the first time it's needed (not published: it's read while drawing)
    var canJoin: Bool { PDFMerge.canMerge(results.compactMap(\.url)) }
    var files: [URL] {
        let all = results.compactMap(\.url)
        if joinPDFs, canJoin {
            if joined == nil { joined = PDFMerge.merge(all, name: ran?.name ?? "Combined") }
            if let j = joined { return [j] }
        }
        return all
    }
    var texts: [String] { results.compactMap(\.text) }
    var okCount: Int { results.filter { $0.note == nil }.count }

    func shareResults() {
        if !files.isEmpty { shareOn(files) } else if !texts.isEmpty { shareOn([texts.joined(separator: "\n\n")]) }
    }
    var ending: ChainFinish? { (files.isEmpty && texts.isEmpty) ? nil : ShareEnding.of(ran) }
    var outbox: Outbox { Outbox(text: texts.isEmpty ? nil : texts.joined(separator: "\n\n"), files: files) }

    func copyText() {
        UIPasteboard.general.string = texts.joined(separator: "\n\n")
        copied = true
    }

    // MARK: helpers (static so they are easy to reason about)

    /// - Parameters named/tool/many: the tool's own file name, when it has one, wins over the plain "Tenzy-1".
    static func write(_ p: ChainPayload, n: Int, dir: URL, named: String? = nil, tool: String = "", many: Bool = true) -> ShareResult {
        func file(_ d: Data, _ ext: String) -> ShareResult {
            let name = (named ?? "").trimmingCharacters(in: .whitespaces).isEmpty ? "Tenzy-\(n).\(ext)" : ChainName.file(pattern: named, tool: tool, index: many ? n : nil, ext: ext)
            let u = dir.appendingPathComponent(name)
            return (try? d.write(to: u)) != nil ? ShareResult(n: n, url: u) : ShareResult(n: n, note: "Couldn't save this result.")
        }
        switch p {
        case .text(let t): return ShareResult(n: n, text: t)
        case .image(let i): return i.jpegData(compressionQuality: 0.92).map { file($0, "jpg") } ?? ShareResult(n: n, note: "Couldn't save this result.")
        case .file(let d, let ext): return file(d, ext)
        case .video(let u): return ShareResult(n: n, url: u)
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

    /// A shared file of one kind (a PDF), copied into the private folder under `name`.
    static func copyFile(_ p: NSItemProvider, type: UTType, to dir: URL, name: String) async -> URL? {
        await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            _ = p.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                let dst = dir.appendingPathComponent(name)
                if let url, (try? FileManager.default.copyItem(at: url, to: dst)) != nil { cont.resume(returning: dst); return }
                // Some apps hand the file over as data instead.
                _ = p.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                    if let data, (try? data.write(to: dst)) != nil { cont.resume(returning: dst) } else { cont.resume(returning: nil) }
                }
            }
        }
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
    @State private var sending = false

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
            ShareWorking(title: "Getting it ready…", label: "", block: nil)
        case .running(let label):
            ShareWorking(title: model.ran?.name ?? "Working", label: label, block: model.ran?.steps.last?.block)
        case .saved:
            Label("Saved to Clips", systemImage: "checkmark.circle.fill").font(.title3.bold()).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .nothing:
            VStack(spacing: 12) {
                Text("Tenzy can run your tools on photos, PDFs, links and text from here. For a video or a recording, open Tenzy and tap Start with what you have.").multilineTextAlignment(.center)
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
                        // The same face as in the app: the tool's mark in its colour, its name, the steps it runs.
                        HStack(spacing: 12) {
                            if let b = c.steps.last?.block { BlockBadge(block: b, size: 40) }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(c.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                Text(c.steps.map(\.block.title).joined(separator: " → ")).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .accessibilityIdentifier("share-tool-\(c.id)")
                }
            } header: { Text("Run a tool") } footer: {
                Text(model.isText || !model.pdfs.isEmpty ? "Make more in Tenzy, under Build your own." : "Photos are sized for sharing (up to 3000 px on the long side). Make more tools in Tenzy, under Build your own.")
            }
        }
    }

    private var done: some View {
        List {
            Section {
                if model.results.count > 1 { Text("\(model.okCount) of \(model.results.count) done").font(.headline) }
                ForEach(model.results) { r in
                    if let note = r.note {
                        Label(model.results.count > 1 ? "\(model.noun) \(r.n): \(note)" : note, systemImage: "exclamationmark.circle").foregroundStyle(.secondary)
                    } else if let t = r.text {
                        Text(t).textSelection(.enabled)
                    } else if let u = r.url {
                        // See what was made before sharing it: the picture, or the PDF's first page.
                        VStack(alignment: .leading, spacing: 8) {
                            Label(model.results.count > 1 ? "\(model.noun) \(r.n) is ready" : "Ready: \(u.pathExtension.uppercased()) file", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            SharePreviewThumb(url: u)
                        }
                    }
                }
            }
            if model.canJoin {
                Section {
                    Picker("", selection: $model.joinPDFs) {
                        Text("One PDF").tag(true)
                        Text("\(model.results.compactMap(\.url).count) separate PDFs").tag(false)
                    }
                    .pickerStyle(.segmented).accessibilityIdentifier("share-merge")
                } header: { Text("How to save them") }
            }
            Section {
                // The tool's own ending first: the email or message opens filled in, and the person taps Send.
                if let f = model.ending, SendSheet.canSend(f.kind) {
                    Button { sending = true } label: { Label(f.label, systemImage: f.kind == .mail ? "envelope" : "message") }
                        .accessibilityIdentifier("share-finish")
                }
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
        .sheet(isPresented: $sending) {
            if let f = model.ending { SendSheet(finish: f, subject: model.ran?.name ?? "Tenzy", box: model.outbox).ignoresSafeArea() }
        }
    }
}


/// What the share sheet shows while a tool works: the tool's mark breathing in its colour, what's happening, and a
/// running clock once it passes two seconds — so it never looks frozen.
struct ShareWorking: View {
    let title: String
    let label: String
    let block: Block?
    @State private var started = Date()
    @State private var breathe = false
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill((block?.tint ?? .accentColor).opacity(0.16)).frame(width: 84, height: 84)
                    .scaleEffect(breathe ? 1.1 : 0.92)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: breathe)
                if let block { BlockBadge(block: block, size: 52) } else { ProgressView() }
            }
            .accessibilityHidden(true)
            Text(title).font(.headline).multilineTextAlignment(.center)
            HStack(spacing: 6) {
                ProgressView()
                TimelineView(.periodic(from: started, by: 1)) { ctx in
                    let s = Int(ctx.date.timeIntervalSince(started))
                    let clock = s >= 2 ? String(format: " · %d:%02d", s / 60, s % 60) : ""
                    Text((label.isEmpty ? "Working…" : label) + clock).font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { breathe = true }
    }
}

/// A small picture of a finished file (photo or PDF page), made by the system's own thumbnailer.
struct SharePreviewThumb: View {
    let url: URL
    @State private var thumb: UIImage?
    var body: some View {
        Group {
            if let thumb {
                Image(uiImage: thumb).resizable().scaledToFit().frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel(Text("Preview of the result"))
            }
        }
        .task(id: url) {
            let req = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 600, height: 600), scale: 2, representationTypes: .thumbnail)
            thumb = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: req).uiImage
        }
    }
}
