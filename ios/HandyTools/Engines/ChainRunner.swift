import UIKit
import PDFKit

/// Tenzy Builder, Milestone 1: a chain is plain data (a list of built-in blocks with settings) that this
/// runner executes by calling the engines the app already ships. No downloaded or generated code ever runs,
/// so a chain from a template, a friend or the describe-it layer is as safe as a built-in tool.
enum ChainPayload {
    case image(UIImage)
    case text(String)
    case file(Data, ext: String)
    /// A video stays a file on disk (it is far too big to hold in memory); steps hand its location along.
    case video(URL)

    var kind: ChainKind {
        switch self {
        case .image: return .image
        case .text: return .text
        case .video: return .video
        case .file(_, let ext):
            if ChainPayload.isPhoto(ext) { return .photoFile }
            if ext.lowercased() == "pdf" { return .pdf }
            return ChainPayload.isAudio(ext) ? .audio : .file
        }
    }
    static func isPhoto(_ ext: String) -> Bool { ["jpg", "jpeg", "png", "heic"].contains(ext.lowercased()) }
    /// A recording or any other sound file.
    static func isAudio(_ ext: String) -> Bool { ["m4a", "mp3", "wav", "aac", "caf", "ogg", "flac"].contains(ext.lowercased()) }
}

/// What flows between blocks. The builder only offers a block whose `takes` matches the step above it.
enum ChainKind: String, Codable {
    case image, text, file
    /// A photo saved as bytes (the result of shrink, convert, strip...). Any block that takes a picture accepts it.
    case photoFile
    case video
    /// A recording or other sound file, and a PDF. Both travel as file bytes; the kind says which steps fit.
    case audio, pdf
    var label: String {
        switch self {
        case .image, .photoFile: return "a photo"; case .text: return "text"; case .file: return "a file"; case .video: return "a video"
        case .audio: return "a recording"; case .pdf: return "a PDF"
        }
    }
    func feeds(_ need: ChainKind) -> Bool { self == need || (need == .image && self == .photoFile) }
}

enum Block: String, Codable, CaseIterable, Identifiable {
    case readText, pullReceipt, summarize, shrinkImage, stripLocation, cutout, enhance, convertImage
    case businessCard, calendarEvent, actionItems, hideSensitive, passportPhoto
    case cleanText, pullDetails, makeTable
    case scamCheck, cleanLinks, priceCompare, makeQr, describe, identify, photoPdf
    case watermark, resizePhoto
    case stamp
    case expenseRow, addToList
    case chatLink, contactQr
    case wifiQr
    case returnBy
    case videoShrink, videoStill, videoMute, videoAudio
    case videoTrim, videoGif, videoRotate, videoVertical, videoCaptions
    case speechText, readAloud, translate, rewrite
    case readCode, pageText, textPdf
    case pdfShrink, pdfLock, pdfPages, pdfText
    case sticker, emojiFaces, meme, emojiMosaic, videoSpeed, videoLoop
    case artFilter, voiceChange

    var id: String { rawValue }
    var title: String {
        switch self {
        case .readText: return "Read text"
        case .pullReceipt: return "Pull receipt fields"
        case .summarize: return "Summarize"
        case .shrinkImage: return "Shrink to size"
        case .stripLocation: return "Strip location"
        case .cutout: return "Cut out subject"
        case .enhance: return "Enhance"
        case .convertImage: return "Convert format"
        case .businessCard: return "Make a contact"
        case .calendarEvent: return "Make a calendar event"
        case .actionItems: return "Find tasks"
        case .hideSensitive: return "Hide faces and numbers"
        case .passportPhoto: return "Passport photo"
        case .cleanText: return "Tidy text"
        case .pullDetails: return "Find links, emails, phones"
        case .makeTable: return "Text to spreadsheet"
        case .scamCheck: return "Check for scams"
        case .cleanLinks: return "Clean tracking from links"
        case .priceCompare: return "Find the best deal"
        case .makeQr: return "Make a QR code"
        case .describe: return "Describe the photo"
        case .identify: return "Identify it"
        case .photoPdf: return "Make a PDF"
        case .watermark: return "Add a watermark"
        case .resizePhoto: return "Exact pixel size"
        case .stamp: return "Sign and stamp"
        case .expenseRow: return "Receipt to one expense row"
        case .addToList: return "Add to a running list"
        case .chatLink: return "WhatsApp link for a number"
        case .contactQr: return "Contact as a QR code"
        case .wifiQr: return "Wi-Fi join code"
        case .returnBy: return "Return-by reminder"
        case .videoShrink: return "Shrink video to size"
        case .videoStill: return "Grab a still"
        case .videoMute: return "Remove the sound"
        case .videoAudio: return "Keep only the sound"
        case .videoTrim: return "Keep the start or the end"
        case .videoGif: return "Make a GIF"
        case .videoRotate: return "Turn it"
        case .videoVertical: return "Crop to tall (9:16)"
        case .videoCaptions: return "Add captions"
        case .speechText: return "Write out what is said"
        case .readAloud: return "Read it aloud"
        case .translate: return "Translate"
        case .rewrite: return "Rewrite it"
        case .readCode: return "Read a QR or barcode"
        case .pageText: return "Read the page at a link"
        case .textPdf: return "Text to PDF"
        case .pdfShrink: return "Shrink the PDF"
        case .pdfLock: return "Lock with a password"
        case .pdfPages: return "Keep some pages"
        case .pdfText: return "Read the PDF's words"
        case .sticker: return "Make a sticker"
        case .emojiFaces: return "Emoji over faces"
        case .meme: return "Add meme text"
        case .emojiMosaic: return "Rebuild it from emojis"
        case .videoSpeed: return "Slow it down or speed it up"
        case .videoLoop: return "Boomerang GIF"
        case .artFilter: return "Sketch, comic or pop art"
        case .voiceChange: return "Change the voice"
        }
    }
    var takes: ChainKind {
        switch self {
        case .readText, .shrinkImage, .stripLocation, .cutout, .enhance, .convertImage, .hideSensitive, .passportPhoto, .describe, .identify, .photoPdf, .watermark, .resizePhoto, .stamp, .readCode, .sticker, .emojiFaces, .meme, .emojiMosaic, .artFilter: return .image
        case .pullReceipt, .summarize, .businessCard, .calendarEvent, .actionItems, .cleanText, .pullDetails, .makeTable, .scamCheck, .cleanLinks, .priceCompare, .makeQr, .expenseRow, .addToList, .chatLink, .contactQr, .wifiQr, .returnBy, .readAloud, .translate, .rewrite, .pageText, .textPdf: return .text
        case .videoShrink, .videoStill, .videoMute, .videoAudio, .videoTrim, .videoGif, .videoRotate, .videoVertical, .videoCaptions, .videoSpeed, .videoLoop: return .video
        case .speechText, .voiceChange: return .audio
        case .pdfShrink, .pdfLock, .pdfPages, .pdfText: return .pdf
        }
    }
    /// Kind produced, given the settings (convert/shrink/strip give a file, the rest as listed).
    var gives: ChainKind {
        switch self {
        case .readText, .pullReceipt, .summarize, .actionItems, .cleanText, .pullDetails, .scamCheck, .cleanLinks, .priceCompare, .describe, .identify, .expenseRow, .chatLink, .speechText, .translate, .rewrite, .readCode, .pageText, .pdfText: return .text
        case .shrinkImage, .stripLocation, .convertImage, .hideSensitive, .passportPhoto, .sticker: return .photoFile
        case .businessCard, .calendarEvent, .makeTable, .addToList, .returnBy, .videoGif, .videoLoop: return .file
        case .cutout, .enhance, .makeQr, .watermark, .resizePhoto, .stamp, .contactQr, .wifiQr, .videoStill, .emojiFaces, .meme, .emojiMosaic, .artFilter: return .image
        case .videoShrink, .videoMute, .videoTrim, .videoRotate, .videoVertical, .videoCaptions, .videoSpeed: return .video
        case .videoAudio, .readAloud, .voiceChange: return .audio
        case .photoPdf, .textPdf, .pdfShrink, .pdfLock, .pdfPages: return .pdf
        }
    }
}

extension Block {
    /// What the person is trying to get done. The builder groups steps under these, so the list reads as
    /// "what do you want to do with it?" rather than a flat list of tools.
    var goal: String {
        switch self {
        case .shrinkImage, .convertImage, .resizePhoto, .videoShrink, .videoTrim, .pdfShrink: return "Make it easy to send"
        case .stripLocation, .hideSensitive, .watermark, .videoMute, .pdfLock: return "Keep it private"
        case .enhance, .cutout, .videoRotate, .videoVertical, .videoCaptions: return "Make it look better"
        case .readText, .describe, .identify, .readCode, .speechText, .pageText, .pdfText: return "Read what's in it"
        case .stamp, .photoPdf, .textPdf, .pdfPages: return "Paperwork"
        case .passportPhoto, .makeTable, .businessCard, .calendarEvent, .makeQr, .chatLink, .contactQr, .wifiQr, .videoStill, .videoAudio, .videoGif, .readAloud: return "Turn it into something"
        case .summarize, .actionItems, .scamCheck, .translate: return "Understand it"
        case .cleanText, .cleanLinks, .pullDetails, .rewrite: return "Clean it up"
        case .pullReceipt, .priceCompare, .expenseRow, .addToList, .returnBy: return "Money"
        case .sticker, .emojiFaces, .meme, .emojiMosaic, .videoSpeed, .videoLoop, .artFilter, .voiceChange: return "Just for fun"
        }
    }
    static let goalOrder = ["Paperwork", "Make it easy to send", "Keep it private", "Make it look better", "Read what's in it", "Understand it", "Clean it up", "Turn it into something", "Just for fun", "Money"]

    /// The given steps under their goals, goals in a fixed order, empty goals left out.
    static func grouped(_ blocks: [Block]) -> [(goal: String, blocks: [Block])] {
        goalOrder.compactMap { g in
            let b = blocks.filter { $0.goal == g }
            return b.isEmpty ? nil : (g, b)
        }
    }
    /// Steps that can come first when a tool starts with a photo, or with text.
    static func starting(with kind: ChainKind) -> [Block] { allCases.filter { kind.feeds($0.takes) } }
}

struct ChainStep: Codable, Equatable {
    var block: Block
    var settings: [String: String] = [:]
}

