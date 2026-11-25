import Foundation
import CoreLocation
import CoreMotion
import UIKit
import UserNotifications

/// Save where I parked, by itself (Manan, 24 Nov: "independent of anything the user does on the device, always accurate,
/// and it has to work" — and "build around existing permissions"). No CarPlay, Bluetooth or Shortcuts, and no Always
/// location: only the While Using location Tenzy already asks for, and Motion & Fitness, which it already declares.
///
/// How: when the person switches it on, Tenzy keeps a background location session (iOS 17+, `CLBackgroundActivitySession`,
/// which lets a While Using app keep receiving location; iPhone shows the blue location pill while it's on). Away from
/// the car it listens at cell-tower accuracy, which costs almost nothing; when the motion chip or the speed says you're
/// driving, it turns GPS up; when you get out and walk, it saves the spot from a fresh fix right there, notifies you,
/// and turns GPS back down. Everything stays on the phone.

/// The rules, pure so recorded drives prove them (AutoParkTests).
enum AutoParkRules {
    struct Fix: Equatable {
        var lat: Double
        var lng: Double
        var accuracy: Double
        var speed: Double
        var time: Date
    }

    enum Motion: Equatable { case driving, walking, still, unknown }

    /// A drive counts once it has lasted two minutes: a car moved across a car park isn't a parking event worth a pin,
    /// and a moment of "automotive" from a bumpy walk isn't a drive.
    static let minDrive: TimeInterval = 120
    /// Faster than this (25 km/h, 16 mph) is a car, whatever the motion chip says.
    static let carSpeed = 7.0
    /// Still, not driving, for this long after a drive also means parked (you sat in the car before getting out).
    static let stillWait: TimeInterval = 180
    /// A few seconds of walking, so a jolt in traffic isn't taken for getting out.
    static let walkWait: TimeInterval = 5

    static func driving(motion: Motion, speed: Double) -> Bool { motion == .driving || speed >= carSpeed }

    /// How far a drive went, in metres, along the GPS fixes taken during it (25 Nov, drives into the mileage log).
    /// Rough fixes (worse than 65 m) are left out, and a jump no car could make (faster than 70 m/s, 157 mph) is a bad
    /// reading, not distance. Straight lines between fixes taken every few metres follow the road closely.
    static func distance(_ fixes: [Fix]) -> Double {
        let good = fixes.filter { $0.accuracy >= 0 && $0.accuracy <= 65 }.sorted { $0.time < $1.time }
        var total = 0.0
        var last: Fix?
        for f in good {
            if let l = last {
                let d = metres(l, f), t = f.time.timeIntervalSince(l.time)
                if t > 0, d / t > 70 { continue }      // a glitch: skip this fix, keep measuring from the last good one
                total += d
            }
            last = f
        }
        return total
    }

    /// A drive's length: the precise fixes along the way, plus the stretch from the rough fix taken before GPS was
    /// turned up (only when that stretch is longer than the rough fix's own uncertainty, so a guess never adds miles).
    static func driveMetres(_ route: [Fix]) -> Double {
        let precise = route.filter { $0.accuracy >= 0 && $0.accuracy <= 65 }
        var m = distance(route)
        if let first = route.first, first.accuracy > 65, let p = precise.first {
            let lead = metres(first, p)
            if lead > first.accuracy { m += lead - first.accuracy }
        }
        return m
    }

    static func metres(_ a: Fix, _ b: Fix) -> Double {
        let r = 6_371_000.0, p1 = a.lat * .pi / 180, p2 = b.lat * .pi / 180
        let dp = (b.lat - a.lat) * .pi / 180, dl = (b.lng - a.lng) * .pi / 180
        let h = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * atan2(sqrt(h), sqrt(1 - h))
    }

