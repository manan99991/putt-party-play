import Foundation
import StoreKit

/// StoreKit 2. Tenzy Pro, monthly or yearly (Manan's pricing, 22 Nov; shipped 25 Nov).
///
/// App Store Connect (set by `fastlane subscriptions`): group "Tenzy Pro"
///   • tenzy_pro_month     1 Month   $2.99    7-day free trial (introductory offer)
///   • tenzy_pro_yearly    1 Year    $29.99   7-day free trial (people already on $19.99 keep their price)
///
/// For local testing without ASC, use Tenzy/Resources/Products.storekit
/// (Edit Scheme > Run > Options > StoreKit Configuration).
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    static let yearlyID = "tenzy_pro_yearly"
    /// "tenzy_pro_monthly" was used by the old monthly plan (removed in November) and Apple never reuses an ID.
    static let monthlyID = "tenzy_pro_month"
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

    // Tester unlock: lets the owner run the app with Pro on (no limits) without a purchase,
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
        // Unlock Pro automatically in every non-production build — DEBUG and TestFlight (sandbox
        // receipt) — so beta testers get the full paid experience (all themes, no limits)
        // without a purchase. A real App Store build has a production receipt, so isTestBuild is
        // false there and the Pro gate stays on for paying users. (previewPremium/isTesterPro remain
        // for CI screenshots and the manual Developer toggle.)
        if previewPremium || isTesterPro || AppEnv.isTestBuild { isPremium = true }
        updates = Task { await listenForTransactions() }
        Task { await load(); await refresh() }
    }

    // Shown on the paywall button. Falls back to our set price if the store hasn't loaded yet.
    var yearlyPrice: String { yearly?.displayPrice ?? "$29.99" }
    var monthlyPrice: String { monthly?.displayPrice ?? "$2.99" }
    /// "Save 16%" — yearly against twelve months, worked out from the live prices (nil if it doesn't save).
    var yearlySaving: String? {
        guard let y = yearly?.price, let m = monthly?.price, m > 0 else { return screenshotMode ? "Save 16%" : nil }
        let full = m * 12
        guard full > y else { return nil }
        let pct = Int(NSDecimalNumber(decimal: (full - y) / full * 100).doubleValue.rounded(.down))
        return pct >= 5 ? String(format: L("Save %d%%"), pct) : nil
    }

    // CI screenshot capture: force the trial copy on so marketing shots show it even though the
    // simulator has no real offer. Production never uses this path.
    private let screenshotMode = CommandLine.arguments.contains("-screenshots")

    /// True only when the yearly product actually has a live free-trial introductory offer (or during
    /// screenshot capture). The paywall advertises the trial only when this is true, so copy never
    /// promises a trial StoreKit won't grant — e.g. before the offer is approved in App Store Connect.
    var showsFreeTrial: Bool {
        if screenshotMode { return true }
        guard let o = yearly?.subscription?.introductoryOffer else { return false }
        return o.paymentMode == .freeTrial
    }

    /// Whether a plan has a live free trial (the person hasn't used one yet).
    func hasTrial(_ p: Product?) -> Bool {
        if screenshotMode { return true }
        return p?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    /// Trial length as "7-day", read from the live offer (falls back to "3-day" for screenshots).
    var trialLength: String {
        guard !screenshotMode, let p = yearly?.subscription?.introductoryOffer?.period else { return "7-day" }
        let unit: String
        switch p.unit { case .day: unit = "day"; case .week: unit = "week"; case .month: unit = "month"; case .year: unit = "year"; @unknown default: unit = "day" }
        return "\(p.value)-\(unit)"
    }

    /// Trial length in prose, in the app's language: "7 days", "7 Tage", "7 días".
    var trialLengthWords: String {
        var c = DateComponents()
        if !screenshotMode, let p = yearly?.subscription?.introductoryOffer?.period {
            switch p.unit {
            case .day: c.day = p.value
            case .week: c.day = p.value * 7
            case .month: c.month = p.value
            case .year: c.year = p.value
            @unknown default: c.day = 7
            }
        } else { c.day = 7 }
        let f = DateComponentsFormatter()
        f.unitsStyle = .full
        f.maximumUnitCount = 1
        var cal = Calendar.current; cal.locale = Localizer.shared.locale
        f.calendar = cal
        return f.string(from: c) ?? "7 days"
    }

    func load() async {
        let products = (try? await Product.products(for: Self.productIDs)) ?? []
        yearly = products.first { $0.id == Self.yearlyID }
        monthly = products.first { $0.id == Self.monthlyID }
    }

    func refresh() async {
        // Keep Pro on in non-production builds (see init) — the real (empty) sandbox entitlement
        // must never downgrade a TestFlight tester back to free.
        if previewPremium || isTesterPro || AppEnv.isTestBuild { isPremium = true; return }
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Self.productIDs.contains(t.productID), t.revocationDate == nil { active = true }
        }
        setPremium(active)
    }

    func purchase(_ product: Product?) async {
        guard let product else {
            await load()
            if yearly == nil && monthly == nil { purchaseError = "Couldn't reach the App Store. Check your connection and tap again." }
            return
        }
        purchaseError = nil
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
