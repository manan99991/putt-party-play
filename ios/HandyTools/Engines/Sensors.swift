import Foundation
import CoreMotion
import CoreLocation
import AVFoundation
import UIKit

/// Pure conversions behind Instruments — kept free of hardware so they're unit-testable.
enum SensorMath {
    /// Approximate scene illuminance from camera exposure (reflected-light meter, ISO 2720 style).
    /// EV100 = log2(N²/t) − log2(ISO/100); lux ≈ 2.5 · 2^EV100 (calibration constant for a camera meter).
    static func lux(iso: Double, shutter: Double, aperture: Double) -> Double {
        guard iso > 0, shutter > 0, aperture > 0 else { return 0 }
        let ev100 = log2((aperture * aperture) / shutter) - log2(iso / 100)
        return 2.5 * pow(2, ev100)
    }

    /// Human label for a lux reading.
    static func luxLabel(_ lux: Double) -> String {
        switch lux {
        case ..<5: return "Very dark"
        case ..<50: return "Dim — night light / hallway"
        case ..<200: return "Living room"
        case ..<500: return "Office / reading"
        case ..<1000: return "Bright indoor / overcast window"
        case ..<10000: return "Daylight, shade"
        default: return "Direct sun"
        }
    }

    /// Microphone power (dBFS, −160…0) → an everyday dB-ish scale (phone mics aren't calibrated meters;
    /// `offset` lets a user match a real one).
    static func dbSPL(fromPower power: Double, offset: Double = 0) -> Double { max(20, min(130, power + 90 + offset)) }

    static func dbLabel(_ db: Double) -> String {
        switch db {
        case ..<30: return "Whisper quiet"
        case ..<45: return "Quiet room"
        case ..<60: return "Normal conversation"
        case ..<75: return "Busy street / loud office"
        case ..<85: return "Loud — tiring after hours"
        case ..<100: return "Very loud — hearing risk after 15 min"
        default: return "Dangerous — protect your ears"
        }
    }

    static func cardinal(_ degrees: Double) -> String {
        let dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let i = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) + 11.25) / 22.5) % 16
        return dirs[i]
    }

    /// Tilt from gravity: bubble offset (−1…1) and angle in degrees from level; `level` when within 0.3°.
    static func tilt(gx: Double, gy: Double, gz: Double) -> (x: Double, y: Double, angle: Double, upright: Bool) {
        let upright = abs(gz) < 0.6
        if upright {
            // phone standing on an edge: angle of the long edge from vertical (a protractor / inclinometer)
            let a = atan2(gx, -gy) * 180 / .pi
            return (gx, 0, a, true)
        }
        let a = atan2(sqrt(gx * gx + gy * gy), abs(gz)) * 180 / .pi
        return (gx, -gy, a, false)
    }

    /// Microtesla magnitude and a 0…1 "metal nearby" score relative to the ambient baseline (~50 µT).
    static func field(x: Double, y: Double, z: Double, baseline: Double) -> (magnitude: Double, score: Double) {
        let m = sqrt(x * x + y * y + z * z)
        let score = max(0, min(1, (m - baseline) / 300))
        return (m, score)
    }

    /// Barometric altitude change from pressure (hypsometric, standard atmosphere), metres.
    static func altitudeDelta(fromKPa p: Double, referenceKPa p0: Double) -> Double {
        guard p > 0, p0 > 0 else { return 0 }
        return 44330 * (1 - pow(p / p0, 1 / 5.255))
    }

    /// Points per millimetre for an on-screen ruler. iPhones are ~460 ppi at 3× and ~326 ppi at 2×.
    static func pointsPerMM(nativeScale: CGFloat, calibration: Double = 1) -> Double {
        let ppi: Double = nativeScale >= 3 ? 460 : 326
        return (ppi / Double(nativeScale)) / 25.4 * calibration
    }
}

// MARK: - live sensors

@MainActor final class MotionSensor: ObservableObject {
    @Published var x = 0.0
    @Published var y = 0.0
    @Published var angle = 0.0
    @Published var upright = false
    @Published var level = false
    @Published var field = 0.0
    @Published var metalScore = 0.0
    private let mgr = CMMotionManager()
    private var zero = 0.0
    private var baseline = 50.0
    var available: Bool { mgr.isDeviceMotionAvailable }

    func start(magnet: Bool = false) {
        guard mgr.isDeviceMotionAvailable else { return }
        mgr.deviceMotionUpdateInterval = 1.0 / 30.0
        mgr.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: .main) { [weak self] d, _ in
            guard let self, let d else { return }
            let t = SensorMath.tilt(gx: d.gravity.x, gy: d.gravity.y, gz: d.gravity.z)
            self.x = t.x; self.y = t.y; self.upright = t.upright
            let a = t.angle - self.zero
            self.angle = a
            self.level = abs(a) < 0.3
        }
        if magnet, mgr.isMagnetometerAvailable {
            mgr.magnetometerUpdateInterval = 1.0 / 20.0
            mgr.startMagnetometerUpdates(to: .main) { [weak self] m, _ in
                guard let self, let f = m?.magneticField else { return }
                let r = SensorMath.field(x: f.x, y: f.y, z: f.z, baseline: self.baseline)
                self.field = r.magnitude; self.metalScore = r.score
            }
        }
    }
    /// Treat the current surface as zero (calibrate against a known-level table).
    func zeroHere() { zero += angle; HandyHaptics.light() }
    func resetZero() { zero = 0 }
    func calibrateMagnet() { baseline = field; HandyHaptics.light() }
    func stop() { mgr.stopDeviceMotionUpdates(); mgr.stopMagnetometerUpdates() }
}

