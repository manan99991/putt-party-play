import SwiftUI
import Contacts
import ContactsUI
import MessageUI
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
                NotificationsOffCard(isOff: $blocked)
                if store.meds.isEmpty { emptyCard } else { todayCard; medsList }
                CareCard(store: store)
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
        .onChange(of: blocked) { _, off in resumeIfAllowed(off) }
        .onAppear { checkBlocked(); store.addSampleIfEmpty() }
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
    // When notifications come back on (from Settings), put every dose alert back.
    private func resumeIfAllowed(_ off: Bool) { if !off { MedStore.shared.reschedule() } }
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
                Section {
                    Toggle(L("Count my pills and tell me when to refill"), isOn: Binding(get: { med.supply != nil },
                                                                                       set: { med.supply = $0 ? (med.supply ?? 30) : nil }))
                    if let left = med.supply {
                        Stepper("\(L("Pills left now:")) \(left)", value: Binding(get: { med.supply ?? 0 }, set: { med.supply = max(0, $0) }), in: 0...2000)
                        Stepper("\(L("Pills per dose:")) \(med.perDose ?? 1)", value: Binding(get: { med.perDose ?? 1 }, set: { med.perDose = $0 }), in: 1...10)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(L("Tell me when")) \(med.refillAt ?? 7) \(L("are left"))").font(HandyFont.body)
                            HStack {
                                ForEach([3, 7, 10, 14], id: \.self) { n in
                                    HChip(text: "\(n)", selected: (med.refillAt ?? 7) == n) { med.refillAt = n }
                                }
                            }.buttonStyle(.borderless)   // in a Form row, each chip must be its own tap target
                        }
                        if let d = MedSchedule.daysLeft(med) {
                            Text("\(L("At this schedule that's about")) \(d) \(L(d == 1 ? "day" : "days")). \(L("Each Taken counts one dose off; undoing it puts it back."))")
                                .font(HandyFont.caption).foregroundStyle(left <= (med.refillAt ?? 7) ? HandyColor.amber : HandyColor.textSecondary)
                        }
                        if left <= (med.refillAt ?? 7) {
                            Label(L("You're already at your refill point — time to order more."), systemImage: "exclamationmark.circle")
                                .font(HandyFont.caption).foregroundStyle(HandyColor.amber)
                        }
                    }
                } header: { Text(L("Refill")) } footer: {
                    Text(L("You get one alert when the count reaches your number. Tenzy never orders or suggests doses — ask your pharmacist about refills."))
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

/// Family & caregiver, in three plain steps: (1) a second nudge if a dose isn't marked Taken; (2) someone who helps —
/// they're one tap from the missed-dose alert, and Tenzy writes them a real update (how the week went, today's doses,
/// the medicines) that you send, with an optional Sunday reminder to do it; (3) setting up someone else's medicines on
/// their phone. Tenzy never texts anyone on its own — iPhone doesn't allow it — so every message is shown first.
private struct CareCard: View {
    @ObservedObject var store: MedStore
    @AppStorage("medcare.followup") private var followUp = 0
    @AppStorage("medcare.name") private var name = ""
    @AppStorage("medcare.phone") private var phone = ""
    @AppStorage("medcare.weekly") private var weekly = false
    @State private var pasteFound: [Med]?
    @State private var note: String?
    @State private var picking = false
    @State private var composing: TextDraft?
    @State private var notifOff = false

    private var hasPhone: Bool { !phone.filter(\.isNumber).isEmpty }
    private var who: String { name.trimmingCharacters(in: .whitespaces).isEmpty ? L("them") : name }
    private var update: String {
        let w = store.week()
        let today = MedSchedule.today(store.meds).map { (name: $0.med.name, at: $0.at, taken: store.isTaken($0.med, at: $0.at)) }
        return MedCare.update(to: name, meds: store.meds, taken: w.taken, due: w.due, missed: store.missedThisWeek(), today: today)
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                Text(L("Tenzy reminds you on this phone. It never texts anyone by itself — iPhone doesn't allow that — so every message is shown to you first and you tap Send."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)

                step(1, "If a dose isn't marked Taken, nudge again") {
                    Picker(L("Nudge again"), selection: $followUp) {
                        Text(L("Off")).tag(0); Text("15 min").tag(15); Text("30 min").tag(30); Text("1 hour").tag(60)
                    }.pickerStyle(.segmented).accessibilityIdentifier("care-followup")
                    Text(L(followUp == 0 ? "Off — one alert per dose." : "A second alert comes if Taken wasn't tapped. Tapping Taken on either one stops the other."))
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }

                step(2, "Keep someone who helps in the loop") {
                    Text(L("A son, a daughter, a nurse. When a dose is missed, the follow-up alert gets a \"Text\" button for them, and Tenzy writes them an update whenever you want to send one."))
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    Button { picking = true } label: { Label(L("Pick from my contacts"), systemImage: "person.crop.circle.badge.plus").frame(maxWidth: .infinity) }
                        .secondaryButton().accessibilityIdentifier("care-pick")
                    TextField(L("Their name"), text: $name).textFieldStyle(.handy)
                    TextField(L("Their mobile number"), text: $phone).textFieldStyle(.handy).keyboardType(.phonePad)
                    if hasPhone {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(L("The text")) \(who) \(L("gets"))").font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.textSecondary)
                            Text(update).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary)
                                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("care-update")
                        }
                        Button { composing = TextDraft(to: [phone], body: update) } label: {
                            Label("\(L("Text")) \(who) \(L("this update"))", systemImage: "message.fill").frame(maxWidth: .infinity)
                        }.primaryButton().accessibilityIdentifier("care-send")
                        Toggle(isOn: $weekly) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(L("Remind me every Sunday to send")) \(who) \(L("an update"))").font(HandyFont.caption.weight(.semibold))
                                Text(L("Sunday at 6 pm. Open the alert and it's written for you.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                            }
                        }.tint(HandyColor.accent).accessibilityIdentifier("care-weekly")
                        NotificationsOffCard(isOff: $notifOff)
                    }
                }

                step(3, "Set up medicines on someone else's phone") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("1. Add their medicines here.")).font(HandyFont.caption)
                        Text(L("2. Tap Send the list — they get the list and a code.")).font(HandyFont.caption)
                        Text(L("3. On their phone: copy the whole message, open Tenzy → Medicine Reminders → Family & caregiver, tap Paste below. Their reminders start straight away.")).font(HandyFont.caption)
                    }.foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    Button { composing = TextDraft(to: [], body: MedCare.shareMessage(store.meds)) } label: {
                        Label(L("Send the list"), systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                    }.secondaryButton().disabled(store.meds.isEmpty).accessibilityIdentifier("care-share")
                    Text(L("Got a list from someone? Copy their message, then:")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    PasteTextButton(wide: true) { t in
                        if let found = MedCare.imported(t) { pasteFound = found } else { note = "That isn't a Tenzy medicine list. Copy the whole message they sent, then tap Paste." }
                    }.accessibilityIdentifier("meds-import")
                    if let found = pasteFound {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(L("Add these")) \(found.count)?").font(HandyFont.caption.weight(.semibold))
                            ForEach(found) { m in Text("• \(m.name) — \(MedSchedule.summary(m))").font(HandyFont.caption) }
                            HStack {
                                Button(L("Add them")) { store.add(found); pasteFound = nil; note = "Added \(found.count) — reminders are on." }.primaryButton()
                                Button(L("Cancel")) { pasteFound = nil }.textButton()
                            }
                        }.cardStyle(padding: HandySpacing.s8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Button { testRun() } label: { Label(L("Test run"), systemImage: "checkmark.seal").frame(maxWidth: .infinity) }
                        .secondaryButton().disabled(store.meds.isEmpty).accessibilityIdentifier("care-test")
                    Text(L("Sends you a dose alert now and its follow-up a few seconds later, exactly as they'll come.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
                if let note { Label(L(note), systemImage: "info.circle").font(HandyFont.caption).foregroundStyle(HandyColor.accent).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(.top, HandySpacing.s8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: { Label(L("Family & caregiver"), systemImage: "figure.2.and.child.holdinghands").font(HandyFont.bodyStrong) }
        .tint(HandyColor.accent)
        .cardStyle(padding: HandySpacing.s12)
        .onChange(of: followUp) { _, _ in store.reschedule() }
        .onChange(of: name) { _, _ in ToolNotifications.shared.install(); if weekly { Task { await MedCare.setWeekly(true, name: name) } } }
        .onChange(of: weekly) { _, on in
            Task {
                if on, !(await NotifyPermission.ensure()) { notifOff = true }
                await MedCare.setWeekly(on, name: name)
                note = on ? "On — every Sunday at 6 pm." : nil
            }
        }
        .sheet(isPresented: $picking) {
            PersonPicker { n, p in picking = false; if let n { name = n }; if let p { phone = p } }.ignoresSafeArea()
        }
        .sheet(item: $composing) { d in
            if TextComposer.canSend {
                TextComposer(draft: d) { composing = nil }.ignoresSafeArea()
            } else {
                // No Messages on this device (an iPad without a phone): share the same words instead.
                NavigationStack {
                    VStack(alignment: .leading, spacing: HandySpacing.s12) {
                        Text(d.body).font(HandyFont.caption).padding(10).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 12))
                        ShareLink(item: d.body) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
                        Spacer()
                    }.padding(HandySpacing.gutter)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { composing = nil } } }
                }
            }
        }
    }

    private func step<Content: View>(_ n: Int, _ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundStyle(HandyColor.onAccent)
                    .frame(width: 22, height: 22).background(HandyColor.accent, in: Circle())
                Text(L(title)).font(HandyFont.bodyStrong).fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func testRun() {
        guard let m = store.meds.first else { return }
        Task {
            guard await NotifyPermission.ensure() else { note = "Notifications are off for Tenzy — turn them on to get reminders."; notifOff = true; return }
            let now = Date()
            let fu = MedCare.followUpMessage(m, dose: now, caregiver: name)
            let msgs: [(String, String)] = [("Test · Time for \(m.name)", [m.dose, m.note].filter { !$0.isEmpty }.joined(separator: " · ")), (fu.title, fu.body)]
            for (i, msg) in msgs.enumerated() {
                let c = UNMutableNotificationContent()
                c.title = i == 0 ? msg.0 : "Test · " + msg.0; c.body = msg.1; c.sound = .default
                c.categoryIdentifier = MedSchedule.category
                c.userInfo = ["med": m.id.uuidString, "dose": now.timeIntervalSince1970]
                let trigger = i == 0 ? nil : UNTimeIntervalNotificationTrigger(timeInterval: 6, repeats: false)
                try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "medtest-\(i)-\(UUID().uuidString)", content: c, trigger: trigger))
            }
            note = "Sent — the dose alert now and its follow-up in a few seconds. Long-press one to see its buttons."
        }
    }
}

/// A text ready to send: who to, and the words.
struct TextDraft: Identifiable { let id = UUID(); let to: [String]; let body: String }

/// Messages' own compose screen, filled in — so the words are always there and the person taps Send.
struct TextComposer: UIViewControllerRepresentable {
    static var canSend: Bool { MFMessageComposeViewController.canSendText() }
    let draft: TextDraft
    let done: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = draft.to.map { $0.filter { $0.isNumber || $0 == "+" } }.filter { !$0.isEmpty }
        vc.body = draft.body
        return vc
    }
    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}
    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let done: () -> Void
        init(done: @escaping () -> Void) { self.done = done }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) { done() }
    }
}

