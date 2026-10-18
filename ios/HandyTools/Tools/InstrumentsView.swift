import SwiftUI
import CoreLocation

/// Instruments — the sensors the phone already has, exposed as proper instruments: a bubble level
/// and protractor you can zero, a compass with true north, a sound meter with peak/average and a
/// trace, a light meter in lux, a barometer/altimeter, a metal detector, and an on-screen ruler you
/// can calibrate with a bank card. No ads mid-reading, no per-instrument apps.
struct InstrumentsView: View {
    private enum Kind: Int, CaseIterable { case level, compass, sound, light, altitude, magnet, ruler
        var title: String { ["Level", "Compass", "Sound", "Light", "Altitude", "Metal", "Ruler"][rawValue] }
        var icon: String { ["level", "location.north.circle", "waveform", "sun.max", "mountain.2", "magnet", "ruler"][rawValue] } }

    @State private var kind: Kind = .level
    @StateObject private var motion = MotionSensor()
    @StateObject private var heading = HeadingSensor()
    @StateObject private var sound = SoundSensor()
    @StateObject private var light = LightSensor()
    @StateObject private var baro = BarometerSensor()
    @AppStorage("instruments.db.offset") private var dbOffset = 0.0
    @AppStorage("instruments.ruler.cal") private var rulerCal = 1.0
    @AppStorage("instruments.ruler.inches") private var rulerInches = false
    @State private var holdAngle: Double?

