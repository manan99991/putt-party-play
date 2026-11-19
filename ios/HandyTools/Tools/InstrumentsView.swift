import SwiftUI
import CoreLocation
import AudioToolbox
import UserNotifications

/// Instruments — the sensors the phone already has, exposed as proper instruments: a bubble level
/// and protractor you can zero, a compass with true north, a sound meter with peak/average and a
/// trace, a light meter in lux, a barometer/altimeter, a metal detector, and an on-screen ruler you
/// can calibrate with a bank card. No ads mid-reading, no per-instrument apps.
struct InstrumentsView: View {
    private enum Kind: Int, CaseIterable { case level, compass, sound, light, altitude, magnet, ruler
        var title: String { ["Level", "Compass", "Sound", "Light", "Altitude", "Metal", "Ruler"][rawValue] }
        var icon: String { ["level", "location.north.circle", "waveform", "sun.max", "mountain.2", "magnet", "ruler"][rawValue] } }

    /// What people actually come here to do; each opens the right gauge with a purpose, a verdict and alerts.
    private enum Job: Int, CaseIterable, Identifiable {
        case straight, loud, light, stud, direction, ruler
        var id: Int { rawValue }
        var title: String { ["Hang something straight", "Is it too loud?", "Light for a plant or desk", "Find a stud or pipe", "Which way is it?", "Small ruler"][rawValue] }
        var line: String { ["Pictures, shelves, a wobbly table — beeps when it's level", "Safe listening time, warnings and a noise log", "Which plants will thrive in this spot", "Buzzes over screws, nails and pipes before you drill", "Sun direction, Qibla, and how high you are", "Measure something small on the screen"][rawValue] }
        var icon: String { ["level", "ear.badge.waveform", "leaf", "magnet", "location.north.circle", "ruler"][rawValue] }
        var gauge: Kind { [.level, .sound, .light, .magnet, .compass, .ruler][rawValue] }
    }
    @State private var job: Job?
    @AppStorage("instruments.beep") private var beep = true
    @AppStorage("instruments.loudAlert") private var loudAlert = true
    @State private var wasLevel = false
    @State private var lightSamples: [Double] = []
    @State private var lightResult: Double?
    @State private var studPeak = 0.0
    @State private var faced = false
    @State private var warnedLoud = false

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
            if let job {
                HStack {
                    Label(L(job.title), systemImage: job.icon).font(HandyFont.bodyStrong)
                    Spacer()
                    Button { stopAll(); self.job = nil } label: { Label(L("Change"), systemImage: "chevron.left") }.textButton()
                }
                switch job {
                case .straight: levelPanel
                case .loud: soundPanel
                case .light: lightPanel
                case .stud: magnetPanel
                case .direction: compassPanel; altitudePanel
                case .ruler: rulerPanel
                }
            } else {
                Text(L("What do you need?")).font(HandyFont.cardTitle)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: HandySpacing.s12), GridItem(.flexible(), spacing: HandySpacing.s12)], spacing: HandySpacing.s12) {
                    ForEach(Job.allCases) { j in
                        Button { open(j) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: j.icon).font(.system(size: 24, weight: .semibold)).foregroundStyle(HandyColor.accent)
                                Text(L(j.title)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                                Text(L(j.line)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                            .multilineTextAlignment(.leading)
                            .cardStyle(padding: HandySpacing.s12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("instrument-\(j.rawValue)")
                    }
                }
            }
        }
        .onAppear { if Launch.startHardware, let job { open(job) } }
        .onDisappear { stopAll() }
        // Alerts that come to you, so you don't have to stare at the needle:
        .onChange(of: motion.level) { _, now in levelAlert(now) }
        .onChange(of: sound.loudFor) { _, s in loudWarning(s) }
        .onChange(of: motion.metalScore) { _, v in studBuzz(v) }
        .onChange(of: heading.trueHeading) { _, h in facingAlert(h) }
        .onChange(of: light.lux) { _, v in if lightResult == nil, job == .light, lightSamples.count < 40 { lightSamples.append(v); if lightSamples.count == 40 { lightResult = lightSamples.reduce(0, +) / 40; HandyHaptics.success() } } }
    }

    private func open(_ j: Job) {
        job = j; lightSamples = []; lightResult = nil; studPeak = 0; warnedLoud = false; wasLevel = false
        switchTo(j.gauge, force: true)
        if j == .direction { heading.start(location: true); baro.start() }
    }

    // MARK: alerts

    /// A tick and a tap the moment it's level, so you can keep your eyes on the picture, not the phone.
    private func levelAlert(_ now: Bool) {
        guard job == .straight, now != wasLevel else { return }
        wasLevel = now
        if now { HandyHaptics.success(); if beep { AudioServicesPlaySystemSound(1057) } }
    }

    /// Too loud for long enough: a warning buzz on the spot, and a notification after a minute in case the
    /// phone is in a pocket at a concert.
    private func loudWarning(_ secs: Double) {
        guard job == .loud, loudAlert else { return }
        if secs >= 10, secs < 10.15 { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        if secs >= 60, !warnedLoud {
            warnedLoud = true
            let c = UNMutableNotificationContent()
            c.title = L("It's too loud here")
            c.body = "\(Int(sound.db)) dB · \(L(SensorMath.safeText(sound.db))). \(L("Step away from the source or use earplugs."))"
            c.sound = .default
            Task { if await NotifyPermission.ensure() { try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "instruments.loud", content: c, trigger: nil)) } }
        }
    }

    /// Stronger and stronger buzzes as you sweep over metal, and a firm one at the strongest point.
    private func studBuzz(_ v: Double) {
        guard job == .stud else { return }
        if v > studPeak + 0.05, v > 0.25 { studPeak = v; UIImpactFeedbackGenerator(style: v > 0.6 ? .heavy : .medium).impactOccurred() }
    }

    private func facingAlert(_ h: Double) {
        guard job == .direction, let c = heading.coordinate else { return }
        let on = abs(SensorMath.turn(from: h, to: SensorMath.qibla(lat: c.latitude, lon: c.longitude))) < 3
        if on && !faced { HandyHaptics.success() }
        faced = on
    }

    private func remindLightCheck() {
        let c = UNMutableNotificationContent()
        c.title = L("Check that plant spot again")
        c.body = L("Light changes through the day. Open Tenzy › Instruments › Light for a plant to measure the same spot now.")
        Task {
            guard await NotifyPermission.ensure() else { return }
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "instruments.light", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 4 * 3600, repeats: false)))
            await MainActor.run { CopyToast.shared.flash(L("Reminder set for 4 hours from now")) }
        }
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
            let raw = holdAngle ?? motion.angle
            let sq = SensorMath.offSquare(raw)
            let shown = motion.upright ? sq.off : raw
            ZStack {
                if motion.upright {
                    // standing on an edge: a protractor arc with the needle at the tilt angle
                    Circle().trim(from: 0.5, to: 1).stroke(HandyColor.border, lineWidth: 2).frame(width: 260, height: 260).offset(y: 65)
                    ForEach([-90, -60, -45, -30, 0, 30, 45, 60, 90], id: \.self) { d in
                        Rectangle().fill(d == 0 ? HandyColor.accent : HandyColor.textSecondary).frame(width: d % 45 == 0 ? 3 : 1, height: 14)
                            .offset(y: -122).rotationEffect(.degrees(Double(d))).offset(y: 65)
                    }
                    Rectangle().fill(abs(shown) < 0.3 ? HandyColor.success : HandyColor.accent).frame(width: 3, height: 120)
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
                .foregroundStyle(abs(shown) < 0.3 ? HandyColor.success : HandyColor.textPrimary)
            let isLevel = abs(shown) < 0.3
            Text(L(isLevel ? (motion.upright && !sq.level ? "Straight up and down" : "Level") : (motion.upright ? (sq.level ? "Off level" : "Off straight up") : "Tilt from flat")))
                .font(HandyFont.bodyStrong).foregroundStyle(isLevel ? HandyColor.success : HandyColor.textSecondary)
            if !isLevel {
                let sl = SensorMath.slope(degrees: shown)
                Text("\(L("One end is")) \(Int(sl.mm.rounded())) mm \(L("out over 50 cm")) · \(String(format: "%.1f", sl.percent))%\(sl.oneIn.map { " · 1 \(L("in")) \($0)" } ?? "")")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            }
            Toggle(L("Beep when it's level"), isOn: $beep).font(HandyFont.caption).tint(HandyColor.accent)
            Text(L("For a picture or a shelf: hold the phone's long edge along its top. For a table: lay the phone flat.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            HStack(spacing: HandySpacing.s8) {
                Button { motion.zeroHere() } label: { Label(L("Zero here"), systemImage: "scope") }.compactButton()
                Button { motion.resetZero() } label: { Label(L("Reset"), systemImage: "arrow.counterclockwise") }.compactButton()
                Button { holdAngle = holdAngle == nil ? motion.angle : nil } label: { Label(holdAngle == nil ? "Hold" : "Release", systemImage: holdAngle == nil ? "pause.fill" : "play.fill") }.compactButton()
            }
            if !motion.available { LimitNote("Motion sensors aren't available on this device.") }
            Text(L("Zero here makes the surface you're on the reference — handy when the table itself isn't level. Stand the phone on its edge for a protractor."))
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
            if heading.accuracy > 25 { Text(L("Wave the phone in a figure‑8 to calibrate.")).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
            VStack(alignment: .leading, spacing: 6) {
                Label(L(SensorMath.sunText(heading.trueHeading, southernHemisphere: (heading.coordinate?.latitude ?? 1) < 0)), systemImage: "sun.max.fill")
                    .font(HandyFont.body).fixedSize(horizontal: false, vertical: true)
                Text(L("Stand with your back to the window and the phone flat: that's the way the window faces.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                if let c = heading.coordinate {
                    let q = SensorMath.qibla(lat: c.latitude, lon: c.longitude)
                    let t = SensorMath.turn(from: heading.trueHeading, to: q)
                    Label(abs(t) < 3 ? L("Facing the Qibla") : "\(L("Qibla")): \(Int(q.rounded()))° · \(L(t > 0 ? "turn right" : "turn left")) \(Int(abs(t).rounded()))°", systemImage: "location.north.line.fill")
                        .font(HandyFont.body).foregroundStyle(abs(t) < 3 ? HandyColor.success : HandyColor.textPrimary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
        }
    }

    // MARK: sound

    private var soundPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            Text("\(Int(sound.db))").font(.system(size: 72, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(dbColor(sound.db))
                + Text(L(" dB")).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
            Text(SensorMath.dbLabel(sound.db)).font(HandyFont.bodyStrong).foregroundStyle(dbColor(sound.db))
            trace(sound.history, range: 20...110).frame(height: 90)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            Text(L(SensorMath.safeText(sound.db))).font(HandyFont.bodyStrong).foregroundStyle(dbColor(sound.db)).multilineTextAlignment(.center)
            if sound.loudFor >= 10 { Label(L("Loud enough to harm your hearing — step away or use earplugs."), systemImage: "exclamationmark.triangle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            HStack { stat("Peak", "\(Int(sound.peak)) dB"); stat("Average", "\(Int(sound.average)) dB"); stat("Today's safe dose", "\(Int(sound.dose.rounded()))%") }
            Toggle(L("Warn me when it stays too loud"), isOn: $loudAlert).font(HandyFont.caption).tint(HandyColor.accent)
            let loud = sound.moments.filter { $0.seconds >= 1 }
            if !loud.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(L("Noise log")) · \(loud.count) \(L(loud.count == 1 ? "loud moment" : "loud moments"))").font(HandyFont.bodyStrong)
                    ForEach(loud.suffix(4)) { m in
                        Text("\(m.start.formatted(date: .omitted, time: .standard)) · \(Int(m.seconds.rounded())) s · \(Int(m.peak)) dB").font(HandyFont.caption).monospacedDigit()
                    }
                    ShareLink(item: sound.logText()) { Label(L("Share the noise log"), systemImage: "square.and.arrow.up") }.compactButton()
                    Text(L("Keep Tenzy open on a table to log a neighbour's noise with times — useful for a complaint.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
            }
            HStack(spacing: HandySpacing.s8) {
                Button { sound.reset() } label: { Label(L("Reset"), systemImage: "arrow.counterclockwise") }.compactButton()
                Spacer()
                Text(L("Calibrate")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Stepper("\(dbOffset >= 0 ? "+" : "")\(Int(dbOffset)) dB", value: $dbOffset, in: -20...20).font(HandyFont.caption).fixedSize()
            }
            if sound.denied { LimitNote("Microphone access is off. Allow it in Settings to measure sound.") }
            Text(L("Phone mics aren't lab meters — treat it as ±5 dB. If you have a real meter, set the offset so they match.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func dbColor(_ db: Double) -> Color { db < 70 ? HandyColor.success : db < 85 ? HandyColor.accent : HandyColor.danger }

    // MARK: light

    private var lightPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            Text(light.lux < 100 ? String(format: "%.0f", light.lux) : light.lux < 10_000 ? "\(Int(light.lux / 10) * 10)" : "\(Int(light.lux / 100) * 100)")
                .font(.system(size: 72, weight: .bold, design: .rounded)).monospacedDigit()
                + Text(L(" lux")).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
            Text(SensorMath.luxLabel(light.lux)).font(HandyFont.bodyStrong)
            if let r = lightResult {
                let v = SensorMath.lightVerdict(r)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(L("This spot")): \(L(v.title)) · \(Int(r)) lux").font(HandyFont.bodyStrong)
                    Label(L(v.plants), systemImage: "leaf.fill").font(HandyFont.body).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true)
                    Label(L(v.desk), systemImage: "lamp.desk").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    Text("\(L("Measured at")) \(Date().formatted(date: .omitted, time: .shortened)). \(L("Light changes through the day."))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    HStack {
                        Button { lightSamples = []; lightResult = nil } label: { Label(L("Measure again"), systemImage: "arrow.counterclockwise") }.compactButton()
                        Button { remindLightCheck() } label: { Label(L("Remind me this afternoon"), systemImage: "bell") }.compactButton()
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
            } else {
                ProgressView(value: Double(lightSamples.count), total: 40) { Text(L("Hold the phone where the plant's leaves would be, camera facing the window…")).font(HandyFont.caption) }
            }
            Text(L("Reads the back camera's exposure — point it at the surface you care about. Approximate (±30%), fine for plants, desks and rooms.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    // MARK: altitude / barometer

    private var altitudePanel: some View {
        VStack(spacing: HandySpacing.s12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(heading.altitude.map { String(format: "%.0f", $0) } ?? "—").font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                Text(L("m above sea level")).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
            }
            if let a = heading.altitude { Text(String(format: "%.0f ft · GPS ±%.0f m", a * 3.28084, heading.altitudeAccuracy)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            HStack {
                stat("Pressure", baro.pressureKPa.map { String(format: "%.1f hPa", $0 * 10) } ?? "—")
                stat("Climbed", String(format: "%+.1f m", baro.relativeMetres))
                stat("", "")
            }
            HStack(spacing: HandySpacing.s8) {
                Button { baro.reset() } label: { Label(L("Reset climb"), systemImage: "arrow.counterclockwise") }.compactButton()
                Spacer()
            }
            if !baro.available { LimitNote("No barometer on this device — GPS altitude only.") }
            Text(L("Barometer tracks floors and hills precisely (±1 m relative); GPS gives the absolute number. Pressure trend falling fast = weather coming.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
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
                    Text(L("µT")).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                }
            }.padding(.top, HandySpacing.s8)
            Text(motion.metalScore > 0.6 ? "Strong — magnet or steel right here" : motion.metalScore > 0.2 ? "Something ferrous nearby" : "Ambient field").font(HandyFont.bodyStrong)
            HStack(spacing: HandySpacing.s8) {
                Button { motion.calibrateMagnet() } label: { Label(L("Set baseline here"), systemImage: "scope") }.compactButton()
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L("1. Take the phone out of a magnetic case. Hold it away from the wall and tap Set baseline here.")).font(HandyFont.caption)
                Text(L("2. Lay it flat on the wall and slide it slowly sideways. It buzzes harder as you get closer.")).font(HandyFont.caption)
                Text(L("3. The firmest buzz is over the metal — the sensor is near the top of the phone. Mark it with a pencil.")).font(HandyFont.caption)
                Text(L("Finds screws, nails and metal pipes, not wood itself. Wiring can be near studs — check before drilling.")).font(HandyFont.micro).foregroundStyle(HandyColor.amber)
            }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
        }
    }

    // MARK: ruler

    private var rulerPanel: some View {
        VStack(spacing: HandySpacing.s12) {
            RulerStrip(pointsPerMM: SensorMath.pointsPerMM(nativeScale: UIScreen.main.nativeScale, calibration: rulerCal), inches: rulerInches)
                .frame(height: 110)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            Picker(L("Units"), selection: $rulerInches) { Text(L("cm")).tag(false); Text(L("inches")).tag(true) }.pickerStyle(.segmented).frame(width: 180)
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text(L("Calibrate: lay a bank card along the ruler's top edge and slide until its width reads 85.6 mm.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                // A real bank card (85.6 mm) is wider than most phone screens, so keep this preview in a
                // horizontal scroller — otherwise its fixed width would widen the whole page and clip it.
                ScrollView(.horizontal, showsIndicators: false) {
                    Rectangle().fill(HandyColor.accentSoft)
                        .frame(width: 85.6 * SensorMath.pointsPerMM(nativeScale: UIScreen.main.nativeScale, calibration: rulerCal), height: 28)
                        .overlay(Text(L("bank card width")).font(HandyFont.micro).foregroundStyle(HandyColor.accent))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: $rulerCal, in: 0.85...1.15).tint(HandyColor.accent)
                HStack { Button(L("Reset calibration")) { rulerCal = 1 }.textButton(); Spacer() }
            }.frame(maxWidth: .infinity).cardStyle(padding: HandySpacing.s12)
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
