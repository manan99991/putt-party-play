import SwiftUI
import UserNotifications

/// In the tool editor: "Tell me when the number in the result…". Shown for tools that end in text.
struct WatchCard: View {
    @Binding var watch: NumberWatch?
    @State private var valueText = ""
    @State private var note: String?
    @State private var notifyOff = false

    private var on: Binding<Bool> {
        Binding(get: { watch != nil }, set: { on in
            if on {
                watch = watch ?? NumberWatch(condition: .above, value: 100, near: "Total")
                valueText = NumberReader.plain(watch?.value ?? 100)
                Task { if !(await NotifyPermission.ensure()) { notifyOff = true } }
            } else { watch = nil }
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Toggle(isOn: on) { Label(L("Tell me when…"), systemImage: "bell.badge").font(HandyFont.bodyStrong) }
                .tint(HandyColor.accent).accessibilityIdentifier("builder-watch")
            Text(L("Each time this tool runs — from Tenzy, a reminder, a Shortcut or the share sheet — it reads the number in the result and tells you when it crosses your line. Once per crossing, never a stream of alerts."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            if let w = watch {
                HandyFlow(spacing: HandySpacing.s8) {
                    ForEach(NumberWatch.Condition.allCases) { c in
                        HChip(text: L(c.label), selected: w.condition == c) { watch?.condition = c }
                    }
                }
                if w.condition != .changes {
                    HStack {
                        Text(L("The number")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        TextField("100", text: $valueText).keyboardType(.decimalPad).textFieldStyle(.handy).frame(width: 120)
                            .onChange(of: valueText) { _, t in if let v = NumberReader.number(t) { watch?.value = v } }
                    }
                }
                HStack {
                    Text(L("Next to the words")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    TextField(L("e.g. Total, Balance, Price"), text: Binding(get: { watch?.near ?? "" }, set: { watch?.near = $0 })).textFieldStyle(.handy)
                }
                NotificationsOffCard(isOff: $notifyOff)
                Button {
                    Task {
                        guard await NotifyPermission.ensure() else { notifyOff = true; return }
                        let c = UNMutableNotificationContent()
                        let sample = w.condition == .below ? w.value - 1 : w.value + 1
                        c.title = L("Test · Tell me when")
                        c.body = NumberReader.message(w, value: sample, previous: w.value, what: w.near.isEmpty ? "The number" : w.near.capitalized)
                        c.sound = .default
                        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "watch-test-\(UUID().uuidString)", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
                        note = L("Test sent — it arrives in 5 seconds. That's what you'll see when it crosses."); note = await NotifyCheck.report()
                    }
                } label: { Label(L("Test run"), systemImage: "checkmark.seal").frame(maxWidth: .infinity) }.secondaryButton()
                if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.success) }
            }
        }
        .cardStyle()
        .onAppear { if let w = watch { valueText = NumberReader.plain(w.value) } }
    }
}

/// Price Watch: "tell me when this page's price drops below $50". Set once; iPhone checks in the background.
struct PriceWatchView: View {
    @State private var pages = PageWatcher.load()
    @State private var adding = false
    @State private var url = ""
    @State private var name = ""
    @State private var watch = NumberWatch(condition: .below, value: 0, near: "")
    @State private var valueText = ""
    @State private var testing = false
    @State private var found: String?
    @State private var notifyOff = false
    @State private var checking = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ToolPage(title: "Price Watch", subtitle: "Tell me when a price on a web page drops — or any number on it changes. Set it once; your phone checks quietly in the background.") {
            HowTo("pricewatch", [
                "Copy the page's link (a product, a flight, a rate) and paste it here.",
                "Choose: drops below, goes above, or changes. Tap Check now to see the number Tenzy reads.",
                "Save. iPhone checks a few times a day when it's charging or idle — light on battery and data — and tells you once when it crosses.",
            ])
            NotificationsOffCard(isOff: $notifyOff)
            if SmartAlerts.backgroundOff {
                LimitNote("Background App Refresh is off, so pages are only checked while Tenzy is open. Turn it on in Settings → General → Background App Refresh.")
            }
            if pages.isEmpty && !adding {
                EmptyState(icon: "bell.badge", line: "No pages watched yet", sub: "Add a product or a flight page and Tenzy tells you when the price drops.")
            }
            ForEach(pages) { p in row(p) }
            if adding { addCard } else if pages.count < PageWatcher.limit {
                Button { startAdding() } label: { Label(L("Watch a page"), systemImage: "plus").frame(maxWidth: .infinity) }.primaryButton()
                    .accessibilityIdentifier("pricewatch-add")
            } else {
                Text(L("Up to 10 pages, to keep it light on your battery.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            if !pages.isEmpty {
                Button {
                    checking = true
                    Task { await PageWatcher.checkAll(force: true); pages = PageWatcher.load(); checking = false }
                } label: { Label(checking ? L("Checking…") : L("Check all now"), systemImage: "arrow.clockwise").frame(maxWidth: .infinity) }
                    .secondaryButton().disabled(checking)
            }
            Text(L("Reads the page the way a browser first gets it. A few shops only show prices after running scripts — Check now tells you straight away if a page won't work. Nothing about you is sent anywhere."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear { pages = PageWatcher.load() }
    }

    private func row(_ p: PageWatch) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(p.name).font(HandyFont.bodyStrong).lineLimit(1)
                Spacer()
                if let v = p.lastValue { Text(NumberReader.plain(v)).font(HandyFont.bodyStrong).monospacedDigit() }
            }
            Text(L(p.watch.condition == .changes ? "Tells you when it changes" : "Tells you when it \(p.watch.condition.label) \(NumberReader.plain(p.watch.value))"))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            if let problem = p.problem { Text(L(problem)).font(HandyFont.caption).foregroundStyle(HandyColor.danger).fixedSize(horizontal: false, vertical: true) }
            else if let t = p.lastChecked { Text("\(L("Checked")) \(t.formatted(.relative(presentation: .named)))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
            HStack {
                Button { openURL(p.url) } label: { Label(L("Open page"), systemImage: "safari") }.compactButton()
                Spacer()
                Button(role: .destructive) { pages.removeAll { $0.id == p.id }; PageWatcher.save(pages) } label: { Image(systemName: "trash").accessibilityLabel(L("Stop watching")) }.compactButton()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            TextField(L("Paste the page link"), text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.handy)
                .accessibilityIdentifier("pricewatch-url")
            if url.isEmpty {
                // PasteButton reads the clipboard only when tapped — no "allow paste" pop-up.
                PasteButton(payloadType: URL.self) { urls in if let u = urls.first { url = u.absoluteString } }
                    .buttonBorderShape(.capsule).labelStyle(.titleAndIcon)
            }
            TextField(L("Name, e.g. Running shoes"), text: $name).textFieldStyle(.handy)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(NumberWatch.Condition.allCases) { c in HChip(text: L(c.label), selected: watch.condition == c) { watch.condition = c } }
            }
            if watch.condition != .changes {
                HStack {
                    Text(L("The number")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    TextField(L("e.g. 50"), text: $valueText).keyboardType(.decimalPad).textFieldStyle(.handy).frame(width: 120)
                        .onChange(of: valueText) { _, t in if let v = NumberReader.number(t) { watch.value = v } }
                }
            }
            TextField(L("Words next to it (optional), e.g. Price, Sale"), text: $watch.near).textFieldStyle(.handy)
            Button { Task { await testNow() } } label: {
                Label(testing ? L("Checking…") : L("Check now"), systemImage: "magnifyingglass").frame(maxWidth: .infinity)
            }.secondaryButton().disabled(testing || pageURL == nil).accessibilityIdentifier("pricewatch-test")
            if let found { Text(found).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
            HStack {
                Button(L("Cancel")) { adding = false }.textButton()
                Spacer()
                Button { Task { await saveNew() } } label: { Label(L("Start watching"), systemImage: "bell.badge.fill") }
                    .primaryButton().disabled(pageURL == nil || (watch.condition != .changes && valueText.isEmpty))
                    .accessibilityIdentifier("pricewatch-save")
            }
        }
        .cardStyle()
    }

    private var pageURL: URL? {
        var s = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty, !s.lowercased().hasPrefix("http") { s = "https://" + s }
        guard let u = URL(string: s), u.host?.contains(".") == true else { return nil }
        return u
    }

    private func startAdding() {
        adding = true; found = nil; name = ""; valueText = ""
        watch = NumberWatch(condition: .below, value: 0, near: "")
        url = ""
    }

    /// The Test run: fetch the page now and show the number Tenzy would watch.
    private func testNow() async {
        guard let u = pageURL else { return }
        testing = true; found = nil
        let probe = PageWatch(name: name.isEmpty ? (u.host ?? "Page") : name, url: u, watch: watch)
        let (r, _) = await PageWatcher.check(probe)
        testing = false
        if let v = r.lastValue {
            var m = WatchMemory()
            let past = watch.condition != .changes && NumberReader.evaluate(watch, value: v, memory: &m)
            found = "\(L("Found")) \(NumberReader.plain(v)). " + (watch.condition == .changes ? L("You'll hear when it changes.")
                    : (past ? L("It's already past your number — you'd get an alert on the first check.") : L("Not past your number yet — you'll get one alert when it is.")))
            if valueText.isEmpty, watch.condition == .below { valueText = NumberReader.plain((v * 0.9).rounded()) }
        } else {
            found = r.problem.map { L($0) } ?? L("No number found on the page.")
        }
    }

    private func saveNew() async {
        guard let u = pageURL else { return }
        if !(await NotifyPermission.ensure()) { notifyOff = true }
        var p = PageWatch(name: name.trimmingCharacters(in: .whitespaces).isEmpty ? (u.host ?? "Page") : name, url: u, watch: watch)
        let (checked, line) = await PageWatcher.check(p)
        p = checked
        pages.append(p); PageWatcher.save(pages)
        if let line { PageWatcher.post(p, line) }
        SmartAlerts.scheduleBackground()
        adding = false
        HandyHaptics.success()
    }
}
