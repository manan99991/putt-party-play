import UIKit
import AVFoundation

// The share sheet runs photo and text tools only. The engines it borrows from the app mention two video helpers
// and one image helper that live in app-only files, so they get small stand-ins here. Video tools are never offered
// in the share sheet, so the video stand-in is never reached.

enum VideoEngine {
    static func tempURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
    }
    static func transcodeH264(_ asset: AVAsset, maxDimension: CGFloat? = nil, videoBps: Int? = nil,
                              timeout: TimeInterval = 180, progress: ((Double) -> Void)? = nil) async -> URL? { nil }
    static func thumbnail(_ url: URL, at seconds: Double = 0.5, maxDim: CGFloat = 640) async -> UIImage? { nil }
    static func mute(_ src: URL) async -> URL? { nil }
    static func extractAudio(_ src: URL) async -> URL? { nil }
}

extension UIImage {
    /// Redraws the image so its pixels are upright (same as the app's helper).
    func normalizedUp() -> UIImage {
        if imageOrientation == .up { return self }
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = scale
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}

// The scene describer can polish its sentence with the on-device model and can speak. Neither happens in the share
// sheet: it uses the plain sentence, so these two stand-ins only need to exist.
enum AIEngine {
    static var isAvailable: Bool { false }
    static func run(instructions: String, prompt: String, timeout: TimeInterval = 60) async throws -> String { "" }
}

enum Reader {
    static func bestVoice(forLanguage lang: String) -> AVSpeechSynthesisVoice? { AVSpeechSynthesisVoice(language: lang) }
}

// The newer steps that need the speech engine, a voice, the translator, the writing model or the video encoder run in
// the app only. Here they report themselves as not available, so the share sheet never offers a tool that uses one.
enum ChainMedia {
    static let appOnly: Set<Block> = [.speechText, .readAloud, .translate, .rewrite, .videoTrim, .videoGif, .videoRotate, .videoVertical, .videoCaptions, .videoSpeed, .videoLoop]
    static func unavailable(_ b: Block) -> String? { appOnly.contains(b) ? "Open Tenzy to run this tool." : nil }
    static func apply(_ step: ChainStep, to input: ChainPayload, dryRun: Bool) async -> ChainExtras.Outcome? { nil }
}
