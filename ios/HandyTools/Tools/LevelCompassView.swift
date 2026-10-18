import SwiftUI
import CoreMotion
import CoreLocation

// MARK: - Compass

/// A clean compass with the heading in big numbers and the exact cardinal direction. No ads of your
/// attention — just which way you're facing.
struct CompassView: View {
    @StateObject private var h = Heading()
    var body: some View {
        ToolPage(title: "Compass", subtitle: "Which way am I facing? Hold the phone flat.") {
            ZStack {
                Circle().stroke(HandyColor.border, lineWidth: 2)
                ForEach(0..<12) { i in
                    Rectangle().fill(HandyColor.textSecondary).frame(width: i % 3 == 0 ? 3 : 1, height: i % 3 == 0 ? 16 : 10)
                        .offset(y: -110).rotationEffect(.degrees(Double(i) * 30))
                }
                VStack {
                    Text("N").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.danger); Spacer()
                }.frame(height: 220)
                VStack(spacing: 0) {
                    Text("\(Int(h.degrees))°").font(.system(size: 52, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(h.cardinal).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                }
                Image(systemName: "location.north.fill").font(.system(size: 22)).foregroundStyle(HandyColor.accent)
                    .offset(y: -140)
            }
            .frame(width: 260, height: 300).rotationEffect(.degrees(-h.degrees)).animation(.easeOut(duration: 0.15), value: h.degrees)
            .padding(.top, HandySpacing.s16)
            .frame(maxWidth: .infinity)
            if !h.available {
                Text("Your compass needs location access. Enable it in Settings to see your heading.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            }
        }
        .onAppear { h.start() }.onDisappear { h.stop() }
    }
}

@MainActor
final class Heading: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var degrees: Double = 0
    @Published var available = true
    private let m = CLLocationManager()
    func start() {
        m.delegate = self
        m.requestWhenInUseAuthorization()
        if CLLocationManager.headingAvailable() { m.headingFilter = 1; m.startUpdatingHeading() } else { available = false }
    }
    func stop() { m.stopUpdatingHeading() }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let d = newHeading.magneticHeading
        Task { @MainActor in self.degrees = d }
    }
    var cardinal: String {
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return dirs[Int((degrees + 22.5) / 45) % 8]
    }
}

// MARK: - Level

/// A bubble level for hanging a picture or checking a shelf. Flat or upright, it reads the tilt off
/// the phone's motion sensors.
struct LevelView: View {
    @StateObject private var mo = Motion()
    var body: some View {
        ToolPage(title: "Level", subtitle: "Lay it flat or stand it up — find true level.") {
            ZStack {
                Circle().stroke(HandyColor.border, lineWidth: 2).frame(width: 260, height: 260)
                Circle().stroke(HandyColor.border.opacity(0.5), lineWidth: 1).frame(width: 90, height: 90)
                Circle().fill(mo.level ? HandyColor.success : HandyColor.accent)
                    .frame(width: 60, height: 60)
                    .offset(x: CGFloat(mo.x) * 120, y: CGFloat(mo.y) * 120)
                    .animation(.easeOut(duration: 0.1), value: mo.x)
            }
            .frame(maxWidth: .infinity).padding(.top, HandySpacing.s24)
            Text(String(format: "%.1f°", mo.angle)).font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(mo.level ? HandyColor.success : HandyColor.textPrimary)
                .frame(maxWidth: .infinity)
        }
        .onAppear { mo.start() }.onDisappear { mo.stop() }
    }
}

@MainActor
final class Motion: ObservableObject {
    @Published var x = 0.0; @Published var y = 0.0; @Published var angle = 0.0; @Published var level = false
    private let mgr = CMMotionManager()
    func start() {
        guard mgr.isDeviceMotionAvailable else { return }
        mgr.deviceMotionUpdateInterval = 1.0 / 30.0
        mgr.startDeviceMotionUpdates(to: .main) { [weak self] d, _ in
            guard let self, let g = d?.gravity else { return }
            self.x = g.x; self.y = -g.y
            self.angle = abs(atan2(g.x, -g.y) * 180 / .pi)
            let tilt = sqrt(g.x * g.x + g.y * g.y)
            self.level = tilt < 0.03
        }
    }
    func stop() { mgr.stopDeviceMotionUpdates() }
}
