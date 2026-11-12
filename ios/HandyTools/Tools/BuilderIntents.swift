import AppIntents
import UIKit
import UniformTypeIdentifiers

/// Your tools as actions in the Shortcuts app. This is what makes real automation possible on an iPhone: Shortcuts can
/// start on its own (a time of day, arriving somewhere, plugging in, opening an app, the Action button, Back Tap) and
/// then hand a photo or some text to a Tenzy tool, which runs without opening Tenzy and hands the result to the next
/// action (send it, save it, add it to a note).

/// One tool, as Shortcuts sees it: your saved tools first, then the starters.
struct ToolEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Tenzy tool"
    static let defaultQuery = ToolQuery()

    var id: String
    var name: String
    var steps: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(steps)")
    }

    init(_ c: Chain) {
        id = c.id; name = c.name
        steps = c.steps.map(\.block.title).joined(separator: ", ")
    }
}

struct ToolQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ToolEntity] {
        let all = ToolIntentSupport.all()
        return identifiers.compactMap { id in all.first { $0.id == id } }.map(ToolEntity.init)
    }
    func suggestedEntities() async throws -> [ToolEntity] { ToolIntentSupport.all().map(ToolEntity.init) }
}

/// What Shortcuts shows when a tool can't finish: one plain sentence.
struct ToolIntentError: Error, CustomLocalizedStringResourceConvertible {
    let message: String
    var localizedStringResource: LocalizedStringResource { "\(message)" }
}

enum ToolIntentSupport {
    /// Saved tools first, then the starters. A saved tool wins if it shares an id with a starter.
    static func all() -> [Chain] {
        let mine = ChainStore.load()
        let ids = Set(mine.map(\.id))
        return mine + ChainTemplates.all.filter { !ids.contains($0.id) }
    }

    static func chain(_ id: String) throws -> Chain {
        guard let c = all().first(where: { $0.id == id }) else { throw ToolIntentError(message: "That tool isn't in Tenzy any more. Pick another one in this shortcut.") }
        return c
    }

    static func words(_ f: ChainRunner.Failure) -> String {
        switch f {
        case .invalid(let why): return why
        case .wrongInput(let b): return "\(b.title) needs \(b.takes.label)."
        case .nothingFound(let b): return "\(b.title) didn't find anything to work with."
        case .failed(let b): return "\(b.title) couldn't finish."
        }
    }

    /// The result as a named file Shortcuts can pass on. Text becomes a small .txt file, which Shortcuts reads as text.
    static func file(_ p: ChainPayload, chain: Chain) -> (data: Data, name: String)? {
        switch p {
        case .text(let t): return (Data(t.utf8), ChainName.file(pattern: chain.fileName, tool: chain.name, ext: "txt"))
        case .image(let i): return i.jpegData(compressionQuality: 0.92).map { ($0, ChainName.file(pattern: chain.fileName, tool: chain.name, ext: "jpg")) }
        case .file(let d, let ext): return (d, ChainName.file(pattern: chain.fileName, tool: chain.name, ext: ext))
        case .video(let u): return (try? Data(contentsOf: u)).map { ($0, ChainName.file(pattern: chain.fileName, tool: chain.name, ext: u.pathExtension.isEmpty ? "mp4" : u.pathExtension.lowercased())) }
        }
    }

    static func run(_ chain: Chain, on input: ChainPayload) async throws -> IntentFile {
        switch await ChainRunner.run(chain, input: input) {
        case .failure(let f): throw ToolIntentError(message: words(f))
        case .success(let out):
            guard let f = file(out, chain: chain) else { throw ToolIntentError(message: "The result couldn't be saved.") }
            return IntentFile(data: f.data, filename: f.name, type: UTType(filenameExtension: (f.name as NSString).pathExtension))
        }
    }
}

/// "Run [tool] on [photo]": works in the background, gives the result back to the shortcut.
struct RunToolOnPhotoIntent: AppIntent {
    static let title: LocalizedStringResource = "Run a Tool on a Photo"
    static let description: IntentDescription? = IntentDescription("Runs one of your Tenzy tools on a photo and gives back the result, without opening Tenzy. Everything happens on this iPhone.")

    @Parameter(title: "Tool") var tool: ToolEntity
    @Parameter(title: "Photo", supportedTypeIdentifiers: ["public.image"]) var photo: IntentFile

    static var parameterSummary: some ParameterSummary { Summary("Run \(\.$tool) on \(\.$photo)") }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let chain = try ToolIntentSupport.chain(tool.id)
        guard chain.steps.first?.block.takes != .text else { throw ToolIntentError(message: "\(chain.name) starts with text, not a photo. Use Run a Tool on Text.") }
        guard let image = UIImage(data: photo.data) else { throw ToolIntentError(message: "That isn't a photo Tenzy can open.") }
        return .result(value: try await ToolIntentSupport.run(chain, on: .image(image)))
    }
}

/// "Run [tool] on [text]".
struct RunToolOnTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Run a Tool on Text"
    static let description: IntentDescription? = IntentDescription("Runs one of your Tenzy tools on some text (a message, a link, a copied block) and gives back the result, without opening Tenzy.")

    @Parameter(title: "Tool") var tool: ToolEntity
    @Parameter(title: "Text") var text: String

    static var parameterSummary: some ParameterSummary { Summary("Run \(\.$tool) on \(\.$text)") }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let chain = try ToolIntentSupport.chain(tool.id)
        guard chain.steps.first?.block.takes == .text else { throw ToolIntentError(message: "\(chain.name) starts with a photo, not text. Use Run a Tool on a Photo.") }
        return .result(value: try await ToolIntentSupport.run(chain, on: .text(text)))
    }
}

/// "Open [tool]": brings Tenzy forward with that tool ready to run, for tools you want to see working.
struct OpenToolIntent: AppIntent {
    static let title: LocalizedStringResource = "Open a Tool"
    static let description: IntentDescription? = IntentDescription("Opens Tenzy with one of your tools ready to run.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Tool") var tool: ToolEntity

    static var parameterSummary: some ParameterSummary { Summary("Open \(\.$tool)") }

    @MainActor
    func perform() async throws -> some IntentResult {
        ToolSchedules.setPending(tool.id)
        NotificationCenter.default.post(name: .openTool, object: "builder")
        return .result()
    }
}

/// Makes the actions findable in Shortcuts, Spotlight and Siri without any setup.
struct TenzyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenToolIntent(),
                    phrases: ["Open a \(.applicationName) tool", "Run a \(.applicationName) tool"],
                    shortTitle: "Open a Tool", systemImageName: "wand.and.stars")
    }
}
