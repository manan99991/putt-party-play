import SwiftUI
import PhotosUI
import VisionKit
import UniformTypeIdentifiers

/// Tenzy Builder (M2): run a starter or saved tool, or build your own by stacking blocks.
/// Everything here is data over built-in blocks (see ChainRunner), nothing is downloaded or generated as code.
struct BuilderView: View {
    @State private var mine: [Chain] = ChainStore.load()
    @State private var editing: Chain?
    @State private var running: Chain?
    @State private var note: String?
    @State private var ask = ""
    @State private var planning = false
    @State private var sheets: [RunningList.Sheet] = RunningList.all()
    @State private var showSheets = false

    var body: some View {
        ToolPage(title: "Build your own", subtitle: "Snap small steps together into a tool that does exactly what you need. Runs on your phone.") {
            hero
            if !mine.isEmpty {
                Text("My tools").font(HandyFont.cardTitle)
                ForEach(mine) { c in row(c, mine: true) }
            }
            if !sheets.isEmpty {
                Button { showSheets = true } label: {
                    HStack(spacing: HandySpacing.s12) {
                        Image(systemName: "tablecells").font(.system(size: 18, weight: .semibold)).foregroundStyle(HandyColor.accent).frame(width: 38, height: 38).background(HandyColor.accent.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("My sheets").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                            Text(sheets.count == 1 ? "1 sheet your tools add to" : "\(sheets.count) sheets your tools add to").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(HandyColor.textSecondary)
                    }.cardStyle(padding: HandySpacing.s12)
                }.buttonStyle(.plain).accessibilityIdentifier("open-sheets")
            }
            HStack {
                Text("Start from a template").font(HandyFont.cardTitle)
                Spacer()
                Button { editing = Chain(id: UUID().uuidString, name: "My tool", steps: []) } label: { Label("Blank", systemImage: "plus") }.font(HandyFont.caption)
                Button {
                    if let c = Chain.imported(from: UIPasteboard.general.string ?? "") { mine.append(c); persist(); note = "Added \(c.name)." }
                    else { note = "Copy a tool from another Tenzy first, then tap Paste." }
                } label: { Label("Paste", systemImage: "doc.on.clipboard") }.font(HandyFont.caption)
            }
            if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: HandySpacing.s12), GridItem(.flexible(), spacing: HandySpacing.s12)], spacing: HandySpacing.s12) {
                ForEach(ChainTemplates.all) { c in templateCard(c) }
            }
        }
        .sheet(item: $editing) { c in
            NavigationStack {
                ChainEditor(chain: c) { saved in
                    if let i = mine.firstIndex(where: { $0.id == saved.id }) { mine[i] = saved } else { mine.append(saved) }
                    persist(); editing = nil
                }
            }
        }
        .sheet(item: $running) { c in NavigationStack { ChainRunView(chain: c) } }
        .sheet(isPresented: $showSheets, onDismiss: { sheets = RunningList.all() }) { NavigationStack { SheetsView() } }
        .onChange(of: running?.id) { _, now in if now == nil { sheets = RunningList.all() } }   // a run may have added to a sheet
        .onAppear { openReminded() }
        .onReceive(NotificationCenter.default.publisher(for: .openTool)) { _ in openReminded() }
    }

    /// Saves the tools and keeps the phone's reminders in step with them.
    private func persist() { ChainStore.save(mine); ToolSchedules.sync(mine) }

    /// A tapped reminder lands here: open that tool ready to run.
    private func openReminded() {
        guard let id = ToolSchedules.takePending(), let c = mine.first(where: { $0.id == id }) else { return }
        editing = nil; running = c
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label("Describe it", systemImage: "sparkles").font(HandyFont.cardTitle)
            Text("Say what you want in your own words. Tenzy lines up the steps and shows you before anything runs.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            TextField("e.g. shrink a photo under 1 MB and remove its location", text: $ask, axis: .vertical)
                .lineLimit(1...3).textFieldStyle(.roundedBorder).accessibilityIdentifier("describe-field")
            Button {
                planning = true
                Task {
                    let p = await ChainPlanner.plan(ask)
                    await MainActor.run {
                        planning = false
                        if let p { editing = p.chain; note = nil }
                        else { note = "I couldn't turn that into steps yet. Try a template below, or mention what you start with (a photo, a receipt, some text) and what you want out." }
                    }
                }
            } label: { Label(planning ? "Working…" : "Build it for me", systemImage: "wand.and.stars").frame(maxWidth: .infinity) }
                .primaryButton().disabled(planning || ask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.cardStyle()
    }

    private func templateCard(_ c: Chain) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(spacing: -8) {
                ForEach(Array(c.steps.prefix(3).enumerated()), id: \.offset) { _, s in BlockBadge(block: s.block, size: 30).overlay(Circle().stroke(HandyColor.surface, lineWidth: 0)) }
            }
            Text(c.name).font(HandyFont.bodyStrong).lineLimit(2).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            HStack {
                Button("Use") { running = c }.font(HandyFont.micro)
                Spacer()
                Button("Edit copy") { var k = c; k.id = UUID().uuidString; k.name += " (mine)"; editing = k }.font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).cardStyle(padding: HandySpacing.s12)
    }

    private func row(_ c: Chain, mine isMine: Bool) -> some View {
        HStack(spacing: HandySpacing.s12) {
            if let f = c.steps.first { BlockBadge(block: f.block) }
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).font(HandyFont.bodyStrong)
                Text(c.steps.map(\.block.title).joined(separator: "  ›  ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
                if let when = c.schedule {
                    Label(when.label(uses24h: ToolSchedules.uses24h), systemImage: "bell").font(HandyFont.caption).foregroundStyle(HandyColor.accent)
                }
            }
            Spacer()
            Menu {
                Button("Edit") { editing = c }
                Button("Duplicate") {
                    var k = c; k.id = UUID().uuidString; k.name += " copy"; k.schedule = nil
                    mine.append(k); persist(); note = "Duplicated as \(k.name)."
                }
                Button("Copy to share") { UIPasteboard.general.string = c.shareText; note = "Copied. Paste it into Tenzy on another phone." }
                Button("Delete", role: .destructive) { mine.removeAll { $0.id == c.id }; persist() }
            } label: { Image(systemName: "ellipsis.circle").font(.system(size: 20)).frame(width: 44, height: 44) }
            Button("Run") { running = c }.secondaryButton().fixedSize()
        }.cardStyle(padding: HandySpacing.s12)
    }
}

