import SwiftUI
import AVFoundation
import UIKit

/// Countdown timer + stopwatch in one. Big readable digits, quick presets, and a gentle chime
/// that respects the silent switch. No setup, no account — the stuff the clock app buries.
struct TimersView: View {
    @State private var mode = 0   // 0 = timer, 1 = stopwatch
    var body: some View {
        ToolPage(title: "Timers", subtitle: "A countdown and a stopwatch, without digging through the Clock app.") {
            Picker("", selection: $mode) {
                Text("Timer").tag(0); Text("Stopwatch").tag(1)
            }.pickerStyle(.segmented)
            if mode == 0 { CountdownView() } else { StopwatchView() }
        }
    }
}

private struct CountdownView: View {
    @State private var remaining: Int = 300    // seconds
    @State private var total: Int = 300
    @State private var running = false
    @State private var endDate: Date?
    private let tick = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private let presets: [(String, Int)] = [("1m", 60), ("3m", 180), ("5m", 300), ("10m", 600), ("15m", 900), ("25m", 1500)]

    var body: some View {
        VStack(spacing: HandySpacing.s24) {
            ZStack {
                Circle().stroke(HandyColor.border, lineWidth: 10)
                Circle().trim(from: 0, to: total > 0 ? CGFloat(remaining) / CGFloat(total) : 0)
                    .stroke(HandyColor.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90)).animation(.linear(duration: 0.2), value: remaining)
                Text(clock(remaining)).font(.system(size: 54, weight: .bold, design: .rounded)).monospacedDigit()
            }.frame(width: 240, height: 240).padding(.top, HandySpacing.s8)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: HandySpacing.s8) {
                ForEach(presets, id: \.0) { p in
                    Button(p.0) { set(p.1) }.compactButton().disabled(running)
                }
            }

            HStack(spacing: HandySpacing.s16) {
                Button { running ? pause() : start() } label: {
                    Label(running ? "Pause" : "Start", systemImage: running ? "pause.fill" : "play.fill").frame(maxWidth: .infinity)
                }.primaryButton().disabled(remaining == 0)
                Button { reset() } label: { Label("Reset", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity) }.compactButton()
            }
        }
        .onReceive(tick) { _ in
            guard running, let end = endDate else { return }
            remaining = max(0, Int(end.timeIntervalSinceNow.rounded()))
            if remaining == 0 { running = false; endDate = nil; fire() }
        }
    }

    private func set(_ s: Int) { total = s; remaining = s }
    private func start() { endDate = Date().addingTimeInterval(TimeInterval(remaining)); running = true; HandyHaptics.light() }
    private func pause() { running = false; endDate = nil }
    private func reset() { running = false; endDate = nil; remaining = total }
    private func clock(_ s: Int) -> String { String(format: "%02d:%02d", s / 60, s % 60) }
    private func fire() {
        HandyHaptics.success()
        AudioServicesPlaySystemSound(1005)
    }
}

private struct StopwatchView: View {
    @State private var elapsed: TimeInterval = 0
    @State private var running = false
    @State private var startDate: Date?
    @State private var base: TimeInterval = 0
    @State private var laps: [TimeInterval] = []
    private let tick = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: HandySpacing.s24) {
            Text(clock(elapsed)).font(.system(size: 56, weight: .bold, design: .rounded)).monospacedDigit().padding(.top, HandySpacing.s24)
            HStack(spacing: HandySpacing.s16) {
                Button { running ? stop() : go() } label: {
                    Label(running ? "Stop" : "Start", systemImage: running ? "stop.fill" : "play.fill").frame(maxWidth: .infinity)
                }.primaryButton()
                Button { running ? lap() : clear() } label: {
                    Label(running ? "Lap" : "Reset", systemImage: running ? "flag.fill" : "arrow.counterclockwise").frame(maxWidth: .infinity)
                }.compactButton()
            }
            if !laps.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(laps.enumerated().reversed()), id: \.offset) { i, l in
                        HStack { Text("Lap \(i + 1)"); Spacer(); Text(clock(l)).monospacedDigit() }
                            .font(HandyFont.body).padding(.vertical, HandySpacing.s8)
                        if i != 0 { Divider() }
                    }
                }.cardStyle(padding: HandySpacing.s12)
            }
        }
        .onReceive(tick) { _ in if running, let s = startDate { elapsed = base + Date().timeIntervalSince(s) } }
    }
    private func go() { startDate = Date(); running = true; HandyHaptics.light() }
    private func stop() { base = elapsed; running = false }
    private func lap() { laps.append(elapsed) }
    private func clear() { elapsed = 0; base = 0; laps = [] }
    private func clock(_ t: TimeInterval) -> String {
        let cs = Int(t * 100) % 100, s = Int(t) % 60, m = Int(t) / 60
        return String(format: "%02d:%02d.%02d", m, s, cs)
    }
}
