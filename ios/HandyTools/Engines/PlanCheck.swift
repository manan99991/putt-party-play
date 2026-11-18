import Foundation

/// "Describe it" honesty check. Reads what a request actually needs (reminders, a spreadsheet, a photo to start
/// from, weather…), checks a planned tool against it, and says plainly what's covered, what isn't, and when
/// Tenzy already has a full tool that does the job better. Pure and unit-tested — the planner uses it to throw
/// out a plan that doesn't match the request, and the editor uses it to warn instead of pretending.
enum PlanCheck {
    enum Need: String, CaseIterable {
        // Things a custom tool can do
        case tasks, reminders, calendar, spreadsheet, email, message, translate, summary, pdfOut
        case photoIn, videoIn, audioIn, pdfIn
        // Things a custom tool can't do (yet)
        case weather, maps, web, money

        var label: String {
            switch self {
            case .tasks: return "a to-do list"
            case .reminders: return "reminders"
            case .calendar: return "calendar events"
            case .spreadsheet: return "a spreadsheet"
            case .email: return "sending an email"
            case .message: return "sending a message"
            case .translate: return "translating"
            case .summary: return "a summary"
            case .pdfOut: return "a PDF"
            case .photoIn: return "starting from a photo"
            case .videoIn: return "starting from a video"
            case .audioIn: return "starting from a recording"
            case .pdfIn: return "starting from a PDF"
            case .weather: return "weather"
            case .maps: return "maps and directions"
            case .web: return "looking things up online"
            case .money: return "payments or bank accounts"
            }
        }
        var supported: Bool { ![.weather, .maps, .web, .money].contains(self) }
    }

    private static let words: [Need: [String]] = [
        .tasks: ["to do", "to-do", "todo", "task", "tasks", "things i need to do", "need to do", "organize my day", "organise my day",
                 "plan my day", "my day", "checklist", "chores", "errands"],
        .reminders: ["remind", "reminder", "reminders", "alert me", "alarm", "nudge me", "notify me", "don't forget", "dont forget"],
        .calendar: ["calendar", "event", "appointment", "meeting invite"],
        .spreadsheet: ["spreadsheet", "excel", "csv", "table", "sheet"],
        .email: ["email it", "email them", "email to", "send an email", "by email", "mail it"],
        .message: ["text it", "message it", "send a message", "imessage", "whatsapp it"],
        .translate: ["translat"],
        .summary: ["summar", "gist", "key points", "tl;dr", "shorten"],
        .pdfOut: ["into a pdf", "to pdf", "as a pdf", "make a pdf", "into one pdf"],
        .photoIn: ["photo", "picture", "image", "screenshot", "scan", "receipt", "camera", "selfie", "poster", "flyer", "whiteboard",
                   "card", "menu", "sign", "document", "page", "snap", "pic", "foto", "meme", "sticker", "gif", "slideshow", "collage"],
        .videoIn: ["video", "clip", "movie", "footage"],
        .audioIn: ["recording", "voice memo", "audio", "podcast"],
        .pdfIn: ["pdf"],
        .weather: ["weather", "forecast", "rain", "temperature"],
        .maps: ["directions", "near me", "nearby", "route", "navigate", "map"],
        .web: ["search the web", "look up online", "online price", "google it", "browse"],
        .money: ["pay ", "payment", "bank", "transfer money", "stock price"],
    ]

    static func needs(_ ask: String) -> [Need] {
        let s = " " + ask.lowercased().replacingOccurrences(of: "’", with: "'") + " "
        var out: [Need] = []
        for n in Need.allCases {
            guard let ws = words[n] else { continue }
            if ws.contains(where: { w in
                s.range(of: "(?<![a-z])\(NSRegularExpression.escapedPattern(for: w))", options: .regularExpression) != nil
            }) { out.append(n) }
        }
        // "a PDF" said as the thing you end up with isn't a PDF you start from.
        if out.contains(.pdfOut) { out.removeAll { $0 == .pdfIn } }
        return out
    }