/// Where a tool's result goes when it finishes. Optional on a chain, so tools saved before this existed still load
/// (they simply offer Share). No app can send an email or a message by itself, so "mail" and "message" open the
/// system composer already filled in, with the result attached; the person taps Send.
struct ChainFinish: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable { case share, mail, message, open }
    var kind: Kind = .share
    /// Email addresses or phone numbers, separated by commas. May be empty: the composer then opens with no recipient.
    var to: String = ""

    var recipients: [String] {
        to.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    var label: String {
        let who = recipients.isEmpty ? "" : " to " + (recipients.count == 1 ? recipients[0] : "\(recipients.count) people")
        switch kind {
        case .share: return "Save or share"
        case .mail: return "Email it" + who
        case .message: return "Message it" + who
        case .open: return "Open it"
        }
    }
}

extension ChainFinish {
    /// A tool made on Android can end in a way an iPhone doesn't have (opening WhatsApp directly). It still loads here
    /// and simply ends with Save or share.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = Kind(rawValue: (try? c.decode(String.self, forKey: .kind)) ?? "") ?? .share
        to = (try? c.decode(String.self, forKey: .to)) ?? ""
    }
}

/// The tool's own ending, when it is one the share sheet can do: an email or a message already filled in.
/// (Opening a link is not possible from inside another app's share sheet.)
enum ShareEnding {
    static func of(_ chain: Chain?) -> ChainFinish? {
        guard let f = chain?.finish, f.kind == .mail || f.kind == .message else { return nil }
        return f
    }
}

/// When a tool should come back to you: a time of day, and the days it applies. A phone won't let an app start a tool
/// by itself in the background, so this is a reminder: tap it and the tool opens ready to run.
/// Optional on a chain, so tools saved before this existed still load.
struct ChainSchedule: Codable, Equatable {
    var hour: Int = 9
    var minute: Int = 0
    /// Weekdays numbered as the calendar does: 1 = Sunday ... 7 = Saturday. Empty means every day.
    var days: [Int] = []

    /// Sorted, no repeats, only real weekdays. All seven is the same as every day, so it comes back empty.
    var cleanDays: [Int] {
        let d = Array(Set(days.filter { (1...7).contains($0) })).sorted()
        return d.count == 7 ? [] : d
    }

    /// One per reminder the phone has to hold: a single daily one, or one for each chosen weekday.
    var triggers: [DateComponents] {
        let h = min(max(hour, 0), 23), m = min(max(minute, 0), 59)
        let d = cleanDays
        if d.isEmpty { return [DateComponents(hour: h, minute: m)] }
        return d.map { DateComponents(hour: h, minute: m, weekday: $0) }
    }

    static func clock(hour: Int, minute: Int, uses24h: Bool) -> String {
        let h = min(max(hour, 0), 23), m = min(max(minute, 0), 59)
        let mm = m < 10 ? "0\(m)" : "\(m)"
        if uses24h { return "\(h):\(mm)" }
        return "\(h % 12 == 0 ? 12 : h % 12):\(mm) \(h < 12 ? "AM" : "PM")"
    }

    /// "Every day at 9:00 AM", "Weekdays at 6:30 PM", "Mon, Thu at 8:00 AM".
    func label(uses24h: Bool = false) -> String {
        let d = cleanDays
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let who: String
        if d.isEmpty { who = "Every day" }
        else if d == [2, 3, 4, 5, 6] { who = "Weekdays" }
        else if d == [1, 7] { who = "Weekends" }
        else { who = (d.filter { $0 != 1 } + d.filter { $0 == 1 }).map { names[$0 - 1] }.joined(separator: ", ") }   // week reads Mon first
        return who + " at " + ChainSchedule.clock(hour: hour, minute: minute, uses24h: uses24h)
    }
}

extension ChainSchedule {
    /// Missing pieces fall back to 9:00 every day rather than failing the whole tool.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hour = (try? c.decode(Int.self, forKey: .hour)) ?? 9
        minute = (try? c.decode(Int.self, forKey: .minute)) ?? 0
        days = (try? c.decode([Int].self, forKey: .days)) ?? []
    }
}

struct Chain: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var steps: [ChainStep]
    var finish: ChainFinish?
    /// When several pages or photos go in at once, put every result into one PDF instead of one file each.
    /// Optional so tools saved before this existed still load.
    var combine: Bool?
    /// What the result file is called, e.g. "Signed form {date}". Empty or nil keeps the plain default.
    var fileName: String?
    /// With `combine`: lay every photo out on a single page (both sides of an ID card) instead of a page each.
    var onePage: Bool?
    /// A reminder to run this tool at a set time. nil: no reminder.
    var schedule: ChainSchedule?
    /// When several photos go in at once, lay the results out as one picture (a collage) instead of one file each.
    var collage: Bool?
    /// When several photos go in at once, play the results one after another as a single looping GIF.
    var gif: Bool?
    /// Before and after: the first and last of the photos side by side, each with its label.
    var versus: Bool?

    /// nil when valid, otherwise a plain-words reason. Shared by the builder UI, imports and describe-it.
    func problem(starting with: ChainKind) -> String? {
        if steps.isEmpty { return "Add at least one step." }
        var kind = with
        for (i, s) in steps.enumerated() {
            if !kind.feeds(s.block.takes) { return "Step \(i + 1), \(s.block.title), needs \(s.block.takes.label) but gets \(kind.label)." }
            kind = s.block.gives
        }
        return nil
    }
}

enum ChainRunner {
    enum Failure: Error, Equatable { case invalid(String), wrongInput(Block), nothingFound(Block), failed(Block) }

    /// Runs every step in order. Each step does its best with what it is given; a step that cannot
    /// produce anything stops the chain with a reason naming it (never a silent empty result).
    /// - Parameter dryRun: true while the builder previews a tool on sample data, so steps that keep something
    ///   (adding a row to a running list) show what they would do without saving it.
    static func run(_ chain: Chain, input: ChainPayload, dryRun: Bool = false) async -> Result<ChainPayload, Failure> {
        if let p = chain.problem(starting: input.kind) { return .failure(.invalid(p)) }
        var value = input
        for step in chain.steps {
            switch await apply(step, to: value, dryRun: dryRun) {
            case .success(let next): value = next
            case .failure(let f): return .failure(f)
            }
        }
        return .success(value)
    }

