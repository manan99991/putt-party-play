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

    // MARK: jobs, not gauges

    /// Phone standing on an edge: how far the edge is from level (lying on its long side) or plumb (standing
    /// up), whichever is nearer — so a picture frame or a shelf reads 0 when it's right.
    static func offSquare(_ angle: Double) -> (off: Double, level: Bool) {
        let k = (angle / 90).rounded()
        return (angle - k * 90, Int(abs(k)) % 2 == 1)
    }

    /// How far one end is out, over a length (mm), and the slope as a percent and 1-in-N.
    static func slope(degrees d: Double, overMM len: Double = 500) -> (mm: Double, percent: Double, oneIn: Int?) {
        let t = tan(abs(d) * .pi / 180)
        return (t * len, t * 100, t > 0.0005 ? Int((1 / t).rounded()) : nil)
    }

    /// Safe listening time at a level (NIOSH: 8 hours at 85 dB, halved for every 3 dB more), hours.
    static func safeHours(_ db: Double) -> Double { 8 / pow(2, (db - 85) / 3) }

    static func safeText(_ db: Double) -> String {
        if db < 80 { return "Safe for as long as you like" }
        let h = safeHours(db)
        if h >= 1 { return "Safe for about \(Int(h.rounded())) hour\(Int(h.rounded()) == 1 ? "" : "s") a day" }
        let m = h * 60
        if m >= 1 { return "Safe for only about \(Int(m.rounded())) minutes a day" }
        return "Harmful within seconds — cover your ears or leave"
    }

    /// Plants and desks: what this much light is good for.
    static func lightVerdict(_ lux: Double) -> (title: String, plants: String, desk: String) {
        let desk = lux < 300 ? "Too dim to read or work — add a desk lamp" : (lux <= 1000 ? "Good for reading and desk work" : "Very bright — expect glare on screens")
        switch lux {
        case ..<50: return ("Too dark for plants", "Even shade-lovers will struggle here — try a brighter spot or a grow light", desk)
        case ..<250: return ("Low light", "Snake plant, ZZ plant, pothos, peace lily", desk)
        case ..<1000: return ("Medium light", "Philodendron, Chinese evergreen, calathea, spider plant", desk)
        case ..<2500: return ("Bright, indirect light", "Monstera, fiddle-leaf fig, rubber plant, orchids", desk)
        case ..<10000: return ("Very bright light", "Succulents, aloe, citrus, most flowering plants", desk)
        default: return ("Direct sun", "Cacti, herbs like basil and rosemary, tomatoes", desk)
        }
    }

    /// Which way the sun comes from for a direction you face (out of a window), in plain words.
    static func sunText(_ heading: Double, southernHemisphere: Bool = false) -> String {
        let h = southernHemisphere ? (heading + 180).truncatingRemainder(dividingBy: 360) : heading
        switch h {
        case 45..<135: return "Faces east — morning sun"
        case 135..<225: return "Faces the sun at midday — bright most of the day"
        case 225..<315: return "Faces west — afternoon and evening sun"
        default: return "Faces away from the sun — soft, even light all day"
        }
    }

    /// Bearing from a place to the Kaaba in Mecca (Qibla), degrees from true north.
    static func qibla(lat: Double, lon: Double) -> Double {
        let k = (lat: 21.4225 * Double.pi / 180, lon: 39.8262 * Double.pi / 180)
        let p = (lat: lat * Double.pi / 180, lon: lon * Double.pi / 180)
        let dl = k.lon - p.lon
        let y = sin(dl), x = cos(p.lat) * tan(k.lat) - sin(p.lat) * cos(dl)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Turn left or right (−180…180) from where you face to a target bearing.
    static func turn(from heading: Double, to target: Double) -> Double {
        var d = (target - heading).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }; if d < -180 { d += 360 }
        return d
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
    /// Share of a day's safe noise used since Reset (100 = a full day's worth).
    @Published var dose = 0.0
    /// Loud moments above `logAbove`, for a noise log you can share.
    struct Moment: Identifiable { let id = UUID(); let start: Date; var seconds: Double; var peak: Double }
    @Published var moments: [Moment] = []
    @Published var loudFor = 0.0          // seconds in a row at 85 dB or more
    var logAbove = 70.0
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var sum = 0.0, n = 0.0
    private var quietFor = 0.0
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
        if MicCheck.onCall { MicCheck.announce(.onCall); return }
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
        try? session.setActive(true)
        let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatAppleIMA4), AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue]
        recorder = try? AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: settings)
        recorder?.isMeteringEnabled = true
        if recorder?.record() != true { MicCheck.announce(MicCheck.diagnose()) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in Task { @MainActor in self?.sample() } }
    }
    private func sample() {
        guard let r = recorder else { return }
        r.updateMeters()
        let v = SensorMath.dbSPL(fromPower: Double(r.averagePower(forChannel: 0)), offset: offset)
        db = v; peak = max(peak, v); sum += v; n += 1; average = sum / n
        history.append(v); if history.count > 300 { history.removeFirst(history.count - 300) }
        dose += 0.1 / (SensorMath.safeHours(v) * 3600) * 100
        loudFor = v >= 85 ? loudFor + 0.1 : 0
        if v >= logAbove {
            quietFor = 0
            if let last = moments.last, Date().timeIntervalSince(last.start) - last.seconds < 2.5 {
                moments[moments.count - 1].seconds = Date().timeIntervalSince(last.start); moments[moments.count - 1].peak = max(last.peak, v)
            } else { moments.append(Moment(start: Date(), seconds: 0.1, peak: v)) }
        } else { quietFor += 0.1 }
    }
    func reset() { peak = 0; sum = 0; n = 0; average = 0; history = []; dose = 0; moments = []; loudFor = 0 }

    /// The noise log as plain text: when, how long, how loud.
    func logText() -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .medium
        let lines = moments.filter { $0.seconds >= 1 }.map { "\(f.string(from: $0.start)) · \(Int($0.seconds.rounded())) s · peak \(Int($0.peak)) dB" }
        return (["Noise log (phone microphone, about ±5 dB)"] + lines).joined(separator: "\n")
    }
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
