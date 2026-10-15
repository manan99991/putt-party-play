import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

/// Google's official TEST ad unit ids. Replace in AdMob console before shipping.
enum AdUnits {
    static let banner = "ca-app-pub-3940256099942544/2435281174"
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
}

enum AdsBootstrap {
    static func start() {
        MobileAds.shared.start()
        // ATT prompt after a short delay so it doesn't collide with the first-launch UI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }
}

/// Adaptive banner anchored at the bottom of every tool. Renders nothing for Pro.
struct BannerAd: View {
    @ObservedObject private var store = StoreManager.shared
    var body: some View {
        if !store.isPremium { BannerViewRep().frame(height: 60) }
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
        InterstitialAd.load(with: AdUnits.interstitial, request: Request()) { [weak self] ad, _ in
            MainActor.assumeIsolated { self?.ad = ad } // GMA invokes completion on the main thread
        }
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
