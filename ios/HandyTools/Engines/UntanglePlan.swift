import Foundation

/// Untangle's planner. Turns whatever the person dumped ("Shower, groceries, office work, not feeling
/// well") into a real plan: it reads the situation (unwell? low energy? stuck in bed? short on time?),
/// orders the steps so the day gets easier as it goes, times each one (travel included), adds rests when
/// energy is low, says why each step sits where it does and how it'll feel when it's done, and attaches
/// the right one-tap action (stores or pharmacies on a map, a focus timer, Reminders). Then it keeps up
/// with the person: Done / need more time / skip re-times everything after.
///
/// Pure and deterministic — it works on every iPhone with no model, and it's unit-tested. The on-device
/// model can only polish wording on top; it never decides the plan.
enum UntanglePlan {

    // MARK: - Model

    enum Kind: String, CaseIterable, Codable {
        case care, getUp, hygiene, food, groceries, pharmacy, errand, work, chores, call, exercise, appointment, other
        var icon: String {
            switch self {
            case .care: return "heart.text.square"
            case .getUp: return "sunrise"
            case .hygiene: return "shower"
            case .food: return "fork.knife"
            case .groceries: return "cart"
            case .pharmacy: return "cross.case"
            case .errand: return "bag"
            case .work: return "laptopcomputer"
            case .chores: return "house"
            case .call: return "phone"
            case .exercise: return "figure.walk"
            case .appointment: return "calendar"
            case .other: return "checkmark.circle"
            }
        }
        /// Places this step needs, for the map card (nil = it happens where you are).
        var placeQuery: String? {
            switch self {
            case .groceries: return "grocery store"
            case .pharmacy: return "pharmacy"
            case .errand: return nil
            default: return nil
            }
        }
        var needsTrip: Bool { self == .groceries || self == .pharmacy || self == .errand || self == .appointment }
    }

    enum Detail: String, CaseIterable, Codable { case quick, balanced, detailed
        var title: String { ["Quick & light", "Balanced", "Detailed"][Self.allCases.firstIndex(of: self)!] }
    }
    enum Energy: String, CaseIterable, Codable { case low, normal, high
        var title: String { ["Low energy", "Normal", "Full of energy"][Self.allCases.firstIndex(of: self)!] }
    }
    enum Status: String, Codable { case todo, doing, done, skipped }

    struct Step: Identifiable, Equatable, Codable {
        var id = UUID()
        var title: String
        var kind: Kind
        var minutes: Int
        var tripMinutes: Int = 0            // travel there and back, shown separately and counted in the time
        var why: String
        var feel: String                    // how it'll feel when it's done
        var substeps: [String] = []         // shown in Detailed
        var items: [String] = []            // shopping / pick-up list
        var isRest = false                  // a built-in rest between steps
        var start: Date = .distantPast
        var status: Status = .todo
        var totalMinutes: Int { minutes + tripMinutes }
        var end: Date { start.addingTimeInterval(TimeInterval(totalMinutes * 60)) }
    }

    struct Situation: Equatable {
        var unwell = false
        var lowEnergy = false
        var stuckInBed = false
        var shortOnTime = false
        var energy: Energy { lowEnergy || unwell ? .low : .normal }
    }

    struct Plan: Equatable {
        var steps: [Step]
        var situation: Situation
        var detail: Detail
        var energy: Energy
        var startAt: Date
        var encouragement: String
        var careNote: String?               // "see a doctor if…" — only when unwell
        var finishAt: Date { steps.last(where: { $0.status != .skipped })?.end ?? startAt }
        var totalMinutes: Int { steps.filter { $0.status != .skipped }.reduce(0) { $0 + $1.totalMinutes } }
        var remaining: [Step] { steps.filter { $0.status == .todo || $0.status == .doing } }
        var progress: Double {
            let real = steps.filter { !$0.isRest && $0.status != .skipped }
            guard !real.isEmpty else { return 0 }
            return Double(real.filter { $0.status == .done }.count) / Double(real.count)
        }
    }

    // MARK: - Reading the dump

