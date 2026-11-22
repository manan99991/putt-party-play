import SwiftUI
import UserNotifications

/// The personal-assistant hub: everything Tenzy does for you on its own, in one place — every reminder and alert that
/// is set, when it next fires, a Test run that proves it reaches you, the count alerts with an on/off, and the
/// automations you could set up next. Each tool still owns its own settings; this page reads what the phone is
/// actually holding, so what it shows is always true.
enum AutomationGroups {
    struct Group: Equatable { let key: String; let title: String; let icon: String; let tool: String }

    /// Which tool a waiting reminder belongs to, from its identifier (each tool names its own) or its "open" hint.
    static func group(id: String, open: String? = nil) -> Group {
        let table: [(prefixes: [String], g: Group)] = [
            (["med-", "medfu-", "medrefill-"], Group(key: "med", title: "Medicines", icon: "pills.fill", tool: "medreminder")),
            (["daily-brief"], Group(key: "brief", title: "Morning Summary", icon: "sun.max.fill", tool: "brief")),
            (["bday-"], Group(key: "bday", title: "Birthdays", icon: "gift.fill", tool: "contacts")),
            (["contacts-backup"], Group(key: "backup", title: "Contacts backup", icon: "person.crop.circle.badge.checkmark", tool: "contacts")),
            (["plan-", "arrive-", "untangle-"], Group(key: "plans", title: "Plans and arrivals", icon: "mappin.and.ellipse", tool: "untangle")),
            (["sorted-"], Group(key: "bills", title: "Bills and letters", icon: "doc.text.fill", tool: "sorted")),
            (["warranty-", "return-"], Group(key: "warranty", title: "Warranties and returns", icon: "shield.lefthalf.filled", tool: "warranty")),
            (["vault-exp-"], Group(key: "vault", title: "Documents expiring", icon: "lock.doc.fill", tool: "vault")),
            (["tool-"], Group(key: "tools", title: "Tool reminders", icon: "square.stack.3d.up.fill", tool: "builder")),
            (["watch-", "pricewatch"], Group(key: "watch", title: "Tell me when · Price Watch", icon: "bell.badge.fill", tool: "pricewatch")),
            (["park-meter"], Group(key: "park", title: "Parking meter", icon: "parkingsign.circle.fill", tool: "gpsdash")),
            (["rest-"], Group(key: "rest", title: "Bedtime", icon: "moon.zzz.fill", tool: "rest")),
            (["planner."], Group(key: "planner", title: "Morning plan", icon: "list.bullet.clipboard", tool: "planner")),
            (["daydiary-"], Group(key: "diary", title: "Mood Diary", icon: "book.closed.fill", tool: "daydiary")),
            (["smart-"], Group(key: "smart", title: "Phone alerts", icon: "iphone.gen3", tool: "cleaner")),
        ]
        for row in table where row.prefixes.contains(where: { id.hasPrefix($0) }) { return row.g }
        if let open, let row = table.first(where: { $0.g.tool == open }) { return row.g }
        return Group(key: "other", title: "Other reminders", icon: "bell.fill", tool: open ?? "")
    }

    /// Reminders that are only part of a test or a one-off (a snooze, a Test run) — not shown as set-up automations.
    static func isOneOff(_ id: String) -> Bool { id.contains("test") || id.hasPrefix("med-snooze") || id.hasPrefix("done-") }

    /// What can be set up next, each one tap to the tool that does it. Shown only for what isn't set yet.
    static let ideas: [(key: String, title: String, detail: String, icon: String, tool: String)] = [
        ("med", "Medicine reminders", "A Taken button, refills, a nudge if you miss one", "pills.fill", "medreminder"),
        ("brief", "A morning brief", "Today's doses, bills, birthdays and weather in one note", "sun.max.fill", "brief"),
        ("backup", "Back up my contacts every month", "A dated copy in Files, so a lost phone isn't lost contacts", "person.crop.circle.badge.checkmark", "contacts"),
        ("bday", "Birthday reminders", "A day early, with a wish ready to send", "gift.fill", "contacts"),
        ("bills", "Bill reminders", "Snap a bill; get told before it's due", "doc.text.fill", "sorted"),
        ("smart", "Tell me when my phone fills up", "Screenshots piling up, space running low, big videos", "iphone.gen3", "cleaner"),
        ("watch", "Watch a price", "Told when a price on a web page drops", "bell.badge.fill", "pricewatch"),
        ("tools", "Run one of my tools on a schedule", "e.g. 'scan my receipts every Friday at 6'", "square.stack.3d.up.fill", "builder"),
        ("rest", "A bedtime nudge", "A wind-down reminder at the same time each night", "moon.zzz.fill", "rest"),
    ]
}

