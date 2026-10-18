import Foundation
import CoreLocation

/// Trip arithmetic for the GPS Dashboard — fed CLLocation fixes, keeps distance / time / max / average
/// with the usual GPS-noise filtering. Pure Swift so it's unit-testable without a satellite.
struct TripTracker {
    private(set) var distance: Double = 0          // metres
    private(set) var movingSeconds: Double = 0
    private(set) var maxSpeed: Double = 0          // m/s
    private(set) var samples = 0
    private var last: (coord: CLLocationCoordinate2D, time: Date)?
    var running = true

    var averageSpeed: Double { movingSeconds > 0 ? distance / movingSeconds : 0 }

    /// Accept a fix: ignore poor accuracy, teleports and timestamps out of order.
    mutating func add(coordinate: CLLocationCoordinate2D, speed: Double, horizontalAccuracy: Double, timestamp: Date) {
        guard running, horizontalAccuracy >= 0, horizontalAccuracy <= 50 else { return }
        samples += 1
        if speed > maxSpeed, speed < 140 { maxSpeed = speed }   // 140 m/s ≈ 500 km/h — anything above is a glitch
        if let l = last {
            let dt = timestamp.timeIntervalSince(l.time)
            guard dt > 0, dt < 60 else { last = (coordinate, timestamp); return }
            let d = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: CLLocation(latitude: l.coord.latitude, longitude: l.coord.longitude))
            let impliedSpeed = d / dt
            if impliedSpeed < 140, d > max(2, horizontalAccuracy * 0.5) {
                distance += d
                movingSeconds += dt
            } else if speed > 0.5 {
                movingSeconds += dt
            }
        }
        last = (coordinate, timestamp)
    }

    mutating func reset() { self = TripTracker(running: running) }
    init(running: Bool = true) { self.running = running }
}

enum GeoFormat {
    static func speed(_ mps: Double, metric: Bool) -> String { String(format: "%.0f", max(0, mps) * (metric ? 3.6 : 2.23694)) }
    static func speedUnit(metric: Bool) -> String { metric ? "km/h" : "mph" }
    static func distance(_ m: Double, metric: Bool) -> String {
        if metric { return m < 1000 ? String(format: "%.0f m", m) : String(format: "%.2f km", m / 1000) }
        let ft = m * 3.28084
        return ft < 1000 ? String(format: "%.0f ft", ft) : String(format: "%.2f mi", m / 1609.344)
    }
    static func altitude(_ m: Double, metric: Bool) -> String { metric ? String(format: "%.0f m", m) : String(format: "%.0f ft", m * 3.28084) }
    static func duration(_ s: Double) -> String {
        let t = Int(s); return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }
    /// Degrees-minutes-seconds, e.g. 37°46'29.7"N 122°25'09.8"W
    static func dms(_ c: CLLocationCoordinate2D) -> String {
        func part(_ v: Double, _ pos: String, _ neg: String) -> String {
            let a = abs(v); let d = Int(a); let mf = (a - Double(d)) * 60; let m = Int(mf); let s = (mf - Double(m)) * 60
            return String(format: "%d°%02d'%04.1f\"%@", d, m, s, v >= 0 ? pos : neg)
        }
        return part(c.latitude, "N", "S") + " " + part(c.longitude, "E", "W")
    }
    static func decimal(_ c: CLLocationCoordinate2D) -> String { String(format: "%.5f, %.5f", c.latitude, c.longitude) }
    static func mapsLink(_ c: CLLocationCoordinate2D) -> String { String(format: "https://maps.apple.com/?ll=%.5f,%.5f&q=Shared%%20location", c.latitude, c.longitude) }
}

/// Tiny persistence for the parked-car spot.
enum ParkStore {
    nonisolated(unsafe) private static let d = UserDefaults.standard
    static func save(_ c: CLLocationCoordinate2D) { d.set(c.latitude, forKey: "park.lat"); d.set(c.longitude, forKey: "park.lng"); d.set(Date(), forKey: "park.at") }
    static func load() -> CLLocationCoordinate2D? {
        guard d.object(forKey: "park.lat") != nil else { return nil }
        return CLLocationCoordinate2D(latitude: d.double(forKey: "park.lat"), longitude: d.double(forKey: "park.lng"))
    }
    static func date() -> Date? { d.object(forKey: "park.at") as? Date }
    static func note() -> String { d.string(forKey: "park.note") ?? "" }
    static func setNote(_ s: String) { d.set(s, forKey: "park.note") }
    static func clear() { ["park.lat", "park.lng", "park.at", "park.note"].forEach { d.removeObject(forKey: $0) } }
}