    var body: some View {
        ToolPage(title: "Instruments", subtitle: "Level, compass, sound, light, altitude, metal and a ruler — the sensors you already own, done properly.") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HandySpacing.s8) {
                    ForEach(Kind.allCases, id: \.rawValue) { k in HChip(text: k.title, selected: kind == k) { switchTo(k) } }
                }
            }
            switch kind {
            case .level: levelPanel
            case .compass: compassPanel
            case .sound: soundPanel
            case .light: lightPanel
            case .altitude: altitudePanel
            case .magnet: magnetPanel
            case .ruler: rulerPanel
            }
        }
        .onAppear { switchTo(kind, force: true) }
        .onDisappear { stopAll() }
    }

    private func stopAll() { motion.stop(); heading.stop(); sound.stop(); light.stop(); baro.stop() }
    private func switchTo(_ k: Kind, force: Bool = false) {
        guard force || k != kind else { return }
        stopAll(); kind = k; holdAngle = nil
        switch k {
        case .level: motion.start()
        case .compass: heading.start()
        case .sound: sound.reset(); sound.start()
        case .light: light.start()
        case .altitude: baro.start(); heading.start(location: true)
        case .magnet: motion.start(magnet: true)
        case .ruler: break
        }
    }

    // MARK: level / protractor

    private var levelPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            let shown = holdAngle ?? motion.angle
            ZStack {
                if motion.upright {
                    // standing on an edge: a protractor arc with the needle at the tilt angle
                    Circle().trim(from: 0.5, to: 1).stroke(HandyColor.border, lineWidth: 2).frame(width: 260, height: 260).offset(y: 65)
                    ForEach([-90, -60, -45, -30, 0, 30, 45, 60, 90], id: \.self) { d in
                        Rectangle().fill(d == 0 ? HandyColor.accent : HandyColor.textSecondary).frame(width: d % 45 == 0 ? 3 : 1, height: 14)
                            .offset(y: -122).rotationEffect(.degrees(Double(d))).offset(y: 65)
                    }
                    Rectangle().fill(motion.level ? HandyColor.success : HandyColor.accent).frame(width: 3, height: 120)
                        .offset(y: -60).rotationEffect(.degrees(shown)).offset(y: 65)
                        .animation(.easeOut(duration: 0.08), value: shown)
                } else {
                    Circle().stroke(HandyColor.border, lineWidth: 2).frame(width: 260, height: 260)
                    Circle().stroke(HandyColor.border.opacity(0.5), lineWidth: 1).frame(width: 90, height: 90)
                    Rectangle().fill(HandyColor.border.opacity(0.5)).frame(width: 260, height: 1)
                    Rectangle().fill(HandyColor.border.opacity(0.5)).frame(width: 1, height: 260)
                    Circle().fill(motion.level ? HandyColor.success : HandyColor.accent)
                        .frame(width: 60, height: 60)
                        .offset(x: CGFloat(motion.x) * 120, y: CGFloat(motion.y) * 120)
                        .animation(.easeOut(duration: 0.08), value: motion.x)
                }
            }
            .frame(height: 280).frame(maxWidth: .infinity)
            Text(String(format: "%.1f°", abs(shown))).font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(motion.level ? HandyColor.success : HandyColor.textPrimary)
            Text(motion.upright ? "Protractor — angle of the long edge from vertical" : (motion.level ? "Level" : "Tilt from level")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HStack(spacing: HandySpacing.s8) {
                Button { motion.zeroHere() } label: { Label("Zero here", systemImage: "scope") }.compactButton()
                Button { motion.resetZero() } label: { Label("Reset", systemImage: "arrow.counterclockwise") }.compactButton()
                Button { holdAngle = holdAngle == nil ? motion.angle : nil } label: { Label(holdAngle == nil ? "Hold" : "Release", systemImage: holdAngle == nil ? "pause.fill" : "play.fill") }.compactButton()
            }
            if !motion.available { LimitNote("Motion sensors aren't available on this device.") }
            Text("Zero here makes the surface you're on the reference — handy when the table itself isn't level. Stand the phone on its edge for a protractor.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    // MARK: compass

    private var compassPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            ZStack {
                Circle().stroke(HandyColor.border, lineWidth: 2)
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
            .rotationEffect(.degrees(-heading.trueHeading))
            .animation(.easeOut(duration: 0.15), value: heading.trueHeading)
            .overlay(alignment: .top) { Image(systemName: "arrowtriangle.down.fill").font(.system(size: 18)).foregroundStyle(HandyColor.accent).offset(y: -14) }
            .overlay {
                VStack(spacing: 0) {
                    Text("\(Int(heading.trueHeading.rounded()) % 360)°").font(.system(size: 50, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(SensorMath.cardinal(heading.trueHeading)).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity).padding(.top, HandySpacing.s8)
            HStack {
                stat("True", "\(Int(heading.trueHeading.rounded()) % 360)°")
                stat("Magnetic", "\(Int(heading.magnetic.rounded()) % 360)°")
                stat("Accuracy", heading.accuracy < 0 ? "—" : "±\(Int(heading.accuracy))°")
            }
            if !heading.available { LimitNote("No compass hardware, or location access is off (needed for true north).") }
            if heading.accuracy > 25 { Text("Wave the phone in a figure‑8 to calibrate.").font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
        }
    }

    // MARK: sound

    private var soundPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            Text("\(Int(sound.db))").font(.system(size: 72, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(dbColor(sound.db))
                + Text(" dB").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
            Text(SensorMath.dbLabel(sound.db)).font(HandyFont.bodyStrong).foregroundStyle(dbColor(sound.db))
            trace(sound.history, range: 20...110).frame(height: 90)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            HStack { stat("Peak", "\(Int(sound.peak)) dB"); stat("Average", "\(Int(sound.average)) dB"); stat("Samples", "\(sound.history.count / 10)s") }
            HStack(spacing: HandySpacing.s8) {
                Button { sound.reset() } label: { Label("Reset", systemImage: "arrow.counterclockwise") }.compactButton()
                Spacer()
                Text("Calibrate").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Stepper("\(dbOffset >= 0 ? "+" : "")\(Int(dbOffset)) dB", value: $dbOffset, in: -20...20).font(HandyFont.caption).fixedSize()
            }
            if sound.denied { LimitNote("Microphone access is off. Allow it in Settings to measure sound.") }
            Text("Phone mics aren't lab meters — treat it as ±5 dB. If you have a real meter, set the offset so they match.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func dbColor(_ db: Double) -> Color { db < 70 ? HandyColor.success : db < 85 ? HandyColor.accent : HandyColor.danger }

    // MARK: light

    private var lightPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            Text(light.lux < 100 ? String(format: "%.0f", light.lux) : light.lux < 10_000 ? "\(Int(light.lux / 10) * 10)" : "\(Int(light.lux / 100) * 100)")
                .font(.system(size: 72, weight: .bold, design: .rounded)).monospacedDigit()
                + Text(" lux").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
            Text(SensorMath.luxLabel(light.lux)).font(HandyFont.bodyStrong)
            VStack(alignment: .leading, spacing: 4) {
                ForEach([("Reading / desk work", "300–500"), ("Plants: low light", "50–250"), ("Plants: bright indirect", "1,000–2,500"), ("Photography: EV check", "—")], id: \.0) { r in
                    HStack { Text(r.0).font(HandyFont.caption); Spacer(); Text(r.1).font(HandyFont.caption).monospacedDigit().foregroundStyle(HandyColor.textSecondary) }
                }
            }.cardStyle(padding: HandySpacing.s12)
            Text("Reads the back camera's exposure — point it at the surface you care about. Approximate (±30%), fine for plants, desks and rooms.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    // MARK: altitude / barometer

    private var altitudePanel: some View {
        VStack(spacing: HandySpacing.s12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(heading.altitude.map { String(format: "%.0f", $0) } ?? "—").font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                Text("m above sea level").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
            }
            if let a = heading.altitude { Text(String(format: "%.0f ft · GPS ±%.0f m", a * 3.28084, heading.altitudeAccuracy)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            HStack {
                stat("Pressure", baro.pressureKPa.map { String(format: "%.1f hPa", $0 * 10) } ?? "—")
                stat("Climbed", String(format: "%+.1f m", baro.relativeMetres))
                stat("", "")
            }
            HStack(spacing: HandySpacing.s8) {
                Button { baro.reset() } label: { Label("Reset climb", systemImage: "arrow.counterclockwise") }.compactButton()
                Spacer()
            }
            if !baro.available { LimitNote("No barometer on this device — GPS altitude only.") }
            Text("Barometer tracks floors and hills precisely (±1 m relative); GPS gives the absolute number. Pressure trend falling fast = weather coming.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    // MARK: magnet

    private var magnetPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            ZStack {
                Circle().stroke(HandyColor.border, lineWidth: 10).frame(width: 220, height: 220)
                Circle().trim(from: 0, to: motion.metalScore).stroke(motion.metalScore > 0.5 ? HandyColor.danger : HandyColor.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 220, height: 220).rotationEffect(.degrees(-90)).animation(.easeOut(duration: 0.1), value: motion.metalScore)
                VStack(spacing: 2) {
                    Text("\(Int(motion.field))").font(.system(size: 56, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("µT").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                }
            }.padding(.top, HandySpacing.s8)
            Text(motion.metalScore > 0.6 ? "Strong — magnet or steel right here" : motion.metalScore > 0.2 ? "Something ferrous nearby" : "Ambient field").font(HandyFont.bodyStrong)
            HStack(spacing: HandySpacing.s8) {
                Button { motion.calibrateMagnet() } label: { Label("Set baseline here", systemImage: "scope") }.compactButton()
                Spacer()
            }
            Text("Sweep slowly near the wall to find studs' screws, nails, pipes and wiring boxes. Keep it away from your case's magnets. The sensor sits near the top of the phone.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    // MARK: ruler

    private var rulerPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            RulerStrip(pointsPerMM: SensorMath.pointsPerMM(nativeScale: UIScreen.main.nativeScale, calibration: rulerCal), inches: rulerInches)
                .frame(height: 110)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            Picker("Units", selection: $rulerInches) { Text("cm").tag(false); Text("inches").tag(true) }.pickerStyle(.segmented).frame(width: 180)
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text("Calibrate: lay a bank card along the top edge and slide until its width reads 85.6 mm.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Rectangle().fill(HandyColor.accentSoft).frame(width: 85.6 * SensorMath.pointsPerMM(nativeScale: UIScreen.main.nativeScale, calibration: rulerCal), height: 28)
                    .overlay(Text("bank card width").font(HandyFont.micro).foregroundStyle(HandyColor.accent))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: $rulerCal, in: 0.85...1.15).tint(HandyColor.accent)
                HStack { Button("Reset calibration") { rulerCal = 1 }.textButton(); Spacer() }
            }.cardStyle(padding: HandySpacing.s12)
        }
    }

    // MARK: bits

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(spacing: 2) { Text(v).font(HandyFont.bodyStrong).monospacedDigit(); Text(k).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }.frame(maxWidth: .infinity)
    }

    private func trace(_ values: [Double], range: ClosedRange<Double>) -> some View {
        GeometryReader { geo in
            Path { p in
                guard values.count > 1 else { return }
                let w = geo.size.width, h = geo.size.height
                let n = max(300, values.count)
                for (i, v) in values.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(n - 1)
                    let y = h - h * CGFloat((min(max(v, range.lowerBound), range.upperBound) - range.lowerBound) / (range.upperBound - range.lowerBound))
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }.stroke(HandyColor.accent, lineWidth: 2)
        }
    }
}

/// A physical-size ruler drawn with true millimetre (or 1/16") ticks along the top edge.
struct RulerStrip: View {
    let pointsPerMM: Double
    let inches: Bool
    var body: some View {
        GeometryReader { geo in
            let unit = inches ? pointsPerMM * 25.4 / 16 : pointsPerMM   // one tick = 1/16 in or 1 mm
            let count = Int(geo.size.width / unit)
            ZStack(alignment: .topLeading) {
                ForEach(0...count, id: \.self) { i in
                    let major = inches ? i % 16 == 0 : i % 10 == 0
                    let mid = inches ? i % 8 == 0 : i % 5 == 0
                    Rectangle().fill(HandyColor.textPrimary).frame(width: major ? 2 : 1, height: major ? 34 : mid ? 22 : 12)
                        .offset(x: CGFloat(Double(i) * unit))
                    if major, i > 0 {
                        Text(inches ? "\(i / 16)" : "\(i / 10)").font(HandyFont.caption).monospacedDigit()
                            .offset(x: CGFloat(Double(i) * unit) + 4, y: 38)
                    }
                }
                Text(inches ? "in" : "cm").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).offset(x: 4, y: 80)
            }
        }
        .clipped()
    }
}
