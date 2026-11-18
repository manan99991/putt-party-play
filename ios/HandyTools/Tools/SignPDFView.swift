import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Sign a PDF — place your saved signature, today's date or typed text anywhere on any page, drag it into
/// place, size it, and save. The original pages stay as vectors (sharp, text still selectable); the
/// signed result is reopened and previewed before you Save or Share. On device.
struct SignPDFView: View {
    @State private var sourceData: Data?
    @State private var pages: [UIImage] = []
    @State private var fileName = "Document"
    @State private var page = 0
    @State private var stamps: [Int: [DocEngine.Stamp]] = [:]
    @State private var selected: UUID?
    @State private var signature: UIImage? = DocEngine.savedSignature
    @State private var typed = ""
    @State private var resultURL: URL?
    @State private var resultPreview: UIImage?
    @State private var working = false
    @State private var errorText: String?
    @State private var showFiles = false
    @State private var showPad = false

    private var here: [DocEngine.Stamp] { stamps[page] ?? [] }
    private var total: Int { stamps.values.reduce(0) { $0 + $1.count } }

    var body: some View {
        ToolPage(title: "Sign PDF",
                 subtitle: "Add your signature, the date or text to any page — drag it where it goes.",
                 working: working) {
            VStack(spacing: HandySpacing.s16) {
                if pages.isEmpty { pickCard }
                else if let url = resultURL { result(url) }
                else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { res in
            if case .success(let url) = res { load(url) }
        }
        .sheet(isPresented: $showPad) { SignaturePadSheet { img in signature = img } }
        .onAppear { if Launch.sample, pages.isEmpty { loadSample() } }
        .handoff("pdfsign") { p in if let u = ToolHandoff.fileURL(p) { load(u) } }
    }

    // MARK: - Pick

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "signature").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a PDF, then drop your signature where it needs to go."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose a PDF"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(spacing: HandySpacing.s12) {
            if pages.count > 1 { pager }
            canvas(pages[page])
            Text(L("Drag to move. Tap one to select it, then resize or remove it."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)

            if let id = selected, let i = here.firstIndex(where: { $0.id == id }) {
                HStack(spacing: HandySpacing.s12) {
                    Image(systemName: "arrow.left.and.right").foregroundStyle(HandyColor.textSecondary)
                    Slider(value: Binding(get: { here[i].width },
                                          set: { stamps[page]?[i].width = $0 }), in: 0.08...0.8)
                        .tint(HandyColor.accent)
                    Button { stamps[page]?.remove(at: i); selected = nil } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless).foregroundStyle(HandyColor.danger)
                        .accessibilityLabel(L("Remove"))
                }
            }

            // What to add
            VStack(spacing: HandySpacing.s8) {
                if let sig = signature {
                    HStack(spacing: HandySpacing.s12) {
                        Image(uiImage: sig).resizable().scaledToFit().frame(height: 40)
                            .padding(4).background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                        Button { add(.signature(sig), width: 0.35) } label: {
                            Label(L("Add signature"), systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                        }.primaryButton()
                    }
                    Button(L("Redo my signature")) { showPad = true }.textButton().font(HandyFont.caption)
                } else {
                    Button { showPad = true } label: {
                        Label(L("Draw your signature"), systemImage: "signature").frame(maxWidth: .infinity)
                    }.primaryButton()
                }
                HStack(spacing: HandySpacing.s8) {
                    Button { add(.text(Date().formatted(date: .abbreviated, time: .omitted)), width: 0.25) } label: {
                        Label(L("Add date"), systemImage: "calendar").frame(maxWidth: .infinity)
                    }.secondaryButton()
                }
                HStack(spacing: HandySpacing.s8) {
                    TextField(L("Name, initials or any text"), text: $typed)
                        .textFieldStyle(.roundedBorder)
                    Button { let t = typed.trimmingCharacters(in: .whitespaces); if !t.isEmpty { add(.text(t), width: 0.3); typed = "" } } label: {
                        Text(L("Add"))
                    }.secondaryButton().disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .cardStyle(padding: HandySpacing.s12)

            if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { run() } label: {
                Label(L("Sign & preview"), systemImage: "checkmark.seal.fill").frame(maxWidth: .infinity)
            }.primaryButton().disabled(total == 0 || working)
            if working { ToolProgressBar(label: "Signing your PDF…") }
            Button(L("Choose a different PDF")) { reset() }.textButton().font(HandyFont.caption)
        }
    }

    private var pager: some View {
        HStack(spacing: HandySpacing.s16) {
            Button { if page > 0 { page -= 1; selected = nil } } label: { Image(systemName: "chevron.left") }.disabled(page == 0)
            Text("\(L("Page")) \(page + 1) / \(pages.count)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Button { if page < pages.count - 1 { page += 1; selected = nil } } label: { Image(systemName: "chevron.right") }.disabled(page == pages.count - 1)
        }
    }

    private func canvas(_ img: UIImage) -> some View {
        GeometryReader { geo in
            let fit = fitRect(image: img.size, in: geo.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: img).resizable().scaledToFit().frame(width: geo.size.width, height: geo.size.height)
                ForEach(here) { st in
                    stampView(st, fit: fit)
                        .position(x: fit.minX + st.center.x * fit.width, y: fit.minY + st.center.y * fit.height)
                        .gesture(DragGesture(coordinateSpace: .named("signpage"))
                            .onChanged { v in
                                selected = st.id
                                move(st.id, to: CGPoint(x: (v.location.x - fit.minX) / fit.width,
                                                        y: (v.location.y - fit.minY) / fit.height))
                            })
                        .onTapGesture { selected = st.id }
                }
            }
            .coordinateSpace(name: "signpage")
        }
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    @ViewBuilder private func stampView(_ st: DocEngine.Stamp, fit: CGRect) -> some View {
        let w = st.width * fit.width
        Group {
            switch st.kind {
            case .signature(let s):
                Image(uiImage: s).resizable().scaledToFit().frame(width: w)
            case .text(let s):
                Text(s).font(.system(size: DocEngine.fontSize(for: s, width: w))).foregroundStyle(Color.black)
                    .fixedSize()
            }
        }
        .padding(2)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(HandyColor.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
            .opacity(selected == st.id ? 1 : 0))
    }

    // MARK: - Result

    private func result(_ url: URL) -> some View {
        VStack(spacing: HandySpacing.s12) {
            Label(L("Signed — check it below, then save or share."), systemImage: "checkmark.seal.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let img = resultPreview {
                Image(uiImage: img).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 380)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .accessibilityLabel(L("Preview of the signed page"))
            }
            ShareLink(item: url) {
                Label(L("Save or share signed PDF"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.primaryButton()
            Button(L("Keep editing")) { resultURL = nil; resultPreview = nil }.textButton().font(HandyFont.caption)
        }
    }

    // MARK: - Actions

    private func add(_ kind: DocEngine.Stamp.Kind, width: CGFloat) {
        var st = DocEngine.Stamp(kind: kind)
        st.width = width
        // Stagger new stamps a little so two don't land exactly on top of each other.
        let n = CGFloat(here.count)
        st.center = CGPoint(x: 0.5, y: min(0.85, 0.7 + n * 0.06))
        stamps[page, default: []].append(st)
        selected = st.id
    }

    private func move(_ id: UUID, to p: CGPoint) {
        guard let i = stamps[page]?.firstIndex(where: { $0.id == id }) else { return }
        stamps[page]?[i].center = CGPoint(x: min(max(p.x, 0), 1), y: min(max(p.y, 0), 1))
    }

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { errorText = "Couldn't open that PDF."; return }
        let imgs = DocEngine.importPDF(url)
        guard !imgs.isEmpty else { errorText = "That PDF has no pages Tenzy can read."; return }
        sourceData = data; pages = imgs; page = 0; stamps = [:]; selected = nil
        fileName = url.deletingPathExtension().lastPathComponent
        resultURL = nil; resultPreview = nil; errorText = nil
    }

    private func loadSample() {
        let doc = SampleAssets.document()
        var opts = DocEngine.PDFOptions(); opts.searchable = false
        guard let data = DocEngine.pdf(images: [doc], ocr: [nil], options: opts) else { return }
        sourceData = data; pages = [doc]; page = 0; fileName = "Sample"
    }

    private func reset() {
        sourceData = nil; pages = []; stamps = [:]; selected = nil; resultURL = nil; resultPreview = nil; errorText = nil
    }

    private func run() {
        guard let data = sourceData else { return }
        working = true; errorText = nil; selected = nil
        let plan = stamps
        let firstSigned = plan.keys.filter { !(plan[$0] ?? []).isEmpty }.min() ?? 0
        let name = fileName.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        Task { @MainActor in
            let out: URL? = await Task.detached(priority: .userInitiated) {
                guard let signed = PDFOverlay.stamp(data, stamps: plan) else { return nil }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(name.isEmpty ? "Document" : String(name.prefix(50))) (signed).pdf")
                try? FileManager.default.removeItem(at: url)
                guard (try? signed.write(to: url)) != nil else { return nil }
                return url
            }.value
            working = false
            // Preview the REAL output: reopen the saved file and show the first signed page.
            if let url = out, let doc = PDFDocument(url: url), let p = doc.page(at: min(firstSigned, doc.pageCount - 1)) {
                resultURL = url
                resultPreview = p.thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox)
                HandyHaptics.success()
            } else {
                errorText = "Couldn't sign the PDF — try again."
            }
        }
    }

    private func fitRect(image: CGSize, in c: CGSize) -> CGRect {
        let s = min(c.width / max(1, image.width), c.height / max(1, image.height))
        let w = image.width * s, h = image.height * s
        return CGRect(x: (c.width - w) / 2, y: (c.height - h) / 2, width: w, height: h)
    }
}
