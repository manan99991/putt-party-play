import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

/// Live Tenzy AdMob ad unit ids.
enum AdUnits {
    static let banner = "ca-app-pub-5414801919054534/9681092972"
    static let interstitial = "ca-app-pub-5414801919054534/5362574012"
}

@MainActor
enum AdsBootstrap {
    private static var started = false

    static func start() {
        guard !started else { return }
        started = true
        // Defer the SDK start until after the first frame: the first foreground activation
        // lands right after first render, so cold start stays under 800ms with no ad SDK
        // on the main thread before first draw.
        // MEASURE: cold-start timing — CI measures with the xctrace 'App Launch' template.
        let testing = ProcessInfo.processInfo.arguments.contains("-screenshots") || ProcessInfo.processInfo.arguments.contains("-uitest")
        if testing {
            if !ProcessInfo.processInfo.arguments.contains("-uitest") { MobileAds.shared.start() }
        } else {
            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { _ in
                if let token { NotificationCenter.default.removeObserver(token) }
                MobileAds.shared.start()
            }
        }
        // ATT prompt after a short delay so it doesn't collide with the first-launch UI.
        if testing { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }
}

/// Adaptive banner anchored at the bottom of every tool. Renders nothing for Pro.
struct BannerAd: View {
    @ObservedObject private var store = StoreManager.shared
    var body: some View {
        if !store.isPremium {
            VStack(spacing: 0) {
                Rectangle().fill(HandyColor.border).frame(height: 1)
                HStack {
                    Text("Ads keep Tenzy free").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                    Button("Remove ads") { NotificationCenter.default.post(name: .showPaywall, object: nil) }.font(HandyFont.micro).foregroundStyle(HandyColor.accent)
                }
                .padding(.horizontal, HandySpacing.gutter).padding(.vertical, 2)
                BannerViewRep().frame(height: HandySpacing.adReservedHeight)
            }
            .background(HandyColor.bg)
        }
    }
}

private struct BannerViewRep: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let width = UIScreen.main.bounds.width
        let v = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        v.adUnitID = AdUnits.banner
        v.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
        v.load(Request())
        return v
    }
    func updateUIView(_ uiView: BannerView, context: Context) {}
}

/// Full-screen ad after a tool finishes, at most once every 3 minutes.
@MainActor
final class Interstitials {
    static let shared = Interstitials()
    private var ad: InterstitialAd?
    private var lastShown = Date.distantPast
    private let gap: TimeInterval = 180

    func preload() {
        guard !StoreManager.shared.isPremium, ad == nil else { return }
        InterstitialAd.load(with: AdUnits.interstitial, request: Request()) { [weak self] ad, _ in self?.ad = ad } // GMA calls back on main
    }

    func showIfReady() {
        guard !StoreManager.shared.isPremium, let ad, Date().timeIntervalSince(lastShown) > gap,
              let root = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first
        else { preload(); return }
        lastShown = Date()
        ad.present(from: root)
        self.ad = nil
        preload()
    }
}
