import UIKit
import PDFKit

/// Tenzy Builder, Milestone 1: a chain is plain data (a list of built-in blocks with settings) that this
/// runner executes by calling the engines the app already ships. No downloaded or generated code ever runs,
/// so a chain from a template, a friend or the describe-it layer is as safe as a built-in tool.
enum ChainPayload {
    case image(UIImage)
    case text(String)
    case file(Data, ext: String)

    var kind: ChainKind {
        switch self {
        case .image: return .image
        case .text: return .text
        case .file(_, let ext): return ChainPayload.isPhoto(ext) ? .photoFile : .file
        }
    }
    static func isPhoto(_ ext: String) -> Bool { ["jpg", "jpeg", "png", "heic"].contains(ext.lowercased()) }
}

/// What flows between blocks. The builder only offers a block whose `takes` matches the step above it.
enum ChainKind: String, Codable {
    case image, text, file
    /// A photo saved as bytes (the result of shrink, convert, strip...). Any block that takes a picture accepts it.
    case photoFile
    var label: String { switch self { case .image, .photoFile: return "a photo"; case .text: return "text"; case .file: return "a file" } }
    func feeds(_ need: ChainKind) -> Bool { self == need || (need == .image && self == .photoFile) }
}

enum Block: String, Codable, CaseIterable, Identifiable {
    case readText, pullReceipt, summarize, shrinkImage, stripLocation, cutout, enhance, convertImage
    case businessCard, calendarEvent, actionItems, hideSensitive, passportPhoto
    case cleanText, pullDetails, makeTable
    case scamCheck, cleanLinks, priceCompare, makeQr, describe, identify, photoPdf
    case watermark, resizePhoto
    case stamp

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
        }
    }
    var takes: ChainKind {
        switch self {
        case .readText, .shrinkImage, .stripLocation, .cutout, .enhance, .convertImage, .hideSensitive, .passportPhoto, .describe, .identify, .photoPdf, .watermark, .resizePhoto, .stamp: return .image
        case .pullReceipt, .summarize, .businessCard, .calendarEvent, .actionItems, .cleanText, .pullDetails, .makeTable, .scamCheck, .cleanLinks, .priceCompare, .makeQr: return .text
        }
    }
    /// Kind produced, given the settings (convert/shrink/strip give a file, the rest as listed).
    var gives: ChainKind {
        switch self {
        case .readText, .pullReceipt, .summarize, .actionItems, .cleanText, .pullDetails, .scamCheck, .cleanLinks, .priceCompare, .describe, .identify: return .text
        case .shrinkImage, .stripLocation, .convertImage, .hideSensitive, .passportPhoto: return .photoFile
        case .businessCard, .calendarEvent, .makeTable, .photoPdf: return .file
        case .cutout, .enhance, .makeQr, .watermark, .resizePhoto, .stamp: return .image
        }
    }
}

extension Block {
    /// What the person is trying to get done. The builder groups steps under these, so the list reads as
    /// "what do you want to do with it?" rather than a flat list of tools.
    var goal: String {
        switch self {
        case .shrinkImage, .convertImage, .resizePhoto: return "Make it easy to send"
        case .stripLocation, .hideSensitive, .watermark: return "Keep it private"
        case .enhance, .cutout: return "Make it look better"
        case .readText, .describe, .identify: return "Read what's in it"
        case .stamp, .photoPdf: return "Paperwork"
        case .passportPhoto, .makeTable, .businessCard, .calendarEvent, .makeQr: return "Turn it into something"
        case .summarize, .actionItems, .scamCheck: return "Understand it"
        case .cleanText, .cleanLinks, .pullDetails: return "Clean it up"
        case .pullReceipt, .priceCompare: return "Money"
        }
    }
    static let goalOrder = ["Paperwork", "Make it easy to send", "Keep it private", "Make it look better", "Read what's in it", "Understand it", "Clean it up", "Turn it into something", "Money"]

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
    enum Kind: String, Codable, CaseIterable { case share, mail, message }
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
    static func run(_ chain: Chain, input: ChainPayload) async -> Result<ChainPayload, Failure> {
        if let p = chain.problem(starting: input.kind) { return .failure(.invalid(p)) }
        var value = input
        for step in chain.steps {
            switch await apply(step, to: value) {
            case .success(let next): value = next
            case .failure(let f): return .failure(f)
            }
        }
        return .success(value)
    }

    static func apply(_ step: ChainStep, to rawInput: ChainPayload) async -> Result<ChainPayload, Failure> {
        let b = step.block
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
            return .failure(.wrongInput(b))
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
        Chain(id: "share-shield", name: "Privacy share shield", steps: [ChainStep(block: .hideSensitive), ChainStep(block: .stripLocation), ChainStep(block: .shrinkImage, settings: ["mb": "2"])]),
        Chain(id: "id-copy-watermarked", name: "ID copy with a safety watermark", steps: [ChainStep(block: .watermark, settings: ["text": "For verification only"]), ChainStep(block: .stripLocation)]),
        Chain(id: "portal-photo", name: "Portal photo: 35x45 mm under 50 KB", steps: [ChainStep(block: .resizePhoto, settings: ["size": "413x531"]), ChainStep(block: .shrinkImage, settings: ["mb": "0.05"])]),
    ]
}

/// Chains travel as small text: copy one, paste it in another Tenzy. Checked before it is accepted.
extension Chain {
    static let prefix = "tenzy-tool:"
    var shareText: String {
        // A shared tool never carries the owner's recipients (someone's email or phone number).
        var copy = self
        copy.finish?.to = ""
        return (try? JSONEncoder().encode(copy)).flatMap { String(data: $0, encoding: .utf8) }.map { Chain.prefix + $0 } ?? ""
    }
    static func imported(from text: String) -> Chain? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix(prefix), let d = String(t.dropFirst(prefix.count)).data(using: .utf8),
              var c = try? JSONDecoder().decode(Chain.self, from: d), c.steps.count <= 12,
              let first = c.steps.first, c.problem(starting: first.block.takes) == nil else { return nil }
        c.id = UUID().uuidString
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
        var all = (mine + ChainTemplates.all).filter { $0.problem(starting: kind) == nil }
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
    static func onePDF(_ results: [ChainPayload]) -> ChainPayload? {
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
            return DocEngine.pdf(images: images, ocr: images.map { _ -> [DocEngine.OCRLine]? in nil }, options: DocEngine.PDFOptions(searchable: false))
                .map { .file($0, ext: "pdf") }
        }
        return nil
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
        base = String(base.unicodeScalars.filter { !"/\\:*?\"<>|".unicodeScalars.contains($0) && !CharacterSet.newlines.contains($0) && !CharacterSet.controlCharacters.contains($0) })
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".")))
        if base.count > 80 { base = String(base.prefix(80)).trimmingCharacters(in: .whitespaces) }
        if base.isEmpty { base = index == nil ? "Tenzy-result" : "Tenzy" }
        return base + (index.map { "-\($0)" } ?? "") + "." + ext
    }
}
