import SwiftUI
import CoreLocation

/// Daily brief — set once: a time each morning. You get one short notification with today's medicines, bills and
/// letters coming due, birthdays and one tidy-up nudge; tap it for this page, with the weather and what to wear.
struct DailyBriefView: View {
    @AppStorage("brief.on") private var on = false
    @AppStorage("brief.hour") private var hour = 7
    @AppStorage("brief.minute") private var minute = 0
    @State private var lines: [String] = []
    @State private var loading = true
    @State private var notifOff = false
    @State private var note: String?
    @StateObject private var weather = WeatherNow()
    @StateObject private var places = NearbyPlaces()

    private var time: Binding<Date> {
        Binding(get: { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date() },
                set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); hour = c.hour ?? 7; minute = c.minute ?? 0 })
    }

    var body: some View {
        ToolPage(title: "Daily Brief", subtitle: "One short note each morning with what matters today — set it once and it just comes.", working: false) {
            HowTo("brief", [
                "Turn it on and pick a time — 7 AM is a good start.",
                "Each morning you get one notification: medicines, bills and letters due, birthdays, a tidy-up nudge.",
                "Tap it for this page, with the weather and what to wear. Tap Test run any time to see it now.",
            ])
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Toggle(isOn: $on) { Label(L("Send me a daily brief"), systemImage: "sun.horizon.fill").font(HandyFont.bodyStrong) }.tint(HandyColor.accent)
                    .accessibilityIdentifier("brief-on")
                if on {
                    DatePicker(L("Every morning at"), selection: time, displayedComponents: .hourAndMinute)
                    NotificationsOffCard(isOff: $notifOff)
                    Button { Task { await DailyBrief.testRun(); note = "Test sent — check your notifications. That's what each morning looks like." } } label: {
                        Label(L("Test run"), systemImage: "checkmark.seal").frame(maxWidth: .infinity)
                    }.secondaryButton().accessibilityIdentifier("brief-test")
                    if let note { Label(L(note), systemImage: "checkmark.circle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
                }
                Text(L("It's built from what's already in Tenzy — Medicine Reminders, Sorted (bills and letters), your contacts' birthdays and the Cleaner alerts. Add things there and they show up here."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }.cardStyle(padding: HandySpacing.s12)

            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text(L("Today")).font(HandyFont.cardTitle)
                if loading { HStack { BusySpinner(); Text(L("Gathering your day…")).font(HandyFont.caption) } }
                else if lines.isEmpty {
                    Text(L("Nothing pressing today. Enjoy it.")).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                } else {
                    ForEach(lines, id: \.self) { Text($0).font(HandyFont.body).fixedSize(horizontal: false, vertical: true) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)

            if weather.snapshot != nil || weather.loading {
                WeatherWearCard(weather: weather, unwell: false, goingOut: true)
            } else {
                Button { weather.load(using: places) } label: { Label(L("Show today's weather and what to wear"), systemImage: "cloud.sun") }.compactButton()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L("Where it comes from")).font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.textSecondary)
                HandyFlow(spacing: HandySpacing.s8) {
                    link("Medicines", "medreminder", "pills.fill")
                    link("Bills & letters", "sorted", "doc.text")
                    link("Birthdays", "contacts", "gift")
                    link("Tidy-up alerts", "cleaner", "sparkles")
                }
            }
        }
        .task {
            MedStore.shared.addSampleIfEmpty()
            await load()
            // Weather only when location is already allowed — never a surprise permission prompt on open.
            let st = CLLocationManager().authorizationStatus
            if st == .authorizedWhenInUse || st == .authorizedAlways { weather.load(using: places) }
        }
        .onChange(of: on) { _, v in
            Task {
                if v { let ok = await NotifyPermission.ensure(); notifOff = !ok }
                await DailyBrief.refresh()
            }
        }
        .onChange(of: hour) { _, _ in Task { await DailyBrief.refresh() } }
        .onChange(of: minute) { _, _ in Task { await DailyBrief.refresh() } }
    }

    private func link(_ title: String, _ tool: String, _ icon: String) -> some View {
        Button { NotificationCenter.default.post(name: .openTool, object: tool) } label: { Label(L(title), systemImage: icon) }.compactButton()
    }

    private func load() async {
        loading = true
        let now = Date()
        lines = DailyBrief.compose(await DailyBrief.gather(for: now), for: now).lines
        loading = false
    }
}
