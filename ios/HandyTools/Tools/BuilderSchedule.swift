import SwiftUI
import UserNotifications

/// Tool reminders: "run my receipt tool every Friday at 6". iOS does not let an app start work by itself at a set
/// time, so a schedule is an honest reminder. Tapping it opens the tool ready to run.
enum ToolSchedules {
    static let prefix = "tool-"
    private static let pendingKey = "builder.pendingTool"
    /// iOS keeps at most 64 waiting reminders per app; stay under it and leave room for the app's other ones.
    static let limit = 56

    /// Does this phone show time as 18:30 rather than 6:30 PM?
    static var uses24h: Bool {
        !(DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "").contains("a")
    }

    /// What the phone should be holding for these tools: one entry per reminder, capped at the limit. Pure, so it is tested.
    static func plan(for chains: [Chain]) -> [(id: String, tool: Chain, when: DateComponents)] {
        var out: [(id: String, tool: Chain, when: DateComponents)] = []
        for c in chains {
            guard let s = c.schedule else { continue }
            for (i, when) in s.triggers.enumerated() where out.count < limit {
                out.append((id: "\(prefix)\(c.id)-\(i)", tool: c, when: when))
            }
        }
        return out
    }

    /// Replace every tool reminder with what the saved tools now ask for. Asks for permission only if a tool has one.
    static func sync(_ chains: [Chain]) {
        let wanted = plan(for: chains)
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !old.isEmpty { center.removePendingNotificationRequests(withIdentifiers: old) }
            guard !wanted.isEmpty else { return }
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }
                for w in wanted {
                    let c = UNMutableNotificationContent()
                    c.title = w.tool.name
                    c.body = "Time to run this tool. Tap to open it."
                    c.sound = .default
                    c.userInfo = ["tool": w.tool.id]
                    center.add(UNNotificationRequest(identifier: w.id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: w.when, repeats: true)))
                }
            }
        }
    }

    /// Are reminders switched off for Tenzy in Settings? The editor says so instead of promising one that never arrives.
    static func blocked(_ done: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let off = s.authorizationStatus == .denied
            DispatchQueue.main.async { done(off) }
        }
    }

    static func setPending(_ id: String) { UserDefaults.standard.set(id, forKey: pendingKey) }
    static var hasPending: Bool { UserDefaults.standard.string(forKey: pendingKey) != nil }
    static func takePending() -> String? {
        let id = UserDefaults.standard.string(forKey: pendingKey)
        UserDefaults.standard.removeObject(forKey: pendingKey)
        return id
    }
}

/// Hears a tapped reminder and sends the person to that tool.
final class ToolNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ToolNotifications()

    func install() { UNUserNotificationCenter.current().delegate = self }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let id = response.notification.request.content.userInfo["tool"] as? String {
            ToolSchedules.setPending(id)
            DispatchQueue.main.async { NotificationCenter.default.post(name: .openTool, object: "builder") }
        }
        completionHandler()
    }

    /// With Tenzy already open, still show the reminder instead of swallowing it.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

/// "Remind me": a switch, a time, and the days. Lives at the bottom of the builder.
struct ScheduleCard: View {
    @Binding var schedule: ChainSchedule?
    @State private var blocked = false

    /// Monday first, Sunday last.
    private let week = [2, 3, 4, 5, 6, 7, 1]

    private var on: Binding<Bool> {
        Binding(get: { schedule != nil }, set: { schedule = $0 ? (schedule ?? ChainSchedule()) : nil })
    }
    private var time: Binding<Date> {
        Binding(get: {
            let s = schedule ?? ChainSchedule()
            return Calendar.current.date(bySettingHour: s.hour, minute: s.minute, second: 0, of: Date()) ?? Date()
        }, set: { d in
            var s = schedule ?? ChainSchedule()
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            s.hour = c.hour ?? 9; s.minute = c.minute ?? 0
            schedule = s
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Toggle(isOn: on) { Label("Remind me to run this", systemImage: "bell").font(HandyFont.bodyStrong) }
                .accessibilityIdentifier("schedule-on")
            if let s = schedule {
                DatePicker("Time", selection: time, displayedComponents: .hourAndMinute).font(HandyFont.caption)
                    .accessibilityIdentifier("schedule-time")
                HStack(spacing: HandySpacing.s8) {
                    ForEach(week, id: \.self) { d in dayChip(d, picked: s.days.isEmpty || s.days.contains(d)) }
                }
                Text(s.label(uses24h: ToolSchedules.uses24h)).font(HandyFont.caption).foregroundStyle(HandyColor.accent)
                Text(blocked
                     ? "Notifications are off for Tenzy. Turn them on in Settings, then save this tool again."
                     : "Your phone shows a reminder at that time. Tap it and this tool opens, ready to run.")
                    .font(HandyFont.caption).foregroundStyle(blocked ? HandyColor.danger : HandyColor.textSecondary)
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .onAppear { ToolSchedules.blocked { blocked = $0 } }
    }

    private func dayChip(_ d: Int, picked: Bool) -> some View {
        let cal = Calendar.current
        return Button {
            var s = schedule ?? ChainSchedule()
            var days = Set(s.days.isEmpty ? Array(1...7) : s.days)
            if days.contains(d) { if days.count > 1 { days.remove(d) } } else { days.insert(d) }   // never zero days
            s.days = days.count == 7 ? [] : days.sorted()
            schedule = s
        } label: {
            Text(cal.veryShortWeekdaySymbols[d - 1]).font(HandyFont.caption)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(picked ? Color.white : HandyColor.textSecondary)
                .background(picked ? HandyColor.accent : HandyColor.bg, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cal.weekdaySymbols[d - 1])
        .accessibilityAddTraits(picked ? .isSelected : [])
    }
}
