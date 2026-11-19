import Foundation
import UserNotifications
import MapKit
import CoreLocation
import UIKit

/// "Call my doctor at 8 tomorrow": a reminder with their number and address, a "leave now" alert worked out
/// from the real drive time for a visit, and one-tap Call / Directions right on the alert.
enum ContactPlans {
    static let category = "CONTACTPLAN"
    static let callAction = "PLAN_CALL"
    static let goAction = "PLAN_GO"

    static func registerCategory() -> UNNotificationCategory {
        UNNotificationCategory(identifier: category, actions: [
            UNNotificationAction(identifier: callAction, title: "Call", options: [.foreground]),
            UNNotificationAction(identifier: goAction, title: "Directions", options: [.foreground]),
        ], intentIdentifiers: [], options: [])
    }

    static func telURL(_ phone: String?) -> URL? {
        guard let p = phone?.filter({ $0.isNumber || $0 == "+" }), !p.isEmpty else { return nil }
        return URL(string: "tel:\(p)")
    }
    static func mapsURL(_ address: String?) -> URL? {
        guard let a = address?.replacingOccurrences(of: "\n", with: ", "), !a.isEmpty,
              let q = a.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "http://maps.apple.com/?daddr=\(q)&dirflg=d")
    }

    /// The drive time from here to the address, in minutes, or nil when it can't be worked out right now.
    static func driveMinutes(to address: String, from here: CLLocation?) async -> Int? {
        guard let here, !address.isEmpty,
              let place = try? await CLGeocoder().geocodeAddressString(address.replacingOccurrences(of: "\n", with: ", ")).first,
              let dest = place.location else { return nil }
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: here.coordinate))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest.coordinate))
        req.transportType = .automobile
        guard let eta = try? await MKDirections(request: req).calculateETA() else { return nil }
        return max(1, Int((eta.expectedTravelTime / 60).rounded()))
    }

    struct Setup: Equatable {
        var reminderAt: Date
        var leaveAt: Date?
        var travelMinutes: Int?
    }

    /// Book the alerts. `remindBefore` minutes ahead of the start (0 = at the time).
    @discardableResult
    static func schedule(_ p: ContactBook.Person, kind: ContactBook.PlanKind, start: Date, remindBefore: Int, note: String,
                         travelMinutes: Int?, now: Date = Date()) -> Setup {
        let at = start.addingTimeInterval(-Double(remindBefore * 60))
        let leave = kind == .call ? nil : ContactBook.leaveBy(start: start, travelMinutes: travelMinutes)
        let base = "plan-\(p.id.filter { $0.isLetter || $0.isNumber })-\(Int(start.timeIntervalSince1970))"
        if at > now { post(p, kind: kind, start: start, travel: travelMinutes, note: note, leaving: false, at: at, id: base) }
        if let leave, leave > now, abs(leave.timeIntervalSince(at)) > 60 {
            post(p, kind: kind, start: start, travel: travelMinutes, note: note, leaving: true, at: leave, id: base + "-leave")
        }
        return Setup(reminderAt: at, leaveAt: leave, travelMinutes: travelMinutes)
    }

    /// The same alerts, right now, marked "Test" — so you can see exactly what will arrive.
    static func testRun(_ p: ContactBook.Person, kind: ContactBook.PlanKind, start: Date, note: String, travelMinutes: Int?) {
        post(p, kind: kind, start: start, travel: travelMinutes, note: note, leaving: false, at: nil, id: "plan-test-\(UUID().uuidString)")
        if kind != .call, travelMinutes != nil {
            post(p, kind: kind, start: start, travel: travelMinutes, note: note, leaving: true, at: Date().addingTimeInterval(4), id: "plan-test-leave-\(UUID().uuidString)")
        }
    }

    private static func post(_ p: ContactBook.Person, kind: ContactBook.PlanKind, start: Date, travel: Int?, note: String,
                             leaving: Bool, at: Date?, id: String) {
        let m = ContactBook.planMessage(p, kind: kind, start: start, travelMinutes: travel, note: note, leaving: leaving)
        let c = UNMutableNotificationContent()
        c.title = (at == nil || id.hasPrefix("plan-test") ? "Test · " : "") + m.title
        c.body = m.body; c.sound = .default
        c.categoryIdentifier = category
        var info: [String: String] = ["open": "contacts", "contact": p.id]
        if let t = telURL(p.phones.first?.value) { info["tel"] = t.absoluteString }
        if let u = mapsURL(p.addresses.first?.value) { info["maps"] = u.absoluteString }
        c.userInfo = info
        let trigger: UNNotificationTrigger? = at.map {
            $0.timeIntervalSinceNow < 60 ? UNTimeIntervalNotificationTrigger(timeInterval: max(1, $0.timeIntervalSinceNow), repeats: false)
                : UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0), repeats: false)
        }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: c, trigger: trigger))
    }

    /// What a tap on Call / Directions does.
    static func handle(action: String, info: [AnyHashable: Any]) -> URL? {
        switch action {
        case callAction: return (info["tel"] as? String).flatMap(URL.init(string:))
        case goAction: return (info["maps"] as? String).flatMap(URL.init(string:))
        default: return nil
        }
    }
}