struct AutomationsView: View {
    /// Shown as the My stuff tab: its own header with Settings, My tools and History above the reminders.
    var tab = false
    private struct Row: Identifiable { let id: String; let group: AutomationGroups.Group; let count: Int; let next: Date?; let sample: UNNotificationRequest }

    @State private var rows: [Row] = []
    @State private var rules: [SmartAlerts.Rule] = AlertStore.load()
    @State private var denied = false
    @State private var loaded = false
    @State private var tested: String?
    @State private var adding = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                if tab { tabHeader } else {
                    ToolHero(title: L("Your automations"), subtitle: L("Everything Tenzy does for you on its own, in one place."),
                             tint: HandyColor.accent, steps: [], hint: nil) {
                        Image(systemName: "bolt.badge.clock.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(HandyColor.accent)
                            .frame(width: 52, height: 52).background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                if denied { notificationsOff }
                SectionLabel(text: L("Set and running"), icon: "checkmark.seal.fill")
                if !loaded {
                    HStack { BusySpinner(); Text(L("Looking at what's set…")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                } else if rows.isEmpty && rules.filter(\.on).isEmpty {
                    Text(L("Nothing is set yet. Pick one below — each takes a minute and has a Test run."))
                        .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).cardStyle()
                }
                ForEach(rows) { r in running(r) }
                ForEach(rules.filter(\.on)) { r in ruleRow(r) }
                // The ready-made ones not set yet, right here (no extra screen), then your own.
                let ideas = AutomationGroups.ideas.filter { !Set(rows.map(\.group.key)).contains($0.key) }
                if !ideas.isEmpty {
                    SectionLabel(text: L("Switch one on"), icon: "plus.circle.fill")
                    ForEach(ideas, id: \.key) { i in ideaRow(i) }
                }
                SectionLabel(text: L("Your own"), icon: "wand.and.stars")
                Button { open("builder") } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(L("Build a custom automation"), systemImage: "sparkles").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                        Text(L("Make a tool in Build your own, then give it a time — it reminds you and opens ready to run."))
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).cardStyle(padding: HandySpacing.s12).accessibilityIdentifier("auto-own")
                Text(L("Reminders come from iPhone itself, so they arrive even when Tenzy is closed. Turn one off inside its tool."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(HandySpacing.gutter)
        }
        .background(Ground())
        .accessibilityIdentifier("automations")
        .task { await load() }
        .sheet(isPresented: $adding, onDismiss: { Task { await load() } }) {
            NewAutomationSheet(already: Set(rows.map(\.group.key))) { tool in adding = false; open(tool) }
        }
    }

    private var tabHeader: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack {
                Text(L("My stuff")).font(HandyFont.display)
                Spacer()
                NavigationLink(value: "settings") {
                    Image(systemName: "gearshape").font(.system(size: 18)).foregroundStyle(HandyColor.textSecondary).frame(width: 44, height: 44)
                }.accessibilityLabel(L("Settings")).accessibilityIdentifier("settings-tab")
            }
            HStack(spacing: HandySpacing.s8) {
                shortcut(ChainStore.load().isEmpty ? "My tools" : "My tools · \(ChainStore.load().count)", "square.stack.3d.up.fill", "mytools")
                shortcut("History", "clock.arrow.circlepath", "results")
            }
        }
    }

    private func shortcut(_ title: String, _ icon: String, _ route: String) -> some View {
        NavigationLink(value: route) {
            Label(L(title), systemImage: icon).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
        }.buttonStyle(.plain).cardStyle(padding: HandySpacing.s8).accessibilityIdentifier("mine-\(route)")
    }

    /// A ready-made reminder not set yet: phone alerts and the contacts backup are set right here; the rest open their tool.
    private func ideaRow(_ i: (key: String, title: String, detail: String, icon: String, tool: String)) -> some View {
        Button { if i.key == "smart" || i.key == "backup" { adding = true } else { open(i.tool) } } label: {
            HStack(spacing: HandySpacing.s12) {
                Image(systemName: i.icon).foregroundStyle(HandyColor.accent).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(i.title)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    Text(L(i.detail)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).cardStyle(padding: HandySpacing.s12).accessibilityIdentifier("auto-idea-\(i.key)")
    }

    private var notificationsOff: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Notifications are off for Tenzy"), systemImage: "bell.slash.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.danger)
            Text(L("Nothing below can reach you until they're on.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Button { if let u = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(u) } } label: {
                Label(L("Turn on notifications"), systemImage: "gearshape").frame(maxWidth: .infinity)
            }.primaryButton()
        }.cardStyle()
    }

    private func running(_ r: Row) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(spacing: HandySpacing.s12) {
                Image(systemName: r.group.icon).foregroundStyle(HandyColor.accent).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(r.group.title)).font(HandyFont.bodyStrong)
                    Text(when(r)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "checkmark.circle.fill").foregroundStyle(HandyColor.success)
            }
            HStack(spacing: HandySpacing.s8) {
                Button { testRun(r) } label: { Label(tested == r.id ? L("Sent — check the top of the screen") : L("Test run"), systemImage: "paperplane").frame(maxWidth: .infinity) }
                    .compactButton().accessibilityIdentifier("auto-test-\(r.group.key)")
                if !r.group.tool.isEmpty {
                    Button { open(r.group.tool) } label: { Label(L("Open"), systemImage: "arrow.up.right").frame(maxWidth: .infinity) }.compactButton()
                }
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityIdentifier("auto-\(r.group.key)")
    }

