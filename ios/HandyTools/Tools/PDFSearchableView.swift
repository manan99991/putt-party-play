import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Make Searchable — turn a scanned PDF (pages that are just pictures) into one you can search, select
/// and copy, by reading every page with on-device OCR. Shows live page-by-page progress with time left,
/// then previews the text it found before you Save or Share. On device, nothing uploaded.
struct PDFSearchableView: View {
    @State private var sourceData: Data?
    @State private var preview: UIImage?
    @State private var pageCount = 0
    @State private var alreadyText = false
    @State private var fileName = "Document"
    @State private var progress: Double = 0
    @State private var resultURL: URL?
    @State private var foundText = ""
    @State private var words = 0
    @State private var working = false
    @State private var errorText: String?
    @State private var showFiles = false

    var body: some View {
        ToolPage(title: "Make Searchable",
                 subtitle: "Turn a scanned PDF into one you can search and copy text from.",
                 working: working) {
            VStack(spacing: HandySpacing.s16) {
                if sourceData == nil { pickCard }
                else if let url = resultURL { result(url) }
                else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { res in
            if case .success(let url) = res { load(url) }
        }
        .onAppear { if Launch.sample, sourceData == nil { loadSample() } }
        .handoff("pdfsearchable") { p in if let u = ToolHandoff.fileURL(p) { load(u) } }
    }

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "text.viewfinder").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a scanned PDF and Tenzy will read every page so you can search and copy its text."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose a PDF"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    private var editor: some View {
        VStack(spacing: HandySpacing.s12) {
            if let img = preview {
                Image(uiImage: img).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            }
            Text("\(pageCount) \(pageCount == 1 ? L("page") : L("pages"))")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            if alreadyText {
                Label(L("This PDF already has searchable text. Running it again re-reads the pages — fine for a patchy scan."),
                      systemImage: "info.circle")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { run() } label: {
                Label(L("Make it searchable"), systemImage: "text.magnifyingglass").frame(maxWidth: .infinity)
            }.primaryButton().disabled(working)
            if working { ToolProgressBar(value: progress, label: "Reading page \(min(pageCount, Int(progress * Double(pageCount)) + 1)) of \(pageCount)…") }
            Button(L("Choose a different PDF")) { reset() }.textButton().font(HandyFont.caption)
        }
    }

    private func result(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label("\(L("Searchable now")) — \(words) \(L("words found"))", systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
            Text(L("Here's the text it can now find and copy:")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            ScrollView {
                Text(foundText.isEmpty ? L("(No readable words were found — the scan may be too faint or handwritten.)") : foundText)
                    .font(HandyFont.body).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 220)
            .padding(HandySpacing.s12)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            KeepShare(url, tool: "Searchable PDF")
            Button(L("Do another")) { reset() }.textButton().font(HandyFont.caption)
        }
    }

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let doc = PDFDocument(data: data) else {
            errorText = "Couldn't open that PDF."; return
        }
        guard !doc.isLocked else { errorText = "That PDF is password-locked — remove the password with Protect first."; return }
        guard doc.pageCount > 0 else { errorText = "That PDF has no pages."; return }
        sourceData = data; pageCount = doc.pageCount; alreadyText = PDFSearchable.hasText(data)
        preview = doc.page(at: 0)?.thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox)
        fileName = url.deletingPathExtension().lastPathComponent
        resultURL = nil; foundText = ""; errorText = nil
    }

    private func loadSample() {
        let img = SampleAssets.document()
        var opts = DocEngine.PDFOptions(); opts.searchable = false
        guard let data = DocEngine.pdf(images: [img], ocr: [nil], options: opts) else { return }
        sourceData = data; pageCount = 1; preview = img; alreadyText = false; fileName = "Sample"
    }

    private func reset() {
        sourceData = nil; preview = nil; pageCount = 0; resultURL = nil; foundText = ""; errorText = nil; progress = 0
    }

    private func run() {
        guard let data = sourceData else { return }
        working = true; errorText = nil; progress = 0
        let name = fileName.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        Task {
            let made = await PDFSearchable.make(data) { p in Task { @MainActor in progress = p } }
            await MainActor.run {
                working = false
                guard let made else { errorText = "Couldn't read that PDF — try again."; return }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(name.isEmpty ? "Document" : String(name.prefix(50))) (searchable).pdf")
                try? FileManager.default.removeItem(at: url)
                guard (try? made.data.write(to: url)) != nil, let doc = PDFDocument(url: url) else {
                    errorText = "Couldn't save the PDF — try again."; return
                }
                // Preview what the REAL output can now find.
                foundText = String((doc.string ?? "").prefix(4000))
                words = made.words
                resultURL = url
                HandyHaptics.success()
            }
        }
    }
}
