import Foundation
import StoreKit

/// StoreKit 2. One auto-renewing subscription — Tenzy Pro, billed yearly.
///
/// App Store Connect setup (one time):
///   App > Subscriptions > group "Tenzy Pro"
///   • Product ID: tenzy_pro_yearly    Duration: 1 Year   Price: $19.99
///   (Product ID must match the constant below.) 3-day free trial (introductory offer).
///
/// For local testing without ASC, use Tenzy/Resources/Products.storekit
/// (Edit Scheme > Run > Options > StoreKit Configuration).
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    static let yearlyID = "tenzy_pro_yearly"
    static var productIDs: [String] { [yearlyID] }

    @Published private(set) var yearly: Product?
    @Published private(set) var isPremium: Bool = Premium.isActive
    @Published var purchaseError: String?

    private var updates: Task<Void, Never>?

    // CI screenshot only: the `homepro` route renders Home in Pro state (no ad strip). In-memory
    // only; never written to Premium.isActive, and it makes refresh() a no-op so the real (empty)
    // sim entitlement can't downgrade it back to free.
    private let previewPremium = CommandLine.arguments.contains("homepro")

    // Tester unlock: lets the owner run the app with Pro on (ads off, no limits) without a purchase,
    // for testing the paid experience. Persisted, and refresh() won't downgrade it. Not shown to
    // normal users — reachable only from Settings › Developer (reveal by tapping the title 7×).
    private let testerProKey = "tenzy.testerPro"
    var isTesterPro: Bool { UserDefaults.standard.bool(forKey: testerProKey) }
    func setTesterPro(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: testerProKey)
        if on { isPremium = true } else { Task { await refresh() } }
        Diagnostics.shared.log("tester Pro \(on ? "ON" : "OFF")")
    }

    private init() {
        #if DEBUG
        if previewPremium || isTesterPro { isPremium = true }
        #endif
        updates = Task { await listenForTransactions() }
        Task { await load(); await refresh() }
    }

    // Shown on the paywall button. Falls back to our set price if the store hasn't loaded yet.
    var yearlyPrice: String { yearly?.displayPrice ?? "$19.99" }

    func load() async {
        let products = (try? await Product.products(for: Self.productIDs)) ?? []
        yearly = products.first { $0.id == Self.yearlyID }
    }

    func refresh() async {
        #if DEBUG
        if previewPremium || isTesterPro { isPremium = true; return }
        #endif
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Self.productIDs.contains(t.productID), t.revocationDate == nil { active = true }
        }
        setPremium(active)
    }

    func purchase(_ product: Product?) async {
        guard let product else { await load(); return }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let t) = verification { await t.finish(); setPremium(true) }
            case .userCancelled, .pending: break
            @unknown default: break
            }
        } catch { purchaseError = error.localizedDescription }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let t) = result { await t.finish(); await refresh() }
        }
    }

    private func setPremium(_ v: Bool) { isPremium = v; Premium.isActive = v }
}