    private func ruleRow(_ r: SmartAlerts.Rule) -> some View {
        let due = r.lastValue.map { SmartAlerts.crossed(r, value: $0) } ?? false
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(spacing: HandySpacing.s12) {
                Image(systemName: r.kind == .lowSpace ? "internaldrive" : r.kind == .screenshots ? "camera.viewfinder" : "film.stack")
                    .foregroundStyle(HandyColor.accent).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(r.kind.title)).font(HandyFont.bodyStrong).fixedSize(horizontal: false, vertical: true)
                    Text("\(L(r.kind.sentence.before)) \(SmartAlerts.number(r.limit, r.kind)) \(L(r.kind.sentence.after))")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: Binding(get: { r.on }, set: { on in
                    var n = r; n.on = on; AlertStore.upsert(n); rules = AlertStore.load()
                })).labelsHidden().tint(HandyColor.accent)
            }
            if r.on, let v = r.lastValue {
                Label("\(SmartAlerts.number(v, r.kind)) \(L("now"))\(due ? " — " + L("due") : "")", systemImage: "circle.fill")
                    .font(HandyFont.caption.weight(.semibold)).foregroundStyle(due ? HandyColor.danger : HandyColor.success)
                    .accessibilityIdentifier("auto-progress-\(r.kind.rawValue)")
            }
            if r.on {
                Button { open(r.kind.opens) } label: { Label(L("Do it now"), systemImage: "sparkles").frame(maxWidth: .infinity) }.compactButton()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityIdentifier("auto-rule-\(r.kind.rawValue)")
    }

    private func when(_ r: Row) -> String {
        let n = r.count == 1 ? L("1 reminder set") : "\(r.count) \(L("reminders set"))"
        guard let d = r.next else { return n }
        return "\(n) · \(L("next")) \(d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))"
    }

    private func open(_ tool: String) { NotificationCenter.default.post(name: .openTool, object: tool, userInfo: ["from": "automations"]) }

    /// A copy of the next real reminder, delivered in a few seconds: proves notifications reach this phone.
    private func testRun(_ r: Row) {
        guard let c = r.sample.content.mutableCopy() as? UNMutableNotificationContent else { return }
        c.title = "\(L("Test")) · \(c.title)"
        let req = UNNotificationRequest(identifier: "auto-test-\(UUID().uuidString)", content: c,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false))
        UNUserNotificationCenter.current().add(req)
        tested = r.id
    }

    private func load() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let pending = await center.pendingNotificationRequests()
        var by: [String: [UNNotificationRequest]] = [:]
        var groups: [String: AutomationGroups.Group] = [:]
        for p in pending where !AutomationGroups.isOneOff(p.identifier) {
            let g = AutomationGroups.group(id: p.identifier, open: p.content.userInfo["open"] as? String)
            by[g.key, default: []].append(p); groups[g.key] = g
        }
        func next(_ p: UNNotificationRequest) -> Date? {
            (p.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? (p.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
        }
        let built: [Row] = by.compactMap { k, ps in
            guard let g = groups[k] else { return nil }
            let sorted = ps.sorted { (next($0) ?? .distantFuture) < (next($1) ?? .distantFuture) }
            return Row(id: k, group: g, count: ps.count, next: sorted.first.flatMap(next), sample: sorted[0])
        }.sorted { ($0.next ?? .distantFuture) < ($1.next ?? .distantFuture) }
        // Show what's set straight away; the count alerts' live numbers fill in after.
        await MainActor.run { rows = built; denied = settings.authorizationStatus == .denied; loaded = true }
        // The live number for each count alert, so the card shows where it stands right now.
        var fresh = AlertStore.load()
        for i in fresh.indices where fresh[i].on {
            let k = fresh[i].kind
            if let v = await Task.detached(priority: .utility, operation: { SmartAlerts.read(k) }).value {
                fresh[i].lastValue = v; fresh[i].lastChecked = Date()
            }
        }
        AlertStore.save(fresh)
        await MainActor.run {
            rows = built
            rules = fresh
            denied = settings.authorizationStatus == .denied
            loaded = true
        }
    }
}

