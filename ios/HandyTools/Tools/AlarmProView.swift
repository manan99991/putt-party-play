import SwiftUI
import AlarmKit
import ActivityKit
import AppIntents

/// AlarmKit (iOS 26) gives real alarms that ring through silent mode and Focus.
/// What it adds over the stock Clock app: snooze length you choose (1–30 min), per-alarm sound,
/// labels, repeat days. What iOS still doesn't expose to any app: per-alarm volume — alarms
/// play at the system alarm volume. Be honest about that in the App Store listing.

struct HTAlarmMetadata: AlarmMetadata {
    var label: String
}

struct SavedAlarm: Codable, Identifiable {
    var id = UUID()
    var hour = 7
    var minute = 0
    var label = ""
    var weekdays: [Int] = []          // 1 = Sunday … 7 = Saturday (Locale.Weekday order)
    var snoozeMinutes = 9
    var sound = "default"
    var enabled = true
}

@MainActor
final class AlarmProModel: ObservableObject {
    @Published var alarms: [SavedAlarm] = AlarmProModel.load() { didSet { save() } }
    @Published var authorized = false
    @Published var error: String?

    static let freeLimit = 3
    private static let key = "saved_alarms"

    static func load() -> [SavedAlarm] {
        guard let d = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SavedAlarm].self, from: d)) ?? []
    }
    private func save() { UserDefaults.standard.set(try? JSONEncoder().encode(alarms), forKey: Self.key) }

    func requestAuth() async {
        do { authorized = try await AlarmManager.shared.requestAuthorization() == .authorized }
        catch { self.error = error.localizedDescription }
    }

    func upsert(_ a: SavedAlarm) async {
        if let i = alarms.firstIndex(where: { $0.id == a.id }) { alarms[i] = a } else { alarms.append(a) }
        await sync(a)
    }

    func delete(_ a: SavedAlarm) {
        alarms.removeAll { $0.id == a.id }
        try? AlarmManager.shared.cancel(id: a.id)
    }

    /// Pushes one SavedAlarm into AlarmKit (or cancels it if disabled).
    func sync(_ a: SavedAlarm) async {
        try? AlarmManager.shared.cancel(id: a.id)
        guard a.enabled else { return }
        if !authorized { await requestAuth(); guard authorized else { return } }

        let weekdays: [Locale.Weekday] = a.weekdays.compactMap {
            [1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday, 5: .thursday, 6: .friday, 7: .saturday][$0]
        }
        let schedule: Alarm.Schedule = .relative(.init(
            time: .init(hour: a.hour, minute: a.minute),
            repeats: weekdays.isEmpty ? .never : .weekly(weekdays)))

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: a.label.isEmpty ? "Alarm" : a.label),
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: AlarmButton(text: "Snooze \(a.snoozeMinutes)m", textColor: .white, systemImageName: "zzz"),
            secondaryButtonBehavior: .countdown)
        let countdown = AlarmPresentation.Countdown(title: "Snoozed")
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert, countdown: countdown),
            metadata: HTAlarmMetadata(label: a.label),
            tintColor: Color(red: 0.12, green: 0.37, blue: 1.0))

        // postAlert = the snooze length. This is the knob the Clock app hides.
        let duration = Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval(a.snoozeMinutes * 60))

        let config = AlarmManager.AlarmConfiguration(
            countdownDuration: duration,
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: a.id.uuidString),
            sound: a.sound == "default" ? .default : .named(a.sound))
        do { _ = try await AlarmManager.shared.schedule(id: a.id, configuration: config) }
        catch { self.error = error.localizedDescription }
    }
}

struct StopAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop alarm"
    @Parameter(title: "Alarm ID") var alarmID: String
    init() {}
    init(alarmID: String) { self.alarmID = alarmID }
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) { try AlarmManager.shared.stop(id: id) }
        return .result()
    }
}

struct AlarmProView: View {
    @StateObject private var m = AlarmProModel()
    @EnvironmentObject var store: StoreManager
    @State private var editing: SavedAlarm?
    @State private var showPaywall = false