    static func apply(_ step: ChainStep, to rawInput: ChainPayload, dryRun: Bool = false) async -> Result<ChainPayload, Failure> {
        let b = step.block
        // A step this phone can't do says so plainly instead of failing halfway.
        if let why = b.unavailable { return .failure(.invalid("\(b.title) isn't available on this phone. \(why)")) }
        var input = rawInput
        // A photo that was saved as bytes by an earlier step (shrink, convert...) is opened again for the next one.
        if b.takes == .image, case .file(let d, let ext) = rawInput, ChainPayload.isPhoto(ext) {
            guard let img = UIImage(data: d) else { return .failure(.failed(b)) }
            input = .image(img)
        }
        switch (b, input) {
        case (.readText, .image(let img)):
            let text = rows(DocEngine.recognize(img)).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? .failure(.nothingFound(b)) : .success(.text(text))

        case (.pullReceipt, .text(let t)):
            let r = DataGrab.receipt(t)
            guard r.total != nil || !r.items.isEmpty else { return .failure(.nothingFound(b)) }
            return .success(.text(DataGrab.receiptCSV(r)))

        case (.summarize, .text(let t)):
            let n = Int(step.settings["sentences"] ?? "") ?? 3
            let s = TextTools.summarize(t, sentences: max(1, n))
            return s.isEmpty ? .failure(.nothingFound(b)) : .success(.text(s.joined(separator: " ")))

        case (.shrinkImage, .image(let img)):
            let mb = Double(step.settings["mb"] ?? "") ?? 2
            guard let data = await SizeTarget.image(img, targetBytes: Int(max(0.01, mb) * 1_048_576)) else { return .failure(.failed(b)) }
            return .success(.file(data, ext: "jpg"))

        case (.stripLocation, .image(let img)):
            // Re-encoding from pixels carries no EXIF/GPS across.
            guard let data = img.jpegData(compressionQuality: 0.92) else { return .failure(.failed(b)) }
            return .success(.file(data, ext: "jpg"))

        case (.cutout, .image(let img)):
            guard let out = ImageStudio.cutout(img) else { return .failure(.nothingFound(b)) }
            return .success(.image(out))

        case (.enhance, .image(let img)):
            guard let out = ImageStudio.enhance(img, upscale: false) else { return .failure(.failed(b)) }
            return .success(.image(out))

        case (.convertImage, .image(let img)):
            let fmt = ImageStudio.Format(rawValue: (step.settings["format"] ?? "JPG").uppercased()) ?? .jpg
            guard let data = ImageStudio.encode(img, as: fmt, quality: 0.9) else { return .failure(.failed(b)) }
            return .success(.file(data, ext: fmt.rawValue.lowercased()))

        case (.businessCard, .text(let t)):
            let c = DataGrab.card(t)
            // A contact with only a name can't be saved or sent by most apps (WhatsApp, Messages), so it needs a way to reach the person.
            guard !c.phones.isEmpty || !c.emails.isEmpty, let d = DataGrab.vcard(c).data(using: .utf8) else { return .failure(.nothingFound(b)) }
            return .success(.file(d, ext: "vcf"))

        case (.calendarEvent, .text(let t)):
            let e = DataGrab.event(t)
            guard e.start != nil, let d = DataGrab.ics(e).data(using: .utf8) else { return .failure(.nothingFound(b)) }
            return .success(.file(d, ext: "ics"))

        case (.actionItems, .text(let t)):
            let items = TextTools.actionItems(t)
            return items.isEmpty ? .failure(.nothingFound(b)) : .success(.text(items.map { "• " + $0 }.joined(separator: "\n")))

        case (.cleanText, .text(let t)):
            let out = TextTidy.clean(t)
            return out.isEmpty ? .failure(.nothingFound(b)) : .success(.text(out))

        case (.pullDetails, .text(let t)):
            let d = TextTidy.details(t)
            return d.isEmpty ? .failure(.nothingFound(b)) : .success(.text(d.text))

        case (.makeTable, .text(let t)):
            let csv = DataGrab.tableCSV(t)
            guard !csv.isEmpty, let d = csv.data(using: .utf8) else { return .failure(.nothingFound(b)) }
            return .success(.file(d, ext: "csv"))

        case (.scamCheck, .text(let t)):
            guard !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .failure(.nothingFound(b)) }
            return .success(.text(ChainText.scamReport(ScamAnalyzer.analyze(t))))

        case (.cleanLinks, .text(let t)):
            guard let out = ChainText.cleanLinks(in: t) else { return .failure(.nothingFound(b)) }
            return .success(.text(out))

        case (.priceCompare, .text(let t)):
            guard let out = ChainText.bestDeal(in: t) else { return .failure(.nothingFound(b)) }
            return .success(.text(out))

        case (.makeQr, .text(let t)):
            let msg = t.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !msg.isEmpty else { return .failure(.nothingFound(b)) }
            guard let img = ChainText.qr(msg) else { return .failure(.failed(b)) }   // too long for one code
            return .success(.image(img))

        case (.describe, .image(let img)):
            let p = SceneDescriber.perceive(img)
            let text = await SceneDescriber.polish(p, fallback: SceneDescriber.compose(p)).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? .failure(.nothingFound(b)) : .success(.text(text))

        case (.identify, .image(let img)):
            let o = await Identifier.identify(img)
            var lines = o.guesses.prefix(3).map { "\($0.label) (\(Int(($0.confidence * 100).rounded()))% sure)" }
            if let code = o.barcode { lines.insert("Barcode \(code)" + (o.symbology.map { " (\($0))" } ?? ""), at: 0) }
            return lines.isEmpty ? .failure(.nothingFound(b)) : .success(.text(lines.joined(separator: "\n")))

        case (.photoPdf, .image(let img)):
            guard let d = DocEngine.pdf(images: [img], ocr: [DocEngine.recognize(img)], options: DocEngine.PDFOptions()) else { return .failure(.failed(b)) }
            return .success(.file(d, ext: "pdf"))

        case (.chatLink, .text(let t)):
            guard let link = ChainText.chatLink(t, countryCode: step.settings["cc"] ?? ChainText.callingCode(region: Locale.current.region?.identifier)) else { return .failure(.nothingFound(b)) }
            return .success(.text(link))

        case (.wifiQr, .text(let t)):
            // The network name and password from a router label or a cafe sign, as a code a guest's camera joins from.
            guard let code = ChainText.wifiCode(t) else { return .failure(.nothingFound(b)) }
            guard let img = ChainText.qr(code) else { return .failure(.failed(b)) }
            return .success(.image(img))

        case (.contactQr, .text(let t)):
            // Only what is in the text goes into the code, so you choose what the other person gets.
            let c = DataGrab.card(t)
            guard !c.phones.isEmpty || !c.emails.isEmpty else { return .failure(.nothingFound(.businessCard)) }
            guard let img = ChainText.qr(DataGrab.vcard(c)) else { return .failure(.failed(b)) }
            return .success(.image(img))

        case (.expenseRow, .text(let t)):
            let r = DataGrab.receipt(t)
            guard r.total != nil || !r.items.isEmpty else { return .failure(.nothingFound(b)) }
            return .success(.text(DataGrab.expenseRow(r)))

        case (.videoShrink, .video(let url)):
            // Re-encoded to fit the limit. The new file carries no location or camera details from the original.
            let mb = ChainText.videoLimit(step.settings["mb"])
            guard let out = await SizeTarget.videoBestEffort(url: url, targetBytes: mb * 1_048_576) else { return .failure(.failed(b)) }
            return .success(.video(out.url))

        case (.videoStill, .video(let url)):
            guard let img = await VideoEngine.thumbnail(url, at: 0.5, maxDim: 1920) else { return .failure(.failed(b)) }
            return .success(.image(img))

        case (.videoMute, .video(let url)):
            guard let out = await VideoEngine.mute(url) else { return .failure(.failed(b)) }
            return .success(.video(out))

        case (.videoAudio, .video(let url)):
            guard let out = await VideoEngine.extractAudio(url), let d = try? Data(contentsOf: out) else { return .failure(.nothingFound(b)) }
            return .success(.file(d, ext: out.pathExtension.isEmpty ? "m4a" : out.pathExtension.lowercased()))

        case (.returnBy, .text(let t)):
            // The last day to take it back, counted from the date on the receipt (today if it shows none), as a calendar entry.
            let r = DataGrab.receipt(t)
            guard r.total != nil || !r.items.isEmpty || r.date != nil else { return .failure(.nothingFound(b)) }
            let days = ChainText.returnDays(step.settings["days"])
            let due = ChainText.returnDeadline(purchased: r.date, days: days)
            guard due > Date() else { return .failure(.invalid("The \(days)-day return window for this receipt has already ended.")) }
            let e = DataGrab.Event(title: ChainText.returnTitle(r.merchant), start: due, end: due.addingTimeInterval(1800), location: "")
            guard let d = DataGrab.ics(e).data(using: .utf8) else { return .failure(.failed(b)) }
            return .success(.file(d, ext: "ics"))

        case (.addToList, .text(let t)):
            // Every run adds to the same sheet (one per month by default) and hands back the whole sheet.
            let name = ChainName.file(pattern: step.settings["list"] ?? RunningList.defaultName, tool: "List", ext: "csv")
            let merged = RunningList.merged(existing: dryRun ? "" : RunningList.read(name), incoming: t)
            guard !merged.isEmpty, let d = merged.data(using: .utf8) else { return .failure(.nothingFound(b)) }
            if !dryRun, !RunningList.write(name, merged) { return .failure(.failed(b)) }
            return .success(.file(d, ext: "csv"))

        case (.stamp, .image(let img)):
            let plan = StampPlan(step.settings["marks"] ?? StampPlan.standard.text)
            guard !plan.spots.isEmpty else { return .failure(.invalid("Sign and stamp has nothing to place. Turn on the signature, your name or the date.")) }
            var stamps: [DocEngine.Stamp] = []
            for s in plan.spots {
                let at = CGPoint(x: s.x, y: s.y)
                switch s.mark {
                case .signature:
                    guard let sig = DocEngine.savedSignature else { return .failure(.invalid("Sign and stamp needs your signature. Edit the tool and tap Draw my signature.")) }
                    stamps.append(DocEngine.Stamp(kind: .signature(sig), center: at, width: CGFloat(s.w)))
                case .name:
                    let n = StampBook.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !n.isEmpty else { return .failure(.invalid("Sign and stamp needs your name. Edit the tool and type it in.")) }
                    stamps.append(DocEngine.Stamp(kind: .text(n), center: at, width: CGFloat(s.w)))
                case .date:
                    stamps.append(DocEngine.Stamp(kind: .text(StampPlan.dateText(Date())), center: at, width: CGFloat(s.w)))
                }
            }
            // Burned into the picture, so the signature can't be lifted off the page afterwards.
            var page = DocEngine.Page(source: img)
            page.filter = .color
            page.stamps = stamps
            return .success(.image(DocEngine.render(page)))

        case (.watermark, .image(let img)):
            // The date is stamped at run time, so a copy made today can't be passed off later.
            let words = (step.settings["text"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(.image(ChainImage.watermark(img, text: ChainImage.watermarkLine(words, on: Date()))))

        case (.resizePhoto, .image(let img)):
            guard let px = ChainImage.pixels(step.settings["size"] ?? "") else { return .failure(.invalid("Exact pixel size needs a size like 600x600.")) }
            return .success(.image(ChainImage.fill(img, to: px)))

        case (.hideSensitive, .image(let img)):
            let hits = Scrubber.detect(img)
            let rects = hits.faces + hits.text.filter(\.personal).map(\.rect)
            // Nothing to hide is still a good result: hand back a clean copy rather than an error.
            guard let d = Scrubber.render(img, rects: rects, style: .block) else { return .failure(.failed(b)) }
            return .success(.file(d, ext: "jpg"))

        case (.passportPhoto, .image(let img)):
            let spec = ImageStudio.passportSpecs.first { $0.id == (step.settings["country"] ?? "us") } ?? ImageStudio.passportSpecs[0]
            guard let out = ImageStudio.passport(img, spec: spec, background: .white), let d = out.jpegData(compressionQuality: 0.95) else { return .failure(.nothingFound(b)) }
            return .success(.file(d, ext: "jpg"))

        default:
            // The newer steps (recordings, PDFs, links, codes, translating, more video) live in ChainExtras.
            return await ChainExtras.apply(step, to: input, dryRun: dryRun) ?? .failure(.wrongInput(b))
        }
    }
}

extension ChainRunner {
    /// Text that sits on the same visual row is rejoined left to right. Vision often returns "Total" and
    /// "13.72" as separate pieces when a receipt leaves a wide gap between them, and the field parser needs
    /// the label and its amount on one line.
    static func rows(_ lines: [DocEngine.OCRLine]) -> String {
        let sorted = lines.sorted { $0.box.midY < $1.box.midY }
        var groups: [[DocEngine.OCRLine]] = []
        for l in sorted {
            if var last = groups.last, let ref = last.first, abs(l.box.midY - ref.box.midY) < max(ref.box.height, l.box.height) * 0.6 {
                last.append(l); groups[groups.count - 1] = last
            } else { groups.append([l]) }
        }
        return groups.map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: "  ") }.joined(separator: "\n")
    }
}