/// "+ New automation", as in the approved prototype: when a count builds up, on a schedule, or your own. The count
/// alerts and the contacts backup are set right here with the same cards their tools use; the rest open the tool
/// that sets them up, already where the setting is.
struct NewAutomationSheet: View {
    let already: Set<String>
    var open: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var backup = ContactsBackup()
    @State private var testedBackup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s16) {
                    Text(L("Pick what Tenzy should look after. Everything runs on your phone."))
                        .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)

                    SectionLabel(text: L("When a count builds up"), icon: "chart.bar.fill")
                    ForEach(SmartAlerts.Kind.allCases) { k in SmartAlertCard(kind: k).cardStyle(padding: HandySpacing.s12) }

                    SectionLabel(text: L("On a schedule"), icon: "calendar")
                    VStack(alignment: .leading, spacing: HandySpacing.s8) {
                        Label(L("Back up my contacts"), systemImage: "person.crop.circle.badge.checkmark").font(HandyFont.bodyStrong)
                        Text(L("A dated copy of everyone in Files, on the schedule you pick, with a nudge when it's saved."))
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                        Picker(L("How often"), selection: $backup.frequency) {
                            ForEach([BackupFrequency.off, .weekly, .monthly, .quarterly], id: \.self) { Text(L($0.title)).tag($0) }
                        }.pickerStyle(.segmented)
                        if backup.frequency != .off {
                            Button {
                                Task { await ContactBackupReminder.testRun(); testedBackup = true }
                            } label: { Label(testedBackup ? L("Sent — check the top of the screen") : L("Test run"), systemImage: "paperplane").frame(maxWidth: .infinity) }
                                .compactButton()
                        }
                    }.cardStyle(padding: HandySpacing.s12).accessibilityIdentifier("auto-new-backup")

                }
                .padding(HandySpacing.gutter)
            }
            .background(Ground())
            .navigationTitle(L("Alerts and backup")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() } } }
        }
    }
}
