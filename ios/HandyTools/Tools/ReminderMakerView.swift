import SwiftUI
import UserNotifications

/// A reminder the person writes themselves: what, when (once, every day, or chosen days) and, if they like, the tool
/// that opens when they tap it ("Scan my receipts" every Friday at 6 opens Scan). Manan, 23 Nov: "what if they want a
/// reminder tool, can't they make it from here?" iOS shows it from the phone itself, so it arrives with Tenzy closed.
struct OwnReminder: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var text: String
    var schedule = ChainSchedule()
    /// Once, at the next time `schedule.hour:minute` comes round; otherwise it repeats on `schedule`'s days.
    var once = false
    var onceAt: Date?
    /// The tool that opens from the reminder, if any.
    var opens: String?

    func label(uses24h: Bool) -> String {
        if once, let d = onceAt { return d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()) }
        return schedule.label(uses24h: uses24h)
    }
}

enum OwnReminders {
    static let prefix = "own-"
    private static let key = "tenzy.ownReminders"
    /// Room left after the app's other reminders (iOS holds 64 at most).
    static let limit = 16

    static func load() -> [OwnReminder] {
        (UserDefaults.standard.data(forKey: key)).flatMap { try? JSONDecoder().decode([OwnReminder].self, from: $0) } ?? []
    }
    static func save(_ all: [OwnReminder]) {
        if let d = try? JSONEncoder().encode(all) { UserDefaults.standard.set(d, forKey: key) }
        sync(all)
    }

    /// The next time `hour:minute` comes round after `now`: later today, or tomorrow.
    static func next(hour: Int, minute: Int, after now: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        return today > now ? today : (calendar.date(byAdding: .day, value: 1, to: today) ?? today)
    }

    /// What the phone should hold: one entry per reminder time, a one-off only while it's still ahead. Pure, so it's tested.
    static func plan(_ all: [OwnReminder], now: Date = Date(), calendar: Calendar = .current) -> [(id: String, reminder: OwnReminder, when: DateComponents, repeats: Bool)] {
        var out: [(id: String, reminder: OwnReminder, when: DateComponents, repeats: Bool)] = []
        for r in all {
            if r.once {
                guard let at = r.onceAt, at > now, out.count < limit else { continue }
                out.append((id: "\(prefix)\(r.id)-0", reminder: r, when: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: at), repeats: false))
            } else {
                for (i, w) in r.schedule.triggers.enumerated() where out.count < limit {
                    out.append((id: "\(prefix)\(r.id)-\(i)", reminder: r, when: w, repeats: true))
                }
            }
        }
        return out
    }

    static func content(_ r: OwnReminder) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = r.text
        c.body = r.opens.flatMap { id in TOOLS.first { $0.id == id } }.map { "\(L("Tap to open")) \(L($0.name))." } ?? L("Your reminder from Tenzy.")
        c.sound = .default
        if let o = r.opens { c.userInfo = ["open": o] }
        return c
    }

    /// Replaces every reminder of this kind with what's saved. Asks for permission only when there's one to set.
    static func sync(_ all: [OwnReminder], done: ((Bool) -> Void)? = nil) {
        let wanted = plan(all)
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !old.isEmpty { center.removePendingNotificationRequests(withIdentifiers: old) }
            guard !wanted.isEmpty else { done?(true); return }
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { done?(false); return }
                for w in wanted {
                    center.add(UNNotificationRequest(identifier: w.id, content: content(w.reminder),
                                                     trigger: UNCalendarNotificationTrigger(dateMatching: w.when, repeats: w.repeats)))
                }
                done?(true)
            }
        }
    }
}

