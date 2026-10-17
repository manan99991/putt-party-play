import Foundation

/// App Group container shared by the app, keyboard, share extension and widget.
enum AppGroup {
    static let id = "group.com.tenzy.toolkit"
    static var defaults: UserDefaults { UserDefaults(suiteName: id)! }
}

// MARK: - Multi-clipboard (tool 2 on iOS)

struct Clip: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var createdAt = Date()
    var pinned = false
}

/// The clipboard stack. On iOS no app can watch the clipboard in the background, so clips
/// get in three ways: the Share Sheet ("Save to Clips"), the app's own "Grab clipboard" button,
/// and the keyboard's "+" key (which reads the pasteboard while the keyboard is open).
enum ClipStore {
    private static let key = "clips"
    static let freeLimit = 20

    static func all() -> [Clip] {
        guard let data = AppGroup.defaults.data(forKey: key),
              let clips = try? JSONDecoder().decode([Clip].self, from: data) else { return [] }
        return clips.sorted { ($0.pinned ? 1 : 0, $0.createdAt) > ($1.pinned ? 1 : 0, $1.createdAt) }
    }

    @discardableResult
    static func add(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        var clips = all()
        if clips.first?.text == t { return false }
        clips.removeAll { $0.text == t && !$0.pinned }
        clips.insert(Clip(text: t), at: 0)
        if !Premium.isActive {
            let unpinned = clips.filter { !$0.pinned }
            if unpinned.count > freeLimit {
                let dropIds = Set(unpinned.suffix(unpinned.count - freeLimit).map(\.id))
                clips.removeAll { dropIds.contains($0.id) }
            }
        }
        save(clips)
        return true
    }

    static func togglePin(_ id: UUID) {
        var c = all(); if let i = c.firstIndex(where: { $0.id == id }) { c[i].pinned.toggle() }; save(c)
    }
    static func remove(_ id: UUID) { save(all().filter { $0.id != id }) }
    static func clearUnpinned() { save(all().filter { $0.pinned }) }
    private static func save(_ clips: [Clip]) {
        AppGroup.defaults.set(try? JSONEncoder().encode(clips), forKey: key)
    }
}

// MARK: - Sticky note (tool 5 on iOS)

enum NoteStore {
    private static let key = "sticky_note"
    static var text: String {
        get { AppGroup.defaults.string(forKey: key) ?? "" }
        set { AppGroup.defaults.set(newValue, forKey: key) }
    }
}

// MARK: - Premium flag mirrored into the group so extensions can read it

enum Premium {
    private static let key = "premium_active"
    static var isActive: Bool {
        get { AppGroup.defaults.bool(forKey: key) }
        set { AppGroup.defaults.set(newValue, forKey: key) }
    }
}