/// Apple's contact picker for one person's name and mobile number. Needs no permission.
struct PersonPicker: UIViewControllerRepresentable {
    let done: (String?, String?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }
    func makeUIViewController(context: Context) -> Host {
        let h = Host()
        h.picker.delegate = context.coordinator
        h.picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        h.picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return h
    }
    func updateUIViewController(_ vc: Host, context: Context) {}
    final class Host: UIViewController {
        let picker = CNContactPickerViewController()
        private var shown = false
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            if !shown { shown = true; present(picker, animated: false) }
        }
    }
    final class Coordinator: NSObject, CNContactPickerDelegate {
        let done: (String?, String?) -> Void
        init(done: @escaping (String?, String?) -> Void) { self.done = done }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName)
            let mobile = contact.phoneNumbers.first { ContactBook.kind(CNLabeledValue<NSString>.localizedString(forLabel: $0.label ?? "")) == "mobile" } ?? contact.phoneNumbers.first
            done(name, mobile?.value.stringValue)
        }
        /// Tapping one number picks that number.
        func contactPicker(_ picker: CNContactPickerViewController, didSelect prop: CNContactProperty) {
            done(CNContactFormatter.string(from: prop.contact, style: .fullName), (prop.value as? CNPhoneNumber)?.stringValue)
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { done(nil, nil) }
    }
}
