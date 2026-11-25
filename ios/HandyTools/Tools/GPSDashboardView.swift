import SwiftUI
import CoreLocation
import MapKit
import UserNotifications
import AudioToolbox

/// GPS Dashboard — the instrument cluster your phone never shows: live speed, heading, altitude and
/// GPS accuracy, a trip computer (distance, moving time, max, average), a windshield HUD mode,
/// exact coordinates to copy or send to someone, and "park here → walk me back".
/// Which location a parking pin may use. iPhone's first answer after it starts looking is often a remembered one from
/// earlier (where the phone last checked), which pinned old places (Manan, 24 Nov). A pin uses only a fix taken after
/// saving began: the first good to 65 m, or after 20 s the freshest there is.
enum ParkFix {
    /// Taken after saving began (2 s of clock slack).
    static func ready(fixTime: Date?, accuracy: Double, since: Date, now: Date) -> Bool {
        guard let f = fixTime, f >= since.addingTimeInterval(-2) else { return false }
        return (accuracy >= 0 && accuracy <= 65) || now.timeIntervalSince(since) > 20
    }
    /// For the Park here button: the fix is from the last 15 seconds.
    static func fresh(_ fixTime: Date?, now: Date) -> Bool {
        guard let f = fixTime else { return false }
        return now.timeIntervalSince(f) <= 15
    }
}

/// Set by "Save where I parked" (Control Center, Lock Screen, Shortcuts): the dashboard drops the pin on its first fix.
@MainActor enum ParkNow {
    static var pending = false
    /// Posted when the dashboard is already open, so it starts saving straight away.
    static let notification = Notification.Name("tenzy.parknow")
    /// Posted when automatic parking saves a spot, so an open Find my car shows it at once.
    static let saved = Notification.Name("tenzy.parknow.saved")
}

struct GPSDashboardView: View {
    @StateObject private var gps = GPSFeed()
    @AppStorage("gps.metric") private var metric = !(Locale.current.measurementSystem == .us)
    @State private var hud = false
    @State private var parked: CLLocationCoordinate2D? = ParkStore.load()
    @State private var parkedAt: Date? = ParkStore.date()
    @State private var parkNote = ParkStore.note()
    @State private var copied = false
    @State private var meterEnds: Date? = ParkingMeter.endsAt.flatMap { $0 > Date() ? $0 : nil }
    @State private var meterLead = ParkingMeter.lead
    @State private var customMeter = Date().addingTimeInterval(3600)
    @State private var meterNote: String?
    @State private var notifyOff = false
    @ObservedObject private var auto = AutoPark.shared
    @AppStorage(AutoPark.onKey) private var autoOn = false
    @State private var alertsAllowed = false
    @State private var autoTest: String?
    @AppStorage("gps.speedLimit") private var speedLimit = 0.0
    @State private var warnState = SpeedWarning.State()
    @State private var overLimit = false
    @State private var savingNow = false
    @State private var savingSince = Date()
    @State private var autoNote: String?

