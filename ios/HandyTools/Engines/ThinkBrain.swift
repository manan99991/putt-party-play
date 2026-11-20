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

    enum Kind: String, CaseIterable, Equatable, Codable {
        case worry, decision, tasks, question, message, prep, idea, recipe, judge, estimate
        var label: String {
            switch self {
            case .worry: return "Something weighing on you"
            case .decision: return "A decision"
            case .tasks: return "Things to get done"
            case .question: return "A question"
            case .message: return "A message to get right"
            case .prep: return "Getting ready"
            case .idea: return "An idea to shape"
            case .recipe: return "A meal from what you have"
            case .judge: return "How a message comes across"
            case .estimate: return "How long it will take"
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
            case .recipe: return "fork.knife"
            case .judge: return "eye"
            case .estimate: return "hourglass"
            }
        }
    }

    enum Engine: String, Equatable, Codable { case cloud, phone, builtIn
        var note: String {
            switch self {
            case .cloud: return "Answered by Apple's Private Cloud Compute — nothing is stored or seen by anyone."
            case .phone: return "Answered on your iPhone. Nothing left your phone."
            case .builtIn: return "Built-in answer. With Apple Intelligence (iPhone 15 Pro or newer) Tenzy writes a fuller one for your exact situation."
            }
        }
    }

    struct Section: Equatable, Identifiable, Codable { var id: String { title }; let title: String; let bullets: [String] }
    struct Step: Equatable, Identifiable, Codable { var id: String { text }; let text: String; let minutes: Int? }

    struct Answer: Equatable, Codable {
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
        var tone: String?               // how they sound — "stressed", "in a hurry" — and the answer matches it
        var variants: [Variant] = []    // a message in several tones: warmer, more professional, shorter, firmer
        var options: [Option] = []      // a decision: each choice with its pros and cons, weighed
    }
    /// One choice in a decision. Each pro and con carries a weight (1 small, 2 medium, 3 big) the person can change;
    /// the lean is worked out from the weights, so the answer moves when what matters to them moves.
    struct Option: Equatable, Identifiable, Codable {
        var id: String { name }
        var name: String
        var pros: [Point]
        var cons: [Point]
        var score: Int { pros.map(\.weight).reduce(0, +) - cons.map(\.weight).reduce(0, +) }
    }
    struct Point: Equatable, Identifiable, Codable { var id: String { text }; var text: String; var weight: Int }
    /// The option the weights favour, and by how much — nil when they tie.
    static func lean(_ options: [Option]) -> (Option, Int)? {
        let ranked = options.sorted { $0.score > $1.score }
        guard let top = ranked.first, ranked.count > 1, top.score > ranked[1].score else { return nil }
        return (top, top.score - ranked[1].score)
    }
    /// How finely to break things down — goblin's "spiciness", in plain words.
    enum Detail: String, CaseIterable, Codable { case few, balanced, tiny
        var label: String { ["A few big steps", "Balanced", "Tiny steps"][Self.allCases.firstIndex(of: self)!] }
        var prompt: String {
            switch self {
            case .few: return "Detail: a few big steps (3 or 4)."
            case .balanced: return "Detail: balanced (5 to 7 steps)."
            case .tiny: return "Detail: tiny steps (8 to 15 very small, physical micro-steps, for a day when starting is hard)."
            }
        }
    }
    struct Variant: Equatable, Identifiable, Codable { var id: String { label }; let label: String; let text: String }

    /// Help to reach right now, for the person's country.
    struct Support: Equatable, Codable { let line: String; let call: String?; let text: String?; let web: String }

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
        if has(t, #"(how does (this|it|that) (sound|come across|read|land)|what does (this|she|he|it|that|they) (mean|really mean)|is (this|it|that) (rude|ok|okay|passive|mean|too much|harsh)|(is|are) (he|she|they|my \w+) (mad|upset|angry|annoyed|annoyed with me)|read between the lines|what'?s the tone|judge (this|the tone))"#)
            || has(t, #"\b(he|she|they|my (boss|manager|partner|wife|husband|friend|mum|mom|dad|landlord|client)) (said|wrote|texted|replied|messaged|sent)\b.{0,20}[:\"“]"#) { return .judge }
        if has(t, #"^(please\s+)?(re-?word|rewrite|rephrase|reply to|respond to|make (this|it) (sound|more|less|shorter|nicer|polite)|fix (this|my) (message|email|text)|write (a|an|me a) (message|email|text|note|reply))"#)
            || has(t, #"^(hi|hey|hello|dear)\b.{25,}"#) { return .message }
        if has(t, #"^how long (will|does|would|should|do|might)|\bhow long (it|this|that) (will|would)? ?take|\bestimate (how long|the time)|\bhow much time\b"#) { return .estimate }
        if has(t, #"\bshould i\b|\bor not\b|\bvs\.?\b|\bversus\b|which (one|is better|should)|\bdecid|\bchoose between\b|\bworth it\b|\bpros and cons\b"#) { return .decision }
        if has(t, #"(what (can|should) i (cook|make)|recipe|dinner (idea|with)|i have .*(eggs|chicken|rice|pasta|potato|tofu|beans|spinach|onion))"#) { return .recipe }
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

    /// How the person sounds, read from their words, so the answer can match it. Nil when it's plain.
    static func tone(of t: String) -> String? {
        if needsSupport(t) { return "in pain" }
        if count(t, ["overwhelm", "stress", "anxious", "panic", "can'?t cope", "scared", "worried", "exhausted", "too much", "hopeless"]) > 0 { return "stressed" }
        if has(t, #"\b(asap|urgent|right now|hurry|deadline (is )?(today|tomorrow))\b|!!"#) { return "in a hurry" }
        if has(t, #"\b(angry|furious|pissed|annoyed|fed up|unfair)\b"#) { return "frustrated" }
        if has(t, #"\b(excited|can'?t wait|thrilled)\b"#) { return "excited" }
        return nil
    }

    /// One step, broken into smaller ones you can start right away — when there's no model to do it properly.
    static func breakDown(_ step: Step, detail: Detail = .balanced) -> [Step] {
        let parts = ThinkingEngine.split(step.text.replacingOccurrences(of: " and ", with: ", "))
        if parts.count > 1 { return parts.map { Step(text: $0.prefix(1).uppercased() + $0.dropFirst(), minutes: step.minutes.map { max(2, $0 / parts.count) }) } }
        let what = step.text.prefix(1).lowercased() + step.text.dropFirst()
        let m = step.minutes ?? 20
        if detail == .tiny {
            return [Step(text: "Stand up and go to where you'll \(what)", minutes: 1),
                    Step(text: "Put out everything you need, where you can see it", minutes: 3),
                    Step(text: "Do just the first small part — 5 minutes, then you can stop", minutes: 5),
                    Step(text: "Take one breath, then do the next small part", minutes: 5),
                    Step(text: "Keep going in 5-minute bits until it's done", minutes: max(2, m - 16)),
                    Step(text: "Put things away", minutes: 1),
                    Step(text: "Tick it off — that counts", minutes: 1)]
        }
        return [Step(text: "Get out everything you need to \(what)", minutes: 3),
                Step(text: "Set a 10-minute timer and just start", minutes: 10),
                Step(text: "Keep going until it's done — \(what)", minutes: max(5, m - 14)),
                Step(text: "Tick it off and note what's next", minutes: 1)]
    }

    /// How a message comes across, from its words alone: the reading behind "is she annoyed with me?".
    static func reading(of t: String) -> [String] {
        var r: [String] = []
        if has(t, #"(per my last|as (previously|already) (mentioned|stated)|just a (gentle )?reminder|going forward|noted\.?$|as discussed)"#) { r.append("Pointed — they think they've said this before") }
        if has(t, #"\b(asap|urgent|immediately|right away|by (eod|end of day|today))\b|!!"#) { r.append("Urgent — they want it soon") }
        if has(t, #"\b(disappointed|unacceptable|not ok|frustrat|annoyed|upset|angry)"#) || t.filter(\.isUppercase).count > max(12, t.count / 3) { r.append("Upset — something has bothered them") }
        if has(t, #"\b(thanks|thank you|appreciate|great|love|awesome|no worries|no rush)\b|:\)|😊|🙂"#) { r.append("Friendly and warm") }
        if has(t, #"^\s*(k|ok|okay|fine|sure|whatever)\.?\s*$"#) { r.append("Very short — could be busy, could be cool; don't read too much into one word") }
        if has(t, #"\b(please|kindly|regards|dear)\b"#), r.isEmpty { r.append("Polite and formal") }
        if r.isEmpty { r.append("Neutral — nothing in the words themselves says they're upset") }
        return r
    }

    static func builtIn(_ raw: String, region: String? = Locale.current.region?.identifier, now: Date = Date()) -> Answer {
        var a = builtInCore(raw, region: region, now: now)
        a.tone = tone(of: raw)
        return a
    }

    private static func builtInCore(_ raw: String, region: String?, now: Date) -> Answer {
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
        case .judge:
            let quoted = text.range(of: #"[:"“](.+)$"#, options: .regularExpression).map { String(text[$0]).trimmingCharacters(in: CharacterSet(charactersIn: ":\"“” ")) } ?? text
            let read = reading(of: quoted)
            return Answer(kind: .judge, understood: "You want to know how this message really comes across.",
                          headline: read[0].components(separatedBy: " — ").first ?? read[0],
                          sections: [Section(title: "How it comes across", bullets: read),
                                     Section(title: "Before you reply", bullets: [
                                        "Read it once more as if a friend sent it — the kindest reading is usually closest.",
                                        "If you're unsure, ask: a short \"Just checking — all good?\" clears it up fast."])],
                          recommendation: read.contains { $0.hasPrefix("Upset") || $0.hasPrefix("Pointed") }
                            ? "Reply calmly and fix the thing they mention first; keep it short and skip the defending."
                            : "Take it at face value and reply normally.",
                          rewrite: "Thanks for letting me know — I'm on it.",
                          followUps: ["Write me a calm reply", "Am I overthinking this?"],
                          variants: [Variant(label: "Friendly", text: "Thanks for the heads-up! I'll sort it out and get back to you."),
                                     Variant(label: "Short", text: "On it — will update you soon."),
                                     Variant(label: "Clear the air", text: "Just checking — is everything all right? Happy to talk it through.")])
        case .decision:
            let q = text.replacingOccurrences(of: #"(?i)^should i\s+"#, with: "", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: "?. "))
            return Answer(kind: .decision, understood: "You're deciding whether to \(q).",
                          headline: "Questions that settle it",
                          sections: [Section(title: "Ask yourself", bullets: [
                            "A year from now, which would I regret more — doing it or not doing it?",
                            "Can I undo it if it goes wrong? Easy to undo means try it.",
                            "What does it cost — money, time, and what I'd give up?",
                            "If a friend asked me this, what would I tell them?"])],
                          recommendation: "Weigh each side below — tap a point to make it matter more or less, and add your own. The lean updates as you go.",
                          followUps: ["What are the pros and cons?", "What would change your answer?"],
                          options: decisionOptions(text))
        case .question, .message, .prep, .idea, .recipe, .estimate:
            return Answer(kind: k, understood: "\(k.label).",
                          headline: "This one needs Apple Intelligence",
                          sections: [Section(title: "Why", bullets: [
                            "Explaining, rewording and planning something new need a language model. Tenzy uses Apple's, which runs on iPhone 15 Pro and newer with Apple Intelligence turned on — free and private."])],
                          recommendation: "Turn on Apple Intelligence in Settings if your iPhone supports it, then ask again.")
        }
    }

    /// "rent" → "Rent", but "iPhone" stays "iPhone".
    static func capFirst(_ s: String) -> String {
        let c = Array(s)
        if c.count > 1, c[1].isUppercase { return s }
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    private static func splitting(_ s: String, by pattern: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [s] }
        var out: [String] = [], last = s.startIndex
        for m in re.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
            if let r = Range(m.range, in: s) { out.append(String(s[last..<r.lowerBound])); last = r.upperBound }
        }
        out.append(String(s[last...]))
        return out
    }

    /// The choices in a decision, read from how it's asked: "A or B", "A vs B", or "should I X" (X, or stay as you are).
    /// Built-in answers start them empty so the person weighs their own reasons; the model fills them in.
    static func decisionOptions(_ raw: String) -> [Option] {
        let t = raw.trimmingCharacters(in: CharacterSet(charactersIn: "?.! ").union(.whitespacesAndNewlines))
        let body = t.replacingOccurrences(of: #"(?i)^(should i|do i|which is better[:,]?|help me decide[:,]?|i can'?t decide (between|whether to)?)\s*"#, with: "", options: .regularExpression)
        for sep in [#"\s+vs\.?\s+"#, #"\s+versus\s+"#, #"\s+or\s+"#] {
            let parts = splitting(body, by: sep).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if parts.count >= 2, !parts.last!.lowercased().hasPrefix("not") {
                return parts.prefix(4).map { Option(name: capFirst($0), pros: [], cons: []) }
            }
        }
        let what = body.replacingOccurrences(of: #"(?i)\s+or not$"#, with: "", options: .regularExpression)
        return [Option(name: capFirst(what), pros: [], cons: []),
                Option(name: "Stay as you are", pros: [], cons: [])]
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
    Tone: read how they sound (stressed, in a hurry, frustrated, excited, calm) and match it — gentle and short when \
    they're stressed, brisk when they're in a hurry, steady when they're frustrated. Name it in two or three words.
    Message: give the ready-to-send text, plus 4 to 6 variants labelled by tone (Warmer, More professional, Shorter, \
    Firmer, More casual, Kinder), each keeping every name, time and fact.
    Tasks: order them so the one that unblocks the rest comes first, and give honest minutes for each.
    Recipe (they list ingredients or ask what to cook): one dish they can make mostly from what they have — you need \
    not use every ingredient — respecting any diet they mention; the ingredients with amounts, numbered method steps \
    with minutes, and what to swap if something is missing.
    Decision: first find the real choice. Chores that stand in the way (a shower, getting ready, travel, paperwork) are \
    steps, not options: "my friend leaves for good tomorrow, I'd have to shower and get ready, not sure I want to" is the \
    choice "go and say goodbye, or skip it", and the shower is step 1. Give 2 or 3 options that are clearly different, \
    never two versions of the same thing; for a yes/no, the option and not doing it. Each gets 2 to 4 pros and cons \
    about THEIR situation (never generic ones like "feels rushed"), weighted 1 (small), 2 (medium) or 3 (big). \
    When one option can't be had again (someone leaving for good, a last chance, a deadline), say so plainly and weigh \
    regret: people rarely regret showing up, often regret missing a last chance. Then a clear lean and what would change it.
    Recommendation: start with what to do, in a few words, then why in their terms; warm when it's personal.
    Steps are real actions with honest minutes (a quick shower is about 10 minutes); never "decide", "think about it" \
    or "tell me" as a step, and no filler sections such as what to wear unless they asked.
    Question (Professor): explain in plain words first, then one concrete everyday example, then why it matters to \
    them; follow the detail level — few means the short version, tiny means build it up from the very basics.
    Estimate (they ask how long something takes): a realistic range in the headline ("About 2 to 3 hours"), the steps \
    with minutes, what makes it take longer, and how to make it faster.
    Recipe extras: honour servings, equipment, time and diet if they mention them.
    Judge (they ask how a message they received comes across, or what someone meant): sections How it comes across, \
    What they probably mean, What to watch for; be fair to the sender and don't invent bad intent; then a calm \
    recommended reply as the rewrite, with variants labelled Friendly, Short and Clear the air.
    """

    /// Steps that are things to DO. "Decide if you'll shower", "Tell me which way you lean" and "Think about it" are
    /// not steps (your 20 Nov goodbye example had three of them and a 1 h 15 min total); keep a list that has
    /// nothing else rather than an empty one.
    static func realSteps(_ steps: [Step]) -> [Step] {
        let notActions = #"^(decide|deciding|tell me|think about|consider|reflect|figure out whether|choose whether|ask yourself)\b"#
        let kept = steps.filter { $0.text.trimmingCharacters(in: .whitespaces).lowercased().range(of: notActions, options: .regularExpression) == nil }
        return kept.isEmpty ? steps : kept
    }

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
        @Guide(description: "One of: worry, decision, tasks, question, message, prep, idea, recipe, judge, estimate") var kind: String
        @Guide(description: "One warm, specific sentence showing you understood, in their own terms") var understood: String
        @Guide(description: "The core of the answer in under 8 words") var headline: String
        @Guide(description: "2 to 4 sections that untangle the situation") var sections: [AISection]
        @Guide(description: "2 to 5 next actions, smallest first; empty for a pure question or message") var steps: [AIStep]
        @Guide(description: "The bottom line in one or two sentences, with a clear lean") var recommendation: String
        @Guide(description: "Only for a message: the ready-to-send text. Otherwise empty") var rewrite: String
        @Guide(description: "2 or 3 short follow-up questions they might ask next, in their voice") var followUps: [String]
        @Guide(description: "How they sound in two or three words, e.g. stressed, in a hurry, calm") var tone: String
        @Guide(description: "For a message: 4 to 6 versions labelled Warmer, More professional, Shorter, Firmer, More casual, Kinder. For judge: replies labelled Friendly, Short, Clear the air. Otherwise empty") var variants: [AIVariant]
        @Guide(description: "Only for a decision: the 2 or 3 real, clearly different options, each with weighted pros and cons. Otherwise empty") var options: [AIOption]
    }
    @available(iOS 26.0, *)
    @Generable struct AIPoint {
        @Guide(description: "One specific reason, in a short sentence") var text: String
        @Guide(description: "How much it matters for them: 1 small, 2 medium, 3 big") var weight: Int
    }
    @available(iOS 26.0, *)
    @Generable struct AIOption {
        @Guide(description: "The option, in a few words") var name: String
        @Guide(description: "2 to 4 pros") var pros: [AIPoint]
        @Guide(description: "2 to 4 cons") var cons: [AIPoint]
    }
    @available(iOS 26.0, *)
    @Generable struct AIVariant {
        @Guide(description: "The label: Warmer, More professional, Shorter, Firmer, More casual, Kinder, Friendly, Short or Clear the air") var label: String
        @Guide(description: "The full message in that tone, ready to send") var text: String
    }
    @available(iOS 26.0, *)
    @Generable struct AIBreakdown {
        @Guide(description: "Smaller steps, each doable in one go, starting with a verb, smallest and easiest first, as many as the detail level asks") var steps: [AIStep]
    }
    #endif

    /// A conversation with the model: the first question and every follow-up, so "and what about the margin
    /// interest?" is answered knowing what came before. Falls back to the built-in answer, never dead-ends.
    struct Turn: Codable, Equatable { let asked: String; let answer: Answer }

    @MainActor final class Conversation: ObservableObject {
        @Published private(set) var turns: [Turn] = []
        private var session: AnyObject?
        private var engine: Engine = .builtIn
        private var saved = UUID()
        /// How finely steps are broken down; the model and the built-in breakdown both follow it.
        var detail: Detail = .balanced

        var last: Answer? { turns.last?.answer }
        func reset() { turns = []; session = nil; saved = UUID() }
        /// Pick up an earlier conversation from history: the answers come back as they were, and a follow-up is
        /// asked on a fresh session told what was said before.
        func restore(_ s: ThinkHistory.Saved) { turns = s.turns; session = nil; saved = s.id }
        private func keep() { ThinkHistory.save(id: saved, turns: turns) }

        /// One step broken into smaller ones (the "too big to start" fix), in the same conversation so it knows
        /// what the step is part of. Built-in breakdown when there's no model.
        func breakDown(_ step: Step) async -> [Step] {
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *), let session = self.session as? LanguageModelSession {
                let prompt = "Break this step into smaller steps they can start right now. \(detail.prompt) Step: \(step.text)"
                if let r = try? await withThrowingTaskGroup(of: AIBreakdown?.self, body: { g in
                    g.addTask { try await session.respond(to: prompt, generating: AIBreakdown.self).content }
                    g.addTask { try await Task.sleep(nanoseconds: 60_000_000_000); return nil }
                    defer { g.cancelAll() }
                    return try await g.next() ?? nil
                }), !r.steps.isEmpty {
                    return r.steps.map { Step(text: $0.text, minutes: $0.minutes > 0 ? $0.minutes : nil) }
                }
            }
            #endif
            return ThinkBrain.breakDown(step, detail: detail)
        }

        func ask(_ text: String) async {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            defer { keep() }
            if ThinkBrain.needsSupport(t) { turns.append(Turn(asked: t, answer: ThinkBrain.builtIn(t))); return }
            if let a = await askModel(t) { turns.append(Turn(asked: t, answer: a)); return }
            // No model: a follow-up is answered from everything said so far.
            let all = (turns.map(\.asked) + [t]).joined(separator: ", ")
            turns.append(Turn(asked: t, answer: ThinkBrain.builtIn(turns.isEmpty ? t : all)))
        }

        /// `prompt` overrides the usual wording — used when a fresh session has to be told what came before.
        private func askModel(_ text: String, prompt override: String? = nil, retried: Bool = false) async -> Answer? {
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let session: LanguageModelSession
                var fresh = false
                if let s = self.session as? LanguageModelSession { session = s }
                else {
                    guard let made = Self.makeSession() else { return nil }
                    session = made.0; engine = made.1; self.session = made.0; fresh = true
                }
                let earlier = turns.map { "- \($0.asked)" }.joined(separator: "\n")
                let base = turns.isEmpty ? "What they wrote:\n\(text)"
                    : (fresh ? "Earlier they said:\n\(earlier)\n\nTheir follow-up:\n\(text)" : "Their follow-up:\n\(text)")
                let prompt = (override ?? base) + "\n\n" + detail.prompt
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
                      steps: realSteps(r.steps.map { Step(text: $0.text, minutes: $0.minutes > 0 ? $0.minutes : nil) }),
                      recommendation: r.recommendation, rewrite: k == .message || k == .judge ? r.rewrite : "",
                      followUps: Array(r.followUps.prefix(3)),
                      caution: money ? "General guidance, not financial advice." : nil, engine: engine,
                      tone: r.tone.trimmingCharacters(in: .whitespaces).isEmpty ? tone(of: asked) : r.tone.lowercased(),
                      variants: k == .message || k == .judge ? r.variants.filter { !$0.text.isEmpty }.map { Variant(label: $0.label, text: $0.text) } : [],
                      options: k == .decision ? r.options.prefix(3).map { o in
                        Option(name: o.name, pros: o.pros.map { Point(text: $0.text, weight: min(3, max(1, $0.weight))) },
                               cons: o.cons.map { Point(text: $0.text, weight: min(3, max(1, $0.weight))) }) } : [])
    }
    #endif
}

/// Past conversations, kept on this phone only — so a decision you weighed or a plan you made last week is still
/// there. The last 30, newest first; "Clear" removes them all.
enum ThinkHistory {
    struct Saved: Codable, Identifiable, Equatable { let id: UUID; var date: Date; var turns: [ThinkBrain.Turn]
        var title: String { turns.first?.asked ?? "" }
        var headline: String { turns.last?.answer.headline ?? "" }
    }
    static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("think-history.json")
    }
    static func load(from u: URL = url) -> [Saved] {
        (try? JSONDecoder().decode([Saved].self, from: Data(contentsOf: u))) ?? []
    }
    static func save(id: UUID, turns: [ThinkBrain.Turn], to u: URL = url, now: Date = Date()) {
        guard !turns.isEmpty else { return }
        var all = load(from: u).filter { $0.id != id }
        all.insert(Saved(id: id, date: now, turns: turns), at: 0)
        if let d = try? JSONEncoder().encode(Array(all.prefix(30))) {
            try? d.write(to: u, options: [.atomic, .completeFileProtection])
        }
    }
    static func clear(at u: URL = url) { try? FileManager.default.removeItem(at: u) }
}
