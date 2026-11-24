import Foundation
import NaturalLanguage

/// The written part of Meeting Notes (Manan, 23 Nov: "the summary is too long and not clear … the to-do list is all
/// over the place … the email needs to be crisp"). A 30-minute meeting is far longer than the on-device model can
/// read at once, so it used to fail quietly and fall back to picking sentences ("Okay. Okay. Okay."). Now:
///
/// • Apple Intelligence (on the phone): the transcript is cleaned of filler, cut into parts the model can read, each
///   part turned into points / decisions / commitments, and the parts merged into one headline, 3–5 points and a tight
///   to-do list (task, who, by when).
/// • Phones without it: a much stricter built-in engine — filler and small talk never become a "point", and only real
///   commitments ("I'll send…", "Sam will…", "can you…by Friday") become to-dos, rewritten to start with the verb.
///
/// The email is assembled from those, never from raw transcript. Parsing, cleaning, choosing and the email are pure
/// and unit-tested.
enum MeetingDigest {
    enum Engine: Equatable { case onDevice, builtIn }

    struct Action: Equatable, Hashable {
        var task: String
        var owner: String?
        var due: String?
        /// "Send the revised deck — Sam · by Friday"
        var line: String {
            var s = task
            let tail = [owner, due.map { "by \($0)" }].compactMap { $0 }
            if !tail.isEmpty { s += " — " + tail.joined(separator: " · ") }
            return s
        }
    }

    struct Result: Equatable {
        var headline: String
        var points: [String]
        var decisions: [String]
        var actions: [Action]
        var engine: Engine
    }

    // MARK: - Cleaning (pure)

    private static let fillerPhrases = [
        "you know", "i mean", "sort of", "kind of", "like,", "um", "uh", "erm", "hmm", "mhm", "mm-hmm", "uh-huh",
        "basically", "literally", "actually,", "so yeah", "yeah yeah", "okay okay", "right right",
    ]

