import UIKit

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
        }
    }
    var takes: ChainKind {
        switch self {
        case .readText, .shrinkImage, .stripLocation, .cutout, .enhance, .convertImage, .hideSensitive, .passportPhoto, .describe, .identify, .photoPdf: return .image
        case .pullReceipt, .summarize, .businessCard, .calendarEvent, .actionItems, .cleanText, .pullDetails, .makeTable, .scamCheck, .cleanLinks, .priceCompare, .makeQr: return .text
        }
    }
    /// Kind produced, given the settings (convert/shrink/strip give a file, the rest as listed).
    var gives: ChainKind {
        switch self {
        case .readText, .pullReceipt, .summarize, .actionItems, .cleanText, .pullDetails, .scamCheck, .cleanLinks, .priceCompare, .describe, .identify: return .text
        case .shrinkImage, .stripLocation, .convertImage, .hideSensitive, .passportPhoto: return .photoFile
        case .businessCard, .calendarEvent, .makeTable, .photoPdf: return .file
        case .cutout, .enhance, .makeQr: return .image
        }
    }
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
            guard let data = await SizeTarget.image(img, targetBytes: Int(max(0.05, mb) * 1_048_576)) else { return .failure(.failed(b)) }
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