    private static let unwellWords = ["not feeling well", "not well", "sick", "unwell", "ill", "fever", "cold", "flu", "headache",
                                      "migraine", "cough", "sore throat", "nausea", "throwing up", "stomach", "pain", "hurts", "under the weather"]
    private static let lowWords = ["tired", "exhausted", "no energy", "drained", "lazy", "can't be bothered", "unmotivated",
                                   "overwhelmed", "low", "burnt out", "burned out", "sleepy", "don't feel like"]
    private static let bedWords = ["get out of bed", "can't get up", "cant get up", "in bed", "stay in bed", "still in bed", "get up"]
    private static let rushWords = ["asap", "hurry", "rush", "only have", "short on time", "quick", "in an hour", "before work"]

    /// Words that are a state, not a task — they shape the plan but don't become a step.
    static func isStateLine(_ s: String) -> Bool {
        let states = unwellWords + lowWords + bedWords + ["feeling", "i feel", "mood"]
        let taskVerbs = ["buy", "get", "pick up", "call", "book", "clean", "finish", "send", "pay", "shower", "cook", "go to", "take", "make", "do"]
        let l = s.lowercased()
        if has(l, bedWords) && l.split(separator: " ").count <= 7 { return true }   // "can't get out of bed" is a state
        return has(l, states) && !has(l, taskVerbs) && l.split(separator: " ").count <= 6
    }

    /// Whole-word / whole-phrase match, so "low" doesn't fire on "follow" and "ill" not on "pillow".
    static func has(_ text: String, _ words: [String]) -> Bool {
        let l = " " + text.lowercased().replacingOccurrences(of: "’", with: "'") + " "
        return words.contains { w in
            l.range(of: "(?<![a-z])\(NSRegularExpression.escapedPattern(for: w))(?![a-z])", options: .regularExpression) != nil
        }
    }

    static func situation(of text: String) -> Situation {
        var s = Situation()
        s.unwell = has(text, unwellWords)
        s.lowEnergy = has(text, lowWords)
        s.stuckInBed = has(text, bedWords)
        s.shortOnTime = has(text, rushWords)
        return s
    }

    static func kind(of task: String) -> Kind {
        let l = task.lowercased()
        func any(_ ws: [String]) -> Bool { has(l, ws) }
        if any(["pharmacy", "medicine", "medication", "meds", "prescription", "tylenol", "ibuprofen", "advil", "chemist", "cvs", "walgreens"]) { return .pharmacy }
        if any(["grocery", "groceries", "supermarket", "milk", "eggs", "bread", "vegetables", "costco", "walmart", "trader joe", "aldi", "food shopping", "shopping list", "fruit", "veggies"]) { return .groceries }
        if any(["shower", "bath", "bathe", "brush teeth", "get dressed", "shave", "wash hair", "skincare"]) { return .hygiene }
        if any(["breakfast", "lunch", "dinner", "cook", "cooking", "eat", "meal", "meals", "snack"]) { return .food }
        if any(["office", "work", "email", "emails", "report", "meeting prep", "deck", "presentation", "deadline", "project", "homework", "study"]) { return .work }
        if any(["clean", "cleaning", "laundry", "dishes", "vacuum", "tidy", "trash", "bins", "declutter", "organize"]) { return .chores }
        if any(["call", "phone", "ring", "text", "reply to"]) { return .call }
        if any(["gym", "walk", "run", "workout", "running", "yoga", "stretch", "exercise"]) { return .exercise }
        if any(["doctor", "dentist", "appointment", "clinic", "vet", "haircut", "bank", "post office", "dmv"]) { return .appointment }
        if any(["buy", "pick up", "return", "drop off", "store", "mall", "errand", "errands", "shop", "shopping"]) { return .errand }
        return .other
    }

