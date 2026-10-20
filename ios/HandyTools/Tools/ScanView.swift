import SwiftUI
import VisionKit
import PhotosUI
import PencilKit
import PDFKit
import UniformTypeIdentifiers

/// Scan — the whole paperwork loop in one place: scan or import pages → clean up → sign / fill →
/// read the text → export a *searchable* PDF that lands under the size limit (or split it).
/// Notes gives you a scanner; Files gives you a signature; Mail gives you an attachment that's too
/// big. This is the one screen where the form actually gets done.
struct ScanView: View {
    @EnvironmentObject var store: StoreManager

    private enum Mode: Int, CaseIterable { case pages, sign, text, export
        var title: String { ["Clean up", "Sign & fill", "Text", "Export"][rawValue] } }

    @State private var pages: [DocEngine.Page] = []
    @State private var selected = 0
    @State private var mode: Mode = .pages
    @State private var showScanner = false
    @State private var showPDFImporter = false
    @State private var photoItems: [PhotosPickerItem] = []
    @StateObject private var previews = PreviewStore()
    @State private var working = false
    @State private var errorText: String?

    // sign & fill
    @State private var canvas = PKCanvasView()
    @State private var inking = false
    @State private var newText = ""
    @State private var savedSignature: UIImage? = DocEngine.savedSignature
    @State private var showSignaturePad = false
    @State private var selectedStamp: UUID?

    // text
    @State private var ocrText = ""
    @State private var ocrBusy = false

    // export
    @State private var searchable = true
    @State private var pageSize: DocEngine.PageSize = .auto
    @State private var limitIdx: Int? = nil
    @State private var splitSpec = ""
    @State private var splitting = false
    @State private var outputs: [URL] = []
    @State private var jpgOutputs: [URL] = []
    @State private var outputBytes = 0

    private let limits: [(String, Int)] = [("No limit", 0), ("Under 10 MB", 10_000_000), ("Under 5 MB", 5_000_000), ("Under 2 MB", 2_000_000), ("Under 1 MB", 1_000_000), ("Under 500 KB", 500_000)]
    private var overQuota: Bool { !Usage.hasRoom("scan", limit: Limits.freeScanPerDay) }
    private var page: DocEngine.Page? { pages.indices.contains(selected) ? pages[selected] : nil }

