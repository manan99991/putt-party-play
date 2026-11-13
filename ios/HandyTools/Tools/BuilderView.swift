import SwiftUI
import PhotosUI
import VisionKit
import UniformTypeIdentifiers
import WidgetKit

/// Something handed over before a tool was chosen: "here is what I have, what can you do with it?"
struct Given: Identifiable {
    let id = UUID()
    let payload: ChainPayload
    /// A few words for the top of the list: "A photo", "A PDF · 2 pages"...
    let label: String

    /// What a file from the Files app is, by its name. nil for a kind of file no tool takes.
    static func from(file url: URL) -> Given? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        let type = UTType(filenameExtension: ext)
        if ext == "pdf" || type?.conforms(to: .pdf) == true {
            return (try? Data(contentsOf: url)).map { Given(payload: .file($0, ext: "pdf"), label: "A PDF") }
        }
        if ChainPayload.isAudio(ext) || type?.conforms(to: .audio) == true {
            return (try? Data(contentsOf: url)).map { Given(payload: .file($0, ext: ChainPayload.isAudio(ext) ? ext : "m4a"), label: "A recording") }
        }
        if type?.conforms(to: .movie) == true {
            // A video stays a file: copy it somewhere it can still be read after the picker closes.
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-given-\(UUID().uuidString).\(ext.isEmpty ? "mov" : ext)")
            return (try? FileManager.default.copyItem(at: url, to: copy)) != nil ? Given(payload: .video(copy), label: "A video") : nil
        }
        if type?.conforms(to: .image) == true {
            return (try? Data(contentsOf: url)).flatMap(UIImage.init).map { Given(payload: .image($0), label: "A photo") }
        }
        if type?.conforms(to: .text) == true, let words = try? String(contentsOf: url, encoding: .utf8), !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Given(payload: .text(words), label: "Some text")
        }
        return nil
    }

    static func from(text: String) -> Given? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return Given(payload: .text(t), label: TextTidy.details(t).links.isEmpty ? "Some text" : "A link")
    }
}

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
    @State private var history = RunHistory.all()
    @State private var showHistory = false
    /// The tool being handed on as a link and a QR code.
    @State private var linking: Chain?
    /// The how-it-works card, until Got it. Never shown to automated runs, which expect the plain screen.
    @AppStorage("builder.introSeen") private var introSeen = false
    /// "What do you have?": narrows the starters to ones that begin with it. nil shows all.
    @State private var have: ChainKind?
    /// Shown at the top of the editor after Describe it, when the request was only half said.
    @State private var editHint: String?
    @State private var renaming: Chain?
    @State private var newName = ""
    /// "Start with what you have": the thing picked, waiting for a tool to be chosen for it.
    @State private var given: Given?
    @State private var anyPick: PhotosPickerItem?
    @State private var pickingAny = false
    @State private var gettingReady = false

    var body: some View {
        ToolPage(title: "Build your own", subtitle: "Snap small steps together into a tool that does exactly what you need. Runs on your phone.") {
            if !introSeen, !Launch.uitest, !Launch.screenshots {
                BuilderIntroCard(onShow: {
                    if var demo = ChainTemplates.all.first(where: { $0.id == BuilderIntro.demoID }) {
                        demo.id = UUID().uuidString; demo.name += " (mine)"; editing = demo
                    }
                }, onDone: { withAnimation { introSeen = true } })
            }
            hero
            anything
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
            if !history.isEmpty {
                Button { showHistory = true } label: {
                    HStack(spacing: HandySpacing.s12) {
                        Image(systemName: "clock.arrow.circlepath").font(.system(size: 18, weight: .semibold)).foregroundStyle(HandyColor.accent).frame(width: 38, height: 38).background(HandyColor.accent.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recent results").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                            Text(history.count == 1 ? "The last thing a tool made" : "The last \(history.count) things your tools made").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(HandyColor.textSecondary)
                    }.cardStyle(padding: HandySpacing.s12)
                }.buttonStyle(.plain).accessibilityIdentifier("open-history")
            }
            HStack {
                Text("Start from a template").font(HandyFont.cardTitle)
                Spacer()
                Button { editHint = nil; editing = Chain(id: UUID().uuidString, name: "", steps: []) } label: { Label("Blank", systemImage: "plus") }.font(HandyFont.caption)
                Button {
                    if let c = ToolLink.chain(from: UIPasteboard.general.string ?? "") {
                        if BuilderLimits.canSave(savedCount: mine.count, isPremium: StoreManager.shared.isPremium) { mine.append(c); persist(); note = "Added \(c.name)." }
                        else { proForSave() }
                    } else { note = "Copy a tool from another Tenzy first, then tap Paste." }
                } label: { Label("Paste", systemImage: "doc.on.clipboard") }.font(HandyFont.caption)
            }
            if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            Picker("What do you have?", selection: $have) {
                Text("All").tag(ChainKind?.none)
                Text("Photo").tag(ChainKind?.some(.image))
                Text("Text").tag(ChainKind?.some(.text))
                Text("Video").tag(ChainKind?.some(.video))
                Text("Sound").tag(ChainKind?.some(.audio))
                Text("PDF").tag(ChainKind?.some(.pdf))
            }.pickerStyle(.segmented).accessibilityIdentifier("starter-filter")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: HandySpacing.s12), GridItem(.flexible(), spacing: HandySpacing.s12)], spacing: HandySpacing.s12) {
                // Only starters this phone can run. One that needs something it lacks is simply not offered.
                ForEach(BuilderIntro.starters(for: have).filter { $0.unavailable == nil }) { c in templateCard(c) }
            }
            if introSeen {
                Button("How does this work?") { withAnimation { introSeen = false } }.font(HandyFont.caption).frame(minHeight: 44)
            }
        }
        .sheet(item: $editing) { c in
            NavigationStack {
                ChainEditor(chain: c, hint: editHint) { saved in
                    if let i = mine.firstIndex(where: { $0.id == saved.id }) { mine[i] = saved; persist(); editing = nil; editHint = nil }
                    else if BuilderLimits.canSave(savedCount: mine.count, isPremium: StoreManager.shared.isPremium) { mine.append(saved); persist(); editing = nil; editHint = nil }
                    else { proForSave() }   // keep the editor open so the built tool isn't lost; Save works again after upgrading
                }
            }
        }
        .sheet(item: $running) { c in NavigationStack { ChainRunView(chain: c) } }
        .sheet(item: $given) { g in NavigationStack { ToolPickView(given: g, mine: mine) } }
        .alert("Name this tool", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if let r = renaming, !name.isEmpty, let i = mine.firstIndex(where: { $0.id == r.id }) { mine[i].name = name; persist() }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .fileImporter(isPresented: $pickingAny, allowedContentTypes: [.pdf, .audio, .movie, .image, .plainText]) { r in
            guard case .success(let url) = r else { return }
            if let g = Given.from(file: url) { note = nil; given = g } else { note = "Tenzy couldn't open that file, or has no tool for that kind of file yet." }
        }
        .onChange(of: anyPick) { _, item in
            guard let item else { return }
            anyPick = nil; gettingReady = true; note = nil
            Task {
                var g: Given?
                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    if let movie = try? await item.loadTransferable(type: MovieImport.self) { g = Given(payload: .video(movie.url), label: "A video") }
                } else if let img = (try? await item.loadTransferable(type: Data.self)).flatMap(UIImage.init) {
                    g = Given(payload: .image(img), label: "A photo")
                }
                await MainActor.run {
                    gettingReady = false
                    if let g { given = g } else { note = "That couldn't be opened. Try another." }
                }
            }
        }
        .sheet(isPresented: $showSheets, onDismiss: { sheets = RunningList.all() }) { NavigationStack { SheetsView() } }
        .sheet(isPresented: $showHistory, onDismiss: { history = RunHistory.all() }) { NavigationStack { HistoryView() } }
        .sheet(item: $linking) { c in NavigationStack { ToolLinkSheet(chain: c) } }
        .onChange(of: running?.id) { _, now in if now == nil { sheets = RunningList.all(); history = RunHistory.all() } }   // a run may have added to a sheet, and to the recent results
        .onChange(of: given?.id) { _, now in if now == nil { history = RunHistory.all() } }
        .onAppear { openReminded() }
        .onReceive(NotificationCenter.default.publisher(for: .openTool)) { _ in
            // A tool opened from a link was saved before this arrived, so pick it up.
            let saved = ChainStore.load()
            if saved.count > mine.count, let added = saved.last { mine = saved; note = "Added \(added.name)." }
            openReminded()
        }
    }

    /// Saves the tools and keeps the phone's reminders and the home-screen widget in step with them.
    private func persist() { ChainStore.save(mine); ToolSchedules.sync(mine); WidgetCenter.shared.reloadTimelines(ofKind: "ToolsWidget") }

    /// Free keeps a couple of your own tools; Pro lifts the cap. Shown when a free user tries to save past it.
    private func proForSave() {
        note = "Free keeps \(BuilderLimits.freeSaved) of your own tools. Go Pro to save as many as you like."
        NotificationCenter.default.post(name: .showPaywall, object: nil)
    }

    /// "Start with what you have": pick the thing first, and Tenzy lists the tools that fit it.
    private var anything: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label("Start with what you have", systemImage: "tray.and.arrow.down").font(HandyFont.cardTitle)
            Text(gettingReady ? "Getting it ready…" : "Pick it, and Tenzy shows the tools that fit. No need to know which one you want.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HStack(spacing: HandySpacing.s8) {
                PhotosPicker(selection: $anyPick, matching: .any(of: [.images, .videos])) { haveTile("Photo or video", "photo.on.rectangle") }
                    .accessibilityIdentifier("have-photo")
                Button { pickingAny = true } label: { haveTile("File", "doc") }.accessibilityIdentifier("have-file")
                Button {
                    if let g = Given.from(text: UIPasteboard.general.string ?? "") { note = nil; given = g }
                    else if let img = UIPasteboard.general.image { note = nil; given = Given(payload: .image(img), label: "A photo") }
                    else { note = "There is nothing copied to paste. Copy some text, a link or a picture first." }
                } label: { haveTile("Paste", "doc.on.clipboard") }.accessibilityIdentifier("have-paste")
            }
        }.cardStyle()
    }
    private func haveTile(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 4) { Image(systemName: icon).font(.system(size: 18, weight: .semibold)); Text(title).font(HandyFont.micro).lineLimit(1).minimumScaleFactor(0.7) }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(HandyColor.accent)
            .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// A tapped reminder lands here: open that tool ready to run.
    private func openReminded() {
        guard let id = ToolSchedules.takePending(), let c = mine.first(where: { $0.id == id }) else { return }
        editing = nil; running = c
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label("Describe it", systemImage: "sparkles").font(HandyFont.cardTitle)
            Text("Say what you want in your own words. Spelling doesn't matter, and half a sentence is enough. Tenzy lines up the steps and shows you before anything runs.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            TextField("e.g. shrink a photo under 1 MB and remove its location", text: $ask, axis: .vertical)
                .lineLimit(1...3).textFieldStyle(.roundedBorder).accessibilityIdentifier("describe-field")
            Button {
                planning = true
                Task {
                    let p = await ChainPlanner.plan(ask)
                    await MainActor.run {
                        planning = false
                        if let p {
                            editHint = p.guessed ? "That wasn't much to go on, so this is my best guess. Change, add or remove any step before you save." : nil
                            editing = p.chain; note = nil
                        }
                        else { note = "I couldn't tell what you'd like done. Say what you have (a photo, a PDF, a video, a recording, a link or some text) and what should happen to it." }
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
                Button("Edit copy") { var k = c; k.id = UUID().uuidString; k.name += " (mine)"; editHint = nil; editing = k }.font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading).cardStyle(padding: HandySpacing.s12)
    }

    private func row(_ c: Chain, mine isMine: Bool) -> some View {
        HStack(spacing: HandySpacing.s12) {
            if let f = c.steps.first { BlockBadge(block: f.block) }
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).font(HandyFont.bodyStrong).lineLimit(2)
                Text(c.steps.map(\.block.title).joined(separator: "  ›  ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
                if let when = c.schedule {
                    Label(when.label(uses24h: ToolSchedules.uses24h), systemImage: "bell").font(HandyFont.caption).foregroundStyle(HandyColor.accent)
                }
                if c.unavailable != nil {
                    Label("Has a step this phone can't run", systemImage: "exclamationmark.triangle").font(HandyFont.caption).foregroundStyle(HandyColor.amber)
                }
            }
            Spacer(minLength: 0)
            Menu {
                Button("Edit") { editHint = nil; editing = c }
                Button("Rename") { newName = c.name; renaming = c }
                if mine.first?.id != c.id {
                    Button("Move to top") { mine.removeAll { $0.id == c.id }; mine.insert(c, at: 0); persist(); note = "\(c.name) is now first, here and on the My Tools widget." }
                }
                Button("Put on Home Screen") {
                    note = "Add the My Tools widget: touch and hold the Home Screen, tap Edit, then Add Widget, choose Tenzy, then My Tools. Your first tools appear on it, one tap each. Use Move to top to choose which."
                }
                Button("Duplicate") {
                    guard BuilderLimits.canSave(savedCount: mine.count, isPremium: StoreManager.shared.isPremium) else { proForSave(); return }
                    var k = c; k.id = UUID().uuidString; k.name += " copy"; k.schedule = nil
                    mine.append(k); persist(); note = "Duplicated as \(k.name)."
                }
                Button("Copy to share") { UIPasteboard.general.string = c.shareText; note = "Copied. Paste it into Tenzy on another phone." }
                if ToolLink.live { Button("Share as a link or QR code") { linking = c } }
                Button("Delete", role: .destructive) { mine.removeAll { $0.id == c.id }; persist() }
            } label: { Image(systemName: "ellipsis.circle").font(.system(size: 20)).frame(width: 44, height: 44) }
            // A compact button with room around its word, so it never looks squeezed beside a long name.
            Button { running = c } label: {
                Text("Run").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent)
                    .padding(.horizontal, HandySpacing.s16).frame(minHeight: 44)
                    .background(HandyColor.accentSoft, in: Capsule())
            }.buttonStyle(.plain).fixedSize().accessibilityLabel("Run \(c.name)")
        }.cardStyle(padding: HandySpacing.s12)
    }
}

/// The builder: a vertical flow from what you give, through each step, to what you get. Each step shows what it
/// does to a sample while you build, so you see the tool working before you save it.
private struct ChainEditor: View {
    @State var chain: Chain
    /// A line from Describe it shown above the steps, e.g. that the tool is a best guess.
    var hint: String? = nil
    var onSave: (Chain) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var previews: [StepPreview?] = []
    @State private var inputPreview: StepPreview?

    private var startKind: ChainKind { chain.steps.first?.block.takes ?? .image }
    private var endKind: ChainKind? { chain.steps.last?.block.gives }
    /// What the person said they start with, before there is a first step to tell us.
    @State private var startChoice: ChainKind?
    private var fitting: [Block] {
        guard let end = endKind else { return startChoice.map(Block.starting(with:)) ?? [] }
        return Block.allCases.filter { end.feeds($0.takes) }
    }
    /// Steps that fit here and that this phone can run, and the ones that fit but it can't.
    private var options: [Block] { fitting.filter { $0.unavailable == nil } }
    private var missing: [Block] { fitting.filter { $0.unavailable != nil } }

    static func icon(for k: ChainKind) -> String {
        switch k {
        case .text: return "text.alignleft"; case .video: return "film"; case .audio: return "waveform"; case .pdf: return "doc.richtext"
        case .image, .photoFile, .file: return "photo"
        }
    }
    /// A name is optional: a tool saved without one is named for what it does.
    private var valid: Bool { chain.problem(starting: startKind) == nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TextField("Name your tool", text: $chain.name).font(HandyFont.title).accessibilityIdentifier("tool-name")
                Text(chain.name.trimmingCharacters(in: .whitespaces).isEmpty && !chain.steps.isEmpty ? "No name yet. It will be saved as \u{201C}\(ChainText.autoName(chain))\u{201D}." : "Tap the name to change it.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, HandySpacing.s16)
                if let hint {
                    Label(hint, systemImage: "sparkles").font(HandyFont.caption).foregroundStyle(HandyColor.accent)
                        .frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12).padding(.bottom, HandySpacing.s12)
                }
                if chain.steps.isEmpty, startChoice == nil {
                    startPicker
                } else {
                    let k = chain.steps.isEmpty ? (startChoice ?? .image) : startKind
                    node(icon: Self.icon(for: k), title: "You give it \(k.label)", sub: chain.steps.isEmpty ? "Now add a first step. You only see steps that work with \(k.label)." : "Preview uses a sample so you can see each step work.")
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
                    if let first = missing.first, let why = first.unavailable {
                        Text(missing.count == 1 ? "\(first.title) is greyed out on this phone. \(why)" : "\(missing.count) steps are greyed out because this phone can't run them. Everything else works.")
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).padding(.top, HandySpacing.s8)
                    }
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
            ToolbarItem(placement: .confirmationAction) { Button("Save") { var c = chain; c.name = ChainText.savedName(c); onSave(c) }.disabled(!valid) }
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
        let collage = Binding<Bool>(get: { chain.collage == true }, set: { chain.collage = $0 ? true : nil; if $0 { chain.combine = nil; chain.onePage = nil; chain.gif = nil; chain.versus = nil } })
        let oneGif = Binding<Bool>(get: { chain.gif == true }, set: { chain.gif = $0 ? true : nil; if $0 { chain.combine = nil; chain.onePage = nil; chain.collage = nil; chain.versus = nil } })
        let versus = Binding<Bool>(get: { chain.versus == true }, set: { chain.versus = $0 ? true : nil; if $0 { chain.combine = nil; chain.onePage = nil; chain.collage = nil; chain.gif = nil } })
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if startKind == .image, endKind != .text {
                Toggle("Put all pages or photos into one PDF", isOn: Binding(get: { onePdf.wrappedValue }, set: { onePdf.wrappedValue = $0; if $0 { chain.collage = nil; chain.gif = nil; chain.versus = nil } })).font(HandyFont.caption).accessibilityIdentifier("finish-one-pdf")
                if chain.combine == true {
                    Toggle("All on a single page (both sides of an ID)", isOn: onePage).font(HandyFont.caption).accessibilityIdentifier("finish-one-page")
                }
                if endKind == .image || endKind == .photoFile {
                    Toggle("Put all photos into one picture (a collage)", isOn: collage).font(HandyFont.caption).accessibilityIdentifier("finish-collage")
                    Toggle("Play all photos as one GIF", isOn: oneGif).font(HandyFont.caption).accessibilityIdentifier("finish-gif")
                    Toggle("Before and after: two photos side by side", isOn: versus).font(HandyFont.caption).accessibilityIdentifier("finish-versus")
                }
            }
            if startKind == .pdf, endKind == .pdf {
                Toggle("Join several PDFs into one", isOn: onePdf).font(HandyFont.caption).accessibilityIdentifier("finish-join-pdf")
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
            if !missing.isEmpty {
                Section("Not on this phone") {
                    ForEach(missing) { b in Button {} label: { Label(b.title, systemImage: b.icon) }.disabled(true) }
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
                startButton(.text, "Text or a link", "text.alignleft")
                startButton(.video, "A video", "film")
            }
            HStack(spacing: HandySpacing.s12) {
                startButton(.audio, "A recording", "waveform")
                startButton(.pdf, "A PDF", "doc.richtext")
            }
            Text("A photo tool also takes scans, PDF pages and QR codes. A text tool also takes a link, what you say, a contact, where you are, or the words in a PDF. A recording tool writes out what was said.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func startButton(_ kind: ChainKind, _ title: String, _ icon: String) -> some View {
        Button { startChoice = kind } label: {
            VStack(spacing: HandySpacing.s8) {
                Image(systemName: icon).font(.title2)
                Text(title).font(HandyFont.bodyStrong).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
        }
        .accessibilityIdentifier(kind == .text ? "start-text" : kind == .video ? "start-video" : kind == .audio ? "start-audio" : kind == .pdf ? "start-pdf" : "start-photo")
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
        if [.video, .audio, .pdf].contains(first.block.takes) {
            // There is no sample video, recording or PDF to try steps on, so say what each one will do instead of showing a result.
            previews = steps.map { s in s.block.unavailable.map { StepPreview.failed($0) } ?? StepPreview.file(s.block.blurb) }
            return
        }
        try? await Task.sleep(nanoseconds: 250_000_000)   // let a stepper settle before re-running
        if Task.isCancelled { return }
        var value: ChainPayload
        switch first.block {
        case .readText, .stamp, .photoPdf: value = .image(SampleAssets.receipt())   // paperwork steps preview on a document
        case .readCode: value = ChainText.qr("https://example.com/sale?utm_source=poster").map { .image($0) } ?? .image(SampleAssets.photo())
        case .pageText: value = .text("https://example.com/article")
        case _ where first.block.takes == .text: value = .text(Self.sampleText)
        default: value = .image(SampleAssets.photo())
        }
        for (i, step) in steps.enumerated() {
            if Task.isCancelled { return }
            if !value.kind.feeds(step.block.takes) { previews[i] = .failed("Needs \(step.block.takes.label) from the step above."); continue }
            if let why = step.block.unavailable { previews[i] = .failed("Not available on this phone. " + why); return }
            if ChainExtras.noPreview.contains(step.block), step.block != .pageText {
                // These need a voice, a translator or the writing model, so the sample isn't run through them.
                previews[i] = .file(step.block.blurb)
                if step.block.gives == .text { continue }      // the steps below still preview, on the text as it was
                for j in (i + 1)..<steps.count { previews[j] = .file(steps[j].block.blurb) }
                return
            }
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
        case .video(let u): return .file("Video · " + (SizeTarget.fileSize(u).map(SizeTarget.format) ?? "ready"))
        }
    }

    private func defaults(_ b: Block) -> [String: String] {
        switch b { case .shrinkImage: return ["mb": "2"]; case .summarize: return ["sentences": "3"]; case .convertImage: return ["format": "JPG"]; case .passportPhoto: return ["country": "us"]
        case .watermark: return ["text": "For verification only"]; case .resizePhoto: return ["size": "413x531"]
        case .stamp: return ["marks": StampPlan.standard.text]; case .addToList: return ["list": RunningList.defaultName]
        case .chatLink: return ["cc": ChainText.callingCode(region: Locale.current.region?.identifier)]
        case .videoTrim: return ["side": "first", "secs": "30"]; case .videoRotate: return ["turn": "right"]; case .videoShrink: return ["mb": "25"]
        case .translate: return ["to": "en"]; case .rewrite: return ["style": "clear"]
        case .pdfShrink: return ["mb": "5"]; case .pdfLock: return ["password": ""]; case .pdfPages: return ["pages": ""]
        case .emojiFaces: return ["emoji": ChainText.faceEmojis[0]]; case .meme: return ["top": "", "bottom": ""]
        case .videoSpeed: return ["speed": "slow"]; case .videoLoop: return ["style": "boomerang"]
        case .artFilter: return ["style": "sketch"]; case .voiceChange: return ["voice": "chipmunk"]
        default: return [:] }
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
        case .videoShrink:
            Picker("Size limit", selection: Binding(get: { ChainText.videoLimit(chain.steps[i].settings["mb"]) }, set: { chain.steps[i].settings["mb"] = String($0) })) {
                ForEach(ChainText.videoLimits, id: \.self) { Text("\($0) MB").tag($0) }
            }.pickerStyle(.segmented)
        case .returnBy:
            Picker("Return window", selection: Binding(get: { ChainText.returnDays(chain.steps[i].settings["days"]) }, set: { chain.steps[i].settings["days"] = String($0) })) {
                ForEach(ChainText.returnWindows, id: \.self) { Text("\($0) days").tag($0) }
            }.pickerStyle(.segmented)
        case .videoTrim:
            Picker("Which part", selection: Binding(get: { chain.steps[i].settings["side"] == "last" ? "last" : "first" }, set: { chain.steps[i].settings["side"] = $0 })) {
                Text("The start").tag("first"); Text("The end").tag("last")
            }.pickerStyle(.segmented)
            let secs = Int(chain.steps[i].settings["secs"] ?? "") ?? 30
            Picker("How long", selection: Binding(get: { secs }, set: { chain.steps[i].settings["secs"] = String($0) })) {
                ForEach(ChainText.trimLengths.contains(secs) ? ChainText.trimLengths : (ChainText.trimLengths + [secs]).sorted(), id: \.self) { Text("\($0) sec").tag($0) }
            }.pickerStyle(.segmented)
        case .videoRotate:
            Picker("Turn", selection: Binding(get: { chain.steps[i].settings["turn"] ?? "right" }, set: { chain.steps[i].settings["turn"] = $0 })) {
                Text("Right").tag("right"); Text("Left").tag("left"); Text("Upside down").tag("flip")
            }.pickerStyle(.segmented)
        case .translate:
            Picker("Into", selection: Binding(get: { ChainText.languageCode(chain.steps[i].settings["to"]) }, set: { chain.steps[i].settings["to"] = $0 })) {
                ForEach(ChainText.languages, id: \.code) { Text($0.name).tag($0.code) }
            }.pickerStyle(.menu).font(HandyFont.caption)
            Text("The first time you use a language, the phone may ask to download it.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .rewrite:
            Picker("Make it", selection: Binding(get: { ChainText.rewriteStyle(chain.steps[i].settings["style"]) }, set: { chain.steps[i].settings["style"] = $0 })) {
                ForEach(ChainText.rewriteStyles, id: \.id) { Text($0.name).tag($0.id) }
            }.pickerStyle(.menu).font(HandyFont.caption)
        case .pdfShrink:
            let limit = ChainText.pdfLimit(chain.steps[i].settings["mb"])
            Picker("Size limit", selection: Binding(get: { limit }, set: { chain.steps[i].settings["mb"] = String($0) })) {
                ForEach(ChainText.pdfLimits.contains(limit) ? ChainText.pdfLimits : (ChainText.pdfLimits + [limit]).sorted(), id: \.self) { Text("\($0) MB").tag($0) }
            }.pickerStyle(.segmented)
        case .pdfLock:
            SecureField("Password", text: Binding(get: { chain.steps[i].settings["password"] ?? "" }, set: { chain.steps[i].settings["password"] = $0 }))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .font(HandyFont.caption).padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
            Text("Kept on this phone with the tool. It is left out when you copy the tool to share.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .pdfPages:
            TextField("Pages, e.g. 1-3, 5 (empty keeps all)", text: Binding(get: { chain.steps[i].settings["pages"] ?? "" }, set: { chain.steps[i].settings["pages"] = $0 }))
                .keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                .font(HandyFont.caption).padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
        case .emojiFaces:
            Picker("Emoji", selection: Binding(get: { ChainText.faceEmoji(chain.steps[i].settings["emoji"]) }, set: { chain.steps[i].settings["emoji"] = $0 })) {
                ForEach(ChainText.faceEmojis, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
        case .meme:
            TextField("Top line", text: Binding(get: { chain.steps[i].settings["top"] ?? "" }, set: { chain.steps[i].settings["top"] = $0 }))
                .font(HandyFont.caption).padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8)).accessibilityIdentifier("meme-top")
            TextField("Bottom line", text: Binding(get: { chain.steps[i].settings["bottom"] ?? "" }, set: { chain.steps[i].settings["bottom"] = $0 }))
                .font(HandyFont.caption).padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8)).accessibilityIdentifier("meme-bottom")
            Text("Leave them empty to type new words every time you run the tool.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        case .videoSpeed:
            Picker("Speed", selection: Binding(get: { ChainText.speeds.first { $0.id == chain.steps[i].settings["speed"] }?.id ?? "slow" }, set: { chain.steps[i].settings["speed"] = $0 })) {
                ForEach(ChainText.speeds, id: \.id) { Text($0.name).tag($0.id) }
            }.pickerStyle(.segmented)
        case .artFilter:
            Picker("Style", selection: Binding(get: { PixelArt.style(chain.steps[i].settings["style"]) }, set: { chain.steps[i].settings["style"] = $0 })) {
                ForEach(PixelArt.styles, id: \.id) { Text($0.name).tag($0.id) }
            }.pickerStyle(.menu).font(HandyFont.caption)
        case .voiceChange:
            Picker("Voice", selection: Binding(get: { ChainText.voices.first { $0.id == chain.steps[i].settings["voice"] }?.id ?? "chipmunk" }, set: { chain.steps[i].settings["voice"] = $0 })) {
                ForEach(ChainText.voices, id: \.id) { Text($0.name).tag($0.id) }
            }.pickerStyle(.segmented)
        case .videoLoop:
            Picker("Plays", selection: Binding(get: { chain.steps[i].settings["style"] == "reverse" ? "reverse" : "boomerang" }, set: { chain.steps[i].settings["style"] = $0 })) {
                Text("Forwards and back").tag("boomerang"); Text("Backwards").tag("reverse")
            }.pickerStyle(.segmented)
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
        case .video(let u): b.url = u; b.summary = (SizeTarget.fileSize(u).map(SizeTarget.format) ?? "") + " · VIDEO"
        }
        return b
    }
}

/// Give it a photo or some text, see the result, copy or share it.
private struct ChainRunView: View {
    let chain: Chain
    /// Handed over already ("Start with what you have"): the tool runs on it straight away.
    var initial: ChainPayload? = nil
    @State private var started = false
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
    @State private var videoPick: PhotosPickerItem?
    @State private var livePick: PhotosPickerItem?
    /// A meme's words can be typed fresh for each run.
    @State private var memeTop = ""
    @State private var memeBottom = ""
    @State private var memeLoaded = false
    @StateObject private var here = WhereAmI()
    @StateObject private var recorder = QuickRecorder()
    /// What each result of a many-at-once run is called in the list: a photo, or a file.
    @State private var noun = "Photo"
    @State private var busy = false
    @State private var result: ChainPayload?
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss

    private var start: ChainKind { chain.steps.first?.block.takes ?? .image }
    private var hasMeme: Bool { chain.steps.contains { $0.block == .meme } }

    /// The tool as it runs this time: a meme step takes the words typed on this screen.
    private var runChain: Chain {
        guard hasMeme else { return chain }
        var c = chain
        for i in c.steps.indices where c.steps[i].block == .meme {
            c.steps[i].settings["top"] = memeTop; c.steps[i].settings["bottom"] = memeBottom
        }
        return c
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                Text(chain.name).font(HandyFont.title)
                stampSetup
                if hasMeme {
                    TextField("Top line", text: $memeTop).padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("run-meme-top")
                    TextField("Bottom line", text: $memeBottom).padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("run-meme-bottom")
                }
                if let why = chain.unavailable {
                    Label(why, systemImage: "exclamationmark.triangle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.amber).cardStyle(padding: HandySpacing.s12)
                }
                if start == .audio {
                    audioInputs
                } else if start == .pdf {
                    pdfInputs
                } else if start == .video {
                    PhotosPicker(selection: $videoPick, matching: .videos) { Label("Choose a video", systemImage: "film").frame(maxWidth: .infinity) }
                        .primaryButton().accessibilityIdentifier("run-video")
                    PhotosPicker(selection: $livePick, matching: .livePhotos) { Label("Choose a Live Photo", systemImage: "livephoto").frame(maxWidth: .infinity) }
                        .secondaryButton().accessibilityIdentifier("run-live-photo")
                    Text("Long videos take a little while. Keep Tenzy open until it finishes. A Live Photo is used as its short video.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                } else if start != .text {
                    PhotosPicker(selection: $picks, maxSelectionCount: 20, matching: .images) { Label("Choose photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }.primaryButton()
                    if VNDocumentCameraViewController.isSupported {
                        Button { scanning = true } label: { Label("Scan a document", systemImage: "doc.viewfinder").frame(maxWidth: .infinity) }
                            .secondaryButton().accessibilityIdentifier("run-scan")
                    }
                    Button { pickingPDF = true } label: { Label("Choose a PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity) }
                        .secondaryButton().accessibilityIdentifier("run-pdf")
                    Text(chain.combine == true ? "Pick or scan as many pages as you need. They all go into one PDF." : chain.collage == true ? "Pick up to 20 photos. They are laid out as one picture." : chain.gif == true ? "Pick up to 20 photos. They play one after another as a GIF." : chain.versus == true ? "Pick two photos: the before, then the after." : "Pick one, or up to 20 at once. Each one gets the same steps.")
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
                        fill(here.looking ? "Finding…" : "Location", "location", id: "in-location") { addLocation() }
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
            if items.count == 1, chain.gif != true, chain.versus != true, let item = items.first {
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
        .fileImporter(isPresented: $pickingPDF, allowedContentTypes: start == .audio ? [.audio] : [.pdf], allowsMultipleSelection: start == .pdf) { r in
            guard case .success(let urls) = r, let url = urls.first else { return }
            if start == .audio {
                if let d = Self.read(url) { go(.file(d, ext: url.pathExtension.isEmpty ? "m4a" : url.pathExtension.lowercased())) }
                else { message = "That recording couldn't be opened. Try another." }
            } else if start == .pdf {
                // One PDF runs straight away; several each get the tool's steps (and are joined if the tool says so).
                if urls.count == 1 {
                    if let d = Self.read(url) { go(.file(d, ext: "pdf")) } else { message = "That PDF couldn't be opened. Try another." }
                } else {
                    runMany(count: urls.count, noun: "File") { i in Self.read(urls[i]).map { ChainPayload.file($0, ext: "pdf") } }
                }
            } else if start == .text {
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
        .onDisappear { if speech.running { speech.stop() }; if recorder.running { _ = recorder.stop() } }
        .onAppear {
            if !memeLoaded, let words = chain.steps.first(where: { $0.block == .meme })?.settings {
                memeLoaded = true
                memeTop = words["top"] ?? ""; memeBottom = words["bottom"] ?? ""
            }
            guard let initial, !started else { return }
            started = true
            if case .text(let t) = initial { text = t }
            go(initial)
        }
        .onChange(of: videoPick) { _, item in
            guard let item else { return }
            videoPick = nil
            busy = true; result = nil; message = nil; batch = []; outbox = nil; progress = "Getting the video ready…"
            Task {
                let movie = try? await item.loadTransferable(type: MovieImport.self)
                await MainActor.run {
                    if let movie { go(.video(movie.url)) } else { busy = false; progress = ""; message = "That video couldn't be opened. Try another." }
                }
            }
        }
        .onChange(of: livePick) { _, item in
            guard let item else { return }
            livePick = nil
            busy = true; result = nil; message = nil; batch = []; outbox = nil; progress = "Getting the Live Photo ready…"
            Task {
                let movie = await LivePhotoVideo.movie(from: item)
                await MainActor.run {
                    if let movie { go(.video(movie)) } else { busy = false; progress = ""; message = "That Live Photo couldn't be opened. Try another, or choose a video." }
                }
            }
        }
        .fullScreenCover(isPresented: $scanning) {
            // Apple's document camera: finds the page edges, straightens it, and takes several pages in one go.
            DocCameraSheet { pages in
                scanning = false
                if pages.count == 1 { go(.image(pages[0])) } else if pages.count > 1 { runBatch(count: pages.count) { i in pages[i] } }
            }.ignoresSafeArea()
        }
    }

    /// A tool that starts with a recording: make one here, or pick one.
    @ViewBuilder private var audioInputs: some View {
            Button { toggleRecording() } label: { Label(recorder.running ? "Stop and run" : "Record", systemImage: recorder.running ? "stop.circle.fill" : "mic").frame(maxWidth: .infinity) }
                .primaryButton().accessibilityIdentifier("run-record")
            Button { pickingPDF = true } label: { Label("Choose a recording", systemImage: "waveform").frame(maxWidth: .infinity) }
                .secondaryButton().disabled(recorder.running).accessibilityIdentifier("run-audio")
            Text(recorder.running ? "Recording… tap Stop when you're done." : "Record now, or pick a voice memo or any sound file. It never leaves this phone.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
    }

    /// A tool that starts with a PDF.
    @ViewBuilder private var pdfInputs: some View {
            Button { pickingPDF = true } label: { Label(chain.combine == true ? "Choose PDFs" : "Choose a PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity) }
                .primaryButton().accessibilityIdentifier("run-pdf-file")
            Text(chain.combine == true ? "Pick them in the order you want. They are joined into one PDF." : "Pick one, or several at once. Each one gets the same steps.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
    }

    private func fill(_ title: String, _ icon: String, id: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(spacing: 4) { Image(systemName: icon).font(.system(size: 18, weight: .semibold)); Text(title).font(HandyFont.micro).lineLimit(1).minimumScaleFactor(0.7) }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }.buttonStyle(.plain).foregroundStyle(HandyColor.accent).accessibilityIdentifier(id)
    }

    /// A picked file's bytes. Files chosen from the Files app need their access opened first.
    private static func read(_ url: URL) -> Data? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }

    /// Record: starts a recording, and on Stop runs the tool on it.
    private func toggleRecording() {
        if recorder.running {
            if let url = recorder.stop(), let d = try? Data(contentsOf: url), !d.isEmpty { go(.file(d, ext: "m4a")) }
            else { message = "Nothing was recorded. Try again." }
        } else {
            message = nil; result = nil
            recorder.start { message = "Tenzy needs the microphone to record. Allow it in Settings, or choose a recording instead." }
        }
    }

    /// Location: adds where the phone is (an address and a map link) to the text box.
    private func addLocation() {
        guard !here.looking else { return }
        message = nil
        here.find { found in
            if let found { text = InputText.joined(text, found) }
            else { message = "Tenzy couldn't find where you are. Check that Location is allowed for Tenzy in Settings, or type the place in." }
        }
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
        runMany(count: count, noun: "Photo") { i in await load(i).map { ChainPayload.image($0) } }
    }

    /// The same for anything a tool can start with: photos, pages, or several PDFs.
    private func runMany(count: Int, noun name: String, load: @escaping (Int) async -> ChainPayload?) {
        busy = true; result = nil; message = nil; batch = []; outbox = nil; noun = name
        let combine = chain.combine == true
        let collage = chain.collage == true
        let gif = chain.gif == true
        let versus = chain.versus == true
        let tool = runChain
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-batch-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        Task {
            var out: [BatchItem] = []
            var kept: [ChainPayload] = []      // only held when everything is going into one PDF
            for i in 0..<count {
                await MainActor.run { progress = "Working… \(i + 1) of \(count)" }
                guard let item = await load(i) else {
                    out.append(BatchItem(n: i + 1, note: "Couldn't open this \(name.lowercased()).")); continue
                }
                switch await ChainRunner.run(tool, input: item) {
                case .success(let p):
                    if combine || collage || gif || versus { kept.append(p) }
                    out.append(BatchItem.make(n: i + 1, payload: p, in: dir, named: chain.fileName, tool: chain.name))
                case .failure(let f): out.append(BatchItem(n: i + 1, note: ChainRunView.words(f)))
                }
            }
            // One PDF for everything, when the tool asks for it and the results can be joined.
            if versus, kept.count < 2 {
                await MainActor.run { busy = false; progress = ""; message = "Before and after needs two photos: pick the before and the after together." }
                return
            }
            if let one = versus ? ChainCombine.beforeAfter(kept) : gif ? ChainCombine.oneGif(kept) : collage ? ChainCombine.onePicture(kept) : combine ? ChainCombine.onePDF(kept, onePage: chain.onePage == true) : nil {
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
        // Kept so the result is still there after this screen is closed. Copied off the main thread: a video can be large.
        if let box { let name = chain.name; Task.detached(priority: .utility) { RunHistory.add(box, tool: name) } }
        if let f = chain.finish, f.kind == .open, box != nil { openLink(box) }
        else if let f = chain.finish, f.kind == .mail || f.kind == .message, box != nil, SendSheet.canSend(f.kind) { sending = true }
    }

    @ViewBuilder private var batchView: some View {
        let ok = batch.filter { $0.note == nil }
        let urls = ok.compactMap(\.url)
        let texts = ok.compactMap { b in b.text.map { "\(noun) \(b.n)\n\($0)" } }
        Text("\(ok.count) of \(batch.count) done").font(HandyFont.cardTitle)
        ForEach(batch) { b in
            HStack {
                Image(systemName: b.note == nil ? "checkmark.circle.fill" : "exclamationmark.circle").foregroundStyle(b.note == nil ? Color.green : HandyColor.textSecondary)
                Text("\(noun) \(b.n)").font(HandyFont.bodyStrong)
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
        case .video(let u):
            Label("Your video is ready" + (SizeTarget.fileSize(u).map { " · " + SizeTarget.format($0) } ?? ""), systemImage: "film").font(HandyFont.bodyStrong)
            ShareLink(item: u) { Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
        }
    }

    private func tempURL(_ d: Data, _ ext: String) -> URL? {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(ChainName.file(pattern: chain.fileName, tool: chain.name, ext: ext))
        return (try? d.write(to: u)) != nil ? u : nil
    }

    private func go(_ input: ChainPayload) {
        busy = true; result = nil; message = nil; batch = []; progress = ""; outbox = nil
        let tool = runChain
        Task {
            let r = await ChainRunner.run(tool, input: input)
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

/// "Start with what you have", step two: the tools that fit the thing that was picked. The person's own first.
private struct ToolPickView: View {
    let given: Given
    let mine: [Chain]
    @Environment(\.dismiss) private var dismiss

    private var tools: [Chain] {
        let kind = given.payload.kind == .photoFile ? ChainKind.image : given.payload.kind
        return ChainStore.offers(for: kind, mine: mine, last: nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                Text(given.label).font(HandyFont.title)
                if case .text(let t) = given.payload { Text(t).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(3) }
                if tools.isEmpty {
                    Text("No tool takes this yet. Close this, tap Blank, and build one that starts with \(given.payload.kind.label).").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                } else {
                    Text("Pick what to do with it. It runs straight away.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                ForEach(tools) { c in
                    NavigationLink { ChainRunView(chain: c, initial: given.payload) } label: {
                        HStack(spacing: HandySpacing.s12) {
                            if let f = c.steps.first { BlockBadge(block: f.block) }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                                Text(c.steps.map(\.block.title).joined(separator: "  ›  ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2).multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(HandyColor.textSecondary)
                        }.cardStyle(padding: HandySpacing.s12)
                    }.buttonStyle(.plain).accessibilityIdentifier("pick-tool-\(c.id)")
                }
            }.padding(HandySpacing.gutter)
        }
        .background(HandyColor.bg)
        .navigationTitle("What to do with it").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
    }
}
