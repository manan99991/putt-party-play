import Foundation
import CoreLocation
import MapKit
import UserNotifications

/// Nearby places for a plan step ("grocery store", "pharmacy"): the closest few with real drive time,
/// open in Apple Maps with one tap. Apple Maps search works worldwide; nothing is stored. If location is
/// off, the step still offers "Open Maps" (Maps searches near wherever the person is).
@MainActor final class NearbyPlaces: NSObject, ObservableObject, CLLocationManagerDelegate {
    struct Place: Identifiable {
        let id = UUID()
        let item: MKMapItem
        let name: String
        let address: String
        let meters: CLLocationDistance
        var driveMinutes: Int?
    }

    @Published var places: [String: [Place]] = [:]   // by query
    @Published var looking: Set<String> = []
    @Published var denied = false

    private let manager = CLLocationManager()
    private var here: CLLocation?
    private var waiting: [(CLLocation?) -> Void] = []

    /// Find the 3 closest for `query`, with drive time. Calls back on the main actor when done.
    func find(_ query: String) {
        guard !looking.contains(query) else { return }
        looking.insert(query)
        locate { [weak self] loc in
            guard let self else { return }
            guard let loc else { self.looking.remove(query); self.denied = true; return }
            Task { await self.search(query, near: loc) }
        }
    }

    static func mapsURL(_ query: String) -> URL? {
        var c = URLComponents(string: "https://maps.apple.com/")
        c?.queryItems = [URLQueryItem(name: "q", value: query)]
        return c?.url
    }

    private func search(_ query: String, near loc: CLLocation) async {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        req.region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 8000, longitudinalMeters: 8000)
        let items = (try? await MKLocalSearch(request: req).start().mapItems) ?? []
        var found: [Place] = items.compactMap { m in
            guard let p = m.placemark.location else { return nil }
            let addr = [m.placemark.subThoroughfare, m.placemark.thoroughfare, m.placemark.locality].compactMap { $0 }.joined(separator: " ")
            return Place(item: m, name: m.name ?? query, address: addr, meters: p.distance(from: loc))
        }
        .sorted { $0.meters < $1.meters }
        found = Array(found.prefix(3))
        for i in found.indices {
            let d = MKDirections.Request()
            d.source = MKMapItem.forCurrentLocation()
            d.destination = found[i].item
            d.transportType = .automobile
            if let eta = try? await MKDirections(request: d).calculateETA() {
                found[i].driveMinutes = max(1, Int((eta.expectedTravelTime / 60).rounded()))
            }
        }
        places[query] = found
        looking.remove(query)
    }

    // MARK: - One-shot location

    func locate(_ done: @escaping (CLLocation?) -> Void) {
        if let h = here, abs(h.timestamp.timeIntervalSinceNow) < 600 { done(h); return }
        waiting.append(done)
        guard waiting.count == 1 else { return }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: finish(nil)
        default: manager.requestLocation()
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            self?.finish(nil)
        }
    }

    private func finish(_ loc: CLLocation?) {
        if let loc { here = loc }
        let w = waiting; waiting = []
        w.forEach { $0(loc) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in
            if s == .authorizedWhenInUse || s == .authorizedAlways { if !self.waiting.isEmpty { self.manager.requestLocation() } }
            else if s == .denied || s == .restricted { self.finish(nil) }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let l = locations.last
        Task { @MainActor in self.finish(l) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }
}

/// Step-start check-ins: a notification as each step begins ("Time for: Shower — on track?"), rebuilt
/// whenever the plan re-times so it never nags about a step that's done or skipped.
enum UntangleCheckIns {
    static let prefix = "untangle-"

    static func schedule(_ plan: UntanglePlan.Plan, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            center.removePendingNotificationRequests(withIdentifiers: reqs.map(\.identifier).filter { $0.hasPrefix(prefix) })
            for s in plan.steps where s.status == .todo && !s.isRest && s.start > now.addingTimeInterval(30) {
                let c = UNMutableNotificationContent()
                c.title = "\(L("Time for")): \(s.title)"
                c.body = "\(s.totalMinutes) \(L("min")) · \(L("Open Untangle to tick it off or get more time."))"
                c.sound = .default
                c.userInfo = ["open": "thinking"]
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: s.start)
                center.add(UNNotificationRequest(identifier: prefix + s.id.uuidString, content: c,
                                                 trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            center.removePendingNotificationRequests(withIdentifiers: reqs.map(\.identifier).filter { $0.hasPrefix(prefix) })
        }
    }

    static func ask() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
}
