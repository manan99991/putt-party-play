import Foundation
import StoreKit

/// StoreKit 2. Two auto-renewing subscriptions in one group — Monthly and Yearly —
/// so a buyer can pick either and switch tiers without re-subscribing.
///
/// App Store Connect setup (one time):
///   App > Subscriptions > group "Tenzy Pro"
///   • Product ID: tenzy_pro_yearly    Duration: 1 Year   Price: $19.99
///   • Product ID: tenzy_pro_monthly   Duration: 1 Month  Price: $2.99
///   (Product IDs must match the constants below.) Optional 1-week free trial on yearly.
///
/// For local testing without ASC, use Tenzy/Resources/Products.storekit
/// (Edit Scheme > Run > Options > StoreKit Configuration).
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    static let yearlyID = "tenzy_pro_yearly"
    static let monthlyID = "tenzy_pro_monthly"
    static var productIDs: [String] { [yearlyID, monthlyID] }

    @Published private(set) var yearly: Product?
    @Published private(set) var monthly: Product?
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
        if previewPremium || isTesterPro { isPremium = true }
        updates = Task { await listenForTransactions() }
        Task { await load(); await refresh() }
    }

    // Shown on the paywall buttons. Fall back to our set prices if the store hasn't loaded yet.
    var yearlyPrice: String { yearly?.displayPrice ?? "$19.99" }
    var monthlyPrice: String { monthly?.displayPrice ?? "$2.99" }

    /// Roughly what the yearly plan saves versus paying monthly for 12 months, as a %.
    var yearlySavingsPercent: Int {
        guard let y = yearly?.price, let m = monthly?.price, m > 0 else { return 44 }
        let full = m * 12
        let pct = (1 - (y / full)) * 100
        return max(0, Int(NSDecimalNumber(decimal: pct).doubleValue.rounded()))
    }

    func load() async {
        let products = (try? await Product.products(for: Self.productIDs)) ?? []
        yearly = products.first { $0.id == Self.yearlyID }
        monthly = products.first { $0.id == Self.monthlyID }
    }

    func refresh() async {
        if previewPremium || isTesterPro { isPremium = true; return }
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