/// Starter chains shipped inside the app. Users can run them, or copy one and edit it.
enum ChainTemplates {
    static let all: [Chain] = [
        Chain(id: "receipt-to-row", name: "Receipt to expense row", steps: [
            ChainStep(block: .readText), ChainStep(block: .pullReceipt)]),
        Chain(id: "photo-under-2mb", name: "Photo under 2 MB", steps: [
            ChainStep(block: .shrinkImage, settings: ["mb": "2"])]),
        Chain(id: "safe-to-share", name: "Safe-to-share photo", steps: [
            ChainStep(block: .stripLocation), ]),
        Chain(id: "card-to-contact", name: "Business card to contact", steps: [ChainStep(block: .readText), ChainStep(block: .businessCard)]),
        Chain(id: "poster-to-event", name: "Poster to calendar event", steps: [ChainStep(block: .readText), ChainStep(block: .calendarEvent)]),
        Chain(id: "whiteboard-to-tasks", name: "Whiteboard to task list", steps: [ChainStep(block: .readText), ChainStep(block: .actionItems)]),
        Chain(id: "passport-photo", name: "Passport photo", steps: [ChainStep(block: .passportPhoto, settings: ["country": "us"])]),
        Chain(id: "hide-sensitive", name: "Hide faces and numbers", steps: [ChainStep(block: .hideSensitive)]),
        Chain(id: "short-summary", name: "Long text to 3 sentences", steps: [ChainStep(block: .summarize, settings: ["sentences": "3"])]),
        Chain(id: "sticker", name: "Cut out a subject", steps: [ChainStep(block: .cutout)]),
        Chain(id: "table-to-sheet", name: "Photo of a table to spreadsheet", steps: [ChainStep(block: .readText), ChainStep(block: .makeTable)]),
        Chain(id: "links-and-numbers", name: "Pull links, emails and phones", steps: [ChainStep(block: .pullDetails)]),
        Chain(id: "tidy-text", name: "Tidy pasted text", steps: [ChainStep(block: .cleanText)]),
        Chain(id: "scam-check", name: "Is this message a scam?", steps: [ChainStep(block: .scamCheck)]),
        Chain(id: "clean-link", name: "Link without the tracking", steps: [ChainStep(block: .cleanLinks)]),
        Chain(id: "shelf-best-deal", name: "Shelf photo to best deal", steps: [ChainStep(block: .readText), ChainStep(block: .priceCompare)]),
        Chain(id: "photo-to-pdf", name: "Photo to searchable PDF", steps: [ChainStep(block: .photoPdf)]),
        Chain(id: "text-to-qr", name: "Text or link to QR code", steps: [ChainStep(block: .makeQr)]),
        Chain(id: "what-is-this", name: "What is this?", steps: [ChainStep(block: .identify)]),
        Chain(id: "scan-to-pdf", name: "Scan pages into one PDF", steps: [ChainStep(block: .photoPdf)], combine: true),
        Chain(id: "sign-and-send", name: "Sign a form and send it", steps: [ChainStep(block: .stamp, settings: ["marks": StampPlan.standard.text]), ChainStep(block: .photoPdf)],
              finish: ChainFinish(kind: .mail, to: ""), combine: true, fileName: "Signed form {date}"),
        Chain(id: "receipt-run", name: "Receipt into this month's expense sheet", steps: [ChainStep(block: .readText), ChainStep(block: .expenseRow), ChainStep(block: .addToList, settings: ["list": RunningList.defaultName])]),
        Chain(id: "whatsapp-no-save", name: "WhatsApp a number without saving it", steps: [ChainStep(block: .chatLink)], finish: ChainFinish(kind: .open, to: "")),
        Chain(id: "contact-qr", name: "My contact as a QR code", steps: [ChainStep(block: .contactQr)]),
        Chain(id: "video-email", name: "Video under 25 MB for email", steps: [ChainStep(block: .videoShrink, settings: ["mb": "25"])], finish: ChainFinish(kind: .mail, to: "")),
        Chain(id: "video-chat", name: "Video small enough for chat (16 MB)", steps: [ChainStep(block: .videoShrink, settings: ["mb": "16"])]),
        Chain(id: "video-still", name: "Grab a still from a video", steps: [ChainStep(block: .videoStill)]),
        Chain(id: "video-quiet", name: "Video without its sound", steps: [ChainStep(block: .videoMute)]),
        Chain(id: "return-by", name: "Receipt to a return-by reminder", steps: [ChainStep(block: .readText), ChainStep(block: .returnBy, settings: ["days": "30"])]),
        Chain(id: "wifi-sign", name: "Wi-Fi sign to a code guests scan", steps: [ChainStep(block: .readText), ChainStep(block: .wifiQr)]),
        Chain(id: "id-both-sides", name: "Both sides of an ID on one page", steps: [ChainStep(block: .watermark, settings: ["text": "For verification only"])], combine: true, onePage: true),
        Chain(id: "share-shield", name: "Privacy share shield", steps: [ChainStep(block: .hideSensitive), ChainStep(block: .stripLocation), ChainStep(block: .shrinkImage, settings: ["mb": "2"])]),
        Chain(id: "id-copy-watermarked", name: "ID copy with a safety watermark", steps: [ChainStep(block: .watermark, settings: ["text": "For verification only"]), ChainStep(block: .stripLocation)]),
        Chain(id: "portal-photo", name: "Portal photo: 35x45 mm under 50 KB", steps: [ChainStep(block: .resizePhoto, settings: ["size": "413x531"]), ChainStep(block: .shrinkImage, settings: ["mb": "0.05"])]),
        Chain(id: "memo-to-notes", name: "Voice memo to written notes", steps: [ChainStep(block: .speechText), ChainStep(block: .cleanText)]),
        Chain(id: "memo-to-tasks", name: "Meeting recording to task list", steps: [ChainStep(block: .speechText), ChainStep(block: .actionItems)]),
        Chain(id: "qr-safe", name: "Is this QR code safe?", steps: [ChainStep(block: .readCode), ChainStep(block: .scamCheck)]),
        Chain(id: "sign-to-english", name: "Sign or menu photo to English", steps: [ChainStep(block: .readText), ChainStep(block: .translate, settings: ["to": "en"])]),
        Chain(id: "page-to-pdf", name: "Web page to a clean PDF", steps: [ChainStep(block: .pageText), ChainStep(block: .textPdf)]),
        Chain(id: "page-summary", name: "Web page to 3 sentences", steps: [ChainStep(block: .pageText), ChainStep(block: .summarize, settings: ["sentences": "3"])]),
        Chain(id: "listen-later", name: "Text to an audio file", steps: [ChainStep(block: .readAloud)]),
        Chain(id: "pdf-email", name: "PDF under 5 MB for email", steps: [ChainStep(block: .pdfShrink, settings: ["mb": "5"])], finish: ChainFinish(kind: .mail, to: "")),
        Chain(id: "pdf-join", name: "Join PDFs into one", steps: [ChainStep(block: .pdfPages, settings: ["pages": ""])], combine: true),
        Chain(id: "pdf-first-page", name: "Just the first page of a PDF", steps: [ChainStep(block: .pdfPages, settings: ["pages": "1"])]),
        Chain(id: "video-story", name: "First 30 seconds, cropped tall", steps: [ChainStep(block: .videoTrim, settings: ["side": "first", "secs": "30"]), ChainStep(block: .videoVertical)]),
        Chain(id: "video-gif", name: "Video to a GIF", steps: [ChainStep(block: .videoGif)]),
        Chain(id: "video-words", name: "What was said in a video", steps: [ChainStep(block: .videoAudio), ChainStep(block: .speechText)]),
        Chain(id: "photo-collage", name: "Photos into one collage", steps: [ChainStep(block: .stripLocation)], collage: true),
        Chain(id: "where-i-am", name: "Send where I am", steps: [ChainStep(block: .cleanText)], finish: ChainFinish(kind: .message, to: "")),
        Chain(id: "photos-gif", name: "Photos into a GIF", steps: [ChainStep(block: .stripLocation)], gif: true),
        Chain(id: "sticker-maker", name: "Photo to a sticker", steps: [ChainStep(block: .sticker)]),
        Chain(id: "emoji-faces", name: "Emoji over every face", steps: [ChainStep(block: .emojiFaces, settings: ["emoji": ChainText.faceEmojis[0]])]),
        Chain(id: "meme", name: "Make a meme", steps: [ChainStep(block: .meme, settings: ["top": "", "bottom": ""])]),
        Chain(id: "emoji-mosaic", name: "Photo made of emojis", steps: [ChainStep(block: .emojiMosaic)]),
        Chain(id: "video-boomerang", name: "Boomerang GIF from a video", steps: [ChainStep(block: .videoLoop, settings: ["style": "boomerang"])]),
        Chain(id: "video-slowmo", name: "Slow-motion video", steps: [ChainStep(block: .videoSpeed, settings: ["speed": "slow"])]),
        Chain(id: "video-fast", name: "Speed a video up", steps: [ChainStep(block: .videoSpeed, settings: ["speed": "fast"])]),
        Chain(id: "photo-sketch", name: "Photo to a pencil sketch", steps: [ChainStep(block: .artFilter, settings: ["style": "sketch"])]),
        Chain(id: "photo-comic", name: "Photo to a comic", steps: [ChainStep(block: .artFilter, settings: ["style": "comic"])]),
        Chain(id: "voice-chipmunk", name: "Chipmunk voice", steps: [ChainStep(block: .voiceChange, settings: ["voice": "chipmunk"])]),
        Chain(id: "voice-deep", name: "Deep voice", steps: [ChainStep(block: .voiceChange, settings: ["voice": "deep"])]),
        Chain(id: "video-voice", name: "Funny voice from a video", steps: [ChainStep(block: .videoAudio), ChainStep(block: .voiceChange, settings: ["voice": "chipmunk"])]),
        Chain(id: "before-after", name: "Before and after, side by side", steps: [ChainStep(block: .stripLocation)], versus: true),
    ]
}

/// Chains travel as small text: copy one, paste it in another Tenzy. Checked before it is accepted.
extension Chain {
    static let prefix = "tenzy-tool:"
    var shareText: String {
        // A shared tool never carries the owner's recipients (someone's email or phone number).
        var copy = self
        copy.finish?.to = ""
        copy.schedule = nil        // nor their reminder times
        for i in copy.steps.indices { copy.steps[i].settings["password"] = nil }   // nor a PDF password
        return (try? JSONEncoder().encode(copy)).flatMap { String(data: $0, encoding: .utf8) }.map { Chain.prefix + $0 } ?? ""
    }
    static func imported(from text: String) -> Chain? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix(prefix), let d = String(t.dropFirst(prefix.count)).data(using: .utf8),
              var c = try? JSONDecoder().decode(Chain.self, from: d), c.steps.count <= 12,
              let first = c.steps.first, c.problem(starting: first.block.takes) == nil else { return nil }
        c.id = UUID().uuidString
        c.schedule = nil           // a pasted tool never arrives with reminders already switched on
        return c
    }
}

/// Saved tools live in the App Group so the share sheet ("Tenzy" in any app's Share menu) can run them too.
enum ChainStore {
    private static let key = "builder.chains"
    private static let lastKey = "builder.lastShared"

