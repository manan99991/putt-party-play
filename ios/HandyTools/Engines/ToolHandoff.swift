import UIKit
import SwiftUI

/// Hands something the person already has (a PDF from Files, a photo, a recording, a file shared into
/// Tenzy) straight to a dedicated tool, so it opens already loaded instead of asking them to pick it
/// again. "Start with what you have" lists the right tools for each kind (`tools(for:)`); the tool takes
/// its item once on appear (`take`). One pending item per tool, consumed on read — a tool never reopens
/// showing an old input (fresh slate).
@MainActor
final class ToolHandoff {
    static let shared = ToolHandoff()
    private var pending: [String: ChainPayload] = [:]

    func put(_ payload: ChainPayload, for tool: String) { pending[tool] = payload }

    /// The waiting item for `tool`, removed so it's used once.
    func take(_ tool: String) -> ChainPayload? { pending.removeValue(forKey: tool) }

    /// Dedicated tools that open this kind of thing, best first. Only tools that accept a hand-off.
    nonisolated static func tools(for kind: ChainKind) -> [String] {
        switch kind {
        case .pdf: return ["pdfsign", "pdfform", "pdfsearchable", "pdfprotect", "pdfpages", "zipmaker"]
        case .image, .photoFile: return ["sticker", "animate", "collage", "faceemoji", "comicstrip", "menu", "cards"]
        case .audio: return ["meetingnotes", "audiocompress", "audiomix", "audiotags", "audioconvert", "zipmaker"]
        case .video: return ["audiocompress", "audioconvert", "audiomix"]
        case .file: return ["zipmaker"]
        case .text: return []
        }
    }

    /// The item as a file on disk (written to a fresh temp file when it's bytes or a picture).
    nonisolated static func fileURL(_ p: ChainPayload, name: String = "Shared") -> URL? {
        let dir = FileManager.default.temporaryDirectory
        switch p {
        case .video(let u): return u
        case .file(let d, let ext):
            let u = dir.appendingPathComponent("\(name)-\(UUID().uuidString.prefix(6)).\(ext.isEmpty ? "bin" : ext)")
            return (try? d.write(to: u)) != nil ? u : nil
        case .image(let img):
            guard let d = img.jpegData(compressionQuality: 0.95) else { return nil }
            let u = dir.appendingPathComponent("\(name)-\(UUID().uuidString.prefix(6)).jpg")
            return (try? d.write(to: u)) != nil ? u : nil
        case .text: return nil
        }
    }

    /// The item as a picture, when it is one.
    nonisolated static func image(_ p: ChainPayload) -> UIImage? {
        switch p {
        case .image(let img): return img
        case .file(let d, let ext) where ChainPayload.isPhoto(ext): return UIImage(data: d)
        default: return nil
        }
    }
}

extension View {
    /// When this tool opens with an item handed to it (from "Start with what you have", Files, Unzip or
    /// a share), load it once — the same as if the person had just picked it here.
    func handoff(_ tool: String, _ use: @escaping (ChainPayload) -> Void) -> some View {
        onAppear { if let p = ToolHandoff.shared.take(tool) { use(p) } }
    }
}
