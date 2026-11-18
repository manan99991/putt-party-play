import SwiftUI
import UserNotifications

/// Medicine Reminders — add a medicine once (name, dose, when), get a reminder with "Taken ✓" and
/// "Snooze" buttons, and see today's doses ticked off plus how this week went. Every schedule people
/// actually need: set times daily, set days of the week, every N hours while awake, start/end dates, and
/// a "remind me in 3 months" follow-up for refills or check-ins. Private: stays on this phone.
struct MedRemindersView: View {
    @ObservedObject private var store = MedStore.shared
    @State private var editing: Med?
    @State private var blocked = false

    var body: some View {
        ToolPage(title: "Medicine Reminders",
                 subtitle: "Reminders for every medicine, with a Taken button and a week view.",
                 working: false) {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                if blocked {
                    Label(L("Notifications are off for Tenzy, so reminders can't alert you. Turn them on in Settings → Notifications → Tenzy."),
                          systemImage: "bell.slash.fill")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                        .cardStyle(padding: HandySpacing.s12)
                }
                if store.meds.isEmpty { emptyCard } else { todayCard; medsList }
                if store.droppedAlerts > 0 {
                    Label("\(L("iPhone allows 64 alerts per app — the")) \(store.droppedAlerts) \(L("furthest-away doses will be scheduled as the nearer ones pass. Open Tenzy now and then to top them up."))",
                          systemImage: "exclamationmark.triangle")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Text(L("A reminder tool, not medical advice — always follow your doctor's or pharmacist's instructions. Stays on this phone."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .sheet(item: $editing) { m in
            MedEditor(med: m, isNew: !store.meds.contains { $0.id == m.id }) { saved in
                store.save(saved); editing = nil; askPermission()
            } onDelete: { gone in
                store.delete(gone); editing = nil
            } onCancel: { editing = nil }
        }
        .onAppear { checkBlocked() }
    }

    private var emptyCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "pills.fill").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Add your first medicine — name, dose and when. Tenzy reminds you, and you tap Taken right from the alert."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { editing = Med() } label: {
                Label(L("Add a medicine"), systemImage: "plus").frame(maxWidth: .infinity)
            }.primaryButton()
        }
        .cardStyle(padding: HandySpacing.s16)
        .frame(maxWidth: .infinity)
    }

