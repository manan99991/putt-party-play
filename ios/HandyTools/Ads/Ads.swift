import SwiftUI

// Tenzy is subscription-only — AdMob was removed entirely (the account kept getting
// declined and ads weren't serving, so we dropped ad revenue in favour of Tenzy Pro).
// These are inert shims so the former call sites keep compiling; none of them render
// an ad or load any ad SDK. Tenzy Pro now means unlimited tools and no daily limits.

@MainActor
enum AdsBootstrap {
    /// No-op: there is no ad SDK to start.
    static func start() {}
}

/// Renders nothing. Kept so screens that still call `BannerAd()` compile; there is no ad strip.
struct BannerAd: View {
    var body: some View { EmptyView() }
}

/// No-op interstitials. Kept so former call sites compile; nothing is ever shown.
@MainActor
final class Interstitials {
    static let shared = Interstitials()
    func preload() {}
    func showIfReady() {}
}
