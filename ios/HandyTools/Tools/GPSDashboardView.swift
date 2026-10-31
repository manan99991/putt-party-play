import SwiftUI
import CoreLocation
import MapKit

/// GPS Dashboard — the instrument cluster your phone never shows: live speed, heading, altitude and
/// GPS accuracy, a trip computer (distance, moving time, max, average), a windshield HUD mode,
/// exact coordinates to copy or send to someone, and "park here → walk me back".
struct GPSDashboardView: View {
    @StateObject private var gps = GPSFeed()
    @AppStorage("gps.metric") private var metric = !(Locale.current.measurementSystem == .us)
    @State private var hud = false
    @State private var parked: CLLocationCoordinate2D? = ParkStore.load()
    @State private var parkedAt: Date? = ParkStore.date()
    @State private var parkNote = ParkStore.note()
    @State private var copied = false

    var body: some View {
        ToolPage(title: "GPS Dashboard", subtitle: "Find your parked car, grab your exact location to share, and get a full driving dashboard — all from GPS.") {
            HowTo("gpsdash", [
                "Allow location, then step outside for the best signal.",
                "Tap “Park here” when you leave the car — walk back to it any time.",
                "Driving? Watch speed and your trip, or flip on the windshield HUD.",
            ])

            // 1) The everyday job most people open this for: find the car again.
            sectionHeader("Find my car", "Drop a pin where you parked, then get walking directions back to it.")
            parkCard

            // 2) Your exact spot, to copy or send to someone.
            sectionHeader("My location", "Your exact coordinates — copy them or text them to someone meeting you.")
            locationCard

            // 3) The live driving instruments.
            sectionHeader("Driving dashboard", "Live speed, heading, altitude and a trip computer. Tap HUD to reflect speed in your windshield at night.")
            speedCard
            HStack(spacing: HandySpacing.s8) {
                tile("Heading", gps.course >= 0 ? "\(Int(gps.course))° \(SensorMath.cardinal(gps.course))" : "—", "location.north")
                tile("Altitude", gps.altitude.map { GeoFormat.altitude($0, metric: metric) } ?? "—", "mountain.2")
                tile("GPS ±", gps.accuracy >= 0 ? (metric ? "\(Int(gps.accuracy)) m" : "\(Int(gps.accuracy * 3.28)) ft") : "—", "scope")
            }
            tripCard

            if gps.denied { LimitNote("Location access is off. Allow it in Settings for parking, your location and speed.") }
            Text("Speed comes from GPS, so it lags a second and reads low under trees or between tall buildings. Trip tracking pauses when you leave the app.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear { if Launch.startHardware { gps.start() } }
        .onDisappear { gps.stop() }
        .fullScreenCover(isPresented: $hud) { HUDSheet(gps: gps, metric: metric) }
    }

    private var speedCard: some View {
        VStack(spacing: HandySpacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(GeoFormat.speed(gps.speed, metric: metric)).font(.system(size: 88, weight: .bold, design: .rounded)).monospacedDigit()
                Text(GeoFormat.speedUnit(metric: metric)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textSecondary)
            }
            HStack(spacing: HandySpacing.s8) {
                Picker("Units", selection: $metric) { Text("mph").tag(false); Text("km/h").tag(true) }.pickerStyle(.segmented).frame(width: 150)
                Spacer()
                Button { hud = true } label: { Label("HUD", systemImage: "car.windshield") }.compactButton()
            }
        }.cardStyle()
    }

    private var tripCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Text("Trip").font(HandyFont.bodyStrong)
                Spacer()
                Button { gps.trip.running.toggle() } label: { Label(gps.trip.running ? "Pause" : "Resume", systemImage: gps.trip.running ? "pause.fill" : "play.fill") }.compactButton()
                Button { gps.trip.reset() } label: { Label("Reset", systemImage: "arrow.counterclockwise") }.compactButton()
            }
            HStack(spacing: HandySpacing.s8) {
                tile("Distance", GeoFormat.distance(gps.trip.distance, metric: metric), nil)
                tile("Moving", GeoFormat.duration(gps.trip.movingSeconds), nil)
                tile("Max", GeoFormat.speed(gps.trip.maxSpeed, metric: metric) + " " + GeoFormat.speedUnit(metric: metric), nil)
                tile("Average", GeoFormat.speed(gps.trip.averageSpeed, metric: metric) + " " + GeoFormat.speedUnit(metric: metric), nil)
            }
        }.cardStyle()
    }

    private func sectionHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(HandyFont.cardTitle)
            Text(subtitle).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, HandySpacing.s8)
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if let c = gps.coordinate {
                Text(GeoFormat.decimal(c)).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                Text(GeoFormat.dms(c)).font(HandyFont.caption).monospaced().foregroundStyle(HandyColor.textSecondary)
                HStack(spacing: HandySpacing.s8) {
                    Button { UIPasteboard.general.string = GeoFormat.decimal(c); copied = true; HandyHaptics.success() } label: { Label(copied ? "Copied" : "Copy", systemImage: "doc.on.doc") }.compactButton()
                    ShareLink(item: "I'm here: \(GeoFormat.decimal(c))\n\(GeoFormat.mapsLink(c))") { Label("Send my location", systemImage: "square.and.arrow.up") }.compactButton()
                    Spacer()
                }
            } else {
                Text("Waiting for a GPS fix…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }.cardStyle()
    }

    private var parkCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if let p = parked {
                if let here = gps.coordinate {
                    let d = CLLocation(latitude: p.latitude, longitude: p.longitude).distance(from: CLLocation(latitude: here.latitude, longitude: here.longitude))
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill").font(.system(size: 13)).foregroundStyle(HandyColor.accent)
                        Text("Your car is \(GeoFormat.distance(d, metric: metric)) away").font(HandyFont.bodyStrong)
                        Spacer()
                    }
                }
                Map(initialPosition: .region(MKCoordinateRegion(center: p, latitudinalMeters: 250, longitudinalMeters: 250))) {
                    Marker("Your car", systemImage: "car.fill", coordinate: p).tint(HandyColor.accent)
                    UserAnnotation()
                }
                .frame(height: 160).clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                if let parkedAt { Text("Saved \(parkedAt.formatted(.relative(presentation: .named)))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                TextField("Note (Level 3, near the lift…)", text: $parkNote).textFieldStyle(.roundedBorder).onChange(of: parkNote) { _, n in ParkStore.setNote(n) }
                HStack(spacing: HandySpacing.s8) {
                    Button { walkBack(p) } label: { Label("Walk me back", systemImage: "figure.walk").frame(maxWidth: .infinity) }.primaryButton()
                    Button { park() } label: { Label("Move pin here", systemImage: "mappin.and.ellipse") }.compactButton()
                }
            } else {
                Button { park() } label: { Label("Park here — remember this spot", systemImage: "mappin.and.ellipse").frame(maxWidth: .infinity) }.primaryButton().disabled(gps.coordinate == nil)
                Text(gps.coordinate == nil ? "Waiting for a GPS fix — step outside for a clearer signal." : "Saves the spot on your phone. Nothing is uploaded.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }.cardStyle()
    }

    private func tile(_ k: String, _ v: String, _ icon: String?) -> some View {
        VStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 14)).foregroundStyle(HandyColor.accent) }
            Text(v).font(HandyFont.bodyStrong).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(k).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, HandySpacing.s8)
        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
    }

    private func park() {
        guard let c = gps.coordinate else { return }
        ParkStore.save(c); parked = c; parkedAt = Date(); HandyHaptics.success()
    }
    private func walkBack(_ c: CLLocationCoordinate2D) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: c)); item.name = "Your car"
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

