import SwiftUI
import PhotosUI

/// Tenzy Builder (M2): run a starter or saved tool, or build your own by stacking blocks.
/// Everything here is data over built-in blocks (see ChainRunner), nothing is downloaded or generated as code.
enum ChainStore {
    private static let key = "builder.chains"
    static func load() -> [Chain] {
        guard let d = UserDefaults.standard.data(forKey: key), let c = try? JSONDecoder().decode([Chain].self, from: d) else { return [] }
        return c
    }
    static func save(_ chains: [Chain]) {
        if let d = try? JSONEncoder().encode(chains) { UserDefaults.standard.set(d, forKey: key) }
    }
}

struct BuilderView: View {
    @State private var mine: [Chain] = ChainStore.load()
    @State private var editing: Chain?
    @State private var running: Chain?
    @State private var note: String?
    @State private var ask = ""
    @State private var planning = false

    var body: some View {
        ToolPage(title: "Build your own", subtitle: "Snap small steps together into a tool that does exactly what you need. Runs on your phone.") {
            hero
            if !mine.isEmpty {
                Text("My tools").font(HandyFont.cardTitle)
                ForEach(mine) { c in row(c, mine: true) }
            }
            HStack {
                Text("Start from a template").font(HandyFont.cardTitle)
                Spacer()
                Button { editing = Chain(id: UUID().uuidString, name: "My tool", steps: []) } label: { Label("Blank", systemImage: "plus") }.font(HandyFont.caption)
                Button {
                    if let c = Chain.imported(from: UIPasteboard.general.string ?? "") { mine.append(c); ChainStore.save(mine); note = "Added \(c.name)." }
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
                    ChainStore.save(mine); editing = nil
                }
            }
        }
        .sheet(item: $running) { c in NavigationStack { ChainRunView(chain: c) } }
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
            }
            Spacer()
            Menu {
                Button("Edit") { editing = c }
                Button("Copy to share") { UIPasteboard.general.string = c.shareText; note = "Copied. Paste it into Tenzy on another phone." }
                Button("Delete", role: .destructive) { mine.removeAll { $0.id == c.id }; ChainStore.save(mine) }
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
    private var options: [Block] {
        guard let end = endKind else { return Block.allCases }
        return Block.allCases.filter { end.feeds($0.takes) }
    }
    private var valid: Bool { chain.problem(starting: startKind) == nil && !chain.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TextField("Name your tool", text: $chain.name).font(HandyFont.title).padding(.bottom, HandySpacing.s16)
                node(icon: startKind == .text ? "text.alignleft" : "photo", title: chain.steps.isEmpty ? "You give it…" : "You give it \(startKind.label)", sub: chain.steps.isEmpty ? "Add a first step. It decides whether you start with a photo or text." : "Preview uses a sample so you can see each step work.")
                ForEach(Array(chain.steps.enumerated()), id: \.offset) { i, s in
                    connector
                    stepCard(i, s)
                }
                connector
                addMenu
                if let end = endKind {
                    connector
                    node(icon: "checkmark.circle.fill", title: "You get \(end.label)", sub: "Then copy it, save it or share it.", tint: HandyColor.success)
                }
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
            ForEach(options) { b in Button { chain.steps.append(ChainStep(block: b, settings: defaults(b))) } label: { Label(b.title, systemImage: b.icon) } }
        } label: {
            Label(chain.steps.isEmpty ? "Add the first step" : "Add a step", systemImage: "plus.circle.fill").font(HandyFont.bodyStrong).frame(maxWidth: .infinity, minHeight: 48)
                .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
        }.accessibilityIdentifier("add-step")
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
    private func refreshPreviews() async {
        let steps = chain.steps
        previews = Array(repeating: nil, count: steps.count)
        guard let first = steps.first else { return }
        try? await Task.sleep(nanoseconds: 250_000_000)   // let a stepper settle before re-running
        if Task.isCancelled { return }
        var value: ChainPayload
        switch first.block {
        case .readText: value = .image(SampleAssets.receipt())
        case _ where first.block.takes == .text: value = .text(Self.sampleText)
        default: value = .image(SampleAssets.photo())
        }
        for (i, step) in steps.enumerated() {
            if Task.isCancelled { return }
            if !value.kind.feeds(step.block.takes) { previews[i] = .failed("Needs \(step.block.takes.label) from the step above."); continue }
            switch await ChainRunner.apply(step, to: value) {
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
            return .file("\(ext.uppercased()) file · \(SizeTarget.format(d.count))")
        }
    }

    private func defaults(_ b: Block) -> [String: String] {
        switch b { case .shrinkImage: return ["mb": "2"]; case .summarize: return ["sentences": "3"]; case .convertImage: return ["format": "JPG"]; case .passportPhoto: return ["country": "us"]; default: return [:] }
    }

    @ViewBuilder private func settings(_ i: Int) -> some View {
        switch chain.steps[i].block {
        case .shrinkImage:
            let mb = Double(chain.steps[i].settings["mb"] ?? "2") ?? 2
            Stepper("Under \(mb.formatted()) MB", value: Binding(get: { mb }, set: { chain.steps[i].settings["mb"] = String($0) }), in: 0.25...20, step: 0.25).font(HandyFont.caption)
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

/// Give it a photo or some text, see the result, copy or share it.
private struct ChainRunView: View {
    let chain: Chain
    @State private var pick: PhotosPickerItem?
    @State private var text = ""
    @State private var busy = false
    @State private var result: ChainPayload?
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss

    private var start: ChainKind { chain.steps.first?.block.takes ?? .image }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                Text(chain.name).font(HandyFont.title)
                if start != .text {
                    PhotosPicker(selection: $pick, matching: .images) { Label("Choose a photo", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }.primaryButton()
                } else {
                    TextEditor(text: $text).frame(minHeight: 140).cardStyle(padding: HandySpacing.s8)
                    Button("Run") { go(.text(text)) }.primaryButton().disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if busy { ProgressView("Working…") }
                if let message { Text(message).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                if let result { output(result) }
            }.padding(HandySpacing.gutter)
        }
        .background(HandyColor.bg)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                let img = (try? await item.loadTransferable(type: Data.self)).flatMap(UIImage.init)
                pick = nil
                if let img { go(.image(img)) } else { message = "That photo couldn't be opened. Try another." }
            }
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
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-result.\(ext)")
        return (try? d.write(to: u)) != nil ? u : nil
    }

    private func go(_ input: ChainPayload) {
        busy = true; result = nil; message = nil
        Task {
            let r = await ChainRunner.run(chain, input: input)
            await MainActor.run {
                busy = false
                switch r {
                case .success(let p): result = p
                case .failure(let f): message = ChainRunView.words(f)
                }
            }
        }
    }

    static func words(_ f: ChainRunner.Failure) -> String {
        switch f {
        case .invalid(let s): return s
        case .wrongInput(let b): return "\(b.title) can't use that input."
        case .nothingFound(let b): return "\(b.title) didn't find anything in it. Try a clearer or closer picture."
        case .failed(let b): return "\(b.title) couldn't finish. Try again."
        }
    }
}
