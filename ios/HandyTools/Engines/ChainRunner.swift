import UIKit

/// Tenzy Builder, Milestone 1: a chain is plain data (a list of built-in blocks with settings) that this
/// runner executes by calling the engines the app already ships. No downloaded or generated code ever runs,
/// so a chain from a template, a friend or the describe-it layer is as safe as a built-in tool.
enum ChainPayload {
    case image(UIImage)
    case text(String)
    case file(Data, ext: String)

    var kind: ChainKind {
        switch self { case .image: return .image; case .text: return .text; case .file: return .file }
    }
}

/// What flows between blocks. The builder only offers a block whose `takes` matches the step above it.
enum ChainKind: String, Codable { case image, text, file }

enum Block: String, Codable, CaseIterable, Identifiable {
    case readText, pullReceipt, summarize, shrinkImage, stripLocation, cutout, enhance, convertImage

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
        }
    }
    var takes: ChainKind {
        switch self {
        case .readText, .shrinkImage, .stripLocation, .cutout, .enhance, .convertImage: return .image
        case .pullReceipt, .summarize: return .text
        }
    }
    /// Kind produced, given the settings (convert/shrink/strip give a file, the rest as listed).
    var gives: ChainKind {
        switch self {
        case .readText, .pullReceipt, .summarize: return .text
        case .shrinkImage, .stripLocation, .convertImage: return .file
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
            if s.block.takes != kind { return "Step \(i + 1), \(s.block.title), needs \(s.block.takes.rawValue) but gets \(kind.rawValue)." }
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

    static func apply(_ step: ChainStep, to input: ChainPayload) async -> Result<ChainPayload, Failure> {
        let b = step.block
        switch (b, input) {
        case (.readText, .image(let img)):
            let text = DocEngine.text(DocEngine.recognize(img)).trimmingCharacters(in: .whitespacesAndNewlines)
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

        default:
            return .failure(.wrongInput(b))
        }
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
    ]
}
