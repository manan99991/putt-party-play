import SwiftUI
import StoreKit
import UserNotifications
import AVFoundation
import Speech
import CoreLocation
import Photos

let PRIVACY_URL = URL(string: "https://manan99991.github.io/tenzy/privacy.html")!
let SUPPORT_EMAIL = "tenzy.app@gmail.com"
let APP_STORE_ID = "6824023361"

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

/// The permissions the tools need, each explained and granted with one tap. Shown once after
/// onboarding; reachable later from Settings › Permissions. Nothing is asked for that a tool doesn't use.
struct SetupView: View {
    let onDone: () -> Void
    @State private var camera = false
    @State private var mic = false
    @State private var speech = false
    @State private var location = false
    @State private var photos = false
    @Environment(\.scenePhase) private var phase
    @StateObject private var loc = SetupLocation()

    private var done: Int { [camera, mic, speech, location, photos].filter { $0 }.count }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s12) {
                    Text("Set up once").font(HandyFont.display)
                    Text("Grant what you'll use; skip the rest. Any tool will ask again the first time it needs something.").font(.system(size: 15)).foregroundStyle(HandyColor.textSecondary)
                    Text("\(done) of 5 granted").font(HandyFont.micro).foregroundStyle(HandyColor.accent)
                    SetupRow(icon: "camera", title: "Camera", why: "Scan, Capture, Color Vision, Magnifier+, Pro Camera, Measure and the light meter. Frames are processed on the phone.", unlocks: "Camera tools", granted: camera) {
                        Permission.camera { _ in Task { @MainActor in await refresh() } }
                    }
                    SetupRow(icon: "mic", title: "Microphone", why: "Sound meter, tuner, Live Captions, Voice → Notes, Rest's night recorder. Levels and words are handled on the phone.", unlocks: "Audio tools", granted: mic) {
                        Permission.microphone { _ in Task { @MainActor in await refresh() } }
                    }
                    SetupRow(icon: "waveform.and.mic", title: "Speech recognition", why: "Turns speech into text for Live Captions, Voice → Notes and Translate's Talk mode — on-device for supported languages.", unlocks: "Captions & notes", granted: speech) {
                        Diagnostics.shared.log("requesting speech authorization")
                        Permission.speech { status in
                            Diagnostics.shared.log("speech authorization result: \(status.rawValue)")
                            Task { @MainActor in await refresh() }
                        }
                    }
                    SetupRow(icon: "location", title: "Location (while using)", why: "True-north compass, altitude, the GPS dashboard and where you parked. Never stored or sent.", unlocks: "Compass & GPS", granted: location) {
                        loc.request()
                    }
                    SetupRow(icon: "photo.badge.plus", title: "Save to Photos", why: "Lets Pro Camera and long exposures save into your library. Picking photos never needs this.", unlocks: "Pro Camera", granted: photos) {
                        Task { _ = await PHPhotoLibrary.requestAuthorization(for: .addOnly); await refresh() }
                    }
                    SetupRow(icon: "keyboard", title: "Clips keyboard", why: "Settings › General › Keyboard › Keyboards › Add New. Allow Full Access: it only reads the clipboard when you tap Grab.", unlocks: "Clipboard", granted: false, buttonLabel: "Open Settings") {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    }
                    Text("Everything stays on your iPhone. No account, no cloud, no analytics.")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                .padding(.horizontal, HandySpacing.gutter).padding(.vertical, HandySpacing.s16)
            }
            Button("Done for now") { onDone() }.primaryButton().padding(.horizontal, HandySpacing.gutter).padding(.bottom, HandySpacing.s16)
        }
        .background(HandyColor.bg)
        .task { await refresh() }
        .onAppear { Diagnostics.shared.currentTool = "Permissions" }
        .onChange(of: phase) { _, p in if p == .active { Task { await refresh() } } }
        .onChange(of: loc.granted) { _, g in location = g }
    }

    private func refresh() async {
        camera = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        mic = AVAudioApplication.shared.recordPermission == .granted
        speech = SFSpeechRecognizer.authorizationStatus() == .authorized
        location = loc.granted
        let p = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        photos = p == .authorized || p == .limited
    }
}

