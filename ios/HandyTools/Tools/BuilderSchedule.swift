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
    /// Test run: the reminder exactly as it will arrive, in 5 seconds. Tapping it opens the tool (once it's saved).
    static func testRun(name: String, toolID: String?) async {
        let c = UNMutableNotificationContent()
        c.title = "Test · " + (name.isEmpty ? "Your tool" : name)
        c.body = "Time to run this tool. Tap to open it."
        c.sound = .default
        if let toolID { c.userInfo = ["tool": toolID] }
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "tool-test-\(UUID().uuidString)", content: c,
                                                                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }

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

    func install() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().setNotificationCategories([MedSchedule.registerCategory(), DayDiary.registerCategory(), DayDiary.savedCategoryDef(), ContactPlans.registerCategory()])
        // Top up dated medication alerts (they're scheduled two weeks ahead) every launch.
        Task { @MainActor in MedStore.shared.reschedule() }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        if content.categoryIdentifier == MedSchedule.category {
            let medID = (content.userInfo["med"] as? String).flatMap(UUID.init(uuidString:))
            switch response.actionIdentifier {
            case MedSchedule.takenAction:
                if let medID { Task { @MainActor in MedStore.shared.takenFromAlert(medID: medID) } }
            case MedSchedule.snoozeAction:
                MedSchedule.snooze(content)
            case MedCare.textAction:
                Task { @MainActor in
                    let name = medID.flatMap { id in MedStore.shared.meds.first { $0.id == id }?.name } ?? "medicine"
                    let due = content.userInfo["dose"] as? Double
                    let body = MedCare.missedNote(name, due: due.map { Date(timeIntervalSince1970: $0) }, to: MedCare.caregiverName)
                    if let u = MedCare.smsURL(MedCare.caregiverPhone, body: body) { _ = await UIApplication.shared.open(u) }
                }
            default:
                DispatchQueue.main.async { NotificationCenter.default.post(name: .openTool, object: "medreminder") }
            }
            completionHandler(); return
        }
        if content.categoryIdentifier == DayDiary.category || content.categoryIdentifier == DayDiary.savedCategory {
            switch response.actionIdentifier {
            case DayDiary.talkAction:
                // Straight to recording — the day's answer (if given) is kept, the message is added to it.
                DispatchQueue.main.async { NotificationCenter.default.post(name: .openTool, object: "daydiary-record") }
            case DayDiary.goodAction:
                DiaryStore.shared.log(.good); DayDiary.confirm(.good)
            case DayDiary.badAction:
                DiaryStore.shared.log(.bad); DayDiary.confirm(.bad)
            default:
                DispatchQueue.main.async { NotificationCenter.default.post(name: .openTool, object: "daydiary") }
            }
            completionHandler(); return
        }
        if content.categoryIdentifier == ContactPlans.category, let u = ContactPlans.handle(action: response.actionIdentifier, info: content.userInfo) {
            DispatchQueue.main.async { UIApplication.shared.open(u) }   // Call or Directions, straight from the alert
            completionHandler(); return
        }
        if let tool = content.userInfo["open"] as? String {
            DispatchQueue.main.async { NotificationCenter.default.post(name: .openTool, object: tool) }
            completionHandler(); return
        }
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

/// After a Test run: waits for the test alert to land, then says plainly what happened — so "it arrives in 5 seconds"
/// is never a promise nobody checked. A Focus (Sleep, Do Not Disturb) silences alerts without blocking them, so the
/// alert still lands in Notification Center and the person is told where to look.
enum NotifyCheck {
    static func report(after seconds: Double = 7) async -> String {
        let since = Date().addingTimeInterval(-1)
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        let center = UNUserNotificationCenter.current()
        let landed = await center.deliveredNotifications().contains { $0.date >= since && ($0.request.content.title.hasPrefix("Test") || $0.request.identifier.lowercased().contains("test")) }
        let settings = await center.notificationSettings()
        if landed {
            if settings.alertSetting != .enabled {
                return L("It arrived ✓ — but banners are off for Tenzy, so it went straight to Notification Center. Turn on Banners in Settings › Notifications › Tenzy to see them pop up.")
            }
            return L("It arrived ✓ — that's exactly what you'll get. Didn't see it pop up? A Focus like Sleep (the bed at the top of your screen) keeps alerts quiet; it's waiting in Notification Center — swipe down from the top.")
        }
        if settings.authorizationStatus == .denied {
            return L("It didn't arrive — notifications are off for Tenzy. Turn them on in Settings › Notifications › Tenzy.")
        }
        return L("It didn't arrive yet. Check Settings › Notifications › Tenzy (Allow Notifications on) and that a Focus or Scheduled Summary isn't holding it.")
    }
}

/// "Remind me": a switch, a time, and the days. Lives at the bottom of the builder.
struct ScheduleCard: View {
    @Binding var schedule: ChainSchedule?
    var name = ""
    var toolID: String?
    @State private var blocked = false
    @State private var testNote: String?

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
            Toggle(isOn: on) { Label(L("Remind me to run this"), systemImage: "bell").font(HandyFont.bodyStrong) }
                .accessibilityIdentifier("schedule-on")
            if let s = schedule {
                DatePicker("Time", selection: time, displayedComponents: .hourAndMinute).font(HandyFont.caption)
                    .accessibilityIdentifier("schedule-time")
                HStack(spacing: HandySpacing.s8) {
                    ForEach(week, id: \.self) { d in dayChip(d, picked: s.days.isEmpty || s.days.contains(d)) }
                }
                Text(s.label(uses24h: ToolSchedules.uses24h)).font(HandyFont.caption).foregroundStyle(HandyColor.accent)
                if blocked {
                    NotificationsOffCard(isOff: $blocked)
                } else {
                    Text(L("Your phone shows a reminder at that time. Tap it and this tool opens, ready to run."))
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Button {
                    Task {
                        guard await NotifyPermission.ensure() else { blocked = true; return }
                        await ToolSchedules.testRun(name: name, toolID: toolID); testNote = L("Test sent — it arrives in 5 seconds."); testNote = await NotifyCheck.report()
                    }
                } label: { Label(L("Test run"), systemImage: "checkmark.seal").frame(maxWidth: .infinity) }.secondaryButton()
                    .accessibilityIdentifier("schedule-testrun")
                if let testNote { Text(testNote).font(HandyFont.caption).foregroundStyle(HandyColor.success) }
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .onAppear {
            ToolSchedules.blocked { blocked = $0 }
            // A tool described with its timing ("every evening…") opens with the reminder already on: ask now, once.
            if schedule != nil { Task { let ok = await NotifyPermission.ensure(); await MainActor.run { blocked = !ok } } }
        }
        .onChange(of: schedule != nil) { _, on in
            // Turning the reminder on is the moment to ask — and to show how to fix it if the answer was no.
            guard on else { return }
            Task { let ok = await NotifyPermission.ensure(); await MainActor.run { blocked = !ok } }
        }
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
