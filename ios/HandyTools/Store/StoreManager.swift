import Foundation
import StoreKit

/// StoreKit 2. Yearly auto-renewing subscription only.
///
/// App Store Connect setup (one time):
///   App > Subscriptions > Create group "HandyTools Pro"
///   Product ID: handytools_pro_yearly   (must match `productID`)
///   Duration: 1 year. Optional 1-week free trial as an introductory offer.
///
/// For local testing without ASC, use HandyTools/Resources/Products.storekit
/// (Edit Scheme > Run > Options > StoreKit Configuration).
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    static let productID = "handytools_pro_yearly"

    @Published private(set) var product: Product?
    @Published private(set) var isPremium: Bool = Premium.isActive
    @Published var purchaseError: String?

    private var updates: Task<Void, Never>?

    private init() {
        // CI screenshot only: the `homepro` route renders Home in Pro state (no ad strip)
        // for the store split slide. In-memory only; never written to Premium.isActive.
        if CommandLine.arguments.firstIndex(of: "-route").map({ CommandLine.arguments.indices.contains($0 + 1) && CommandLine.arguments[$0 + 1] == "homepro" }) == true {
            isPremium = true
        }
        updates = Task { await listenForTransactions() }
        Task { await load(); await refresh() }
    }

    var priceLabel: String { product.map { "\($0.displayPrice) / year" } ?? "…" }

    func load() async {
        product = try? await Product.products(for: [Self.productID]).first
    }

    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil { active = true }
        }
        setPremium(active)
    }

    func purchase() async {
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