@MainActor private final class SetupLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var granted = false
    private let m = CLLocationManager()
    override init() { super.init(); m.delegate = self; granted = [.authorizedWhenInUse, .authorizedAlways].contains(m.authorizationStatus) }
    func request() { m.requestWhenInUseAuthorization() }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let ok = [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus)
        Task { @MainActor in self.granted = ok }
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
    @State private var showAbout = false
    @State private var showDiagnostics = false
    @State private var devTaps = 0
    @AppStorage("tenzy.devUnlocked") private var devUnlocked = false
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text("Settings").font(HandyFont.display).padding(.bottom, HandySpacing.s8)
                        .onTapGesture {
                            guard !devUnlocked else { return }
                            devTaps += 1
                            if devTaps >= 7 { devUnlocked = true; HandyHaptics.success() }
                        }

                    Button { if !store.isPremium { showPaywall = true } } label: {
                        HStack(spacing: HandySpacing.s12) {
                            ZStack {
                                Circle().fill(store.isPremium ? HandyColor.accent : HandyColor.accentSoft).frame(width: 44, height: 44)
                                Image(systemName: "crown.fill").foregroundStyle(store.isPremium ? .white : HandyColor.accent)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.isPremium ? "Tenzy Pro" : "Go Pro").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                                Text(store.isPremium ? "Ads off. Every tool unlimited." : "From \(store.monthlyPrice)/mo or \(store.yearlyPrice)/yr. Ads gone, everything unlimited.")
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
                        SettingsRow(icon: "slider.horizontal.3", title: "Permissions", sub: "Camera, microphone, speech, location, Photos, the Clips keyboard") { showSetup = true }
                        SettingsRow(icon: "lock", title: "Privacy", sub: "What stays on your phone (everything)") { showPrivacy = true }
                    }
                    Section("Help") {
                        SettingsRow(icon: "envelope", title: "Send feedback", sub: SUPPORT_EMAIL) {
                            UIApplication.shared.open(URL(string: "mailto:\(SUPPORT_EMAIL)?subject=Tenzy%20iOS%20\(version)")!)
                        }
                        SettingsRow(icon: "star", title: "Rate Tenzy", sub: "30 seconds, means a lot") {
                            UIApplication.shared.open(URL(string: "https://apps.apple.com/app/id\(APP_STORE_ID)?action=write-review")!)
                        }
                        SettingsRow(icon: "info.circle", title: "About", sub: "Version \(version) · Made by a Dad") { showAbout = true }
                    }
                    if devUnlocked {
                        Section("Developer") {
                            Toggle(isOn: Binding(get: { store.isTesterPro }, set: { store.setTesterPro($0) })) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock Pro (tester)").font(HandyFont.body).foregroundStyle(HandyColor.textPrimary)
                                    Text("Ads off, every tool unlimited — for testing the paid experience.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                                }
                            }.tint(HandyColor.accent).padding(.vertical, HandySpacing.s8)
                            SettingsRow(icon: "ladybug", title: "Diagnostics", sub: "View the on-device log and share it with me") { showDiagnostics = true }
                            SettingsRow(icon: "eye.slash", title: "Hide developer tools", sub: "Tap the Settings title 7× to show again") { devUnlocked = false; devTaps = 0 }
                        }
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
        .sheet(isPresented: $showAbout) { AboutView().sheetCloseButton { showAbout = false } }
        .sheet(isPresented: $showDiagnostics) { DiagnosticsView().sheetCloseButton { showDiagnostics = false } }
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

// MARK: - About

struct AboutView: View {
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }
    private var storeURL: URL { URL(string: "https://apps.apple.com/app/id\(APP_STORE_ID)")! }

    var body: some View {
        ScrollView {
            VStack(spacing: HandySpacing.s16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [HandyColor.accent, HandyColor.accentPressed], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 92, height: 92)
                    Image(systemName: "square.grid.2x2.fill").font(.system(size: 40)).foregroundStyle(.white)
                }.padding(.top, HandySpacing.s32)

                Text("Tenzy").font(.system(size: 30, weight: .bold))
                Text("Version \(version)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)

                Text("30 small tools your phone should've had — flashlight, clipboard, scanner, PDF, AI and more. Everything runs on your phone; nothing is uploaded.")
                    .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, HandySpacing.s8)

                VStack(spacing: HandySpacing.s12) {
                    Button { UIApplication.shared.open(URL(string: "https://apps.apple.com/app/id\(APP_STORE_ID)?action=write-review")!) } label: {
                        Label("Rate Tenzy", systemImage: "star.fill").frame(maxWidth: .infinity)
                    }.primaryButton()
                    ShareLink(item: storeURL) { Label("Share Tenzy", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.compactButton()
                    Button { UIApplication.shared.open(URL(string: "mailto:\(SUPPORT_EMAIL)?subject=Tenzy%20iOS%20\(version)")!) } label: {
                        Label("Send feedback", systemImage: "envelope").frame(maxWidth: .infinity)
                    }.compactButton()
                }.padding(.top, HandySpacing.s8)

                Text("Made by a Dad.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).padding(.top, HandySpacing.s16)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.bottom, HandySpacing.s48)
        }
        .background(HandyColor.bg)
    }
}

// MARK: - Diagnostics (developer / tester)

/// Shows the on-device diagnostics log and lets the tester share it. Nothing is ever uploaded
/// automatically — sharing is a deliberate tap.
struct DiagnosticsView: View {
    @State private var text = Diagnostics.shared.reportText()
    @State private var fileURL = Diagnostics.shared.reportFileURL()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s12) {
                    Text("Diagnostics").font(HandyFont.display).padding(.top, HandySpacing.s24)
                    Text("A local record of what the app did — tools opened, how long actions took, UI freezes and crashes. Share it with me to debug a problem. It only leaves your phone when you send it.")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    HStack(spacing: HandySpacing.s8) {
                        ShareLink(item: fileURL) { Label("Share log", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
                        Button {
                            Diagnostics.shared.clear(); text = Diagnostics.shared.reportText(); fileURL = Diagnostics.shared.reportFileURL()
                        } label: { Label("Clear", systemImage: "trash").frame(maxWidth: .infinity) }.secondaryButton()
                    }
                    Text(text)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(HandySpacing.s8)
                        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                }
                .padding(.horizontal, HandySpacing.gutter).padding(.bottom, HandySpacing.s32)
            }
        }
        .background(HandyColor.bg)
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
                    "Clips and snippets you save (keyboard, Share Sheet, or Grab)",
                    "Vault items — encrypted with a key only your Face ID or passcode can release",
                    "Voice notes, night-recorder clips and transcripts",
                    "Scans, extracted text, and cleaned photos — until you share them yourself",
                ], note: "Stored in the app's private container. Deleting the app deletes all of it. We can't see it; there is no server.")
                Block("Never collected", check: true, [
                    "Your name, email, or any account — there isn't one",
                    "Keystrokes — the Clips keyboard never logs what you type",
                    "Your location (used live for the compass and GPS dashboard, never stored or sent), contacts, or photo library beyond what you pick",
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