    static func load() -> [Chain] {
        let g = AppGroup.defaults
        // One-time move from the app's own defaults (where tools were kept before the share sheet could run them).
        if g.data(forKey: key) == nil, let old = UserDefaults.standard.data(forKey: key) { g.set(old, forKey: key) }
        guard let d = g.data(forKey: key), let c = try? JSONDecoder().decode([Chain].self, from: d) else { return [] }
        return c
    }
    static func save(_ chains: [Chain]) {
        if let d = try? JSONEncoder().encode(chains) { AppGroup.defaults.set(d, forKey: key) }
    }

    /// The tool last run from the share sheet, offered first next time.
    static var lastShared: String? {
        get { AppGroup.defaults.string(forKey: lastKey) }
        set { AppGroup.defaults.set(newValue, forKey: lastKey) }
    }

    /// Every tool that can start from what was shared: the user's own first, then the starters, with the last-used one on top.
    static func offers(for kind: ChainKind, mine: [Chain], last: String?) -> [Chain] {
        var all = (mine + ChainTemplates.all).filter { $0.problem(starting: kind) == nil && $0.unavailable == nil }
        if let last, let i = all.firstIndex(where: { $0.id == last }) { all.insert(all.remove(at: i), at: 0) }
        return all
    }
}

/// Plain-text results for the blocks that wrap the scam, link and price engines. Pure, so they are unit-tested.
enum ChainText {
    static func scamReport(_ r: ScamAnalyzer.Report) -> String {
        var out = [r.verdict.rawValue + "."]
        out += r.findings.sorted { $0.weight > $1.weight }.prefix(4).map { "• \($0.title)" }
        for l in r.links where !l.issues.isEmpty { out.append("• Link \(l.host): \(l.issues.joined(separator: "; "))") }
        if let first = ScamAnalyzer.advice(for: r).first { out.append(""); out.append(first) }
        return out.joined(separator: "\n")
    }

    /// A wa.me link that opens a WhatsApp chat with the number in the text, so it never has to be saved as a contact.
    /// A number written without a country code gets `countryCode`. nil when the text holds no usable number.
    static func chatLink(_ text: String, countryCode: String) -> String? {
        let raw = (TextTidy.details(text).phones.first ?? text).trimmingCharacters(in: .whitespacesAndNewlines)
        var digits = String(raw.unicodeScalars.filter { ("0"..."9").contains($0) })
        guard (7...15).contains(digits.count) else { return nil }
        if !raw.hasPrefix("+") {
            if digits.hasPrefix("00") { digits.removeFirst(2) }
            else {
                if digits.hasPrefix("0") { digits.removeFirst() }
                let cc = String(countryCode.unicodeScalars.filter { ("0"..."9").contains($0) })
                if digits.count <= 10 { digits = cc + digits }      // longer than a national number: it already has its country code
            }
        }
        return "https://wa.me/" + digits
    }
    /// Country calling code for a region ("US" -> "1"). Unknown regions fall back to "1"; the step lets it be changed.
    static func callingCode(region: String?) -> String {
        let codes = ["US": "1", "CA": "1", "IN": "91", "GB": "44", "AU": "61", "DE": "49", "FR": "33", "ES": "34", "IT": "39", "NL": "31", "BR": "55", "MX": "52",
                     "AE": "971", "SA": "966", "SG": "65", "PK": "92", "BD": "880", "ID": "62", "PH": "63", "NG": "234", "ZA": "27", "KE": "254", "JP": "81", "KR": "82", "TR": "90", "EG": "20"]
        return codes[(region ?? "").uppercased()] ?? "1"
    }

    /// Every web link in the text with its tracking removed. nil when the text has no links.
    static func cleanLinks(in text: String) -> String? {
        let links = TextTidy.details(text).links
        guard !links.isEmpty else { return nil }
        if links.count == 1, text.trimmingCharacters(in: .whitespacesAndNewlines) == links[0] { return LinkCleaner.clean(full(links[0])) }
        var out = text
        for l in links { out = out.replacingOccurrences(of: l, with: LinkCleaner.clean(full(l))) }
        return out
    }
    private static func full(_ link: String) -> String { link.lowercased().hasPrefix("http") ? link : "https://" + link }

    /// Ranks the priced, sized items found in the text by true unit price. nil when fewer than two can be compared.
    static func bestDeal(in text: String) -> String? {
        let entries = PriceBrain.extract(from: text).compactMap { row -> PriceBrain.Entry? in
            let digits = row.price.filter { $0.isNumber || $0 == "." }
            guard let price = Double(digits) else { return nil }
            return PriceBrain.Entry(name: row.name.isEmpty ? row.size : row.name, price: price, sizeText: row.size)
        }
        let ranked = PriceBrain.rank(entries).filter { $0.perBase != nil }.sorted { ($0.perBase ?? .infinity) < ($1.perBase ?? .infinity) }
        guard ranked.count >= 2, let best = ranked.first else { return nil }
        var out = ["Best deal: \(best.entry.name), \(PriceBrain.perUnitString(best))"]
        out += ranked.dropFirst().map { "\($0.entry.name), \(PriceBrain.perUnitString($0))" }
        return out.joined(separator: "\n")
    }

    // MARK: video size limits

    /// Size limits a video tool can pick, in megabytes: chat apps, email, and upload forms.
    static let videoLimits = [10, 16, 25, 50, 100]
    static func videoLimit(_ setting: String?) -> Int { min(2000, max(1, Int(Double(setting ?? "") ?? 25))) }

    // MARK: trimming a video

    /// Lengths "Keep the start or the end" can pick, in seconds: story and status limits.
    static let trimLengths = [15, 30, 60, 90]
    /// The part of a video to keep, in seconds. `side` is "first" or "last"; a video shorter than the length is kept whole.
    static func trimWindow(side: String?, secs: String?, duration: Double) -> (start: Double, end: Double) {
        let want = Double(min(600, max(1, Int(secs ?? "") ?? 30)))
        let d = max(0, duration)
        if d <= want { return (0, d) }
        return side == "last" ? (d - want, d) : (0, want)
    }
    /// Quarter turns "Turn it" can make: to the right, to the left, or upside down. Anything else turns right.
    static func turnDegrees(_ setting: String?) -> Int { setting == "left" ? 270 : setting == "flip" ? 180 : 90 }

    // MARK: pages of a PDF

    /// Size limits a PDF tool can pick, in megabytes.
    static let pdfLimits = [1, 2, 5, 10, 20]
    static func pdfLimit(_ setting: String?) -> Int { min(200, max(1, Int(Double(setting ?? "") ?? 5))) }
    /// "1-3, 5" as page positions counted from zero, in the order written, without repeats, only pages that exist.
    /// Empty or unreadable means every page.
    static func pageList(_ setting: String, count: Int) -> [Int] {
        var out: [Int] = []
        for raw in setting.replacingOccurrences(of: "–", with: "-").components(separatedBy: CharacterSet(charactersIn: ",; ")) {
            let part = raw.trimmingCharacters(in: .whitespaces)
            if part.isEmpty { continue }
            let ends = part.split(separator: "-").map { Int($0.trimmingCharacters(in: .whitespaces)) }
            if ends.count == 2, let a = ends[0], let b = ends[1] {
                let lo = max(1, min(a, b)), hi = min(count, max(a, b))
                if lo <= hi { for p in lo...hi where !out.contains(p - 1) { out.append(p - 1) } }
            } else if ends.count == 1, let p = ends[0], p >= 1, p <= count, !out.contains(p - 1) { out.append(p - 1) }
        }
        return out.isEmpty ? Array(0..<max(0, count)) : out
    }

    // MARK: languages

    /// Languages "Translate" offers: the ones both iPhone and Android can translate on the phone.
    static let languages: [(code: String, name: String)] = [
        ("en", "English"), ("es", "Spanish"), ("fr", "French"), ("de", "German"), ("it", "Italian"), ("pt", "Portuguese"), ("hi", "Hindi"),
        ("ar", "Arabic"), ("zh", "Chinese"), ("ja", "Japanese"), ("ko", "Korean"), ("ru", "Russian"), ("tr", "Turkish"), ("nl", "Dutch"),
        ("pl", "Polish"), ("id", "Indonesian"), ("vi", "Vietnamese"), ("th", "Thai"), ("uk", "Ukrainian"),
    ]
    static func languageName(_ code: String?) -> String { languages.first { $0.code == code }?.name ?? "English" }
    static func languageCode(_ setting: String?) -> String { languages.contains { $0.code == setting } ? (setting ?? "en") : "en" }

    // MARK: rewriting

    static let rewriteStyles: [(id: String, name: String)] = [("clear", "Clearer"), ("short", "Shorter"), ("friendly", "Friendlier"), ("formal", "More formal")]
    static func rewriteStyle(_ setting: String?) -> String { rewriteStyles.contains { $0.id == setting } ? (setting ?? "clear") : "clear" }
    static func rewriteAsk(_ style: String) -> String {
        let how: String
        switch style {
        case "short": how = "Make it about half as long. Keep every fact, name, number and date."
        case "friendly": how = "Make it warm and friendly, in plain everyday words."
        case "formal": how = "Make it polite and professional."
        default: how = "Make it clear and easy to read, in plain words and short sentences."
        }
        return "Rewrite the text the person gives you. " + how + " Keep the meaning and the language it is written in. Reply with the rewritten text only."
    }

    // MARK: captions

    /// Spoken words grouped into caption lines: a new line starts when the line is full or the speaker pauses.
    /// Each line stays up until the next one starts, but never longer than 4 seconds after its last word.
    static func captionLines(_ words: [(text: String, start: Double, end: Double)], maxChars: Int = 32, pause: Double = 0.8) -> [(text: String, start: Double, end: Double)] {
        var out: [(text: String, start: Double, end: Double)] = []
        for w in words {
            let t = w.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { continue }
            if let last = out.last, last.text.count + 1 + t.count <= maxChars, w.start - last.end <= pause {
                out[out.count - 1] = (last.text + " " + t, last.start, max(last.end, w.end))
            } else {
                out.append((t, w.start, max(w.end, w.start)))
            }
        }
        for i in out.indices {
            let hold = out[i].end + 4
            let next = i + 1 < out.count ? out[i + 1].start : hold
            out[i].end = max(out[i].end, min(hold, next))
        }
        return out
    }

