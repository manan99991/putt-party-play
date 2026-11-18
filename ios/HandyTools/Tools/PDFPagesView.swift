import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Organize Pages — reorder, rotate and remove a PDF's pages, then save a new PDF. Pages are copied, not
/// re-rendered, so text stays sharp and selectable. The result is rendered back and previewed before you
/// Save or Share. On device.
struct PDFPagesView: View {
    @State private var sourceData: Data?
    @State private var thumbs: [UIImage] = []          // one per SOURCE page
    @State private var items: [PDFPages.Item] = []
    @State private var fileName = "Document"
    @State private var resultURL: URL?
    @State private var resultPreview: UIImage?
    @State private var resultPages = 0
    @State private var working = false
    @State private var errorText: String?
    @State private var showFiles = false

    var body: some View {
        ToolPage(title: "Organize Pages",
                 subtitle: "Reorder, rotate or remove pages, then save a clean new PDF.",
                 working: working) {
            VStack(spacing: HandySpacing.s16) {
                if thumbs.isEmpty { pickCard }
                else if let url = resultURL { result(url) }
                else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { res in
            if case .success(let url) = res { load(url) }
        }
        .onAppear { if Launch.sample, thumbs.isEmpty { loadSample() } }
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "rectangle.stack").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a PDF, then move, turn or remove its pages."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose a PDF"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
            if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
            }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(spacing: HandySpacing.s12) {
            HStack {
                Text("\(items.count) of \(thumbs.count) \(L("pages"))")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Spacer()
                if items != PDFPages.items(pageCount: thumbs.count) {
                    Button(L("Undo all")) { items = PDFPages.items(pageCount: thumbs.count) }
                        .textButton().font(HandyFont.caption)
                }
            }
            VStack(spacing: HandySpacing.s8) {
                ForEach(Array(items.enumerated()), id: \.element.id) { pos, item in row(pos, item) }
            }
            if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { run() } label: {
                Label(L("Make new PDF"), systemImage: "doc.badge.gearshape").frame(maxWidth: .infinity)
            }.primaryButton().disabled(items.isEmpty || working)
            if working { ToolProgressBar(label: "Building your PDF…") }
            Button(L("Choose a different PDF")) { reset() }.textButton().font(HandyFont.caption)
        }
    }

    private func row(_ pos: Int, _ item: PDFPages.Item) -> some View {
        HStack(spacing: HandySpacing.s12) {
            Image(uiImage: thumbs[item.index]).resizable().scaledToFit()
                .rotationEffect(.degrees(Double(item.rotation)))
                .frame(width: 54, height: 70)
                .background(HandyColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(L("Page")) \(pos + 1)").font(HandyFont.bodyStrong)
                if item.index != pos || item.rotation != 0 {
                    Text(item.rotation == 0 ? "\(L("was page")) \(item.index + 1)"
                                            : "\(L("was page")) \(item.index + 1) · \(item.rotation)°")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
            iconButton("arrow.up", L("Move up"), disabled: pos == 0) { items.swapAt(pos, pos - 1) }
            iconButton("arrow.down", L("Move down"), disabled: pos == items.count - 1) { items.swapAt(pos, pos + 1) }
            iconButton("rotate.right", L("Rotate")) { items[pos].rotation = PDFPages.normalized(items[pos].rotation + 90) }
            iconButton("trash", L("Remove page"), disabled: items.count == 1, tint: HandyColor.danger) { items.remove(at: pos) }
        }
        .padding(HandySpacing.s8)
        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
    }

    private func iconButton(_ symbol: String, _ label: String, disabled: Bool = false,
                            tint: Color = HandyColor.accent, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 44)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(disabled ? HandyColor.textSecondary.opacity(0.4) : tint)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(spacing: HandySpacing.s12) {
            Label("\(L("New PDF ready")) — \(resultPages) \(resultPages == 1 ? L("page") : L("pages"))",
                  systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let img = resultPreview {
                Image(uiImage: img).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 340)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .accessibilityLabel(L("Preview of the first page"))
            }
            ShareLink(item: url) {
                Label(L("Save or share PDF"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.primaryButton()
            Button(L("Keep editing")) { resultURL = nil; resultPreview = nil }.textButton().font(HandyFont.caption)
        }
    }

    // MARK: - Actions

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { errorText = "Couldn't open that PDF."; return }
        let imgs = DocEngine.importPDF(url, maxWidth: 240)
        guard !imgs.isEmpty else { errorText = "That PDF has no pages Tenzy can read."; return }
        sourceData = data; thumbs = imgs; items = PDFPages.items(pageCount: imgs.count)
        fileName = url.deletingPathExtension().lastPathComponent
        resultURL = nil; resultPreview = nil; errorText = nil
    }

    private func loadSample() {
        let a = SampleAssets.document()
        var opts = DocEngine.PDFOptions(); opts.searchable = false
        guard let data = DocEngine.pdf(images: [a, a, a], ocr: [nil, nil, nil], options: opts) else { return }
        sourceData = data; thumbs = [a, a, a]; items = PDFPages.items(pageCount: 3); fileName = "Sample"
    }

    private func reset() {
        sourceData = nil; thumbs = []; items = []; resultURL = nil; resultPreview = nil; errorText = nil
    }

    private func run() {
        guard let data = sourceData else { return }
        working = true; errorText = nil
        let plan = items
        let name = fileName.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        Task { @MainActor in
            let out: URL? = await Task.detached(priority: .userInitiated) {
                guard let built = PDFPages.build(data, items: plan) else { return nil }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(name.isEmpty ? "Document" : String(name.prefix(50))) (organized).pdf")
                try? FileManager.default.removeItem(at: url)
                guard (try? built.write(to: url)) != nil else { return nil }
                return url
            }.value
            working = false
            // Preview the REAL output: reopen the saved file and show its first page as it will look.
            if let url = out, let doc = PDFDocument(url: url), doc.pageCount > 0, let first = doc.page(at: 0) {
                resultURL = url; resultPages = doc.pageCount
                resultPreview = first.thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox)
                HandyHaptics.success()
            } else {
                errorText = "Couldn't build the PDF — try again."
            }
        }
    }
}
