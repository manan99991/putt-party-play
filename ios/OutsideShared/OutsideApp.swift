import Foundation
import AppIntents
import ActivityKit

// Tenzy outside the app (24 Nov, UX plan phase 2): buttons in Control Center and on the Lock Screen, a Shortcuts action
// that saves where you parked when the phone leaves the car's Bluetooth, and the parking meter counting down on the Lock
// Screen. Shared by the app and the widget extension. Nothing here needs a new permission: every action opens Tenzy, and
// Tenzy does the work in the open (location only while it's showing, as today).

/// The parking meter on the Lock Screen and in the Dynamic Island.
struct ParkingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var ends: Date
        /// The person's own note ("Level 3, near the lift"), shown under the countdown.
        var note: String
    }
    var parkedAt: Date
}

/// What a button outside the app asked Tenzy to do when it opens. Kept two minutes, so a stale ask never fires later.
enum OutsideAction {
    static let key = "tenzy.outside.action"
    static let notification = Notification.Name("tenzy.outside.action")
    static func ask(_ action: String) {
        AppGroup.defaults.set(action, forKey: key)
        AppGroup.defaults.set(Date(), forKey: key + ".at")
    }
    static func take(now: Date = Date()) -> String? {
        let d = AppGroup.defaults
        defer { d.removeObject(forKey: key); d.removeObject(forKey: key + ".at") }
        guard let a = d.string(forKey: key), let at = d.object(forKey: key + ".at") as? Date, now.timeIntervalSince(at) < 120 else { return nil }
        return a
    }
}

/// "Save where I parked": opens Tenzy on Find my car and drops the pin as soon as it has a GPS fix. In Control Center, on
/// the Lock Screen, on the Action button, and in a Shortcuts automation ("When my car's Bluetooth disconnects").
struct SaveParkingIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Where I Parked"
    static let description: IntentDescription? = IntentDescription("Opens Tenzy and saves where your car is, so you can walk back to it. Add it to an automation that runs when your phone leaves the car's Bluetooth.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        OutsideAction.ask("park")
        NotificationCenter.default.post(name: OutsideAction.notification, object: nil)
        return .result()
    }
}

/// A Control Center / Lock Screen button that opens one Tenzy tool.
struct OpenToolControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Open a Tenzy Tool"
    static let openAppWhenRun: Bool = true
    static let isDiscoverable: Bool = false

    @Parameter(title: "Tool", default: "scan") var tool: String

    init() {}
    init(tool: String) { self.tool = tool }

    @MainActor
    func perform() async throws -> some IntentResult {
        OutsideAction.ask("tool:" + tool)
        NotificationCenter.default.post(name: OutsideAction.notification, object: nil)
        return .result()
    }
}
