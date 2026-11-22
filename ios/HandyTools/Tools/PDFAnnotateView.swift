import SwiftUI
import UniformTypeIdentifiers

/// Annotate a PDF — sweep a highlighter over a line or draw freehand on the page, in the colour you
/// pick, then Tenzy bakes the marks straight into the page and rebuilds the file, so they show in
/// every reader (not a removable annotation layer a viewer can toggle off). The text underneath is
/// kept, not destroyed: highlights use a multiply blend so the words stay readable, and the rebuilt
/// PDF is re-OCR'd so find/select still work. You preview the flattened page — the same marks that go
/// into the file — before you ever Save or Share. On device.
struct PDFAnnotateView: View {
    enum Mode: Int { case highlight, draw }

    @State private var sourceData: Data?
    @State private var pages: [UIImage] = []
    @State private var fileName = "Document"
    @State private var marksByPage: [Int: [DocEngine.Annotation]] = [:]
    @State private var page = 0
    @State private var mode: Mode = .highlight
    @State private var color: Color = .yellow
    @State private var drawingRect: CGRect?        // live highlight sweep
    @State private var drawingPts: [CGPoint] = []   // live freehand stroke (normalized)
    @State private var result: Data?
    @State private var working = false
    @State private var showFiles = false
    @State private var highlights: [(page: Int, text: String)] = []

    private let palette: [(String, Color)] = [
        ("Yellow", .yellow), ("Green", .green), ("Pink", .pink), ("Blue", .blue), ("Red", .red), ("Black", .black)
    ]

    private var markCount: Int { marksByPage.values.reduce(0) { $0 + $1.count } }
    private var thisPageMarks: [DocEngine.Annotation] { marksByPage[page] ?? [] }
    private var strokeWidth: CGFloat { mode == .highlight ? 0 : 0.008 }

