import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// The one Thinking box. A person types (or says, pastes, screenshots) whatever is on their mind; Tenzy first
/// works out what they actually need — worries, a decision, things to do, a question, a message to fix,
/// something to get ready for, an idea — and answers THAT, instead of chopping their words into a timetable.
///
/// Three engines, best first: Apple's Private Cloud Compute model (when the app holds the entitlement and the
/// phone supports it — built only with the TENZY_PCC flag), Apple's on-device model, and a built-in reader that
/// needs no model so every phone still gets a real, specific answer. The built-in parts are pure and unit-tested.
enum ThinkBrain {

    enum Kind: String, CaseIterable, Equatable {
        case worry, decision, tasks, question, message, prep, idea
        var label: String {
            switch self {
            case .worry: return "Something weighing on you"
            case .decision: return "A decision"
            case .tasks: return "Things to get done"
            case .question: return "A question"
            case .message: return "A message to get right"
            case .prep: return "Getting ready"
            case .idea: return "An idea to shape"
            }
        }
        var icon: String {
            switch self {
            case .worry: return "heart.text.square"
            case .decision: return "arrow.triangle.branch"
            case .tasks: return "checklist"
            case .question: return "lightbulb"
            case .message: return "text.bubble"
            case .prep: return "bag"
            case .idea: return "sparkles"
            }
        }
    }

    enum Engine: Equatable { case cloud, phone, builtIn
        var note: String {
            switch self {
            case .cloud: return "Answered by Apple's Private Cloud Compute — nothing is stored or seen by anyone."
            case .phone: return "Answered on your iPhone. Nothing left your phone."
            case .builtIn: return "Built-in answer. With Apple Intelligence (iPhone 15 Pro or newer) Tenzy writes a fuller one for your exact situation."
            }
        }
    }

    struct Section: Equatable, Identifiable { var id: String { title }; let title: String; let bullets: [String] }
    struct Step: Equatable, Identifiable { var id: String { text }; let text: String; let minutes: Int? }

    struct Answer: Equatable {
        var kind: Kind
        var understood: String
        var headline: String
        var sections: [Section] = []
        var steps: [Step] = []
        var recommendation: String = ""
        var rewrite: String = ""
        var followUps: [String] = []
        var caution: String?            // "General guidance, not financial advice" and the like
        var support: Support?           // crisis help, shown before anything else
        var engine: Engine = .builtIn
    }

    /// Help to reach right now, for the person's country.
    struct Support: Equatable { let line: String; let call: String?; let text: String?; let web: String }

    // MARK: - Reading what it is (no model)

