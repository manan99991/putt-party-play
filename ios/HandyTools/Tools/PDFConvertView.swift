import SwiftUI
import UniformTypeIdentifiers

/// Convert a PDF — turn it into one image per page (JPEG or PNG), or pull its text out into a plain
/// .txt. The text path reuses the embedded text layer when the PDF has one and falls back to OCR for a
/// scanned PDF, so even a photographed document yields real, selectable text. You preview the page (or
/// the extracted text) before you ever Save or Share, and everything lands in the share sheet. On device.
struct PDFConvertView: View {
    enum Mode: String, CaseIterable, Hashable { case images, text
        var title: String { self == .images ? "Images" : "Text" } }

    @State private var sourceData: Data?
    @State private var pages: [UIImage] = []
    @State private var fileName = "Document"
    @State private var mode: Mode = .images
    @State private var asPNG = false
    @State private var page = 0
    @State private var imageURLs: [URL] = []
    @State private var textURL: URL?
    @State private var extractedText = ""
    @State private var working = false
    @State private var errorText: String?
    @State private var showFiles = false

    var body: some View {
        ToolPage(title: "Convert PDF",
                 subtitle: "Turn a PDF into image pages, or pull its text out — on your phone.",
                 working: working) {
            VStack(spacing: HandySpacing.s16) {
                if pages.isEmpty {
                    pickCard
                } else {
                    editor
                }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { res in
            if case .success(let url) = res { load(url) }
        }
        .onChange(of: mode) { _, _ in clearResults() }
        .onAppear { if Launch.sample, pages.isEmpty { loadSample() } }
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "doc.on.doc").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a PDF, then turn it into images or text."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose a PDF"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(spacing: HandySpacing.s12) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text(L($0.title)).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("convert-mode")

            if pages.count > 1 { pager }
            preview

            if mode == .images {
                Toggle(L("PNG (lossless, larger)"), isOn: $asPNG).tint(HandyColor.accent).font(HandyFont.body)
            }

            if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if mode == .images && !imageURLs.isEmpty {
                resultImages
            } else if mode == .text && !extractedText.isEmpty {
                resultText
            } else {
                Button { run() } label: {
                    Label(mode == .images ? L("Convert to images") : L("Extract text"),
                          systemImage: "arrow.right.doc.on.clipboard").frame(maxWidth: .infinity)
                }.primaryButton().disabled(working)
            }

            if working { ToolProgressBar(label: mode == .images ? "Rendering pages…" : "Reading the text…") }

            Button(L("Choose a different PDF")) { reset() }.textButton().font(HandyFont.caption)
        }
    }

    private var pager: some View {
        HStack(spacing: HandySpacing.s16) {
            Button { if page > 0 { page -= 1 } } label: { Image(systemName: "chevron.left") }.disabled(page == 0)
            Text("\(L("Page")) \(page + 1) / \(pages.count)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Button { if page < pages.count - 1 { page += 1 } } label: { Image(systemName: "chevron.right") }.disabled(page == pages.count - 1)
        }
    }

    private var preview: some View {
        Image(uiImage: pages[min(page, pages.count - 1)])
            .resizable().scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: 340)
            .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    // MARK: - Results

    private var resultImages: some View {
        VStack(spacing: HandySpacing.s8) {
            Label("\(imageURLs.count) image\(imageURLs.count == 1 ? "" : "s") ready — \(asPNG ? "PNG" : "JPEG")",
                  systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            ShareLink(items: imageURLs) {
                Label(imageURLs.count == 1 ? L("Save or share image") : L("Save or share all"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.primaryButton()
            Button(L("Convert again")) { imageURLs = [] }.textButton().font(HandyFont.caption)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var resultText: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Text extracted — preview below, then save or share."), systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
            ScrollView {
                Text(extractedText).font(HandyFont.body).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 220)
            .padding(HandySpacing.s12)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            if let url = textURL {
                ShareLink(item: url) {
                    Label(L("Save or share .txt"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.primaryButton()
            }
            Button(L("Extract again")) { extractedText = ""; textURL = nil }.textButton().font(HandyFont.caption)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    // MARK: - Actions

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { errorText = "Couldn't open that PDF."; return }
        let imgs = DocEngine.importPDF(url)
        guard !imgs.isEmpty else { errorText = "That PDF has no pages Tenzy can read."; return }
        sourceData = data; pages = imgs; page = 0
        fileName = url.deletingPathExtension().lastPathComponent
        clearResults()
    }

    private func loadSample() {
        let doc = SampleAssets.document()
        var opts = DocEngine.PDFOptions(); opts.searchable = true
        guard let data = DocEngine.pdf(images: [doc], ocr: [DocEngine.recognize(doc)], options: opts) else { return }
        sourceData = data; pages = [doc]; page = 0; fileName = "Sample"
        clearResults()
    }

    private func reset() {
        sourceData = nil; pages = []; page = 0; clearResults()
    }

    private func clearResults() {
        imageURLs = []; extractedText = ""; textURL = nil; errorText = nil
    }

    private func run() {
        guard let data = sourceData else { return }
        working = true; errorText = nil
        let png = asPNG, name = safeName(fileName), m = mode
        Task.detached(priority: .userInitiated) {
            if m == .images {
                let datas = DocEngine.pdfToImages(data, png: png)
                var urls: [URL] = []
                for (i, d) in datas.enumerated() {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(i + 1).\(png ? "png" : "jpg")")
                    try? FileManager.default.removeItem(at: url)
                    if (try? d.write(to: url)) != nil { urls.append(url) }
                }
                let out = urls
                await MainActor.run {
                    working = false
                    if out.isEmpty { errorText = "Couldn't render the pages." }
                    else { imageURLs = out; HandyHaptics.success() }
                }
            } else {
                let text = DocEngine.pdfText(data)
                var url: URL?
                if !text.isEmpty {
                    let u = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).txt")
                    try? FileManager.default.removeItem(at: u)
                    if (try? Data(text.utf8).write(to: u)) != nil { url = u }
                }
                let outText = text, outURL = url
                await MainActor.run {
                    working = false
                    if outText.isEmpty { errorText = "No readable text found in this PDF." }
                    else { extractedText = outText; textURL = outURL; HandyHaptics.success() }
                }
            }
        }
    }

    /// Keep the shared filename to safe characters so the temp file writes and the share sheet shows a
    /// sensible name.
    private func safeName(_ raw: String) -> String {
        let trimmed = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Document" : String(trimmed.prefix(60))
    }
}
