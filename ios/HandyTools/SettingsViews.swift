import SwiftUI
import StoreKit
import UserNotifications
import AlarmKit

let PRIVACY_URL = URL(string: "https://manan99991.github.io/tenzy/privacy.html")!
let SUPPORT_EMAIL = "tenzy.app@gmail.com"

extension View {
    /// Floating close button for sheet-presented pages, so users aren't forced to swipe to dismiss.
    func sheetCloseButton(_ onClose: @escaping () -> Void) -> some View {
        overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(HandyColor.textSecondary, HandyColor.surface)
            }
            .padding(.top, HandySpacing.s12)
            .padding(.trailing, HandySpacing.s16)
            .accessibilityLabel("Close")
        }
    }
}

// MARK: - One-time setup

/// iPhone needs far less than Android: notifications (for alarms), alarm permission, and the Clips keyboard.
/// Each is one tap. Shown once after onboarding; reachable later from Settings › Permissions.
struct SetupView: View {
    let onDone: () -> Void
    @State private var notifs = false
    @State private var alarms = false
    @State private var tick = 0
    @Environment(\.scenePhase) private var phase

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s12) {
                    Text("Set up once").font(HandyFont.display)
                    Text("Three switches, one tap each. After this page Tenzy won't ask again.").font(.system(size: 15)).foregroundStyle(HandyColor.textSecondary)
                    Text("\([notifs, alarms].filter { $0 }.count) of 3 done").font(HandyFont.micro).foregroundStyle(HandyColor.accent)
                    SetupRow(icon: "bell.badge", title: "Notifications", why: "The alarm itself, and a quiet 'saved' confirmation now and then.", unlocks: "Alarm Pro", granted: notifs) {
                        Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]); await refresh() }
                    }
                    SetupRow(icon: "alarm", title: "Alarms", why: "Lets Tenzy ring through Silent mode and Focus, like the Clock app.", unlocks: "Alarm Pro", granted: alarms) {
                        Task { alarms = (try? await AlarmManager.shared.requestAuthorization()) == .authorized }
                    }
                    SetupRow(icon: "keyboard", title: "Clips keyboard", why: "Settings › General › Keyboard › Keyboards › Add New. Allow Full Access: it only reads the clipboard when you tap Grab.", unlocks: "Multi-Clipboard", granted: false, buttonLabel: "Open Settings") {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    }
                    Text("Everything stays on your iPhone. No account, no cloud. Camera, microphone and photos are asked for by the tool that needs them, when you first use it.")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                .padding(.horizontal, HandySpacing.gutter).padding(.vertical, HandySpacing.s16)
            }
            Button("Done for now") { onDone() }.primaryButton().padding(.horizontal, HandySpacing.gutter).padding(.bottom, HandySpacing.s16)
        }
        .background(HandyColor.bg)
        .task { await refresh() }
        .onChange(of: phase) { _, p in if p == .active { Task { await refresh() } } }
    }

    private func refresh() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        notifs = s.authorizationStatus == .authorized
        alarms = AlarmManager.shared.authorizationState == .authorized
    }
}

private struct SetupRow: View {
    let icon: String, title: String, why: String, unlocks: String, granted: Bool
    var buttonLabel = "Allow"
    let action: () -> Void
    var body: some View {
        HStack(alignment: .center, spacing: HandySpacing.s12) {
            ZStack {
                Circle().fill(granted ? HandyColor.accent : HandyColor.accentSoft).frame(width: 40, height: 40)
                Image(systemName: granted ? "checkmark" : icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(granted ? .white : HandyColor.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(HandyFont.bodyStrong)
                Text(why).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Text(unlocks).font(HandyFont.micro).foregroundStyle(HandyColor.accent)
            }
            Spacer(minLength: HandySpacing.s8)
            if !granted { Button(buttonLabel, action: action).compactButton() }
        }
        .cardStyle()
        .background(granted ? HandyColor.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
        .animation(.easeOut(duration: HandyMotion.base), value: granted)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var store: StoreManager
    @State private var showPaywall = false
    @State private var showSetup = false
    @State private var showPrivacy = false
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text("Settings").font(HandyFont.display).padding(.bottom, HandySpacing.s8)

                    Button { if !store.isPremium { showPaywall = true } } label: {
                        HStack(spacing: HandySpacing.s12) {
                            ZStack {
                                Circle().fill(store.isPremium ? HandyColor.accent : HandyColor.accentSoft).frame(width: 44, height: 44)
                                Image(systemName: "crown.fill").foregroundStyle(store.isPremium ? .white : HandyColor.accent)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.isPremium ? "Tenzy Pro" : "Go Pro").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                                Text(store.isPremium ? "Ads off. Renews yearly at $9.99." : "$9.99 a year. Ads gone, unlimited clips and alarms.")
                                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.leading)
                            }
                            Spacer()
                            if !store.isPremium { Image(systemName: "chevron.right").foregroundStyle(HandyColor.textSecondary) }
                        }
                        .cardStyle()
                    }
                    .buttonStyle(.plain)
                    if store.isPremium {
                        Button("Manage subscription") { UIApplication.shared.open(URL(string: "https://apps.apple.com/account/subscriptions")!) }.textButton()
                    } else {
                        Button("Restore purchases") { Task { await store.restore() } }.textButton()
                    }

                    Section("App") {
                        SettingsRow(icon: "slider.horizontal.3", title: "Permissions", sub: "Notifications, alarms, the Clips keyboard") { showSetup = true }
                        SettingsRow(icon: "lock", title: "Privacy", sub: "What stays on your phone (everything)") { showPrivacy = true }
                    }
                    Section("Help") {
                        SettingsRow(icon: "envelope", title: "Send feedback", sub: SUPPORT_EMAIL) {
                            UIApplication.shared.open(URL(string: "mailto:\(SUPPORT_EMAIL)?subject=Tenzy%20iOS%20\(version)")!)
                        }
                        SettingsRow(icon: "star", title: "Rate Tenzy", sub: "30 seconds, means a lot") {
                            if let s = UIApplication.shared.connectedScenes.first as? UIWindowScene { AppStore.requestReview(in: s) }
                        }
                        SettingsRow(icon: "info.circle", title: "About", sub: "Version \(version) · Made by one person in Illinois") { }
                    }
                }
                .padding(.horizontal, HandySpacing.gutter).padding(.vertical, HandySpacing.s8)
            }
            BannerAd()
        }
        .background(HandyColor.bg)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView().presentationDetents([.large]).presentationDragIndicator(.visible).presentationBackground(HandyColor.surfaceRaised).sheetCloseButton { showPaywall = false } }
        .sheet(isPresented: $showSetup) { SetupView(onDone: { showSetup = false }).sheetCloseButton { showSetup = false } }
        .sheet(isPresented: $showPrivacy) { PrivacyView().sheetCloseButton { showPrivacy = false } }
    }

    @ViewBuilder private func Section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        Text(title.uppercased()).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).padding(.top, HandySpacing.s24)
        content()
    }
}