    private static func has(_ t: String, _ pattern: String) -> Bool {
        t.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    private static func count(_ t: String, _ words: [String]) -> Int {
        words.reduce(0) { $0 + (has(t, #"\b"# + $1) ? 1 : 0) }
    }

    static let worryWords = ["overwhelm", "stress", "anxious", "anxiety", "worried", "worry", "scared", "afraid", "panic", "lonely",
                             "sad", "depress", "exhausted", "burn(t|ed)? ?out", "can'?t cope", "too much", "falling apart", "hopeless",
                             "debt", "losses", "lost money", "broke\\b", "bills?\\b", "behind on", "loan", "margin", "overdraft", "bankrupt",
                             "laid off", "fired", "divorce", "break ?up", "grief", "lfe\\b", "life\\b", "money", "stuck", "failing", "mess\\b"]
    static let taskVerbs = ["call", "buy", "email", "pick up", "drop off", "finish", "book", "clean", "pay", "send", "schedule", "fix",
                            "order", "return", "cook", "wash", "file", "submit", "renew", "cancel", "meet", "write", "pack", "gym", "groceries"]

    /// What the person wrote is mainly — read from the words alone. The model makes its own call; this is the
    /// answer on phones without one, and the safety net when the model fails.
    static func kind(of raw: String) -> Kind {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if has(t, #"^(please\s+)?(re-?word|rewrite|rephrase|reply to|respond to|make (this|it) (sound|more|less|shorter|nicer|polite)|fix (this|my) (message|email|text)|write (a|an|me a) (message|email|text|note|reply))"#)
            || has(t, #"^(hi|hey|hello|dear)\b.{25,}"#) { return .message }
        if has(t, #"\bshould i\b|\bor not\b|\bvs\.?\b|\bversus\b|which (one|is better|should)|\bdecid|\bchoose between\b|\bworth it\b|\bpros and cons\b"#) { return .decision }
        if has(t, #"(getting ready|prepare|prep for|packing for|before (my|the) (interview|appointment|trip|meeting|surgery|exam)|first day|checklist for)"#) { return .prep }
        let worry = count(t, worryWords)
        let doing = has(t, #"\b("# + taskVerbs.joined(separator: "|") + #")\b"#)
        let asking = has(t, #"\?\s*$"#) || has(t, #"^(what|why|how|when|who|where|explain|is it|are|can|does|do)\b"#)
        if asking && worry < 3 { return .question }
        if worry >= 2 || (worry == 1 && !doing) { return .worry }
        if asking { return .question }
        if has(t, #"\b(idea|brainstorm|plan (a|an|my)|start (a|an)|launch|name for)\b"#) { return .idea }
        return .tasks
    }

    /// Words that mean the person may be thinking of ending their life or hurting themselves.
    static func needsSupport(_ t: String) -> Bool {
        has(t, #"(kill(ing)? my ?self|suicid|end (it all|my life)|want to die|don'?t want to (live|be here)|no reason to live|hurt(ing)? my ?self|self[- ]?harm|better off without me)"#)
    }

    static func support(region: String?) -> Support {
        switch region {
        case "US": return Support(line: "988 Suicide & Crisis Lifeline — free, 24/7", call: "988", text: "988", web: "https://988lifeline.org")
        case "CA": return Support(line: "9-8-8 Suicide Crisis Helpline — free, 24/7", call: "988", text: "988", web: "https://988.ca")
        case "GB", "IE": return Support(line: "Samaritans — free, 24/7", call: "116123", text: nil, web: "https://www.samaritans.org")
        case "IN": return Support(line: "Tele-MANAS — free, 24/7", call: "14416", text: nil, web: "https://telemanas.mohfw.gov.in")
        case "AU": return Support(line: "Lifeline — free, 24/7", call: "131114", text: "0477131114", web: "https://www.lifeline.org.au")
        default: return Support(line: "Find a free helpline in your country", call: nil, text: nil, web: "https://findahelpline.com")
        }
    }

    // MARK: - Built-in answers (every phone)

    struct Theme { let name: String; let words: [String]; let control: [String]; let firstStep: Step }

    static let themes: [Theme] = [
        Theme(name: "Money", words: ["money", "debt", "loan", "credit card", "bills?", "rent", "mortgage", "margin", "stock", "loss", "invest",
                                     "interest", "broke", "overdraft", "tax", "savings", "paycheck", "salary"],
              control: ["Get the whole picture on one page: every debt, what you owe, the interest rate and the next due date. Seeing it is smaller than imagining it.",
                        "Anything with a deadline or a rising cost — a payment about to bounce, the highest interest rate — comes first.",
                        "Hold off on big money moves (new trades, new loans) while you feel this way; decide them on a calmer day.",
                        "Call a lender before you miss a payment, not after — most have hardship options they don't advertise."],
              firstStep: Step(text: "List every debt: who, how much, interest rate, next due date", minutes: 20)),
        Theme(name: "Work", words: ["work", "job", "boss", "deadline", "career", "fired", "laid off", "office", "client", "project"],
              control: ["Write down the one deliverable that matters most this week; the rest can wait or be asked about.",
                        "Tell your manager early what's slipping — a heads-up lands far better than a surprise."],
              firstStep: Step(text: "Pick the one work thing that matters most this week", minutes: 10)),
        Theme(name: "Health & energy", words: ["sick", "ill", "pain", "tired", "exhausted", "sleep", "health", "doctor", "burn"],
              control: ["Sleep, food and a short walk are the cheapest fixes for a heavy head — protect them first.",
                        "If it's been going on for a while, book a check-up; that's one less thing to carry alone."],
              firstStep: Step(text: "Drink water, eat something, take a 10-minute walk", minutes: 15)),
        Theme(name: "People", words: ["wife", "husband", "partner", "kids?", "family", "parents?", "mom", "dad", "friend", "divorce", "break ?up", "lonely"],
              control: ["Say it out loud to one person you trust — problems shared get smaller.",
                        "You don't have to fix the relationship today; you only need the next honest conversation."],
              firstStep: Step(text: "Message one person you trust and tell them how you're doing", minutes: 5)),
    ]

    /// Which themes the words touch, and the words that put them there (in the person's spelling).
    static func themesIn(_ text: String) -> [(Theme, [String])] {
        let parts = ThinkingEngine.split(text)
        return themes.compactMap { th in
            let hits = parts.filter { p in th.words.contains { has(p, #"\b"# + $0) } }
            return hits.isEmpty ? nil : (th, hits)
        }
    }

    static func builtIn(_ raw: String, region: String? = Locale.current.region?.identifier, now: Date = Date()) -> Answer {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if needsSupport(text) {
            return Answer(kind: .worry, understood: "It sounds like you're in a lot of pain right now.",
                          headline: "You don't have to carry this alone",
                          sections: [Section(title: "Right now", bullets: [
                            "Please reach out to someone today — a helpline, a friend, or someone you live with.",
                            "If you're in immediate danger, call your local emergency number."])],
                          support: support(region: region))
        }
        let k = kind(of: text)
        switch k {
        case .worry:
            let found = themesIn(text)
            var sections: [Section] = []
            if !found.isEmpty {
                sections.append(Section(title: "What's weighing on you", bullets: found.map { "\($0.0.name): \($0.1.joined(separator: ", "))" }))
            }
            for (th, _) in found {
                var control = th.control
                // Only what they raised: margin comes up when they mentioned it, never as a stock example.
                if th.name == "Money", has(text, #"\bmargin"#) {
                    control.insert("Margin debt can force sales at the worst moment: know your margin balance and how far prices can fall before a margin call.", at: 1)
                }
                sections.append(Section(title: "\(th.name) — what you can do", bullets: control))
            }
            if found.isEmpty {
                sections.append(Section(title: "What you can do", bullets: [
                    "Write each worry on its own line. Next to each, write the one thing you could do about it — or 'nothing right now'.",
                    "Cross out the ones that are 'nothing right now'. What's left is your real list, and it's shorter."]))
            }
            var steps = found.map(\.0.firstStep)
            if has(text, #"\bmargin"#) {
                steps.insert(Step(text: "Check your margin balance and how close you are to a margin call", minutes: 10), at: min(1, steps.count))
            }
            if has(text, #"overwhelm|too much|can'?t cope|stress|anxious|panic"#), !found.contains(where: { $0.0.name == "People" }) {
                steps.append(Step(text: "Tell one person you trust how you're really doing", minutes: 5))
            }
            if steps.count < 3 { steps.append(Step(text: "Write down the one thing that would make tomorrow a bit lighter", minutes: 5)) }
            let money = found.contains { $0.0.name == "Money" }
            return Answer(kind: .worry,
                          understood: found.count > 1 ? "A lot is landing at once — \(found.map { $0.0.name.lowercased() }.joined(separator: ", ")) — and that's why it feels overwhelming."
                                                      : "That's a heavy load, and it makes sense that it feels overwhelming.",
                          headline: "Make it smaller, one piece at a time",
                          sections: sections, steps: Array(steps.prefix(4)),
                          recommendation: money
                            ? "Start with the money picture on paper tonight — the debt with a deadline or the highest interest goes first. If it's more than you can sort alone, a free nonprofit credit counsellor can go through it with you."
                            : "Pick the smallest step above and do it today. Momentum beats a perfect plan.",
                          followUps: money ? ["How do I pay down debt with the highest interest first?", "What should I ask a credit counsellor?", "How do I stop panicking about losses?"]
                                           : ["What should I do first?", "How do I stop overthinking this?"],
                          caution: money ? "General guidance, not financial advice." : nil)
        case .tasks:
            let tasks = ThinkingEngine.tasks(from: text, now: now)
            return Answer(kind: .tasks, understood: "\(tasks.count) thing\(tasks.count == 1 ? "" : "s") to get done.",
                          headline: "Your list, tidied",
                          steps: tasks.map { Step(text: $0.text.prefix(1).uppercased() + $0.text.dropFirst(), minutes: nil) },
                          recommendation: "Do the quickest one first — it gets you moving.",
                          followUps: ["Which of these should I do first?", "Plan my day around these"])
        case .decision:
            let q = text.replacingOccurrences(of: #"(?i)^should i\s+"#, with: "", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: "?. "))
            return Answer(kind: .decision, understood: "You're deciding whether to \(q).",
                          headline: "Questions that settle it",
                          sections: [Section(title: "Ask yourself", bullets: [
                            "A year from now, which would I regret more — doing it or not doing it?",
                            "Can I undo it if it goes wrong? Easy to undo means try it.",
                            "What does it cost — money, time, and what I'd give up?",
                            "If a friend asked me this, what would I tell them?"])],
                          recommendation: "If it's easy to undo, try it for a short, set time and then decide for good.",
                          followUps: ["What are the pros and cons?", "What would change your answer?"])
        case .question, .message, .prep, .idea:
            return Answer(kind: k, understood: "\(k.label).",
                          headline: "This one needs Apple Intelligence",
                          sections: [Section(title: "Why", bullets: [
                            "Explaining, rewording and planning something new need a language model. Tenzy uses Apple's, which runs on iPhone 15 Pro and newer with Apple Intelligence turned on — free and private."])],
                          recommendation: "Turn on Apple Intelligence in Settings if your iPhone supports it, then ask again.")
        }
    }

    // MARK: - The model

    static let instructions = """
    You are Tenzy's thinking partner. A person typed whatever is on their mind. First work out what they actually need, \
    then give the most useful answer for that. Never just split their words into a list or a schedule.
    Kinds: worry (feelings, stress or problems weighing on them — even when written as a list of words like "money, debts, \
    overwhelmed"), decision (whether or which), tasks (things they need to get done), question (wants something explained \
    or answered), message (wants text reworded, replied to or written), prep (getting ready for an event, trip, appointment \
    or conversation), idea (planning or brainstorming something new).
    Answer rules: plain everyday words, kind but direct, specific to what they wrote; never invent facts about them. \
    Sections untangle the situation (worry: name each concern and what is in their control; decision: pros, cons, what \
    would change the answer; question: the answer then the detail; prep: bring, do, ask; idea: options and how to start). \
    Steps are 2 to 5 concrete next actions, smallest first, with realistic minutes; none for a pure question or message. \
    The recommendation is the bottom line with a clear lean — never sit on the fence. \
    Money: general guidance only; never tell them to buy, sell or hold a specific investment; when debts are serious suggest \
    a free nonprofit credit counsellor or a qualified adviser. Health: never diagnose or give doses; suggest a clinician. \
    Never mention weather, apps or anything they did not raise.
    """

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    @Generable struct AISection {
        @Guide(description: "A short title, 2 to 5 words") var title: String
        @Guide(description: "2 to 4 short, specific sentences") var bullets: [String]
    }
    @available(iOS 26.0, *)
    @Generable struct AIStep {
        @Guide(description: "One concrete action, starting with a verb") var text: String
        @Guide(description: "Realistic minutes it takes") var minutes: Int
    }
    @available(iOS 26.0, *)
    @Generable struct AIAnswer {
        @Guide(description: "One of: worry, decision, tasks, question, message, prep, idea") var kind: String
        @Guide(description: "One warm, specific sentence showing you understood, in their own terms") var understood: String
        @Guide(description: "The core of the answer in under 8 words") var headline: String
        @Guide(description: "2 to 4 sections that untangle the situation") var sections: [AISection]
        @Guide(description: "2 to 5 next actions, smallest first; empty for a pure question or message") var steps: [AIStep]
        @Guide(description: "The bottom line in one or two sentences, with a clear lean") var recommendation: String
        @Guide(description: "Only for a message: the ready-to-send text. Otherwise empty") var rewrite: String
        @Guide(description: "2 or 3 short follow-up questions they might ask next, in their voice") var followUps: [String]
    }
    #endif

    /// A conversation with the model: the first question and every follow-up, so "and what about the margin
    /// interest?" is answered knowing what came before. Falls back to the built-in answer, never dead-ends.
    @MainActor final class Conversation: ObservableObject {
        @Published private(set) var turns: [(asked: String, answer: Answer)] = []
        private var session: AnyObject?
        private var engine: Engine = .builtIn

        var last: Answer? { turns.last?.answer }
        func reset() { turns = []; session = nil }

        func ask(_ text: String) async {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            if ThinkBrain.needsSupport(t) { turns.append((t, ThinkBrain.builtIn(t))); return }
            if let a = await askModel(t) { turns.append((t, a)); return }
            // No model: a follow-up is answered from everything said so far.
            let all = (turns.map(\.asked) + [t]).joined(separator: ", ")
            turns.append((t, ThinkBrain.builtIn(turns.isEmpty ? t : all)))
        }

        /// `prompt` overrides the usual wording — used when a fresh session has to be told what came before.
        private func askModel(_ text: String, prompt override: String? = nil, retried: Bool = false) async -> Answer? {
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let session: LanguageModelSession
                if let s = self.session as? LanguageModelSession { session = s }
                else {
                    guard let made = Self.makeSession() else { return nil }
                    session = made.0; engine = made.1; self.session = made.0
                }
                let prompt = override ?? (turns.isEmpty ? "What they wrote:\n\(text)" : "Their follow-up:\n\(text)")
                do {
                    let r = try await withThrowingTaskGroup(of: AIAnswer?.self) { g in
                        g.addTask { try await session.respond(to: prompt, generating: AIAnswer.self).content }
                        g.addTask { try await Task.sleep(nanoseconds: 90_000_000_000); return nil }
                        defer { g.cancelAll() }
                        return try await g.next() ?? nil
                    }
                    guard let r else { return nil }
                    return ThinkBrain.answer(from: r, engine: engine, asked: text)
                } catch {
                    // The cloud was unreachable or over today's limit, or a long conversation filled the model's
                    // memory: start once more on a fresh on-phone session, told what was said before.
                    guard !retried, let fresh = Self.phoneSession() else { return nil }
                    self.session = fresh; engine = .phone
                    let earlier = turns.map { "- \($0.asked)" }.joined(separator: "\n")
                    return await askModel(text, prompt: turns.isEmpty ? nil : "Earlier they said:\n\(earlier)\n\nTheir follow-up:\n\(text)", retried: true)
                }
            }
            #endif
            return nil
        }

        #if canImport(FoundationModels)
        @available(iOS 26.0, *)
        private static func phoneSession() -> LanguageModelSession? {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            return LanguageModelSession { ThinkBrain.instructions }
        }
        @available(iOS 26.0, *)
        private static func makeSession() -> (LanguageModelSession, Engine)? {
            #if TENZY_PCC
            if #available(iOS 27.0, *) {
                let cloud = PrivateCloudComputeLanguageModel()
                if case .available = cloud.availability, !cloud.quotaUsage.isLimitReached {
                    return (LanguageModelSession(model: cloud, instructions: ThinkBrain.instructions), .cloud)
                }
            }
            #endif
            return phoneSession().map { ($0, .phone) }
        }
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    static func answer(from r: AIAnswer, engine: Engine, asked: String) -> Answer {
        let k = Kind(rawValue: r.kind.lowercased().trimmingCharacters(in: .whitespaces)) ?? kind(of: asked)
        let money = themesIn(asked).contains { $0.0.name == "Money" }
        return Answer(kind: k, understood: r.understood, headline: r.headline,
                      sections: r.sections.filter { !$0.bullets.isEmpty }.map { Section(title: $0.title, bullets: $0.bullets) },
                      steps: r.steps.map { Step(text: $0.text, minutes: $0.minutes > 0 ? $0.minutes : nil) },
                      recommendation: r.recommendation, rewrite: k == .message ? r.rewrite : "",
                      followUps: Array(r.followUps.prefix(3)),
                      caution: money ? "General guidance, not financial advice." : nil, engine: engine)
    }
    #endif
}
