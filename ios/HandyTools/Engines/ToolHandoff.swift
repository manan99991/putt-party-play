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
    private var more: [String: [UIImage]] = [:]

    /// `others`: the rest of the photos when several were picked at once (the first is `payload`).
    func put(_ payload: ChainPayload, for tool: String, others: [UIImage] = []) {
        pending[tool] = payload
        more[tool] = others.isEmpty ? nil : others
    }

    /// Every photo waiting for `tool` — the one handed over plus any others picked with it — removed so they're used once.
    func takePhotos(_ tool: String) -> [UIImage] {
        let rest = more.removeValue(forKey: tool) ?? []
        guard let p = pending.removeValue(forKey: tool) else { return rest }
        return (ToolHandoff.image(p).map { [$0] } ?? []) + rest
    }

    /// The waiting item for `tool`, removed so it's used once.
    func take(_ tool: String) -> ChainPayload? { more[tool] = nil; return pending.removeValue(forKey: tool) }

    /// Dedicated tools that open this kind of thing, best first. Only tools that accept a hand-off.
    nonisolated static func tools(for kind: ChainKind) -> [String] {
        switch kind {
        case .pdf: return ["pdfsign", "pdfform", "pdfsearchable", "pdfprotect", "pdfpages", "fitit", "zipmaker"]
        case .image, .photoFile: return ["scrub", "fitit", "studio", "sticker", "animate", "celebrate", "collage", "faceemoji", "comicstrip", "menu", "cards"]
        case .audio: return ["meetingnotes", "audioclean", "audioedit", "audiocompress", "audiomix", "audiotags", "audioconvert", "zipmaker"]
        // Every tool that can work on a video, named as a video job (Guide.videoNames): edit it, make it stunning, send it,
        // join or speed it, take its sound out (MP3/M4A, ringtone, cleaned up, trimmed, small) and get its words. precheck
        // fails if a tool that opens videos is missing here. Soundboard is the one left out: on a video, "Give a video a
        // funny voice" does the same with every voice and puts the new voice back on the video.
        case .video: return ["video", "post", "celebrate", "fitit", "audiomix", "audioconvert", "ringtone", "audioclean", "audioedit", "audiocompress", "meetingnotes"]
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

    /// The same for a photo tool that takes several at once: every photo picked arrives together.
    func handoffPhotos(_ tool: String, _ use: @escaping ([UIImage]) -> Void) -> some View {
        onAppear { let photos = ToolHandoff.shared.takePhotos(tool); if !photos.isEmpty { use(photos) } }
    }
}
