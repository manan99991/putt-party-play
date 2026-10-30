import SwiftUI
import PDFKit
import QuickLook
import UniformTypeIdentifiers

/// Documents — scan, sign, merge, find. Scan and Sign & fill are the deep legacy Scan tool opened
/// on the right mode; Merge & split is a thin PDFKit layer (PDFTools); Word Finder is new (WordFinder).
struct DocumentsHub: View {
    @EnvironmentObject var store: StoreManager
    @State private var tab = 0

    // merge & split
    @State private var items: [PDFTools.Item] = []
    @State private var showPDFPicker = false
    @State private var splitSpec = ""
    @State private var working = false
    @State private var busyLabel = ""
    @State private var outputs: [URL] = []
    @State private var outputText = ""
    @State private var errorText: String?

    // word finder
    @StateObject private var finder = WordFinder()
    @State private var query = ""
    @State private var showFilePicker = false
    @State private var showFolderPicker = false
    @State private var preview: PreviewItem?

    private struct PreviewItem: Identifiable { let url: URL; var id: String { url.path } }
    private var overQuota: Bool { !Usage.hasRoom("pdfops", limit: Limits.freePdfOpsPerDay) }

    var body: some View {
        PowerToolPage(id: "documents", tabs: ["Scan", "Sign & fill", "Merge & split", "Word Finder"], selected: $tab) {
            Group {
                if tab < 2 {
                    // One Scan instance for both tabs so pages survive switching; the mode follows the tab.
                    ScanView(initialMode: tab == 0 ? .pages : .sign).environment(\.embeddedInHub, true)
                } else if tab == 2 {
                    mergeTab
                } else {
                    finderTab
                }
            }
        }
        .sheet(item: $preview) { p in DocQuickLook(url: p.url).ignoresSafeArea().onDisappear { finder.releaseScopes() } }
        .onChange(of: query) { _, q in finder.search(q) }
        .onChange(of: finder.indexing) { _, busy in if !busy { finder.search(query) } }
    }

    // MARK: - Merge & split

