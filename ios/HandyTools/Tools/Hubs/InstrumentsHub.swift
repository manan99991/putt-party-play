import SwiftUI
import AVFoundation
import ARKit

/// Instruments — the "instruments" power tool (prototype SCREENS.instruments). Ten tabs over the sensor
/// engines that already exist: Level, Compass, Sound, Light, Altitude and Metal read the live sensors in
/// `Engines/Sensors.swift`, Ruler draws `RulerStrip`, and the last three embed the full Measure (AR),
/// Magnifier+ and GPS Dashboard tools. Without hardware (simulator, UI tests) every gauge shows a sample
/// reading with a one-line note — nothing spins, nothing crashes.
struct InstrumentsHub: View {
    private static let tabs = ["Level", "Compass", "Sound", "Light", "Altitude", "Metal", "Ruler", "Measure (AR)", "Magnifier", "GPS"]
    @State private var tab = 0
    @StateObject private var motion = MotionSensor()
    @StateObject private var heading = HeadingSensor()
    @StateObject private var sound = SoundSensor()
    @StateObject private var light = LightSensor()
    @StateObject private var baro = BarometerSensor()
    @AppStorage("instruments.db.offset") private var dbOffset = 0.0
    @AppStorage("instruments.ruler.cal") private var rulerCal = 1.0
    @AppStorage("instruments.ruler.inches") private var rulerInches = false
    @State private var levelBar = false          // Bubble (false) / Bar (true)
    @State private var zeroed = false
    @State private var soundOn = false
    @State private var calibratingRuler = false
    @State private var altWaited = false

    /// Sensors only run when hardware start-up is allowed (never in the plain `-uitest` smoke run).
    private var live: Bool { Launch.startHardware }
    private var hasMotion: Bool { live && motion.available }
    private var hasCamera: Bool { AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil }

    var body: some View {
        PowerToolPage(id: "instruments", tabs: Self.tabs, selected: $tab) {
            Group {
                switch tab {
                case 0: levelPanel
                case 1: compassPanel
                case 2: soundPanel
                case 3: lightPanel
                case 4: altitudePanel
                case 5: metalPanel
                case 6: rulerPanel
                case 7: measurePanel
                case 8: magnifierPanel
                default: gpsPanel
                }
            }
        }
        .onAppear { switchTo(tab) }
        .onDisappear { stopAll() }
        .onChange(of: tab) { _, t in switchTo(t) }
    }

    // MARK: sensor lifecycle

    private func stopAll() { motion.stop(); heading.stop(); sound.stop(); light.stop(); baro.stop(); soundOn = false }
    private func switchTo(_ t: Int) {
        stopAll()
        guard live else { return }
        switch t {
        case 0: motion.start()
        case 1: heading.start()
        case 3: light.start()
        case 4: baro.start(); heading.start(location: true)
        case 5: motion.start(magnet: true)
        default: break   // Sound starts from its own button; the embedded tools start themselves.
        }
    }

    // MARK: Level

    private var levelPanel: some View {
        let angle = hasMotion ? motion.angle : 0.6
        let isLevel = hasMotion ? motion.level : false
        return VStack(spacing: HandySpacing.s12) {
            levelGauge(isLevel: isLevel)
            Text(String(format: "%.1f°", abs(angle))).font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(isLevel ? HandyColor.success : HandyColor.textPrimary)
            Text(levelSub(isLevel: isLevel)).font(HandyFont.caption).foregroundStyle(isLevel ? HandyColor.success : HandyColor.textSecondary)
            FlowLayout(spacing: 8) {
                HubChip("Bubble", selected: !levelBar) { levelBar = false }
                HubChip("Bar", selected: levelBar) { levelBar = true }
                HubChip("Calibrate", selected: false) { motion.zeroHere(); zeroed = true }
                if zeroed { HubChip("Reset zero", selected: false) { motion.resetZero(); zeroed = false } }
            }
            if zeroed { HubNote("Zeroed to current angle — the surface you're on is now the reference.") }
            if !hasMotion { HubPill("No motion sensor here — sample reading", tone: .native) }
            HubNote("Lay the phone flat on the surface. Calibrate makes a table that isn't quite level the reference. Stand the phone on its edge for a protractor.")
        }
    }

