import Foundation

/// Smart autorun: voice memos into written notes (26 Nov). iPhone keeps Voice Memos to itself, so the person picks a
/// folder once (Voice Memos › Share › Save to Files puts a memo there, and so does any recorder app); each evening the
/// memos saved there that day are transcribed on the phone — nothing is sent anywhere — and written up the way Meeting
/// Notes writes up a meeting: a one-line headline, the key points, decisions, and the to-dos with who and by when,
/// ready for Reminders. The whole transcript stays one tap away, tidied into paragraphs.
enum SmartVoice {
    struct Todo: Codable, Equatable, Hashable { var task: String; var owner: String?; var due: String? }

    struct Entry: Codable, Equatable, Identifiable {
        var id: String                // file name + its modification time: the same memo is never written up twice
        var name: String              // the memo's file name, without extension
        var recorded: Date
        var seconds: Double
        var headline: String
        var points: [String]
        var decisions: [String]
        var todos: [Todo]
        var transcript: [String]      // paragraphs
        var people: [String]
        var byAI = false
        var done = false

        var todoLines: [String] { todos.map { MeetingDigest.Action(task: $0.task, owner: $0.owner, due: $0.due).line } }

        /// The notes as plain text, to share or paste anywhere.
        var text: String {
            var s = headline + "\n" + recorded.formatted(date: .abbreviated, time: .shortened) + "\n"
            if !points.isEmpty { s += "\n" + points.map { "• " + $0 }.joined(separator: "\n") + "\n" }
            if !decisions.isEmpty { s += "\n" + L("Decided") + ":\n" + decisions.map { "• " + $0 }.joined(separator: "\n") + "\n" }
            if !todos.isEmpty { s += "\n" + L("To-dos") + ":\n" + todoLines.map { "☐ " + $0 }.joined(separator: "\n") + "\n" }
            return s
        }
    }

    static let audioTypes: Set<String> = ["m4a", "mp3", "wav", "caf", "aac", "aif", "aiff", "qta", "mp4", "m4b", "opus", "ogg", "flac", "amr", "3gp"]

    // MARK: pure

    /// The memos in a folder listing worth writing up: sound files changed inside the window, not done before.
    static func picks(_ files: [(name: String, modified: Date, bytes: Int)], window: DateInterval, done: Set<String>) -> [(name: String, id: String)] {
        files.filter { audioTypes.contains(($0.name as NSString).pathExtension.lowercased()) && window.contains($0.modified) && $0.bytes > 4_000 }
            .sorted { $0.modified < $1.modified }
            .map { ($0.name, id($0.name, $0.modified)) }
            .filter { !done.contains($0.1) }
    }

    static func id(_ name: String, _ modified: Date) -> String { "\(name)@\(Int(modified.timeIntervalSince1970))" }

    /// "New Recording 14" says nothing; the headline does. A memo the person named keeps its name.
    static func title(name: String, headline: String) -> String {
        let generic = name.range(of: #"^(new recording|recording|audio|voice|memo|rec|untitled|aud|voice memo)[\s_-]*\d*$"#,
                                 options: [.regularExpression, .caseInsensitive]) != nil
            || name.range(of: #"^\d{4}[-_]?\d{2}[-_]?\d{2}"#, options: .regularExpression) != nil
        return generic || name.isEmpty ? headline : name
    }

    // MARK: on the phone

    private static let folderKey = "smartruns.voice.folder"

    /// The folder the person chose for memos, kept as a bookmark so it still opens later.
    static func remember(folder url: URL) -> Bool {
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        guard let d = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { return false }
        AppGroup.defaults.set(d, forKey: folderKey); return true
    }
    static var folder: URL? {
        guard let d = AppGroup.defaults.data(forKey: folderKey) else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: d, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    /// Writes up the memos saved in the window. `done`: memos already written up.
    @MainActor static func gather(in window: DateInterval, done: Set<String>, progress: ((Double, String) -> Void)? = nil) async -> [Entry] {
        guard let dir = folder else { return [] }
        let ok = dir.startAccessingSecurityScopedResource()
        defer { if ok { dir.stopAccessingSecurityScopedResource() } }
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        var listing: [(name: String, modified: Date, bytes: Int)] = []
        var byName: [String: URL] = [:]
        for u in urls {
            guard let v = try? u.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
            listing.append((u.lastPathComponent, v.contentModificationDate ?? .distantPast, v.fileSize ?? 0)); byName[u.lastPathComponent] = u
        }
        let todo = picks(listing, window: window, done: done)
        var out: [Entry] = []
        for (i, p) in todo.enumerated() {
            if Task.isCancelled { break }
            guard let src = byName[p.name] else { continue }
            let label = "\(L("Listening to memo")) \(i + 1)/\(todo.count)"
            progress?(Double(i) / Double(max(1, todo.count)), label)
            // A local copy: the recogniser reads it at its own pace, and the folder's access can end meanwhile.
            let local = FileManager.default.temporaryDirectory.appendingPathComponent("memo-\(UUID().uuidString).\(src.pathExtension)")
            guard (try? FileManager.default.copyItem(at: src, to: local)) != nil else { continue }
            defer { try? FileManager.default.removeItem(at: local) }
            let heard = await MeetingNotes.transcribe(local) { f in progress?((Double(i) + f * 0.8) / Double(max(1, todo.count)), label) }
            guard case .success(let h) = heard, h.text.split(separator: " ").count >= 3 else { continue }
            var d: MeetingDigest.Result?
            if AIEngine.isAvailable, Usage.hasRoom("ai", limit: Limits.freeAiPerDay) {
                d = await MeetingDigest.onDevice(h.text) { _, _ in }
                if d != nil { _ = Usage.use("ai", limit: Limits.freeAiPerDay) }
            }
            let r = d ?? MeetingDigest.builtIn(h.text)
            let base = (p.name as NSString).deletingPathExtension
            let modified = (try? src.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
            out.append(Entry(id: p.id, name: base, recorded: modified, seconds: h.words.last?.end ?? 0,
                             headline: title(name: base, headline: r.headline), points: r.points, decisions: r.decisions,
                             todos: r.actions.map { Todo(task: $0.task, owner: $0.owner, due: $0.due) },
                             transcript: TranscriptTidy.paragraphs(h.text), people: MeetingNotes.people(in: h.text), byAI: r.engine == .onDevice))
        }
        progress?(1, L("Done"))
        return out
    }

    /// The to-dos into Reminders (a list named for the memo), with who and when where it was said. -1 if not allowed.
    @MainActor static func toReminders(_ e: Entry) async -> Int {
        let list = e.headline.count > 40 ? String(e.headline.prefix(40)) + "…" : e.headline
        let entries = e.todos.map { t in
            PlannerStore.Entry(text: t.task, list: list, due: t.due.flatMap { Understand.due(in: "by " + $0, now: e.recorded) },
                               person: t.owner == "Me" || t.owner == "Us" ? nil : t.owner, source: "Voice memo")
        }
        return (try? await PlannerStore.toReminders(entries)) ?? -1
    }
}