    private var mergeTab: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HubPreviewBox(minHeight: 150) {
                if items.isEmpty {
                    VStack(spacing: HandySpacing.s8) {
                        Image(systemName: "doc.on.doc").font(.system(size: 28)).foregroundStyle(HandyColor.accent)
                        Text("Pick 2 or more PDFs to merge, or one to split.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                    }.padding(HandySpacing.s16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, it in
                            HStack(spacing: HandySpacing.s12) {
                                Image(systemName: "doc.richtext.fill").font(.system(size: 22)).foregroundStyle(HandyColor.accent).frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(it.name).font(HandyFont.bodyStrong).lineLimit(1)
                                    Text("\(it.pages) page\(it.pages == 1 ? "" : "s") · \(PDFTools.format(it.bytes))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                                }
                                Spacer(minLength: 0)
                                Button { if i > 0 { items.swapAt(i, i - 1); outputs = [] } } label: { Image(systemName: "chevron.up") }.textButton().disabled(i == 0).accessibilityLabel("Move \(it.name) up")
                                Button { if i + 1 < items.count { items.swapAt(i, i + 1); outputs = [] } } label: { Image(systemName: "chevron.down") }.textButton().disabled(i >= items.count - 1).accessibilityLabel("Move \(it.name) down")
                                Button(role: .destructive) { if items.indices.contains(i) { items.remove(at: i); outputs = [] } } label: { Image(systemName: "xmark") }.textButton().accessibilityLabel("Remove \(it.name)")
                            }
                            .padding(.horizontal, HandySpacing.s12).padding(.vertical, HandySpacing.s8)
                            if i < items.count - 1 { Divider().padding(.leading, 52) }
                        }
                    }.padding(.vertical, HandySpacing.s4)
                }
            }
            HStack(spacing: HandySpacing.s8) {
                Button { showPDFPicker = true } label: { Label("Pick PDFs", systemImage: "plus").frame(maxWidth: .infinity) }.primaryButton()
                Button { useSamples() } label: { Text("Use samples").frame(maxWidth: .infinity) }.secondaryButton().disabled(working)
            }
            HStack(spacing: HandySpacing.s8) {
                Button { run("Merging…", "merged.pdf") { PDFTools.merge($0).map { [$0] } ?? [] } } label: { Text("Merge → one PDF").frame(maxWidth: .infinity) }
                    .primaryButton().disabled(items.count < 2 || working || overQuota)
                Button { let spec = splitSpec; run("Splitting…", "part.pdf") { $0.first.map { PDFTools.split($0, spec: spec) } ?? [] } } label: { Text("Split pages").frame(maxWidth: .infinity) }
                    .secondaryButton().disabled(items.count != 1 || working || overQuota)
            }
            if items.count == 1 {
                TextField("Ranges, e.g. 1-2, 3, 4-  (blank = every page on its own)", text: $splitSpec)
                    .padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            }
            FlowLayout(spacing: 6) {
                HubChip("Compress", selected: false) { run("Compressing…", "compressed.pdf") { $0.compactMap { PDFTools.compress($0, maxWidth: 1000, quality: 0.45) } } }
                HubChip("Rotate pages", selected: false) { run("Rotating…", "rotated.pdf") { $0.compactMap { PDFTools.rotate($0) } } }
                HubChip("Reorder", selected: false) { errorText = items.count < 2 ? "Add two or more PDFs, then use the arrows next to each file." : "Use the arrows next to each file to change the order." }
                HubChip("PDF → images", selected: false) { runImages() }
            }
            .disabled(items.isEmpty || working || overQuota)
            .opacity(items.isEmpty ? 0.55 : 1)

            Group {
                if !store.isPremium { QuotaChip(name: "pdfops", limit: Limits.freePdfOpsPerDay).environmentObject(store) }
                if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freePdfOpsPerDay) free PDF jobs.") }
                if working { HStack(spacing: HandySpacing.s8) { ProgressView().tint(HandyColor.accent); Text(busyLabel).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
                if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            }
            if !outputs.isEmpty {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    HStack(spacing: HandySpacing.s8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(HandyColor.success)
                        Text(outputText).font(HandyFont.bodyStrong)
                    }
                    ShareLink(items: outputs) { Label(outputs.count == 1 ? "Save or share" : "Save or share all", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
                }.cardStyle(padding: HandySpacing.s12)
            }
            HubNote("Merge, split and rotate move pages losslessly. Compress re-renders pages smaller and keeps them searchable. Everything stays on this phone.")
        }
        .fileImporter(isPresented: $showPDFPicker, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { res in
            if case .success(let urls) = res { addPDFs(urls) }
        }
    }

    private func addPDFs(_ urls: [URL]) {
        working = true; busyLabel = "Reading…"; errorText = nil
        Task.detached(priority: .userInitiated) {
            let got = urls.compactMap { PDFTools.load($0) }
            await MainActor.run {
                working = false
                if got.isEmpty { errorText = "Couldn't read those PDFs." } else { items.append(contentsOf: got); outputs = [] }
            }
        }
    }

    private func useSamples() {
        working = true; busyLabel = "Making samples…"; errorText = nil
        Task.detached(priority: .userInitiated) {
            var got: [PDFTools.Item] = []
            for (name, img) in [("Lease_2026.pdf", SampleAssets.document()), ("Receipt.pdf", SampleAssets.receipt())] {
                if let d = DocEngine.pdf(images: [img], ocr: [nil], options: DocEngine.PDFOptions(searchable: false)), let u = PDFTools.write(d, name: name), let it = PDFTools.load(u) { got.append(it) }
            }
            let out = got
            await MainActor.run { working = false; items.append(contentsOf: out); outputs = [] }
        }
    }

    /// Run a PDF job off the main thread; the free counter is consumed only once files exist.
    private func run(_ label: String, _ name: String, _ job: @escaping ([PDFTools.Item]) -> [Data]) {
        guard !items.isEmpty, !overQuota else { return }
        working = true; busyLabel = label; errorText = nil; outputs = []
        let snapshot = items
        Task.detached(priority: .userInitiated) {
            let datas = job(snapshot)
            var urls: [URL] = []
            for (i, d) in datas.enumerated() {
                let base = (name as NSString).deletingPathExtension
                if let u = PDFTools.write(d, name: datas.count == 1 ? name : "\(base)-\(i + 1).pdf") { urls.append(u) }
            }
            let out = urls, total = datas.reduce(0) { $0 + $1.count }
            await MainActor.run { finish(out, text: out.count == 1 ? "PDF ready — \(PDFTools.format(total))" : "\(out.count) PDFs ready — \(PDFTools.format(total)) total") }
        }
    }

    private func runImages() {
        guard !items.isEmpty, !overQuota else { return }
        working = true; busyLabel = "Rendering pages…"; errorText = nil; outputs = []
        let snapshot = items
        Task.detached(priority: .userInitiated) {
            let urls = snapshot.flatMap { PDFTools.images($0) }
            await MainActor.run { finish(urls, text: "\(urls.count) image\(urls.count == 1 ? "" : "s") ready") }
        }
    }

    private func finish(_ out: [URL], text: String) {
        working = false
        if out.isEmpty { errorText = "That didn't work — try another PDF."; return }
        _ = Usage.use("pdfops", limit: Limits.freePdfOpsPerDay)   // only now, on a real result
        outputs = out; outputText = text; HandyHaptics.success()
    }

    // MARK: - Word Finder

    private var finderTab: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s8) {
                Image(systemName: "magnifyingglass").foregroundStyle(HandyColor.textSecondary)
                TextField("Find a word or phrase across all your documents…", text: $query).autocorrectionDisabled().submitLabel(.search)
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(HandyColor.textSecondary) }.accessibilityLabel("Clear search") }
            }
            .padding(HandySpacing.s12)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))

            FlowLayout(spacing: 6) {
                HubChip("＋ Add files", selected: false) { showFilePicker = true }
                HubChip("＋ Add folder", selected: false) { showFolderPicker = true }
                ForEach(finder.sources) { s in
                    HubChip("\(s.isFolder ? "📁 " : "")\(s.name)  ✕", selected: true) { finder.remove(s) }
                }
                if !finder.sources.isEmpty { HubChip("Re-index", selected: false) { finder.reindex() }.disabled(finder.indexing) }
            }

            if finder.indexing {
                HStack(spacing: HandySpacing.s8) {
                    ProgressView().tint(HandyColor.accent)
                    Text("Indexing \(finder.progress.done) of \(finder.progress.total)…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            if let e = finder.lastError { Text(e).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            resultsBox

            HubSection("Saved passages")
            if finder.saved.isEmpty {
                Text("Nothing saved yet.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    ForEach(finder.saved) { p in
                        HStack(alignment: .top, spacing: HandySpacing.s8) {
                            Image(systemName: "bookmark.fill").foregroundStyle(HandyColor.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.fileName).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                                Text(p.passage).font(HandyFont.body).textSelection(.enabled)
                            }
                            Spacer(minLength: 0)
                            Button { finder.unsave(p) } label: { Image(systemName: "xmark") }.textButton().accessibilityLabel("Remove saved passage")
                        }
                        .padding(HandySpacing.s12)
                        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    }
                }
            }
        }
        // Each picker lives on its own view so the two never fight over one presentation slot.
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: WordFinder.importTypes, allowsMultipleSelection: true) { res in
            if case .success(let urls) = res { finder.add(urls: urls, asFolder: false) }
        }
        .background {
            Color.clear.fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { res in
                if case .success(let urls) = res { finder.add(urls: urls, asFolder: true) }
            }
        }
    }

    @ViewBuilder private var resultsBox: some View {
        if finder.sources.isEmpty {
            HubPreviewBox(minHeight: 170) {
                VStack(spacing: HandySpacing.s12) {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 28)).foregroundStyle(HandyColor.accent)
                    Text("Searches every PDF, Word, Excel, PowerPoint and text file you add — no account, nothing uploaded.")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                    HStack(spacing: HandySpacing.s8) {
                        Button { showFilePicker = true } label: { Label("Add files", systemImage: "doc.badge.plus") }.compactButton()
                        Button { showFolderPicker = true } label: { Label("Add folder", systemImage: "folder.badge.plus") }.compactButton()
                    }
                }.padding(HandySpacing.s16)
            }
        } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
            HubPreviewBox(minHeight: 90) {
                Text(finder.indexing ? "Indexing…" : "\(finder.docs.count) file\(finder.docs.count == 1 ? "" : "s") indexed. Type a word or phrase.")
                    .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s16)
            }
        } else if finder.hits.isEmpty {
            HubPreviewBox(minHeight: 90) {
                Text("No matches for “\(query)”.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s16)
            }
        } else {
            HubSection("\(finder.hits.count) passage\(finder.hits.count == 1 ? "" : "s") in \(finder.fileCount) file\(finder.fileCount == 1 ? "" : "s")")
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                ForEach(finder.hits) { h in
                    HStack(alignment: .top, spacing: HandySpacing.s8) {
                        Image(systemName: icon(for: h.fileName)).foregroundStyle(HandyColor.accent).frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(h.fileName).font(HandyFont.bodyStrong).lineLimit(1)
                            Text(WordFinder.highlighted(h)).font(HandyFont.body).lineSpacing(3)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { open(h) }
                        Spacer(minLength: 0)
                        Button { finder.save(h); HandyHaptics.light() } label: { Text("Save") }.compactButton()
                    }
                    .padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                }
            }
            HubNote("Tap a passage to open the file.")
        }
    }

    private func icon(for name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "xlsx", "csv": return "tablecells"
        case "pptx": return "rectangle.on.rectangle"
        case "docx", "rtf": return "doc.text"
        default: return "doc.plaintext"
        }
    }

    private func open(_ h: WordFinder.Hit) {
        guard let d = finder.docs.first(where: { $0.id == h.docID }), let u = finder.previewURL(for: d) else { return }
        preview = PreviewItem(url: u)
    }
}

/// QuickLook for any document URL (the finder re-opens the file's security scope around it).
private struct DocQuickLook: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> QLPreviewController { let c = QLPreviewController(); c.dataSource = context.coordinator; return c }
    func updateUIViewController(_ c: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(url: url) }
    final class Coord: NSObject, QLPreviewControllerDataSource {
        let url: URL; init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}