    var body: some View {
        ToolPage(title: "Alarm Pro", subtitle: "Snooze as long or short as you want. Rings through silent and Focus.") {
            if let e = m.error { Text(e).foregroundStyle(HandyColor.danger).font(HandyFont.caption) }
            Button {
                if !store.isPremium && m.alarms.count >= AlarmProModel.freeLimit { showPaywall = true } else { editing = SavedAlarm() }
            } label: { Label("New alarm", systemImage: "plus") }
            .primaryButton()
            if m.alarms.isEmpty { EmptyState(icon: "alarm", line: "No alarms yet.", sub: "Tap New alarm to set your first.") }
            ForEach(m.alarms) { a in
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: HandySpacing.s8) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(String(format: "%d:%02d", a.hour % 12 == 0 ? 12 : a.hour % 12, a.minute)).font(.system(size: 40, weight: .light)).monospacedDigit()
                            Text(a.hour < 12 ? "AM" : "PM").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        }
                        Text(summary(a)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        HStack(spacing: 6) {
                            ForEach(1...7, id: \.self) { d in Circle().fill(a.weekdays.contains(d) ? HandyColor.accent : HandyColor.border).frame(width: 8, height: 8) }
                        }
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { a.enabled }, set: { v in var c = a; c.enabled = v; Task { await m.upsert(c) } })).labelsHidden().tint(HandyColor.accent)
                }
                .cardStyle()
                .contentShape(Rectangle())
                .onTapGesture { editing = a }
            }
            if !store.isPremium { LimitNote("Free: 3 alarms. Pro: unlimited.") }
            LimitNote("iOS plays every alarm at the system alarm volume; per-alarm volume isn't something Apple lets any app set yet.")
        }
        .task { if !Launch.screenshots { await m.requestAuth() } }
        .sheet(item: $editing) { a in AlarmEditor(alarm: a, onSave: { saved in Task { await m.upsert(saved) } }, onDelete: { gone in m.delete(gone) }) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func summary(_ a: SavedAlarm) -> String {
        let days = ["S", "M", "T", "W", "T", "F", "S"]
        let rep = a.weekdays.isEmpty ? "Once" : (a.weekdays.count == 7 ? "Every day" : "Repeats")
        return [a.label.isEmpty ? nil : a.label, rep, "snooze \(a.snoozeMinutes) min"].compactMap { $0 }.joined(separator: " · ")
    }
}

struct AlarmEditor: View {
    @State var alarm: SavedAlarm
    let onSave: (SavedAlarm) -> Void
    let onDelete: (SavedAlarm) -> Void
    @Environment(\.dismiss) private var dismiss
    private let days = ["S", "M", "T", "W", "T", "F", "S"]
    private let sounds = ["default", "Chime", "Radar", "Beacon"] // bundle .caf files named like this for custom sounds

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Time", selection: Binding(
                    get: { Calendar.current.date(from: DateComponents(hour: alarm.hour, minute: alarm.minute)) ?? .now },
                    set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); alarm.hour = c.hour ?? 7; alarm.minute = c.minute ?? 0 }),
                    displayedComponents: .hourAndMinute).datePickerStyle(.wheel)
                TextField("Label", text: $alarm.label)
                Section("Repeat") {
                    HStack {
                        ForEach(1...7, id: \.self) { d in
                            let on = alarm.weekdays.contains(d)
                            Text(days[d - 1]).frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(on ? HandyColor.accent : HandyColor.accentSoft, in: Circle())
                                .foregroundStyle(on ? .white : .primary)
                                .onTapGesture { if on { alarm.weekdays.removeAll { $0 == d } } else { alarm.weekdays.append(d) } }
                        }
                    }
                }
                Section {
                    VStack(spacing: HandySpacing.s8) {
                        HStack(alignment: .lastTextBaseline) {
                            Text("Snooze length").font(HandyFont.body)
                            Spacer()
                            Text("\(alarm.snoozeMinutes) min").font(.system(size: 28, weight: .semibold)).monospacedDigit().foregroundStyle(HandyColor.accent)
                                .contentTransition(.numericText())
                        }
                        Slider(value: Binding(get: { Double(alarm.snoozeMinutes) }, set: { alarm.snoozeMinutes = Int($0) }), in: 1...30, step: 1).tint(HandyColor.accent)
                    }
                    .padding(.vertical, HandySpacing.s4)
                } footer: { Text("The one thing the Clock app won't let you change.") }
                Picker("Sound", selection: $alarm.sound) { ForEach(sounds, id: \.self) { Text($0.capitalized) } }
                if !alarm.label.isEmpty || alarm.hour != 7 {
                    Button("Delete alarm", role: .destructive) { onDelete(alarm); dismiss() }
                }
            }
            .navigationTitle("Alarm")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(alarm); dismiss() } }
            }
        }
    }
}