    /// Has the drive ended with the car parked? Walking after a real drive, or still for three minutes. A red light or
    /// a traffic jam is "driving" or "still" for less than that, so it never counts.
    static func parked(drivingSince: Date?, lastDriving: Date?, motion: Motion, motionSince: Date, now: Date) -> Bool {
        guard let start = drivingSince, let last = lastDriving, last.timeIntervalSince(start) >= minDrive else { return false }
        switch motion {
        case .walking: return now.timeIntervalSince(motionSince) >= walkWait
        case .still: return now.timeIntervalSince(max(motionSince, last)) >= stillWait
        case .driving, .unknown: return false
        }
    }

    /// Where the car is, given the moment you got out (`stop`):
    /// 1. a fix good to 25 m from just before to 30 s after getting out, the one nearest that moment (you're beside the car);
    /// 2. else the latest fix good to 50 m from the last three minutes of the drive (a garage hides the sky, so the spot
    ///    is the entrance, which is where you'd walk back to);
    /// 3. else the most accurate fix good to 100 m around the stop.
    /// Nil when nothing is good enough yet: it keeps listening rather than pinning the wrong place.
    static func spot(stop: Date, fixes: [Fix]) -> Fix? {
        let good = fixes.filter { $0.accuracy >= 0 }
        let beside = good.filter { $0.accuracy <= 25 && $0.time >= stop.addingTimeInterval(-20) && $0.time <= stop.addingTimeInterval(30) }
        if let f = beside.min(by: { abs($0.time.timeIntervalSince(stop)) < abs($1.time.timeIntervalSince(stop)) }) { return f }
        let entrance = good.filter { $0.accuracy <= 50 && $0.time <= stop && $0.time >= stop.addingTimeInterval(-180) }
        if let f = entrance.max(by: { $0.time < $1.time }) { return f }
        let rough = good.filter { $0.accuracy <= 100 && $0.time >= stop.addingTimeInterval(-180) && $0.time <= stop.addingTimeInterval(60) }
        return rough.min(by: { $0.accuracy < $1.accuracy })
    }

    /// Keep only the last five minutes of fixes.
    static func trim(_ fixes: [Fix], now: Date) -> [Fix] { fixes.filter { now.timeIntervalSince($0.time) <= 300 } }

    static func motion(automotive: Bool, walking: Bool, running: Bool, stationary: Bool, confident: Bool) -> Motion {
        guard confident else { return .unknown }
        if automotive && !stationary { return .driving }
        if walking || running { return .walking }
        if stationary && !automotive { return .still }
        if automotive { return .driving }   // stopped at a light: still a drive
        return .unknown
    }
}

