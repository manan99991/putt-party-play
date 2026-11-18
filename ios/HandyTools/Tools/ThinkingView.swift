import SwiftUI

/// The seven Thinking tools, as one hub tool in the catalog. Clear My Head and My Day run with no model
/// (so they work on every phone); Untangle, Crossroads, Plain, Reword and Prep use Apple's on-device model
/// with a clean fallback. Each result that produces tasks shows the apps each task can flow into (Maps /
/// call now; Reminders + Calendar writes land next). Shell unchanged — this is one more entry under Tools.
enum ThinkingTool: String, CaseIterable, Identifiable {
    case untangle, myday, clearhead, crossroads, plain, reword, prep
    var id: String { rawValue }

    var title: String {
        switch self {
        case .untangle: return "Untangle"
        case .myday: return "My Day"
        case .clearhead: return "Clear My Head"
        case .crossroads: return "Crossroads"
        case .plain: return "Plain"
        case .reword: return "Reword"
        case .prep: return "Prep"
        }
    }
    var icon: String {
        switch self {
        case .untangle: return "scribble.variable"
        case .myday: return "sun.max"
        case .clearhead: return "brain.head.profile"
        case .crossroads: return "arrow.triangle.branch"
        case .plain: return "lightbulb"
        case .reword: return "pencil.and.outline"
        case .prep: return "checklist"
        }
    }
    var blurb: String {
        switch self {
        case .untangle: return "Everything on your plate → a plan built around how you feel, with maps, check-ins and Reminders."
        case .myday: return "Everything today → a realistic timeline."
        case .clearhead: return "Dump it all out → sorted, deduped tasks with dates found."
        case .crossroads: return "A decision → pros, cons and a clear recommendation."
        case .plain: return "Explain anything in plain words, at the level you want."
        case .reword: return "Say it in the right tone, ready to send."
        case .prep: return "Get ready for anything → a checklist and what to ask."
        }
    }
    var placeholder: String {
        switch self {
        case .untangle: return "What's the big task that feels like too much?"
        case .myday: return "List everything on your plate today…"
        case .clearhead: return "Dump everything that's swirling — one line each, or just a run-on…"
        case .crossroads: return "What's the decision? e.g. Should I switch to a 4-day week?"
        case .plain: return "Paste the thing to explain, or ask a question…"
        case .reword: return "Paste your message…"
        case .prep: return "What are you getting ready for? e.g. a dentist visit"
        }
    }
    var sample: String {
        switch self {
        case .untangle: return "Plan my daughter's 5th birthday party"
        case .myday: return "gym, finish the deck, pick up Deeyan at 3pm, groceries, call the dentist"
        case .clearhead: return "call vendor, buy milk, finish deck, email Ana the budget by Thursday, buy milk, book flights"
        case .crossroads: return "Should I switch to a 4-day work week?"
        case .plain: return "What is a mutual fund?"
        case .reword: return "hey i cant make the 2pm thursday meeting move it"
        case .prep: return "a first visit to a new dentist"
        }
    }
    /// Structuring tools need no model; the rest reason with it.
    var usesModel: Bool { mind != nil }
    var mind: ThinkingMind.Tool? {
        switch self {
        case .untangle: return .untangle
        case .crossroads: return .crossroads
        case .plain: return .plain
        case .reword: return .reword
        case .prep: return .prep
        case .myday, .clearhead: return nil
        }
    }
}

/// The hub: a grid of the seven, each opening its own screen.
struct ThinkingHubView: View {
    @State private var selected: ThinkingTool?
    private let cols = [GridItem(.flexible(), spacing: HandySpacing.s12), GridItem(.flexible(), spacing: HandySpacing.s12)]