    private func levelSub(isLevel: Bool) -> String {
        guard hasMotion else { return "Lay the phone on the surface" }
        if motion.upright { return "Protractor — angle of the long edge from vertical" }
        if isLevel { return "✓ Level" }
        if abs(motion.y) > abs(motion.x) { return motion.y > 0 ? "Tilted toward you" : "Tilted away" }
        return motion.x > 0 ? "Tilted right" : "Tilted left"
    }

    @ViewBuilder private func levelGauge(isLevel: Bool) -> some View {
        let x = hasMotion ? motion.x : 0.006
        let y = hasMotion ? motion.y : -0.008
        let tint = isLevel ? HandyColor.success : HandyColor.accent
        if levelBar {
            // a spirit-level vial: the bubble slides left/right with the side-to-side tilt
            ZStack {
                Capsule().fill(HandyColor.surface).overlay(Capsule().stroke(HandyColor.border, lineWidth: 2))
                HStack(spacing: 40) { Rectangle().fill(HandyColor.border).frame(width: 2, height: 56); Rectangle().fill(HandyColor.border).frame(width: 2, height: 56) }
                Circle().fill(tint).frame(width: 40, height: 40).offset(x: CGFloat(max(-1, min(1, x))) * 130)
                    .animation(.easeOut(duration: 0.08), value: x)
            }
            .frame(height: 56).frame(maxWidth: .infinity).padding(.vertical, 60)
        } else if hasMotion && motion.upright {
            ZStack {
                Circle().trim(from: 0.5, to: 1).stroke(HandyColor.border, lineWidth: 2).frame(width: 260, height: 260).offset(y: 65)
                ForEach([-90, -60, -45, -30, 0, 30, 45, 60, 90], id: \.self) { d in
                    Rectangle().fill(d == 0 ? HandyColor.accent : HandyColor.textSecondary).frame(width: d % 45 == 0 ? 3 : 1, height: 14)
                        .offset(y: -122).rotationEffect(.degrees(Double(d))).offset(y: 65)
                }
                Rectangle().fill(tint).frame(width: 3, height: 120).offset(y: -60).rotationEffect(.degrees(motion.angle)).offset(y: 65)
                    .animation(.easeOut(duration: 0.08), value: motion.angle)
            }
            .frame(height: 260).frame(maxWidth: .infinity)
        } else {
            ZStack {
                Circle().stroke(HandyColor.border, lineWidth: 2).frame(width: 240, height: 240)
                Circle().stroke(HandyColor.border.opacity(0.5), lineWidth: 1).frame(width: 84, height: 84)
                Rectangle().fill(HandyColor.border.opacity(0.5)).frame(width: 240, height: 1)
                Rectangle().fill(HandyColor.border.opacity(0.5)).frame(width: 1, height: 240)
                Circle().fill(tint).frame(width: 56, height: 56)
                    .offset(x: CGFloat(max(-1, min(1, x))) * 110, y: CGFloat(max(-1, min(1, y))) * 110)
                    .animation(.easeOut(duration: 0.08), value: x)
            }
            .frame(height: 260).frame(maxWidth: .infinity)
        }
    }

    // MARK: Compass

