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
            (["daily-brief"], Group(key: "brief", title: "Daily brief", icon: "sun.max.fill", tool: "brief")),
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
            (["daydiary-"], Group(key: "diary", title: "My Day", icon: "book.closed.fill", tool: "daydiary")),
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
    private struct Row: Identifiable { let id: String; let group: AutomationGroups.Group; let count: Int; let next: Date?; let sample: UNNotificationRequest }

    @State private var rows: [Row] = []
    @State private var rules: [SmartAlerts.Rule] = AlertStore.load()
    @State private var denied = false
    @State private var loaded = false
    @State private var tested: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                ToolHero(title: L("Your automations"), subtitle: L("Everything Tenzy does for you on its own, in one place."),
                         tint: HandyColor.accent, steps: [], hint: nil) {
                    Image(systemName: "bolt.badge.clock.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(HandyColor.accent)
                        .frame(width: 52, height: 52).background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                ForEach(rules) { r in ruleRow(r) }
                let set = Set(rows.map(\.group.key) + (rules.contains(where: \.on) ? ["smart"] : []))
                let ideas = AutomationGroups.ideas.filter { !set.contains($0.key) }
                if !ideas.isEmpty {
                    SectionLabel(text: L("Set one up"), icon: "plus.circle.fill")
                    VStack(spacing: 0) {
                        ForEach(ideas, id: \.key) { i in
                            Button { open(i.tool) } label: {
                                HStack(spacing: HandySpacing.s12) {
                                    Image(systemName: i.icon).foregroundStyle(HandyColor.accent).frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(L(i.title)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                                        Text(L(i.detail)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                                }.padding(.vertical, 10).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("auto-idea-\(i.key)")
                            if i.key != ideas.last?.key { Divider() }
                        }
                    }.cardStyle(padding: HandySpacing.s12)
                }
                Text(L("Reminders come from iPhone itself, so they arrive even when Tenzy is closed. Turn one off inside its tool."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(HandySpacing.gutter)
        }
        .background(Ground())
        .accessibilityIdentifier("automations")
        .task { await load() }
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
        HStack(spacing: HandySpacing.s12) {
            Image(systemName: "iphone.gen3").foregroundStyle(HandyColor.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(L(r.kind.title)).font(HandyFont.bodyStrong).fixedSize(horizontal: false, vertical: true)
                if let v = r.lastValue, let c = r.lastChecked {
                    Text("\(L("Last checked")) \(c.formatted(.relative(presentation: .named))) · \(Int(v))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Toggle("", isOn: Binding(get: { r.on }, set: { on in
                var n = r; n.on = on; AlertStore.upsert(n); rules = AlertStore.load()
            })).labelsHidden().tint(HandyColor.accent)
        }
        .cardStyle(padding: HandySpacing.s12)
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
        await MainActor.run {
            rows = built
            rules = AlertStore.load()
            denied = settings.authorizationStatus == .denied
            loaded = true
        }
    }
}