struct ReminderMakerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var saved = OwnReminders.load()
    @State private var text = ""
    @State private var time = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var how = 1          // 0 once, 1 every day, 2 some days
    @State private var days: Set<Int> = [2, 3, 4, 5, 6]
    @State private var opens = ""
    @State private var note: String?
    @State private var blocked = false
    @FocusState private var typing: Bool

    private let week = [2, 3, 4, 5, 6, 7, 1]
    private let ideas = ["Take out the bins", "Water the plants", "Call Mum", "Pay the rent", "Take my vitamins", "Back up my photos"]

    private var schedule: ChainSchedule {
        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
        return ChainSchedule(hour: c.hour ?? 18, minute: c.minute ?? 0, days: how == 2 ? Array(days).sorted() : [])
    }
    private var draft: OwnReminder {
        OwnReminder(text: text.trimmingCharacters(in: .whitespacesAndNewlines), schedule: schedule, once: how == 0,
                    onceAt: how == 0 ? OwnReminders.next(hour: schedule.hour, minute: schedule.minute) : nil, opens: opens.isEmpty ? nil : opens)
    }
    private var canSave: Bool { !draft.text.isEmpty && (how != 2 || !days.isEmpty) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                hero
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text(L("Remind me to")).font(HandyFont.bodyStrong)
                    TextField(L("e.g. Water the plants"), text: $text, axis: .vertical)
                        .lineLimit(1...3).font(HandyFont.body).focused($typing)
                        .padding(HandySpacing.s12)
                        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(text.isEmpty ? HandyColor.border : HandyColor.accent, lineWidth: 1))
                        .accessibilityIdentifier("reminder-text")
                    HandyFlow(spacing: 6) {
                        ForEach(ideas, id: \.self) { i in HChip(text: i, selected: text == L(i)) { text = L(i) } }
                    }
                }
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text(L("When")).font(HandyFont.bodyStrong)
                    Picker(L("How often"), selection: $how) {
                        Text(L("Once")).tag(0); Text(L("Every day")).tag(1); Text(L("Some days")).tag(2)
                    }.pickerStyle(.segmented).accessibilityIdentifier("reminder-how")
                    DatePicker(L("Time"), selection: $time, displayedComponents: .hourAndMinute).font(HandyFont.body)
                    if how == 2 {
                        HStack(spacing: 6) { ForEach(week, id: \.self) { d in dayChip(d) } }
                    }
                    Text(summary).font(HandyFont.caption).foregroundStyle(HandyColor.accent)
                }.cardStyle(padding: HandySpacing.s12)
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text(L("When you tap it, open")).font(HandyFont.bodyStrong)
                    Picker(L("Tool"), selection: $opens) {
                        Text(L("Nothing — just remind me")).tag("")
                        ForEach(TOOLS.sorted { L($0.name) < L($1.name) }) { t in Text(L(t.name)).tag(t.id) }
                    }.pickerStyle(.menu).accessibilityIdentifier("reminder-opens")
                }.cardStyle(padding: HandySpacing.s12)
                if blocked {
                    NotificationsOffCard(isOff: $blocked)
                }
                HStack(spacing: HandySpacing.s8) {
                    Button { save() } label: { Label(L("Set reminder"), systemImage: "bell.badge.fill").frame(maxWidth: .infinity) }
                        .primaryButton().disabled(!canSave).accessibilityIdentifier("reminder-save")
                    Button { test() } label: { Label(L("Test run"), systemImage: "paperplane").frame(maxWidth: .infinity) }
                        .compactButton().disabled(draft.text.isEmpty)
                }
                if let note { Label(L(note), systemImage: "checkmark.circle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success) }
                if !saved.isEmpty {
                    SectionLabel(text: L("Your reminders"), icon: "bell.fill")
                    ForEach(saved) { r in row(r) }
                }
                Text(L("Reminders come from iPhone itself, so they arrive even when Tenzy is closed."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(HandySpacing.gutter)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Ground())
        .navigationTitle(L("Build a reminder")).navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("reminder-maker")
    }

    private var hero: some View {
        HStack(spacing: HandySpacing.s12) {
            Image(systemName: "bell.badge.fill").font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                .frame(width: 52, height: 52).background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(L("Your own reminder")).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                Text(L("Say what and when. It can open the tool you need, ready to go."))
                    .font(HandyFont.caption).foregroundStyle(.white.opacity(0.88)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(HandySpacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PostTileGround(hex: 0x7B5CFF, icon: "bell.fill"))
    }

    private var summary: String {
        let clock = ChainSchedule.clock(hour: schedule.hour, minute: schedule.minute, uses24h: ToolSchedules.uses24h)
        switch how {
        case 0:
            let at = OwnReminders.next(hour: schedule.hour, minute: schedule.minute)
            return "\(L(Calendar.current.isDateInToday(at) ? "Today at" : "Tomorrow at")) \(clock)"
        case 1: return "\(L("Every day at")) \(clock)"
        default: return days.isEmpty ? L("Pick at least one day") : schedule.label(uses24h: ToolSchedules.uses24h)
        }
    }

    private func dayChip(_ d: Int) -> some View {
        let on = days.contains(d)
        let name = Calendar.current.veryShortWeekdaySymbols[d - 1]
        return Button { if on { days.remove(d) } else { days.insert(d) } } label: {
            Text(name).font(.system(size: 13, weight: .bold))
                .foregroundStyle(on ? HandyColor.onAccent : HandyColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(on ? HandyColor.accent : HandyColor.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Calendar.current.weekdaySymbols[d - 1])
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func row(_ r: OwnReminder) -> some View {
        HStack(spacing: HandySpacing.s12) {
            Image(systemName: r.opens.flatMap { id in TOOLS.first { $0.id == id }?.icon } ?? "bell.fill")
                .font(.system(size: 15, weight: .bold)).foregroundStyle(HandyColor.accent)
                .frame(width: 34, height: 34).background(HandyColor.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.text).font(HandyFont.bodyStrong).lineLimit(2)
                Text(r.label(uses24h: ToolSchedules.uses24h)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Spacer(minLength: 0)
            Button {
                saved.removeAll { $0.id == r.id }; OwnReminders.save(saved)
            } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                .foregroundStyle(HandyColor.danger).accessibilityLabel("\(L("Delete")) \(r.text)")
        }
        .cardStyle(padding: HandySpacing.s8)
    }

    private func save() {
        guard canSave else { return }
        typing = false
        let r = draft
        saved.append(r)
        OwnReminders.save(saved)
        note = "Set — \(r.label(uses24h: ToolSchedules.uses24h))."
        text = ""; opens = ""
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { blocked = s.authorizationStatus == .denied }
        }
    }

    /// The reminder exactly as it will arrive, in 5 seconds.
    private func test() {
        let c = OwnReminders.content(draft)
        c.title = "\(L("Test")) · \(c.title)"
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            DispatchQueue.main.async { if !ok { blocked = true } }
            guard ok else { return }
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "own-test-\(UUID().uuidString)", content: c,
                                                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
            DispatchQueue.main.async { note = "Sent — check the top of the screen in 5 seconds." }
        }
    }
}
