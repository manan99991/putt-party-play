import SwiftUI

@main
struct TenzyApp: App {
    @StateObject private var store = StoreManager.shared

    // AdMob init and the interstitial preload are deferred until after the first frame
    // (prompt 1: cold-start work). They fire once, from a .task on the root view below.
    @State private var adsStarted = false

    @State private var showOnboarding = !OnboardingFlag.seen && Launch.route == nil
    @State private var onboardingPage = 0

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeView().environmentObject(store).tint(HandyColor.accent)
                if showOnboarding {
                    OnboardingView(startPage: onboardingPage,
                                   onDone: { OnboardingFlag.seen = true; withAnimation(.easeOut(duration: HandyMotion.slow)) { showOnboarding = false }; NotificationCenter.default.post(name: .showSetup, object: nil) },
                                   onSeePro: { OnboardingFlag.seen = true; showOnboarding = false; NotificationCenter.default.post(name: .showPaywall, object: nil) })
                        .environmentObject(store)
                        .transition(.opacity)
                }
            }
            .onAppear {
                if let r = Launch.route, r.hasPrefix("onboarding") { onboardingPage = Int(r.dropFirst("onboarding".count)).map { $0 - 1 } ?? 0; showOnboarding = true }
            }
            .task {
                // First frame has rendered by the time this runs; now it's safe to pay the
                // ad SDK costs off the critical path. Runs exactly once per launch.
                if !adsStarted {
                    await MainActor.run {
                        adsStarted = true
                        AdsBootstrap.start()
                        Interstitials.shared.preload()
                    }
                }
            }
        }
    }
}

@MainActor
struct Tool: Identifiable {
    let id: String
    let name: String
    let blurb: String
    let icon: String
}

@MainActor let TOOLS: [Tool] = [
    Tool(id: "alarm", name: "Alarm Pro", blurb: "Your own snooze length, limits, sounds", icon: "alarm.fill"),
    Tool(id: "clips", name: "Multi-Clipboard", blurb: "Stack copies, paste any from the keyboard", icon: "doc.on.clipboard.fill"),
    Tool(id: "flash", name: "Flashlight Dimmer", blurb: "Brightness slider, SOS, strobe", icon: "flashlight.on.fill"),
    Tool(id: "webclip", name: "Web → Home", blurb: "Any link becomes a home-screen icon", icon: "square.and.arrow.down.on.square.fill"),
    Tool(id: "sticky", name: "Sticky Note", blurb: "One note, home + lock screen widget", icon: "note.text"),
    Tool(id: "ocr", name: "Text from Image", blurb: "Copy every word in a screenshot", icon: "text.viewfinder"),
    Tool(id: "scan", name: "Doc Scanner", blurb: "Scan pages, share as PDF", icon: "doc.viewfinder.fill"),
    Tool(id: "db", name: "Decibel Meter", blurb: "How loud is it, really?", icon: "waveform"),
    Tool(id: "exif", name: "Photo Metadata", blurb: "See it, strip it before sharing", icon: "photo.badge.exclamationmark"),
    Tool(id: "qr", name: "QR Tools", blurb: "Scan, or make Wi‑Fi / link codes", icon: "qrcode.viewfinder"),
]

/// Tool routing without AnyView (prompt 1): enum-free string ids stay the
/// route contract; this @ViewBuilder switch is the single destination map.
struct ToolDestination: View {
    let id: String
    var body: some View {
        switch id {
        case "alarm": AlarmProView()
        case "clips": ClipboardView()
        case "flash": FlashlightView()
        case "webclip": WebClipView()
        case "sticky": StickyNotesView()
        case "ocr": TextFromImageView()
        case "scan": DocScannerView()
        case "db": DecibelMeterView()
        case "exif": ExifView()
        case "qr": QRToolsView()
        default: EmptyView()
        }
    }
}

enum Launch {
    static var args: [String] { ProcessInfo.processInfo.arguments }
    static var route: String? { args.firstIndex(of: "-route").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } }
    static var screenshots: Bool { args.contains("-screenshots") }
}

