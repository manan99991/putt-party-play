import Foundation
import UserNotifications

/// Rest's "how was the night" and "time to wind down": the night recorder's clips summed up by hour, and a
/// daily bedtime nudge. Pure parts are unit-tested.
enum RestNight {
    struct Summary: Equatable {
        var count: Int
        var seconds: Double
        var loudestDB: Double
        var busiestHour: Int?          // 0–23, the hour with the most noisy time
        var byHour: [(hour: Int, seconds: Double)]
        static func == (a: Summary, b: Summary) -> Bool {
            a.count == b.count && a.seconds == b.seconds && a.busiestHour == b.busiestHour && a.byHour.map(\.hour) == b.byHour.map(\.hour)
        }
    }

    /// The clips from one night (evening 6 pm → next 2 pm), bucketed by the hour they started.
    static func summary(_ clips: [(date: Date, seconds: Double, peakDB: Double)], night ending: Date = Date(), cal: Calendar = .current) -> Summary? {
        let day = cal.startOfDay(for: ending)
        let to = cal.date(byAdding: .hour, value: 14, to: day) ?? ending
        let from = cal.date(byAdding: .hour, value: -6, to: day) ?? ending
        let night = clips.filter { $0.date >= from && $0.date < to }
        guard !night.isEmpty else { return nil }
        var buckets: [Int: Double] = [:]
        for c in night { buckets[cal.component(.hour, from: c.date), default: 0] += c.seconds }
        // Order the hours as the night runs: 18…23, then 0…13.
        let order = Array(18...23) + Array(0...13)
        let byHour = order.compactMap { h in buckets[h].map { (hour: h, seconds: $0) } }
        let busiest = byHour.max { $0.seconds < $1.seconds }?.hour
        return Summary(count: night.count, seconds: night.reduce(0) { $0 + $1.seconds },
                       loudestDB: night.map(\.peakDB).max() ?? 0, busiestHour: busiest, byHour: byHour)
    }

    static func hourLabel(_ h: Int) -> String {
        var c = DateComponents(); c.hour = h
        let d = Calendar.current.date(from: c) ?? Date()
        return d.formatted(.dateTime.hour())
    }

    // MARK: - Bedtime nudge

    static let id = "rest-bedtime"
    static var on: Bool { UserDefaults.standard.bool(forKey: "rest.bedtime.on") }
    static var hour: Int { let h = UserDefaults.standard.object(forKey: "rest.bedtime.hour") as? Int; return h ?? 22 }
    static var minute: Int { UserDefaults.standard.integer(forKey: "rest.bedtime.minute") }

    static let message = ("Time to wind down", "Tap to start your sleep sound and the night recorder.")

    static func set(on: Bool, hour: Int, minute: Int) async {
        let d = UserDefaults.standard
        d.set(on, forKey: "rest.bedtime.on"); d.set(hour, forKey: "rest.bedtime.hour"); d.set(minute, forKey: "rest.bedtime.minute")
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard on else { return }
        let c = UNMutableNotificationContent()
        c.title = message.0; c.body = message.1; c.sound = .default
        c.userInfo = ["open": "rest"]
        var when = DateComponents(); when.hour = hour; when.minute = minute
        try? await center.add(UNNotificationRequest(identifier: id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
    }

    static func testRun() async {
        let c = UNMutableNotificationContent()
        c.title = "Test · " + message.0; c.body = message.1; c.sound = .default
        c.userInfo = ["open": "rest"]
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "rest-test-\(UUID().uuidString)", content: c,
                                                                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }
}