/// The builder: a vertical flow from what you give, through each step, to what you get. Each step shows what it
/// does to a sample while you build, so you see the tool working before you save it.
private struct ChainEditor: View {
    @State var chain: Chain
    var onSave: (Chain) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var previews: [StepPreview?] = []
    @State private var inputPreview: StepPreview?

    private var startKind: ChainKind { chain.steps.first?.block.takes ?? .image }
    private var endKind: ChainKind? { chain.steps.last?.block.gives }
    /// What the person said they start with, before there is a first step to tell us.
    @State private var startChoice: ChainKind?
    private var options: [Block] {
        guard let end = endKind else { return startChoice.map(Block.starting(with:)) ?? [] }
        return Block.allCases.filter { end.feeds($0.takes) }
    }
    private var valid: Bool { chain.problem(starting: startKind) == nil && !chain.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TextField("Name your tool", text: $chain.name).font(HandyFont.title).padding(.bottom, HandySpacing.s16)
                if chain.steps.isEmpty, startChoice == nil {
                    startPicker
                } else {
                    let k = chain.steps.isEmpty ? (startChoice ?? .image) : startKind
                    node(icon: k == .text ? "text.alignleft" : "photo", title: "You give it \(k.label)", sub: chain.steps.isEmpty ? "Now add a first step. You only see steps that work with \(k.label)." : "Preview uses a sample so you can see each step work.")
                    if chain.steps.isEmpty {
                        Button("Start with something else") { startChoice = nil }.font(HandyFont.caption).padding(.top, HandySpacing.s8)
                    }
                }
                ForEach(Array(chain.steps.enumerated()), id: \.offset) { i, s in
                    connector
                    stepCard(i, s)
                }
                if !(chain.steps.isEmpty && startChoice == nil) {
                    connector
                    addMenu
                }
                if let end = endKind {
                    connector
                    node(icon: "checkmark.circle.fill", title: "You get \(end.label)", sub: "Then copy it, save it or share it.", tint: HandyColor.success)
                }
                if endKind != nil { finishCard.padding(.top, HandySpacing.s12) }
                if endKind != nil { ScheduleCard(schedule: $chain.schedule).padding(.top, HandySpacing.s12) }
                if let p = chain.problem(starting: startKind), !chain.steps.isEmpty {
                    Text(p).font(HandyFont.caption).foregroundStyle(HandyColor.danger).padding(.top, HandySpacing.s12)
                }
            }.padding(HandySpacing.gutter)
        }
        .background(HandyColor.bg)
        .navigationTitle("Build a tool").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(chain) }.disabled(!valid) }
        }
        .task(id: chain.steps) { await refreshPreviews() }
    }

    /// "Then": where the result goes. Email and Message open already filled in, so sending is one tap.
    private var finishCard: some View {
        let kind = Binding<ChainFinish.Kind>(
            get: { chain.finish?.kind ?? .share },
            set: { k in var f = chain.finish ?? ChainFinish(); f.kind = k; chain.finish = f })
        let to = Binding<String>(
            get: { chain.finish?.to ?? "" },
            set: { t in var f = chain.finish ?? ChainFinish(); f.to = t; chain.finish = f })
        let onePdf = Binding<Bool>(get: { chain.combine == true }, set: { chain.combine = $0 ? true : nil; if !$0 { chain.onePage = nil } })
        let onePage = Binding<Bool>(get: { chain.onePage == true }, set: { chain.onePage = $0 ? true : nil })
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if startKind == .image, endKind != .text {
                Toggle("Put all pages or photos into one PDF", isOn: onePdf).font(HandyFont.caption).accessibilityIdentifier("finish-one-pdf")
                if chain.combine == true {
                    Toggle("All on a single page (both sides of an ID)", isOn: onePage).font(HandyFont.caption).accessibilityIdentifier("finish-one-page")
                }
            }
            if endKind != .text {
                TextField("File name (optional), e.g. Signed form {date}", text: Binding(get: { chain.fileName ?? "" }, set: { chain.fileName = $0.isEmpty ? nil : $0 }))
                    .font(HandyFont.caption).autocorrectionDisabled()
                    .padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("finish-file-name")
                Text("Write {date} where today's date should go.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Text("Then").font(HandyFont.bodyStrong)
            Picker("Then", selection: kind) {
                Text("Share").tag(ChainFinish.Kind.share)
                Text("Email").tag(ChainFinish.Kind.mail)
                Text("Message").tag(ChainFinish.Kind.message)
                if endKind == .text { Text("Open").tag(ChainFinish.Kind.open) }
            }.pickerStyle(.segmented).accessibilityIdentifier("finish-kind")
            if kind.wrappedValue == .open {
                Text("When the tool finishes, the link it made opens.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            if kind.wrappedValue == .mail || kind.wrappedValue == .message {
                TextField(kind.wrappedValue == .mail ? "Email address (optional)" : "Phone number (optional)", text: to)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(kind.wrappedValue == .mail ? .emailAddress : .phonePad)
                    .padding(HandySpacing.s12).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("finish-to")
                Text(kind.wrappedValue == .mail
                     ? "When the tool finishes, an email opens with the result attached. You tap Send."
                     : "When the tool finishes, a message opens with the result attached. You tap Send.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }.cardStyle(padding: HandySpacing.s12)
    }

    private var connector: some View {
        Image(systemName: "arrow.down").font(.system(size: 14, weight: .bold)).foregroundStyle(HandyColor.textSecondary).frame(height: 28).accessibilityHidden(true)
    }

    private func node(icon: String, title: String, sub: String, tint: Color = HandyColor.accent) -> some View {
        HStack(spacing: HandySpacing.s12) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint).frame(width: 38, height: 38).background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(HandyFont.bodyStrong)
                Text(sub).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
    }

    private var addMenu: some View {
        Menu {
            // Grouped by what you want to get done, and only steps that fit what the tool has at this point.
            ForEach(Block.grouped(options), id: \.goal) { g in
                Section(g.goal) {
                    ForEach(g.blocks) { b in Button { chain.steps.append(ChainStep(block: b, settings: defaults(b))) } label: { Label(b.title, systemImage: b.icon) } }
                }
            }
        } label: {
            Label(chain.steps.isEmpty ? "Add the first step" : "Add a step", systemImage: "plus.circle.fill").font(HandyFont.bodyStrong).frame(maxWidth: .infinity, minHeight: 48)
                .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
        }.accessibilityIdentifier("add-step")
    }

    /// First question of a new tool: what do you have? Everything offered after this fits the answer.
    private var startPicker: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Text("What do you start with?").font(HandyFont.cardTitle)
            HStack(spacing: HandySpacing.s12) {
                startButton(.image, "A photo", "photo")
                startButton(.text, "Text", "text.alignleft")
            }
            Text("A photo tool also takes scans and PDF pages. A text tool also takes what you say, a contact, or the words in a PDF.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func startButton(_ kind: ChainKind, _ title: String, _ icon: String) -> some View {
        Button { startChoice = kind } label: {
            VStack(spacing: HandySpacing.s8) {
                Image(systemName: icon).font(.title2)
                Text(title).font(HandyFont.bodyStrong)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
        }
        .accessibilityIdentifier(kind == .text ? "start-text" : "start-photo")
    }

    private func stepCard(_ i: Int, _ s: ChainStep) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s12) {
                BlockBadge(block: s.block)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(i + 1). \(s.block.title)").font(HandyFont.bodyStrong)
                    Text(s.block.blurb).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Spacer(minLength: 0)
                Menu {
                    if i > 0 { Button { chain.steps.swapAt(i, i - 1) } label: { Label("Move up", systemImage: "arrow.up") } }
                    if i < chain.steps.count - 1 { Button { chain.steps.swapAt(i, i + 1) } label: { Label("Move down", systemImage: "arrow.down") } }
                    Button(role: .destructive) { chain.steps.remove(at: i) } label: { Label("Remove step", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
            }
            settings(i)
            previewView(i < previews.count ? previews[i] : nil)
        }.cardStyle(padding: HandySpacing.s12)
    }

    @ViewBuilder private func previewView(_ p: StepPreview?) -> some View {
        Group {
            switch p {
            case .none: HStack { ProgressView().controlSize(.small); Text("Trying it on a sample…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            case .text(let t): Text(t).font(.system(.caption, design: .monospaced)).lineLimit(6).frame(maxWidth: .infinity, alignment: .leading)
            case .image(let i): Image(uiImage: i).resizable().scaledToFit().frame(maxHeight: 120).clipShape(RoundedRectangle(cornerRadius: 8))
            case .file(let d): Label(d, systemImage: "doc.fill").font(HandyFont.caption)
            case .failed(let w): Label(w, systemImage: "exclamationmark.triangle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.amber)
            }
        }
        .padding(HandySpacing.s8).frame(maxWidth: .infinity, alignment: .leading)
        .background(HandyColor.bg, in: RoundedRectangle(cornerRadius: HandyRadius.small, style: .continuous))
    }

    /// Runs the chain on a sample one step at a time, keeping every step's result for the strips above.
    /// The sample page as it looks just before step `i`, for placing stamps on.
    private func pageBefore(_ i: Int) -> UIImage? {
        if i == 0 { return SampleAssets.receipt() }
        if i - 1 < previews.count, case .image(let img)? = previews[i - 1] { return img }
        return nil
    }

    private func refreshPreviews() async {
        let steps = chain.steps
        previews = Array(repeating: nil, count: steps.count)
        guard let first = steps.first else { return }
        try? await Task.sleep(nanoseconds: 250_000_000)   // let a stepper settle before re-running
        if Task.isCancelled { return }
        var value: ChainPayload
        switch first.block {
        case .readText, .stamp, .photoPdf: value = .image(SampleAssets.receipt())   // paperwork steps preview on a document
        case _ where first.block.takes == .text: value = .text(Self.sampleText)
        default: value = .image(SampleAssets.photo())
        }
        for (i, step) in steps.enumerated() {
            if Task.isCancelled { return }
            if !value.kind.feeds(step.block.takes) { previews[i] = .failed("Needs \(step.block.takes.label) from the step above."); continue }
            switch await ChainRunner.apply(step, to: value, dryRun: true) {   // a preview never saves anything
            case .success(let next):
                value = next
                if Task.isCancelled { return }
                previews[i] = Self.preview(next)
            case .failure(let f):
                previews[i] = .failed(ChainRunView.words(f))
                return
            }
        }
    }

    static let sampleText = "Team sync Friday at 3pm in Room 4. Please send the budget to Ana by Thursday. Call the vendor about the invoice. Review the launch checklist before noon. Priya Rao, Design Lead, priya@studio.example, 555 010 2030."

    private static func preview(_ p: ChainPayload) -> StepPreview {
        switch p {
        case .text(let t): return .text(t)
        case .image(let i): return .image(i)
        case .file(let d, let ext):
            if ChainPayload.isPhoto(ext), let i = UIImage(data: d) { return .image(i) }
            if ["csv", "vcf", "ics"].contains(ext), let t = String(data: d, encoding: .utf8) { return .text(t) }
            return .file("\(ext.uppercased()) file · \(SizeTarget.format(d.count))")
        }
    }

    private func defaults(_ b: Block) -> [String: String] {
        switch b { case .shrinkImage: return ["mb": "2"]; case .summarize: return ["sentences": "3"]; case .convertImage: return ["format": "JPG"]; case .passportPhoto: return ["country": "us"]
        case .watermark: return ["text": "For verification only"]; case .resizePhoto: return ["size": "413x531"]
        case .stamp: return ["marks": StampPlan.standard.text]; case .addToList: return ["list": RunningList.defaultName]
        case .chatLink: return ["cc": ChainText.callingCode(region: Locale.current.region?.identifier)]; default: return [:] }
    }

    @ViewBuilder private func settings(_ i: Int) -> some View {
        switch chain.steps[i].block {
        case .shrinkImage:
            // A short list of limits, down to the 20-50 KB that government and bank upload forms ask for.
            let mb = Double(chain.steps[i].settings["mb"] ?? "2") ?? 2
            Picker("Size limit", selection: Binding(get: { mb }, set: { chain.steps[i].settings["mb"] = String($0) })) {
                ForEach((ChainImage.limits.contains(mb) ? ChainImage.limits : (ChainImage.limits + [mb]).sorted()), id: \.self) { v in Text("Under " + ChainImage.limitLabel(v)).tag(v) }
            }.pickerStyle(.menu).font(HandyFont.caption)
        case .chatLink:
            HStack {
                Text("Country code  +").font(HandyFont.caption)
                TextField("1", text: Binding(get: { chain.steps[i].settings["cc"] ?? "1" }, set: { chain.steps[i].settings["cc"] = $0.filter(\.isNumber) }))
                    .keyboardType(.numberPad).font(HandyFont.caption).frame(width: 60)
                    .padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
            }
            Text("Used when the number is written without one.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .addToList:
            TextField("Sheet name", text: Binding(get: { chain.steps[i].settings["list"] ?? RunningList.defaultName }, set: { chain.steps[i].settings["list"] = $0 }))
                .font(HandyFont.caption).autocorrectionDisabled().padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
            Text("Write {month} to start a fresh sheet each month. The sample shown here is not saved.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .stamp:
            StampEditor(marks: Binding(get: { chain.steps[i].settings["marks"] ?? StampPlan.standard.text }, set: { chain.steps[i].settings["marks"] = $0 }), page: pageBefore(i))
        case .watermark:
            TextField("Words to write across it", text: Binding(get: { chain.steps[i].settings["text"] ?? "" }, set: { chain.steps[i].settings["text"] = $0 }))
                .font(HandyFont.caption).padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
            Text("Today's date is added each time it runs.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .resizePhoto:
            Picker("Size", selection: Binding(get: { chain.steps[i].settings["size"] ?? "413x531" }, set: { chain.steps[i].settings["size"] = $0 })) {
                ForEach(ChainImage.sizes, id: \.value) { s in Text(s.label).tag(s.value) }
            }.pickerStyle(.menu).font(HandyFont.caption)
        case .summarize:
            let n = Int(chain.steps[i].settings["sentences"] ?? "3") ?? 3
            Stepper("\(n) sentences", value: Binding(get: { n }, set: { chain.steps[i].settings["sentences"] = String($0) }), in: 1...8).font(HandyFont.caption)
        case .convertImage:
            Picker("Format", selection: Binding(get: { chain.steps[i].settings["format"] ?? "JPG" }, set: { chain.steps[i].settings["format"] = $0 })) {
                ForEach(ImageStudio.Format.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
            }.pickerStyle(.segmented)
        case .passportPhoto:
            Picker("Country", selection: Binding(get: { chain.steps[i].settings["country"] ?? "us" }, set: { chain.steps[i].settings["country"] = $0 })) {
                ForEach(ImageStudio.passportSpecs) { Text($0.name).tag($0.id) }
            }.font(HandyFont.caption)
        default: EmptyView()
        }
    }
}

/// One photo's outcome in a batch run. Files and pictures are written to a temporary folder straight away,
/// so twenty full-size results never sit in memory together.
struct BatchItem: Identifiable {
    let id = UUID()
    let n: Int
    var url: URL?
    var text: String?
    var summary = ""
    var note: String?

    static func make(n: Int, payload: ChainPayload, in dir: URL, named: String? = nil, tool: String = "") -> BatchItem {
        var b = BatchItem(n: n)
        func write(_ d: Data, _ ext: String) {
            let u = dir.appendingPathComponent(ChainName.file(pattern: named, tool: tool, index: n, ext: ext))
            if (try? d.write(to: u)) != nil { b.url = u; b.summary = "\(SizeTarget.format(d.count)) · \(ext.uppercased())" } else { b.note = "Couldn't save this result." }
        }
        switch payload {
        case .text(let t): b.text = t; b.summary = "\(t.count) characters"
        case .image(let i): if let d = i.jpegData(compressionQuality: 0.92) { write(d, "jpg") } else { b.note = "Couldn't save this result." }
        case .file(let d, let ext): write(d, ext)
        }
        return b
    }
}

/// Give it a photo or some text, see the result, copy or share it.
private struct ChainRunView: View {
    let chain: Chain
    @State private var picks: [PhotosPickerItem] = []
    @State private var batch: [BatchItem] = []
    @State private var progress = ""
    @State private var outbox: Outbox?
    @State private var sending = false
    @State private var scanning = false
    @State private var signing = false
    @State private var hasSignature = DocEngine.savedSignature != nil
    @State private var myName = StampBook.name
    /// Decided once when the screen opens, so the field doesn't vanish while the name is being typed.
    @State private var askName = StampBook.name.trimmingCharacters(in: .whitespaces).isEmpty
    @State private var text = ""
    @StateObject private var speech = SpeechStream()
    @State private var pickingContact = false
    @State private var pickingPDF = false
    @State private var busy = false
    @State private var result: ChainPayload?
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss

    private var start: ChainKind { chain.steps.first?.block.takes ?? .image }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                Text(chain.name).font(HandyFont.title)
                stampSetup
                if start != .text {
                    PhotosPicker(selection: $picks, maxSelectionCount: 20, matching: .images) { Label("Choose photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }.primaryButton()
                    if VNDocumentCameraViewController.isSupported {
                        Button { scanning = true } label: { Label("Scan a document", systemImage: "doc.viewfinder").frame(maxWidth: .infinity) }
                            .secondaryButton().accessibilityIdentifier("run-scan")
                    }
                    Button { pickingPDF = true } label: { Label("Choose a PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity) }
                        .secondaryButton().accessibilityIdentifier("run-pdf")
                    Text(chain.combine == true ? "Pick or scan as many pages as you need. They all go into one PDF." : "Pick one, or up to 20 at once. Each one gets the same steps.")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                } else {
                    // Four ways to get the words in without typing them.
                    HStack(spacing: HandySpacing.s8) {
                        fill("Paste", "doc.on.clipboard", id: "in-paste") {
                            if let s = UIPasteboard.general.string, !s.isEmpty { text = InputText.joined(text, s) } else { message = "There is nothing copied to paste." }
                        }
                        fill(speech.running ? "Stop" : "Speak", speech.running ? "stop.circle.fill" : "mic", id: "in-speak") { toggleSpeech() }
                        fill("Contact", "person.crop.circle", id: "in-contact") { pickingContact = true }
                        fill("PDF", "doc.richtext", id: "in-pdf") { pickingPDF = true }
                    }
                    if speech.running { Text(speech.live.isEmpty ? "Listening… tap Stop when you're done." : speech.live).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
                    if let e = speech.errorText { Text(e).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
                    TextEditor(text: $text).frame(minHeight: 140).cardStyle(padding: HandySpacing.s8)
                    Button("Run") { go(.text(text)) }.primaryButton().disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if busy { ProgressView(progress.isEmpty ? "Working…" : progress) }
                if let message { Text(message).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                if let result { output(result) }
                if !batch.isEmpty { batchView }
                sendOn
            }.padding(HandySpacing.gutter)
        }
        .background(HandyColor.bg)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        .sheet(isPresented: $sending) {
            if let f = chain.finish, let box = outbox { SendSheet(finish: f, subject: chain.name, box: box).ignoresSafeArea() }
        }
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            picks = []
            if items.count == 1, let item = items.first {
                Task {
                    let img = (try? await item.loadTransferable(type: Data.self)).flatMap(UIImage.init)
                    if let img { go(.image(img)) } else { message = "That photo couldn't be opened. Try another." }
                }
            } else { runBatch(count: items.count) { i in (try? await items[i].loadTransferable(type: Data.self)).flatMap(UIImage.init) } }
        }
        .sheet(isPresented: $signing) { SignaturePadSheet { _ in hasSignature = true } }
        .sheet(isPresented: $pickingContact) {
            ContactPickerSheet { picked in
                pickingContact = false
                if let picked { text = InputText.joined(text, picked) }
            }.ignoresSafeArea()
        }
        .fileImporter(isPresented: $pickingPDF, allowedContentTypes: [.pdf]) { r in
            guard case .success(let url) = r else { return }
            if start == .text {
                // The words in the PDF become the text the tool works on.
                if let words = PDFInput.text(from: url), !words.isEmpty { text = InputText.joined(text, words); message = nil }
                else { message = "That PDF has no words Tenzy can read (it may be a scan). Use a photo tool with Read text, and choose the PDF there." }
            } else {
                // Each page becomes a picture and gets the tool's steps, like scanned pages.
                let pages = PDFInput.pages(from: url)
                if pages.isEmpty { message = "That PDF couldn't be opened. Try another." }
                else if pages.count == 1 { go(.image(pages[0])) }
                else { runBatch(count: pages.count) { i in pages[i] } }
            }
        }
        .onDisappear { if speech.running { speech.stop() } }
        .fullScreenCover(isPresented: $scanning) {
            // Apple's document camera: finds the page edges, straightens it, and takes several pages in one go.
            DocCameraSheet { pages in
                scanning = false
                if pages.count == 1 { go(.image(pages[0])) } else if pages.count > 1 { runBatch(count: pages.count) { i in pages[i] } }
            }.ignoresSafeArea()
        }
    }

    private func fill(_ title: String, _ icon: String, id: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(spacing: 4) { Image(systemName: icon).font(.system(size: 18, weight: .semibold)); Text(title).font(HandyFont.micro) }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }.buttonStyle(.plain).foregroundStyle(HandyColor.accent).accessibilityIdentifier(id)
    }

    /// Speak: starts listening, and on Stop adds what was said to the text box.
    private func toggleSpeech() {
        if speech.running {
            speech.stop()
            text = InputText.joined(text, speech.committed.joined(separator: " "))
            speech.clear()
        } else {
            message = nil; speech.clear(); speech.start()
        }
    }

    /// One result per photo. A photo that can't be processed never stops the others; it just gets its own note.
    private func runBatch(count: Int, load: @escaping (Int) async -> UIImage?) {
        busy = true; result = nil; message = nil; batch = []; outbox = nil
        let combine = chain.combine == true
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-batch-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        Task {
            var out: [BatchItem] = []
            var kept: [ChainPayload] = []      // only held when everything is going into one PDF
            for i in 0..<count {
                await MainActor.run { progress = "Working… \(i + 1) of \(count)" }
                guard let img = await load(i) else {
                    out.append(BatchItem(n: i + 1, note: "Couldn't open this photo.")); continue
                }
                switch await ChainRunner.run(chain, input: .image(img)) {
                case .success(let p):
                    if combine { kept.append(p) }
                    out.append(BatchItem.make(n: i + 1, payload: p, in: dir, named: chain.fileName, tool: chain.name))
                case .failure(let f): out.append(BatchItem(n: i + 1, note: ChainRunView.words(f)))
                }
            }
            // One PDF for everything, when the tool asks for it and the results can be joined.
            if combine, let one = ChainCombine.onePDF(kept, onePage: chain.onePage == true) {
                let skipped = out.filter { $0.note != nil }.count
                await MainActor.run {
                    busy = false; progress = ""; result = one
                    if skipped > 0 { message = "\(skipped) of \(count) couldn't be used and were left out." }
                    finished(Outbox.make(one, named: chain.fileName, tool: chain.name))
                }
                return
            }
            await MainActor.run {
                batch = out; busy = false; progress = ""
                let ok = out.filter { $0.note == nil }
                finished(ok.isEmpty ? nil : Outbox(text: ok.compactMap(\.text).isEmpty ? nil : ok.compactMap(\.text).joined(separator: "\n\n"), files: ok.compactMap(\.url)))
            }
        }
    }

    /// A tool that signs needs your signature (and one that stamps your name needs the name). Ask for them right
    /// here, once, instead of failing after the scan.
    @ViewBuilder private var stampSetup: some View {
        let plans = chain.steps.filter { $0.block == .stamp }.map { StampPlan($0.settings["marks"] ?? StampPlan.standard.text) }
        if plans.contains(where: { $0.has(.signature) }), !hasSignature {
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text("This tool signs for you. Draw your signature once; it stays on this phone.").font(HandyFont.caption)
                Button { signing = true } label: { Label("Draw my signature", systemImage: "signature").frame(maxWidth: .infinity) }
                    .secondaryButton().accessibilityIdentifier("run-draw-signature")
            }.cardStyle(padding: HandySpacing.s12)
        }
        if plans.contains(where: { $0.has(.name) }), askName {
            TextField("Your name as it should appear", text: $myName)
                .padding(HandySpacing.s12).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 10))
                .onChange(of: myName) { _, v in StampBook.name = v }
        }
    }

    /// The tool's own ending: "Email it to..." or "Message it to...". If this phone can't do that, say so and leave
    /// Save or share above as the way out, never a dead button.
    @ViewBuilder private var sendOn: some View {
        if let f = chain.finish, f.kind == .open, outbox != nil {
            Button { openLink() } label: { Label(f.label, systemImage: "arrow.up.forward.app").frame(maxWidth: .infinity) }
                .primaryButton().accessibilityIdentifier("open-link")
        } else if let f = chain.finish, f.kind != .share, outbox != nil {
            if SendSheet.canSend(f.kind) {
                Button { sending = true } label: { Label(f.label, systemImage: f.kind == .mail ? "envelope" : "message").frame(maxWidth: .infinity) }
                    .primaryButton().accessibilityIdentifier("send-on")
            } else {
                Text(f.kind == .mail ? "This phone has no Mail account set up, so use Save or share." : "This device can't send messages, so use Save or share.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }
    }

    /// "Open it": follows the link the tool made (a WhatsApp chat, a cleaned link). If the result holds no link, say
    /// so; the result is still on screen to copy.
    private func openLink(_ box: Outbox? = nil) {
        let text = (box ?? outbox)?.text ?? ""
        let found = TextTidy.details(text).links.first ?? text.trimmingCharacters(in: .whitespacesAndNewlines)
        let full = found.lowercased().hasPrefix("http") ? found : "https://" + found
        guard !found.isEmpty, !found.contains(" "), let url = URL(string: full) else { message = "There was no link to open. The result is shown below to copy."; return }
        UIApplication.shared.open(url)
    }

    /// Called when a run finishes: get the result ready to send and, if the tool ends in an email or a message, open it.
    private func finished(_ box: Outbox?) {
        outbox = box
        if let f = chain.finish, f.kind == .open, box != nil { openLink(box) }
        else if let f = chain.finish, f.kind == .mail || f.kind == .message, box != nil, SendSheet.canSend(f.kind) { sending = true }
    }

    @ViewBuilder private var batchView: some View {
        let ok = batch.filter { $0.note == nil }
        let urls = ok.compactMap(\.url)
        let texts = ok.compactMap { b in b.text.map { "Photo \(b.n)\n\($0)" } }
        Text("\(ok.count) of \(batch.count) done").font(HandyFont.cardTitle)
        ForEach(batch) { b in
            HStack {
                Image(systemName: b.note == nil ? "checkmark.circle.fill" : "exclamationmark.circle").foregroundStyle(b.note == nil ? Color.green : HandyColor.textSecondary)
                Text("Photo \(b.n)").font(HandyFont.bodyStrong)
                Spacer()
                Text(b.note ?? b.summary).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.trailing)
            }.cardStyle(padding: HandySpacing.s12)
        }
        if !urls.isEmpty {
            ShareLink(items: urls) { Label("Save or share all (\(urls.count))", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        }
        if !texts.isEmpty {
            Button { UIPasteboard.general.string = texts.joined(separator: "\n\n") } label: { Label("Copy all text", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.secondaryButton()
        }
    }

    @ViewBuilder private func output(_ r: ChainPayload) -> some View {
        switch r {
        case .text(let t):
            Text(t).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
            Button { UIPasteboard.general.string = t } label: { Label("Copy", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.secondaryButton()
        case .image(let i):
            Image(uiImage: i).resizable().scaledToFit().frame(maxHeight: 320)
            ShareLink(item: Image(uiImage: i), preview: SharePreview("Result")) { Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        case .file(let d, let ext):
            if let u = tempURL(d, ext) {
                Text("\(SizeTarget.format(d.count)) · \(ext.uppercased())").font(HandyFont.caption)
                ShareLink(item: u) { Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            }
        }
    }

    private func tempURL(_ d: Data, _ ext: String) -> URL? {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(ChainName.file(pattern: chain.fileName, tool: chain.name, ext: ext))
        return (try? d.write(to: u)) != nil ? u : nil
    }

    private func go(_ input: ChainPayload) {
        busy = true; result = nil; message = nil; batch = []; progress = ""; outbox = nil
        Task {
            let r = await ChainRunner.run(chain, input: input)
            await MainActor.run {
                busy = false
                switch r {
                case .success(let p): result = p; finished(Outbox.make(p, named: chain.fileName, tool: chain.name))
                case .failure(let f): message = ChainRunView.words(f)
                }
            }
        }
    }

    static func words(_ f: ChainRunner.Failure) -> String {
        switch f {
        case .invalid(let s): return s
        case .wrongInput(let b): return "\(b.title) can't use that input."
        case .nothingFound(.businessCard): return "Make a contact needs a phone number or an email, and didn't find one. Try a business card or a signature."
        case .nothingFound(let b): return b.takes == .text ? "\(b.title) didn't find anything in that text." : "\(b.title) didn't find anything in it. Try a clearer or closer picture."
        case .failed(let b): return "\(b.title) couldn't finish. Try again."
        }
    }
}
