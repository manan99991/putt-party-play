import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// "Describe it": turn a sentence into a chain of built-in blocks. The on-device language model proposes one where
/// the phone has it; a deterministic keyword planner covers every other phone and backs the model up. Whatever comes
/// back is only ever a list of existing block names with settings, and it is validated before anyone sees it, so
/// a description can never run anything that isn't already in the app.
enum ChainPlanner {
    struct Plan { let chain: Chain; let usedModel: Bool }

    static func plan(_ ask: String) async -> Plan? {
        let text = ask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), let c = await modelPlan(text) { return Plan(chain: c, usedModel: true) }
        #endif
        return keywordPlan(text).map { Plan(chain: $0, usedModel: false) }
    }

    // MARK: validation

    /// Accepts only a chain whose steps fit together, trimmed to a sensible length.
    static func validated(_ chain: Chain) -> Chain? {
        var c = chain
        c.steps = Array(c.steps.prefix(8))
        guard let first = c.steps.first, c.problem(starting: first.block.takes) == nil else { return nil }
        return c
    }

    // MARK: keyword planner (works everywhere, unit-tested)

    static func keywordPlan(_ ask: String) -> Chain? {
        let s = " " + ask.lowercased() + " "
        func has(_ words: [String]) -> Bool { words.contains { s.contains($0) } }

        var steps: [ChainStep] = []
        let wantsPhotoInput = has(["photo", "picture", "image", "scan", "screenshot", "snap", "camera", "receipt", "card", "poster", "flyer", "whiteboard", "sign "])

        // Text-making jobs: they start from a picture of the thing, or from pasted text, so read it first when a picture is meant.
        // "Tidy up this photo" is about the picture, so tidying only means text when text is what is being talked about.
        let textish = has(["text", "notes", "words", "list", "lines", "pasted", "paste"])
        let wantsClean = has(["tidy", "clean up", "clean the", "dedupe", "de-dupe", "duplicate line", "remove duplicates", "extra spaces", "blank lines"]) && (!wantsPhotoInput || textish)
        let textJob: Block? =
            has(["scam", "phishing", "fraud", "is this real", "suspicious"]) ? .scamCheck :
            has(["best deal", "cheapest", "cheaper", "unit price", "per unit", "better value"]) ? .priceCompare :
            has(["tracking", "clean link", "clean the link", "clean my link", "utm"]) ? .cleanLinks :
            has(["qr"]) ? .makeQr :
            has(["receipt", "expense", "invoice"]) ? .pullReceipt :
            has(["business card", "contact", "vcard"]) ? .businessCard :
            has(["calendar", "event", "poster", "flyer", "invite", "appointment"]) ? .calendarEvent :
            has(["spreadsheet", "csv", "excel", "table", "columns"]) ? .makeTable :
            has(["links", "urls", "web address", "email address", "phone number"]) ? .pullDetails :
            has(["task", "to-do", "todo", "whiteboard", "action item", "checklist"]) ? .actionItems :
            has(["summar", "tl;dr", "tldr", "shorten", "gist", "key points"]) ? .summarize : nil

        // A running sheet: each receipt becomes one row added to the same list.
        if has(["expense sheet", "expense log", "ledger", "running list", "running sheet", "monthly sheet"]) {
            if wantsPhotoInput || has(["receipt"]) { steps.append(ChainStep(block: .readText)) }
            steps.append(ChainStep(block: .expenseRow))
            steps.append(ChainStep(block: .addToList, settings: ["list": RunningList.defaultName]))
            return build(ask, steps)
        }
        if textJob != nil || wantsClean {
            let needsPhoto = wantsPhotoInput || textJob == .pullReceipt || textJob == .businessCard || textJob == .calendarEvent
            if needsPhoto { steps.append(ChainStep(block: .readText)) }
            // Tidying goes first so the next step sees clean text.
            if wantsClean { steps.append(ChainStep(block: .cleanText)) }
            if let job = textJob {
                var st = ChainStep(block: job)
                if job == .summarize { st.settings["sentences"] = number(near: ["sentence", "line", "point"], in: s).map(String.init) ?? "3" }
                steps.append(st)
            }
            return build(ask, steps)
        }

        // Questions about a picture: the answer is words, so nothing else follows.
        if has(["identify", "what is this", "what's this", "what plant", "what bug", "what breed", "what kind of"]) { return build(ask, [ChainStep(block: .identify)]) }
        if has(["describe", "what's in", "what is in", "what does it show"]) { return build(ask, [ChainStep(block: .describe)]) }

        // Picture jobs, in the order that gives the best result.
        if has(["cut out", "cutout", "remove background", "remove the background", "background", "sticker", "isolate"]) { steps.append(ChainStep(block: .cutout)) }
        if has(["enhance", "sharpen", "improve", "fix the photo", "better quality", "clearer", "brighten"]) { steps.append(ChainStep(block: .enhance)) }
        if has(["blur", "hide", "redact", "private", "faces", "face ", "anonym", "censor"]) { steps.append(ChainStep(block: .hideSensitive)) }
        if has(["passport", "id photo", "visa photo", "headshot size"]) { steps.append(ChainStep(block: .passportPhoto, settings: ["country": "us"])) }
        if has(["watermark"]) { steps.append(ChainStep(block: .watermark, settings: ["text": "For verification only"])) }
        if has(["location", "gps", "exif", "metadata", "safe to share", "safe-to-share", "strip"]) { steps.append(ChainStep(block: .stripLocation)) }
        if has(["35x45", "35 x 45", "pixels", "pixel size", " px"]) { steps.append(ChainStep(block: .resizePhoto, settings: ["size": has(["35x45", "35 x 45"]) ? "413x531" : "600x600"])) }
        if has(["png", "heic", "jpg", "jpeg", "convert", "format"]) {
            let f = s.contains("png") ? "PNG" : s.contains("heic") ? "HEIC" : "JPG"
            steps.append(ChainStep(block: .convertImage, settings: ["format": f]))
        }
        if has(["shrink", "smaller", "compress", "reduce", "under ", " mb", " kb", "email", "upload", "size"]) {
            // "under 50 kb" is common for upload forms; a kilobyte figure wins over the megabyte default.
            if let kb = number(near: ["kb", "kilobyte"], in: s, before: true) {
                steps.append(ChainStep(block: .shrinkImage, settings: ["mb": String(Double(kb) / 1000)]))
            } else {
                let mb = number(near: ["mb", "megabyte"], in: s, before: true) ?? 2
                steps.append(ChainStep(block: .shrinkImage, settings: ["mb": String(mb)]))
            }
        }
        // A PDF comes last: it takes whatever the photo has become.
        if has(["pdf"]) { steps.append(ChainStep(block: .photoPdf)) }
        return build(ask, steps)
    }

    private static func build(_ ask: String, _ steps: [ChainStep]) -> Chain? {
        guard !steps.isEmpty else { return nil }
        // Shrinking is always last: it is the step that fixes the final size.
        var ordered = steps.filter { $0.block != .shrinkImage } + steps.filter { $0.block == .shrinkImage }
        // Keep one conversion at most.
        var seenConvert = false
        ordered = ordered.filter { if $0.block == .convertImage { defer { seenConvert = true }; return !seenConvert }; return true }
        let name = title(from: ask)
        return validated(Chain(id: UUID().uuidString, name: name, steps: ordered))
    }

    private static func title(from ask: String) -> String {
        let t = ask.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        let first = t.prefix(1).uppercased() + t.dropFirst()
        return first.count > 34 ? String(first.prefix(32)) + "…" : String(first)
    }

    /// The number written next to a unit word: "under 3 mb" gives 3, "in 2 sentences" gives 2.
    static func number(near units: [String], in s: String, before: Bool = true) -> Int? {
        for u in units {
            guard let r = s.range(of: u) else { continue }
            let head = s[..<r.lowerBound].reversed().drop { $0 == " " }
            let digits = String(head.prefix { $0.isNumber }.reversed())
            if let n = Int(digits), n > 0 { return n }
        }
        return nil
    }

    // MARK: on-device model

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    @Generable struct PlannedStep {
        @Guide(description: "Exactly one block id from the list in the instructions") var block: String
        @Guide(description: "Optional single setting value: megabytes for shrinkImage, sentence count for summarize, format for convertImage") var value: String?
    }
    @available(iOS 26.0, *)
    @Generable struct PlannedChain {
        @Guide(description: "A short name for the tool, under 30 characters") var name: String
        @Guide(description: "The steps in order, at most 6", .count(1...6)) var steps: [PlannedStep]
    }

    @available(iOS 26.0, *)
    private static func modelPlan(_ ask: String) async -> Chain? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let list = Block.allCases.map { "\($0.rawValue): takes \($0.takes.label), gives \($0.gives.label)" }.joined(separator: "\n")
        let session = LanguageModelSession(instructions: """
        You design small tools for a phone app by chaining the app's built-in blocks. Use only these block ids, \
        each step must be able to accept what the previous step gives:
        \(list)
        Prefer the fewest steps. Never invent a block id.
        """)
        guard let out = try? await session.respond(to: ask, generating: PlannedChain.self).content else { return nil }
        var steps: [ChainStep] = []
        for p in out.steps {
            guard let b = Block(rawValue: p.block) else { return nil }
            var st = ChainStep(block: b)
            switch b {
            case .shrinkImage: st.settings["mb"] = p.value.flatMap(Double.init).map { String($0) } ?? "2"
            case .summarize: st.settings["sentences"] = p.value.flatMap(Int.init).map(String.init) ?? "3"
            case .convertImage: st.settings["format"] = (p.value ?? "JPG").uppercased()
            case .passportPhoto: st.settings["country"] = "us"
            default: break
            }
            steps.append(st)
        }
        return validated(Chain(id: UUID().uuidString, name: String(out.name.prefix(34)), steps: steps))
    }
    #endif
}
