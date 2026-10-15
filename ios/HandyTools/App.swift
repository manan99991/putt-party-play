import SwiftUI

@main
struct HandyToolsApp: App {
    @StateObject private var store = StoreManager.shared

    init() { AdsBootstrap.start(); Task { @MainActor in Interstitials.shared.preload() } }

    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(store).tint(Color(red: 0.12, green: 0.37, blue: 1.0))
        }
    }
}

@MainActor
struct Tool: Identifiable {
    let id: String
    let name: String
    let blurb: String
    let icon: String
    let view: () -> AnyView
}

@MainActor let TOOLS: [Tool] = [
    Tool(id: "alarm", name: "Alarm Pro", blurb: "Your own snooze length, limits, sounds", icon: "alarm.fill") { AnyView(AlarmProView()) },
    Tool(id: "clips", name: "Multi-Clipboard", blurb: "Stack copies, paste any from the keyboard", icon: "doc.on.clipboard.fill") { AnyView(ClipboardView()) },
    Tool(id: "flash", name: "Flashlight Dimmer", blurb: "Brightness slider, SOS, strobe", icon: "flashlight.on.fill") { AnyView(FlashlightView()) },
    Tool(id: "webclip", name: "Web → Home", blurb: "Any link becomes a home-screen icon", icon: "square.and.arrow.down.on.square.fill") { AnyView(WebClipView()) },
    Tool(id: "sticky", name: "Sticky Note", blurb: "One note, home + lock screen widget", icon: "note.text") { AnyView(StickyNotesView()) },
    Tool(id: "ocr", name: "Text from Image", blurb: "Copy every word in a screenshot", icon: "text.viewfinder") { AnyView(TextFromImageView()) },
    Tool(id: "scan", name: "Doc Scanner", blurb: "Scan pages, share as PDF", icon: "doc.viewfinder.fill") { AnyView(DocScannerView()) },
    Tool(id: "db", name: "Decibel Meter", blurb: "How loud is it, really?", icon: "waveform") { AnyView(DecibelMeterView()) },
    Tool(id: "exif", name: "Photo Metadata", blurb: "See it, strip it before sharing", icon: "photo.badge.exclamationmark") { AnyView(ExifView()) },
    Tool(id: "qr", name: "QR Tools", blurb: "Scan, or make Wi‑Fi / link codes", icon: "qrcode.viewfinder") { AnyView(QRToolsView()) },
]

enum Launch {
    static var args: [String] { ProcessInfo.processInfo.arguments }
    static var route: String? { args.firstIndex(of: "-route").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } }
    static var screenshots: Bool { args.contains("-screenshots") }
}

struct HomeView: View {
    @EnvironmentObject var store: StoreManager
    @State private var showPaywall = false
    @State private var path: [String] = Launch.route.map { [$0] } ?? []
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(TOOLS) { t in
                            NavigationLink(value: t.id) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Image(systemName: t.icon).font(.title2).foregroundStyle(.tint)
                                    Spacer()
                                    Text(t.name).font(.headline).foregroundStyle(.primary)
                                    Text(t.blurb).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                                .padding(16)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                    .padding(16)
                }
                BannerAd()
            }
            .navigationDestination(for: String.self) { id in
                if id == "paywall" { PaywallView() } else { (TOOLS.first { $0.id == id }?.view() ?? AnyView(EmptyView())).toolbarRole(.editor) }
            }
            .navigationTitle("HandyTools")
            .toolbar {
                if !store.isPremium {
                    Button { showPaywall = true } label: { Label("Go Pro", systemImage: "crown.fill") }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}

struct PaywallView: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HandyTools Pro").font(.largeTitle.bold())
            Text("One yearly payment. Ads gone for good.").foregroundStyle(.secondary)
            ForEach(["No banner or full-screen ads", "Unlimited clipboard history (free: 20)", "Unlimited alarms (free: 3)", "Support one indie developer"], id: \.self) {
                Label($0, systemImage: "checkmark.circle.fill")
            }
            Spacer()
            if store.isPremium {
                Text("You're Pro. Thank you.").font(.headline)
            } else {
                Button { Task { await store.purchase(); if store.isPremium { dismiss() } } } label: {
                    Text(store.product == nil ? "Loading price…" : "Go Pro · \(store.priceLabel)").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large).disabled(store.product == nil)
                Button("Restore purchases") { Task { await store.restore() } }.frame(maxWidth: .infinity)
                Text("Auto-renews yearly. Cancel anytime in Settings › Apple ID › Subscriptions.").font(.caption).foregroundStyle(.secondary)
            }
            if let e = store.purchaseError { Text(e).font(.caption).foregroundStyle(.red) }
        }
        .padding(24)
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
                VStack(alignment: .leading, spacing: 16) {
                    Text(subtitle).foregroundStyle(.secondary)
                    content()
                }
                .padding(20)
            }
            BannerAd()
        }
        .navigationTitle(title)
    }
}
