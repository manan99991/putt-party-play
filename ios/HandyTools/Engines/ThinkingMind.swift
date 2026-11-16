import Foundation

/// The five thinking tools that reason with the on-device model (Untangle, Crossroads, Plain, Reword,
/// Prep). Each is just a well-chosen instruction + a prompt built from the user's input, run through
/// `AIEngine` (Apple's on-device model, iOS 26+, nothing leaves the phone). The instruction/prompt
/// builders are pure and unit-tested so the product's "think a step deeper" wording is pinned; the model
/// call itself is device-only. When the model isn't available (older iPhone) the caller shows the
/// fallback, and Clear My Head + My Day (in `ThinkingEngine`) still work with no model at all.
enum ThinkingMind {
    enum Tool: String, CaseIterable { case untangle, crossroads, plain, reword, prep }

    static var isAvailable: Bool { AIEngine.isAvailable }
    static var availabilityReason: String { AIEngine.availabilityReason }

    /// The role/instruction for a tool — what the model is told to be. Smart defaults baked in, options
    /// (the explain level, the reword tone) fold in where given. Pure.
    static func instructions(for tool: Tool, options: [String: String] = [:]) -> String {
        switch tool {
        case .untangle:
            return """
            You turn one overwhelming task into a short, ordered list of concrete next steps a person can actually do. \
            Give 3–7 steps, each a short imperative line, in the order that unblocks the rest — put the step everything \
            else depends on first. Add a rough time in minutes to each step. If the task has a real deadline, call it out. \
            Reply with only the numbered steps, nothing else.
            """
        case .crossroads:
            return """
            You help someone make one decision clearly. Give three honest pros and three honest cons, then a single \
            recommendation line that begins "Lean yes:" or "Lean no:" with one sentence of reasoning. Be balanced and \
            concrete; never sit on the fence without a lean. Keep it short.
            """
        case .plain:
            let level = explainLevel(options["level"])
            return "You explain things in plain, everyday words for \(level). No jargon, no preamble. 3–5 short sentences. If the input is a question, answer it; if it's a passage, explain what it means."
        case .reword:
            let tone = rewordTone(options["tone"])
            return "You rewrite the user's message in a \(tone) tone while keeping its meaning and any names, times and facts. Reply with only the rewritten message — no options, no notes."
        case .prep:
            return """
            You help someone get ready for something (a meeting, a trip, an appointment, an interview). Give a short \
            checklist of what to bring or do, then 3 good questions to ask or things to confirm while there. Keep each \
            line short and practical. Reply with the checklist then the questions, nothing else.
            """
        }
    }

    /// The prompt — the user's own content, lightly framed. Pure.
    static func prompt(for tool: Tool, input: String, options: [String: String] = [:]) -> String {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        switch tool {
        case .untangle:   return "Task: \(t)"
        case .crossroads: return "Decision: \(t)"
        case .plain:      return t
        case .reword:     return t
        case .prep:       return "Getting ready for: \(t)"
        }
    }

    /// Run a tool through the on-device model. Throws `AIEngine.AIError.unavailable` when there's no model,
    /// so the screen falls back instead of dead-ending.
    static func think(_ tool: Tool, input: String, options: [String: String] = [:]) async throws -> String {
        try await AIEngine.run(instructions: instructions(for: tool, options: options),
                               prompt: prompt(for: tool, input: input, options: options))
    }

    // MARK: - option wording (pure)

    static func explainLevel(_ raw: String?) -> String {
        switch raw {
        case "kid": return "a curious 8-year-old"
        case "teen": return "a teenager"
        case "expert": return "someone who knows the field and wants the precise version"
        default: return "a curious adult"      // the smart default
        }
    }

    static func rewordTone(_ raw: String?) -> String {
        switch raw {
        case "formal": return "polite and professional"
        case "shorter": return "much shorter and to the point"
        case "firmer": return "firm and direct but still polite"
        default: return "warmer and friendlier"  // the smart default
        }
    }
}