    /// Like ThinkingEngine.split, but a line with a colon ("groceries: milk, eggs") stays one task.
    static func splitKeepingLists(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).flatMap { line -> [String] in
            let l = String(line)
            return l.contains(":") ? [l] : ThinkingEngine.split(l)
        }
        .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Items in "groceries: milk, eggs" / "buy milk and eggs".
    static func items(in task: String) -> [String] {
        var t = task
        if let r = t.range(of: ":") { t = String(t[r.upperBound...]) }
        else if let r = t.range(of: #"\b(buy|get|pick up)\b"#, options: [.regularExpression, .caseInsensitive]) { t = String(t[r.upperBound...]) }
        else { return [] }
        return t.replacingOccurrences(of: " and ", with: ",")
            .split(whereSeparator: { ",;/".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .filter { !$0.isEmpty && $0.count < 40 }
    }

    // MARK: - Building

    static func make(from text: String, detail: Detail = .balanced, energy override: Energy? = nil,
                     start: Date = Date(), tripMinutes: Int = 15) -> Plan {
        let sit = situation(of: text)
        let energy = override ?? sit.energy
        var lines = splitKeepingLists(text).filter { !isStateLine($0) }
        if lines.isEmpty, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isStateLine(text) { lines = [text] }

        var steps: [Step] = lines.map { line in
            let k = kind(of: line)
            var s = Step(title: tidy(line), kind: k, minutes: minutes(for: k, detail: detail, energy: energy),
                         why: "", feel: feel(for: k), substeps: substeps(for: k), items: items(in: line))
            if k.needsTrip { s.tripMinutes = tripMinutes * 2 }
            return s
        }
        // Not well → care comes first, and medicine becomes part of any trip out.
        if sit.unwell {
            steps.insert(Step(title: "Rest, water and something light to eat", kind: .care, minutes: energy == .low ? 20 : 15,
                              why: "Your body's asking for it — everything after goes easier on a little fuel.",
                              feel: "A bit steadier, and ready for the next small thing.",
                              substeps: ["A full glass of water", "Something light — toast, fruit, soup", "Sit or lie down for a few minutes"]), at: 0)
            if !steps.contains(where: { $0.kind == .pharmacy }) {
                if let g = steps.firstIndex(where: { $0.kind == .groceries || $0.kind == .errand }) {
                    steps[g].substeps.append("While you're out: the pharmacy aisle for anything you need")
                    if !steps[g].items.contains(where: { $0.lowercased().contains("medicine") }) { steps[g].items.append("Anything from the pharmacy aisle") }
                }
            }
        }
        if sit.stuckInBed || (energy == .low && !steps.isEmpty) {
            steps.insert(Step(title: "Two-minute start", kind: .getUp, minutes: 2,
                              why: "The hardest part is the first move — this one is tiny on purpose.",
                              feel: "You're up. That was the hardest step of the day.",
                              substeps: ["Sit up and put your feet on the floor", "Open the curtains — let light in",
                                         "Three slow breaths", "Stand up and stretch your arms up once"]), at: 0)
        }
        steps = order(steps, energy: energy)
        for i in steps.indices { steps[i].why = steps[i].why.isEmpty ? why(steps[i], index: i, all: steps, energy: energy) : steps[i].why }
        steps = withRests(steps, energy: energy, detail: detail)
        if detail == .quick { for i in steps.indices { steps[i].substeps = [] } }
        if detail == .balanced { for i in steps.indices { steps[i].substeps = Array(steps[i].substeps.prefix(2)) } }

        var plan = Plan(steps: steps, situation: sit, detail: detail, energy: energy, startAt: start,
                        encouragement: encouragement(sit, energy: energy, count: steps.filter { !$0.isRest }.count),
                        careNote: sit.unwell ? careNote : nil)
        retime(&plan, from: start)
        return plan
    }

    /// Order so the day gets easier as it goes: getting up → care → feeling human (hygiene, food) → trips out
    /// while you still have energy (one combined trip) → focused work → the rest.
    static func order(_ steps: [Step], energy: Energy) -> [Step] {
        let rank: [Kind: Int] = energy == .low
            ? [.getUp: 0, .care: 1, .hygiene: 2, .food: 3, .pharmacy: 4, .groceries: 5, .errand: 6, .appointment: 6, .call: 7, .work: 8, .chores: 9, .exercise: 10, .other: 9]
            : [.getUp: 0, .care: 1, .hygiene: 2, .food: 3, .appointment: 4, .work: 5, .call: 6, .pharmacy: 7, .groceries: 8, .errand: 8, .chores: 9, .exercise: 10, .other: 9]
        let sorted = steps.enumerated().sorted { a, b in
            let ra = rank[a.element.kind] ?? 9, rb = rank[b.element.kind] ?? 9
            return ra == rb ? a.offset < b.offset : ra < rb
        }.map(\.element)
        // Trips next to each other share one drive: only the first leg out and the last leg home count.
        var out = sorted
        var i = 0
        while i < out.count {
            if out[i].kind.needsTrip, i + 1 < out.count, out[i + 1].kind.needsTrip {
                let legs = out[i].tripMinutes / 2
                out[i].tripMinutes = legs                 // out, no drive home
                out[i + 1].tripMinutes = max(legs, out[i + 1].tripMinutes / 2) // short hop + home
                out[i + 1].why = "Right after the last stop — one trip instead of two."
            }
            i += 1
        }
        return out
    }

    static func withRests(_ steps: [Step], energy: Energy, detail: Detail) -> [Step] {
        guard energy == .low, steps.count > 2 else { return steps }
        var out: [Step] = []
        for (i, s) in steps.enumerated() {
            out.append(s)
            let next = i + 1 < steps.count ? steps[i + 1] : nil
            if let n = next, s.kind != .getUp, (s.totalMinutes >= 15 || n.kind.needsTrip) {
                out.append(Step(title: "Short rest", kind: .care, minutes: 10, why: "Pacing yourself is how the whole list gets done.",
                                feel: "Recharged for the next one.", isRest: true))
            }
        }
        return out
    }

    /// Set every start time from `now`, skipping finished/skipped steps.
    static func retime(_ plan: inout Plan, from now: Date) {
        var t = now
        for i in plan.steps.indices {
            switch plan.steps[i].status {
            case .done, .skipped: continue
            case .todo, .doing:
                plan.steps[i].start = t
                t = plan.steps[i].end
            }
        }
    }

    // MARK: - Keeping up ("On track?")

    static func markDone(_ plan: inout Plan, _ id: UUID, now: Date = Date()) {
        guard let i = plan.steps.firstIndex(where: { $0.id == id }) else { return }
        plan.steps[i].status = .done
        retime(&plan, from: now)
    }
    static func skip(_ plan: inout Plan, _ id: UUID, now: Date = Date()) {
        guard let i = plan.steps.firstIndex(where: { $0.id == id }) else { return }
        plan.steps[i].status = .skipped
        retime(&plan, from: now)
    }
    /// "Need 10 more minutes" — the step grows and everything after slides.
    static func extend(_ plan: inout Plan, _ id: UUID, by minutes: Int, now: Date = Date()) {
        guard let i = plan.steps.firstIndex(where: { $0.id == id }) else { return }
        plan.steps[i].minutes += minutes
        plan.steps[i].status = .doing
        let from = min(now, plan.steps[i].start)
        retime(&plan, from: from)
    }
    static func move(_ plan: inout Plan, from: IndexSet, to: Int, now: Date = Date()) {
        var s = plan.steps
        let moving = from.sorted().map { s[$0] }
        for i in from.sorted(by: >) { s.remove(at: i) }
        let dest = min(to - from.filter { $0 < to }.count, s.count)
        s.insert(contentsOf: moving, at: max(0, dest))
        plan.steps = s
        retime(&plan, from: now)
    }

    // MARK: - Wording (pure)

    static func tidy(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;-•")))
        guard let f = t.first else { return t }
        return f.uppercased() + t.dropFirst()
    }

    static func minutes(for k: Kind, detail: Detail, energy: Energy) -> Int {
        let base: [Kind: Int] = [.care: 15, .getUp: 2, .hygiene: 15, .food: 20, .groceries: 35, .pharmacy: 15, .errand: 25,
                                 .work: 60, .chores: 25, .call: 10, .exercise: 30, .appointment: 45, .other: 20]
        var m = Double(base[k] ?? 20)
        if energy == .low, k == .work || k == .chores || k == .exercise { m *= 0.75 }   // smaller, doable chunks
        if detail == .quick { m *= 0.85 }
        return max(2, Int((m / 5).rounded()) * 5)
    }

    static func feel(for k: Kind) -> String {
        switch k {
        case .care: return "A bit steadier, and ready for the next small thing."
        case .getUp: return "You're up. That was the hardest step of the day."
        case .hygiene: return "Fresh and more like yourself — this one lifts the whole day."
        case .food: return "Fuelled. Focus comes back after you eat."
        case .groceries: return "Fridge stocked — one less thing on your mind all week."
        case .pharmacy: return "You've got what you need to feel better."
        case .errand: return "Done and off the list."
        case .work: return "The work weight is lighter, and you can stop thinking about it."
        case .chores: return "A calmer space — you'll notice it every time you walk in."
        case .call: return "That's off your mind."
        case .exercise: return "Clearer head and more energy, even after a short one."
        case .appointment: return "Handled."
        case .other: return "One more thing done."
        }
    }

    static func substeps(for k: Kind) -> [String] {
        switch k {
        case .hygiene: return ["Warm water, not hot, if you're unwell", "Clean, comfy clothes after", "Drink a glass of water"]
        case .groceries: return ["Check the fridge and write the list first", "Go to the nearest store — the map below shows them", "Easy foods if you're unwell: soup, fruit, crackers, tea"]
        case .pharmacy: return ["Ask the pharmacist what suits your symptoms", "Check what you already have at home first"]
        case .work: return ["Pick the ONE thing that matters most today", "Phone face-down, start a focus timer", "Stop at a natural break and note where you left off"]
        case .chores: return ["Set a timer — stop when it rings", "Start with the spot you see most"]
        case .food: return ["Keep it simple", "Water with it"]
        case .call: return ["Jot the one thing you need from the call"]
        case .exercise: return ["Easy pace — a short walk counts"]
        case .appointment: return ["Bring ID, card and anything they asked for", "Leave 10 minutes early"]
        default: return []
        }
    }

    static func why(_ s: Step, index: Int, all: [Step], energy: Energy) -> String {
        switch s.kind {
        case .getUp: return "The hardest part is the first move — this one is tiny on purpose."
        case .care: return "Your body first — everything after goes easier."
        case .hygiene: return index <= 2 ? "A shower early resets how you feel for everything after it." : "A reset before the next stretch."
        case .food: return "Eat before the bigger tasks so your energy holds."
        case .groceries, .pharmacy, .errand:
            return energy == .low ? "Go while you still have the energy — and get it done in one trip." : "One trip, at a time stores are open and calm."
        case .work: return energy == .low ? "Once the basics are done, your head is clearer for work. A shorter block — it still counts." : "Your best focus block, with the small stuff out of the way first."
        case .chores: return "Lighter task for when energy dips."
        case .call: return "Quick win between bigger tasks."
        case .exercise: return "Leaves you with more energy for the evening."
        case .appointment: return "Fixed time — the rest fits around it."
        case .other: return "Fits here without blocking anything else."
        }
    }

    static func encouragement(_ s: Situation, energy: Energy, count: Int) -> String {
        if s.unwell { return "You don't have to do it all at full speed today. Small steps, rest in between — doing it gently still gets it done." }
        if s.stuckInBed { return "Just the two-minute start. Nothing else yet. Once you're up, the next step is waiting and it's small." }
        if energy == .low { return "Low days count too. \(count) small steps, one at a time — you only ever have to do the next one." }
        if s.shortOnTime { return "Tight on time, so it's ordered for speed — the must-dos first." }
        return "\(count) steps, in the order that makes the rest easier. Start with the first one and let the plan carry you."
    }

    /// Plain safety signs — never a diagnosis or dosing advice.
    static let careNote = "Not a diagnosis. Call your doctor or go to urgent care if you have trouble breathing, chest pain, a high fever that won't come down, you can't keep fluids down, or you're getting worse or not better after a few days. In an emergency, call your local emergency number."

    // MARK: - Share text

    static func text(_ p: Plan) -> String {
        let tf = DateFormatter(); tf.timeStyle = .short; tf.dateStyle = .none
        var lines = ["My plan · \(p.totalMinutes / 60 > 0 ? "\(p.totalMinutes / 60)h " : "")\(p.totalMinutes % 60)m · done by \(tf.string(from: p.finishAt))", ""]
        for s in p.steps where s.status != .skipped {
            let mark = s.status == .done ? "✓" : "○"
            lines.append("\(mark) \(tf.string(from: s.start))  \(s.title) — \(s.totalMinutes) min\(s.tripMinutes > 0 ? " incl. travel" : "")")
            for it in s.items { lines.append("     • \(it)") }
        }
        return lines.joined(separator: "\n")
    }
}
