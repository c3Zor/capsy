import StoreKit
import Observation

/// Capsy Plus — StoreKit 2, fully on-device: no server, no login.
/// Entitlements come from Apple via the user's Apple ID; `isPlus` is true
/// when any Plus product (subscription or lifetime) is currently owned.
@MainActor
@Observable
final class Plus {
    static let shared = Plus()

    static let monthlyID = "com.capsy.plus.monthly"
    static let yearlyID = "com.capsy.plus.yearly"
    static let lifetimeID = "com.getcapsy.plus.lifetime"
    static let allIDs = [monthlyID, yearlyID, lifetimeID]

    private(set) var products: [Product] = []
    private(set) var isPlus = false
    private(set) var isLoading = true

    private init() {
        Task {
            await loadProducts()
            await refreshEntitlements()
            await listenForUpdates()
        }
    }

    // MARK: - Loading

    private func loadProducts() async {
        products = (try? await Product.products(for: Self.allIDs)) ?? []
        // Stable order: monthly, yearly, lifetime.
        products.sort {
            (Self.allIDs.firstIndex(of: $0.id) ?? 9) < (Self.allIDs.firstIndex(of: $1.id) ?? 9)
        }
        isLoading = false
    }

    /// Walks Apple's current entitlements — works offline, survives
    /// reinstalls, restores automatically on any device with the Apple ID.
    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.allIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPlus = owned
    }

    private func listenForUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }

    // MARK: - Actions

    /// Returns true when the purchase succeeded.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard let result = try? await product.purchase() else { return false }
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                await refreshEntitlements()
                return true
            }
            return false
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}
