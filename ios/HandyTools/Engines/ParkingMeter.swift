import Foundation
import UserNotifications
import ActivityKit

/// "My meter runs out at…": a heads-up before the parking time ends (with the walk back), and one when it ends.
/// Plus the speed warning for the driving dashboard. Pure parts are unit-tested.
enum ParkingMeter {
    static let ids = ["park-meter-soon", "park-meter-end"]
    static let lengths: [(minutes: Int, label: String)] = [(30, "30 min"), (60, "1 hour"), (120, "2 hours"), (240, "4 hours")]
    static let leads: [Int] = [5, 10, 15]

    static var endsAt: Date? {
        get { UserDefaults.standard.object(forKey: "park.meter") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "park.meter") }
    }
    static var lead: Int {
        get { let v = UserDefaults.standard.integer(forKey: "park.meter.lead"); return v == 0 ? 10 : v }
        set { UserDefaults.standard.set(newValue, forKey: "park.meter.lead") }
    }

    /// When the two alerts fire. The heads-up is skipped if it would already be in the past.
    static func fireTimes(ends: Date, lead: Int, now: Date = Date()) -> (soon: Date?, end: Date?) {
        let soon = ends.addingTimeInterval(-Double(lead) * 60)
        return (soon > now ? soon : nil, ends > now ? ends : nil)
    }

    /// The words, with how far away the car is when we know it.
    static func messages(lead: Int, walk: String?) -> (soon: (String, String), end: (String, String)) {
        let away = walk.map { " Your car is \($0) away." } ?? ""
        return (("Parking ends in \(lead) minutes", "Time to head back.\(away) Tap for walking directions."),
                ("Parking time is up", "Your meter just ran out.\(away) Tap for walking directions."))
    }

    static func schedule(ends: Date, lead: Int, walk: String?) async {
        cancel()
        endsAt = ends; self.lead = lead
        await ParkingLive.start(ends: ends, note: ParkStore.note())
        let t = fireTimes(ends: ends, lead: lead)
        let m = messages(lead: lead, walk: walk)
        let center = UNUserNotificationCenter.current()
        for (id, when, text) in [(ids[0], t.soon, m.soon), (ids[1], t.end, m.end)] {
            guard let when else { continue }
            let c = UNMutableNotificationContent()
            c.title = text.0; c.body = text.1; c.sound = .default
            c.userInfo = ["open": "gpsdash"]
            try? await center.add(UNNotificationRequest(identifier: id, content: c,
                                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, when.timeIntervalSinceNow), repeats: false)))
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        endsAt = nil
        Task { await ParkingLive.end() }
    }

    /// What the reminder will look like, in 5 seconds — lock the phone to see it on the Lock Screen.
    static func testRun(walk: String?) async {
        let m = messages(lead: lead, walk: walk).soon
        let c = UNMutableNotificationContent()
        c.title = "Test · " + m.0; c.body = m.1; c.sound = .default
        c.userInfo = ["open": "gpsdash"]
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "park-meter-test-\(UUID().uuidString)", content: c,
                                                                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }
}

/// "Warn me above 70": one chime when you go over, then quiet until you've dropped back under by a margin,
/// so it never nags at the limit. Speeds here are in the dashboard's own units (mph or km/h).
enum SpeedWarning {
    static let margin = 3.0
    static let gapSeconds = 20.0

    struct State: Equatable { var armed = true; var lastWarn: Date? }

    static func check(speed: Double, limit: Double, state: inout State, now: Date = Date()) -> Bool {
        guard limit > 0 else { return false }
        if speed < limit - margin { state.armed = true; return false }
        guard speed > limit, state.armed else { return false }
        if let last = state.lastWarn, now.timeIntervalSince(last) < gapSeconds { return false }
        state.armed = false; state.lastWarn = now
        return true
    }
}

/// The meter counting down on the Lock Screen and in the Dynamic Island (a Live Activity). Started when the meter is set,
/// ended when it's cancelled or the car is cleared; once the time is up it says so and goes after a while.
enum ParkingLive {
    static func start(ends: Date, note: String) async {
        await end()
        guard ActivityAuthorizationInfo().areActivitiesEnabled, ends > Date() else { return }
        let content = ActivityContent(state: ParkingAttributes.ContentState(ends: ends, note: note), staleDate: ends)
        _ = try? Activity.request(attributes: ParkingAttributes(parkedAt: ParkStore.date() ?? Date()), content: content, pushType: nil)
    }
    static func end() async {
        for a in Activity<ParkingAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