@MainActor final class HeadingSensor: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var magnetic = 0.0
    @Published var trueHeading = 0.0
    @Published var accuracy = 0.0
    @Published var altitude: Double? = nil
    @Published var altitudeAccuracy = 0.0
    @Published var coordinate: CLLocationCoordinate2D? = nil
    @Published var available = true
    private let m = CLLocationManager()
    func start(location: Bool = false) {
        m.delegate = self
        m.requestWhenInUseAuthorization()
        if CLLocationManager.headingAvailable() { m.headingFilter = 1; m.startUpdatingHeading() } else { available = false }
        if location { m.desiredAccuracy = kCLLocationAccuracyBest; m.startUpdatingLocation() }
    }
    func stop() { m.stopUpdatingHeading(); m.stopUpdatingLocation() }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading h: CLHeading) {
        let mg = h.magneticHeading, tr = h.trueHeading, acc = h.headingAccuracy
        Task { @MainActor in self.magnetic = mg; self.trueHeading = tr >= 0 ? tr : mg; self.accuracy = acc }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let l = locs.last else { return }
        let alt = l.altitude, va = l.verticalAccuracy, c = l.coordinate
        Task { @MainActor in if va >= 0 { self.altitude = alt; self.altitudeAccuracy = va }; self.coordinate = c }
    }
}

@MainActor final class SoundSensor: ObservableObject {
    @Published var db = 0.0
    @Published var peak = 0.0
    @Published var average = 0.0
    @Published var history: [Double] = []
    @Published var denied = false
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var sum = 0.0, n = 0.0
    var offset: Double { UserDefaults.standard.double(forKey: "instruments.db.offset") }

    func start() {
        Permission.microphone { [weak self] ok in
            Task { @MainActor in
                guard let self else { return }
                if !ok { self.denied = true; return }
                self.begin()
            }
        }
    }
    private func begin() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
        try? session.setActive(true)
        let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatAppleIMA4), AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue]
        recorder = try? AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in Task { @MainActor in self?.sample() } }
    }
    private func sample() {
        guard let r = recorder else { return }
        r.updateMeters()
        let v = SensorMath.dbSPL(fromPower: Double(r.averagePower(forChannel: 0)), offset: offset)
        db = v; peak = max(peak, v); sum += v; n += 1; average = sum / n
        history.append(v); if history.count > 300 { history.removeFirst(history.count - 300) }
    }
    func reset() { peak = 0; sum = 0; n = 0; average = 0; history = [] }
    func stop() { timer?.invalidate(); timer = nil; recorder?.stop(); recorder = nil; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
}

/// Light meter from the camera's auto-exposure: reads ISO / shutter / aperture as it adapts.
@MainActor final class LightSensor: ObservableObject {
    @Published var lux = 0.0
    private let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var timer: Timer?
    func start() {
        nonisolated(unsafe) let s = session
        if session.inputs.isEmpty {
            guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), let input = try? AVCaptureDeviceInput(device: dev), session.canAddInput(input) else { return }
            session.sessionPreset = .low
            session.addInput(input)
            device = dev
        }
        DispatchQueue.global().async { s.startRunning() }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in Task { @MainActor in self?.read() } }
    }
    private func read() {
        guard let d = device else { return }
        let v = SensorMath.lux(iso: Double(d.iso), shutter: d.exposureDuration.seconds, aperture: Double(d.lensAperture))
        lux = lux == 0 ? v : lux * 0.7 + v * 0.3
    }
    func stop() {
        timer?.invalidate(); timer = nil
        nonisolated(unsafe) let s = session
        if session.isRunning { DispatchQueue.global().async { s.stopRunning() } }
    }
}

@MainActor final class BarometerSensor: ObservableObject {
    @Published var pressureKPa: Double? = nil
    @Published var relativeMetres = 0.0
    @Published var available = CMAltimeter.isRelativeAltitudeAvailable()
    private let alt = CMAltimeter()
    func start() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { available = false; return }
        alt.startRelativeAltitudeUpdates(to: .main) { [weak self] d, _ in
            guard let self, let d else { return }
            self.pressureKPa = d.pressure.doubleValue; self.relativeMetres = d.relativeAltitude.doubleValue
        }
    }
    func reset() { alt.stopRelativeAltitudeUpdates(); relativeMetres = 0; start() }
    func stop() { alt.stopRelativeAltitudeUpdates() }
}
