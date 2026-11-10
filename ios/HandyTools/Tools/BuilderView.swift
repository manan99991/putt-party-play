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

    var body: some View {
        ToolPage(title: "Build your own", subtitle: "Snap small steps together into a tool that does exactly what you need. Runs on your phone.") {
            Button { editing = Chain(id: UUID().uuidString, name: "My tool", steps: []) } label: {
                Label("Build a new tool", systemImage: "plus").frame(maxWidth: .infinity)
            }.primaryButton()

            Button {
                if let c = Chain.imported(from: UIPasteboard.general.string ?? "") { mine.append(c); ChainStore.save(mine); note = "Added \(c.name)." }
                else { note = "Copy a tool from another Tenzy first, then tap this." }
            } label: { Label("Paste a shared tool", systemImage: "doc.on.clipboard").frame(maxWidth: .infinity) }.secondaryButton()
            if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }

            if !mine.isEmpty {
                Text("My tools").font(HandyFont.bodyStrong)
                ForEach(mine) { c in row(c, mine: true) }
            }
            Text("Start from a template").font(HandyFont.bodyStrong)
            ForEach(ChainTemplates.all) { c in row(c, mine: false) }
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

    private func row(_ c: Chain, mine isMine: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).font(HandyFont.bodyStrong)
                Text(c.steps.map(\.block.title).joined(separator: "  ›  ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Spacer()
            Menu {
                Button(isMine ? "Edit" : "Edit a copy") {
                    var k = c
                    if !isMine { k.id = UUID().uuidString; k.name += " (mine)" }
                    editing = k
                }
                Button("Copy to share") { UIPasteboard.general.string = c.shareText; note = "Copied. Paste it into Tenzy on another phone." }
                if isMine { Button("Delete", role: .destructive) { mine.removeAll { $0.id == c.id }; ChainStore.save(mine) } }
            } label: { Image(systemName: "ellipsis.circle").font(.system(size: 20)) }
            Button("Run") { running = c }.secondaryButton()
        }.cardStyle(padding: HandySpacing.s12)
    }
}

/// Stack blocks: only blocks that fit the step above are offered, so a chain can't be built wrong.
private struct ChainEditor: View {
    @State var chain: Chain
    var onSave: (Chain) -> Void
    @Environment(\.dismiss) private var dismiss

    private var startKind: ChainKind { chain.steps.first?.block.takes ?? .image }
    private var endKind: ChainKind? { chain.steps.last?.block.gives }
    private var options: [Block] {
        guard let end = endKind else { return Block.allCases }
        return Block.allCases.filter { $0.takes == end }
    }

    var body: some View {
        List {
            Section("Name") { TextField("Name", text: $chain.name) }
            Section("Steps, top to bottom") {
                if chain.steps.isEmpty { Text("Add the first step. It decides what you give the tool: a photo or some text.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                ForEach(Array(chain.steps.enumerated()), id: \.offset) { i, s in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(i + 1). \(s.block.title)").font(HandyFont.bodyStrong)
                        settings(i)
                    }
                }
                .onDelete { chain.steps.remove(atOffsets: $0) }
                .onMove { chain.steps.move(fromOffsets: $0, toOffset: $1) }
                Menu {
                    ForEach(options) { b in Button(b.title) { chain.steps.append(ChainStep(block: b, settings: defaults(b))) } }
                } label: { Label("Add a step", systemImage: "plus.circle.fill") }
            }
            if let p = chain.problem(starting: startKind), !chain.steps.isEmpty {
                Section { Text(p).font(HandyFont.caption).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Build a tool").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { onSave(chain) }.disabled(chain.problem(starting: startKind) != nil || chain.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ToolbarItem(placement: .bottomBar) { EditButton() }
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
                if start == .image {
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