    var body: some View {
        ToolPage(title: "Scan", subtitle: "Scan or import pages, clean them up, sign and fill, then export a searchable PDF that fits.") {
            if pages.isEmpty {
                emptyState
            } else {
                pageStrip
                preview
                modeChips
                switch mode {
                case .pages: pageControls
                case .sign: signControls
                case .text: textControls
                case .export: exportControls
                }
            }
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .onAppear { if Launch.sample, pages.isEmpty { append([SampleAssets.document(), SampleAssets.receipt()]) } }
        .fullScreenCover(isPresented: $showScanner) {
            DocCameraSheet { images in showScanner = false; append(images) }.ignoresSafeArea()
        }
        .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { res in
            if case .success(let urls) = res { importPDFs(urls) }
        }
        .onChange(of: photoItems) { _, items in loadPhotos(items) }
        .onChange(of: selected) { old, new in commitInk(to: old); loadInk(from: new); selectedStamp = nil; ocrText = "" }
        .onChange(of: mode) { old, _ in if old == .sign { commitInk(to: selected); inking = false } }
        .sheet(isPresented: $showSignaturePad) { SignaturePadSheet { img in savedSignature = img } }
    }

    // MARK: empty + add

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Button { showScanner = true } label: { Label("Scan with the camera", systemImage: "doc.viewfinder").frame(maxWidth: .infinity) }
                .primaryButton().disabled(!VNDocumentCameraViewController.isSupported)
            PhotosPicker(selection: $photoItems, maxSelectionCount: 40, matching: .images) {
                Label("Choose photos of pages", systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
            }.secondaryButton()
            Button { showPDFImporter = true } label: { Label("Open a PDF (or several, to merge)", systemImage: "doc.fill").frame(maxWidth: .infinity) }.secondaryButton()
            Text("Auto-crop and flatten · enhance, grayscale or black-and-white · sign with a saved signature · type into form fields · copy the text · export a PDF you can search, under any size limit, or split.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private var addMenu: some View {
        Menu {
            Button { showScanner = true } label: { Label("Scan more pages", systemImage: "doc.viewfinder") }.disabled(!VNDocumentCameraViewController.isSupported)
            Button { showPDFImporter = true } label: { Label("Add a PDF", systemImage: "doc.fill") }
        } label: {
            VStack { Image(systemName: "plus").font(.system(size: 20, weight: .semibold)); Text("Add").font(HandyFont.micro) }
                .foregroundStyle(HandyColor.accent).frame(width: 56, height: 74)
                .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: strip + preview

    private var pageStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HandySpacing.s8) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { i, p in
                    Button { selected = i } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(uiImage: thumb(p)).resizable().scaledToFit().frame(width: 56, height: 74)
                                .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(i == selected ? HandyColor.accent : HandyColor.border, lineWidth: i == selected ? 2.5 : 1))
                            Text("\(i + 1)").font(HandyFont.micro).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(i == selected ? HandyColor.accent : HandyColor.textSecondary, in: Capsule()).offset(x: -3, y: -3)
                        }
                    }.buttonStyle(.plain)
                }
                PhotosPicker(selection: $photoItems, maxSelectionCount: 40, matching: .images) {
                    VStack { Image(systemName: "photo").font(.system(size: 18)); Text("Photos").font(HandyFont.micro) }
                        .foregroundStyle(HandyColor.accent).frame(width: 56, height: 74)
                        .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                addMenu
            }.padding(.vertical, 2)
        }
    }

    private var preview: some View {
        GeometryReader { geo in
            if let page {
                let img = cleaned(page)
                let fitted = fitSize(img.size, in: geo.size)
                ZStack {
                    Image(uiImage: img).resizable().scaledToFit()
                    ForEach(page.stamps) { st in stampView(st, in: fitted) }
                    if mode == .sign && inking { InkCanvas(canvas: canvas) }
                }
                .frame(width: fitted.width, height: fitted.height)
                .coordinateSpace(name: "page")
                .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .frame(height: 340)
    }

    private func stampView(_ st: DocEngine.Stamp, in size: CGSize) -> some View {
        let w = st.width * size.width
        return Group {
            switch st.kind {
            case .signature(let img):
                Image(uiImage: img).resizable().scaledToFit().frame(width: w)
            case .text(let s):
                Text(s).font(.system(size: DocEngine.fontSize(for: s, width: w))).foregroundStyle(Color(st.color)).lineLimit(1).fixedSize()
            }
        }
        .padding(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(selectedStamp == st.id && mode == .sign ? HandyColor.accent : .clear, style: StrokeStyle(lineWidth: 1, dash: [4])))
        .position(x: st.center.x * size.width, y: st.center.y * size.height)
        .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("page")).onChanged { v in
            guard mode == .sign, !inking else { return }
            selectedStamp = st.id
            update(st.id) { $0.center = CGPoint(x: min(1, max(0, v.location.x / size.width)), y: min(1, max(0, v.location.y / size.height))) }
        })
        .simultaneousGesture(TapGesture().onEnded { if mode == .sign { selectedStamp = st.id } })
        .allowsHitTesting(mode == .sign && !inking)
    }

    private var modeChips: some View {
        HandyFlow(spacing: HandySpacing.s8) {
            ForEach(Mode.allCases, id: \.rawValue) { m in HChip(text: m.title, selected: mode == m) { mode = m; errorText = nil } }
        }
    }

    // MARK: clean up

    private var pageControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(DocEngine.Filter.allCases, id: \.rawValue) { f in
                    HChip(text: f.title, selected: page?.filter == f) { update(selected) { $0.filter = f; $0.ocr = nil } }
                }
            }
            HStack(spacing: HandySpacing.s8) {
                Button { rotate() } label: { Label("Rotate", systemImage: "rotate.right") }.compactButton()
                Button { move(-1) } label: { Image(systemName: "arrow.left") }.compactButton().disabled(selected == 0)
                Button { move(1) } label: { Image(systemName: "arrow.right") }.compactButton().disabled(selected >= pages.count - 1)
                Button(role: .destructive) { remove() } label: { Image(systemName: "trash") }.compactButton()
            }
            Button { applyFilterToAll() } label: { Label("Apply this look to every page", systemImage: "square.on.square") }.textButton()
            Text("Page \(selected + 1) of \(pages.count). Enhance fixes shadows and uneven lighting; Black & white makes the smallest, crispest forms.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    // MARK: sign & fill

    private var signControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s8) {
                Button { toggleInk() } label: { Label(inking ? "Done drawing" : "Draw", systemImage: inking ? "checkmark" : "pencil.tip").frame(maxWidth: .infinity) }
                    .buttonStyle(inking ? AnyButtonStyle(HandyPrimaryButtonStyle()) : AnyButtonStyle(HandySecondaryButtonStyle()))
                if let savedSignature {
                    Button { place(.signature(savedSignature)) } label: { Label("Place signature", systemImage: "signature").frame(maxWidth: .infinity) }.secondaryButton().disabled(inking)
                } else {
                    Button { showSignaturePad = true } label: { Label("Save a signature", systemImage: "signature").frame(maxWidth: .infinity) }.secondaryButton().disabled(inking)
                }
            }
            HStack(spacing: HandySpacing.s8) {
                TextField("Type a name, date, or answer…", text: $newText)
                    .padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .submitLabel(.done).onSubmit { addText() }
                Button { addText() } label: { Text("Add") }.compactButton().disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty || inking)
            }
            if let sid = selectedStamp, let st = page?.stamps.first(where: { $0.id == sid }) {
                HStack(spacing: HandySpacing.s8) {
                    Text("Size").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Slider(value: Binding(get: { st.width }, set: { w in update(sid) { $0.width = w } }), in: 0.06...0.9).tint(HandyColor.accent)
                    Button(role: .destructive) { update(selected) { $0.stamps.removeAll { $0.id == sid } }; selectedStamp = nil } label: { Image(systemName: "trash") }.compactButton()
                }
            }
            HStack {
                if savedSignature != nil {
                    Button { showSignaturePad = true } label: { Label("Redo signature", systemImage: "arrow.counterclockwise") }.textButton()
                }
                Button { update(selected) { $0.ink = PKDrawing(); $0.stamps = [] }; canvas.drawing = PKDrawing(); selectedStamp = nil } label: { Label("Clear this page", systemImage: "eraser") }.textButton()
                Spacer()
            }
            Text(inking ? "Draw on the page with your finger. Tap Done drawing when finished."
                        : "Drag a signature or text into place; tap it to resize. Everything is burned into the page on export.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    // MARK: text

    private var textControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if ocrText.isEmpty {
                Button { runOCR(all: false) } label: { HStack { if ocrBusy { ProgressView().tint(.white) }; Text(ocrBusy ? "Reading…" : "Read this page") }.frame(maxWidth: .infinity) }.primaryButton().disabled(ocrBusy)
                Button { runOCR(all: true) } label: { Label("Read every page", systemImage: "doc.text.magnifyingglass").frame(maxWidth: .infinity) }.secondaryButton().disabled(ocrBusy)
            } else {
                ScrollView { Text(ocrText).font(HandyFont.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 220).padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                HStack(spacing: HandySpacing.s8) {
                    Button { UIPasteboard.general.string = ocrText; HandyHaptics.success() } label: { Label("Copy", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.primaryButton()
                    ShareLink(item: ocrText) { Label("Share text", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
                }
                Button { runOCR(all: true) } label: { Label("Read every page", systemImage: "doc.text.magnifyingglass") }.textButton()
            }
        }
    }

    // MARK: export

    private var exportControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Toggle(isOn: $searchable) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Searchable PDF").font(HandyFont.body)
                    Text("Adds an invisible text layer so Find, select and copy work in any reader.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }.tint(HandyColor.accent)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(DocEngine.PageSize.allCases, id: \.rawValue) { s in HChip(text: s.title, selected: pageSize == s) { pageSize = s } }
            }
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(0..<limits.count, id: \.self) { i in HChip(text: limits[i].0, selected: (limitIdx ?? 0) == i) { limitIdx = i == 0 ? nil : i } }
            }
            HStack(spacing: HandySpacing.s8) {
                Toggle("Split", isOn: $splitting).tint(HandyColor.accent).font(HandyFont.body).fixedSize()
                if splitting {
                    TextField("e.g. 1-2, 3, 4-  (blank = every page)", text: $splitSpec)
                        .padding(HandySpacing.s12)
                        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                }
                Spacer(minLength: 0)
            }

            if !store.isPremium { QuotaChip(name: "scan", limit: Limits.freeScanPerDay).environmentObject(store) }
            if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freeScanPerDay) free exports.") }

            Button { export() } label: {
                HStack { if working { ProgressView().tint(.white) }; Text(working ? "Building PDF…" : exportLabel) }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(working || overQuota)

            if !outputs.isEmpty {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    HStack(spacing: HandySpacing.s8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(HandyColor.success)
                        Text(outputs.count == 1 ? "PDF ready — \(SizeTarget.format(outputBytes))" : "\(outputs.count) PDFs ready — \(SizeTarget.format(outputBytes)) total").font(HandyFont.bodyStrong)
                    }
                    ShareLink(items: outputs) { Label(outputs.count == 1 ? "Save or share PDF" : "Save or share all", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
                    if jpgOutputs.isEmpty {
                        Button { exportJPGs() } label: { Label("Pages as JPGs instead", systemImage: "photo.stack") }.textButton()
                    } else {
                        ShareLink(items: jpgOutputs) { Label("Save or share \(jpgOutputs.count) JPG\(jpgOutputs.count == 1 ? "" : "s")", systemImage: "photo.stack").frame(maxWidth: .infinity) }.secondaryButton()
                    }
                }.cardStyle(padding: HandySpacing.s12)
            }
        }
    }

    private var exportLabel: String {
        var s = splitting ? "Split & export" : "Export \(pages.count) page\(pages.count == 1 ? "" : "s")"
        if let i = limitIdx { s += " \(limits[i].0.lowercased())" }
        return s
    }

    // MARK: helpers

    private func fitSize(_ s: CGSize, in box: CGSize) -> CGSize {
        guard s.width > 0, s.height > 0, box.width > 0, box.height > 0 else { return box }
        let k = min(box.width / s.width, box.height / s.height)
        return CGSize(width: (s.width * k).rounded(), height: (s.height * k).rounded())
    }

    private func cleaned(_ p: DocEngine.Page) -> UIImage { previews.image(for: p) }
    private func thumb(_ p: DocEngine.Page) -> UIImage { previews.image(for: p) }

    private func update(_ index: Int, _ f: (inout DocEngine.Page) -> Void) {
        guard pages.indices.contains(index) else { return }
        f(&pages[index])
    }
    private func update(_ stampID: UUID, _ f: (inout DocEngine.Stamp) -> Void) {
        guard let i = pages[selected].stamps.firstIndex(where: { $0.id == stampID }) else { return }
        f(&pages[selected].stamps[i])
    }

    private func append(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        let wasEmpty = pages.isEmpty
        pages.append(contentsOf: images.map { DocEngine.Page(source: $0.normalizedUp()) })
        if wasEmpty { selected = 0 } else { selected = pages.count - images.count }
        outputs = []; errorText = nil
        HandyHaptics.light()
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var imgs: [UIImage] = []
            for it in items { if let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d) { imgs.append(img.resized(maxDimension: 2400)) } }
            let got = imgs
            await MainActor.run {
                append(got)
                // photos are usually not paper — start them on the original look
                for i in max(0, pages.count - got.count)..<pages.count { pages[i].filter = .color }
                photoItems = []
            }
        }
    }

    private func importPDFs(_ urls: [URL]) {
        working = true
        Task.detached(priority: .userInitiated) {
            var imgs: [UIImage] = []
            for u in urls { imgs.append(contentsOf: DocEngine.importPDF(u)) }
            let got = imgs
            await MainActor.run {
                working = false
                if got.isEmpty { errorText = "Couldn't read those PDFs." } else { append(got); for i in max(0, pages.count - got.count)..<pages.count { pages[i].filter = .color } }
            }
        }
    }

    private func rotate() {
        commitInk(to: selected)
        update(selected) { p in
            p.rotation = (p.rotation + 1) % 4; p.ocr = nil
            p.stamps = p.stamps.map { var s = $0; s.center = CGPoint(x: 1 - $0.center.y, y: $0.center.x); return s }
            if p.inkCanvas.width > 0 {
                let h = p.inkCanvas.height
                p.ink = p.ink.transformed(using: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: h, ty: 0))
                p.inkCanvas = CGSize(width: h, height: p.inkCanvas.width)
            }
        }
        loadInk(from: selected)
    }
    private func move(_ d: Int) {
        let j = selected + d
        guard pages.indices.contains(j) else { return }
        commitInk(to: selected); pages.swapAt(selected, j); selected = j
    }
    private func remove() {
        guard pages.indices.contains(selected) else { return }
        pages.remove(at: selected); selected = min(selected, max(0, pages.count - 1)); outputs = []
        if !pages.isEmpty { loadInk(from: selected) }
    }
    private func applyFilterToAll() {
        guard let f = page?.filter else { return }
        for i in pages.indices { update(i) { $0.filter = f; $0.ocr = nil } }
        HandyHaptics.light()
    }

    // ink lives in the canvas while editing; commit it to the page model when we leave the page
    private func commitInk(to index: Int) {
        guard pages.indices.contains(index) else { return }
        pages[index].ink = canvas.drawing
        pages[index].inkCanvas = canvas.bounds.size
    }
    private func loadInk(from index: Int) {
        guard pages.indices.contains(index) else { return }
        canvas.drawing = pages[index].ink
    }
    private func toggleInk() {
        if inking { commitInk(to: selected) } else { loadInk(from: selected) }
        inking.toggle()
    }
    private func place(_ kind: DocEngine.Stamp.Kind) {
        var st = DocEngine.Stamp(kind: kind)
        if case .text = kind { st.width = 0.25 }
        update(selected) { $0.stamps.append(st) }
        selectedStamp = st.id
    }
    private func addText() {
        let t = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        place(.text(t)); newText = ""
    }

    private func runOCR(all: Bool) {
        commitInk(to: selected)
        ocrBusy = true
        let targets: [Int] = all ? Array(pages.indices) : [selected]
        let snapshot = targets.map { (i: $0, page: pages[$0]) }
        Task.detached(priority: .userInitiated) {
            var results: [(Int, [DocEngine.OCRLine])] = []
            for (i, p) in snapshot { results.append((i, p.ocr ?? DocEngine.recognize(DocEngine.render(p)))) }
            let done = results
            await MainActor.run {
                for (i, lines) in done where pages.indices.contains(i) { pages[i].ocr = lines }
                let chunks = done.map { (i, lines) in (all && done.count > 1 ? "— Page \(i + 1) —\n" : "") + DocEngine.text(lines) }
                ocrText = chunks.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if ocrText.isEmpty { ocrText = ""; errorText = "No readable text found on \(all ? "these pages" : "this page")." } else { errorText = nil }
                ocrBusy = false
            }
        }
    }

    private func exportJPGs() {
        commitInk(to: selected)
        let snapshot = pages
        Task.detached(priority: .userInitiated) {
            var urls: [URL] = []
            for (i, p) in snapshot.enumerated() {
                guard let d = DocEngine.render(p).jpegData(compressionQuality: 0.9) else { continue }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("Scan-page\(i + 1).jpg")
                try? FileManager.default.removeItem(at: url)
                if (try? d.write(to: url)) != nil { urls.append(url) }
            }
            let out = urls
            await MainActor.run { jpgOutputs = out; if !out.isEmpty { HandyHaptics.success() } }
        }
    }

    private func export() {
        guard !pages.isEmpty, Usage.use("scan", limit: Limits.freeScanPerDay) else { return }
        commitInk(to: selected)
        working = true; errorText = nil; outputs = []; jpgOutputs = []
        let snapshot = pages, opts = DocEngine.PDFOptions(searchable: searchable, pageSize: pageSize)
        let limit = limitIdx.map { limits[$0].1 } ?? 0, split = splitting, spec = splitSpec
        Task.detached(priority: .userInitiated) {
            let data: Data? = limit > 0 ? DocEngine.pdfUnder(snapshot, targetBytes: limit, base: opts) : DocEngine.pdf(snapshot, options: opts)
            var files: [URL] = []
            if let data {
                let parts = split ? DocEngine.split(data, ranges: spec) : [data]
                for (i, d) in parts.enumerated() {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(split ? "Scan-part\(i + 1).pdf" : "Scan-\(Int(Date().timeIntervalSince1970)).pdf")
                    try? FileManager.default.removeItem(at: url)
                    if (try? d.write(to: url)) != nil { files.append(url) }
                }
            }
            let out = files, total = files.reduce(0) { $0 + (SizeTarget.fileSize($1) ?? 0) }
            await MainActor.run {
                working = false
                if out.isEmpty { errorText = limit > 0 ? "Couldn't get it under that size. Try Black & white, fewer pages, or a larger limit." : "Couldn't build the PDF." }
                else { outputs = out; outputBytes = total; HandyHaptics.success(); Interstitials.shared.showIfReady() }
            }
        }
    }
}

