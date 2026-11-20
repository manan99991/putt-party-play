import Foundation

/// One way in for every audio tool: the picked file is copied somewhere we can keep reading it, WhatsApp /
/// Telegram voice notes (Ogg-Opus — even when saved with no or a wrong file ending) are decoded so the phone can
/// play and edit them, and the name is shown the way a person wrote it ("DON%25E2%2580%2599T" → "DON’T").
/// Every audio tool uses this, so a file that works in one works in all of them.
enum AudioIntake {
    static func local(_ url: URL) -> (url: URL, name: String)? {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.isEmpty ? "audio" : url.pathExtension
        let local = FileManager.default.temporaryDirectory.appendingPathComponent("ain-\(UUID().uuidString.prefix(8)).\(ext)")
        guard (try? FileManager.default.copyItem(at: url, to: local)) != nil else { return nil }
        let name = cleanName(url.deletingPathExtension().lastPathComponent)
        if isOggOpus(local), let m4a = ChainMedia.oggOpusToM4A(local) { return (m4a, name) }
        return (local, name)
    }

    /// Ogg by its ending, or by the "OggS" bytes every Ogg file starts with (voice notes are often saved without
    /// an ending, or as .m4a/.mp3 by mistake).
    static func isOggOpus(_ u: URL) -> Bool {
        if ChainMedia.oggOpusExts.contains(u.pathExtension.lowercased()) { return true }
        guard let h = try? FileHandle(forReadingFrom: u) else { return false }
        defer { try? h.close() }
        return (try? h.read(upToCount: 4)) == Data("OggS".utf8)
    }

    /// File names that were percent-encoded once or twice by the app that saved them, decoded for people.
    static func cleanName(_ s: String) -> String {
        var t = s
        for _ in 0..<3 { guard let d = t.removingPercentEncoding, d != t else { break }; t = d }
        return t.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces)
    }
}
