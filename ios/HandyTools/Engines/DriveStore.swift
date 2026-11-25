import Foundation

/// The drives this phone noticed (Find my car's drive detection, when "Save my spot automatically" is on), kept 60 days
/// on the phone, for the mileage autorun: at the end of the day, "3 drives today — which were for work?".
enum DriveStore {
    struct Drive: Codable, Equatable, Identifiable {
        var id = UUID()
        var start: Date
        var end: Date
        var fromLat: Double
        var fromLng: Double
        var toLat: Double
        var toLng: Double
        var metres: Double
        /// Looked at in the review (logged or left out), so it's never offered twice.
        var reviewed = false

        var miles: Double { Mileage.round1(metres / 1609.344) }
    }

    private static var url: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Business", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d.appendingPathComponent("drives.json")
    }
    static func all() -> [Drive] {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([Drive].self, from: $0) } ?? []
    }
    static func save(_ d: [Drive]) {
        if let data = try? JSONEncoder().encode(d) { try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }
    static func add(_ d: Drive, now: Date = Date()) { save(kept(all() + [d], now: now)) }
    static func markReviewed(_ ids: Set<UUID>) { save(all().map { var x = $0; if ids.contains(x.id) { x.reviewed = true }; return x }) }

    /// Only the last 60 days, and a drive shorter than a tenth of a mile isn't a drive worth logging.
    static func kept(_ d: [Drive], now: Date) -> [Drive] {
        d.filter { now.timeIntervalSince($0.end) < 60 * 86_400 && $0.metres >= 160 }.sorted { $0.start < $1.start }
    }
    /// The drives waiting for a look: not reviewed, ended inside the window.
    static func waiting(_ d: [Drive], in window: DateInterval) -> [Drive] {
        d.filter { !$0.reviewed && window.contains($0.end) }
    }
}