    static func covers(_ n: Need, _ c: Chain) -> Bool {
        let blocks = Set(c.steps.map(\.block))
        let start = c.steps.first?.block.takes
        switch n {
        case .tasks: return blocks.contains(.actionItems)
        case .reminders: return blocks.contains(.actionItems) || blocks.contains(.calendarEvent) || blocks.contains(.returnBy) || c.schedule != nil
        case .calendar: return blocks.contains(.calendarEvent)
        case .spreadsheet: return !blocks.isDisjoint(with: [.makeTable, .expenseRow, .addToList])
        case .email: return c.finish?.kind == .mail
        case .message: return c.finish?.kind == .message
        case .translate: return blocks.contains(.translate)
        case .summary: return blocks.contains(.summarize)
        case .pdfOut: return !blocks.isDisjoint(with: [.photoPdf, .textPdf]) || c.combine == true
        case .photoIn: return start == .image || start == .photoFile
        case .videoIn: return start == .video
        case .audioIn: return start == .audio || blocks.contains(.videoAudio)
        case .pdfIn: return start == .pdf
        case .weather, .maps, .web, .money: return false
        }
    }

    /// The tool starts from a kind of thing the request never mentions (a photo, when only text was talked about).
    static func startConflict(_ ask: String, _ c: Chain) -> Bool {
        guard let start = c.steps.first?.block.takes else { return false }
        let n = Set(needs(ask))
        switch start {
        case .image, .photoFile: return !n.contains(.photoIn) && (n.contains(.tasks) || n.contains(.reminders) || n.isDisjoint(with: [.translate, .summary, .pdfOut, .spreadsheet]))
                                       && !n.isEmpty
        case .video: return !n.contains(.videoIn) && !n.isEmpty
        case .audio: return !n.contains(.audioIn) && !n.contains(.videoIn) && !n.isEmpty
        case .pdf: return !n.contains(.pdfIn) && !n.isEmpty
        case .text, .file: return false
        }
    }

    /// How well a tool matches what was asked: needs met, minus the ones it misses, minus a lot for starting
    /// from the wrong kind of thing. Used to choose between the rules' plan and the model's.
    static func score(_ ask: String, _ c: Chain) -> Int {
        let n = needs(ask).filter(\.supported)
        let met = n.filter { covers($0, c) }.count
        return met * 2 - (n.count - met) - (startConflict(ask, c) ? 5 : 0)
    }

    static func missing(_ ask: String, _ c: Chain) -> [Need] {
        needs(ask).filter { !covers($0, c) }
    }

    // MARK: - A full tool that already does this

    struct BuiltIn: Equatable { let id: String; let name: String; let why: String }

    static func builtIn(_ ask: String) -> BuiltIn? {
        let s = " " + ask.lowercased() + " "
        func has(_ ws: [String]) -> Bool { ws.contains { s.contains($0) } }
        let n = Set(needs(ask))
        if has(["medicine", "medication", "meds", " pill", "pills", "dose", "tablet"]), n.contains(.reminders) || has(["take my", "schedule"]) {
            return BuiltIn(id: "medreminder", name: "Med Reminders", why: "Reminds you at each dose time, with Taken / Snooze right from the alert, and keeps a log.")
        }
        if n.contains(.tasks) || (n.contains(.reminders) && !n.contains(.photoIn) && !n.contains(.calendar)) || has(["overwhelmed", "organize my", "organise my", "plan my", "schedule my day"]) {
            return BuiltIn(id: "untangle", name: "Untangle",
                           why: "Turns everything on your plate into a timed plan for your day — around how you feel — with a check-in as each step starts and every task added to Reminders with alerts.")
        }
        if has(["meeting notes", "record a meeting", "record my meeting", "minutes of"]) {
            return BuiltIn(id: "meetingnotes", name: "Meeting Notes", why: "Records the meeting, writes it out by speaker and pulls out the action items.")
        }
        if has(["best photo", "best picture", "better photos", "take a photo of the sunset", "camera settings"]) {
            return BuiltIn(id: "procam", name: "Pro Camera", why: "Picks the best camera settings for what you're pointing at.")
        }
        return nil
    }

    /// The line shown at the top of the editor: what's covered, and what this tool can't do.
    static func report(_ ask: String, _ c: Chain) -> (good: [String], gaps: [String]) {
        let n = needs(ask)
        let good = n.filter { $0.supported && covers($0, c) && ![.photoIn, .videoIn, .audioIn, .pdfIn].contains($0) }.map(\.label)
        let gaps = missing(ask, c).map(\.label)
        return (good, gaps)
    }
}