    private var compassPanel: some View {
        let hasHeading = live && heading.available
        let deg = hasHeading ? heading.trueHeading : 312
        return VStack(spacing: HandySpacing.s12) {
            ZStack {
                Circle().stroke(HandyColor.border, lineWidth: 3)
                ForEach(0..<72, id: \.self) { i in
                    Rectangle().fill(i % 18 == 0 ? HandyColor.textPrimary : HandyColor.textSecondary.opacity(i % 6 == 0 ? 0.9 : 0.4))
                        .frame(width: i % 18 == 0 ? 3 : 1, height: i % 18 == 0 ? 18 : (i % 6 == 0 ? 12 : 7))
                        .offset(y: -118).rotationEffect(.degrees(Double(i) * 5))
                }
                ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { i, s in
                    Text(s).font(HandyFont.bodyStrong).foregroundStyle(s == "N" ? HandyColor.danger : HandyColor.textPrimary)
                        .offset(y: -92).rotationEffect(.degrees(Double(i) * 90))
                }
            }
            .frame(width: 270, height: 270)
            .rotationEffect(.degrees(-deg))
            .animation(.easeOut(duration: 0.15), value: deg)
            .overlay(alignment: .top) { Rectangle().fill(HandyColor.accent).frame(width: 3, height: 28).offset(y: 4) }
            .frame(maxWidth: .infinity).padding(.top, HandySpacing.s8)
            Text("\(Int(deg.rounded()) % 360)° \(SensorMath.cardinal(deg))").font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
            Text(hasHeading && heading.magnetic != heading.trueHeading ? "true heading" : "magnetic heading").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HStack {
                stat("True", "\(Int(deg.rounded()) % 360)°")
                stat("Magnetic", hasHeading ? "\(Int(heading.magnetic.rounded()) % 360)°" : "312°")
                stat("Accuracy", hasHeading && heading.accuracy >= 0 ? "±\(Int(heading.accuracy))°" : "—")
            }
            if hasHeading && heading.accuracy > 25 { Text("Wave the phone in a figure‑8 to calibrate.").font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
            if !hasHeading { HubPill(live ? "No compass here, or location is off (needed for true north) — sample reading" : "No compass sensor here — sample reading", tone: .native) }
            HubNote("Hold the phone flat and away from magnets and metal. Allow location once for true north instead of magnetic north.")
        }
    }

    // MARK: Sound

    private var soundPanel: some View {
        let db = sound.db
        let has = soundOn && db > 0
        return VStack(spacing: HandySpacing.s12) {
            (Text(has ? "\(Int(db))" : "—").font(.system(size: 72, weight: .bold, design: .rounded)).foregroundStyle(has ? dbColor(db) : HandyColor.textPrimary)
                + Text(" dB").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)).monospacedDigit()
            Text(has ? SensorMath.dbLabel(db) : "dB (approx.)").font(HandyFont.bodyStrong).foregroundStyle(has ? dbColor(db) : HandyColor.textSecondary)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(HandyColor.border.opacity(0.5))
                    Capsule().fill(dbColor(db)).frame(width: g.size.width * CGFloat(has ? min(1, max(0, db / 120)) : 0))
                }
            }
            .frame(height: 10).animation(.easeOut(duration: 0.1), value: db)
            HStack { stat("Peak", has ? "\(Int(sound.peak)) dB" : "—"); stat("Average", has ? "\(Int(sound.average)) dB" : "—"); stat("Samples", "\(sound.history.count / 10)s") }
            VStack(alignment: .leading, spacing: 4) {
                ForEach([("Quiet room", "30–40", false), ("Conversation", "60", false), ("Traffic", "80", false), ("Harmful over time", "85+", true)], id: \.0) { r in
                    HStack { Text(r.0).font(HandyFont.caption); Spacer(); Text(r.1).font(HandyFont.caption).monospacedDigit().foregroundStyle(r.2 ? HandyColor.danger : HandyColor.textSecondary) }
                }
            }.cardStyle(padding: HandySpacing.s12)
            Button { toggleSound() } label: { Label(soundOn ? "Stop" : "Start measuring", systemImage: soundOn ? "stop.fill" : "mic.fill").frame(maxWidth: .infinity) }.primaryButton()
            HStack(spacing: HandySpacing.s8) {
                Button { sound.reset() } label: { Label("Reset", systemImage: "arrow.counterclockwise") }.compactButton()
                Spacer()
                Text("Calibrate").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Stepper("\(dbOffset >= 0 ? "+" : "")\(Int(dbOffset)) dB", value: $dbOffset, in: -20...20).font(HandyFont.caption).fixedSize()
            }
            if sound.denied { LimitNote("Microphone access is off. Allow it in Settings to measure sound.") }
            HubNote("Phone mics aren't lab meters — treat it as ±5 dB. If you have a real meter, set the offset so they match.")
        }
    }

    private func toggleSound() {
        if soundOn { sound.stop(); soundOn = false } else { sound.reset(); sound.start(); soundOn = true }
        HandyHaptics.light()
    }
    private func dbColor(_ db: Double) -> Color { db < 70 ? HandyColor.success : db < 85 ? HandyColor.amber : HandyColor.danger }

    // MARK: Light

    private var lightPanel: some View {
        let lux = light.lux
        let has = live && lux > 0
        return VStack(spacing: HandySpacing.s12) {
            HubPill("Uses the camera to estimate light", tone: .native)
            (Text(has ? (lux < 100 ? String(format: "%.0f", lux) : lux < 10_000 ? "\(Int(lux / 10) * 10)" : "\(Int(lux / 100) * 100)") : "—")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                + Text(" lux").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)).monospacedDigit()
            Text(has ? SensorMath.luxLabel(lux) : (hasCamera && live ? "Point the back camera at the surface" : "No camera here — nothing to read")).font(HandyFont.bodyStrong).foregroundStyle(has ? HandyColor.textPrimary : HandyColor.textSecondary)
            VStack(alignment: .leading, spacing: 4) {
                ForEach([("Reading light", "300–500"), ("Office", "500"), ("Overcast day", "1,000"), ("Plants: bright indirect", "1,000–2,500")], id: \.0) { r in
                    HStack { Text(r.0).font(HandyFont.caption); Spacer(); Text(r.1).font(HandyFont.caption).monospacedDigit().foregroundStyle(HandyColor.textSecondary) }
                }
            }.cardStyle(padding: HandySpacing.s12)
            HubNote("iPhones have no app-readable light sensor, so this reads the back camera's exposure. Approximate (±30%) — fine for plants, desks and rooms.")
        }
    }

    // MARK: Altitude

    private var altitudePanel: some View {
        let alt: Double? = live ? heading.altitude : 214
        return VStack(spacing: HandySpacing.s12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(alt.map { String(format: "%.0f", $0) } ?? "—").font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                Text("m above sea level").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
            }
            Text(altitudeSub(alt)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HStack {
                stat("Pressure", baro.pressureKPa.map { String(format: "%.1f hPa", $0 * 10) } ?? "—")
                stat("Climbed", String(format: "%+.1f m", baro.relativeMetres))
                stat("GPS ±", alt != nil && live ? String(format: "%.0f m", heading.altitudeAccuracy) : "—")
            }
            HStack(spacing: HandySpacing.s8) {
                Button { baro.reset(); HandyHaptics.light() } label: { Label("Set reference", systemImage: "scope") }.compactButton()
                Spacer()
            }
            if !live { HubPill("No GPS or barometer here — sample reading", tone: .native) }
            if live && !baro.available { LimitNote("No barometer on this device — GPS altitude only.") }
            HubNote("GPS gives the absolute number; the barometer tracks floors and hills to ±1 m from where you set the reference. Pressure falling fast = weather coming.")
        }
        .onAppear { altWaited = false }
        .task { try? await Task.sleep(for: .seconds(10)); altWaited = true }
    }

    private func altitudeSub(_ alt: Double?) -> String {
        if !live { return "Sample reading — sensors are off in this preview" }
        if let a = alt { return String(format: "%.0f ft · GPS ±%.0f m", a * 3.28084, heading.altitudeAccuracy) }
        return altWaited ? "No fix yet — step outside or near a window" : "Getting fix…"
    }

    // MARK: Metal

    private var metalPanel: some View {
        let field = hasMotion ? motion.field : 48
        let score = hasMotion ? motion.metalScore : 0.16
        return VStack(spacing: HandySpacing.s12) {
            ZStack {
                Circle().stroke(HandyColor.border, lineWidth: 10).frame(width: 220, height: 220)
                Circle().trim(from: 0, to: score).stroke(score > 0.5 ? HandyColor.danger : HandyColor.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 220, height: 220).rotationEffect(.degrees(-90)).animation(.easeOut(duration: 0.1), value: score)
                VStack(spacing: 2) {
                    Text("\(Int(field))").font(.system(size: 56, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("µT").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                }
            }.frame(maxWidth: .infinity).padding(.top, HandySpacing.s8)
            Text(score > 0.6 ? "Strong — magnet or steel right here" : score > 0.2 ? "Something ferrous nearby" : "Ambient field").font(HandyFont.bodyStrong)
            Text("move the phone near metal — the needle jumps").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HStack(spacing: HandySpacing.s8) {
                Button { motion.calibrateMagnet() } label: { Label("Set baseline here", systemImage: "scope") }.compactButton()
                Spacer()
            }
            if !hasMotion { HubPill("No magnetometer here — sample reading", tone: .native) }
            HubNote("Sweep slowly near the wall to find studs' screws, nails, pipes and wiring boxes. Keep it away from your case's magnets; the sensor sits near the top of the phone.")
        }
    }

    // MARK: Ruler

    private var rulerPanel: some View {
        let ppm = SensorMath.pointsPerMM(nativeScale: UIScreen.main.nativeScale, calibration: rulerCal)
        return VStack(spacing: HandySpacing.s12) {
            RulerStrip(pointsPerMM: ppm, inches: rulerInches)
                .frame(height: 120)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            FlowLayout(spacing: 8) {
                HubChip("cm", selected: !rulerInches) { rulerInches = false }
                HubChip("inches", selected: rulerInches) { rulerInches = true }
                HubChip("Calibrate with a card", selected: calibratingRuler) { calibratingRuler.toggle() }
            }
            if calibratingRuler {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text("Hold a bank card against the screen and slide until the bar matches its width (85.6 mm).").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    // A real bank card is wider than most phone screens — keep the bar in a scroller so it never widens the page.
                    ScrollView(.horizontal, showsIndicators: false) {
                        Rectangle().fill(HandyColor.accentSoft).frame(width: 85.6 * ppm, height: 28)
                            .overlay(Text("bank card width").font(HandyFont.micro).foregroundStyle(HandyColor.accent))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Slider(value: $rulerCal, in: 0.85...1.15).tint(HandyColor.accent)
                    HStack { Button("Reset calibration") { rulerCal = 1 }.textButton(); Spacer(); Button("Done") { calibratingRuler = false }.textButton() }
                }.frame(maxWidth: .infinity).cardStyle(padding: HandySpacing.s12)
            }
            HubNote(rulerCal == 1 ? "Calibrated to this screen's pixel density." : String(format: "Calibrated by you (×%.3f).", rulerCal))
        }
    }

    // MARK: embedded tools

    @ViewBuilder private var measurePanel: some View {
        if ARWorldTrackingConfiguration.isSupported {
            MeasureARView().environment(\.embeddedInHub, true)
        } else {
            HubPill("Needs a real iPhone — the AR tape maps the room with the camera", tone: .native)
            HubPreviewBox(minHeight: 200) {
                VStack(spacing: HandySpacing.s8) {
                    Image(systemName: "ruler").font(.system(size: 30)).foregroundStyle(HandyColor.textSecondary)
                    Text("Tap to place points on real surfaces — distance, area or height from the floor.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center).padding(.horizontal, HandySpacing.s16)
                }
            }
            Button { tab = 6 } label: { Label("Use the on-screen ruler instead", systemImage: "ruler").frame(maxWidth: .infinity) }.secondaryButton()
        }
    }

    @ViewBuilder private var magnifierPanel: some View {
        if !hasCamera { HubPill("Needs the camera — runs on a real iPhone", tone: .native) }
        MagnifierView().environment(\.embeddedInHub, true)
    }

    @ViewBuilder private var gpsPanel: some View {
        if !live { HubPill("No GPS here — runs on a real iPhone", tone: .native) }
        GPSDashboardView().environment(\.embeddedInHub, true)
    }

    // MARK: bits

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(spacing: 2) { Text(v).font(HandyFont.bodyStrong).monospacedDigit(); Text(k).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }.frame(maxWidth: .infinity)
    }
}