// MARK: - pieces

/// Cleaned-page previews, computed off the main thread and keyed by what affects the look, so the
/// strip and the big preview never run Core Image during a layout pass.
@MainActor final class PreviewStore: ObservableObject {
    @Published private var images: [String: UIImage] = [:]
    private var pending: Set<String> = []
    private func key(_ p: DocEngine.Page) -> String { "\(p.id)-\(p.filter.rawValue)-\(p.rotation)" }

    /// Cached cleaned preview, or the raw source while one is being prepared.
    func image(for p: DocEngine.Page) -> UIImage {
        let k = key(p)
        if let img = images[k] { return img }
        if !pending.contains(k) {
            pending.insert(k)
            let src = p.source, f = p.filter, r = p.rotation
            Task.detached(priority: .userInitiated) {
                let img = DocEngine.clean(src, filter: f).rotated(quarterTurns: r).resized(maxDimension: 1400)
                await MainActor.run { self.images[k] = img; self.pending.remove(k) }
            }
        }
        return p.source
    }
}

/// Apple's edge-detecting document camera (multi-page, auto-crop, perspective fix).
private struct DocCameraSheet: UIViewControllerRepresentable {
    let done: ([UIImage]) -> Void
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController { let v = VNDocumentCameraViewController(); v.delegate = context.coordinator; return v }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(done: done) }
    final class Coord: NSObject, VNDocumentCameraViewControllerDelegate {
        let done: ([UIImage]) -> Void
        init(done: @escaping ([UIImage]) -> Void) { self.done = done }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) { done((0..<scan.pageCount).map { scan.imageOfPage(at: $0) }) }
        func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) { done([]) }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFailWithError e: Error) { done([]) }
    }
}