struct HomeView: View {
    @EnvironmentObject var store: StoreManager
    @State private var showPaywall = false
    @State private var path: [String] = Launch.route.flatMap { $0.hasPrefix("onboarding") || $0 == "paywall" || $0 == "home" || $0 == "homepro" ? nil : [$0] } ?? []
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: HandySpacing.s4) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: HandySpacing.s4) {
                                Text("Tenzy").font(HandyFont.display)
                                Text(store.isPremium ? "Pro · no ads" : "10 tools your phone should've had")
                                    .font(.system(size: 15)).foregroundStyle(HandyColor.textSecondary)
                            }
                            Spacer()
                            HStack(spacing: HandySpacing.s8) {
                                if !store.isPremium {
                                    Button { showPaywall = true } label: {
                                        Image(systemName: "crown.fill").font(.system(size: 20)).foregroundStyle(HandyColor.accent)
                                            .frame(width: 44, height: 44).background(HandyColor.accentSoft, in: Circle())
                                    }
                                    .accessibilityLabel("Go Pro")
                                }
                                NavigationLink(value: "settings") {
                                    Image(systemName: "gearshape").font(.system(size: 20)).foregroundStyle(HandyColor.textSecondary).frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Settings")
                            }
                        }
                        .padding(.horizontal, HandySpacing.gutter)
                        .padding(.top, HandySpacing.s8)
                        .padding(.bottom, HandySpacing.s12)
                        LazyVGrid(columns: cols, spacing: HandySpacing.s12) {
                            ForEach(Array(TOOLS.enumerated()), id: \.element.id) { idx, t in
                                NavigationLink(value: t.id) { ToolCard(tool: t).handyListEntrance(index: idx) }.buttonStyle(ToolCardPress())
                            }
                        }
                        .padding(.horizontal, HandySpacing.gutter)
                        .padding(.bottom, HandySpacing.s16)
                    }
                }
                BannerAd()
            }
            .background(HandyColor.bg)
            .navigationDestination(for: String.self) { id in
                switch id {
                case "settings": SettingsView().toolbarRole(.editor)
                case "setup": SetupView(onDone: { path.removeLast() }).toolbarRole(.editor)
                case "privacy": PrivacyView().toolbarRole(.editor)
                case "ring": AlarmRingPreviewView() // CI screenshot route: static ring preview
                default: ToolDestination(id: id).toolbarRole(.editor)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: path) { _, p in if p.last == "paywall" { path.removeLast(); showPaywall = true } }
            .onAppear { if Launch.route == "paywall" { showPaywall = true } }
            .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { _ in showPaywall = true }
            .onReceive(NotificationCenter.default.publisher(for: .showSetup)) { _ in if !(Launch.route?.hasPrefix("onboarding") ?? false) { path = ["setup"] } }
            .sheet(isPresented: $showPaywall) {
                PaywallView().presentationDetents([.large]).presentationDragIndicator(.visible)
                    .presentationBackground(HandyColor.surfaceRaised).presentationCornerRadius(HandyRadius.sheet)
            }
        }
    }
}

/// Home grid card: icon in an accentSoft circle, name, one-line blurb.
struct ToolCard: View {
    let tool: Tool
    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s4) {
            ZStack {
                Circle().fill(HandyColor.accentSoft).frame(width: 40, height: 40)
                Image(systemName: tool.icon).font(.system(size: 18, weight: .medium)).foregroundStyle(HandyColor.accent)
            }
            Spacer(minLength: HandySpacing.s12)
            Text(tool.name).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary).lineLimit(2).minimumScaleFactor(0.9)
            Text(tool.blurb).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .cardStyle()
    }
}

struct ToolCardPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? HandyMotion.pressScale : 1)
            .animation(.easeOut(duration: HandyMotion.fast), value: configuration.isPressed)
    }
}

/// Paywall as a bottom sheet. Honest: price, term, cancel path, no timers, no fake discounts.
struct PaywallView: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: HandySpacing.s16) {
            ZStack {
                Circle().fill(HandyColor.accentSoft).frame(width: 64, height: 64)
                Image(systemName: "crown.fill").font(.system(size: 28)).foregroundStyle(HandyColor.accent)
            }
            .padding(.top, HandySpacing.s24)
            Text("Tenzy Pro").font(.system(size: 28, weight: .bold))
            Text("One yearly payment. Ads gone for good.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                ForEach(["No banner or full-screen ads", "Unlimited clipboard history (free: 20)", "Unlimited alarms (free: 3)", "Support one indie developer"], id: \.self) { line in
                    HStack(spacing: HandySpacing.s12) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(HandyColor.accent)
                        Text(line).font(HandyFont.body)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, HandySpacing.s8)
            Spacer()
            if store.isPremium {
                Label("You're Pro. Thank you.", systemImage: "checkmark.circle.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success)
            } else {
                Button { Task { await store.purchase(); if store.isPremium { dismiss() } } } label: {
                    Text("Go Pro · \(store.product == nil ? "$9.99 / year" : store.priceLabel)")
                }
                .primaryButton()
                Text("$9.99 a year, auto-renews. Cancel anytime in Settings › Apple ID › Subscriptions. Price shown in your currency at checkout.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                HStack(spacing: HandySpacing.s24) {
                    Button("Restore purchases") { Task { await store.restore() } }.textButton()
                    Button("Not now") { dismiss() }.textButton()
                }
            }
            if let e = store.purchaseError { Text(e).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .padding(.horizontal, HandySpacing.s24)
        .padding(.bottom, HandySpacing.s24)
    }
}

/// Shared chrome for every tool page.
struct ToolPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s16) {
                    Text(title).font(HandyFont.display)
                    Text(subtitle).font(.system(size: 15)).foregroundStyle(HandyColor.textSecondary).padding(.top, -HandySpacing.s8)
                    content()
                }
                .padding(.horizontal, HandySpacing.gutter)
                .padding(.vertical, HandySpacing.s8)
            }
            BannerAd()
        }
        .background(HandyColor.bg)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Notification.Name {
    static let showPaywall = Notification.Name("handytools.showPaywall")
    static let showSetup = Notification.Name("handytools.showSetup")
}