    /// Takes the filler out of spoken text without changing what was said.
    static func clean(_ s: String) -> String {
        var t = " " + s.replacingOccurrences(of: "\u{2019}", with: "'") + " "
        for f in fillerPhrases {
            let pattern = "(?i)(?<=[\\s,.])" + NSRegularExpression.escapedPattern(for: f) + "(?=[\\s,.!?])[,]?"
            t = t.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        t = t.replacingOccurrences(of: #"\b(\w+)( \1\b)+"#, with: "$1", options: [.regularExpression, .caseInsensitive])  // "I I I" → "I"
        t = t.replacingOccurrences(of: #"\s+,"#, with: ",", options: .regularExpression)
        t = t.replacingOccurrences(of: #",\s*,"#, with: ",", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: #"^[,.\s]+"#, with: "", options: .regularExpression)
        if let f = t.first, f.isLowercase { t = f.uppercased() + t.dropFirst() }
        return t
    }

    private static let smallTalk = #"^(ok(ay)?|yeah|yes|no|sure|right|cool|great|thanks?( you)?|thank you( all| everyone| everybody)?|bye( guys| all| everyone)?|hi( all| everyone| guys)?|hello|good (morning|afternoon)|sounds good|perfect|got it|alright|all right)[.!,]?( (thanks|thank you|bye|guys|everyone|everybody|all))*[.!]?$"#

    /// Filler, small talk or a fragment — never a point or a to-do.
    static func isNoise(_ sentence: String) -> Bool {
        let c = clean(sentence).trimmingCharacters(in: CharacterSet(charactersIn: " .!?,"))
        if c.isEmpty { return true }
        if c.range(of: smallTalk, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        return contentWords(c).count < 4
    }

    static func contentWords(_ s: String) -> [String] {
        TextTools.words(s).filter { !weak.contains($0) }
    }
    private static let weak: Set<String> = ["yeah", "okay", "gonna", "wanna", "thing", "things", "stuff", "whatever", "really", "maybe", "something", "anything", "everything", "know", "mean", "said", "says", "say", "think", "guess", "well", "good", "right", "sure", "kinda", "sorta"]

    /// Cuts the cleaned transcript into parts of about `words` words, at sentence ends.
    static func chunks(_ text: String, words: Int = 850) -> [String] {
        var out: [String] = [], cur: [String] = [], n = 0
        for s in TextTools.sentences(text) {
            let w = s.split(separator: " ").count
            if n + w > words, !cur.isEmpty { out.append(cur.joined(separator: " ")); cur = []; n = 0 }
            cur.append(s); n += w
        }
        if !cur.isEmpty { out.append(cur.joined(separator: " ")) }
        return out
    }

    // MARK: - Reading the model's notes (pure)

    struct Notes: Equatable { var headline: String?; var points: [String] = []; var decisions: [String] = []; var actions: [Action] = [] }

    static func parse(_ out: String) -> Notes {
        var n = Notes()
        for raw in out.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: CharacterSet(charactersIn: " *-•\t"))
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].uppercased().trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty, value.uppercased() != "NONE" else { continue }
            switch key {
            case "HEADLINE", "TOPIC": n.headline = value.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
            case "POINT", "SUMMARY": n.points.append(sentence(value))
            case "DECISION": n.decisions.append(sentence(value))
            case "ACTION", "TODO", "TO-DO": if let a = action(value) { n.actions.append(a) }
            default: continue
            }
        }
        return n
    }

    /// "Send the deck | Sam | Friday" → Action. A dash or "none" means not said.
    static func action(_ value: String) -> Action? {
        let parts = value.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        let task = sentence(parts[0], period: false)
        guard task.split(separator: " ").count >= 2 else { return nil }
        func field(_ i: Int) -> String? {
            guard parts.count > i else { return nil }
            let v = parts[i].trimmingCharacters(in: CharacterSet(charactersIn: " .-–—"))
            return v.isEmpty || ["none", "n/a", "unknown", "unspecified", "not said", "tbd", "anyone", "someone"].contains(v.lowercased()) ? nil : v
        }
        return Action(task: task, owner: field(1), due: field(2))
    }

    private static func sentence(_ s: String, period: Bool = true) -> String {
        var t = s.trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
        if let f = t.first, f.isLowercase { t = f.uppercased() + t.dropFirst() }
        if period, let l = t.last, !".!?".contains(l) { t += "." }
        if !period { t = t.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
        return t
    }

    // MARK: - Merging (pure)

    static func similarity(_ a: String, _ b: String) -> Double {
        let x = Set(contentWords(a)), y = Set(contentWords(b))
        guard !x.isEmpty, !y.isEmpty else { return a.lowercased() == b.lowercased() ? 1 : 0 }
        return Double(x.intersection(y).count) / Double(x.union(y).count)
    }

    /// Same task said twice → kept once (keeping whichever knows who and when).
    static func dedupe(_ actions: [Action], limit: Int = 8) -> [Action] {
        var out: [Action] = []
        for a in actions {
            if let i = out.firstIndex(where: { similarity($0.task, a.task) >= 0.5 }) {
                if out[i].owner == nil { out[i].owner = a.owner }
                if out[i].due == nil { out[i].due = a.due }
            } else { out.append(a) }
        }
        return Array(out.prefix(limit))
    }

    static func dedupe(_ lines: [String], limit: Int) -> [String] {
        var out: [String] = []
        for l in lines where !out.contains(where: { similarity($0, l) >= 0.5 }) { out.append(l) }
        return Array(out.prefix(limit))
    }

    // MARK: - Apple Intelligence path

    static let mapInstructions = """
    You turn one part of a meeting transcript into notes. The transcript is speech-to-text, so ignore filler, \
    small talk, greetings, goodbyes and false starts. Write short, plain English.
    Reply only with lines in exactly these forms:
    POINT: <one key fact, update, question or problem that was discussed — under 20 words>
    DECISION: <something the group agreed or decided>
    ACTION: <task, starting with a verb> | <who will do it, or -> | <deadline as said, or ->
    At most 4 POINT lines. A DECISION only when something was clearly agreed. An ACTION only for a clear \
    commitment or request that someone will do something — never for things merely mentioned. \
    If nothing qualifies, reply NONE.
    """

    static let reduceInstructions = """
    You write the final notes of a meeting from notes taken part by part, in order. Merge repeats, keep what \
    matters most, write short plain English.
    Reply only with lines in exactly these forms:
    HEADLINE: <what the meeting was about, under 12 words>
    POINT: <the 3 to 5 most important things discussed, most important first, under 20 words each>
    DECISION: <each decision that was made, if any>
    ACTION: <task, starting with a verb> | <who, or -> | <deadline, or ->
    At most 8 ACTION lines: only real commitments, merged when they are the same task.
    """

    /// Map every part, then merge; reports (part, of) as it goes. Nil when the model can't run.
    static func onDevice(_ transcript: String, progress: @escaping (Int, Int) -> Void) async -> Result? {
        guard AIEngine.isAvailable else { return nil }
        let parts = chunks(clean(transcript))
        guard !parts.isEmpty else { return nil }
        var notes: [Notes] = []
        for (i, p) in parts.enumerated() {
            progress(i + 1, parts.count + 1)
            if let out = try? await AIEngine.run(instructions: mapInstructions, prompt: p, timeout: 50) { notes.append(parse(out)) }
        }
        guard !notes.isEmpty else { return nil }
        progress(parts.count + 1, parts.count + 1)
        // Merge, in rounds if the notes themselves are long.
        var lines = notes.flatMap { n in
            n.points.map { "POINT: \($0)" } + n.decisions.map { "DECISION: \($0)" } + n.actions.map { "ACTION: \($0.task) | \($0.owner ?? "-") | \($0.due ?? "-")" }
        }
        var merged: Notes?
        for _ in 0..<3 {
            let groups = chunkLines(lines, words: 900)
            var next: [Notes] = []
            for g in groups {
                if let out = try? await AIEngine.run(instructions: reduceInstructions, prompt: g.joined(separator: "\n"), timeout: 50) { next.append(parse(out)) }
            }
            if next.isEmpty { break }
            if next.count == 1 { merged = next[0]; break }
            lines = next.flatMap { n in n.points.map { "POINT: \($0)" } + n.decisions.map { "DECISION: \($0)" } + n.actions.map { "ACTION: \($0.task) | \($0.owner ?? "-") | \($0.due ?? "-")" } }
        }
        let m = merged ?? Notes(headline: nil, points: notes.flatMap(\.points), decisions: notes.flatMap(\.decisions), actions: notes.flatMap(\.actions))
        let points = dedupe(m.points, limit: 5)
        guard !points.isEmpty || !m.actions.isEmpty else { return nil }
        return Result(headline: m.headline ?? headline(transcript), points: points, decisions: dedupe(m.decisions, limit: 5),
                      actions: dedupe(m.actions, limit: 8), engine: .onDevice)
    }

    static func chunkLines(_ lines: [String], words: Int) -> [[String]] {
        var out: [[String]] = [], cur: [String] = [], n = 0
        for l in lines {
            let w = l.split(separator: " ").count
            if n + w > words, !cur.isEmpty { out.append(cur); cur = []; n = 0 }
            cur.append(l); n += w
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    // MARK: - Built-in path (every phone, pure)

    static func builtIn(_ transcript: String) -> Result {
        let sents = TextTools.sentences(transcript).map(clean).filter { !isNoise($0) }
        return Result(headline: headline(transcript), points: keyPoints(sents), decisions: decisions(sents), actions: commitments(sents), engine: .builtIn)
    }

    /// "About: installation, operator screen, notifications" — the nouns talked about most.
    static func headline(_ text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass]); tagger.string = text
        var freq: [String: Int] = [:]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { tag, r in
            let w = text[r].lowercased()
            if tag == .noun, w.count > 3, !weak.contains(w), !["meeting", "time", "today", "week", "call", "people", "guys", "point", "part", "kind", "sort", "way", "lot"].contains(w) { freq[w, default: 0] += 1 }
            return true
        }
        let top = freq.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.prefix(3).map(\.key)
        return top.isEmpty ? "Meeting notes" : "About: " + top.joined(separator: ", ")
    }

    /// The sentences that carry the meeting: most typical content, spread across the beginning, middle and end,
    /// never two that say the same thing. 3–5 of them.
    static func keyPoints(_ sents: [String], limit: Int = 4) -> [String] {
        guard !sents.isEmpty else { return [] }
        var df: [String: Int] = [:]
        for s in sents { for w in Set(contentWords(s)) { df[w, default: 0] += 1 } }
        let scored: [(i: Int, s: String, score: Double)] = sents.enumerated().map { i, s in
            let ws = contentWords(s)
            let len = ws.count
            guard len >= 5 else { return (i, s, 0) }
            let central = ws.reduce(0.0) { $0 + log(1 + Double(df[$1] ?? 0)) } / Double(len)
            let lengthFit = len > 30 ? 0.7 : 1.0                    // very long run-ons read badly as a point
            let question = s.hasSuffix("?") ? 0.6 : 1.0
            return (i, s, central * lengthFit * question)
        }
        // Best of each third, then the best of the rest, never repeating an idea.
        let thirds = stride(from: 0, to: 3, by: 1).map { t in scored.filter { $0.i * 3 / max(1, sents.count) == t } }
        var picked: [(Int, String)] = []
        for t in thirds { if let b = t.max(by: { $0.score < $1.score }), b.score > 0 { picked.append((b.i, b.s)) } }
        for c in scored.sorted(by: { $0.score > $1.score }) where picked.count < limit && c.score > 0 {
            if !picked.contains(where: { $0.0 == c.i || similarity($0.1, c.s) >= 0.4 }) { picked.append((c.i, c.s)) }
        }
        return picked.sorted { $0.0 < $1.0 }.prefix(limit).map { shorten($0.1) }
    }

    /// Keeps a point to about 30 words, at a clause break where it can.
    static func shorten(_ s: String, words: Int = 30) -> String {
        let ws = s.split(separator: " ")
        guard ws.count > words else { return sentence(s) }
        var cut = Array(ws.prefix(words)).joined(separator: " ")
        if let r = cut.range(of: #"[,;:—–] [^,;:—–]*$"#, options: .regularExpression), cut.distance(from: cut.startIndex, to: r.lowerBound) > 40 {
            cut = String(cut[..<r.lowerBound])
        }
        return sentence(cut.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:")) + "…", period: false)
    }

    static func decisions(_ sents: [String]) -> [String] {
        let p = #"\b(we (agreed|decided|'?re going with|will go with)|let'?s go with|decision is|we'?ll go with|agreed to|final(ly)? decided)\b"#
        return dedupe(sents.filter { $0.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil }.map { shorten($0) }, limit: 4)
    }

    private static let actionVerbs: Set<String> = ["do", "send", "share", "email", "call", "review", "update", "schedule", "book", "set", "fix", "finish", "prepare", "draft", "write", "create", "build", "test", "check", "confirm", "follow", "start", "deliver", "submit", "file", "order", "buy", "pay", "invite", "ask", "talk", "meet", "look", "add", "remove", "change", "move", "plan", "organize", "organise", "get", "put", "make", "sort", "finalize", "finalise", "approve", "sign", "publish", "deploy", "release", "ship", "upload", "document", "rebase", "merge", "push", "investigate", "find", "reach", "loop", "circle", "contact", "arrange", "complete", "cancel", "clean", "post", "print", "renew", "register", "install", "configure", "migrate", "present", "demo", "run", "work"]
    /// A clause can start a sentence or follow a comma or "so / and / then" — spoken sentences rarely start clean.
    private static let lead = #"(?:^|[,;:] |\b(?i:so|and|then|but|now|okay|yeah) )"#
    private static let commitment = lead + #"(?<who>[Ii]|[Ww]e|[Yy]ou|[A-Z][a-z]+(?: [A-Z][a-z]+)?)(?i:'ll| will| need to| needs to| have to| has to| should| must|'re going to| are going to| is going to|'m going to| am going to)\s+(?<rest>[^,;]+)"#
    private static let request = lead + #"(?i:can|could|would) (?<who>you|[A-Z][a-z]+) (?:please )?(?<rest>[^,;?]+)"#
    private static let lets = lead + #"(?i:let'?s|please|action item[:,]?|remember to|don'?t forget to) (?<rest>[^,;]+)"#
    /// Words that start a sentence but aren't a person ("This will…", "They should…").
    private static let notPeople: Set<String> = ["this", "that", "it", "there", "which", "what", "he", "she", "they", "everybody", "everyone", "somebody", "someone", "nobody", "then", "yeah", "okay", "so", "and", "but", "now", "here", "who", "whoever", "anyone", "anybody"]
    private static let dueWords = #"\b(?:by |before |on |until |next |this )?(today|tonight|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday|next week|this week|end of (?:the )?(?:day|week|month)|eod|eow|\d{1,2}(?:st|nd|rd|th)? of \w+|(?:january|february|march|april|may|june|july|august|september|october|november|december) \d{1,2})\b"#
    private static let notActions = #"\b(drop (?:off )?(?:another|the) call|hop off|jump off|talk to you|see you|have a (?:good|great|wonderful)|let me know if|i guess|whatever|if you want|you know what i mean)\b"#

    /// Real commitments and requests, rewritten to start with the verb, with who and when where it was said.
    static func commitments(_ sents: [String], limit: Int = 8) -> [Action] {
        var out: [Action] = []
        for s in sents {
            let t = s.trimmingCharacters(in: CharacterSet(charactersIn: " .!"))
            if t.range(of: notActions, options: [.regularExpression, .caseInsensitive]) != nil { continue }
            var who: String?, rest: String?
            for p in [commitment, request, lets] {
                guard let re = try? NSRegularExpression(pattern: p),
                      let m = re.matches(in: t, range: NSRange(t.startIndex..., in: t)).last else { continue }
                // "maybe I'll…", "I might…" — hedged, not a commitment.
                if let start = Range(m.range, in: t)?.lowerBound {
                    let before = t[t.index(start, offsetBy: -min(14, t.distance(from: t.startIndex, to: start)))..<start].lowercased()
                    if before.range(of: #"\b(maybe|probably|might|perhaps|possibly)\b"#, options: .regularExpression) != nil { break }
                }
                if let r = Range(m.range(withName: "rest"), in: t) { rest = String(t[r]) }
                if m.range(withName: "who").location != NSNotFound, let r = Range(m.range(withName: "who"), in: t) { who = String(t[r]) }
                break
            }
            guard var task = rest else { continue }
            if let w = who, notPeople.contains(w.lowercased()) { continue }
            // Hedged or hypothetical ("if", "maybe", "probably") isn't a commitment.
            if task.range(of: #"^(?:maybe|probably|possibly|just|kind of|sort of)\b"#, options: [.regularExpression, .caseInsensitive]) != nil { continue }
            task = task.replacingOccurrences(of: #"^(?:also|then|go ahead and|try to|start to|be able to)\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            guard let first = task.split(separator: " ").first?.lowercased(), actionVerbs.contains(String(first)) else { continue }
            if t.hasSuffix("?") && who?.lowercased() != "you" && !(who?.first?.isUppercase ?? false) { continue }
            var due: String?
            if let r = task.range(of: dueWords, options: [.regularExpression, .caseInsensitive]) {
                due = task[r].replacingOccurrences(of: #"^(by|before|on|until) "#, with: "", options: [.regularExpression, .caseInsensitive])
                task.removeSubrange(r)
            }
            task = task.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: " ,."))
            // "…working on it for" once "this week" came out → "…working on it".
            task = task.replacingOccurrences(of: #"\s+(?:for|by|on|before|until|in|at|to|from)$"#, with: "", options: [.regularExpression, .caseInsensitive])
            let words = task.split(separator: " ")
            guard words.count >= 2 else { continue }
            if words.count > 16 { task = words.prefix(16).joined(separator: " ") + "…" }
            let owner: String? = {
                guard let w = who else { return nil }
                switch w.lowercased() { case "i": return "Me"; case "we": return "Us"; case "you": return nil; default: return w }
            }()
            out.append(Action(task: sentence(task, period: false), owner: owner, due: due.map { sentence($0, period: false) }))
        }
        return dedupe(out, limit: limit)
    }

    // MARK: - The email (pure)

    /// A crisp follow-up: what we covered (3 points at most), what we decided, and next steps with who and when.
    static func email(_ r: Result, people: [String], meeting: String) -> (subject: String, body: String) {
        let topic = r.headline.hasPrefix("About: ") ? String(r.headline.dropFirst(7)) : r.headline
        let subject = "Recap: " + (topic.isEmpty || topic == "Meeting notes" ? meeting : topic)
        var b = (people.isEmpty ? "Hi all," : "Hi " + people.prefix(3).joined(separator: ", ") + ",") + "\n\n"
        b += "Thanks for today. A quick recap:\n"
        for p in r.points.prefix(3) { b += "\n• " + p }
        if !r.decisions.isEmpty {
            b += "\n\nWe agreed:\n"
            for d in r.decisions.prefix(3) { b += "\n• " + d }
        }
        if r.actions.isEmpty {
            b += "\n\nNo action items came up — reply if I missed one."
        } else {
            b += "\n\nNext steps:\n"
            for a in r.actions.prefix(6) {
                var l = "\n• "
                if let o = a.owner, o != "Us" { l += (o == "Me" ? "I'll" : o) + (o == "Me" ? " " + a.task.prefix(1).lowercased() + a.task.dropFirst() : ": " + a.task) }
                else { l += a.task }
                if let d = a.due { l += " — by " + d }
                b += l
            }
            b += "\n\nLet me know if I missed anything."
        }
        b += "\n\nBest,"
        return (subject, b)
    }

    /// Text for reading aloud: no bullets, boxes or symbols (the narrator would say "ballot box").
    static func speakable(_ lines: [String]) -> String {
        lines.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "•☐✓ ")) }
            .map { $0.replacingOccurrences(of: " — ", with: ", ").replacingOccurrences(of: " · ", with: ", ") }
            .map { l in l.hasSuffix(".") || l.hasSuffix("?") || l.hasSuffix("!") ? l : l + "." }
            .joined(separator: " ")
    }
}