    // MARK: a web page as plain reading text

    /// The link a "Read the page" step should open: the first web link in the text, with https added if it has none.
    static func pageLink(in text: String) -> String? {
        guard let l = TextTidy.details(text).links.first else { return nil }
        return full(l)
    }

    /// The readable words of a web page: its title, then its headings and paragraphs. Menus, scripts, forms and
    /// footers are dropped. Empty when the page has no readable text. Pure, and the same rules as Android.
    static func article(html: String) -> String {
        func sub(_ s: String, _ pattern: String, _ with: String) -> String {
            s.replacingOccurrences(of: pattern, with: with, options: [.regularExpression, .caseInsensitive])
        }
        func first(_ s: String, _ pattern: String) -> String? {
            guard let r = s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
            return String(s[r])
        }
        func plain(_ s: String) -> String {
            var t = sub(s, "<[^>]+>", " ")
            for (a, b) in [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&rsquo;", "'"), ("&lsquo;", "'"),
                           ("&ldquo;", "\""), ("&rdquo;", "\""), ("&mdash;", "-"), ("&ndash;", "-"), ("&hellip;", "...")] { t = t.replacingOccurrences(of: a, with: b) }
            t = sub(t, "&#?[a-z0-9]+;", " ")
            return sub(t, "[ \\t\u{00A0}]+", " ").trimmingCharacters(in: .whitespaces)
        }
        let title = first(html, "(?s)<title[^>]*>.*?</title>").map(plain) ?? ""
        var h = html
        for tag in ["script", "style", "nav", "footer", "header", "aside", "noscript", "svg", "form", "iframe", "button", "head", "title"] {
            h = sub(h, "(?s)<\(tag)\\b[^>]*>.*?</\(tag)>", " ")
        }
        h = sub(h, "(?s)<!--.*?-->", " ")
        if let a = first(h, "(?s)<article\\b[^>]*>.*?</article>") { h = a } else if let m = first(h, "(?s)<main\\b[^>]*>.*?</main>") { h = m }
        h = sub(h, "\\s+", " ")          // line breaks in the page's source mean nothing; only its tags do
        h = sub(h, "<li\\b[^>]*>", "\n• ")
        h = sub(h, "<br\\s*/?>|</p>|</h[1-6]>|</li>|</div>|</tr>|</blockquote>|</section>", "\n")
        var lines = h.components(separatedBy: "\n").map(plain).filter { !$0.isEmpty && $0 != "•" }
        if !title.isEmpty, lines.first != title { lines.insert(title, at: 0) }
        return lines.joined(separator: "\n")
    }

    // MARK: naming a tool

    /// A short name for a tool nobody has named: a starter's name when the steps are a starter's, otherwise the steps themselves.
    static func autoName(_ chain: Chain) -> String {
        let blocks = chain.steps.map(\.block)
        if blocks.isEmpty { return "My tool" }
        if let t = ChainTemplates.all.first(where: { $0.steps.map(\.block) == blocks }) { return t.name }
        if blocks.count == 1 { return blocks[0].title }
        if blocks.count == 2 { return blocks[0].title + " + " + blocks[1].title }
        return blocks[0].title + " + \(blocks.count - 1) more"
    }
    /// The name "Describe it" gives a tool: the request itself when it is short enough to read as a name, otherwise `autoName`.
    static func toolName(ask: String, chain: Chain) -> String {
        let t = ask.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        guard !t.isEmpty, t.count <= 28 else { return autoName(chain) }
        return t.prefix(1).uppercased() + t.dropFirst()
    }
    /// What a tool is saved as: the name typed, or `autoName` when it was left empty or as "My tool".
    static func savedName(_ chain: Chain) -> String {
        let n = chain.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty || n == "My tool" ? autoName(chain) : n
    }

    // MARK: collage

    /// How many columns and rows a collage of `count` pictures gets: as square as it can be.
    static func collageGrid(_ count: Int) -> (cols: Int, rows: Int) {
        guard count > 0 else { return (0, 0) }
        let cols = Int(Double(count).squareRoot().rounded(.up))
        return (cols, Int((Double(count) / Double(cols)).rounded(.up)))
    }

    // MARK: just for fun

    /// Emojis "Emoji over faces" offers. The first is the default.
    static let faceEmojis = ["😀", "😎", "🤡", "🐶", "🐱", "👽", "🤖", "🎃"]
    static func faceEmoji(_ setting: String?) -> String { faceEmojis.contains(setting ?? "") ? (setting ?? faceEmojis[0]) : faceEmojis[0] }

    /// A line of meme text as it is drawn: capitals, one line's worth of spaces, at most 120 characters.
    static func memeText(_ raw: String) -> String {
        let words = raw.uppercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return String(words.joined(separator: " ").prefix(120))
    }

    /// Speeds "Slow it down or speed it up" offers.
    static let speeds: [(id: String, name: String, rate: Double)] = [("slow", "Slow motion", 0.5), ("fast", "2x faster", 2), ("faster", "4x faster", 4)]
    static func speedRate(_ setting: String?) -> Double { speeds.first { $0.id == setting }?.rate ?? 0.5 }

    /// The order a loop plays its frames in. "reverse" plays them backwards; anything else is a boomerang: forwards,
    /// then back again without repeating the two end frames, so the loop has no stutter.
    static func loopOrder(_ count: Int, style: String?) -> [Int] {
        guard count > 0 else { return [] }
        if style == "reverse" { return Array((0..<count).reversed()) }
        return Array(0..<count) + (count > 2 ? Array((1..<(count - 1)).reversed()) : [])
    }

    /// How many emojis across and down a mosaic gets: 56 along the picture's long side, the other side in proportion.
    static func mosaicGrid(width: Double, height: Double, long: Int = 56) -> (cols: Int, rows: Int) {
        guard width > 0, height > 0 else { return (0, 0) }
        if width >= height { return (long, max(1, Int((Double(long) * height / width).rounded()))) }
        return (max(1, Int((Double(long) * width / height).rounded())), long)
    }

    /// Emojis a mosaic is built from: a spread of every colour, so any part of a photo has a close match.
    static let mosaicEmojis = ["🍎", "🌹", "🍓", "🔴", "🍅", "🍊", "🦊", "🏀", "🥕", "🟠", "🌟", "🍋", "🌻", "🟡", "🧀", "🍌", "🍏", "🌲", "🐸", "🥦", "🟢", "🍀", "🥝", "💙", "🌊", "🐳", "🔵", "🧊", "🫐", "💜", "🍇", "🔮", "🟣", "🌸", "🐷", "💗", "🍑", "🐻", "🍫", "🟤", "🥔", "🌰", "🍞", "🥜", "🧇", "🍪", "⚫", "🎱", "🖤", "🎩", "⚪", "☁️", "🥚", "🤍", "🐑", "🐘", "🪨", "🐭", "🥈", "🔘"]

    /// Which colour in `palette` is closest to the one given (all 0...255). -1 for an empty palette.
    static func nearestColor(r: Int, g: Int, b: Int, in palette: [(r: Int, g: Int, b: Int)]) -> Int {
        var best = -1, bestD = Int.max
        for (i, p) in palette.enumerated() {
            let d = (p.r - r) * (p.r - r) + (p.g - g) * (p.g - g) + (p.b - b) * (p.b - b)
            if d < bestD { best = i; bestD = d }
        }
        return best
    }

    // MARK: voices

    /// Voices "Change the voice" offers, and how much faster (and so higher) each plays the recording.
    static let voices: [(id: String, name: String, rate: Double)] = [("chipmunk", "Chipmunk", 1.5), ("deep", "Deep", 0.75), ("giant", "Giant", 0.6)]
    static func voiceRate(_ setting: String?) -> Double { voices.first { $0.id == setting }?.rate ?? 1.5 }

    /// The 44 bytes that start a .wav file of plain 16-bit sound.
    static func wavHeader(sampleRate: Int, channels: Int, dataBytes: Int) -> [UInt8] {
        func le(_ v: Int, _ n: Int) -> [UInt8] { (0..<n).map { UInt8((v >> (8 * $0)) & 0xFF) } }
        let ch = max(1, channels), rate = max(1, sampleRate)
        return Array("RIFF".utf8) + le(36 + dataBytes, 4) + Array("WAVEfmt ".utf8) + le(16, 4) + le(1, 2) + le(ch, 2) + le(rate, 4) + le(rate * ch * 2, 4) + le(ch * 2, 2) + le(16, 2)
            + Array("data".utf8) + le(dataBytes, 4)
    }

    // MARK: where I am

    /// What "Where I am" puts in the text box: the address when the phone knows it, and a map link anyone can open.
    static func locationText(latitude: Double, longitude: Double, address: String) -> String {
        let link = "https://maps.google.com/?q=" + String(format: "%.5f", latitude) + "," + String(format: "%.5f", longitude)
        let a = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return (a.isEmpty ? "I'm here:" : "I'm here: " + a) + "\n" + link
    }

    // MARK: return windows