/// Black screen, giant mirrored digits: lay the phone on the dash and read the reflection in the windshield at night.
private struct HUDSheet: View {
    @ObservedObject var gps: GPSFeed
    let metric: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var mirrored = true
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 8) {
                Text(GeoFormat.speed(gps.speed, metric: metric)).font(.system(size: 190, weight: .heavy, design: .rounded)).monospacedDigit().minimumScaleFactor(0.5)
                Text(GeoFormat.speedUnit(metric: metric)).font(.system(size: 34, weight: .semibold))
                HStack(spacing: 40) {
                    if gps.course >= 0 { Text(SensorMath.cardinal(gps.course)).font(.system(size: 40, weight: .bold)) }
                    Text(GeoFormat.distance(gps.trip.distance, metric: metric)).font(.system(size: 40, weight: .bold)).monospacedDigit()
                }.foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(Color(red: 0.3, green: 1, blue: 0.4))
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            VStack {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).padding(12).background(.white.opacity(0.12), in: Circle()) }.accessibilityLabel("Close HUD")
                    Spacer()
                    Button { mirrored.toggle() } label: { Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right").font(.system(size: 16, weight: .bold)).padding(12).background(.white.opacity(0.12), in: Circle()) }
                }
                Spacer()
                Text(mirrored ? "Mirrored for the windshield · tap to flip" : "Normal view").font(HandyFont.caption).foregroundStyle(.white.opacity(0.4))
            }.padding(HandySpacing.gutter).foregroundStyle(.white)
        }
        .statusBarHidden()
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true; UIScreen.main.brightness = 1 }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

@MainActor
final class GPSFeed: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var speed = 0.0
    @Published var course = -1.0
    @Published var accuracy = -1.0
    @Published var altitude: Double? = nil
    @Published var coordinate: CLLocationCoordinate2D? = nil
    @Published var trip = TripTracker()
    @Published var denied = false
    private let m = CLLocationManager()
    override init() { super.init(); m.delegate = self; m.desiredAccuracy = kCLLocationAccuracyBestForNavigation; m.activityType = .automotiveNavigation }
    func start() { m.requestWhenInUseAuthorization(); m.startUpdatingLocation() }
    func stop() { m.stopUpdatingLocation() }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let l = locs.last else { return }
        let sp = l.speed, co = l.course, acc = l.horizontalAccuracy, alt = l.altitude, va = l.verticalAccuracy, c = l.coordinate, t = l.timestamp
        Task { @MainActor in
            self.speed = sp >= 0 ? sp : 0; self.course = co; self.accuracy = acc; self.coordinate = c
            if va >= 0 { self.altitude = alt }
            self.trip.add(coordinate: c, speed: max(0, sp), horizontalAccuracy: acc, timestamp: t)
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in self.denied = (s == .denied || s == .restricted) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