private struct SettingsRow: View {
    let icon: String, title: String, sub: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: HandySpacing.s16) {
                    Image(systemName: icon).font(.system(size: 20)).foregroundStyle(HandyColor.accent).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary)
                        Text(sub).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(HandyColor.textSecondary)
                }
                .padding(.vertical, HandySpacing.s12)
                Rectangle().fill(HandyColor.border).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Privacy

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s24) {
                VStack(alignment: .leading, spacing: HandySpacing.s4) {
                    Text("Privacy").font(HandyFont.display).padding(.top, HandySpacing.s24)
                    Text("Short version: everything you do in Tenzy stays on this iPhone.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                }
                Block("Stays on your phone", check: true, [
                    "Clips you save (keyboard, Share Sheet, or Grab)",
                    "Alarms you set",
                    "Your sticky note (shared only with the widget on your own phone)",
                    "Scans, extracted text, and cleaned photos — until you share them yourself",
                ], note: "Stored in the app's private container. Deleting the app deletes all of it. We can't see it; there is no server.")
                Block("Never collected", check: true, [
                    "Your name, email, or any account — there isn't one",
                    "Keystrokes — the Clips keyboard never logs what you type",
                    "Your location, contacts, or photo library beyond the single photo you pick",
                    "Analytics or crash reports — Tenzy has none",
                ], note: nil)
                Block("The one exception: ads", check: false, [
                    "The free version shows ads through Google AdMob.",
                    "If you allow tracking when asked, AdMob may use your advertising identifier to pick ads; say no and you still get ads, just less relevant ones.",
                    "Change it anytime in Settings › Privacy & Security › Tracking.",
                    "Pro removes the ads and the ad code doesn't run.",
                ], note: nil)
                Block("Payments", check: false, ["Pro is $9.99 a year, billed by Apple. We never see your card."], note: nil)
                Block("Permissions", check: false, [
                    "Microphone: Decibel Meter measures level only; audio is never recorded.",
                    "Camera: Doc Scanner, QR scanner, flashlight.",
                    "Keyboard Full Access: reads the clipboard only when you tap Grab.",
                ], note: nil)
                Block("Children", check: false, ["Tenzy isn't for children under 13 and doesn't knowingly collect anything from them."], note: nil)
                Text("Questions: \(SUPPORT_EMAIL) · Last updated October 15, 2026").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).padding(.bottom, HandySpacing.s32)
            }
            .padding(.horizontal, HandySpacing.gutter)
        }
        .background(HandyColor.bg)
    }

    @ViewBuilder private func Block(_ title: String, check: Bool, _ lines: [String], note: String?) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(title).font(HandyFont.bodyStrong)
            ForEach(lines, id: \.self) { l in
                HStack(alignment: .top, spacing: HandySpacing.s8) {
                    Image(systemName: check ? "checkmark.circle.fill" : "minus.circle").font(.system(size: 15)).foregroundStyle(check ? HandyColor.accent : HandyColor.textSecondary).padding(.top, 2)
                    Text(l).font(.system(size: 15))
                }
            }
            if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
        }
    }
}