/// Transparent PencilKit canvas over the page.
private struct InkCanvas: UIViewRepresentable {
    let canvas: PKCanvasView
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
        return canvas
    }
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

/// Draw once, keep forever: a white pad that saves a trimmed transparent signature.
private struct SignaturePadSheet: View {
    let saved: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pad = PKCanvasView()
    var body: some View {
        NavigationStack {
            VStack(spacing: HandySpacing.s16) {
                Text("Sign in the box with your finger. It's saved on this phone only.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                ZStack {
                    RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).fill(Color.white)
                    Rectangle().fill(HandyColor.border).frame(height: 1).padding(.horizontal, 24).offset(y: 50)
                    InkCanvas(canvas: pad)
                }
                .frame(height: 220)
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                HStack {
                    Button { pad.drawing = PKDrawing() } label: { Label("Clear", systemImage: "eraser") }.textButton()
                    Spacer()
                }
                Button {
                    if let img = DocEngine.saveSignature(pad.drawing) { saved(img); HandyHaptics.success(); dismiss() }
                } label: { Text("Save signature").frame(maxWidth: .infinity) }.primaryButton().padding(.top, HandySpacing.s8)
                Spacer()
            }
            .padding(HandySpacing.gutter)
            .background(HandyColor.bg)
            .navigationTitle("Your signature").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

/// Lets a button switch between the primary and secondary looks at runtime.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