    var body: some View {
        ToolPage(title: "Annotate PDF",
                 subtitle: "Highlight a line or draw on the page — the marks are baked into the file.",
                 working: working) {
            VStack(spacing: HandySpacing.s16) {
                if pages.isEmpty {
                    pickCard
                } else if let out = result {
                    resultView(out)
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
        .onAppear { if Launch.sample, pages.isEmpty { loadSample() } }
        .handoff("pdfannotate") { p in if let u = ToolHandoff.fileURL(p) { load(u) } }
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "highlighter").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a PDF, then highlight lines or draw on the page."))
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
                Text(L("Highlight")).tag(Mode.highlight)
                Text(L("Draw")).tag(Mode.draw)
            }.pickerStyle(.segmented)
            colorRow
            if pages.count > 1 { pager }
            canvas(pages[page])
            Text(mode == .highlight ? L("Drag across a line to highlight it.") : L("Drag to draw. Tap a mark to remove it."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HStack {
                if !thisPageMarks.isEmpty {
                    Button(L("Undo")) { undo() }.textButton().font(HandyFont.caption)
                    Button(L("Clear this page")) { marksByPage[page] = [] }.textButton().font(HandyFont.caption)
                }
                Spacer()
                Text(markCount == 1 ? L("1 mark") : "\(markCount) " + L("marks"))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Button { runAnnotate() } label: {
                Label(L("Apply & preview"), systemImage: "eye.fill").frame(maxWidth: .infinity)
            }.primaryButton().disabled(markCount == 0)
        }
    }

    private var colorRow: some View {
        HStack(spacing: HandySpacing.s12) {
            ForEach(palette, id: \.0) { name, c in
                Circle().fill(c)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(color == c ? HandyColor.accent : HandyColor.border, lineWidth: color == c ? 3 : 1))
                    .onTapGesture { color = c }
                    .accessibilityLabel(L(name))
            }
            Spacer()
        }
    }

    private var pager: some View {
        HStack(spacing: HandySpacing.s16) {
            Button { if page > 0 { page -= 1 } } label: { Image(systemName: "chevron.left") }.disabled(page == 0)
            Text("\(L("Page")) \(page + 1) / \(pages.count)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Button { if page < pages.count - 1 { page += 1 } } label: { Image(systemName: "chevron.right") }.disabled(page == pages.count - 1)
        }
    }

    private func canvas(_ img: UIImage) -> some View {
        GeometryReader { geo in
            let fit = fitRect(image: img.size, in: geo.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: img).resizable().scaledToFit().frame(width: geo.size.width, height: geo.size.height)
                ForEach(Array(thisPageMarks.enumerated()), id: \.offset) { idx, m in
                    markShape(m, fit).onTapGesture { removeMark(idx) }
                }
                liveOverlay(fit)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 2)
                .onChanged { v in
                    if mode == .highlight {
                        drawingRect = normRect(from: v.startLocation, to: v.location, fit)
                    } else {
                        drawingPts.append(normPoint(v.location, fit))
                    }
                }
                .onEnded { v in
                    if mode == .highlight {
                        let r = normRect(from: v.startLocation, to: v.location, fit)
                        if r.width > 0.01 && r.height > 0.004 {
                            marksByPage[page, default: []].append(.init(kind: .highlight(r), color: UIColor(color)))
                        }
                        drawingRect = nil
                    } else {
                        if drawingPts.count > 1 {
                            marksByPage[page, default: []].append(.init(kind: .stroke(points: drawingPts, width: strokeWidth), color: UIColor(color)))
                        }
                        drawingPts = []
                    }
                })
        }
        .frame(height: 380)
        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    @ViewBuilder private func markShape(_ m: DocEngine.Annotation, _ fit: CGRect) -> some View {
        switch m.kind {
        case .highlight(let r):
            let d = denorm(r, fit)
            Rectangle().fill(Color(uiColor: m.color).opacity(0.4))
                .frame(width: d.width, height: d.height).offset(x: d.minX, y: d.minY)
        case .stroke(let pts, let w):
            strokePath(pts, fit).stroke(Color(uiColor: m.color), style: StrokeStyle(lineWidth: max(1, w * fit.width), lineCap: .round, lineJoin: .round))
        }
    }

    @ViewBuilder private func liveOverlay(_ fit: CGRect) -> some View {
        if let d = drawingRect {
            let r = denorm(d, fit)
            Rectangle().fill(color.opacity(0.4)).frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
        }
        if drawingPts.count > 1 {
            strokePath(drawingPts, fit).stroke(color, style: StrokeStyle(lineWidth: max(1, strokeWidth * fit.width), lineCap: .round, lineJoin: .round))
        }
    }

    private func strokePath(_ pts: [CGPoint], _ fit: CGRect) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: CGPoint(x: fit.minX + first.x * fit.width, y: fit.minY + first.y * fit.height))
        for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: fit.minX + pt.x * fit.width, y: fit.minY + pt.y * fit.height)) }
        return p
    }

    // MARK: - Result

    private func resultView(_ out: Data) -> some View {
        VStack(spacing: HandySpacing.s12) {
            Label(L("Marked up — baked into the page, and the text is still selectable."), systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            if pages.count > 1 { pager }
            // Faithful preview: the page with the same marks the engine baked into the file.
            GeometryReader { geo in
                let img = pages[page]
                let fit = fitRect(image: img.size, in: geo.size)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: img).resizable().scaledToFit().frame(width: geo.size.width, height: geo.size.height)
                    ForEach(Array(thisPageMarks.enumerated()), id: \.offset) { _, m in markShape(m, fit) }
                }
            }
            .frame(height: 380)
            .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            KeepShare([.data(out, name: L("Annotated PDF"), ext: "pdf")], tool: "Annotate a PDF")
            if !highlights.isEmpty {
                let summary = highlights.map { "p.\($0.page) — \($0.text)" }.joined(separator: "\n")
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(L("What you highlighted")) (\(highlights.count))", systemImage: "highlighter").font(HandyFont.bodyStrong)
                    ForEach(Array(highlights.enumerated()), id: \.offset) { _, h in
                        HStack(alignment: .top, spacing: 6) {
                            Text("p.\(h.page)").font(HandyFont.micro.weight(.semibold)).foregroundStyle(HandyColor.textSecondary).frame(width: 30, alignment: .leading)
                            Text(h.text).font(HandyFont.caption).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    HStack {
                        ShareLink(item: "\(L("Highlights from")) \(fileName)\n\n" + summary) { Label(L("Send to Notes or share"), systemImage: "note.text") }.compactButton()
                        Button { Copier.copy(summary) } label: { Label(L("Copy"), systemImage: "doc.on.doc") }.compactButton()
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
            }
            Button(L("Edit the marks")) { result = nil }.textButton()
        }
    }

    // MARK: - Actions

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let imgs = DocEngine.importPDF(url)
        guard !imgs.isEmpty else { return }
        sourceData = data; pages = imgs; marksByPage = [:]; page = 0; result = nil
        fileName = url.deletingPathExtension().lastPathComponent
    }

    private func loadSample() {
        let doc = SampleAssets.document()
        var opts = DocEngine.PDFOptions(); opts.searchable = false
        guard let data = DocEngine.pdf(images: [doc], ocr: [nil], options: opts) else { return }
        sourceData = data; pages = [doc]; marksByPage = [:]; page = 0; result = nil
        fileName = "Sample"
    }

    private func undo() {
        guard var list = marksByPage[page], !list.isEmpty else { return }
        list.removeLast(); marksByPage[page] = list
    }

    private func removeMark(_ idx: Int) {
        guard var list = marksByPage[page], idx < list.count else { return }
        list.remove(at: idx); marksByPage[page] = list
    }

    private func runAnnotate() {
        guard let data = sourceData, markCount > 0 else { return }
        let marks = (0..<pages.count).map { marksByPage[$0] ?? [] }
        working = true
        Task { @MainActor in
            let out = await Task.detached(priority: .userInitiated) { DocEngine.annotate(data, marks: marks) }.value
            result = out
            working = false
            let imgs = pages
            highlights = await Task.detached(priority: .utility) { Self.highlightedLines(pages: imgs, marks: marks) }.value
        }
    }

    /// The words under each highlight, page by page, in reading order — the summary of what you marked.
    nonisolated static func highlightedLines(pages: [UIImage], marks: [[DocEngine.Annotation]]) -> [(page: Int, text: String)] {
        var out: [(Int, String)] = []
        for (i, img) in pages.enumerated() where i < marks.count {
            let rects = marks[i].compactMap { m -> CGRect? in if case .highlight(let r) = m.kind { return r } else { return nil } }
            guard !rects.isEmpty else { continue }
            let lines = DocEngine.recognize(img).sorted { $0.box.minY < $1.box.minY }
            for l in lines where rects.contains(where: { RedactFinder.covered(l.box, by: $0.insetBy(dx: -0.01, dy: -0.01)) > 0.4 }) { out.append((i + 1, l.text)) }
        }
        return out
    }

    // MARK: - Coordinate math (shared convention with the Redact tool / Privacy Scrubber)

    private func fitRect(image: CGSize, in c: CGSize) -> CGRect {
        let s = min(c.width / image.width, c.height / image.height)
        let w = image.width * s, h = image.height * s
        return CGRect(x: (c.width - w) / 2, y: (c.height - h) / 2, width: w, height: h)
    }
    private func denorm(_ r: CGRect, _ fit: CGRect) -> CGRect {
        CGRect(x: fit.minX + r.minX * fit.width, y: fit.minY + r.minY * fit.height, width: r.width * fit.width, height: r.height * fit.height)
    }
    private func normPoint(_ p: CGPoint, _ fit: CGRect) -> CGPoint {
        CGPoint(x: min(max((p.x - fit.minX) / fit.width, 0), 1), y: min(max((p.y - fit.minY) / fit.height, 0), 1))
    }
    private func normRect(from a: CGPoint, to b: CGPoint, _ fit: CGRect) -> CGRect {
        let p = normPoint(a, fit), q = normPoint(b, fit)
        return CGRect(x: min(p.x, q.x), y: min(p.y, q.y), width: abs(p.x - q.x), height: abs(p.y - q.y))
    }
}
