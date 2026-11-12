import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// "Describe it": turn a sentence into a chain of built-in blocks. The on-device language model proposes one where
/// the phone has it; a deterministic keyword planner covers every other phone and backs the model up. Whatever comes
/// back is only ever a list of existing block names with settings, and it is validated before anyone sees it, so
/// a description can never run anything that isn't already in the app.
enum ChainPlanner {
    /// `guessed`: the words didn't say enough to be sure, so this is the closest sensible tool rather than an exact match.
    struct Plan { let chain: Chain; let usedModel: Bool; var guessed = false }

    /// The rules go first: they are the same on every phone and understand misspelt and half-finished requests. Only
    /// when they are unsure does the on-device model get a try, and if it has nothing either, the best guess is used.
    static func plan(_ ask: String) async -> Plan? {
        let text = ask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let g = guess(text)
        if let g, g.sure { return Plan(chain: g.chain, usedModel: false) }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), let c = await modelPlan(PlannerWords.tidy(text)) { return Plan(chain: c, usedModel: true) }
        #endif
        return g.map { Plan(chain: $0.chain, usedModel: false, guessed: true) }
    }

    /// The tool for a sentence, and whether the sentence said enough to be sure of it.
    static func guess(_ ask: String) -> (chain: Chain, sure: Bool)? {
        let clean = PlannerWords.tidy(ask)
        var found = rules(clean).map { (chain: $0, sure: true) } ?? fallback(clean).map { (chain: $0, sure: false) }
        guard var c = found?.chain else { return nil }
        if c.finish == nil { c.finish = ending(clean) }
        // A short request is its own best name; a long one gets a name from what the tool does. A starter keeps its name.
        if found?.sure == true || c.name.isEmpty { c.name = ChainText.toolName(ask: ask, chain: c) }
        found?.chain = c
        return found
    }

    /// "…and email it" / "…then text it": how the tool should end, when the sentence says. nil leaves it at Save or share.
    static func ending(_ clean: String) -> ChainFinish? {
        let s = " " + clean + " "
        func has(_ words: [String]) -> Bool { words.contains { s.contains($0) } }
        if has(["email"]), !has(["email address", "emails", "email and phone", "find the email"]) { return ChainFinish(kind: .mail, to: "") }
        if has(["text it", "message it", "imessage", " sms", "by text", "as a message", "send a message"]) { return ChainFinish(kind: .message, to: "") }
        return nil
    }

    /// When no rule fits: the starter whose name shares a word with the request, or else the most useful tool for
    /// whatever kind of thing was mentioned. nil only when the request names nothing Tenzy works with.
    static func fallback(_ clean: String) -> Chain? {
        let s = " " + clean + " "
        func has(_ words: [String]) -> Bool { words.contains { s.contains($0) } }
        let words = PlannerWords.words(clean).filter { $0.count >= 4 && !PlannerWords.plain.contains($0) }
        var best: Chain?, bestScore = 0
        for t in ChainTemplates.all {
            let name = PlannerWords.words(t.name.lowercased())
            let score = words.filter { w in name.contains { n in n == w || (n.count >= 5 && w.count >= 5 && PlannerWords.distance(n, w, limit: 1) <= 1) } }.count
            if score > bestScore { best = t; bestScore = score }
        }
        if var c = best { c.id = UUID().uuidString; return validated(c) }
        var steps: [ChainStep] = []
        if has(["photo", "picture", "image", "screenshot", "selfie"]) { steps = [ChainStep(block: .stripLocation), ChainStep(block: .shrinkImage, settings: ["mb": "2"])] }
        else if has(["http", "www.", "link", " url"]) { steps = [ChainStep(block: .cleanLinks)] }
        else if has(["text", "notes", "words", "message", "paragraph", "essay", "letter"]) { steps = [ChainStep(block: .cleanText)] }
        guard !steps.isEmpty else { return nil }
        return validated(Chain(id: UUID().uuidString, name: "", steps: steps))
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

    /// The tool a sentence asks for, whatever its spelling. nil when it names nothing Tenzy works with.
    static func keywordPlan(_ ask: String) -> Chain? { guess(ask)?.chain }

    /// The rules themselves, read from a sentence whose spelling has already been tidied.
    static func rules(_ ask: String) -> Chain? {
        let s = " " + ask.lowercased() + " "
        func has(_ words: [String]) -> Bool { words.contains { s.contains($0) } }

        // Just for fun. These requests name exactly what they want, so they are read before anything else.
        let film = has(["video", " clip", "movie", "footage", "live photo"])
        if has(["boomerang"]) { return build(ask, [ChainStep(block: .videoLoop, settings: ["style": "boomerang"])]) }
        if has(["reverse", "backwards", "backward"]), film || has([" gif"]) { return build(ask, [ChainStep(block: .videoLoop, settings: ["style": "reverse"])]) }
        if has(["slow mo", "slow-mo", "slowmo", "slow motion", "slow it down", "slow down", "half speed"]) { return build(ask, [ChainStep(block: .videoSpeed, settings: ["speed": "slow"])]) }
        if has(["speed up", "speed it up", "sped up", "timelapse", "time lapse", "time-lapse", "fast forward", "double speed", " 2x", " 4x"]) || (film && has(["faster"])) {
            return build(ask, [ChainStep(block: .videoSpeed, settings: ["speed": has([" 4x", "four times", "timelapse", "time lapse", "time-lapse"]) ? "faster" : "fast"])])
        }
        if has(["meme"]) { return build(ask, [ChainStep(block: .meme, settings: ["top": "", "bottom": ""])]) }
        if has(["sticker"]) { return build(ask, [ChainStep(block: .sticker)]) }
        if has(["mosaic"]) || (has(["emoji"]) && has(["made of", "out of", "made from", "rebuild", " art "])) { return build(ask, [ChainStep(block: .emojiMosaic)]) }
        if has(["emoji", "smiley"]) { return build(ask, [ChainStep(block: .emojiFaces, settings: ["emoji": ChainText.faceEmojis[0]])]) }
        if has(["before and after", "before/after", "before after", "side by side"]) {
            var c = build(ask, [ChainStep(block: .stripLocation)])
            c?.versus = true
            return c
        }
        if has(["chipmunk", "helium", "voice changer", "funny voice", "deep voice", "change my voice", "change the voice"]) {
            return build(ask, (film ? [ChainStep(block: .videoAudio)] : []) + [ChainStep(block: .voiceChange, settings: ["voice": has(["deep", "giant", "low voice"]) ? "deep" : "chipmunk"])])
        }
        if has(["sketch", "pencil", "drawing", "cartoon", "comic", "pop art", "black and white", "noir"]) {
            let style = has(["cartoon", "comic"]) ? "comic" : has(["pop art"]) ? "pop" : has(["black and white", "noir"]) ? "noir" : "sketch"
            return build(ask, [ChainStep(block: .artFilter, settings: ["style": style])])
        }
        if has([" gif", "slideshow", "slide show"]), !has(["video", " clip", "movie", "footage"]) {
            // A Live Photo carries a short video; several photos play one after another.
            if has(["live photo"]) { return build(ask, [ChainStep(block: .videoGif)]) }
            var c = build(ask, [ChainStep(block: .stripLocation)])
            c?.gif = true
            return c
        }

        // A recording: write out what was said, then whatever else was asked for.
        if has(["voice memo", "recording", "transcribe", "transcript", "what was said", "speech to text", "audio to text"]) {
            var a: [ChainStep] = has(["video", " clip", "movie", "footage"]) ? [ChainStep(block: .videoAudio)] : []
            a.append(ChainStep(block: .speechText))
            if has(["task", "to-do", "todo", "action item"]) { a.append(ChainStep(block: .actionItems)) }
            else if has(["summar", "key points", "gist"]) { a.append(ChainStep(block: .summarize, settings: ["sentences": "3"])) }
            return build(ask, a)
        }

        // Video jobs come first: a video takes its own steps, never the photo ones.
        if has(["video", " clip", "movie", "footage"]) {
            if has(["caption", "subtitle"]) { return build(ask, [ChainStep(block: .videoCaptions)]) }
            if has([" gif"]) { return build(ask, [ChainStep(block: .videoGif)]) }
            if has(["still", "frame", "thumbnail"]) { return build(ask, [ChainStep(block: .videoStill)]) }
            if has(["audio only", "just the audio", "only the sound", "just the sound", "extract audio", "extract the audio", "as audio", "mp3"]) { return build(ask, [ChainStep(block: .videoAudio)]) }
            var v: [ChainStep] = []
            if has(["trim", "seconds", " secs", "first part", "last part", "cut the"]) {
                let secs = number(near: ["second", "sec"], in: s, before: true) ?? 30
                v.append(ChainStep(block: .videoTrim, settings: ["side": has(["last ", "the end"]) ? "last" : "first", "secs": String(secs)]))
            }
            if has(["rotate", "sideways", "upside down", "right way up"]) {
                v.append(ChainStep(block: .videoRotate, settings: ["turn": has(["upside down"]) ? "flip" : has([" left"]) ? "left" : "right"]))
            }
            if has(["vertical", "portrait", "9:16", " tall", "story", "stories", "reel", "tiktok"]) { v.append(ChainStep(block: .videoVertical)) }
            if has(["mute", "no sound", "without sound", "without its sound", "remove the sound", "remove sound", "silent"]) { v.append(ChainStep(block: .videoMute)) }
            if v.isEmpty || has(["shrink", "smaller", "compress", "reduce", "under ", " mb", "email", "whatsapp", "send", "size"]) {
                let mb = number(near: ["mb", "megabyte"], in: s, before: true) ?? (has(["whatsapp", "chat"]) ? 16 : 25)
                v.append(ChainStep(block: .videoShrink, settings: ["mb": String(mb)]))
            }
            return build(ask, v)
        }

        // Jobs that start from a PDF (a photo turned into a PDF is handled further down).
        if has(["pdf"]), !has(["photo", "picture", "image", "scan", "screenshot", "receipt", "web page", "webpage", "article", "link", "text to", "form"]) {
            if has(["words", "text from", "text out", "copy the text", "read the pdf"]) { return build(ask, [ChainStep(block: .pdfText)]) }
            var p: [ChainStep] = []
            let join = has(["merge", "join", "combine", "into one"])
            if join || has(["page ", "pages", "split", "extract"]) { p.append(ChainStep(block: .pdfPages, settings: ["pages": !join && has(["first page"]) ? "1" : ""])) }
            if has(["shrink", "smaller", "compress", "reduce", "under ", " mb", "email"]) {
                p.append(ChainStep(block: .pdfShrink, settings: ["mb": String(number(near: ["mb", "megabyte"], in: s, before: true) ?? 5)]))
            }
            if has(["password", "lock", "protect", "encrypt"]) { p.append(ChainStep(block: .pdfLock, settings: ["password": ""])) }
            if !p.isEmpty {
                var c = build(ask, p)
                if join { c?.combine = true }
                return c
            }
        }

        var steps: [ChainStep] = []
        let wantsPhotoInput = has(["photo", "picture", "image", "scan", "screenshot", "snap", "camera", "receipt", "card", "poster", "flyer", "whiteboard", "sign "])

        // Translating: read the words first when a picture is meant.
        if has(["translat"]) {
            let to = ChainText.languages.first { s.contains(" " + $0.name.lowercased()) && !s.contains("from " + $0.name.lowercased()) }?.code ?? "en"
            return build(ask, (wantsPhotoInput || has(["menu"]) ? [ChainStep(block: .readText)] : []) + [ChainStep(block: .translate, settings: ["to": to])])
        }
        // A web page: keep its words, then make a PDF, a summary or an audio file of them.
        if has(["web page", "webpage", "article", "website"]) {
            var w = [ChainStep(block: .pageText)]
            if has(["pdf"]) { w.append(ChainStep(block: .textPdf)) }
            else if has(["summar", "gist", "key points", "shorten"]) { w.append(ChainStep(block: .summarize, settings: ["sentences": "3"])) }
            else if has(["read aloud", "listen", "audio"]) { w.append(ChainStep(block: .readAloud)) }
            return build(ask, w)
        }
        if has(["read aloud", " aloud", "read out", "listen to", "text to speech", "audio file"]) {
            return build(ask, (wantsPhotoInput ? [ChainStep(block: .readText)] : []) + [ChainStep(block: .readAloud)])
        }
        // Reading a code (making one is handled below).
        if has(["qr", "barcode"]), has(["read ", "scan ", "what does", "safe", "decode"]), !has(["wifi", "wi-fi", "make ", "create", "turn ", "into a qr", "to qr", "to a qr"]) {
            return build(ask, [ChainStep(block: .readCode)] + (has(["safe", "scam"]) ? [ChainStep(block: .scamCheck)] : []))
        }
        if has(["rewrite", "reword", "rephrase", "more formal", "friendlier", "more polite"]) {
            let style = has(["formal", "polite", "professional"]) ? "formal" : has(["friendl", "warm"]) ? "friendly" : has(["short", "brief"]) ? "short" : "clear"
            return build(ask, [ChainStep(block: .rewrite, settings: ["style": style])])
        }

        // Text-making jobs: they start from a picture of the thing, or from pasted text, so read it first when a picture is meant.
        // "Tidy up this photo" is about the picture, so tidying only means text when text is what is being talked about.
        let textish = has(["text", "notes", "words", "list", "lines", "pasted", "paste"])
        let wantsClean = has(["tidy", "clean up", "clean the", "dedupe", "de-dupe", "duplicate line", "remove duplicates", "extra spaces", "blank lines"]) && (!wantsPhotoInput || textish)
        let textJob: Block? =
            has(["scam", "phishing", "fraud", "is this real", "suspicious"]) ? .scamCheck :
            has(["best deal", "cheapest", "cheaper", "unit price", "per unit", "better value"]) ? .priceCompare :
            has(["tracking", "clean link", "clean the link", "clean my link", "utm"]) ? .cleanLinks :
            has(["wifi", "wi-fi"]) ? .wifiQr :
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
        if has(["cut out", "cutout", "remove background", "remove the background", "background", "isolate"]) { steps.append(ChainStep(block: .cutout)) }
        if has(["enhance", "sharpen", "improve", "fix the photo", "better quality", "clearer", "brighten"]) { steps.append(ChainStep(block: .enhance)) }
        if has(["blur", "hide", "redact", "private", "faces", "face ", "anonym", "censor", "personal", "sensitive", "confidential", "identity"]) { steps.append(ChainStep(block: .hideSensitive)) }
        if has(["passport", "id photo", "visa photo", "headshot size"]) { steps.append(ChainStep(block: .passportPhoto, settings: ["country": "us"])) }
        if has(["watermark"]) { steps.append(ChainStep(block: .watermark, settings: ["text": "For verification only"])) }
        // Posting a photo, or taking the personal details out of it, also means leaving behind where it was taken.
        let posting = has([" post", "social", "instagram", "facebook", "online", "publicly"])
        if posting || has(["location", "gps", "exif", "metadata", "safe to share", "safe-to-share", "strip", "personal", "sensitive", "confidential"]) { steps.append(ChainStep(block: .stripLocation)) }
        if has(["35x45", "35 x 45", "pixels", "pixel size", " px"]) { steps.append(ChainStep(block: .resizePhoto, settings: ["size": has(["35x45", "35 x 45"]) ? "413x531" : "600x600"])) }
        if has(["png", "heic", "jpg", "jpeg", "convert", "format"]) {
            let f = s.contains("png") ? "PNG" : s.contains("heic") ? "HEIC" : "JPG"
            steps.append(ChainStep(block: .convertImage, settings: ["format": f]))
        }
        if posting || has(["shrink", "smaller", "compress", "reduce", "under ", " mb", " kb", "email", "upload", "size"]) {
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

/// Makes sense of what was typed before the rules read it: fixes misspelt words it knows and expands short forms, so
/// "shrnk my foto" reads as "shrink my photo". Everything else (numbers, punctuation, words it doesn't know) is left
/// exactly as written. Pure, and the same lists and rules as Android.
enum PlannerWords {
    static let short: [String: String] = ["pic": "photo", "pics": "photos", "img": "image", "foto": "photo", "fotos": "photos", "vid": "video", "vids": "videos", "msg": "message", "pwd": "password"]

    /// Words the rules look for. A typed word close to exactly one of these is taken to be it.
    static let vocab: Set<String> = Set(("""
    photo photos picture pictures image images scan screenshot camera receipt receipts card poster flyer whiteboard video videos clip movie footage still frame \
    thumbnail audio sound mute silent shrink smaller compress reduce under email whatsapp send size caption captions subtitle subtitles trim seconds rotate sideways \
    upside vertical portrait story stories reel tiktok merge join combine pages page split extract password lock protect encrypt words translate translation webpage \
    article website link links aloud listen speech barcode read safe decode rewrite reword rephrase formal friendlier polite professional scam phishing fraud \
    suspicious deal cheapest cheaper tracking wifi expense expenses invoice business contact contacts vcard calendar event invite appointment spreadsheet excel \
    table columns urls address number numbers task tasks todo checklist action summarize summarise summary shorten gist points tidy clean clear dedupe duplicate \
    duplicates spaces blank lines identify describe cutout background sticker isolate enhance sharpen improve quality clearer brighten blur hide redact private \
    faces anonymous censor passport visa headshot watermark location metadata strip pixels pixel convert format upload voice memo recording transcribe transcript \
    collage personal sensitive confidential identity details data date information post posting social instagram facebook online share remove delete signature \
    sign stamp text notes message messages list pasted paste sheet ledger running monthly return plant breed menu document documents file files kilobyte megabyte \
    sentence sentences letter paragraph essay record quiet crop tall wide turn first last start keep english spanish french german italian portuguese hindi arabic \
    chinese japanese korean russian turkish dutch polish indonesian vietnamese thai ukrainian boomerang reverse backwards motion slowmo speed faster timelapse meme memes stickers emoji emojis mosaic slideshow funny sketch pencil drawing cartoon comic chipmunk helium comparison black white
    """).split(separator: " ").map(String.init))

    /// Ordinary words that sit one letter away from a word above and must never be "corrected" into it.
    static let real: Set<String> = Set("carton cosmic spend fasten notion store phone strap plane plate price point their there where which about would could should these those other after before every later thing things something anything everything people person month today tomorrow title state place right light night great small large please thanks really always never maybe while without within between through because again being doing going having making taking getting using wants wanted needs needed friend friends family client clients office house school second flame world paper print".split(separator: " ").map(String.init))

    /// Words too general to tell one starter from another.
    static let plain: Set<String> = Set("photo photos picture pictures image images text video videos into from with that this your mine make turn want need have please some them then just only also file files thing something anything notes words page pages link links code list sheet".split(separator: " ").map(String.init))

    /// The sentence in lower case with each misspelt word it recognises put right. Nothing else changes.
    static func tidy(_ ask: String) -> String {
        var out = "", word = ""
        for ch in ask.lowercased() {
            if ch >= "a" && ch <= "z" { word.append(ch) } else { out += fix(word); word = ""; out.append(ch) }
        }
        return out + fix(word)
    }

    /// The words of a sentence: runs of letters, lower case.
    static func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !($0 >= "a" && $0 <= "z") }).map(String.init)
    }

    /// One word put right: a short form spelt out, or a word of five letters or more that is one slip (two for long
    /// words) away from exactly one known word starting with the same letter. An "-ing", "-ed" or "-s" ending is
    /// tried without it too. Anything else comes back unchanged.
    static func fix(_ w: String) -> String {
        if let full = short[w] { return full }
        if w.count < 5 || vocab.contains(w) || real.contains(w) { return w }
        if let v = nearest(w) { return v }
        for ending in ["ing", "ed", "es", "s"] where w.hasSuffix(ending) && w.count - ending.count >= 5 {
            let stem = String(w.dropLast(ending.count))
            if vocab.contains(stem) { return w }
            if let v = nearest(stem) { return v }
        }
        return w
    }

    private static func nearest(_ w: String) -> String? {
        let reach = w.count >= 8 ? 2 : 1
        var best: String?, bestD = reach + 1, tie = false
        for v in vocab where v.first == w.first && abs(v.count - w.count) <= reach {
            let d = distance(w, v, limit: reach)
            if d < bestD { best = v; bestD = d; tie = false } else if d == bestD && d <= reach { tie = true }
        }
        return tie ? nil : best
    }

    /// How many slips apart two words are: a wrong, missing or extra letter, or two neighbours swapped, each count one.
    /// Anything over `limit` comes back as `limit + 1`.
    static func distance(_ a: String, _ b: String, limit: Int) -> Int {
        let x = Array(a), y = Array(b)
        if abs(x.count - y.count) > limit { return limit + 1 }
        if x.isEmpty { return min(y.count, limit + 1) }
        if y.isEmpty { return min(x.count, limit + 1) }
        var d = Array(repeating: Array(repeating: 0, count: y.count + 1), count: x.count + 1)
        for i in 0...x.count { d[i][0] = i }
        for j in 0...y.count { d[0][j] = j }
        for i in 1...x.count {
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
                if i > 1, j > 1, x[i - 1] == y[j - 2], x[i - 2] == y[j - 1] { d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1) }
            }
        }
        return min(d[x.count][y.count], limit + 1)
    }
}