    /// Return windows a tool can pick, in days.
    static let returnWindows = [14, 30, 60, 90]
    static func returnDays(_ setting: String?) -> Int { min(365, max(1, Int(setting ?? "") ?? 30)) }
    /// 9:00 in the morning, `days` after the day it was bought (today when the receipt shows no date).
    static func returnDeadline(purchased: Date?, days: Int, now: Date = Date(), calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: purchased ?? now)
        let due = calendar.date(byAdding: .day, value: days, to: day) ?? day
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: due) ?? due
    }
    static func returnTitle(_ merchant: String) -> String {
        let m = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? "Last day to return" : "Last day to return: \(m)"
    }

    // MARK: Wi-Fi details in text

    /// The network name and password written in some text ("Network: CafeGuest", "Password: latte1234"), or nil when
    /// no name is there. Labels must be followed by ":" or "=". With no labels at all, exactly two single
    /// words are read as name then password. Pure, and the same rules as Android.
    static func wifi(in text: String) -> (name: String, password: String)? {
        let nameKeys = ["network name", "wifi name", "wi-fi name", "ssid", "network", "wi-fi", "wifi"]
        let passKeys = ["password", "passphrase", "passcode", "pass", "pwd", "pw", "key"]
        func labelled(_ line: String, _ keys: [String]) -> String? {
            let lower = line.lowercased()
            for k in keys where lower.hasPrefix(k) {
                let rest = line.dropFirst(k.count).drop(while: { $0 == " " })
                guard let sep = rest.first, sep == ":" || sep == "=" else { continue }
                return rest.dropFirst().trimmingCharacters(in: .whitespaces)
            }
            return nil
        }
        var parts: [String] = []
        for line in text.components(separatedBy: .newlines) {
            var pieces = [line]
            for sep in [" / ", " | ", ",", "  "] { pieces = pieces.flatMap { $0.components(separatedBy: sep) } }
            parts += pieces.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        var name: String?, pass: String?
        for p in parts {
            if let v = labelled(p, nameKeys) { if name == nil, !v.isEmpty { name = v } }
            else if let v = labelled(p, passKeys), pass == nil { pass = v }
        }
        // No labels at all: two single words are a name and a password. Anything wordier is just a sentence.
        if name == nil, pass == nil, parts.count == 2, !parts[0].contains(" "), !parts[1].contains(" ") { return (parts[0], parts[1]) }
        guard let n = name else { return nil }
        return (n, pass ?? "")
    }

    /// The text a Wi-Fi QR code holds. A network with no password is marked open.
    static func wifiCode(_ text: String) -> String? {
        guard let w = wifi(in: text) else { return nil }
        func esc(_ s: String) -> String { String(s.flatMap { "\\;,:\"".contains($0) ? ["\\", $0] : [$0] }) }
        return w.password.isEmpty ? "WIFI:T:nopass;S:\(esc(w.name));;" : "WIFI:T:WPA;S:\(esc(w.name));P:\(esc(w.password));;"
    }

    static func qr(_ message: String) -> UIImage? {
        guard let f = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        f.setValue(Data(message.utf8), forKey: "inputMessage")
        f.setValue("M", forKey: "inputCorrectionLevel")
        guard let ci = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Picture helpers for the watermark, exact-size and size-limit steps. The text parts are pure and unit-tested.
enum ChainImage {
    /// Size limits a tool can pick, in megabytes. The small ones exist because government, bank and visa
    /// portals often demand a photo or signature under 20, 50 or 100 KB.
    static let limits: [Double] = [0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10]
    static func limitLabel(_ mb: Double) -> String {
        mb < 1 ? "\(Int((mb * 1000).rounded())) KB" : "\(mb.formatted()) MB"
    }

    /// Pixel sizes offered by "Exact pixel size". 413x531 is a 35x45 mm passport photo at 300 dpi.
    static let sizes: [(label: String, value: String)] = [
        ("35x45 mm photo (413x531)", "413x531"), ("2x2 inch photo (600x600)", "600x600"), ("Square 1080", "1080x1080"),
        ("Portrait 4:5 (1080x1350)", "1080x1350"), ("Wide 16:9 (1920x1080)", "1920x1080"),
    ]
    /// "413x531" (also "413 x 531" or "413×531") as a size; nil if it isn't two sensible numbers.
    static func pixels(_ s: String) -> CGSize? {
        let parts = s.lowercased().replacingOccurrences(of: "×", with: "x").split(separator: "x").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]), (16...8000).contains(w), (16...8000).contains(h) else { return nil }
        return CGSize(width: w, height: h)
    }

    /// The watermark line: the tool's words (or a safe default) plus the day it was made.
    static func watermarkLine(_ words: String, on day: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "d MMM yyyy"
        return (words.isEmpty ? "For verification only" : words) + " · " + f.string(from: day)
    }

    /// Every picture on one A4-shaped sheet, stacked top to bottom, each as large as fits, with white margins.
    /// Used for both sides of an ID card on a single page.
    static func sheet(_ images: [UIImage], size: CGSize = CGSize(width: 1240, height: 1754), margin: CGFloat = 70) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            for (i, r) in slots(count: images.count, in: size, margin: margin).enumerated() {
                let img = images[i]
                let s = min(r.width / max(1, img.size.width), r.height / max(1, img.size.height))
                let w = img.size.width * s, h = img.size.height * s
                img.draw(in: CGRect(x: r.midX - w / 2, y: r.midY - h / 2, width: w, height: h))
            }
        }
    }
    /// Every picture as one image, in a grid of square tiles with thin white gaps. Each picture fills its tile.
    static func collage(_ images: [UIImage], tile: CGFloat = 900, gap: CGFloat = 12) -> UIImage? {
        guard !images.isEmpty else { return nil }
        let g = ChainText.collageGrid(images.count)
        let size = CGSize(width: CGFloat(g.cols) * tile + CGFloat(g.cols + 1) * gap, height: CGFloat(g.rows) * tile + CGFloat(g.rows + 1) * gap)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            for (i, img) in images.enumerated() {
                let r = CGRect(x: gap + CGFloat(i % g.cols) * (tile + gap), y: gap + CGFloat(i / g.cols) * (tile + gap), width: tile, height: tile)
                ctx.cgContext.saveGState()
                ctx.cgContext.clip(to: r)
                let s = max(tile / max(1, img.size.width), tile / max(1, img.size.height))
                let w = img.size.width * s, h = img.size.height * s
                img.draw(in: CGRect(x: r.midX - w / 2, y: r.midY - h / 2, width: w, height: h))
                ctx.cgContext.restoreGState()
            }
        }
    }

    /// Equal slots down the sheet, one per picture, separated by the margin.
    static func slots(count: Int, in size: CGSize, margin: CGFloat) -> [CGRect] {
        guard count > 0 else { return [] }
        let h = (size.height - margin * CGFloat(count + 1)) / CGFloat(count)
        return (0..<count).map { CGRect(x: margin, y: margin + CGFloat($0) * (h + margin), width: size.width - margin * 2, height: h) }
    }

    /// Fills the exact pixel size: scales the photo to cover it and trims the overflow evenly, so nothing is stretched.
    static func fill(_ img: UIImage, to px: CGSize) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: px, format: fmt).image { _ in
            let s = max(px.width / img.size.width, px.height / img.size.height)
            let w = img.size.width * s, h = img.size.height * s
            img.draw(in: CGRect(x: (px.width - w) / 2, y: (px.height - h) / 2, width: w, height: h))
        }
    }

    /// Repeats the line diagonally across the whole picture, see-through, so it can't be cropped away.
    static func watermark(_ img: UIImage, text: String) -> UIImage {
        let size = CGSize(width: img.size.width * img.scale, height: img.size.height * img.scale)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            img.draw(in: CGRect(origin: .zero, size: size))
            let fontSize = max(14, min(size.width, size.height) / 20)
            let line = NSAttributedString(string: text, attributes: [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: UIColor.white.withAlphaComponent(0.45),
                .strokeColor: UIColor.black.withAlphaComponent(0.45), .strokeWidth: -2.0,
            ])
            let ts = line.size()
            let cg = ctx.cgContext
            cg.translateBy(x: size.width / 2, y: size.height / 2)
            cg.rotate(by: -.pi / 6)
            let reach = hypot(size.width, size.height) / 2
            var y = -reach, row = 0
            while y < reach {
                var x = -reach - (row % 2 == 0 ? 0 : ts.width / 2)
                while x < reach { line.draw(at: CGPoint(x: x, y: y)); x += ts.width + fontSize * 2 }
                y += ts.height * 3; row += 1
            }
        }
    }
}

/// "One PDF for everything": joins the results of a multi-page or multi-photo run.
enum ChainCombine {
    /// PDFs are joined page after page; pictures become a page each. Text, other files or a mix can't be
    /// combined, and the caller then keeps the separate results (nil).
    /// - Parameter onePage: put every picture on a single sheet (both sides of an ID) instead of a page each.
    static func onePDF(_ results: [ChainPayload], onePage: Bool = false) -> ChainPayload? {
        guard !results.isEmpty else { return nil }
        var pdfs: [Data] = [], images: [UIImage] = []
        for r in results {
            switch r {
            case .file(let d, let ext) where ext.lowercased() == "pdf": pdfs.append(d)
            case .file(let d, let ext) where ChainPayload.isPhoto(ext):
                guard let i = UIImage(data: d) else { return nil }
                images.append(i)
            case .image(let i): images.append(i)
            default: return nil
            }
        }
        if !pdfs.isEmpty, images.isEmpty {
            let out = PDFDocument()
            for d in pdfs {
                guard let doc = PDFDocument(data: d) else { return nil }
                for i in 0..<doc.pageCount {
                    if let p = doc.page(at: i) { out.insert((p.copy() as? PDFPage) ?? p, at: out.pageCount) }
                }
            }
            return out.dataRepresentation().map { .file($0, ext: "pdf") }
        }
        if !images.isEmpty, pdfs.isEmpty {
            if onePage, images.count > 1 {
                return DocEngine.pdf(images: [ChainImage.sheet(images)], ocr: [nil], options: DocEngine.PDFOptions(searchable: false)).map { .file($0, ext: "pdf") }
            }
            return DocEngine.pdf(images: images, ocr: images.map { _ -> [DocEngine.OCRLine]? in nil }, options: DocEngine.PDFOptions(searchable: false))
                .map { .file($0, ext: "pdf") }
        }
        return nil
    }
}

extension ChainImage {
    /// Two pictures side by side, each filling a tall tile, with BEFORE and AFTER written on them.
    static func beforeAfter(_ before: UIImage, _ after: UIImage, tile: CGSize = CGSize(width: 900, height: 1200), gap: CGFloat = 12) -> UIImage {
        let size = CGSize(width: tile.width * 2 + gap * 3, height: tile.height + gap * 2)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            for (i, pair) in [(before, "BEFORE"), (after, "AFTER")].enumerated() {
                let (img, label) = pair
                let r = CGRect(x: gap + CGFloat(i) * (tile.width + gap), y: gap, width: tile.width, height: tile.height)
                ctx.cgContext.saveGState()
                ctx.cgContext.clip(to: r)
                let s = max(tile.width / max(1, img.size.width), tile.height / max(1, img.size.height))
                let w = img.size.width * s, h = img.size.height * s
                img.draw(in: CGRect(x: r.midX - w / 2, y: r.midY - h / 2, width: w, height: h))
                ctx.cgContext.restoreGState()
                let words = NSAttributedString(string: label, attributes: [.font: UIFont.systemFont(ofSize: 44, weight: .heavy), .foregroundColor: UIColor.white, .kern: 2.0])
                let ws = words.size()
                let plate = CGRect(x: r.minX + 28, y: r.minY + 28, width: ws.width + 44, height: ws.height + 24)
                UIColor.black.withAlphaComponent(0.62).setFill()
                UIBezierPath(roundedRect: plate, cornerRadius: plate.height / 2).fill()
                words.draw(at: CGPoint(x: plate.minX + 22, y: plate.minY + 12))
            }
        }
    }
}