    private var todayCard: some View {
        let doses = MedSchedule.today(store.meds)
        let w = store.week()
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Text(L("Today")).font(HandyFont.bodyStrong)
                Spacer()
                if w.due > 0 {
                    Text("\(L("This week")): \(w.taken)/\(w.due)")
                        .font(HandyFont.caption).foregroundStyle(w.taken == w.due ? HandyColor.success : HandyColor.textSecondary)
                }
            }
            if doses.isEmpty {
                Text(L("Nothing due today.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            ForEach(Array(doses.enumerated()), id: \.offset) { _, d in
                let taken = store.isTaken(d.med, at: d.at)
                Button { store.setTaken(d.med, at: d.at, !taken); if !taken { HandyHaptics.success() } } label: {
                    HStack(spacing: HandySpacing.s12) {
                        Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24)).foregroundStyle(taken ? HandyColor.success : HandyColor.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.med.name).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                                .strikethrough(taken)
                            Text([d.at.formatted(date: .omitted, time: .shortened), d.med.dose].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        }
                        Spacer()
                        if !taken && d.at < Date().addingTimeInterval(-3600) {
                            Text(L("Missed?")).font(HandyFont.micro).foregroundStyle(HandyColor.danger)
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(d.med.name), \(d.at.formatted(date: .omitted, time: .shortened)), \(taken ? L("taken") : L("not taken yet"))")
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var medsList: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Text(L("Your medicines")).font(HandyFont.bodyStrong)
                Spacer()
                Button { editing = Med() } label: { Label(L("Add"), systemImage: "plus").font(HandyFont.caption) }
                    .buttonStyle(.bordered)
            }
            ForEach(store.meds) { m in
                Button { editing = m } label: {
                    HStack(spacing: HandySpacing.s12) {
                        Image(systemName: "pills").foregroundStyle(m.paused ? HandyColor.textSecondary : HandyColor.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.name).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                            Text(MedSchedule.summary(m)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
                        }
                        Spacer()
                        if m.paused { Text(L("Paused")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .cardStyle(padding: HandySpacing.s12)
            }
        }
    }

    private func askPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async { checkBlocked(); MedStore.shared.reschedule() }
        }
    }

    private func checkBlocked() { ToolSchedules.blocked { blocked = $0 } }
}

/// Add or edit one medicine.
struct MedEditor: View {
    @State var med: Med
    let isNew: Bool
    let onSave: (Med) -> Void
    let onDelete: (Med) -> Void
    let onCancel: () -> Void
    @State private var hasEnd: Bool
    @State private var hasFollowUp: Bool

    init(med: Med, isNew: Bool, onSave: @escaping (Med) -> Void, onDelete: @escaping (Med) -> Void, onCancel: @escaping () -> Void) {
        _med = State(initialValue: med)
        self.isNew = isNew; self.onSave = onSave; self.onDelete = onDelete; self.onCancel = onCancel
        _hasEnd = State(initialValue: med.end != nil)
        _hasFollowUp = State(initialValue: med.followUp != nil)
    }

    private let week = [2, 3, 4, 5, 6, 7, 1]   // Monday first

    var body: some View {
        NavigationStack {
            Form {
                Section(L("Medicine")) {
                    TextField(L("Name (e.g. Vitamin D)"), text: $med.name)
                    TextField(L("Dose (e.g. 1 tablet, 5 ml)"), text: $med.dose)
                    TextField(L("Note (e.g. with food)"), text: $med.note)
                }
                Section(L("When")) {
                    Picker(L("Schedule"), selection: $med.pattern) {
                        Text(L("Every day")).tag(Med.Pattern.daily)
                        Text(L("Some days")).tag(Med.Pattern.weekdays)
                        Text(L("Every few hours")).tag(Med.Pattern.everyHours)
                    }
                    if med.pattern == .everyHours {
                        Stepper("\(L("Every")) \(med.everyHours) \(L("hours"))", value: $med.everyHours, in: 1...12)
                        Stepper("\(L("From")) \(TimeOfDay(hour: med.firstHour, minute: 0).label)", value: $med.firstHour, in: 0...23)
                        Stepper("\(L("Until")) \(TimeOfDay(hour: med.lastHour, minute: 0).label)", value: $med.lastHour, in: med.firstHour...23)
                    } else {
                        ForEach(med.times.indices, id: \.self) { i in
                            HStack {
                                DatePicker("\(L("Dose")) \(i + 1)", selection: timeBinding(i), displayedComponents: .hourAndMinute)
                                if med.times.count > 1 {
                                    Button { med.times.remove(at: i) } label: { Image(systemName: "minus.circle.fill").foregroundStyle(HandyColor.danger) }
                                        .buttonStyle(.plain).accessibilityLabel(L("Remove this time"))
                                }
                            }
                        }
                        if med.times.count < 8 {
                            Button(L("Add another time")) {
                                let last = med.times.max() ?? TimeOfDay(hour: 8, minute: 0)
                                med.times.append(TimeOfDay(hour: min(23, last.hour + 4), minute: last.minute))
                            }
                        }
                    }
                    if med.pattern == .weekdays {
                        HStack(spacing: 6) {
                            ForEach(week, id: \.self) { d in
                                let on = med.weekdays.contains(d)
                                Button {
                                    if on { if med.weekdays.count > 1 { med.weekdays.remove(d) } } else { med.weekdays.insert(d) }
                                } label: {
                                    Text(String(Calendar.current.veryShortWeekdaySymbols[d - 1]))
                                        .font(HandyFont.caption).frame(maxWidth: .infinity, minHeight: 36)
                                        .background(on ? HandyColor.accent : HandyColor.surface, in: Circle())
                                        .foregroundStyle(on ? Color.white : HandyColor.textPrimary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Calendar.current.weekdaySymbols[d - 1])
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                    Text(MedSchedule.summary(med)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Section(L("Dates")) {
                    DatePicker(L("Start"), selection: $med.start, displayedComponents: .date)
                    Toggle(L("End on a date"), isOn: $hasEnd)
                    if hasEnd {
                        DatePicker(L("Last day"), selection: Binding(get: { med.end ?? Calendar.current.date(byAdding: .day, value: 7, to: med.start) ?? med.start },
                                                                  set: { med.end = $0 }),
                                   in: med.start..., displayedComponents: .date)
                    }
                }
                Section(L("Follow-up")) {
                    Toggle(L("Remind me later (refill, check-in)"), isOn: $hasFollowUp)
                    if hasFollowUp {
                        HStack {
                            ForEach([1, 3, 6], id: \.self) { months in
                                Button("\(months) \(months == 1 ? L("month") : L("months"))") {
                                    med.followUp = Calendar.current.date(byAdding: .month, value: months, to: Date())
                                }.buttonStyle(.bordered).font(HandyFont.caption)
                            }
                        }
                        DatePicker(L("On"), selection: Binding(get: { med.followUp ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date() },
                                                               set: { med.followUp = $0 }),
                                   in: Date()..., displayedComponents: .date)
                        TextField(L("What for"), text: $med.followUpNote)
                    }
                }
                if !isNew {
                    Section {
                        Toggle(L("Pause reminders"), isOn: $med.paused)
                        Button(L("Delete this medicine"), role: .destructive) { onDelete(med) }
                    }
                }
            }
            .navigationTitle(isNew ? L("Add medicine") : med.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { onCancel() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Save")) {
                        var m = med
                        m.name = m.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !hasEnd { m.end = nil } else if m.end == nil { m.end = Calendar.current.date(byAdding: .day, value: 7, to: m.start) }
                        if !hasFollowUp { m.followUp = nil } else if m.followUp == nil { m.followUp = Calendar.current.date(byAdding: .month, value: 3, to: Date()) }
                        onSave(m)
                    }.disabled(med.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func timeBinding(_ i: Int) -> Binding<Date> {
        Binding(get: {
            let t = med.times.indices.contains(i) ? med.times[i] : TimeOfDay(hour: 8, minute: 0)
            return Calendar.current.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: Date()) ?? Date()
        }, set: { d in
            guard med.times.indices.contains(i) else { return }
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            med.times[i] = TimeOfDay(hour: c.hour ?? 8, minute: c.minute ?? 0)
        })
    }
}
