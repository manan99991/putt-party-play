import SwiftUI
import UniformTypeIdentifiers

/// Redact a PDF — drag a box over anything to hide (names, numbers, a signature) and Tenzy bakes an
/// opaque block into the page and rebuilds the file, so the hidden text and images are genuinely gone:
/// no selectable layer under a black box, which is how "redacted" PDFs leak. You preview the flattened
/// result — the same solid blocks that go into the file — before you ever Save or Share. On device.
struct PDFRedactView: View {
    @State private var sourceData: Data?
    @State private var pages: [UIImage] = []
    @State private var fileName = "Document"
    @State private var boxesByPage: [Int: [CGRect]] = [:]   // normalized top-left rects, per page index
    @State private var page = 0
    @State private var drawing: CGRect?
    @State private var result: Data?
    @State private var working = false
    @State private var showFiles = false
    @State private var finding = false
    @State private var foundNote: String?
    @State private var proof: RedactFinder.Proof?

    private var boxCount: Int { boxesByPage.values.reduce(0) { $0 + $1.count } }
    private var thisPageBoxes: [CGRect] { boxesByPage[page] ?? [] }

    var body: some View {
        ToolPage(title: "Redact PDF",
                 subtitle: "Black out anything — the hidden text is destroyed, not just covered over.",
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
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "doc.text.magnifyingglass").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a PDF, then drag a box over anything you want gone."))
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
            if pages.count > 1 { pager }
            canvas(pages[page])
            Text(L("Drag on the page to black out a region. Tap a box to remove it."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HStack {
                if !thisPageBoxes.isEmpty {
                    Button(L("Clear this page")) { boxesByPage[page] = [] }.textButton().font(HandyFont.caption)
                }
                Spacer()
                Text(boxCount == 1 ? L("1 region") : "\(boxCount) " + L("regions"))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Button { findForMe() } label: {
                HStack { if finding { BusySpinner() }; Label(L("Find personal details for me"), systemImage: "sparkle.magnifyingglass") }.frame(maxWidth: .infinity)
            }.secondaryButton().disabled(finding).accessibilityIdentifier("redact-find")
            if let foundNote { Text(L(foundNote)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
            Button { runRedact() } label: {
                Label(L("Redact & preview"), systemImage: "eye.slash.fill").frame(maxWidth: .infinity)
            }.primaryButton().disabled(boxCount == 0)
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
                ForEach(Array(thisPageBoxes.enumerated()), id: \.offset) { idx, b in
                    let r = denorm(b, fit)
                    Rectangle().fill(Color.black)
                        .overlay(Rectangle().stroke(HandyColor.accent, lineWidth: 1.5))
                        .frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
                        .onTapGesture { removeBox(idx) }
                }
                if let d = drawing {
                    let r = denorm(d, fit)
                    Rectangle().fill(Color.black.opacity(0.5)).overlay(Rectangle().stroke(HandyColor.accent, lineWidth: 1.5))
                        .frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 6)
                .onChanged { v in drawing = normRect(from: v.startLocation, to: v.location, fit) }
                .onEnded { v in
                    let r = normRect(from: v.startLocation, to: v.location, fit)
                    if r.width > 0.01 && r.height > 0.01 { boxesByPage[page, default: []].append(r) }
                    drawing = nil
                })
        }
        .frame(height: 380)
        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    // MARK: - Result

    private func resultView(_ out: Data) -> some View {
        VStack(spacing: HandySpacing.s12) {
            Label(L("Redacted — the hidden text is gone, not just covered. Flattened, so it can't be lifted off."),
                  systemImage: "checkmark.shield.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            if pages.count > 1 { pager }
            // Faithful preview: the page with the same solid blocks the engine baked into the file.
            GeometryReader { geo in
                let img = pages[page]
                let fit = fitRect(image: img.size, in: geo.size)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: img).resizable().scaledToFit().frame(width: geo.size.width, height: geo.size.height)
                    ForEach(Array(thisPageBoxes.enumerated()), id: \.offset) { _, b in
                        let r = denorm(b, fit)
                        Rectangle().fill(Color.black).frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
                    }
                }
            }
            .frame(height: 380)
            .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            if let proof {
                if proof.stillFound.isEmpty {
                    Label(proof.checked == 0 ? L("Checked: nothing readable was under the boxes.") : "\(L("Proved: searched the finished file for all")) \(proof.checked) \(L("hidden words — none can be found."))",
                          systemImage: "checkmark.seal.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Label("\(L("Still readable in the file:")) \(proof.stillFound.prefix(5).joined(separator: ", ")). \(L("Make those boxes bigger and redact again."))",
                          systemImage: "exclamationmark.triangle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.danger).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 6) { BusySpinner(); Text(L("Checking the hidden words are really gone…")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            }
            ShareLink(item: PDFFile(data: out), preview: SharePreview(L("Redacted PDF"))) {
                Label(L("Save or share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.primaryButton()
            Button(L("Edit the redactions")) { result = nil }.textButton()
        }
    }

    // MARK: - Actions

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let imgs = DocEngine.importPDF(url)
        guard !imgs.isEmpty else { return }
        sourceData = data; pages = imgs; boxesByPage = [:]; page = 0; result = nil
        fileName = url.deletingPathExtension().lastPathComponent
    }

    private func loadSample() {
        let doc = SampleAssets.document()
        var opts = DocEngine.PDFOptions(); opts.searchable = false
        guard let data = DocEngine.pdf(images: [doc], ocr: [nil], options: opts) else { return }
        sourceData = data; pages = [doc]; boxesByPage = [:]; page = 0; result = nil
        fileName = "Sample"
    }

    private func removeBox(_ idx: Int) {
        guard var list = boxesByPage[page], idx < list.count else { return }
        list.remove(at: idx); boxesByPage[page] = list
    }

    private func runRedact() {
        guard let data = sourceData, boxCount > 0 else { return }
        let boxes = (0..<pages.count).map { boxesByPage[$0] ?? [] }
        let imgs = pages
        working = true; proof = nil
        Task { @MainActor in
            let out = await Task.detached(priority: .userInitiated) { DocEngine.redact(data, boxes: boxes) }.value
            result = out
            working = false
            guard let out else { return }
            // Prove it: every word that was under a box, searched for in the finished file.
            proof = await Task.detached(priority: .utility) { RedactFinder.proof(hidden: RedactFinder.hiddenWords(pages: imgs, boxes: boxes), result: out) }.value
        }
    }

    private func findForMe() {
        let imgs = pages
        finding = true; foundNote = nil
        Task { @MainActor in
            let found = await Task.detached(priority: .userInitiated) { imgs.map { RedactFinder.find($0) } }.value
            var added = 0
            for (i, list) in found.enumerated() {
                var cur = boxesByPage[i] ?? []
                for b in list where !cur.contains(where: { RedactFinder.covered(b, by: $0) > 0.6 }) { cur.append(b); added += 1 }
                boxesByPage[i] = cur
            }
            finding = false
            foundNote = added == 0 ? "Nothing personal found — drag boxes over anything else you want gone."
                                   : "Boxed \(added) personal detail\(added == 1 ? "" : "s") — account and card numbers, phones, emails, addresses, IDs. Check each page, tap a box to remove it."
        }
    }

    // MARK: - Coordinate math (shared convention with the Privacy Scrubber)

    private func fitRect(image: CGSize, in c: CGSize) -> CGRect {
        let s = min(c.width / image.width, c.height / image.height)
        let w = image.width * s, h = image.height * s
        return CGRect(x: (c.width - w) / 2, y: (c.height - h) / 2, width: w, height: h)
    }
    private func denorm(_ r: CGRect, _ fit: CGRect) -> CGRect {
        CGRect(x: fit.minX + r.minX * fit.width, y: fit.minY + r.minY * fit.height, width: r.width * fit.width, height: r.height * fit.height)
    }
    private func normRect(from a: CGPoint, to b: CGPoint, _ fit: CGRect) -> CGRect {
        func n(_ p: CGPoint) -> CGPoint { CGPoint(x: min(max((p.x - fit.minX) / fit.width, 0), 1), y: min(max((p.y - fit.minY) / fit.height, 0), 1)) }
        let p = n(a), q = n(b)
        return CGRect(x: min(p.x, q.x), y: min(p.y, q.y), width: abs(p.x - q.x), height: abs(p.y - q.y))
    }
}
