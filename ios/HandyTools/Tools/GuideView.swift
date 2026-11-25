import SwiftUI
import AVFoundation

/// "What to do with it", as a guided walk instead of a long list:
///   1. What you want — Tenzy looks at the photo and suggests the likeliest job, then up to six big choices.
///   2. How — the two or three best ways to do that job, each with a small preview made from the person's own photo.
///   3. Your result — the tool runs and ends on its preview, ready to save or share.
/// Back always goes one step back; nothing is ever more than three taps away.
struct GuideView: View {
    let given: Given
    let mine: [Chain]
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Stop] = []
    @State private var clues: Guide.Clues?
    @StateObject private var previews = GuidePreviews()

    enum Stop: Hashable { case goal(String), tool(String), chain(String), voices }

    private var kind: ChainKind { given.payload.kind == .photoFile ? .image : given.payload.kind }
    private var isPhoto: Bool { kind == .image }
    private var photos: [UIImage] { (ToolHandoff.image(given.payload).map { [$0] } ?? []) + given.more }

    /// Ready-made flows and the person's own that take this kind of thing (same rules the old list used).
    private var chains: [Chain] {
        let text: String? = { if case .text(let t) = given.payload { return t } else { return nil } }()
        let offers = ChainStore.offers(for: kind, mine: mine, last: nil, text: text)
        if given.label == "A link" {
            let linkStart: Set<Block> = [.pageText, .cleanLinks, .makeQr, .scamCheck]
            let picked = offers.filter { linkStart.contains($0.steps.first?.block ?? .readText) }
            return picked.isEmpty ? offers : picked
        }
        if kind == .audio { return offers.filter { $0.steps.first?.block != .voiceChange } }
        return offers
    }
    private var tools: [String] { ToolHandoff.tools(for: given.payload.kind).filter { id in TOOLS.contains { $0.id == id } } }

    /// Goals with what's in them — never more than six on the screen (the rest fold into "Something else").
    private var goals: [(goal: String, options: [Guide.Option])] {
        let all = Guide.sort(kind: kind, count: given.count, tools: tools, chains: chains, voices: kind == .audio)
        guard all.count > 6 else { return all }
        let keep = Array(all.prefix(5))
        let rest = all.dropFirst(5).flatMap(\.options)
        return keep + [(goal: "more", options: Array(rest))]
    }
    private func options(_ goal: String) -> [Guide.Option] {
        if kind == .video { return videoJobs.first { $0.goal == goal }?.options ?? [] }
        return goals.first { $0.goal == goal }?.options ?? []
    }
    /// A video's ways, sorted into the jobs people think in (Guide.videoJobs) — the whole choice on one screen.
    private var videoJobs: [(goal: String, options: [Guide.Option])] {
        Guide.videoJobs(Guide.sort(kind: .video, count: 1, tools: tools, chains: chains, voices: false).flatMap(\.options))
    }

    /// UI tests only: leave parts of this screen out to find which part breaks ("-guideskip header,grid").
    static let skip: Set<String> = {
        guard Launch.uitest, let i = Launch.args.firstIndex(of: "-guideskip"), Launch.args.indices.contains(i + 1) else { return [] }
        return Set(Launch.args[i + 1].split(separator: ",").map(String.init))
    }()

    private var guess: Guide.Guess? { clues.flatMap { Guide.guess($0, kind: kind) } }
    private var suggested: Guide.Option? {
        guard let g = guess else { return nil }
        return Guide.pick(g, from: options(g.goal))
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group { if kind == .video { videoStart } else { start } }
                .navigationDestination(for: Stop.self) { stop in destination(stop) }
                .navigationDestination(for: String.self) { id in ToolDestination(id: id) }
        }
        .interactiveDismissDisabled(!path.isEmpty)
        .task {
            Diagnostics.shared.crumb("Guide: \(given.label)")
            guard !Self.skip.contains("task") else { return }
            guard isPhoto, let first = photos.first else { return }
            previews.prepare(photos: photos)
            let file: Data? = { if case .file(let d, _) = given.payload { return d } else { return nil } }()
            let c = await Guide.clues(first, count: given.count, file: file)
            clues = c
            if let s = suggested { previews.make([s], kind: kind) }
        }
    }

    // MARK: step 1 — what do you want?

    private var start: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                if !Self.skip.contains("steps") { GuideSteps(step: 1) }
                if !Self.skip.contains("header") { header }
                justOpen
                Text(L("What do you want to do?")).font(HandyFont.title)
                if Self.skip.contains("suggest") { EmptyView() }
                else if let s = suggested, let g = guess { suggestion(s, why: g.why) }
                else if isPhoto && clues == nil { ToolProgressBar(label: "Looking at your photo…", showsTime: false) }
                if !Self.skip.contains("grid") { LazyVGrid(columns: [GridItem(.flexible(), spacing: HandySpacing.s12), GridItem(.flexible(), spacing: HandySpacing.s12)], spacing: HandySpacing.s12) {
                    ForEach(goals, id: \.goal) { g in
                        Button { Diagnostics.shared.crumb("Guide: chose \(g.goal)"); path.append(.goal(g.goal)) } label: { GoalTile(goal: Guide.goal(g.goal, count: given.count), ways: g.options.count, highlighted: guess?.goal == g.goal) }
                            .buttonStyle(.plain).accessibilityIdentifier("goal-\(g.goal)")
                    }
                }
                }
                if goals.isEmpty {
                    Text("No tool takes \(given.payload.kind.label) yet. Close this, tap Blank, and build one that starts with it.")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            .padding(HandySpacing.gutter)
        }
        .background(Ground())
        .navigationTitle(L("What to do with it")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Close")) { dismiss() } } }
    }

    // MARK: step 1 for a video — one screen, every job in plain words

    @State private var facts: VideoFacts?
    @State private var poster: UIImage?
    private var videoURL: URL? { if case .video(let u) = given.payload { return u }; return nil }
    private var hint: (goal: String, why: String)? { facts.map { Guide.videoHint(bytes: $0.bytes, seconds: $0.seconds, tall: $0.isTall) } }

    private var videoStart: some View {
        let jobs = videoJobs
        let grid = jobs.filter { $0.goal != "stunning" }
        return ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                GuideSteps(step: 1)
                videoHeader
                Text(L("What do you want to do with it?")).font(HandyFont.title).padding(.top, 2)
                if let hero = jobs.first(where: { $0.goal == "stunning" }) {
                    Button { pick(hero.goal, hero.options) } label: { StunningCard(goal: Guide.videoGoal(hero.goal), suggested: hint?.goal == hero.goal) }
                        .buttonStyle(.plain).accessibilityIdentifier("goal-stunning")
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(grid, id: \.goal) { j in
                        Button { pick(j.goal, j.options) } label: { VideoJobTile(goal: Guide.videoGoal(j.goal), suggested: hint?.goal == j.goal) }
                            .buttonStyle(.plain).accessibilityIdentifier("goal-\(j.goal)")
                    }
                }
            }
            .padding(.horizontal, HandySpacing.gutter).padding(.vertical, HandySpacing.s12)
        }
        .background(Ground())
        .navigationTitle(L("Your video")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Close")) { dismiss() } } }
        .task {
            guard let u = videoURL else { return }
            facts = await VideoFacts.read(u)
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: u)); gen.appliesPreferredTrackTransform = true; gen.maximumSize = CGSize(width: 240, height: 240)
            if let cg = try? await gen.image(at: CMTime(seconds: min(1, max(0, (facts?.seconds ?? 0) / 3)), preferredTimescale: 600)).image { poster = UIImage(cgImage: cg) }
        }
    }

    /// One job with a single way goes straight there; several show the ways (step 2).
    private func pick(_ goal: String, _ options: [Guide.Option]) {
        Diagnostics.shared.crumb("Guide: chose video \(goal)")
        if options.count == 1, let o = options.first { open(o) } else { path.append(.goal(goal)) }
    }

    /// The video itself: a frame to tap and watch, how long and big it is, and what Tenzy noticed.
    private var videoHeader: some View {
        HStack(spacing: HandySpacing.s12) {
            Button {
                if let u = ToolHandoff.fileURL(given.payload, name: "Video") { FileOpenInbox.shared.receive(u); path.append(.tool("fileviewer")) }
            } label: {
                ZStack {
                    if let poster { Image(uiImage: poster).resizable().scaledToFill() } else { HandyColor.surface }
                    Image(systemName: "play.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(.black.opacity(0.45), in: Circle())
                }
                .frame(width: 68, height: 68).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel(L("Play it")).accessibilityIdentifier("guide-just-open")
            VStack(alignment: .leading, spacing: 3) {
                if let f = facts {
                    Text([VideoFacts.clock(f.seconds), SizeTarget.format(f.bytes), L(f.isTall ? "Tall" : f.size.width > f.size.height ? "Sideways" : "Square"), f.hasSound ? nil : L("No sound")].compactMap { $0 }.joined(separator: " · "))
                        .font(HandyFont.bodyStrong).lineLimit(1).minimumScaleFactor(0.8)
                } else {
                    Text(L(given.label)).font(HandyFont.bodyStrong)
                }
                if let h = hint {
                    Label(L(h.why), systemImage: "sparkles").font(HandyFont.caption).foregroundStyle(HandyColor.accent)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(L("Tap the picture to watch it")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("video-header")
    }

    /// The thing that was handed over, so the person sees what they're working on.
    @ViewBuilder private var header: some View {
        if isPhoto {
            HStack(spacing: HandySpacing.s8) {
                ForEach(Array(previews.thumbs.prefix(4).enumerated()), id: \.offset) { i, t in
                    ZStack {
                        Image(uiImage: t).resizable().scaledToFill().frame(width: 64, height: 64).clipped().contentShape(Rectangle()).accessibilityHidden(true)
                        if i == 3, given.count > 4 {
                            Color.black.opacity(0.55)
                            Text("+\(given.count - 3)").font(HandyFont.bodyStrong).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(given.label)).font(HandyFont.bodyStrong)
                    Text(L(given.count > 1 ? "Every step works on all of them" : "Ready when you are")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(L(given.label)).font(HandyFont.bodyStrong).lineLimit(2).truncationMode(.middle)
                if case .text(let t) = given.payload, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(t).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(3)
                }
            }
        }
    }

    /// First choice for any file, video or recording: just look at it — read the whole document, play the clip,
    /// scroll the sheet — in File Opener, even when no other app on the phone opens it.
    @ViewBuilder private var justOpen: some View {
        if !isPhoto, given.payload.kind != .text, let url = ToolHandoff.fileURL(given.payload, name: "File") {
            Button {
                FileOpenInbox.shared.receive(url)
                path.append(.tool("fileviewer"))
            } label: {
                HStack(spacing: HandySpacing.s12) {
                    Image(systemName: "eye").font(.title3).foregroundStyle(HandyColor.accent).frame(width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Just open it")).font(HandyFont.bodyStrong)
                        Text(L("Read, play or scroll through the whole thing here — even when no other app opens it.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(HandyColor.textSecondary)
                }
                .padding(HandySpacing.s12).frame(maxWidth: .infinity, alignment: .leading)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain).accessibilityIdentifier("guide-just-open")
        }
    }

    /// Tenzy's best guess, one tap from the result.
    private func suggestion(_ o: Guide.Option, why: String) -> some View {
        Button { open(o) } label: {
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Label(L(why), systemImage: "sparkles").font(HandyFont.micro).foregroundStyle(HandyColor.accent)
                OptionRow(option: o, kind: kind, count: given.count, preview: Self.skip.contains("preview") ? nil : previews.image(o), snippet: previews.snippet(o), big: true)
            }
            .padding(HandySpacing.s12)
            .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous).stroke(HandyColor.accent.opacity(0.6), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(L(why)). \(Guide.title(o, count: given.count, kind: kind))"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("guide-suggested")
        .accessibilityHint(L("Opens it straight away"))
    }

    // MARK: step 2 — how?

    @ViewBuilder private func destination(_ stop: Stop) -> some View {
        switch stop {
        case .goal(let g): GoalScreen(goal: kind == .video ? Guide.videoGoal(g) : Guide.goal(g, count: given.count), options: options(g), kind: kind, count: given.count, previews: previews, open: open)
        case .tool(let id): ToolDestination(id: id)
        case .chain(let id):
            if let c = chains.first(where: { $0.id == id }) {
                if given.count > 1, isPhoto { ChainRunView(chain: c, initialMany: given.all) } else { ChainRunView(chain: c, initial: given.payload) }
            }
        case .voices: VoicePickerView(payload: given.payload)
        }
    }

    // MARK: step 3 — your result

    /// Open a choice inside this same walk, so Back comes straight back here (never to Home).
    private func open(_ o: Guide.Option) {
        Diagnostics.shared.crumb("Guide: opened \(o.id) with \(given.count)")
        switch o {
        case .tool(let id):
            ToolHandoff.shared.put(given.payload, for: id, others: given.more)
            path.append(.tool(id))
        case .chain(let c): path.append(.chain(c.id))
        case .voices: path.append(.voices)
        }
    }
}

/// "1 What · 2 How · 3 Result" — where the person is in the walk.
struct GuideSteps: View {
    let step: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(["What you want", "How", "Your result"].enumerated()), id: \.offset) { i, s in
                HStack(spacing: 4) {
                    Text("\(i + 1)").font(.system(size: 11, weight: .bold))
                        .frame(width: 18, height: 18)
                        .foregroundStyle(i + 1 <= step ? HandyColor.onAccent : HandyColor.textSecondary)
                        .background(i + 1 <= step ? HandyColor.accent : HandyColor.surface, in: Circle())
                    Text(L(s)).font(HandyFont.micro).foregroundStyle(i + 1 == step ? HandyColor.textPrimary : HandyColor.textSecondary)
                }
                if i < 2 { Rectangle().fill(HandyColor.border).frame(height: 1).frame(maxWidth: 24) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(L("Step")) \(step) / 3")
    }
}

/// The big card at the top for a video: the wow job.
private struct StunningCard: View {
    let goal: Guide.Goal
    var suggested = false
    var body: some View {
        HStack(spacing: HandySpacing.s12) {
            Image(systemName: goal.icon).font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 52, height: 52).background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(L(goal.title)).font(HandyFont.title).foregroundStyle(.white)
                Text(L(goal.line)).font(HandyFont.caption).foregroundStyle(.white.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.85))
        }
        .padding(HandySpacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: 0x7C3AED), Color(hex: 0xDB2777), Color(hex: 0xF59E0B)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous).stroke(.white.opacity(suggested ? 0.9 : 0.15), lineWidth: suggested ? 2 : 1))
        .shadow(color: Color(hex: 0xDB2777).opacity(0.35), radius: 14, y: 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(L(goal.title)). \(L(goal.line))"))
    }
}

/// One video job in the grid: a coloured picture, the job in a few words, and what it gets you.
private struct VideoJobTile: View {
    let goal: Guide.Goal
    var suggested = false
    static func tint(_ id: String) -> Color {
        switch id {
        case "post": return Color(hex: 0xE1306C)
        case "cut": return Color(hex: 0x0EA5E9)
        case "send": return Color(hex: 0x10B981)
        case "fun": return Color(hex: 0xEAB308)
        case "speed": return Color(hex: 0xF97316)
        case "sound": return Color(hex: 0x8B5CF6)
        case "words": return Color(hex: 0x3B82F6)
        case "photo": return Color(hex: 0x14B8A6)
        default: return Color(hex: 0x64748B)
        }
    }
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: goal.icon)
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(LinearGradient(colors: [Self.tint(goal.id), Self.tint(goal.id).opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(L(goal.title)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    .lineLimit(2).minimumScaleFactor(0.85).fixedSize(horizontal: false, vertical: true)
                Text(L(goal.line)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous)
            .stroke(suggested ? HandyColor.accent : HandyColor.border, lineWidth: suggested ? 1.5 : 1))
        .overlay(alignment: .topTrailing) {
            if suggested {
                Image(systemName: "sparkles").font(.system(size: 10, weight: .bold)).foregroundStyle(HandyColor.onAccent)
                    .padding(5).background(HandyColor.accent, in: Circle()).offset(x: 4, y: -4)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(L(goal.title)). \(L(goal.line))\(suggested ? ". " + L("Suggested") : "")"))
    }
}

private struct GoalTile: View {
    let goal: Guide.Goal
    let ways: Int
    var highlighted = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: goal.icon)
                .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(LinearGradient(colors: [Guide.tint(goal.id), Guide.tint(goal.id).opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(L(goal.title)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(L(goal.line)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text("\(ways) \(L(ways == 1 ? "way" : "ways"))").font(HandyFont.micro).foregroundStyle(HandyColor.accent)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(HandySpacing.s12)
        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous)
            .stroke(highlighted ? HandyColor.accent : HandyColor.border, lineWidth: highlighted ? 1.5 : 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(L(goal.title)). \(L(goal.line)). \(ways) \(L(ways == 1 ? "way" : "ways"))"))
    }
}

/// Step 2: the few ways to do the chosen job, best first, each with a preview from the person's own photo.
private struct GoalScreen: View {
    let goal: Guide.Goal
    let options: [Guide.Option]
    let kind: ChainKind
    let count: Int
    @ObservedObject var previews: GuidePreviews
    let open: (Guide.Option) -> Void
    @State private var showAll = false

    private var visible: [Guide.Option] { showAll ? options : Array(options.prefix(3)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                GuideSteps(step: 2)
                Text(L(goal.title)).font(HandyFont.title)
                Text(L(options.count == 1 ? "Here's the way to do it. Tap it to start." : "Pick one. Each shows what you'll get.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                ForEach(visible) { o in
                    Button { open(o) } label: {
                        OptionRow(option: o, kind: kind, count: count, preview: previews.image(o), snippet: previews.snippet(o))
                            .cardStyle(padding: HandySpacing.s12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("guide-\(o.id)")
                }
                if options.count > 3, !showAll {
                    Button { showAll = true; previews.make(options, kind: kind) } label: {
                        Label("\(L("More ways")) (\(options.count - 3))", systemImage: "chevron.down").frame(maxWidth: .infinity)
                    }.secondaryButton().accessibilityIdentifier("guide-more")
                }
            }
            .padding(HandySpacing.gutter)
        }
        .background(Ground())
        .navigationTitle(L(goal.title)).navigationBarTitleDisplayMode(.inline)
        .onAppear { previews.make(visible, kind: kind) }
    }
}

/// One way to do the job: a picture of the result (or its icon), a plain name, and what you get. Never cut off.
struct OptionRow: View {
    let option: Guide.Option
    let kind: ChainKind
    let count: Int
    var preview: UIImage? = nil
    var snippet: String? = nil
    var big = false

    private var side: CGFloat { big ? 72 : 60 }

    var body: some View {
        HStack(alignment: .top, spacing: HandySpacing.s12) {
            ZStack {
                if let preview {
                    // No badge laid over the picture: a badge overlaid on this preview made iOS's screen reading
                    // (VoiceOver, Voice Control, tests) recurse until the app ran out of stack — your 20 Nov crash
                    // after picking several photos. Proven on the test machine: with the overlay it closes, without it it doesn't.
                    Image(uiImage: preview).resizable().scaledToFill().frame(width: side, height: side).clipped().contentShape(Rectangle()).accessibilityHidden(true)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    badge(side)
                }
            }
            .frame(width: side, height: side)
            VStack(alignment: .leading, spacing: 3) {
                Text(Guide.title(option, count: count, kind: kind)).font(big ? HandyFont.cardTitle : HandyFont.bodyStrong)
                    .foregroundStyle(HandyColor.textPrimary).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L(Guide.gets(option, kind: kind))).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                if let snippet, !snippet.isEmpty {
                    Text("\u{201C}\(snippet)\u{201D}").font(HandyFont.micro).foregroundStyle(HandyColor.accent).lineLimit(2)
                }
                if case .chain(let c) = option, c.steps.count > 1 {
                    Text(c.steps.map { L($0.block.title) }.joined(separator: " → ")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(HandyColor.textSecondary).padding(.top, 4)
        }
        .contentShape(Rectangle())
        // One plain label, read out as a single button. Combining this row's children (a photo preview with a
        // badge laid over it) made iOS's screen reading recurse until the app ran out of stack — your 20 Nov
        // crash after picking several photos, whenever anything read the screen (VoiceOver, Voice Control, tests).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var accessibilityText: String {
        var parts = [Guide.title(option, count: count, kind: kind), L(Guide.gets(option, kind: kind))]
        if let snippet, !snippet.isEmpty { parts.append(snippet) }
        return parts.joined(separator: ". ")
    }

    @ViewBuilder private func badge(_ size: CGFloat) -> some View {
        switch option {
        case .chain(let c): BlockBadge(block: Guide.keyBlock(c, kind: kind), size: size)
        case .tool(let id):
            let t = TOOLS.first { $0.id == id }
            Image(systemName: t?.icon ?? "wrench.and.screwdriver.fill")
                .font(.system(size: size * 0.46, weight: .semibold)).foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(LinearGradient(colors: [HandyColor.accent, HandyColor.accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
                .accessibilityHidden(true)
        case .voices:
            Text("🐿️").font(.system(size: size * 0.5)).frame(width: size, height: size)
                .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        }
    }
}

/// Small previews of each choice, made from the person's own photo on a small copy, one at a time (light on battery).
@MainActor final class GuidePreviews: ObservableObject {
    @Published private(set) var thumbs: [UIImage] = []
    @Published private var images: [String: UIImage] = [:]
    @Published private var texts: [String: String] = [:]
    private var asked = Set<String>()
    private var queue: [Guide.Option] = []
    private var running = false
    private var small: UIImage?

    func image(_ o: Guide.Option) -> UIImage? { images[o.id] }
    func snippet(_ o: Guide.Option) -> String? { texts[o.id] }

    func prepare(photos: [UIImage]) {
        guard thumbs.isEmpty, !photos.isEmpty else { return }
        thumbs = photos.prefix(4).map { $0.resized(maxDimension: 240) }
        small = photos.first?.resized(maxDimension: 480)
    }

    func make(_ options: [Guide.Option], kind: ChainKind) {
        guard kind == .image, small != nil else { return }
        for o in options where !asked.contains(o.id) { asked.insert(o.id); queue.append(o) }
        guard !running else { return }
        running = true
        Task { await drain() }
    }

    private func drain() async {
        while !queue.isEmpty {
            let o = queue.removeFirst()
            guard let img = small else { break }
            switch o {
            case .tool(let id): if let p = await toolPreview(id, img) { images[o.id] = p }
            case .chain(let c) where Guide.previewable(c):
                if case .success(let out) = await ChainRunner.run(c, input: .image(img), dryRun: true) {
                    switch out {
                    case .text(let t):
                        let line = t.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
                        texts[o.id] = String(line.prefix(70))
                    default: if let p = ToolHandoff.image(out) { images[o.id] = p }
                    }
                }
            default: break
            }
        }
        running = false
    }

    private func toolPreview(_ id: String, _ img: UIImage) async -> UIImage? {
        switch id {
        case "comicstrip": return await Task.detached(priority: .utility) { ChainFun.art(img, style: "comic", long: 480) }.value
        case "sticker", "faceemoji":
            let c = Chain(id: "preview-\(id)", name: "", steps: [ChainStep(block: id == "sticker" ? .sticker : .emojiFaces)])
            if case .success(let out) = await ChainRunner.run(c, input: .image(img), dryRun: true) { return ToolHandoff.image(out) }
            return nil
        case "collage", "animate":
            guard thumbs.count > 1 else { return nil }
            return Guide.mosaic(thumbs)
        default: return nil
        }
    }
}

