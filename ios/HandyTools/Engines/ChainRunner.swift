import UIKit
import PDFKit
import ImageIO

/// The same photo with its hidden data (location, camera details, XMP) taken out, copied without re-encoding so
/// the pixels, quality and size stay as they were. The orientation is kept, so the photo isn't turned on its side.
enum ImageClean {
    static func isJPEG(_ ext: String) -> Bool { ["jpg", "jpeg"].contains(ext.lowercased()) }

    static func withoutMetadata(_ data: Data) -> Data? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(src) == 1,
              let type = CGImageSourceGetType(src) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        let orientation = (props?[kCGImagePropertyOrientation] as? NSNumber) ?? 1
        let out = NSMutableData()
        guard let dst = CGImageDestinationCreateWithData(out, type, 1, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageDestinationMetadata: CGImageMetadataCreateMutable(),
            kCGImageDestinationMergeMetadata: false,
            kCGImageMetadataShouldExcludeGPS: true,
            kCGImageMetadataShouldExcludeXMP: true,
            kCGImageDestinationOrientation: orientation,
        ]
        guard CGImageDestinationCopyImageSource(dst, src, opts as CFDictionary, nil) else { return nil }
        let d = out as Data
        // Belt and braces: never hand back something that no longer opens or still says where it was taken.
        guard let check = CGImageSourceCreateWithData(d as CFData, nil),
              let p = CGImageSourceCopyPropertiesAtIndex(check, 0, nil) as? [CFString: Any],
              p[kCGImagePropertyGPSDictionary] == nil else { return nil }
        return d
    }
}

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
    // The common audio file endings, so a recording is recognised as audio however it arrives — an
    // external recorder's MP3/WAV, a WhatsApp/Telegram voice note (opus/ogg), an Apple memo (m4a/caf), an
    // old AMR/AIFF, a WMA. Anything the recogniser's reader can't open natively is transcoded first.
    static func isAudio(_ ext: String) -> Bool {
        ["m4a", "m4b", "m4r", "mp3", "mp2", "mpga", "wav", "wave", "aac", "caf", "ogg", "oga", "opus",
         "flac", "aiff", "aif", "aifc", "amr", "wma", "au", "snd", "aax"].contains(ext.lowercased())
    }
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
    case artFilter, voiceChange, videoCelebrate

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
        case .videoCelebrate: return "Decorate it for a celebration"
        case .artFilter: return "Sketch, comic or pop art"
        case .voiceChange: return "Change the voice"
        }
    }
    var takes: ChainKind {
        switch self {
        case .readText, .shrinkImage, .stripLocation, .cutout, .enhance, .convertImage, .hideSensitive, .passportPhoto, .describe, .identify, .photoPdf, .watermark, .resizePhoto, .stamp, .readCode, .sticker, .emojiFaces, .meme, .emojiMosaic, .artFilter: return .image
        case .pullReceipt, .summarize, .businessCard, .calendarEvent, .actionItems, .cleanText, .pullDetails, .makeTable, .scamCheck, .cleanLinks, .priceCompare, .makeQr, .expenseRow, .addToList, .chatLink, .contactQr, .wifiQr, .returnBy, .readAloud, .translate, .rewrite, .pageText, .textPdf: return .text
        case .videoShrink, .videoStill, .videoMute, .videoAudio, .videoTrim, .videoGif, .videoRotate, .videoVertical, .videoCaptions, .videoSpeed, .videoLoop, .videoCelebrate: return .video
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
        case .videoShrink, .videoMute, .videoTrim, .videoRotate, .videoVertical, .videoCaptions, .videoSpeed, .videoCelebrate: return .video
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
        case .sticker, .emojiFaces, .meme, .emojiMosaic, .videoSpeed, .videoLoop, .artFilter, .voiceChange, .videoCelebrate: return "Just for fun"
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

    /// A plain, present-tense phrase for what this step does, lowercase so steps read as one sentence:
    /// "reads the text in your photo, then finds the best-value option." Used to explain a tool up front.
    var does: String {
        switch self {
        case .readText: return "reads the printed text"
        case .pullReceipt: return "pulls the items and total off a receipt"
        case .summarize: return "shortens it to a few sentences"
        case .shrinkImage: return "shrinks it under a size you choose"
        case .stripLocation: return "removes the hidden location and camera data"
        case .cutout: return "cuts the subject out from the background"
        case .enhance: return "sharpens and cleans it up"
        case .convertImage: return "converts it to an everyday format"
        case .businessCard: return "turns a card into a saveable contact"
        case .calendarEvent: return "turns a date into a calendar event"
        case .actionItems: return "pulls out the to-dos"
        case .hideSensitive: return "blurs faces and numbers"
        case .passportPhoto: return "makes a passport/ID photo to spec"
        case .cleanText: return "tidies the spacing and line breaks"
        case .pullDetails: return "finds the links, emails and phone numbers"
        case .makeTable: return "turns a list into a spreadsheet"
        case .scamCheck: return "checks it for scam warning signs"
        case .cleanLinks: return "strips the tracking from a link"
        case .priceCompare: return "finds the best-value option"
        case .makeQr: return "makes a QR code"
        case .describe: return "describes what's in the picture"
        case .identify: return "identifies what it is"
        case .photoPdf: return "makes a searchable PDF"
        case .watermark: return "stamps a watermark across it"
        case .resizePhoto: return "resizes it to exact pixels"
        case .stamp: return "adds your signature and marks"
        case .expenseRow: return "makes one expense row"
        case .addToList: return "adds it to a running list"
        case .chatLink: return "makes a WhatsApp link for a number"
        case .contactQr: return "makes a QR code of your contact"
        case .wifiQr: return "makes a Wi-Fi join code"
        case .returnBy: return "sets a return-by reminder"
        case .videoShrink: return "shrinks the video under a size"
        case .videoStill: return "picks the sharpest, best-lit frame"
        case .videoMute: return "removes the sound"
        case .videoAudio: return "keeps only the sound"
        case .videoTrim: return "keeps the part you choose"
        case .videoGif: return "makes a GIF"
        case .videoRotate: return "turns it the right way up"
        case .videoVertical: return "crops it to tall 9:16"
        case .videoCaptions: return "adds spoken captions"
        case .speechText: return "writes out what is said"
        case .readAloud: return "reads it aloud"
        case .translate: return "translates it"
        case .rewrite: return "rewrites it in a clearer tone"
        case .readCode: return "reads a QR or barcode"
        case .pageText: return "reads the page at a link"
        case .textPdf: return "turns text into a PDF"
        case .pdfShrink: return "shrinks the PDF"
        case .pdfLock: return "protects it — password, watermark, no printing or copying"
        case .pdfPages: return "keeps the pages you choose"
        case .pdfText: return "reads the PDF's words"
        case .sticker: return "makes a cut-out sticker"
        case .emojiFaces: return "covers faces with emoji"
        case .meme: return "adds a top and bottom caption"
        case .emojiMosaic: return "rebuilds it out of emoji"
        case .videoSpeed: return "speeds it up or slows it down"
        case .videoLoop: return "makes it loop"
        case .videoCelebrate: return "decorates it for a celebration, with your words"
        case .artFilter: return "applies an art style"
        case .voiceChange: return "changes the voice"
        }
    }

    /// A friendly description of what GOOD input looks like — shown up front as a hint and reused in the
    /// "couldn't find anything" message so a failure always tells the person exactly how to get a result.
    var needs: String {
        switch self {
        case .priceCompare: return "a photo showing at least two options with their price and size, like a supermarket shelf"
        case .pullReceipt, .expenseRow: return "a photo of a receipt showing the items and the total"
        case .businessCard: return "a business card or signature with a phone number or email"
        case .calendarEvent, .returnBy: return "something that mentions a date (a poster, a bill, a letter)"
        case .makeTable: return "a list or table — rows of items, like a menu or a receipt"
        case .scamCheck: return "the message, email or link you want checked"
        case .wifiQr: return "a photo or text showing the Wi-Fi name and password"
        case .chatLink: return "a phone number in the text"
        case .pullDetails: return "text that contains a link, email or phone number"
        case .actionItems: return "notes or a transcript with things to do in them"
        case .readCode: return "a photo with a QR code or barcode in it"
        case .identify, .describe: return "a clear, close photo of the thing"
        case .readText: return "a clear photo of printed or written words"
        case .pdfText: return "a PDF with words in it"
        case .pageText: return "a link to a web page"
        case .speechText: return "a recording of someone talking"
        default: return takes == .text ? "some text to work with" : takes == .image ? "a clear, close photo" : takes == .video ? "a video" : takes == .pdf ? "a PDF" : "a recording"
        }
    }
}

extension Chain {
    /// One plain sentence describing what the whole flow does, built from its steps — so a tool explains
    /// itself the moment it opens instead of showing a bare title and three file buttons.
    var about: String {
        if let blurb { return blurb }
        let parts = steps.map { $0.block.does }
        guard let first = parts.first else { return "" }
        let body: String
        if parts.count == 1 { body = first }
        else { body = parts.dropLast().joined(separator: ", ") + ", then " + parts.last! }
        return body.prefix(1).uppercased() + body.dropFirst() + "."
    }
    /// What good input looks like, from the first step — the hint shown under the description.
    /// The most telling step's hint: a receipt tool says "a photo of a receipt…", not the reading step's general one.
    var wants: String? {
        if let h = Chain.inputHints[id] { return h }
        let general: Set<Block> = [.readText, .pdfText, .pageText, .speechText]
        let specific = steps.dropFirst().first { !general.contains($0.block) && $0.block.takes == steps.first?.block.gives && $0.block.needs != "some text to work with" }
        return (specific ?? steps.first)?.block.needs
    }
    /// Ready-made text tools whose steps alone would say "some text to work with": what to actually give each one.
    static let inputHints: [String: String] = [
        "clean-link": "a link copied from anywhere — a shop, a post, an email",
        "contact-qr": "your name, phone and email (tap Contact to fill them in)",
        "listen-later": "an article, email or notes you'd rather hear than read",
        "short-summary": "a long article, email or notes",
        "tidy-text": "text copied from a PDF, email or web page with broken lines",
        "text-to-qr": "a link, a Wi-Fi password or any short text",
        "signature-contact": "an email signature with a name, phone or email",
        "rewrite-clear": "a message you wrote that you want to sound clearer",
        "where-i-am": "a short note, then tap Location to add where you are",
    ]
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
    /// A hand-written description that overrides the auto-built `about` sentence — for tools (collage, GIF)
    /// whose processing step would otherwise describe the wrong thing (e.g. "removes location").
    var blurb: String?
    /// When several photos go in at once, play the results one after another as a single looping GIF.
    var gif: Bool?
    /// Before and after: the first and last of the photos side by side, each with its label.
    var versus: Bool?
    /// Flipbook: the chosen photos played as a page-turning riffle video.
    var flipbook: Bool?
    /// "Tell me when" the number in this tool's result crosses a value. nil: off.
    var watch: NumberWatch?

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

    /// Best-effort outcome for the UI: even when a step can't finish, hand back the furthest the flow
    /// got — the text an OCR step read, say — instead of nothing. So the person always sees their input
    /// was used and keeps whatever value was produced, and only a flow that got NOWHERE shows a bare error.
    enum Outcome {
        case done(ChainPayload)                  // every step finished
        case partial(ChainPayload, Failure)      // got this far, then the named step couldn't finish
        case failed(Failure)                     // nothing usable at all
    }

    static func runKeepingBest(_ chain: Chain, input: ChainPayload) async -> Outcome {
        if let p = chain.problem(starting: input.kind) { return .failed(.invalid(p)) }
        var value = input
        var best: ChainPayload? = nil   // the furthest useful result past the raw input
        var lastIn: ChainPayload? = nil
        for (i, step) in chain.steps.enumerated() {
            let isLast = i == chain.steps.count - 1
            if isLast { lastIn = value }
            switch await apply(step, to: value) {
            case .success(let next): value = next; best = next
            case .failure(.nothingFound) where !isLast && step.block.takes == step.block.gives:
                // An optional same-type "find/extract" step (find links, find tasks, tidy… text→text) had
                // nothing to pull out of what the step above handed it. That's not a reason to dead-end the
                // whole flow — pass the input straight through so every remaining step still runs. Only
                // applies when the step returns the same type it took, so the next step still gets valid
                // input; a step that changes type (read a QR → text) can't be skipped this way. The final
                // step, or any real processing failure, still stops a flow.
                continue
            case .failure(let f):
                return best.map { .partial($0, f) } ?? .failed(f)
            }
        }
        return .done(value)
    }

    /// A per-step record of a run, so the UI can show the person exactly what went through: which steps
    /// ran, which were skipped because there was nothing to find, and which couldn't finish and why.
    struct RunReport {
        enum Mark: Equatable { case ran, skipped, stopped(Failure) }
        struct Line: Identifiable { let id = UUID(); let block: Block; let mark: Mark }
        var lines: [Line]
        var result: ChainPayload?      // the furthest useful payload (the final one if it completed)
        var completed: Bool            // reached the end (some steps may have been skipped)
        var stopper: Failure?          // the failure that stopped it, if it didn't complete
        var finalInput: ChainPayload? = nil   // what the last step was given (e.g. the text a scam check judged)
    }

    /// Runs the flow and records every step's outcome. Same best-effort rules as runKeepingBest — an
    /// optional same-type find step that finds nothing is marked skipped, not failed — but it hands the
    /// UI the whole step-by-step story so the person always knows what happened end to end.
    static func runReport(_ chain: Chain, input: ChainPayload) async -> RunReport {
        if let p = chain.problem(starting: input.kind) {
            return RunReport(lines: [], result: nil, completed: false, stopper: .invalid(p))
        }
        var value = input
        var best: ChainPayload? = nil
        var lines: [RunReport.Line] = []
        var lastIn: ChainPayload? = nil
        for (i, step) in chain.steps.enumerated() {
            let isLast = i == chain.steps.count - 1
            if isLast { lastIn = value }
            switch await apply(step, to: value) {
            case .success(let next):
                value = next; best = next
                lines.append(.init(block: step.block, mark: .ran))
            case .failure(.nothingFound) where !isLast && step.block.takes == step.block.gives:
                lines.append(.init(block: step.block, mark: .skipped))
            case .failure(let f):
                lines.append(.init(block: step.block, mark: .stopped(f)))
                return RunReport(lines: lines, result: best, completed: false, stopper: f)
            }
        }
        return RunReport(lines: lines, result: best ?? value, completed: true, stopper: nil, finalInput: lastIn)
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
            // Read the document, not the screen around it: a receipt in a screenshot is cut out of the browser or
            // app first, and the phone's status bar ("9:32", battery) is never read as part of it.
            let ocr = ChainText.readDocument(img)
            let text = rows(ocr).trimmingCharacters(in: .whitespacesAndNewlines)
            // Remember how big each piece was printed, so a poster's biggest words can become its title.
            DataGrab.rememberHeights(text, Dictionary(ocr.map { ($0.text, $0.box.height) }, uniquingKeysWith: max))
            return text.isEmpty ? .failure(.nothingFound(b)) : .success(.text(text))

        case (.pullReceipt, .text(let t)):
            let r = DataGrab.receipt(t)
            guard r.total != nil || !r.items.isEmpty else { return .failure(.nothingFound(b)) }
            let csv = DataGrab.receiptCSV(r)
            DataGrab.remember(csv, r)
            return .success(.text(csv))

        case (.summarize, .text(let t)):
            let n = Int(step.settings["sentences"] ?? "") ?? 3
            let s = TextTools.summarize(t, sentences: max(1, n))
            return s.isEmpty ? .failure(.nothingFound(b)) : .success(.text(ChainText.summaryText(s, bullets: step.settings["format"] == "bullets")))

        case (.shrinkImage, .image(let img)):
            let mb = Double(step.settings["mb"] ?? "") ?? 2
            // "2 MB" means 2,000,000 bytes — what upload sites count and what the phone shows — so it's always under.
            let target = Int(max(0.01, mb) * 1_000_000)
            // A JPEG already under the size is kept as it is (only its hidden data removed): re-saving it would
            // lose quality and could even make it bigger (119 KB came back as 124 KB, Nov 21).
            if case .file(let d, let ext) = rawInput, ImageClean.isJPEG(ext), d.count <= target, let same = ImageClean.withoutMetadata(d) {
                return .success(.file(same, ext: "jpg"))
            }
            guard let data = await SizeTarget.image(img, targetBytes: target) else { return .failure(.failed(b)) }
            return .success(.file(data, ext: "jpg"))

        case (.stripLocation, .image(let img)):
            // A JPEG keeps its exact pixels — only the location, camera and XMP data come out, so it's never
            // bigger or softer than what went in. Anything else is re-encoded from pixels, which carries none across.
            if case .file(let d, let ext) = rawInput, ImageClean.isJPEG(ext), let same = ImageClean.withoutMetadata(d) {
                return .success(.file(same, ext: "jpg"))
            }
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
            let e = DataGrab.event(t, heights: DataGrab.heights(for: t))
            guard e.start != nil, let d = DataGrab.ics(e).data(using: .utf8) else { return .failure(.nothingFound(b)) }
            return .success(.file(d, ext: "ics"))

        case (.actionItems, .text(let t)):
            let items = TextTools.actionItems(t)
            guard !items.isEmpty else { return .failure(.nothingFound(b)) }
            // Smart task list: any task that means "go somewhere" gets a one-tap Maps directions link, and
            // obvious first/last tasks are ordered. Tasks with no place are listed plainly, so it never
            // gets in the way. (Phase 2 adds real in-app drive-time ETAs and a timed itinerary.)
            return .success(.text(RoutePlan.plan(from: items)))

        case (.cleanText, .text(let t)):
            let out = TextTidy.clean(t, oneParagraph: TextTidy.reflowsToParagraph(step.settings["shape"]))
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
            guard let img = ChainText.qr(msg, correction: ChainText.qrCorrection(step.settings["sturdiness"])) else { return .failure(.failed(b)) }   // too long for one code
            return .success(.image(img))

        case (.describe, .image(let img)):
            let p = SceneDescriber.perceive(img)
            let text = await SceneDescriber.polish(p, fallback: SceneDescriber.compose(p)).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? .failure(.nothingFound(b)) : .success(.text(text))

        case (.identify, .image(let img)):
            let o = await Identifier.identify(img)
            // Mostly writing: say what kind of written thing it is and carry everything read, so the card can open
            // the right reader in place — not "Document 71%" and a web search.
            if let p = o.paper { return .success(.text(Paper.encode(p))) }
            // A busy people-scene with nothing to name: say so honestly instead of guessing an object.
            if let note = o.sceneNote, o.guesses.isEmpty, o.barcode == nil {
                return .success(.text(note))
            }
            func pct(_ x: Double) -> Int { Int((x * 100).rounded()) }
            var lines: [String] = []
            if let top = o.guesses.first {
                lines.append("Most likely: \(top.label) — \(pct(top.confidence))%")
                let rest = o.guesses.dropFirst().prefix(3).map { "\($0.label) — \(pct($0.confidence))%" }
                if !rest.isEmpty { lines.append("Also: " + rest.joined(separator: ", ")) }
            }
            if let t = o.text { lines.append("Text: \(t)") }
            if let code = o.barcode { lines.append("Barcode: \(code)" + (o.symbology.map { " (\($0))" } ?? "")) }
            return lines.isEmpty ? .failure(.nothingFound(b)) : .success(.text(lines.joined(separator: "\n")))

        case (.photoPdf, .image(let img)):
            var opts = DocEngine.PDFOptions()
            switch step.settings["pagesize"] { case "a4": opts.pageSize = .a4; case "letter": opts.pageSize = .letter; default: break }
            if step.settings["searchable"] == "false" { opts.searchable = false }
            // A photo of a page becomes the page: corners found and flattened, paper whitened, ink darkened —
            // like a scanner, not a snapshot of a desk. "Keep as photographed" turns it off.
            let page = step.settings["flatten"] == "false" ? img : PageFlatten.scan(img).image
            guard let d = DocEngine.pdf(images: [page], ocr: [opts.searchable ? DocEngine.recognize(page) : nil], options: opts) else { return .failure(.failed(b)) }
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
            // Only a receipt becomes an expense: a total AND what a receipt looks like (several amounts, a total or
            // tax or payment line). A whiteboard, an app screen or a parcel note is never written into the sheet.
            guard r.total != nil, DataGrab.looksLikeReceipt(t) else {
                return .failure(.invalid("That doesn't look like a receipt, so nothing was added to your sheet. Use a photo or screenshot of the receipt itself."))
            }
            let row = DataGrab.expenseRow(r)
            DataGrab.remember(row, r)
            return .success(.text(row))

        case (.videoShrink, .video(let url)):
            // Re-encoded to fit the limit. The new file carries no location or camera details from the original.
            let mb = ChainText.videoLimit(step.settings["mb"])
            await MainActor.run { RunProgress.shared.begin() }
            let out = await SizeTarget.videoBestEffort(url: url, targetBytes: mb * 1_000_000) { f in Task { @MainActor in RunProgress.shared.set(f) } }
            await MainActor.run { RunProgress.shared.end() }
            guard let out else { return .failure(.failed(b)) }
            return .success(.video(out.url))

        case (.videoStill, .video(let url)):
            guard let img = await VideoEngine.bestFrame(url, maxDim: 1920) else { return .failure(.failed(b)) }
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
                    guard let sig = DocEngine.savedSignature else { return .failure(.invalid("Sign and stamp needs your signature first. In Tenzy, open this tool and tap Draw my signature — it's kept for next time.")) }
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
            // The same engine as Studio and the passport screen: measured to the country's rules, fixed, graded.
            guard let made = PassportPhoto.make(img, spec: PassportPhoto.spec(step.settings["country"])), let d = PassportPhoto.file(made) else { return .failure(.nothingFound(b)) }
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

/// Which finished result screen a tool lands on — the same screen its dedicated tool uses — or nil when it still
/// ends on the plain result (a bare picture, file or text). The Builder's result view routes by this, and a test
/// fails if any ready-made tool lands on the plain result without being on the public known-gap list.
enum ResultScreens {
    static func screen(for chain: Chain) -> String? {
        let blocks = chain.steps.map(\.block)
        guard let last = blocks.last else { return nil }
        if blocks == [.readText, .actionItems], chain.finish == nil { return "Board review" }
        if blocks.contains(.watermark), [.watermark, .stripLocation, .shrinkImage].contains(last) { return "ID copy" }
        if chain.gif == true { return "GIF finish" }
        if chain.collage == true || chain.versus == true { return "Picture finish" }
        if chain.flipbook == true { return "Video finish" }
        if [.shrinkImage, .stripLocation, .hideSensitive, .resizePhoto, .enhance, .convertImage].contains(last) { return "Photo finish" }
        switch last {
        case .cutout: return "Cut-out finishing"
        case .identify: return "What is this / written things"
        case .passportPhoto: return "Passport studio"
        case .pullReceipt, .expenseRow: return "Receipt"
        case .addToList where blocks.contains(.expenseRow): return "Expense sheet"
        case .actionItems: return "Reminders"
        case .pullDetails: return "Links, emails, phones"
        case .calendarEvent: return "Calendar event"
        case .businessCard: return "Contact card"
        case .videoShrink, .videoTrim, .videoSpeed, .videoMute, .videoVertical, .videoCaptions, .videoRotate, .videoCelebrate: return "Video finish"
        case .videoGif, .videoLoop: return "GIF finish"
        case .scamCheck: return "Scam verdict"
        case .voiceChange: return "Voice finish"
        case .readAloud: return "Listen finish"
        case .makeTable: return "Table"
        case .cleanLinks: return "Clean link"
        case .priceCompare: return "Best deal"
        case .videoStill: return "Still"
        case .returnBy: return "Calendar event"
        case .summarize, .translate, .rewrite, .cleanText, .speechText: return "Text finish"
        case .sticker, .emojiFaces, .meme, .artFilter, .emojiMosaic: return "Fun finish"
        case .makeQr, .wifiQr, .contactQr: return "Code finish"
        case .chatLink: return "Chat link"
        case .photoPdf: return "Scan PDF"
        case .pdfShrink where blocks.contains(.photoPdf): return "Scan PDF"
        case .pdfShrink, .pdfPages, .textPdf, .pdfLock: return "PDF finish"
        default: return nil
        }
    }

    /// Ready-made tools that still end on the plain result, each with the tracker group rebuilding it. This list may
    /// only shrink: the test fails if a tool here now has a finished screen (take it off) or a new tool lands plain.
    static let knownGaps: [String: String] = [:]
}

/// Starter chains shipped inside the app. Users can run them, or copy one and edit it.
enum ChainTemplates {
    static let all: [Chain] = [
        Chain(id: "receipt-to-row", name: "Read a receipt into your expenses", steps: [
            ChainStep(block: .readText), ChainStep(block: .pullReceipt)]),
        Chain(id: "photo-under-2mb", name: "Shrink a photo to under 2 MB", steps: [
            ChainStep(block: .shrinkImage, settings: ["mb": "2"])]),
        Chain(id: "safe-to-share", name: "Make a photo safe to share", steps: [
            ChainStep(block: .stripLocation), ]),
        Chain(id: "card-to-contact", name: "Turn a business card into a contact", steps: [ChainStep(block: .readText), ChainStep(block: .businessCard)]),
        Chain(id: "poster-to-event", name: "Turn a poster into a calendar event", steps: [ChainStep(block: .readText), ChainStep(block: .calendarEvent)]),
        Chain(id: "whiteboard-to-tasks", name: "Turn a whiteboard into a task list", steps: [ChainStep(block: .readText), ChainStep(block: .actionItems)]),
        Chain(id: "passport-photo", name: "Make a passport photo", steps: [ChainStep(block: .passportPhoto, settings: ["country": "us"])]),
        Chain(id: "hide-sensitive", name: "Hide faces and numbers in a photo", steps: [ChainStep(block: .hideSensitive)]),
        Chain(id: "short-summary", name: "Sum up long text in 3 sentences", steps: [ChainStep(block: .summarize, settings: ["sentences": "3"])]),
        Chain(id: "sticker", name: "Cut the subject out of a photo", steps: [ChainStep(block: .cutout)]),
        Chain(id: "table-to-sheet", name: "Turn a photo of a table into a spreadsheet", steps: [ChainStep(block: .readText), ChainStep(block: .makeTable)]),
        Chain(id: "links-and-numbers", name: "Pull out links, emails and phone numbers", steps: [ChainStep(block: .pullDetails)]),
        Chain(id: "tidy-text", name: "Tidy up pasted text", steps: [ChainStep(block: .cleanText)]),
        Chain(id: "scam-check", name: "Check if a message is a scam", steps: [ChainStep(block: .scamCheck)]),
        Chain(id: "clean-link", name: "Strip the tracking from a link", steps: [ChainStep(block: .cleanLinks)]),
        Chain(id: "shelf-best-deal", name: "Find the best deal on a shelf photo", steps: [ChainStep(block: .readText), ChainStep(block: .priceCompare)]),
        Chain(id: "photo-to-pdf", name: "Turn a photo into a searchable PDF", steps: [ChainStep(block: .photoPdf)]),
        Chain(id: "text-to-qr", name: "Turn text or a link into a QR code", steps: [ChainStep(block: .makeQr)]),
        Chain(id: "what-is-this", name: "Find out what this is", steps: [ChainStep(block: .identify)]),
        Chain(id: "scan-to-pdf", name: "Scan pages into one PDF", steps: [ChainStep(block: .photoPdf)], combine: true),
        Chain(id: "sign-and-send", name: "Sign a form and send it", steps: [ChainStep(block: .stamp, settings: ["marks": StampPlan.standard.text]), ChainStep(block: .photoPdf)],
              finish: ChainFinish(kind: .mail, to: ""), combine: true, fileName: "Signed form {date}"),
        Chain(id: "receipt-run", name: "Receipt into this month's expense sheet", steps: [ChainStep(block: .readText), ChainStep(block: .expenseRow), ChainStep(block: .addToList, settings: ["list": RunningList.defaultName])]),
        Chain(id: "whatsapp-no-save", name: "WhatsApp a number without saving it", steps: [ChainStep(block: .chatLink)], finish: ChainFinish(kind: .open, to: "")),
        Chain(id: "contact-qr", name: "Share my contact as a QR code", steps: [ChainStep(block: .contactQr)]),
        Chain(id: "video-email", name: "Shrink a video under 25 MB and email it", steps: [ChainStep(block: .videoShrink, settings: ["mb": "25"])], finish: ChainFinish(kind: .mail, to: "")),
        Chain(id: "video-chat", name: "Shrink a video for chat (under 16 MB)", steps: [ChainStep(block: .videoShrink, settings: ["mb": "16"])]),
        Chain(id: "video-still", name: "Grab a still from a video", steps: [ChainStep(block: .videoStill)]),
        Chain(id: "video-quiet", name: "Remove the sound from a video", steps: [ChainStep(block: .videoMute)]),
        Chain(id: "return-by", name: "Turn a receipt into a return-by reminder", steps: [ChainStep(block: .readText), ChainStep(block: .returnBy, settings: ["days": "30"])]),
        Chain(id: "wifi-sign", name: "Turn a Wi-Fi sign into a join code", steps: [ChainStep(block: .readText), ChainStep(block: .wifiQr)]),
        Chain(id: "id-both-sides", name: "Put both sides of an ID on one page", steps: [ChainStep(block: .watermark, settings: ["text": "For verification only"])], combine: true, onePage: true),
        Chain(id: "share-shield", name: "Hide, strip and shrink a photo to share", steps: [ChainStep(block: .hideSensitive), ChainStep(block: .stripLocation), ChainStep(block: .shrinkImage, settings: ["mb": "2"])]),
        Chain(id: "id-copy-watermarked", name: "Watermark a copy of my ID", steps: [ChainStep(block: .watermark, settings: ["text": "For verification only"]), ChainStep(block: .stripLocation)]),
        Chain(id: "portal-photo", name: "Passport photo: 35x45 mm under 50 KB", steps: [ChainStep(block: .resizePhoto, settings: ["size": "413x531"]), ChainStep(block: .shrinkImage, settings: ["mb": "0.05"])]),
        Chain(id: "memo-to-notes", name: "Turn a voice memo into written notes", steps: [ChainStep(block: .speechText), ChainStep(block: .cleanText)]),
        Chain(id: "memo-to-tasks", name: "Turn a meeting recording into tasks", steps: [ChainStep(block: .speechText), ChainStep(block: .actionItems)]),
        Chain(id: "qr-safe", name: "Check if a QR code is safe", steps: [ChainStep(block: .readCode), ChainStep(block: .scamCheck)]),
        Chain(id: "sign-to-english", name: "Translate a sign or menu into English", steps: [ChainStep(block: .readText), ChainStep(block: .translate, settings: ["to": "en"])]),
        Chain(id: "page-to-pdf", name: "Save a web page as a clean PDF", steps: [ChainStep(block: .pageText), ChainStep(block: .textPdf)]),
        Chain(id: "page-summary", name: "Sum up a web page in 3 sentences", steps: [ChainStep(block: .pageText), ChainStep(block: .summarize, settings: ["sentences": "3"])]),
        Chain(id: "listen-later", name: "Turn text into an audio file", steps: [ChainStep(block: .readAloud)]),
        Chain(id: "pdf-email", name: "Shrink a PDF under 5 MB and email it", steps: [ChainStep(block: .pdfShrink, settings: ["mb": "5"])], finish: ChainFinish(kind: .mail, to: "")),
        Chain(id: "pdf-join", name: "Join PDFs into one", steps: [ChainStep(block: .pdfPages, settings: ["pages": ""])], combine: true),
        Chain(id: "pdf-first-page", name: "Keep just the first page of a PDF", steps: [ChainStep(block: .pdfPages, settings: ["pages": "1"])]),
        Chain(id: "video-story", name: "Cut a video's first 30 s, tall for stories", steps: [ChainStep(block: .videoTrim, settings: ["side": "first", "secs": "30"]), ChainStep(block: .videoVertical)]),
        Chain(id: "video-gif", name: "Turn a video into a GIF", steps: [ChainStep(block: .videoGif)]),
        Chain(id: "video-words", name: "Write out what was said in a video", steps: [ChainStep(block: .videoAudio), ChainStep(block: .speechText)]),
        Chain(id: "photo-collage", name: "Photos into one collage", steps: [ChainStep(block: .stripLocation)], collage: true, blurb: "Lays your chosen photos out as one combined picture."),
        Chain(id: "where-i-am", name: "Send where I am", steps: [ChainStep(block: .cleanText)], finish: ChainFinish(kind: .message, to: ""),
              blurb: "Puts your address and a map link into a message, ready to send."),
        Chain(id: "photos-gif", name: "Turn photos into a GIF", steps: [ChainStep(block: .stripLocation)], blurb: "Plays your chosen photos one after another as a looping GIF.", gif: true),
        Chain(id: "photos-flipbook", name: "Turn photos into a flipbook", steps: [ChainStep(block: .stripLocation)], blurb: "Flips your chosen photos like the pages of a book — a looping page-riffle video to share.", flipbook: true),
        Chain(id: "sticker-maker", name: "Turn a photo into a sticker", steps: [ChainStep(block: .sticker)]),
        Chain(id: "emoji-faces", name: "Put an emoji over every face", steps: [ChainStep(block: .emojiFaces, settings: ["emoji": ChainText.faceEmojis[0]])]),
        Chain(id: "meme", name: "Make a meme", steps: [ChainStep(block: .meme, settings: ["top": "", "bottom": ""])]),
        Chain(id: "emoji-mosaic", name: "Turn a photo into emoji art", steps: [ChainStep(block: .emojiMosaic)]),
        Chain(id: "video-celebrate", name: "Decorate a video for a celebration", steps: [ChainStep(block: .videoCelebrate, settings: ["theme": "", "text": ""])], blurb: "The next festival coming up (or any you pick) — snow, fireworks, diyas, lanterns — with its greeting placed clear of faces."),
        Chain(id: "video-boomerang", name: "Make a boomerang GIF from a video", steps: [ChainStep(block: .videoLoop, settings: ["style": "boomerang"])]),
        Chain(id: "video-slowmo", name: "Slow a video down", steps: [ChainStep(block: .videoSpeed, settings: ["speed": "slow"])]),
        Chain(id: "video-fast", name: "Speed a video up", steps: [ChainStep(block: .videoSpeed, settings: ["speed": "fast"])]),
        Chain(id: "photo-sketch", name: "Turn a photo into a pencil sketch", steps: [ChainStep(block: .artFilter, settings: ["style": "sketch"])]),
        Chain(id: "photo-comic", name: "Turn a photo into a comic", steps: [ChainStep(block: .artFilter, settings: ["style": "comic"])]),
        Chain(id: "voice-chipmunk", name: "Make a recording sound like a chipmunk", steps: [ChainStep(block: .voiceChange, settings: ["voice": "chipmunk"])]),
        Chain(id: "voice-deep", name: "Make a voice sound deep", steps: [ChainStep(block: .voiceChange, settings: ["voice": "deep"])]),
        Chain(id: "voice-helium", name: "Make a voice sound like helium", steps: [ChainStep(block: .voiceChange, settings: ["voice": "helium"])]),
        Chain(id: "voice-giant", name: "Make a voice sound like a giant", steps: [ChainStep(block: .voiceChange, settings: ["voice": "giant"])]),
        Chain(id: "voice-robot", name: "Make a voice sound like a robot", steps: [ChainStep(block: .voiceChange, settings: ["voice": "robot"])]),
        Chain(id: "voice-alien", name: "Make a voice sound like an alien", steps: [ChainStep(block: .voiceChange, settings: ["voice": "alien"])]),
        Chain(id: "voice-monster", name: "Make a voice sound like a monster", steps: [ChainStep(block: .voiceChange, settings: ["voice": "monster"])]),
        Chain(id: "voice-walkie", name: "Make a voice sound like a walkie-talkie", steps: [ChainStep(block: .voiceChange, settings: ["voice": "walkie"])]),
        Chain(id: "voice-cave", name: "Make a voice echo like in a cave", steps: [ChainStep(block: .voiceChange, settings: ["voice": "cave"])]),
        Chain(id: "voice-ghost", name: "Make a voice sound like a ghost", steps: [ChainStep(block: .voiceChange, settings: ["voice": "ghost"])]),
        Chain(id: "video-voice", name: "Give a video a funny voice", steps: [ChainStep(block: .videoAudio), ChainStep(block: .voiceChange, settings: ["voice": "chipmunk"])]),
        Chain(id: "before-after", name: "Make a before-and-after reveal", steps: [ChainStep(block: .stripLocation)], blurb: "Turns your before and after into a swipe-reveal video — the way people post a transformation.", versus: true),
        // Start-to-finish jobs: several steps that together finish a real task, named as what you'd ask for.
        Chain(id: "photo-sell", name: "Get a product photo ready to sell online", steps: [ChainStep(block: .cutout), ChainStep(block: .enhance), ChainStep(block: .resizePhoto, settings: ["size": "1080x1080"]), ChainStep(block: .stripLocation)],
              blurb: "Cuts the item out of its background, brightens it, makes it a square listing photo and removes where it was taken."),
        Chain(id: "letter-listen", name: "Read a foreign letter out loud in English", steps: [ChainStep(block: .readText), ChainStep(block: .translate, settings: ["to": "en"]), ChainStep(block: .readAloud)],
              blurb: "Reads the words on the page, translates them into English and gives you a recording to listen to."),
        Chain(id: "lecture-summary", name: "Sum up a lecture recording in 5 sentences", steps: [ChainStep(block: .speechText), ChainStep(block: .summarize, settings: ["sentences": "5"])],
              blurb: "Writes out everything that was said, then keeps the five sentences that matter most."),
        Chain(id: "meeting-email", name: "Turn a meeting into tasks and email them", steps: [ChainStep(block: .speechText), ChainStep(block: .actionItems)], finish: ChainFinish(kind: .mail, to: ""),
              blurb: "Writes out the meeting, pulls out who does what and by when, and opens an email with the list ready to send."),
        Chain(id: "voice-spanish", name: "Turn a voice memo into Spanish speech", steps: [ChainStep(block: .speechText), ChainStep(block: .translate, settings: ["to": "es"]), ChainStep(block: .readAloud)],
              blurb: "Writes out what you said, translates it into Spanish and reads it back as a recording you can send."),
        Chain(id: "form-portal", name: "Sign a form and make it a PDF under 1 MB", steps: [ChainStep(block: .stamp, settings: ["marks": StampPlan.standard.text]), ChainStep(block: .photoPdf), ChainStep(block: .pdfShrink, settings: ["mb": "1"])], combine: true,
              blurb: "Adds your signature and today's date, makes one PDF of every page and keeps it small enough for any upload form."),
        Chain(id: "doc-portal", name: "Scan a document to a PDF under 1 MB", steps: [ChainStep(block: .photoPdf), ChainStep(block: .pdfShrink, settings: ["mb": "1"])], combine: true,
              blurb: "Turns photos of the pages into one searchable PDF that fits the 1 MB limit most websites set."),
        Chain(id: "id-portal", name: "Watermark my ID and shrink it for upload", steps: [ChainStep(block: .watermark, settings: ["text": "For verification only"]), ChainStep(block: .stripLocation), ChainStep(block: .shrinkImage, settings: ["mb": "0.5"])],
              blurb: "Stamps \u{201C}For verification only\u{201D} across it, removes where it was taken and makes it small enough to upload."),
        Chain(id: "reel-captions", name: "Make a captioned tall clip for Reels", steps: [ChainStep(block: .videoTrim, settings: ["side": "first", "secs": "60"]), ChainStep(block: .videoVertical), ChainStep(block: .videoCaptions)],
              blurb: "Keeps the first minute, crops it tall for Reels, Shorts and TikTok, and writes what's said on screen."),
        Chain(id: "video-minute-email", name: "Email the first minute of a video", steps: [ChainStep(block: .videoTrim, settings: ["side": "first", "secs": "60"]), ChainStep(block: .videoShrink, settings: ["mb": "25"])], finish: ChainFinish(kind: .mail, to: ""),
              blurb: "Keeps the first minute, shrinks it under 25 MB and opens an email with it attached."),
        Chain(id: "pdf-summary", name: "Sum up a PDF in 5 sentences", steps: [ChainStep(block: .pdfText), ChainStep(block: .summarize, settings: ["sentences": "5"])],
              blurb: "Pulls the words out of the PDF and keeps the five sentences that matter most."),
        Chain(id: "pdf-english", name: "Translate a PDF into English", steps: [ChainStep(block: .pdfText), ChainStep(block: .translate, settings: ["to": "en"])],
              blurb: "Pulls the words out of the PDF and translates them into English."),
        Chain(id: "pdf-listen", name: "Listen to a PDF read aloud", steps: [ChainStep(block: .pdfText), ChainStep(block: .readAloud)],
              blurb: "Pulls the words out of the PDF and turns them into a recording for the car or a walk."),
        Chain(id: "page-listen", name: "Hear a web page in English", steps: [ChainStep(block: .pageText), ChainStep(block: .translate, settings: ["to": "en"]), ChainStep(block: .readAloud)],
              blurb: "Takes just the article from a link, translates it into English and reads it to you."),
        Chain(id: "whiteboard-email", name: "Email the tasks on a whiteboard", steps: [ChainStep(block: .readText), ChainStep(block: .actionItems)], finish: ChainFinish(kind: .mail, to: ""),
              blurb: "Reads the whiteboard photo, lists who does what and opens an email with the list ready to send."),
        Chain(id: "chat-scam", name: "Check a screenshot of a chat for scams", steps: [ChainStep(block: .readText), ChainStep(block: .scamCheck)],
              blurb: "Reads the messages in the screenshot and points out the warning signs of a scam, in plain words."),
        Chain(id: "rewrite-clear", name: "Tidy and rewrite a message more clearly", steps: [ChainStep(block: .cleanText), ChainStep(block: .rewrite)],
              blurb: "Fixes spacing and stray line breaks, then rewrites it so it reads clearly and kindly."),
        Chain(id: "signature-contact", name: "Turn an email signature into a contact", steps: [ChainStep(block: .cleanText), ChainStep(block: .businessCard)],
              blurb: "Paste someone's email signature and get a contact with their name, number, email and company filled in."),
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

/// How many of your own tools the free tier keeps. Building and running are always unlimited; Pro lifts the cap on
/// how many you can save. Pure, so it is the same on both phones and unit-tested.
enum BuilderLimits {
    static let freeSaved = 2
    /// Can a tool be saved, given how many are already kept and whether the person has Pro?
    static func canSave(savedCount: Int, isPremium: Bool) -> Bool { isPremium || savedCount < freeSaved }
}

extension Block {
    /// The basic steps a free tool may use. Everything else is a Pro step, so a free tool stays simple and the
    /// yearly subscription unlocks the real power. Pure, the same on both phones, and unit-tested.
    static let freeStepIDs: Set<String> = ["readText", "cleanText", "translate", "summarize", "pullDetails", "makeQr", "wifiQr", "contactQr", "chatLink", "cleanLinks"]
    var isProStep: Bool { !Block.freeStepIDs.contains(rawValue) }
}

extension Chain {
    /// The Pro steps in this tool, in order (empty when every step is free).
    var proSteps: [Block] { steps.map(\.block).filter(\.isProStep) }
    /// True when running or saving this tool needs Pro (it uses at least one Pro step).
    var needsPro: Bool { !proSteps.isEmpty }
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
    /// When the thing is text, link/phone/page tools are hidden unless the text actually has a link or number,
    /// so plain prose never offers a tool that would immediately dead-end with "didn't find one".
    static func offers(for kind: ChainKind, mine: [Chain], last: String?, text: String? = nil) -> [Chain] {
        var all = (mine + ChainTemplates.all).filter { $0.problem(starting: kind) == nil && $0.unavailable == nil }
        if kind == .text, let text { all = all.filter { fitsText($0, text) } }
        if let last, let i = all.firstIndex(where: { $0.id == last }) { all.insert(all.remove(at: i), at: 0) }
        return ChainSame.unique(all)   // the same tool saved twice (or copied from a ready-made) is offered once
    }

    /// A link/phone/page tool fits a piece of text only when that text really contains a link, number or URL.
    static func fitsText(_ chain: Chain, _ text: String) -> Bool {
        switch chain.steps.first?.block {
        case .cleanLinks: return ChainText.cleanLinks(in: text) != nil
        case .chatLink:   return ChainText.chatLink(text, countryCode: ChainText.callingCode(region: Locale.current.region?.identifier)) != nil
        case .pageText:   return ChainText.pageLink(in: text) != nil
        default:          return true
        }
    }
}

/// Plain-text results for the blocks that wrap the scam, link and price engines. Pure, so they are unit-tested.
enum ChainText {
    /// The phone's own status bar in a screenshot — the clock, signal, battery — at the very top of the picture.
    /// The words of the document in a photo or screenshot — cut to the page first when one sits inside it.
    static func readDocument(_ img: UIImage) -> [DocEngine.OCRLine] {
        let page = PageFlatten.cropToPage(img)
        return DocEngine.recognize(page ?? img).filter { page != nil || !isStatusBar($0) }
    }

    static func isStatusBar(_ l: DocEngine.OCRLine) -> Bool {
        guard l.box.minY < 0.045 else { return false }
        let t = l.text.trimmingCharacters(in: .whitespaces)
        return t.range(of: #"^\d{1,2}:\d{2}"#, options: .regularExpression) != nil || t.count <= 4
    }
    static func scamReport(_ r: ScamAnalyzer.Report) -> String {
        var out = [r.verdict.rawValue + "."]
        out += r.findings.sorted { $0.weight > $1.weight }.prefix(4).map { "• \($0.title)" }
        for l in r.links where !l.issues.isEmpty { out.append("• Link \(l.host): \(l.issues.joined(separator: "; "))") }
        if let first = ScamAnalyzer.advice(for: r).first { out.append(""); out.append(first) }
        return out.joined(separator: "\n")
    }

    /// Shapes a summary: a flowing paragraph (default), or one bullet per sentence when the tool is set to bullets.
    static func summaryText(_ sentences: [String], bullets: Bool) -> String {
        bullets ? sentences.map { "• \($0)" }.joined(separator: "\n") : sentences.joined(separator: " ")
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
        return sentence(chain)
    }

    /// A tool's name as a plain sentence from its steps: "Strip location, convert format and make a PDF —
    /// then email it". Sizes are named ("Shrink the PDF under 5 MB").
    static func sentence(_ chain: Chain) -> String {
        let parts: [String] = chain.steps.enumerated().map { i, st in
            var t = st.block.title
            if let mb = st.settings["mb"], !mb.isEmpty, [.pdfShrink, .shrinkImage, .videoShrink].contains(st.block) { t += " under \(mb) MB" }
            return i == 0 ? t : t.prefix(1).lowercased() + t.dropFirst()
        }
        guard let last = parts.last else { return "My tool" }
        var body = parts.count == 1 ? last : parts.dropLast().prefix(3).joined(separator: ", ") + " and " + last
        if parts.count > 4 { body = parts[0] + " and \(parts.count - 1) more steps" }
        switch chain.finish?.kind {
        case .mail?: body += " — then email it"
        case .message?: body += " — then text it"
        default: break
        }
        return body
    }

    /// The name shown in lists: a name the person typed, unless it's empty, "My tool", or the raw request
    /// Describe it was given ("I want an image to convert to pdf…") — then the plain sentence instead.
    static func displayName(_ chain: Chain) -> String {
        let n = chain.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = n.lowercased()
        let rawAsk = ["i want", "i need", "i'd like", "can you", "could you", "please", "make me", "help me", "want to"].contains { l.hasPrefix($0) } || n.count > 42
        return n.isEmpty || n == "My tool" || rawAsk ? autoName(chain) : n
    }
    /// The name "Describe it" gives a tool: the request itself when it is short enough to read as a name, otherwise `autoName`.
    static func toolName(ask: String, chain: Chain) -> String {
        let t = ask.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        let candidate = Chain(id: "", name: t.prefix(1).uppercased() + t.dropFirst(), steps: chain.steps, finish: chain.finish)
        guard !t.isEmpty, t.count <= 28 else { return autoName(chain) }
        return displayName(candidate)
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
    // Every voice renders with offline DSP (ChainMedia.characters: pitch without changing the words' speed, plus
    // timbre and room). The rate here is only the fallback if DSP can't run on the device. Robot/alien/monster: offline
    // DSP (ChainMedia.characters) — their rate here is only a fallback if DSP is unavailable on the device.
    static let voices: [(id: String, name: String, rate: Double)] = [("chipmunk", "Chipmunk", 1.5), ("helium", "Helium", 1.9), ("deep", "Deep", 0.75), ("giant", "Giant", 0.6), ("robot", "Robot", 0.9), ("alien", "Alien", 1.7), ("monster", "Monster", 0.6), ("walkie", "Walkie-talkie", 1.0), ("cave", "Echo cave", 0.95), ("ghost", "Ghost", 1.1)]
    /// How each voice looks and what it sounds like, for the picker: a picture (emoji) and one line.
    static let voiceLooks: [String: (emoji: String, line: String)] = [
        "chipmunk": ("🐿️", "Tiny, quick and squeaky"),
        "helium":   ("🎈", "Like you breathed in a balloon"),
        "deep":     ("🐻", "Low and calm, like a bear"),
        "giant":    ("🗿", "Huge, slow and booming"),
        "robot":    ("🤖", "Metal, buzzing, beep-boop"),
        "alien":    ("👽", "Warbly, from another planet"),
        "monster":  ("👹", "Growly and scary"),
        "walkie":   ("📻", "Crackly radio, over and out"),
        "cave":     ("🦇", "Echoing in a giant cave"),
        "ghost":    ("👻", "Floaty, spooky and far away"),
    ]
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

    /// Maps the QR "sturdiness" option to an error-correction level: High (H) survives scuffs and a logo
    /// overlay at the cost of a denser code; Normal (M) is the everyday default.
    static func qrCorrection(_ s: String?) -> String { s == "high" ? "H" : "M" }

    static func qr(_ message: String, correction: String = "M") -> UIImage? {
        guard let f = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        f.setValue(Data(message.utf8), forKey: "inputMessage")
        f.setValue(correction, forKey: "inputCorrectionLevel")
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
    static func onePDF(_ results: [ChainPayload], onePage: Bool = false, pageSize: DocEngine.PageSize = .auto) -> ChainPayload? {
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
                return DocEngine.pdf(images: [ChainImage.sheet(images)], ocr: [nil], options: DocEngine.PDFOptions(searchable: false, pageSize: pageSize)).map { .file($0, ext: "pdf") }
            }
            return DocEngine.pdf(images: images, ocr: images.map { _ -> [DocEngine.OCRLine]? in nil }, options: DocEngine.PDFOptions(searchable: false, pageSize: pageSize))
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
        guard let header = old.first ?? new.first else { return "" }
        // A sheet keeps its shape: a line that isn't a row of the sheet's columns (stray text from another tool,
        // a wrapped paragraph) is never added — and any that got in before are cleaned out. The same entry
        // twice (the same receipt scanned again) is kept once.
        let width = fields(header).count
        var seen = Set<String>()
        var out = [header]
        for line in (old + new).dropFirst() where line != header {
            let f = fields(line)
            guard width <= 1 || f.count == width else { continue }
            let key = f.map { $0.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." } }.joined(separator: "|")
            guard !key.replacingOccurrences(of: "|", with: "").isEmpty, seen.insert(key).inserted else { continue }
            out.append(line)
        }
        return out.joined(separator: "\n")
    }

    /// The cells of one CSV line ("a","b, c",d → a | b, c | d).
    static func fields(_ line: String) -> [String] {
        var out: [String] = [], cur = "", quoted = false
        let it = Array(line)
        var i = 0
        while i < it.count {
            let c = it[i]
            if quoted {
                if c == "\"" { if i + 1 < it.count, it[i + 1] == "\"" { cur.append("\""); i += 1 } else { quoted = false } } else { cur.append(c) }
            } else if c == "\"" { quoted = true }
            else if c == "," { out.append(cur); cur = "" }
            else { cur.append(c) }
            i += 1
        }
        out.append(cur)
        return out
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

/// Two tools that do exactly the same thing — same steps, same settings, same ending — are one choice, whatever
/// they're called ("PDF under 5 MB (mine)", "… copy", "… copy copy", and the ready-made it was copied from). Every
/// list that offers tools (the guide after a pick, the Share sheet, search) shows each job once, keeping the first:
/// the person's own tool before a ready-made one.
enum ChainSame {
    static func key(_ c: Chain) -> String {
        var n = c
        n.id = ""; n.name = ""; n.blurb = nil; n.fileName = nil; n.schedule = nil; n.watch = nil
        let enc = JSONEncoder(); enc.outputFormatting = .sortedKeys
        return (try? enc.encode(n)).map { String(decoding: $0, as: UTF8.self) } ?? c.id
    }
    static func unique(_ chains: [Chain]) -> [Chain] {
        var seen = Set<String>()
        return chains.filter { seen.insert(key($0)).inserted }
    }
}
