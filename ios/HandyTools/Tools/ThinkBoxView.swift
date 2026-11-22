import SwiftUI
import PhotosUI

/// Think it through — one box for whatever is on your mind. Type, talk, paste or screenshot it; Tenzy works out
/// what you need (worries, a decision, a to-do list, a question, a message, getting ready, an idea) and answers
/// that, then takes follow-up questions in the same place. Replaces the seven separate Thinking tools.
struct ThinkSeed: Identifiable { let text: String; var id: String { text } }

struct ThinkBoxView: View {
    /// Text handed over from another screen (the day planner, Describe it): answered as soon as it opens.
    var seed = ""
    @State private var planDay: ThinkSeed?
    @StateObject private var talk = ThinkBrain.Conversation()
    @StateObject private var speech = SpeechStream()
    @State private var input = ""
    @State private var followUp = ""
    @State private var shot: PhotosPickerItem?
    @State private var reading = false
    @State private var thinking = false
    @State private var errorText: String?
    @State private var added: String?
    @State private var broken: [String: [ThinkBrain.Step]] = [:]   // a step's smaller steps, once asked for
    @State private var breaking: String?
    @State private var tone: String?                                 // which version of a message is showing
    @State private var boards: [Int: [ThinkBrain.Option]] = [:]      // a decision's options as the person weighs them
    @State private var adding: [String: String] = [:]                // a pro or con being typed, per option
    @State private var history: [ThinkHistory.Saved] = []
    @State private var focus: [ThinkBrain.Step]?
    @AppStorage("think.detail") private var detailRaw = ThinkBrain.Detail.balanced.rawValue
    private var detail: ThinkBrain.Detail { ThinkBrain.Detail(rawValue: detailRaw) ?? .balanced }
    @FocusState private var focused: Bool

    private var trimmed: String { input.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ToolPage(title: "Think it through", subtitle: "Whatever's on your mind — worries, a decision, a to-do list, a question. Tenzy works out what you need.", working: thinking || reading) {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                if talk.turns.isEmpty {
                    inputCard
                    if !history.isEmpty, !thinking { historyCard }
                } else { askedCard }
                if thinking && talk.turns.isEmpty { ToolProgressBar(label: "Thinking it through…", showsTime: false) }
                ForEach(Array(talk.turns.enumerated()), id: \.offset) { i, turn in
                    if i > 0 { Text("“\(turn.asked)”").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textSecondary).padding(.top, HandySpacing.s8) }
                    answerView(turn.answer, index: i, latest: i == talk.turns.count - 1)
                }
                if !talk.turns.isEmpty { followUpCard }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .onChange(of: speech.transcript) { _, t in if speech.running, !t.isEmpty { input = t } }
        .onChange(of: shot) { _, item in readShot(item) }
        .onDisappear { speech.stop() }
        .onAppear {
            // Screenshots and UI tests: a typical worried list, so the page shows the answer, not an empty box.
            let start = seed.isEmpty && Launch.sample && Launch.route == "thinking" ? "overwhelmed, money, credit card debt, work deadline Friday, can't sleep" : seed
            if !start.isEmpty, talk.turns.isEmpty, !thinking { input = start; ask(start) }
        }
        .sheet(item: $planDay) { s in UntangleView(seed: s.text) }
        .sheet(isPresented: Binding(get: { focus != nil }, set: { if !$0 { focus = nil } })) { FocusRunView(steps: focus ?? []) }
        .onAppear { history = ThinkHistory.load(); talk.detail = detail }
        .onChange(of: detailRaw) { _, _ in talk.detail = detail }
    }

