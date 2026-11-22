import Foundation

/// "Ready now" while someone types: when they name what they have ("a photo", "this video", "my recording",
/// "the PDF"), only tools and flows for that kind are offered — "shrink a photo and email it" must not suggest
/// Compress Audio. Tools that don't take a file at all are never filtered out. Pure, so it's unit-tested.
enum ReadyNow {
    static let words: [(ChainKind, [String])] = [
        (.image, ["photo", "picture", "pic", "image", "selfie", "screenshot", "jpg", "jpeg", "png", "heic"]),
        (.video, ["video", "clip", "movie", "reel", "mp4", "mov"]),
        (.audio, ["audio", "recording", "voice memo", "voice note", "song", "mp3", "m4a", "podcast"]),
        (.pdf, ["pdf"]),
    ]

    static func kinds(in text: String) -> Set<ChainKind> {
        let t = text.lowercased()
        return Set(words.filter { _, ws in ws.contains { w in t.range(of: "\\b\(w)", options: .regularExpression) != nil } }.map(\.0))
    }

    private static func handoff(_ k: ChainKind) -> Set<String> {
        k == .image ? Set(ToolHandoff.tools(for: .image) + ToolHandoff.tools(for: .photoFile)) : Set(ToolHandoff.tools(for: k))
    }
    private static let mediaTools: Set<String> = [ChainKind.image, .video, .audio, .pdf].reduce(into: Set<String>()) { $0.formUnion(handoff($1)) }

    static func fits(tool id: String, kinds: Set<ChainKind>) -> Bool {
        guard !kinds.isEmpty, mediaTools.contains(id) else { return true }
        return kinds.contains { handoff($0).contains(id) }
    }

    static func fits(start: ChainKind?, kinds: Set<ChainKind>) -> Bool {
        guard !kinds.isEmpty, let s = start, s != .text, s != .file else { return true }
        let k: ChainKind = s == .photoFile ? .image : s
        return kinds.contains(k)
    }
}
