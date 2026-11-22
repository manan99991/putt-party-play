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
    // what it is (read from the first page's words)
    @State private var smart: ScanSmart.Read?
    @State private var smartFor: UUID?
    @State private var reminded: Bool?
    @State private var watermarkID = true
    @State private var idWords = ""

    private let limits: [(String, Int)] = [("No limit", 0), ("Under 10 MB", 10_000_000), ("Under 5 MB", 5_000_000), ("Under 2 MB", 2_000_000), ("Under 1 MB", 1_000_000), ("Under 500 KB", 500_000)]
    private var overQuota: Bool { !Usage.hasRoom("scan", limit: Limits.freeScanPerDay) }
    private var page: DocEngine.Page? { pages.indices.contains(selected) ? pages[selected] : nil }

    var body: some View {
        ToolPage(title: "Scan", subtitle: "Scan or import pages, clean them up, sign and fill, then export a searchable PDF that fits.", working: working) {
            HowTo("scan", [
                "Add pages with the camera or from Photos.",
                "Pick a mode — clean up, sign or fill — and a filter like black & white.",
                "Export as a PDF; set a size limit or split pages if you need.",
            ])
            if pages.isEmpty {
                emptyState
            } else {
                pageStrip
                smartCard.task(id: pages.first?.id) { readWhatItIs() }
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
            if pages.isEmpty { AlsoInThisTool(hub: "scan") }
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
            Button { showScanner = true } label: { Label(L("Scan with the camera"), systemImage: "doc.viewfinder").frame(maxWidth: .infinity) }
                .primaryButton().disabled(!VNDocumentCameraViewController.isSupported)
            PhotosPicker(selection: $photoItems, maxSelectionCount: 40, matching: .images) {
                Label(L("Choose photos of pages"), systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
            }.secondaryButton()
            Button { showPDFImporter = true } label: { Label(L("Open a PDF (or several, to merge)"), systemImage: "doc.fill").frame(maxWidth: .infinity) }.secondaryButton()
            Text(L("Auto-crop and flatten · enhance, grayscale or black-and-white · sign with a saved signature · type into form fields · copy the text · export a PDF you can search, under any size limit, or split."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private var addMenu: some View {
        Menu {
            Button { showScanner = true } label: { Label(L("Scan more pages"), systemImage: "doc.viewfinder") }.disabled(!VNDocumentCameraViewController.isSupported)
            Button { showPDFImporter = true } label: { Label(L("Add a PDF"), systemImage: "doc.fill") }
        } label: {
            VStack { Image(systemName: "plus").font(.system(size: 20, weight: .semibold)); Text(L("Add")).font(HandyFont.micro) }
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
                    VStack { Image(systemName: "photo").font(.system(size: 18)); Text(L("Photos")).font(HandyFont.micro) }
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
                Button { rotate() } label: { Label(L("Rotate"), systemImage: "rotate.right") }.compactButton()
                Button { move(-1) } label: { Image(systemName: "arrow.left") }.compactButton().disabled(selected == 0).accessibilityLabel(L("Move page left"))
                Button { move(1) } label: { Image(systemName: "arrow.right") }.compactButton().disabled(selected >= pages.count - 1).accessibilityLabel(L("Move page right"))
                Button(role: .destructive) { remove() } label: { Image(systemName: "trash") }.compactButton().accessibilityLabel(L("Delete page"))
            }
            Button { applyFilterToAll() } label: { Label(L("Apply this look to every page"), systemImage: "square.on.square") }.textButton()
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
                    Button { place(.signature(savedSignature)) } label: { Label(L("Place signature"), systemImage: "signature").frame(maxWidth: .infinity) }.secondaryButton().disabled(inking)
                } else {
                    Button { showSignaturePad = true } label: { Label(L("Save a signature"), systemImage: "signature").frame(maxWidth: .infinity) }.secondaryButton().disabled(inking)
                }
            }
            HStack(spacing: HandySpacing.s8) {
                TextField(L("Type a name, date, or answer…"), text: $newText)
                    .padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .submitLabel(.done).onSubmit { addText() }
                Button { addText() } label: { Text(L("Add")) }.compactButton().disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let sid = selectedStamp, let st = page?.stamps.first(where: { $0.id == sid }) {
                HStack(spacing: HandySpacing.s8) {
                    Text(L("Size")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Slider(value: Binding(get: { st.width }, set: { w in update(sid) { $0.width = w } }), in: 0.06...0.9).tint(HandyColor.accent)
                    Button(role: .destructive) { update(selected) { $0.stamps.removeAll { $0.id == sid } }; selectedStamp = nil } label: { Image(systemName: "trash") }.compactButton().accessibilityLabel(L("Remove stamp"))
                }
            }
            HStack {
                if savedSignature != nil {
                    Button { showSignaturePad = true } label: { Label(L("Redo signature"), systemImage: "arrow.counterclockwise") }.textButton()
                }
                Button { update(selected) { $0.ink = PKDrawing(); $0.stamps = [] }; canvas.drawing = PKDrawing(); selectedStamp = nil } label: { Label(L("Clear this page"), systemImage: "eraser") }.textButton()
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
                Button { runOCR(all: false) } label: { HStack { if ocrBusy { BusySpinner().tint(.white) }; Text(ocrBusy ? "Reading…" : "Read this page") }.frame(maxWidth: .infinity) }.primaryButton().disabled(ocrBusy)
                Button { runOCR(all: true) } label: { Label(L("Read every page"), systemImage: "doc.text.magnifyingglass").frame(maxWidth: .infinity) }.secondaryButton().disabled(ocrBusy)
            } else {
                ScrollView { Text(ocrText).font(HandyFont.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 220).padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                HStack(spacing: HandySpacing.s8) {
                    Button { Copier.copy(ocrText) } label: { Label(L("Copy"), systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.primaryButton()
                    ShareLink(item: ocrText) { Label(L("Share text"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
                }
                Button { runOCR(all: true) } label: { Label(L("Read every page"), systemImage: "doc.text.magnifyingglass") }.textButton()
            }
        }
    }

    // MARK: export

    private var exportControls: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Toggle(isOn: $searchable) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Searchable PDF")).font(HandyFont.body)
                    Text(L("Adds an invisible text layer so Find, select and copy work in any reader.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }.tint(HandyColor.accent)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(DocEngine.PageSize.allCases, id: \.rawValue) { s in HChip(text: s.title, selected: pageSize == s) { pageSize = s } }
            }
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(0..<limits.count, id: \.self) { i in HChip(text: limits[i].0, selected: (limitIdx ?? 0) == i) { limitIdx = i == 0 ? nil : i } }
            }
            HStack(spacing: HandySpacing.s8) {
                Toggle(L("Split"), isOn: $splitting).tint(HandyColor.accent).font(HandyFont.body).fixedSize()
                if splitting {
                    TextField(L("e.g. 1-2, 3, 4-  (blank = every page)"), text: $splitSpec)
                        .padding(HandySpacing.s12)
                        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                }
                Spacer(minLength: 0)
            }

            if !store.isPremium { QuotaChip(name: "scan", limit: Limits.freeScanPerDay).environmentObject(store) }
            if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freeScanPerDay) free exports.") }

            Button { export() } label: {
                HStack { if working { BusySpinner().tint(.white) }; Text(working ? "Building PDF…" : exportLabel) }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(working || overQuota)
            if working { ToolProgressBar(label: "Building your PDF…") }

            if !outputs.isEmpty {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    HStack(spacing: HandySpacing.s8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(HandyColor.success)
                        Text(outputs.count == 1 ? "PDF ready — \(SizeTarget.format(outputBytes))" : "\(outputs.count) PDFs ready — \(SizeTarget.format(outputBytes)) total").font(HandyFont.bodyStrong)
                    }
                    KeepShare(outputs.map(KeepItem.file), tool: "Scan")
                    if jpgOutputs.isEmpty {
                        Button { exportJPGs() } label: { Label(L("Pages as JPGs instead"), systemImage: "photo.stack") }.textButton()
                    } else {
                        KeepShare(jpgOutputs.map(KeepItem.file), tool: "Scan")
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
        // If a drawing is in progress, keep it (burn it into the page) and leave draw mode, so typing a
        // name and tapping Add always lands the text instead of silently doing nothing.
        if inking { commitInk(to: selected); inking = false }
        place(.text(t)); newText = ""
    }

    /// Read the first page once (its text is kept for export), and work out what it is.
    private func readWhatItIs() {
        guard let first = pages.first, smartFor != first.id else { return }
        smartFor = first.id; reminded = nil
        let p = first
        Task.detached(priority: .utility) {
            let lines = p.ocr ?? DocEngine.recognize(DocEngine.render(p))
            let r = ScanSmart.read(DocEngine.text(lines))
            await MainActor.run {
                if let i = pages.firstIndex(where: { $0.id == p.id }), pages[i].ocr == nil { pages[i].ocr = lines }
                smart = lines.isEmpty ? nil : r
            }
        }
    }

    @ViewBuilder private var smartCard: some View {
        if let smart {
            VStack(alignment: .leading, spacing: 6) {
                Label(L(smart.summary), systemImage: ["bill": "doc.text.fill", "receipt": "receipt", "letter": "envelope.fill", "form": "square.and.pencil", "id": "person.text.rectangle", "other": "doc"][smart.kind.rawValue] ?? "doc")
                    .font(HandyFont.bodyStrong).fixedSize(horizontal: false, vertical: true)
                Text("\(L("Saved as")) “\(smart.name).pdf”").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                switch smart.kind {
                case .bill, .letter:
                    if smart.due != nil {
                        Button {
                            Task { reminded = (try? await ScanSmart.remind(smart)) ?? false; if reminded == true { HandyHaptics.success() } }
                        } label: { Label(L(reminded == true ? "Reminder set: 3 days before and on the day" : "Remind me 3 days before and on the day"), systemImage: reminded == true ? "checkmark.circle.fill" : "bell.badge").frame(maxWidth: .infinity) }
                            .secondaryButton().disabled(reminded == true).accessibilityIdentifier("scan-remind")
                        if reminded == false { Button(L("Allow Reminders for Tenzy — open Settings")) { Permission.openSettings() }.textButton() }
                    }
                case .form:
                    Button { mode = .sign } label: { Label(L("Sign and fill it"), systemImage: "signature").frame(maxWidth: .infinity) }.secondaryButton()
                case .id:
                    Toggle(L("Write who it's for across the copy, so it can't be reused"), isOn: $watermarkID).tint(HandyColor.accent).font(HandyFont.caption)
                    if watermarkID { WatermarkWordsCard(words: $idWords, storeKey: "tenzy.watermark.scan-id") }
                case .receipt:
                    Text(L("Tip: Warranty & Receipts keeps it with a return-by reminder.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                case .other: EmptyView()
                }
            }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
        }
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
        guard !pages.isEmpty, Usage.hasRoom("scan", limit: Limits.freeScanPerDay) else { return }
        commitInk(to: selected)
        working = true; errorText = nil; outputs = []; jpgOutputs = []
        let snapshot = pages, opts = DocEngine.PDFOptions(searchable: searchable, pageSize: pageSize)
        let limit = limitIdx.map { limits[$0].1 } ?? 0, split = splitting, spec = splitSpec
        let base = smart?.name ?? "Scan \(Date().formatted(.dateTime.day().month(.abbreviated).year()))", mark = smart?.kind == .id && watermarkID, markLine = IDCopyCheck.line(idWords)
        Task.detached(priority: .userInitiated) {
            let data: Data? = limit > 0 ? DocEngine.pdfUnder(snapshot, targetBytes: limit, base: opts) : DocEngine.pdf(snapshot, options: opts)
            var files: [URL] = []
            if let data {
                let marked = mark ? (PDFOverlay.watermark(data, text: markLine) ?? data) : data
                let parts = split ? DocEngine.split(marked, ranges: spec) : [marked]
                for (i, d) in parts.enumerated() {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(split ? "\(base) part \(i + 1).pdf" : "\(base).pdf")
                    try? FileManager.default.removeItem(at: url)
                    if (try? d.write(to: url)) != nil { files.append(url) }
                }
            }
            let out = files, total = files.reduce(0) { $0 + (SizeTarget.fileSize($1) ?? 0) }
            await MainActor.run {
                working = false
                if out.isEmpty { errorText = limit > 0 ? "Couldn't get it under that size. Try Black & white, fewer pages, or a larger limit." : "Couldn't build the PDF." }
                else { _ = Usage.use("scan", limit: Limits.freeScanPerDay); outputs = out; outputBytes = total; HandyHaptics.success(); Interstitials.shared.showIfReady() }
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
struct DocCameraSheet: UIViewControllerRepresentable {
    let done: ([UIImage]) -> Void
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController { let v = VNDocumentCameraViewController(); v.delegate = context.coordinator; return v }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(done: done) }
    final class Coord: NSObject, VNDocumentCameraViewControllerDelegate {
        let done: ([UIImage]) -> Void
        init(done: @escaping ([UIImage]) -> Void) { self.done = done }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Every scanned page comes back as just the document: fingers that held it are painted out.
            let pages = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            let done = self.done
            Task.detached(priority: .userInitiated) {
                let clean = pages.map { PageFlatten.withoutHands($0) }
                await MainActor.run { done(clean) }
            }
        }
        func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) { done([]) }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFailWithError e: Error) { done([]) }
    }
}

/// Transparent PencilKit canvas over the page.
private struct InkCanvas: UIViewRepresentable {
    let canvas: PKCanvasView
    /// Called after every stroke (and on Clear), so Save can stay off until there's real ink.
    var changed: ((PKDrawing) -> Void)? = nil
    func makeCoordinator() -> Coord { Coord(changed: changed) }
    final class Coord: NSObject, PKCanvasViewDelegate {
        let changed: ((PKDrawing) -> Void)?
        init(changed: ((PKDrawing) -> Void)?) { self.changed = changed }
        func canvasViewDrawingDidChange(_ v: PKCanvasView) { changed?(v.drawing) }
    }
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.delegate = context.coordinator
        // The pad is white paper in every theme. PencilKit flips black ink to WHITE in dark mode, so on the
        // white pad a signature was invisible and saved blank. Pin the canvas to light so ink stays black.
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        // PKCanvasView is a scroll view; inside a draggable sheet the finger pan gets eaten by the
        // sheet/scroll gesture instead of drawing. Turning scrolling off makes the canvas capture the
        // stroke, so a finger signature actually inks.
        canvas.isScrollEnabled = false
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
        return canvas
    }
    // Re-assert the pen each update, so a freshly created canvas always has a drawing tool.
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if !(uiView.tool is PKInkingTool) { uiView.tool = PKInkingTool(.pen, color: .black, width: 3) }
    }
}

/// Draw once, keep forever: a white pad that saves a trimmed transparent signature — the same pad on every door
/// (Sign PDF, Scan, the ready-made signing tools, Build your own). Drawn with our own finger tracking, not
/// PencilKit: PencilKit swapped black ink for white in dark mode and fought the sheet for the finger, which is how
/// signatures came out blank. Here the ink is exactly the colour picked, in every theme. Five pen colours, three
/// thicknesses, or type your name and pick a handwriting.
struct SignaturePadSheet: View {
    let saved: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []
    @State private var ink: SignatureInk = SignatureInk.remembered
    @State private var width: CGFloat = 3.2
    @State private var typing = false
    @State private var typed = ""
    @State private var hand: Int = 0
    @State private var problem: String?

    private var inked: Bool { typing ? !typed.trimmingCharacters(in: .whitespaces).isEmpty : !strokes.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s12) {
                    Picker("", selection: $typing) {
                        Text(L("Draw")).tag(false)
                        Text(L("Type my name")).tag(true)
                    }.pickerStyle(.segmented)
                    Text(L(typing ? "Type your name and pick a handwriting." : "Sign in the box with your finger. It's saved on this phone only."))
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    pad
                    // Pen colours — the ink on the pad changes straight away so you can see it before saving.
                    HStack(spacing: 12) {
                        ForEach(SignatureInk.all) { c in
                            Button { ink = c; SignatureInk.remembered = c } label: {
                                ZStack {
                                    Circle().fill(Color(c.ui)).frame(width: 32, height: 32)
                                    if ink == c { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) }
                                }
                                .overlay(Circle().stroke(ink == c ? HandyColor.accent : HandyColor.border, lineWidth: ink == c ? 3 : 1).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L(c.name)).accessibilityIdentifier("ink-\(c.id)")
                        }
                        Spacer()
                        if !typing {
                            Menu {
                                Button(L("Fine")) { width = 2.2 }
                                Button(L("Medium")) { width = 3.2 }
                                Button(L("Bold")) { width = 4.8 }
                            } label: { Image(systemName: "lineweight").font(.title3) }
                            .accessibilityLabel(L("Pen thickness"))
                        }
                    }
                    HStack {
                        Button { strokes = []; current = []; typed = ""; problem = nil } label: { Label(L("Clear"), systemImage: "eraser") }
                            .textButton().accessibilityIdentifier("signature-clear")
                        if !typing && !strokes.isEmpty {
                            Button { _ = strokes.popLast() } label: { Label(L("Undo"), systemImage: "arrow.uturn.backward") }.textButton()
                        }
                        Spacer()
                        if inked {
                            Label(L("Looks good"), systemImage: "checkmark.circle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success)
                                .accessibilityIdentifier("signature-looks-good")
                        }
                    }
                    if let problem { Text(L(problem)).font(HandyFont.caption).foregroundStyle(HandyColor.amber) }
                    Button { save() } label: { Text(L(inked ? "Save signature" : "Sign in the box first")).frame(maxWidth: .infinity) }
                        .primaryButton().disabled(!inked).padding(.top, HandySpacing.s4)
                }
                .padding(HandySpacing.gutter)
            }
            .scrollDisabled(!typing)   // drawing: nothing may scroll under the finger
            .background(HandyColor.bg)
            .navigationTitle(L("Your signature")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } } }
        }
        .presentationDetents([.large])
        // Swiping the sheet down must never steal the signing stroke: Cancel / Save are the way out.
        .interactiveDismissDisabled(true)
    }

    @ViewBuilder private var pad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).fill(Color.white)
            // The signing line, like paper.
            Rectangle().fill(Color.black.opacity(0.15)).frame(height: 1).padding(.horizontal, 24).offset(y: 50)
            Text("✕").font(.title3).foregroundStyle(Color.black.opacity(0.25)).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 18).offset(y: 34)
            if typing {
                if let img = SignatureInk.typedImage(typed, hand: hand, color: ink.ui) {
                    Image(uiImage: img).resizable().scaledToFit().padding(20)
                } else {
                    Text(L("Your name appears here")).foregroundStyle(Color.black.opacity(0.3))
                }
            } else {
                Canvas { ctx, _ in
                    for s in strokes + [current] where !s.isEmpty {
                        ctx.stroke(SignatureInk.path(s), with: .color(Color(ink.ui)), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                    }
                }
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { v in current.append(v.location); problem = nil }
                        .onEnded { _ in if !current.isEmpty { strokes.append(current) }; current = [] }
                )
                .accessibilityElement()
                .accessibilityLabel(L("Signature pad"))
                .accessibilityIdentifier("signature-pad")
                if strokes.isEmpty && current.isEmpty {
                    Text(L("Sign here")).foregroundStyle(Color.black.opacity(0.25)).allowsHitTesting(false)
                }
            }
        }
        .environment(\.colorScheme, .light)
        .frame(height: 220)
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
        if typing {
            TextField(L("Your name"), text: $typed)
                .textInputAutocapitalization(.words).autocorrectionDisabled()
                .padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("signature-typed")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SignatureInk.hands.indices, id: \.self) { i in
                        Button { hand = i } label: {
                            Text(typed.isEmpty ? L("Signature") : typed).font(Font(SignatureInk.handFont(i, size: 20) as CTFont))
                                .lineLimit(1).padding(.horizontal, 12).padding(.vertical, 8)
                                .background(hand == i ? HandyColor.accent.opacity(0.18) : HandyColor.surface, in: Capsule())
                                .overlay(Capsule().stroke(hand == i ? HandyColor.accent : HandyColor.border, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func save() {
        let img = typing ? SignatureInk.typedImage(typed, hand: hand, color: ink.ui, scale: 3)
                         : SignatureInk.image(strokes, color: ink.ui, width: width)
        if let img, let kept = DocEngine.saveSignature(image: img) { saved(kept); HandyHaptics.success(); dismiss() }
        else { problem = "That's too small to read as a signature — sign a little bigger." }
    }
}

/// Pen colours for signatures, and how a signature is turned into a clean see-through picture.
struct SignatureInk: Identifiable, Equatable {
    let id: String
    let name: String
    let hex: UInt32
    var ui: UIColor { UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1) }

    static let all = [
        SignatureInk(id: "black", name: "Black ink", hex: 0x111111),
        SignatureInk(id: "blue", name: "Blue ink", hex: 0x1D4ED8),
        SignatureInk(id: "navy", name: "Navy ink", hex: 0x1E2A78),
        SignatureInk(id: "red", name: "Red ink", hex: 0xB91C1C),
        SignatureInk(id: "green", name: "Green ink", hex: 0x166534),
    ]
    static var remembered: SignatureInk {
        get { all.first { $0.id == UserDefaults.standard.string(forKey: "tenzy.sign.ink") } ?? all[0] }
        set { UserDefaults.standard.set(newValue.id, forKey: "tenzy.sign.ink") }
    }

    /// A smooth line through the finger's points (curves between midpoints, so it reads like pen, not polygon).
    static func path(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        if pts.count == 1 { return Path(ellipseIn: CGRect(x: first.x - 1.2, y: first.y - 1.2, width: 2.4, height: 2.4)) }
        p.move(to: first)
        for i in 1..<pts.count {
            let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
            p.addQuadCurve(to: mid, control: pts[i - 1])
        }
        p.addLine(to: pts[pts.count - 1])
        return p
    }

    /// The strokes as a trimmed, see-through, sharp (3×) picture in the chosen ink. nil if there's nothing.
    static func image(_ strokes: [[CGPoint]], color: UIColor, width: CGFloat) -> UIImage? {
        let all = strokes.flatMap { $0 }
        guard !all.isEmpty else { return nil }
        let minX = all.map(\.x).min()!, maxX = all.map(\.x).max()!, minY = all.map(\.y).min()!, maxY = all.map(\.y).max()!
        let pad = width * 2 + 6
        let bounds = CGRect(x: minX - pad, y: minY - pad, width: maxX - minX + pad * 2, height: maxY - minY + pad * 2)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 3; fmt.opaque = false
        return UIGraphicsImageRenderer(size: bounds.size, format: fmt).image { r in
            let c = r.cgContext
            c.translateBy(x: -bounds.minX, y: -bounds.minY)
            c.setStrokeColor(color.cgColor); c.setFillColor(color.cgColor)
            c.setLineWidth(width); c.setLineCap(.round); c.setLineJoin(.round)
            for s in strokes where !s.isEmpty {
                c.addPath(path(s).cgPath)
                if s.count == 1 { c.fillPath() } else { c.strokePath() }
            }
        }
    }

    static let hands = ["SnellRoundhand-Black", "Zapfino", "BradleyHandITCTT-Bold", "Noteworthy-Bold", "SavoyeLetPlain"]
    static func handFont(_ i: Int, size: CGFloat) -> UIFont {
        UIFont(name: hands[max(0, min(hands.count - 1, i))], size: size) ?? .italicSystemFont(ofSize: size)
    }

    /// A typed name in a handwriting font, trimmed and see-through.
    static func typedImage(_ text: String, hand: Int, color: UIColor, scale: CGFloat = 2) -> UIImage? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let attrs: [NSAttributedString.Key: Any] = [.font: handFont(hand, size: 64), .foregroundColor: color]
        let s = (t as NSString).size(withAttributes: attrs)
        let size = CGSize(width: ceil(s.width) + 24, height: ceil(s.height) + 16)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = scale; fmt.opaque = false
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in (t as NSString).draw(at: CGPoint(x: 12, y: 8), withAttributes: attrs) }
    }
}

/// Lets a button switch between the primary and secondary looks at runtime.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
