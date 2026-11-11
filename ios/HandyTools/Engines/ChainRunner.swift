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
        }
    }
    var takes: ChainKind {
        switch self {
        case .readText, .shrinkImage, .stripLocation, .cutout, .enhance, .convertImage, .hideSensitive, .passportPhoto: return .image
        case .pullReceipt, .summarize, .businessCard, .calendarEvent, .actionItems, .cleanText, .pullDetails, .makeTable: return .text
        }
    }
    /// Kind produced, given the settings (convert/shrink/strip give a file, the rest as listed).
    var gives: ChainKind {
        switch self {
        case .readText, .pullReceipt, .summarize, .actionItems, .cleanText, .pullDetails: return .text
        case .shrinkImage, .stripLocation, .convertImage, .hideSensitive, .passportPhoto: return .photoFile
        case .businessCard, .calendarEvent, .makeTable: return .file
        case .cutout, .enhance: return .image
        }
    }
}

struct ChainStep: Codable, Equatable {
    var block: Block
    var settings: [String: String] = [:]
}

struct Chain: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var steps: [ChainStep]

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
            guard !c.name.isEmpty || !c.phones.isEmpty || !c.emails.isEmpty, let d = DataGrab.vcard(c).data(using: .utf8) else { return .failure(.nothingFound(b)) }
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
    ]
}

/// Chains travel as small text: copy one, paste it in another Tenzy. Checked before it is accepted.
extension Chain {
    static let prefix = "tenzy-tool:"
    var shareText: String {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) }.map { Chain.prefix + $0 } ?? ""
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
