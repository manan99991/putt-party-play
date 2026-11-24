import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

// Buttons for Control Center, the Lock Screen and the Action button (add them from the Controls gallery under "Tenzy"),
// and the parking meter counting down on the Lock Screen and in the Dynamic Island.

struct ParkControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.tenzy.toolkit.control.park") {
            ControlWidgetButton(action: SaveParkingIntent()) { Label("Save parking", systemImage: "car.fill") }
        }
        .displayName("Save where I parked")
        .description("Saves where your car is, so you can walk back to it.")
    }
}

struct ScanControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.tenzy.toolkit.control.scan") {
            ControlWidgetButton(action: OpenToolControlIntent(tool: "scan")) { Label("Scan", systemImage: "doc.viewfinder") }
        }
        .displayName("Scan a document")
        .description("Opens Tenzy's scanner.")
    }
}

struct IdentifyControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.tenzy.toolkit.control.identify") {
            ControlWidgetButton(action: OpenToolControlIntent(tool: "identify")) { Label("What is this?", systemImage: "viewfinder") }
        }
        .displayName("What is this?")
        .description("Point the camera at anything to name it.")
    }
}

struct TranslateControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.tenzy.toolkit.control.translate") {
            ControlWidgetButton(action: OpenToolControlIntent(tool: "translate")) { Label("Translate", systemImage: "character.bubble") }
        }
        .displayName("Translate")
        .description("Opens Tenzy's translator.")
    }
}

/// The parking meter: how long is left, ticking on its own, and the note about where the car is.
struct ParkingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ParkingAttributes.self) { ctx in
            ParkingLockView(state: ctx.state, stale: ctx.isStale)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Parking", systemImage: "car.fill").font(.headline).foregroundStyle(.cyan)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...max(Date(), ctx.state.ends), countsDown: true)
                        .font(.title2.monospacedDigit().weight(.bold)).multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(ctx.state.note.isEmpty ? "Ends at \(ctx.state.ends.formatted(date: .omitted, time: .shortened))" : ctx.state.note)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "car.fill").foregroundStyle(.cyan)
            } compactTrailing: {
                Text(timerInterval: Date()...max(Date(), ctx.state.ends), countsDown: true)
                    .monospacedDigit().frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(.cyan)
            }
            .widgetURL(URL(string: "tenzy://tool/gpsdash"))
        }
    }
}

struct ParkingLockView: View {
    let state: ParkingAttributes.ContentState
    let stale: Bool
    var body: some View {
        let over = stale || state.ends <= Date()
        HStack(spacing: 12) {
            Image(systemName: over ? "exclamationmark.circle.fill" : "car.fill")
                .font(.system(size: 26, weight: .bold)).foregroundStyle(over ? .orange : .cyan)
                .frame(width: 44, height: 44).background(.white.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(over ? "Parking time is up" : "Parking ends at \(state.ends.formatted(date: .omitted, time: .shortened))")
                    .font(.headline).foregroundStyle(.white)
                Text(state.note.isEmpty ? "Tap for walking directions back to your car" : state.note)
                    .font(.caption).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
            }
            Spacer(minLength: 4)
            if !over {
                Text(timerInterval: Date()...state.ends, countsDown: true)
                    .font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                    .multilineTextAlignment(.trailing).frame(maxWidth: 110)
            }
        }
        .padding(16)
        .widgetURL(URL(string: "tenzy://tool/gpsdash"))
    }
}
