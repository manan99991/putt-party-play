import SwiftUI
import Photos

/// "Notify me" for a "tell me when…" alert: one switch, the number in a sentence (tap a common one or type
/// your own), the exact message it will send, a test button, and an honest line about when it checks.
struct SmartAlertCard: View {
    let kind: SmartAlerts.Kind
    @State private var rule: SmartAlerts.Rule
    @State private var custom = ""
    @State private var notifOff = false
    @State private var photosOff = false
    @State private var current: Double?
    @State private var bgOff = false
    @FocusState private var typing: Bool

    init(kind: SmartAlerts.Kind) {
        self.kind = kind
        _rule = State(initialValue: AlertStore.rule(kind) ?? SmartAlerts.Rule(kind: kind, limit: kind.defaultLimit, on: false))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Toggle(isOn: $rule.on) { Label(L(kind.title), systemImage: "bell.badge").font(HandyFont.bodyStrong) }.tint(HandyColor.accent)
            if rule.on {
                Text("\(L(kind.sentence.before)) \(SmartAlerts.number(rule.limit, kind)) \(L(kind.sentence.after)).")
                    .font(HandyFont.body).fixedSize(horizontal: false, vertical: true)
                HandyFlow(spacing: HandySpacing.s8) {
                    ForEach(kind.choices, id: \.self) { v in
                        HChip(text: SmartAlerts.number(v, kind), selected: rule.limit == v) { rule.limit = v; custom = "" }
                    }
                    TextField(L("Other"), text: $custom).keyboardType(.decimalPad).focused($typing)
                        .frame(width: 80).textFieldStyle(.roundedBorder)
                        .onChange(of: custom) { _, t in if let v = Double(t.replacingOccurrences(of: ",", with: ".")), v > 0 { rule.limit = v } }
                }
                if let c = current {
                    Text("\(L("Right now:")) \(SmartAlerts.number(c, kind)) \(L(kind == .screenshots ? "screenshots" : "GB"))\(SmartAlerts.crossed(rule, value: c) ? " — " + L("past your limit, so you'd get this today.") : ".")")
                        .font(HandyFont.caption).foregroundStyle(SmartAlerts.crossed(rule, value: c) ? HandyColor.amber : HandyColor.textSecondary)
                }
                preview
                NotificationsOffCard(isOff: $notifOff)
                if photosOff {
                    Label(L("This alert counts what's in Photos, so Tenzy needs Photos access."), systemImage: "photo.badge.exclamationmark")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.amber)
                    Button(L("Allow Photos access")) { askPhotos() }.compactButton()
                } else if kind.needsPhotos, SmartAlerts.photosLimited {
                    Text(L("Tenzy can only see the photos you chose, so the count covers those. Allow full access in Settings for an exact count."))
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
                Text(bgOff
                     ? L("Checks run each time you open Tenzy. Turn on Background App Refresh for Tenzy in Settings so it can also check during the day.")
                     : L("Checks run each time you open Tenzy and a few times a day in the background, when iPhone allows. At most one alert a day."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                if let t = rule.lastChecked {
                    Text("\(L("Last checked")) \(t.formatted(date: .abbreviated, time: .shortened))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .onChange(of: rule.on) { _, on in turned(on) }
        .onChange(of: rule.limit) { _, _ in AlertStore.upsert(rule) }
        .task { refresh(); if rule.on { notifOff = await NotifyPermission.state() == .off } }
    }

    private var preview: some View {
        let m = SmartAlerts.message(kind, value: current.map { SmartAlerts.crossed(rule, value: $0) ? $0 : sample } ?? sample, limit: rule.limit)
        return VStack(alignment: .leading, spacing: 4) {
            Text(L("What you'll see")).font(HandyFont.micro.weight(.bold)).foregroundStyle(HandyColor.textSecondary)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "app.badge.fill").foregroundStyle(HandyColor.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.title).font(HandyFont.caption.weight(.semibold))
                    Text(m.body).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 12))
            Button { Task { if await NotifyPermission.ensure() { SmartAlerts.post(kind, value: current ?? sample, limit: rule.limit, test: true) } else { notifOff = true } } } label: {
                Label(L("Send me a test"), systemImage: "paperplane")
            }.compactButton()
        }
    }

    /// A believable "past the limit" number for the preview when the real one is under it.
    private var sample: Double { kind.firesAbove ? (kind == .screenshots ? rule.limit + 12 : rule.limit * 1.2) : max(0.5, rule.limit * 0.6) }

    private func turned(_ on: Bool) {
        AlertStore.upsert(rule)
        guard on else { return }
        Task {
            let ok = await NotifyPermission.ensure()
            await MainActor.run { notifOff = !ok }
            if kind.needsPhotos, !SmartAlerts.photosAllowed() { askPhotos() }
            SmartAlerts.scheduleBackground()
            await SmartAlerts.checkAll()
            await MainActor.run { refresh() }
        }
    }

    private func askPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in DispatchQueue.main.async { refresh() } }
    }

    private func refresh() {
        photosOff = kind.needsPhotos && !SmartAlerts.photosAllowed() && PHPhotoLibrary.authorizationStatus(for: .readWrite) != .notDetermined
        bgOff = SmartAlerts.backgroundOff
        if let r = AlertStore.rule(kind) { rule.lastChecked = r.lastChecked }
        let k = kind
        Task.detached(priority: .utility) {
            let v = SmartAlerts.read(k)
            await MainActor.run { current = v }
        }
    }
}

/// Every "tell me when…" alert in one place.
struct MyAlertsView: View {
    var body: some View {
        ToolPage(title: "My alerts", subtitle: "Tenzy taps you on the shoulder only when it matters.", working: false) {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                ForEach(SmartAlerts.Kind.allCases) { SmartAlertCard(kind: $0) }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
    }
}