    var body: some View {
        ToolPage(title: "GPS Dashboard", subtitle: "Find your parked car, grab your exact location to share, and get a full driving dashboard — all from GPS.") {
            HowTo("gpsdash", [
                "Allow location, then step outside for the best signal.",
                "Tap “Park here” when you leave the car — walk back to it any time.",
                "Paid parking? Set when the meter runs out and get a heads-up with the walk back.",
                "Driving? Watch speed and your trip, set a speed warning, or flip on the windshield HUD.",
            ])

            // 1) The everyday job most people open this for: find the car again.
            sectionHeader("Find my car", "Drop a pin where you parked, then get walking directions back to it.")
            if savingNow {
                HStack(spacing: HandySpacing.s8) {
                    BusySpinner()
                    Text(L("Saving where you parked — getting a GPS fix…")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }.cardStyle()
            }
            if let autoNote { Label(L(autoNote), systemImage: "checkmark.circle.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success).cardStyle() }
            parkCard
            if parked != nil { meterCard }
            automaticCard
            autoParkCard

            // 2) Your exact spot, to copy or send to someone.
            sectionHeader("My location", "Your exact coordinates — copy them or text them to someone meeting you.")
            locationCard

            // 3) The live driving instruments.
            sectionHeader("Driving dashboard", "Live speed, heading, altitude and a trip computer. Tap HUD to reflect speed in your windshield at night.")
            speedCard
            speedWarnCard
            HStack(spacing: HandySpacing.s8) {
                tile("Heading", gps.course >= 0 ? "\(Int(gps.course))° \(SensorMath.cardinal(gps.course))" : "—", "location.north")
                tile("Altitude", gps.altitude.map { GeoFormat.altitude($0, metric: metric) } ?? "—", "mountain.2")
                tile("GPS ±", gps.accuracy >= 0 ? (metric ? "\(Int(gps.accuracy)) m" : "\(Int(gps.accuracy * 3.28)) ft") : "—", "scope")
            }
            tripCard

            if gps.denied { LimitNote("Location access is off. Allow it in Settings for parking, your location and speed.") }
            Text(L("Speed comes from GPS, so it lags a second and reads low under trees or between tall buildings. Trip tracking pauses when you leave the app."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear {
            if Launch.startHardware { gps.start() }
            if ParkNow.pending { gps.start(); savingSince = Date(); savingNow = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: ParkNow.notification)) { _ in
            guard ParkNow.pending else { return }
            gps.start(); savingSince = Date(); autoNote = nil; savingNow = true
        }
        // "Save where I parked" from Control Center, the Lock Screen, Siri or the CarPlay/Bluetooth automation: drop the
        // pin on the first FRESH fix good to 65 m, or after 20 s on the freshest there is. Never on the remembered fix
        // iPhone hands over first (Manan, 24 Nov: parked twice and it kept showing an old address).
        .onReceive(gps.$coordinate) { c in
            guard savingNow, c != nil else { return }
            if ParkFix.ready(fixTime: gps.fixTime, accuracy: gps.accuracy, since: savingSince, now: Date()) { autoPark() }
        }
        // The HUD is a full-screen cover, which can count as leaving this page — keep GPS running under it.
        .onDisappear { if !hud { gps.stop() } }
        .onChange(of: hud) { _, on in if !on { gps.start() } }
        .onChange(of: gps.speed) { _, mps in
            let v = mps * (metric ? 3.6 : 2.23694)
            overLimit = speedLimit > 0 && v > speedLimit
            if SpeedWarning.check(speed: v, limit: speedLimit, state: &warnState) { warn() }
        }
        .fullScreenCover(isPresented: $hud) { HUDSheet(gps: gps, metric: metric) }
    }

    private var speedCard: some View {
        VStack(spacing: HandySpacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(GeoFormat.speed(gps.speed, metric: metric)).font(.system(size: 88, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(overLimit ? HandyColor.danger : HandyColor.textPrimary)
                Text(GeoFormat.speedUnit(metric: metric)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textSecondary)
            }
            HStack(spacing: HandySpacing.s8) {
                Picker(L("Units"), selection: $metric) { Text(L("mph")).tag(false); Text(L("km/h")).tag(true) }.pickerStyle(.segmented).frame(width: 150)
                Spacer()
                Button { hud = true } label: { Label(L("HUD"), systemImage: "car.windshield") }.compactButton()
            }
        }.cardStyle()
    }

    private var tripCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Text(L("Trip")).font(HandyFont.bodyStrong)
                Spacer()
                Button { gps.trip.running.toggle() } label: { Label(gps.trip.running ? "Pause" : "Resume", systemImage: gps.trip.running ? "pause.fill" : "play.fill") }.compactButton()
                Button { gps.trip.reset() } label: { Label(L("Reset"), systemImage: "arrow.counterclockwise") }.compactButton()
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
                    ShareLink(item: "I'm here: \(GeoFormat.decimal(c))\n\(GeoFormat.mapsLink(c))") { Label(L("Send my location"), systemImage: "square.and.arrow.up") }.compactButton()
                    Spacer()
                }
            } else {
                Text(L("Waiting for a GPS fix…")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
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
                // A new spot redraws the map around it (the map kept showing the old place after a new save, 24 Nov).
                .id("\(p.latitude),\(p.longitude)")
                if let parkedAt {
                    HStack(spacing: 6) {
                        Text(ParkStore.wasAuto
                             ? String(format: L("Saved by itself %@"), parkedAt.formatted(.relative(presentation: .named))) + (ParkStore.accuracy.map { " · " + String(format: L("within %@"), GeoFormat.distance($0, metric: metric)) } ?? "")
                             : String(format: L("Saved %@"), parkedAt.formatted(.relative(presentation: .named))))
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        Spacer(minLength: 4)
                        if ParkStore.wasAuto {
                            // A bus, a taxi or a friend's car isn't yours: put the earlier spot back.
                            Button { ParkStore.restorePrevious(); reloadSpot() } label: { Text(L("Not my car")).font(HandyFont.caption.weight(.semibold)) }
                                .buttonStyle(.plain).foregroundStyle(HandyColor.accent).frame(minHeight: 44).accessibilityIdentifier("gps-not-my-car")
                        }
                    }
                }
                TextField(L("Note (Level 3, near the lift…)"), text: $parkNote).textFieldStyle(.handy).onChange(of: parkNote) { _, n in ParkStore.setNote(n) }
                HStack(spacing: HandySpacing.s8) {
                    Button { walkBack(p) } label: { Label(L("Walk me back"), systemImage: "figure.walk").frame(maxWidth: .infinity) }.primaryButton()
                    Button { park() } label: { Label(L("Move pin here"), systemImage: "mappin.and.ellipse") }.compactButton()
                }
                HStack(spacing: HandySpacing.s8) {
                    ShareLink(item: "\(L("My car is here")): \(GeoFormat.mapsLink(p))" + (parkNote.isEmpty ? "" : " — \(parkNote)")) {
                        Label(L("Send the spot"), systemImage: "square.and.arrow.up")
                    }.compactButton()
                    Spacer()
                    Button { ParkStore.clear(); ParkingMeter.cancel(); parked = nil; parkedAt = nil; parkNote = ""; meterEnds = nil } label: {
                        Label(L("I'm back — clear it"), systemImage: "checkmark.circle")
                    }.compactButton()
                }
            } else {
                Button { park() } label: { Label(L("Park here — remember this spot"), systemImage: "mappin.and.ellipse").frame(maxWidth: .infinity) }.primaryButton().disabled(!ParkFix.fresh(gps.fixTime, now: Date()))
                Text(!ParkFix.fresh(gps.fixTime, now: Date()) ? "Finding where you are now — step outside for a clearer signal." : "Saves the spot on your phone. Nothing is uploaded.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }.cardStyle()
    }

    private var walkText: String? {
        guard let p = parked, let here = gps.coordinate else { return nil }
        let d = CLLocation(latitude: p.latitude, longitude: p.longitude).distance(from: CLLocation(latitude: here.latitude, longitude: here.longitude))
        return GeoFormat.distance(d, metric: metric)
    }

    /// Paid parking: when it runs out, and a heads-up before. Set once; Test run shows the alert.
    private var meterCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Parking meter"), systemImage: "timer").font(HandyFont.bodyStrong)
            if let ends = meterEnds {
                Text("\(L("Runs out at")) \(ends.formatted(date: .omitted, time: .shortened)) · \(L("we'll remind you")) \(meterLead) \(L("min before"))")
                    .font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent)
                Text(ends, style: .timer).font(.system(.title2, design: .rounded)).monospacedDigit()
                Button { ParkingMeter.cancel(); meterEnds = nil } label: { Label(L("Cancel the reminder"), systemImage: "xmark.circle") }.compactButton()
            } else {
                Text(L("Paid parking? Tell Tenzy when it runs out and get a heads-up in time to walk back.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                HandyFlow(spacing: HandySpacing.s8) {
                    ForEach(ParkingMeter.lengths, id: \.minutes) { l in
                        HChip(text: L(l.label), selected: false) { Task { await setMeter(Date().addingTimeInterval(Double(l.minutes) * 60)) } }
                    }
                }
                HStack {
                    DatePicker(L("Or runs out at"), selection: $customMeter, in: Date()..., displayedComponents: .hourAndMinute).font(HandyFont.caption)
                    Button(L("Set")) { Task { await setMeter(customMeter) } }.compactButton()
                }
            }
            HandyFlow(spacing: HandySpacing.s8) {
                Text(L("Remind me")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                ForEach(ParkingMeter.leads, id: \.self) { m in
                    HChip(text: "\(m) \(L("min before"))", selected: meterLead == m) {
                        meterLead = m
                        if let e = meterEnds { Task { await setMeter(e) } } else { ParkingMeter.lead = m }
                    }
                }
            }
            NotificationsOffCard(isOff: $notifyOff)
            Button {
                Task {
                    guard await NotifyPermission.ensure() else { notifyOff = true; return }
                    await ParkingMeter.testRun(walk: walkText)
                    meterNote = "Test sent — lock your phone; it arrives in 5 seconds."
                }
            } label: { Label(L("Test run"), systemImage: "checkmark.seal").frame(maxWidth: .infinity) }
                .secondaryButton().accessibilityIdentifier("gps-meter-test")
            if let meterNote { Text(L(meterNote)).font(HandyFont.caption).foregroundStyle(HandyColor.success) }
        }
        .cardStyle()
    }

    private func setMeter(_ ends: Date) async {
        guard await NotifyPermission.ensure() else { notifyOff = true; return }
        notifyOff = false
        await ParkingMeter.schedule(ends: ends, lead: meterLead, walk: walkText)
        meterEnds = ends; meterNote = nil
        HandyHaptics.success()
    }

    /// One chime when you go over your number, then quiet until you're back under.
    private var speedWarnCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Label(L("Speed warning"), systemImage: "exclamationmark.triangle").font(HandyFont.bodyStrong)
                Spacer()
                Text(speedLimit > 0 ? "\(Int(speedLimit)) \(GeoFormat.speedUnit(metric: metric))" : L("Off")).font(HandyFont.bodyStrong).monospacedDigit()
            }
            HandyFlow(spacing: HandySpacing.s8) {
                HChip(text: L("Off"), selected: speedLimit == 0) { speedLimit = 0 }
                ForEach(metric ? [30, 50, 80, 100, 120] : [25, 35, 45, 55, 65, 75], id: \.self) { v in
                    HChip(text: "\(v)", selected: Int(speedLimit) == v) { speedLimit = Double(v); warnState = .init() }
                }
            }
            Text(L("Chimes once when you go over, and the number turns red. Works while this screen or the HUD is open.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            Button { warn() } label: { Label(L("Test run — hear the chime"), systemImage: "speaker.wave.2") }.compactButton()
                .accessibilityIdentifier("gps-speed-test")
        }
        .cardStyle()
    }

    private func warn() {
        AudioServicesPlayAlertSound(SystemSoundID(1005))
        HandyHaptics.success()
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

    private func reloadSpot() {
        parked = ParkStore.load(); parkedAt = ParkStore.date(); parkNote = ParkStore.note()
    }

    // MARK: Save my spot automatically

    /// One switch, no setup (Manan, 24 Nov): Tenzy notices the drive ending and saves where you got out. Uses only the
    /// While Using location and Motion & Fitness. Shows what's still needed, with a Settings button for each, and a
    /// Test run that checks everything and sends a sample alert.
    private var automaticCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Toggle(isOn: Binding(get: { autoOn }, set: { on in
                autoOn = on
                if on { auto.turnOn() } else { auto.turnOff() }
                autoTest = nil
                Task { await refreshAlertsAllowed() }
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(L("Save my spot automatically"), systemImage: "car.side.arrowtriangle.down.fill").font(HandyFont.bodyStrong)
                    Text(L("When you stop driving and get out, Tenzy saves where you parked and tells you. Nothing to set up.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            .tint(HandyColor.accent).accessibilityIdentifier("gps-autopark-switch")
            if autoOn {
                autoRow(auto.allowed, L("Location"), auto.authorization == .denied || auto.authorization == .restricted ? L("Turn on in Settings › Tenzy › Location") : L("Allow when asked"))
                autoRow(auto.precise, L("Precise location"), L("Turn on Precise Location in Settings › Tenzy › Location"))
                autoRow(AutoPark.motionAllowed, L("Motion & Fitness"), L("Turn on in Settings › Tenzy"))
                autoRow(alertsAllowed, L("Alerts"), L("Optional: turn on to hear when your spot is saved"))
                if ProcessInfo.processInfo.isLowPowerModeEnabled {
                    Label(L("Low Power Mode is on: iPhone may pause this until it's off."), systemImage: "battery.25").font(HandyFont.caption).foregroundStyle(HandyColor.amber)
                }
                if let last = AutoPark.lastSaved {
                    Text(String(format: L("Last saved by itself: %@"), last.formatted(.relative(presentation: .named)))).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                HStack(spacing: HandySpacing.s8) {
                    Button { runAutoTest() } label: { Label(L("Test run"), systemImage: "play.circle") }
                        .compactButton().accessibilityIdentifier("gps-autopark-check")
                    if !(auto.allowed && auto.precise && AutoPark.motionAllowed), let u = URL(string: UIApplication.openSettingsURLString) {
                        Button { UIApplication.shared.open(u) } label: { Label(L("Open Settings"), systemImage: "gear") }.compactButton()
                    }
                }
                if let autoTest {
                    Text(autoTest).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).accessibilityIdentifier("gps-autopark-result")
                }
                Text(L("Uses the location and motion access Tenzy already has. iPhone shows a small blue location pill while it's on. Swiping Tenzy away pauses it until you open it again. Nothing leaves your phone."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .cardStyle()
        .task { await refreshAlertsAllowed() }
        .onReceive(NotificationCenter.default.publisher(for: ParkNow.saved)) { _ in reloadSpot() }
    }

    private func autoRow(_ ok: Bool, _ what: String, _ fix: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ok ? HandyColor.success : HandyColor.amber).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(what).font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.textPrimary)
                if !ok { Text(fix).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func refreshAlertsAllowed() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        alertsAllowed = s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
    }

    /// Checks every piece and says, in plain words, what Tenzy sees right now; sends a sample "Car parked" alert.
    private func runAutoTest() {
        auto.askMotion()
        Task {
            await refreshAlertsAllowed()
            try? await Task.sleep(nanoseconds: 600_000_000)
            var missing: [String] = []
            if !auto.allowed { missing.append(L("Location")) }
            if !auto.precise { missing.append(L("Precise location")) }
            if !AutoPark.motionAllowed { missing.append(L("Motion & Fitness")) }
            let seen: String
            switch auto.motionNow {
            case .driving: seen = L("driving")
            case .walking: seen = L("walking")
            case .still: seen = L("still")
            case .unknown: seen = L("not sure yet")
            }
            if missing.isEmpty {
                autoTest = String(format: L("Ready. Right now Tenzy sees you %@. Next time you park and walk away, your spot saves by itself."), seen)
                    + (alertsAllowed ? " " + L("A sample alert arrives in 5 seconds.") : "")
                if alertsAllowed { AutoPark.notify(at: Date(), test: true) }
                HandyHaptics.success()
            } else {
                autoTest = String(format: L("Not ready yet. Still needed: %@."), missing.joined(separator: ", "))
            }
        }
    }

    private func park() {
        guard let c = gps.coordinate, ParkFix.fresh(gps.fixTime, now: Date()) else { return }
        ParkStore.save(c); parked = c; parkedAt = Date(); HandyHaptics.success()
    }

    private func autoPark() {
        savingNow = false; ParkNow.pending = false
        park()
        autoNote = "Saved where you parked. Walk back to it any time from here."
    }

    /// Save it without opening the app first: a button in Control Center or on the Lock Screen, or an automation that
    /// runs when the phone leaves the car's Bluetooth. Steps in plain words, and a Test run that does the real thing.
    private var autoParkCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Other ways to save it"), systemImage: "bolt.car.fill").font(HandyFont.bodyStrong)
            Text(L("When you leave the car — automatically")).font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.textPrimary)
            autoStep(1, "Open the Shortcuts app and tap Automation, then +.")
            autoStep(2, "Choose CarPlay (or Bluetooth, then your car) and choose Disconnects. Set it to Run Immediately.")
            autoStep(3, "Tap New Blank Automation, search for Tenzy and add Save Where I Parked. Done.")
            Text(L("With a button — Control Center or the Lock Screen")).font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.textPrimary).padding(.top, 4)
            autoStep(1, "Swipe down from the top right, tap +, then Add a Control.")
            autoStep(2, "Search for Tenzy and tap Save where I parked. (On the Lock Screen: touch and hold it, tap Customize, then a button at the bottom.)")
            HStack(spacing: HandySpacing.s8) {
                if let u = URL(string: "shortcuts://") {
                    Button { UIApplication.shared.open(u) } label: { Label(L("Open Shortcuts"), systemImage: "square.on.square") }.compactButton()
                }
                Button {
                    ParkNow.pending = true; savingSince = Date(); savingNow = true; autoNote = nil; gps.start()
                } label: { Label(L("Test run"), systemImage: "play.circle") }
                .compactButton().accessibilityIdentifier("gps-autopark-test")
            }
            Text(L("Test run does exactly what the automation does: saves where you are now.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .cardStyle()
    }

    private func autoStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HandySpacing.s8) {
            Text("\(n)").font(HandyFont.caption.weight(.bold)).foregroundStyle(.white)
                .frame(width: 20, height: 20).background(HandyColor.accent, in: Circle())
            Text(L(text)).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
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
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).padding(12).background(.white.opacity(0.12), in: Circle()) }.accessibilityLabel(L("Close HUD"))
                    Spacer()
                    Button { mirrored.toggle() } label: { Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right").accessibilityLabel(L("Mirror")).font(.system(size: 16, weight: .bold)).padding(12).background(.white.opacity(0.12), in: Circle()) }
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
    /// When the current fix was taken. iPhone's first answer is often a remembered, old one; parking must not use it.
    @Published var fixTime: Date? = nil
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
            self.speed = sp >= 0 ? sp : 0; self.course = co; self.accuracy = acc; self.coordinate = c; self.fixTime = t
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