    var body: some View {
        ToolPage(title: "Thinking tools", subtitle: "Private, on-device help that doesn't just answer — it turns the result into action on your phone.", working: false) {
            HowTo("thinking", [
                "Pick a tool, type or paste what's on your mind, and run it.",
                "Clear My Head and My Day work on every phone; the rest use Apple Intelligence where you have it.",
                "Nothing leaves your phone.",
            ])
            LazyVGrid(columns: cols, spacing: HandySpacing.s12) {
                ForEach(ThinkingTool.allCases) { t in
                    Button { selected = t } label: {
                        VStack(alignment: .leading, spacing: HandySpacing.s8) {
                            Image(systemName: t.icon).font(.system(size: 22)).foregroundStyle(HandyColor.accent).frame(height: 26)
                            Text(t.title).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                            Text(t.blurb).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading).lineLimit(3, reservesSpace: true)
                        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle()
                    }.buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $selected) { t in
            if t == .untangle { UntangleView() } else { ThinkingToolView(tool: t) }
        }
    }
}

/// One shared screen for every thinking tool: input → run → result (a task list, or model text) → actions.
struct ThinkingToolView: View {
    let tool: ThinkingTool
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var tasks: [ThinkingEngine.Task] = []
    @State private var calendarICS: URL?
    @State private var output = ""
    @State private var note = ""
    @State private var working = false
    @State private var errorText: String?
    @State private var level = "adult"
    @State private var tone = "warmer"
    @FocusState private var focused: Bool

    private var trimmed: String { input.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var overQuota: Bool { !Usage.hasRoom("ai", limit: Limits.freeAiPerDay) }

    var body: some View {
        NavigationStack {
            ToolPage(title: tool.title, subtitle: tool.blurb, working: working) {
                VStack(spacing: HandySpacing.s8) {
                    TextEditor(text: $input).focused($focused)
                        .frame(minHeight: 120).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(focused ? HandyColor.accent : HandyColor.border, lineWidth: 1))
                        .overlay(alignment: .topLeading) { if input.isEmpty { Text(tool.placeholder).foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) } }
                    HStack {
                        Button(L("Paste")) { if let s = UIPasteboard.general.string { input = s } }.compactButton()
                        if !input.isEmpty { Button(L("Clear")) { input = ""; reset() }.textButton() }
                        Spacer()
                    }
                }

                if tool == .plain {
                    HandyFlow(spacing: HandySpacing.s8) {
                        ForEach(["kid", "teen", "adult", "expert"], id: \.self) { l in
                            HChip(text: levelLabel(l), selected: level == l) { level = l }
                        }
                    }
                }
                if tool == .reword {
                    HandyFlow(spacing: HandySpacing.s8) {
                        ForEach(["warmer", "formal", "shorter", "firmer"], id: \.self) { t in
                            HChip(text: toneLabel(t), selected: tone == t) { tone = t }
                        }
                    }
                }

                if tool.usesModel && !AIEngine.isAvailable {
                    LimitNote("\(tool.title) needs Apple Intelligence (iPhone 15 Pro or newer, Apple Intelligence on). Clear My Head and My Day work on every phone.")
                } else {
                    if tool.usesModel && !store.isPremium { QuotaChip(name: "ai", limit: Limits.freeAiPerDay).environmentObject(store) }
                    if tool.usesModel && overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freeAiPerDay) free AI actions.") }
                    Button { run() } label: {
                        HStack { if working { ProgressView().tint(.white) }; Label(working ? "Thinking…" : "Think it through", systemImage: "sparkles") }.frame(maxWidth: .infinity)
                    }.primaryButton().disabled(working || trimmed.isEmpty || (tool.usesModel && overQuota))
                }
                if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

                if !tasks.isEmpty { taskResult }
                if !output.isEmpty { textResult }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { dismiss() } } }
            .onAppear { if Launch.sample, input.isEmpty { input = tool.sample } }
        }
    }

    // A structuring result: the tasks, each with the apps it flows into.
    private var taskResult: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            ForEach(Array(tasks.enumerated()), id: \.offset) { _, t in
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.text).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
                    HandyFlow(spacing: HandySpacing.s8) {
                        if let place = t.actions.place, let u = ThinkingActions.mapsURL(place).flatMap(URL.init) {
                            Link(destination: u) { Label(L("Directions"), systemImage: "map").font(HandyFont.micro) }.compactButton()
                        }
                        if let phone = t.actions.phone, let u = ThinkingActions.telURL(phone).flatMap(URL.init) {
                            Link(destination: u) { Label(L("Call"), systemImage: "phone").font(HandyFont.micro) }.compactButton()
                        }
                        if let phone = t.actions.phone, let u = ThinkingActions.smsURL(phone).flatMap(URL.init) {
                            Link(destination: u) { Label(L("Text"), systemImage: "message").font(HandyFont.micro) }.compactButton()
                        }
                        if let email = ThinkingActions.emailIn(t.text), let u = ThinkingActions.mailtoURL(email).flatMap(URL.init) {
                            Link(destination: u) { Label(L("Email"), systemImage: "envelope").font(HandyFont.micro) }.compactButton()
                        }
                        if let contact = ThinkingContacts.field(for: t) {
                            Button {
                                Task { @MainActor in
                                    do {
                                        try await ThinkingContacts.add(contact)
                                        note = "Saved \(contact.name) to Contacts."; HandyHaptics.success()
                                    } catch ThinkingContacts.AddError.denied {
                                        errorText = "Contacts access is off. Turn it on in Settings › Tenzy and tap again."
                                    } catch {
                                        errorText = "Couldn't save the contact."
                                    }
                                }
                            } label: { Label(L("Save contact"), systemImage: "person.crop.circle.badge.plus").font(HandyFont.micro) }.compactButton()
                        }
                        if t.due != nil { Label(L("has a date"), systemImage: "calendar").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
                    }
                }.padding(.vertical, 2)
                if t.text != tasks.last?.text { Divider() }
            }
            if !note.isEmpty { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            HStack(spacing: HandySpacing.s8) {
                Button { Copier.copy(plainList); ClipStore.add(plainList) } label: { Label(L("Copy"), systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.primaryButton()
                ShareLink(item: plainList) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if !tasks.isEmpty {
                Button {
                    let items = tasks
                    Task { @MainActor in
                        do {
                            let n = try await ThinkingReminders.add(items)
                            note = "Added \(n) to Reminders."; HandyHaptics.success()
                        } catch ThinkingReminders.AddError.denied {
                            errorText = "Reminders access is off. Turn it on in Settings › Tenzy and tap again."
                        } catch {
                            errorText = "Couldn't add to Reminders — your dates are still here to add to Calendar."
                        }
                    }
                } label: { Label(L("Add to Reminders"), systemImage: "checklist").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if let calendarICS {
                ShareLink(item: calendarICS) { Label(L("Add dates to Calendar"), systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }.secondaryButton()
                Text(L("First time, your phone asks once; after that it's a silent one-tap.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }.cardStyle()
    }

    private var textResult: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(output).font(HandyFont.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            if !note.isEmpty { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            HStack(spacing: HandySpacing.s8) {
                Button { Copier.copy(output); ClipStore.add(output) } label: { Label(L("Copy"), systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.primaryButton()
                ShareLink(item: output) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            }
        }.cardStyle()
    }

    private var plainList: String {
        tasks.isEmpty ? output : tasks.map { "• " + $0.text }.joined(separator: "\n")
    }

    private func reset() { tasks = []; calendarICS = nil; output = ""; note = ""; errorText = nil }

    /// Adaptive summary: deadlines named plainly, soft tasks nudged, the trivial left quiet — the behaviour
    /// the thinking tools were asked for, so the list guides without nagging.
    static func adaptiveNote(_ tasks: [ThinkingEngine.Task]) -> String {
        if tasks.isEmpty { return "" }
        let deadlines = tasks.filter { ThinkingEngine.urgency(for: $0) == .deadline }.count
        let nudges = tasks.filter { ThinkingEngine.urgency(for: $0) == .nudge }.count
        let quiet = tasks.count - deadlines - nudges
        var parts: [String] = []
        if deadlines > 0 { parts.append("\(deadlines) with a deadline") }
        if nudges > 0 { parts.append("\(nudges) to get to") }
        if quiet > 0 { parts.append("\(quiet) can wait") }
        return parts.isEmpty ? "\(tasks.count) task\(tasks.count == 1 ? "" : "s")" : parts.joined(separator: " · ")
    }

    /// Bundle every dated task into one .ics written to a temp file, so "Add to Calendar" adds the plan.
    private func buildCalendarICS() {
        let dated = tasks.compactMap { t in t.due.map { (title: t.text, due: $0, place: t.actions.place ?? "") } }
        guard !dated.isEmpty else { calendarICS = nil; return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tenzy-plan-\(UUID().uuidString).ics")
        try? ThinkingActions.icsCalendar(dated).data(using: .utf8)?.write(to: url)
        calendarICS = url
    }

    private func run() {
        focused = false; reset(); working = true
        let text = input, t = tool, lvl = level, tn = tone
        Task { @MainActor in
            defer { working = false }
            switch t {
            case .clearhead:
                tasks = ThinkingEngine.clearMyHead(text)
                note = Self.adaptiveNote(tasks)
                if tasks.isEmpty { errorText = "Nothing to sort yet — type a few things first." } else { HandyHaptics.success() }
                buildCalendarICS()
            case .myday:
                tasks = ThinkingEngine.myDay(text)
                note = Self.adaptiveNote(tasks)
                if tasks.isEmpty { errorText = "Nothing to lay out yet." } else { HandyHaptics.success() }
                buildCalendarICS()
            default:
                guard let mind = t.mind else { return }
                guard AIEngine.isAvailable else { errorText = "\(t.title) needs Apple Intelligence on this phone."; return }
                guard Usage.hasRoom("ai", limit: Limits.freeAiPerDay) else { errorText = "Out of today's free AI runs."; return }
                do {
                    let opts = ["level": lvl, "tone": tn]
                    output = try await ThinkingMind.think(mind, input: text, options: opts).trimmingCharacters(in: .whitespacesAndNewlines)
                    _ = Usage.use("ai", limit: Limits.freeAiPerDay)
                    if output.isEmpty { errorText = "The model didn't return anything — try rephrasing." } else { HandyHaptics.success() }
                } catch {
                    errorText = "On-device AI was busy — try again in a moment."
                }
            }
        }
    }

    private func levelLabel(_ l: String) -> String {
        ["kid": "Explain simply", "teen": "For a teen", "adult": "Curious adult", "expert": "Expert"][l] ?? l
    }
    private func toneLabel(_ t: String) -> String {
        ["warmer": "Warmer", "formal": "Formal", "shorter": "Shorter", "firmer": "Firmer"][t] ?? t
    }
}
