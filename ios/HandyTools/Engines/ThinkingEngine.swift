import Foundation

/// The structuring thinking tools that need no language model, so they deliver the same on every phone
/// (iOS and Android alike, where there is no on-device LLM): Clear My Head and My Day. Both turn a
/// brain-dump into clean, deduped tasks, each already routed to its apps (via `ThinkingActions`) and given
/// a concrete due time where it has one. Pure and deterministic; the Android twin (`ThinkingEngine.kt`)
/// uses the same rules. The language-model tools (Untangle, Crossroads, Plain, Reword, Prep) sit behind a
/// separate engine with the on-device model on iOS and a lighter fallback on Android.
enum ThinkingEngine {
    /// One task pulled from a dump: its words, the apps it flows into, and when it's due (if ever).
    struct Task: Equatable {
        let text: String
        let actions: ThinkingActions.Plan
        let due: Date?
    }

    /// Split a brain-dump into candidate task lines — by line first, then by comma/semicolon within a line,
    /// so both "one per line" and "a, b, c" dumps work. Trimmed, blanks dropped.
    static func split(_ dump: String) -> [String] {
        dump.split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            .flatMap { $0.split(whereSeparator: { $0 == "," || $0 == ";" }) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Dump → unique enriched tasks (case-insensitive dedupe, first kept), in the order dumped.
    static func tasks(from dump: String, now: Date = Date(), calendar: Calendar = .current) -> [Task] {
        var seen = Set<String>()
        var out: [Task] = []
        for line in split(dump) where seen.insert(line.lowercased()).inserted {
            out.append(Task(text: line,
                            actions: ThinkingActions.plan(for: line),
                            due: ThinkingActions.dueDate(from: line, now: now, calendar: calendar)))
        }
        return out
    }

    /// Clear My Head: the tasks, deduped, in the order they came out.
    static func clearMyHead(_ dump: String, now: Date = Date(), calendar: Calendar = .current) -> [Task] {
        tasks(from: dump, now: now, calendar: calendar)
    }

    /// My Day: the same tasks laid out by time — the ones with a due time in order, then the rest.
    static func myDay(_ dump: String, now: Date = Date(), calendar: Calendar = .current) -> [Task] {
        let all = tasks(from: dump, now: now, calendar: calendar)
        let timed = all.filter { $0.due != nil }.sorted { $0.due! < $1.due! }
        return timed + all.filter { $0.due == nil }
    }

    /// How loudly a task wants attention — the adaptive behaviour the thinking tools were asked for: a real
    /// deadline is flagged plainly, a soft-but-actionable task earns a gentle nudge, and a trivial or vague
    /// line stays quiet so the list never nags. Pure and deterministic; the Android twin uses the same rules.
    enum Urgency: String { case deadline, nudge, quiet }

    /// A short, everyday set of action verbs — a line that has one and some substance is worth a nudge even
    /// without a date; a bare fragment ("milk", "that thing") stays quiet.
    static let actionVerbs: Set<String> = [
        "email", "send", "pay", "book", "buy", "get", "pick", "finish", "fix", "write", "reply", "submit",
        "renew", "cancel", "schedule", "order", "return", "print", "sign", "review", "ask", "check", "clean",
        "update", "plan", "prepare", "file", "draft", "confirm", "call", "text", "message", "follow",
    ]

    /// Classify one task: dated → deadline; a place/call or a real action verb with substance → nudge; else quiet.
    static func urgency(for task: Task) -> Urgency {
        if task.due != nil { return .deadline }
        if task.actions.isCall || task.actions.place != nil { return .nudge }
        let words = task.text.split(whereSeparator: { !$0.isLetter }).map { $0.lowercased() }
        if words.contains(where: { actionVerbs.contains($0) }) { return .nudge }
        return .quiet
    }
}