extension ChainCombine {
    /// "Before and after": the first and the last result side by side. nil with fewer than two pictures.
    static func beforeAfter(_ results: [ChainPayload]) -> ChainPayload? {
        var images: [UIImage] = []
        for r in results {
            switch r {
            case .image(let i): images.append(i)
            case .file(let d, let ext) where ChainPayload.isPhoto(ext):
                guard let i = UIImage(data: d) else { return nil }
                images.append(i)
            default: return nil
            }
        }
        guard images.count >= 2, let first = images.first, let last = images.last else { return nil }
        return .image(ChainImage.beforeAfter(first, last))
    }

    /// "One picture for everything": the results of a multi-photo run as a single collage. nil when a result isn't a picture.
    static func onePicture(_ results: [ChainPayload]) -> ChainPayload? {
        var images: [UIImage] = []
        for r in results {
            switch r {
            case .image(let i): images.append(i)
            case .file(let d, let ext) where ChainPayload.isPhoto(ext):
                guard let i = UIImage(data: d) else { return nil }
                images.append(i)
            default: return nil
            }
        }
        return ChainImage.collage(images).map { ChainPayload.image($0) }
    }
}

/// Your reusable details for paperwork. The signature lives with the scanner (`DocEngine.savedSignature`); the name is here.
/// Both stay on this phone, in the App Group so the share sheet can use them.
enum StampBook {
    private static let nameKey = "stamps.name"
    static var name: String {
        get { AppGroup.defaults.string(forKey: nameKey) ?? "" }
        set { AppGroup.defaults.set(newValue, forKey: nameKey) }
    }
}

/// Where a tool puts your signature, your name and the date on a page. Positions are fractions of the page, so one
/// plan fits every scan of the same form: place them once, and the tool does it by itself from then on.
struct StampPlan: Equatable {
    enum Mark: String, CaseIterable {
        case signature = "sig", name, date
        var title: String { switch self { case .signature: return "My signature"; case .name: return "My name"; case .date: return "Today's date" } }
        var short: String { switch self { case .signature: return "Signature"; case .name: return "Name"; case .date: return "Date" } }
        /// Where it starts before the person moves it: signature bottom right, date bottom left, name above the date.
        var home: Spot {
            switch self {
            case .signature: return Spot(mark: self, x: 0.72, y: 0.88, w: 0.30)
            case .date: return Spot(mark: self, x: 0.25, y: 0.88, w: 0.22)
            case .name: return Spot(mark: self, x: 0.25, y: 0.82, w: 0.30)
            }
        }
    }
    struct Spot: Equatable { var mark: Mark; var x: Double; var y: Double; var w: Double }

    var spots: [Spot]
    static let standard = StampPlan(spots: [Mark.signature.home, Mark.date.home])

    init(spots: [Spot]) { self.spots = spots }

    /// Reads "sig@0.720,0.880,0.300;date@0.250,0.880,0.220". Anything malformed is skipped, values are kept on the
    /// page, and a mark listed twice counts once.
    init(_ text: String) {
        var out: [Spot] = []
        for part in text.split(separator: ";") {
            let bits = part.split(separator: "@")
            guard bits.count == 2, let mark = Mark(rawValue: String(bits[0]).trimmingCharacters(in: .whitespaces)) else { continue }
            let n = bits[1].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard n.count == 3, !out.contains(where: { $0.mark == mark }) else { continue }
            out.append(Spot(mark: mark, x: min(1, max(0, n[0])), y: min(1, max(0, n[1])), w: min(0.9, max(0.08, n[2]))))
        }
        spots = out
    }

    var text: String {
        spots.map { "\($0.mark.rawValue)@" + [$0.x, $0.y, $0.w].map { String(format: "%.3f", $0) }.joined(separator: ",") }.joined(separator: ";")
    }
    func has(_ m: Mark) -> Bool { spots.contains { $0.mark == m } }
    mutating func set(_ m: Mark, on: Bool) {
        if on, !has(m) { spots.append(m.home) } else if !on { spots.removeAll { $0.mark == m } }
    }
    mutating func move(_ m: Mark, x: Double, y: Double) {
        guard let i = spots.firstIndex(where: { $0.mark == m }) else { return }
        spots[i].x = min(1, max(0, x)); spots[i].y = min(1, max(0, y))
    }

    static func dateText(_ day: Date, locale: Locale = .current) -> String {
        let f = DateFormatter(); f.locale = locale; f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: day)
    }
}

/// File names for results. "{date}" becomes today's date and "{tool}" the tool's name; characters a file name
/// can't hold are dropped; several results from one run get -1, -2...
enum ChainName {
    static func file(pattern: String?, tool: String, day: Date = Date(), index: Int? = nil, ext: String) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        var base = (pattern ?? "").replacingOccurrences(of: "{date}", with: f.string(from: day)).replacingOccurrences(of: "{tool}", with: tool)
            .replacingOccurrences(of: "{month}", with: String(f.string(from: day).prefix(7)))
        base = String(base.unicodeScalars.filter { !"/\\:*?\"<>|".unicodeScalars.contains($0) && !CharacterSet.newlines.contains($0) && !CharacterSet.controlCharacters.contains($0) })
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".")))
        if base.count > 80 { base = String(base.prefix(80)).trimmingCharacters(in: .whitespaces) }
        if base.isEmpty { base = index == nil ? "Tenzy-result" : "Tenzy" }
        return base + (index.map { "-\($0)" } ?? "") + "." + ext
    }
}

/// A sheet that grows: each run adds rows to the same CSV instead of making a new file. Kept on this phone.
enum RunningList {
    static let defaultName = "Expenses {month}"

    /// The old sheet plus the new rows. If the new rows start with the sheet's own header line, that line is not
    /// repeated. Blank lines are dropped. Pure, so it is unit-tested.
    static func merged(existing: String, incoming: String) -> String {
        func rows(_ s: String) -> [String] {
            s.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        let old = rows(existing)
        var new = rows(incoming)
        if let header = old.first, new.first == header { new.removeFirst() }
        return (old + new).joined(separator: "\n")
    }

    private static var folder: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Lists", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    static func read(_ fileName: String) -> String {
        (try? String(contentsOf: folder.appendingPathComponent(fileName), encoding: .utf8)) ?? ""
    }
    @discardableResult static func write(_ fileName: String, _ text: String) -> Bool {
        (try? text.write(to: folder.appendingPathComponent(fileName), atomically: true, encoding: .utf8)) != nil
    }
    static func delete(_ fileName: String) { try? FileManager.default.removeItem(at: folder.appendingPathComponent(fileName)) }

    /// One saved sheet, as the Sheets screen lists it.
    struct Sheet: Identifiable, Equatable {
        let file: String
        let rows: Int
        let changed: Date
        var id: String { file }
        /// The name without ".csv".
        var name: String { (file as NSString).deletingPathExtension }
    }

    /// Entries below the header line. A sheet with only a header has none.
    static func rowCount(_ text: String) -> Int {
        max(0, text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count - 1)
    }

    static func url(_ fileName: String) -> URL { folder.appendingPathComponent(fileName) }

    /// Every sheet on this phone, most recently changed first.
    static func all() -> [Sheet] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.filter { $0.pathExtension.lowercased() == "csv" }.map { u in
            Sheet(file: u.lastPathComponent, rows: rowCount((try? String(contentsOf: u, encoding: .utf8)) ?? ""),
                  changed: (try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast)
        }.sorted { $0.changed > $1.changed }
    }

    /// Gives a sheet a new name. Returns the new file name, or nil if the name is empty, unchanged or already taken.
    @discardableResult static func rename(_ fileName: String, to newName: String) -> String? {
        let target = ChainName.file(pattern: newName, tool: "List", ext: "csv")
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty, target != fileName, target != "Tenzy-result.csv",
              !FileManager.default.fileExists(atPath: url(target).path) else { return nil }
        return (try? FileManager.default.moveItem(at: url(fileName), to: url(target))) != nil ? target : nil
    }

    /// Removes the last entry (the row added by mistake). Returns false when there is no entry to remove.
    @discardableResult static func removeLastRow(_ fileName: String) -> Bool {
        var lines = read(fileName).components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count > 1 else { return false }
        lines.removeLast()
        return write(fileName, lines.joined(separator: "\n"))
    }
}

/// A tool as a link or a QR code. The whole tool rides in the part of the link after "#", which a browser never
/// sends to the website, so the page that opens it learns nothing about the tool.
enum ToolLink {
    /// The page below is published (12 Nov 2026), so link and QR sharing are offered. Set this to false to hide them again.
    static let live = true
    static let page = "https://manan99991.github.io/tenzy/t.html"

    /// The link for a tool. It never carries recipients, reminder times or a PDF password (see `Chain.shareText`).
    static func link(for chain: Chain) -> String? {
        let text = chain.shareText
        guard text.hasPrefix(Chain.prefix), let d = String(text.dropFirst(Chain.prefix.count)).data(using: .utf8) else { return nil }
        let packed = d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return page + "#" + packed
    }

    /// The tool in a link from `link(for:)`, in the "tenzy://import?d=..." form the page hands to the app, or in copied
    /// tool text. nil for anything else, or for a tool whose steps don't fit together.
    static func chain(from link: String) -> Chain? {
        let t = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix(Chain.prefix) { return Chain.imported(from: t) }
        var packed: Substring
        if t.hasPrefix(page), let i = t.firstIndex(of: "#") { packed = t[t.index(after: i)...] }
        else if t.hasPrefix("tenzy://import"), let r = t.range(of: "d=") { packed = t[r.upperBound...] }
        else { return nil }
        if let end = packed.firstIndex(of: "&") { packed = packed[..<end] }
        var b64 = packed.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let d = Data(base64Encoded: b64), let json = String(data: d, encoding: .utf8) else { return nil }
        return Chain.imported(from: Chain.prefix + json)
    }
}