    // MARK: - Asking

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            TextEditor(text: $input).focused($focused)
                .frame(minHeight: 140).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(focused || speech.running ? HandyColor.accent : HandyColor.border, lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if input.isEmpty {
                        Text(L("Say it however it comes out — \"money, debts, overwhelmed\", \"should I take the new job?\", \"call mum, pay rent, book dentist\""))
                            .foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier("think-input")
            HandyFlow(spacing: HandySpacing.s8) {
                    Button { speech.running ? speech.stop() : speech.start() } label: {
                        Label(speech.running ? L("Stop") : L("Talk"), systemImage: speech.running ? "stop.circle.fill" : "mic.fill")
                    }.compactButton()
                    PhotosPicker(selection: $shot, matching: .images) { Label(L("Screenshot"), systemImage: "text.viewfinder") }.compactButton()
                    PasteTextButton { s in input = input.isEmpty ? s : input + "\n" + s }
                    if !input.isEmpty { Button(L("Clear")) { input = "" }.textButton() }
                }
            if speech.running { Text(L("Listening… say it the way you'd tell a friend.")).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
            if reading { ToolProgressBar(label: "Reading your screenshot…", showsTime: false) }
            if let e = errorText ?? speech.errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            VStack(alignment: .leading, spacing: 4) {
                Text(L("How much detail in the steps")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                HStack(spacing: HandySpacing.s8) {
                    ForEach(ThinkBrain.Detail.allCases, id: \.self) { d in HChip(text: L(d.label), selected: d == detail) { detailRaw = d.rawValue } }
                }
            }
            Button { ask(trimmed) } label: { Label(L("Think it through"), systemImage: "sparkles").frame(maxWidth: .infinity) }
                .primaryButton().disabled(trimmed.isEmpty || thinking).accessibilityIdentifier("think-go")
        }
    }

    private var askedCard: some View {
        HStack(alignment: .top, spacing: HandySpacing.s8) {
            Text("“\(talk.turns.first?.asked ?? "")”").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(L("New")) { talk.reset(); input = ""; followUp = ""; added = nil; broken = [:]; tone = nil; boards = [:]; history = ThinkHistory.load() }.textButton()
        }
    }

    private var followUpCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(spacing: HandySpacing.s8) {
                TextField(L("Ask a follow-up…"), text: $followUp, axis: .vertical).lineLimit(1...4)
                    .padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .submitLabel(.send).onSubmit { askFollowUp() }
                    .accessibilityIdentifier("think-followup")
                Button { askFollowUp() } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)) }
                    .disabled(followUp.trimmingCharacters(in: .whitespaces).isEmpty || thinking)
                    .accessibilityLabel(L("Ask"))
            }
            if thinking { ToolProgressBar(label: "Thinking it through…", showsTime: false) }
        }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Text(L("Earlier")).font(HandyFont.bodyStrong)
                Spacer()
                Button(L("Clear")) { ThinkHistory.clear(); history = [] }.textButton()
            }
            ForEach(history.prefix(5)) { h in
                Button { talk.restore(h); boards = [:]; broken = [:] } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(h.headline).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary).lineLimit(1)
                        Text("“\(h.title)” · \(h.date.formatted(date: .abbreviated, time: .shortened))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
            }
            Text(L("Kept on this phone only.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }.cardStyle(padding: HandySpacing.s16)
    }

    // MARK: - The answer

    @ViewBuilder private func answerView(_ a: ThinkBrain.Answer, index: Int, latest: Bool) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if let s = a.support { supportCard(s) }
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Label(L(a.kind.label), systemImage: a.kind.icon).font(HandyFont.micro).foregroundStyle(HandyColor.accent)
                Text(a.headline).font(HandyFont.title).fixedSize(horizontal: false, vertical: true)
                Text(a.understood).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                if let t = a.tone, a.support == nil {
                    Label("\(L("You sound")) \(L(t)) — \(L(Self.toneNote(t)))", systemImage: "waveform").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s16)
            .accessibilityElement(children: .combine).accessibilityIdentifier("think-answer")

            // A decision or a worry gets the bottom line straight away, before the reasons.
            if Self.bottomLineFirst(a.kind) { recommendationCard(a) }

            if !a.rewrite.isEmpty {
                let versions = [ThinkBrain.Variant(label: a.kind == .judge ? "Suggested reply" : (a.kind == .decision ? "A reply you could send" : "Best fit"), text: a.rewrite)] + a.variants
                let shown = versions.first { $0.label == tone } ?? versions[0]
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text(L(a.kind == .judge ? "If you want to reply" : "Ready to send")).font(HandyFont.bodyStrong)
                    if versions.count > 1 {
                        HandyFlow(spacing: HandySpacing.s8) {
                                ForEach(versions) { v in HChip(text: L(v.label), selected: v.label == shown.label) { tone = v.label } }
                            }
                    }
                    Text(shown.text).font(HandyFont.body).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("think-message")
                    HStack {
                        Button { UIPasteboard.general.string = shown.text; HandyHaptics.success() } label: { Label(L("Copy"), systemImage: "doc.on.doc") }.compactButton()
                        ShareLink(item: shown.text) { Label(L("Send"), systemImage: "paperplane") }.compactButton()
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s16)
            }

            ForEach(a.sections) { s in
                VStack(alignment: .leading, spacing: 6) {
                    Text(s.title).font(HandyFont.bodyStrong)
                    ForEach(s.bullets, id: \.self) { b in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(HandyColor.accent).frame(width: 5, height: 5).offset(y: -3)
                            Text(b).font(HandyFont.body).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s16)
            }

            if !a.options.isEmpty { decisionBoard(index: index, start: a.options) }

            if !a.steps.isEmpty {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text(L(a.kind == .tasks ? "Your list" : "Small first steps")).font(HandyFont.bodyStrong)
                    if let total = Self.totalMinutes(a.steps) {
                        Text("\(L("About")) \(Self.duration(total)) \(L("in all")) · \(L("done by")) \(Date().addingTimeInterval(Double(total) * 60).formatted(date: .omitted, time: .shortened)) \(L("if you start now"))")
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                    ForEach(Array(a.steps.enumerated()), id: \.offset) { i, s in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(i + 1)").font(HandyFont.caption.weight(.bold)).foregroundStyle(HandyColor.onAccent)
                                    .frame(width: 22, height: 22).background(HandyColor.accent, in: Circle())
                                Text(s.text).font(HandyFont.body).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                if let m = s.minutes { Text("\(m) \(L("min"))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                            }
                            if let small = broken[s.text] {
                                ForEach(small) { b in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Image(systemName: "circle").font(.caption2).foregroundStyle(HandyColor.accent)
                                        Text(b.text).font(HandyFont.caption).fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 4)
                                        if let m = b.minutes { Text("\(m) \(L("min"))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
                                    }.padding(.leading, 32)
                                }
                            } else if latest {
                                Button { breakDown(s) } label: {
                                    if breaking == s.text { ProgressView().controlSize(.mini) }
                                    else { Label(L("Too big? Break it down"), systemImage: "arrow.down.right.and.arrow.up.left").font(HandyFont.caption) }
                                }.textButton().padding(.leading, 32).disabled(breaking != nil)
                            }
                        }
                    }
                    if latest {
                        Button { focus = a.steps.flatMap { broken[$0.text] ?? [$0] } } label: {
                            Label(L("Start — one step at a time"), systemImage: "play.fill").frame(maxWidth: .infinity)
                        }.primaryButton().accessibilityIdentifier("think-focus")
                    }
                    if latest, a.kind == .tasks {
                        Button { planDay = ThinkSeed(text: a.steps.map(\.text).joined(separator: "\n")) } label: {
                            Label(L("Time these out for today"), systemImage: "clock").frame(maxWidth: .infinity)
                        }.secondaryButton()
                    }
                    if latest {
                        Button { addSteps(a.steps) } label: { Label(L("Add these to Reminders"), systemImage: "checklist").frame(maxWidth: .infinity) }.secondaryButton()
                        if let added { Text(L(added)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s16)
            }

            if !Self.bottomLineFirst(a.kind) { recommendationCard(a) }

            if latest, a.engine != .builtIn, a.support == nil {
                HandyFlow(spacing: HandySpacing.s8) {
                        ForEach(Self.refinements, id: \.label) { r in HChip(text: L(r.label), selected: false) { ask(r.prompt) } }
                    }
            }

            if latest, !a.followUps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Ask next")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    ForEach(a.followUps, id: \.self) { q in
                        Button { ask(q) } label: {
                            HStack(spacing: 8) {
                                Text(q).font(HandyFont.body).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                Image(systemName: "arrow.up.right").font(.caption)
                            }
                            .foregroundStyle(HandyColor.accent)
                            .padding(.horizontal, HandySpacing.s12).padding(.vertical, 10)
                            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        }.buttonStyle(.plain).disabled(thinking)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let c = a.caution { Text(L(c)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                Text(L(a.engine.note)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            if latest {
                ShareLink(item: Self.plain(a)) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            }
        }
    }

    /// Kinds where the answer leads with what to do; a message or a judged message leads with the text itself.
    static func bottomLineFirst(_ k: ThinkBrain.Kind) -> Bool { [.decision, .worry, .idea, .prep].contains(k) }

    @ViewBuilder private func recommendationCard(_ a: ThinkBrain.Answer) -> some View {
        if !a.recommendation.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label(L("What I'd do"), systemImage: "hand.thumbsup").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent)
                Text(a.recommendation).font(HandyFont.body).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HandySpacing.s16)
            .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
            .accessibilityIdentifier("think-bottom-line")
        }
    }

    private func supportCard(_ s: ThinkBrain.Support) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Talk to someone now"), systemImage: "phone.fill").font(HandyFont.bodyStrong)
            Text(L(s.line)).font(HandyFont.body)
            HStack(spacing: HandySpacing.s8) {
                if let c = s.call, let u = URL(string: "tel:\(c)") { Link(destination: u) { Label(L("Call"), systemImage: "phone") }.compactButton() }
                if let t = s.text, let u = URL(string: "sms:\(t)") { Link(destination: u) { Label(L("Text"), systemImage: "message") }.compactButton() }
                if let u = URL(string: s.web) { Link(destination: u) { Label(L("Website"), systemImage: "safari") }.compactButton() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(HandySpacing.s16)
        .background(HandyColor.warningSoft, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
    }

    // MARK: - Actions

    private func ask(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !thinking else { return }
        speech.stop(); focused = false; errorText = nil; added = nil
        thinking = true
        Task { await talk.ask(t); thinking = false; tone = nil; HandyHaptics.success() }
    }

    // MARK: - Decision board

    @ViewBuilder private func decisionBoard(index: Int, start: [ThinkBrain.Option]) -> some View {
        let options = boards[index] ?? start
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if let lean = ThinkBrain.lean(options) {
                Label("\(L("Leaning")): \(lean.0.name) (+\(lean.1))", systemImage: "scalemass").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent)
            } else {
                Label(L("Even so far — tap a reason to make it matter more, or add your own"), systemImage: "scalemass").font(HandyFont.bodyStrong)
            }
            ForEach(Array(options.enumerated()), id: \.offset) { oi, o in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(o.name).font(HandyFont.bodyStrong)
                        Spacer()
                        Text(o.score > 0 ? "+\(o.score)" : "\(o.score)").font(HandyFont.caption.weight(.bold))
                            .foregroundStyle(o.score >= 0 ? HandyColor.success : HandyColor.danger)
                    }
                    ForEach(Array(o.pros.enumerated()), id: \.offset) { pi, p in pointRow(p, pro: true) { weigh(index, start, oi, pro: true, pi) } }
                    ForEach(Array(o.cons.enumerated()), id: \.offset) { ci, c in pointRow(c, pro: false) { weigh(index, start, oi, pro: false, ci) } }
                    HStack(spacing: 6) {
                        TextField(L("Add your own reason…"), text: Binding(get: { adding[o.name] ?? "" }, set: { adding[o.name] = $0 }))
                            .font(HandyFont.caption).padding(8)
                            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.small, style: .continuous))
                        Button(L("Pro")) { addPoint(index, start, oi, pro: true) }.compactButton()
                        Button(L("Con")) { addPoint(index, start, oi, pro: false) }.compactButton()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
            }
            Text(L("Dots show how much each reason matters — tap to change it.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("think-decision")
    }

    private func pointRow(_ p: ThinkBrain.Point, pro: Bool, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: pro ? "plus.circle.fill" : "minus.circle.fill").foregroundStyle(pro ? HandyColor.success : HandyColor.danger)
                Text(p.text).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                HStack(spacing: 3) { ForEach(1...3, id: \.self) { i in Circle().fill(i <= p.weight ? HandyColor.accent : HandyColor.border).frame(width: 7, height: 7) } }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pro ? L("Pro") : L("Con")): \(p.text), \(L("matters")) \(p.weight) \(L("of 3"))")
    }

    private func weigh(_ index: Int, _ start: [ThinkBrain.Option], _ oi: Int, pro: Bool, _ pi: Int) {
        var o = boards[index] ?? start
        if pro { o[oi].pros[pi].weight = o[oi].pros[pi].weight % 3 + 1 } else { o[oi].cons[pi].weight = o[oi].cons[pi].weight % 3 + 1 }
        boards[index] = o; HandyHaptics.light()
    }

    private func addPoint(_ index: Int, _ start: [ThinkBrain.Option], _ oi: Int, pro: Bool) {
        var o = boards[index] ?? start
        let text = (adding[o[oi].name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let p = ThinkBrain.Point(text: text, weight: 2)
        if pro { o[oi].pros.append(p) } else { o[oi].cons.append(p) }
        adding[o[oi].name] = ""; boards[index] = o
    }

    private func breakDown(_ s: ThinkBrain.Step) {
        breaking = s.text
        Task { broken[s.text] = await talk.breakDown(s); breaking = nil }
    }

    /// One tap to reshape the last answer.
    struct Refine: Hashable { let label: String; let prompt: String }
    static let refinements = [
        Refine(label: "Simpler", prompt: "Say that again more simply, in fewer words."),
        Refine(label: "More detail", prompt: "Go deeper on that — more specific detail."),
        Refine(label: "Another angle", prompt: "Look at it from a different angle."),
        Refine(label: "Gentler", prompt: "Say that more gently."),
    ]

    static func toneNote(_ t: String) -> String {
        switch t {
        case "stressed": return "kept this calm and short."
        case "in a hurry": return "straight to the point."
        case "frustrated": return "kept this steady and practical."
        case "excited": return "let's make the most of it."
        default: return "answered to match."
        }
    }

    static func totalMinutes(_ steps: [ThinkBrain.Step]) -> Int? {
        let m = steps.compactMap(\.minutes)
        return m.count == steps.count && !m.isEmpty ? m.reduce(0, +) : nil
    }

    static func duration(_ m: Int) -> String { m < 60 ? "\(m) min" : (m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) min") }

    private func askFollowUp() { let q = followUp; followUp = ""; ask(q) }

    private func addSteps(_ steps: [ThinkBrain.Step]) {
        let tasks = steps.map { ThinkingEngine.Task(text: $0.text, actions: ThinkingActions.plan(for: $0.text), due: nil) }
        Task {
            do { let n = try await ThinkingReminders.add(tasks); added = "Added \(n) to Reminders." }
            catch { added = "Tenzy isn't allowed to add reminders. Turn it on in Settings › Apps › Tenzy › Reminders." }
        }
    }

    private func readShot(_ item: PhotosPickerItem?) {
        guard let item else { return }
        reading = true; errorText = nil
        Task {
            var text = ""
            if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { text = await AIEngine.recognizeText(img) }
            reading = false; shot = nil
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errorText = "Couldn't read any text in that picture — try a clearer screenshot." }
            else { input = input.isEmpty ? text : input + "\n" + text }
        }
    }

    /// The answer as plain text, to share or keep.
    static func plain(_ a: ThinkBrain.Answer) -> String {
        var out = [a.headline, a.understood, ""]
        if !a.rewrite.isEmpty { out += [a.rewrite, ""] }
        for s in a.sections { out.append(s.title); out += s.bullets.map { "• \($0)" }; out.append("") }
        if !a.steps.isEmpty { out.append("Next steps"); out += a.steps.enumerated().map { "\($0.offset + 1). \($0.element.text)" }; out.append("") }
        for o in a.options {
            out.append("\(o.name) (\(o.score >= 0 ? "+" : "")\(o.score))")
            out += o.pros.map { "  + \($0.text)" } + o.cons.map { "  − \($0.text)" }
        }
        if !a.options.isEmpty { out.append("") }
        if !a.recommendation.isEmpty { out += ["What I'd do: \(a.recommendation)"] }
        return out.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