/// The background half: listens cheaply, follows a drive closely, saves the spot.
@MainActor
final class AutoPark: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = AutoPark()
    static let onKey = "autopark.on"
    static let lastKey = "autopark.last"

    /// Following a drive with GPS turned up.
    @Published private(set) var tracking = false
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined
    @Published private(set) var precise = true
    /// What the motion chip says right now, for the Test run.
    @Published private(set) var motionNow: AutoParkRules.Motion = .unknown

    static var isOn: Bool { UserDefaults.standard.bool(forKey: onKey) }
    static var lastSaved: Date? { UserDefaults.standard.object(forKey: lastKey) as? Date }

    private let lm = CLLocationManager()
    private let motion = CMMotionActivityManager()
    private var session: CLBackgroundActivitySession?
    private var listening = false
    private var fixes: [AutoParkRules.Fix] = []
    private var drivingSince: Date?
    private var lastDriving: Date?
    private var motionSince = Date()
    private var trackingSince: Date?
    private var waitingForSpot: Date?
    /// Every good fix since the drive began, for its distance (the 5-minute window above is only for the spot).
    private var route: [AutoParkRules.Fix] = []
    /// The last fix before the drive was noticed, so the first stretch counts too.
    private var beforeDrive: AutoParkRules.Fix?

    override init() {
        super.init()
        lm.delegate = self
        authorization = lm.authorizationStatus
        precise = lm.accuracyAuthorization == .fullAccuracy
    }

    var allowed: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }

    /// At every launch (and when iPhone relaunches Tenzy for its location session): pick up where it left off.
    func resume() {
        guard Self.isOn, !Launch.uitest, !Launch.screenshots, allowed, !listening else { return }
        listening = true
        if session == nil { session = CLBackgroundActivitySession() }
        lm.allowsBackgroundLocationUpdates = true
        lm.showsBackgroundLocationIndicator = true
        lm.pausesLocationUpdatesAutomatically = false
        lowPower()
        lm.startUpdatingLocation()
        startMotion()
        checkRecentDrive()
    }

    /// The switch on Find my car: the While Using location prompt if it hasn't been asked yet, Motion & Fitness, and
    /// notifications. Nothing else is asked for.
    func turnOn() {
        UserDefaults.standard.set(true, forKey: Self.onKey)
        if lm.authorizationStatus == .notDetermined { lm.requestWhenInUseAuthorization() }
        askMotion()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        resume()
    }

    func turnOff() {
        UserDefaults.standard.set(false, forKey: Self.onKey)
        listening = false
        lm.stopUpdatingLocation()
        lm.allowsBackgroundLocationUpdates = false
        motion.stopActivityUpdates()
        session?.invalidate(); session = nil
        endDrive()
    }

    /// Ask the motion chip about the last minute: shows the Motion & Fitness prompt the first time, and tells the Test
    /// run what Tenzy sees right now.
    func askMotion() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        motion.queryActivityStarting(from: Date().addingTimeInterval(-60), to: Date(), to: .main) { [weak self] acts, _ in
            MainActor.assumeIsolated {
                guard let self, let a = acts?.last else { return }
                self.motionNow = Self.kind(a)
            }
        }
    }

    static var motionAllowed: Bool { CMMotionActivityManager.authorizationStatus() == .authorized }

    // MARK: Listening and following a drive

    /// Away from the car: cell-tower accuracy, every half kilometre. Keeps the session alive for almost no battery.
    private func lowPower() {
        lm.activityType = .other
        lm.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        lm.distanceFilter = 500
    }

    /// During a drive: full GPS, every 5 metres, so the moment you get out has a precise fix.
    private func fullGPS() {
        lm.activityType = .automotiveNavigation
        lm.desiredAccuracy = kCLLocationAccuracyBest
        lm.distanceFilter = 5
    }

    private func startMotion() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        motion.startActivityUpdates(to: .main) { [weak self] a in
            MainActor.assumeIsolated {
                guard let self, let a else { return }
                let k = Self.kind(a)
                if k != self.motionNow { self.motionNow = k; self.motionSince = a.startDate }
                self.evaluate()
            }
        }
    }

    /// At launch: was there a drive in the last ten minutes? Then follow it until you get out.
    private func checkRecentDrive() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        motion.queryActivityStarting(from: Date().addingTimeInterval(-600), to: Date(), to: .main) { [weak self] acts, _ in
            MainActor.assumeIsolated {
                guard let self, let acts, !acts.isEmpty else { return }
                let car = acts.filter { Self.kind($0) == .driving }
                guard let lastCar = car.last else { return }
                self.drivingSince = self.drivingSince ?? car.first?.startDate
                self.lastDriving = max(self.lastDriving ?? .distantPast, lastCar.startDate)
                if let now = acts.last { self.motionNow = Self.kind(now); self.motionSince = now.startDate }
                self.beginDrive()
                self.evaluate()
            }
        }
    }

    private func beginDrive() {
        guard !tracking else { return }
        tracking = true
        trackingSince = Date()
        route = beforeDrive.map { [$0] } ?? []
        fullGPS()
    }

    private func endDrive() {
        // A real drive (two minutes or more) goes into the drives list, for the mileage autorun.
        if tracking, let start = drivingSince, let last = lastDriving, last.timeIntervalSince(start) >= AutoParkRules.minDrive,
           let from = route.first, let to = route.last {
            DriveStore.add(DriveStore.Drive(start: start, end: last, fromLat: from.lat, fromLng: from.lng, toLat: to.lat, toLng: to.lng,
                                            metres: AutoParkRules.driveMetres(route)))
            Task { @MainActor in await SmartRunAlerts.ready(.drives, count: SmartRunStore.shared.waitingCount(.drives)) }
        }
        route = []
        tracking = false
        drivingSince = nil; lastDriving = nil; trackingSince = nil; waitingForSpot = nil
        if listening { lowPower() }
    }

    private func evaluate(now: Date = Date()) {
        let speed = fixes.last.map { now.timeIntervalSince($0.time) < 10 ? $0.speed : 0 } ?? 0
        if AutoParkRules.driving(motion: motionNow, speed: speed) {
            drivingSince = drivingSince ?? now
            lastDriving = now
            waitingForSpot = nil
            beginDrive()
        }
        guard tracking else { return }
        if waitingForSpot == nil,
           AutoParkRules.parked(drivingSince: drivingSince, lastDriving: lastDriving, motion: motionNow, motionSince: motionSince, now: now) {
            waitingForSpot = motionNow == .walking ? motionSince : (lastDriving ?? now)
        }
        if let stop = waitingForSpot {
            if let s = AutoParkRules.spot(stop: stop, fixes: fixes) { save(s); return }
            // Nothing good enough yet: keep listening a minute and a half, then let it go rather than pin a wrong place.
            if now.timeIntervalSince(stop) > 90 { endDrive(); return }
        }
        // A short burst of "driving" that never became a two-minute drive, long gone: back to low power.
        if let last = lastDriving, now.timeIntervalSince(last) > 600, waitingForSpot == nil { endDrive() }
        // Full GPS never runs more than three hours at a stretch.
        if let s = trackingSince, now.timeIntervalSince(s) > 3 * 3600 { endDrive() }
    }

    private func save(_ f: AutoParkRules.Fix) {
        ParkStore.keepPrevious()
        ParkStore.save(CLLocationCoordinate2D(latitude: f.lat, longitude: f.lng))
        ParkStore.setAuto(accuracy: f.accuracy)
        UserDefaults.standard.set(Date(), forKey: Self.lastKey)
        Self.notify(at: f.time)
        NotificationCenter.default.post(name: ParkNow.saved, object: nil)
        endDrive()
    }

    static func notify(at: Date, test: Bool = false) {
        let c = UNMutableNotificationContent()
        let time = at.formatted(date: .omitted, time: .shortened)
        c.title = (test ? "Test · " : "") + L("Car parked")
        c.body = String(format: L("Saved where you parked at %@. Tap to see it and walk back."), time)
        c.sound = .default
        c.userInfo = ["open": "gpsdash"]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "autopark-\(UUID().uuidString)", content: c,
                                                                     trigger: UNTimeIntervalNotificationTrigger(timeInterval: test ? 5 : 1, repeats: false)))
    }

    nonisolated static func kind(_ a: CMMotionActivity) -> AutoParkRules.Motion {
        AutoParkRules.motion(automotive: a.automotive, walking: a.walking, running: a.running, stationary: a.stationary,
                             confident: a.confidence != .low)
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let new = locations.map { AutoParkRules.Fix(lat: $0.coordinate.latitude, lng: $0.coordinate.longitude,
                                                    accuracy: $0.horizontalAccuracy, speed: max(0, $0.speed), time: $0.timestamp) }
        Task { @MainActor in
            guard Self.isOn else { return }
            self.fixes = AutoParkRules.trim(self.fixes + new, now: Date())
            if self.tracking { self.route += new.filter { $0.accuracy >= 0 && $0.accuracy <= 65 } }
            else if let good = new.last(where: { $0.accuracy >= 0 && $0.accuracy <= 600 }) { self.beforeDrive = good }
            self.evaluate()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus, p = manager.accuracyAuthorization == .fullAccuracy
        Task { @MainActor in
            self.authorization = s; self.precise = p
            self.resume()   // the person just allowed location after switching it on
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
