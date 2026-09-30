import Foundation
import Combine
import StoreKit

/// StoreKit 2 purchases. Everything goes through Apple — no external
/// billing, no web links. Works offline for owned entitlements (persisted
/// locally); purchases themselves need a network connection to Apple.
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    // Product IDs — these MUST match the products created in App Store Connect.
    static let removeAdsID = "app.pourpaint.game.removeads"                  // non-consumable, $4.99
    static let extraPoursPackID = "app.pourpaint.game.boosters.extrapours10" // consumable, $0.99

    static let allProductIDs = [removeAdsID, extraPoursPackID]

    /// One Extra Pours refill adds +2 pours to the current level.
    static let poursPerRefill = 2
    static let refillsPerPack = 10

    @Published private(set) var removeAds = false
    @Published private(set) var extraPoursCount = 0
    @Published private(set) var products: [Product] = []
    @Published var purchaseInProgress = false
    @Published var lastError: String?

    private var updateListener: Task<Void, Error>?

    private enum Keys {
        static let removeAds = "pourpaint.store.removeAds"
        static let extraPours = "pourpaint.store.extraPours"
    }

    private init() {
        let d = UserDefaults.standard
        removeAds = d.bool(forKey: Keys.removeAds)
        extraPoursCount = d.integer(forKey: Keys.extraPours)
        // Listen for transactions that complete outside the app
        // (e.g. approved on another device, Ask to Buy, refunds).
        updateListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handleUpdate(result)
            }
        }
        Task { await refreshEntitlements() }
    }

    // MARK: - Products

    @MainActor
    func requestProducts() async {
        do {
            products = try await Product.products(for: Self.allProductIDs)
        } catch {
            lastError = "Couldn't load store products. Check your connection and try again."
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    var removeAdsProduct: Product? { product(for: Self.removeAdsID) }
    var extraPoursPackProduct: Product? { product(for: Self.extraPoursPackID) }

    // MARK: - Purchase

    @MainActor
    func purchase(_ product: Product) async {
        guard !purchaseInProgress else { return }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                try await handleVerified(verification)
                lastError = nil
            case .userCancelled, .pending:
                break // no error to show; pending resolves via Transaction.updates
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed. Please try again."
        }
    }

    @MainActor
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "Couldn't reach the App Store. Check your connection and try again."
        }
    }

    // MARK: - Boosters

    /// Consumes one owned Extra Pours refill. Returns false if none owned.
    @MainActor
    func consumeExtraPours() -> Bool {
        guard extraPoursCount > 0 else { return false }
        extraPoursCount -= 1
        UserDefaults.standard.set(extraPoursCount, forKey: Keys.extraPours)
        return true
    }

    // MARK: - Verification & entitlements

    private func handleUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            try await handleVerified(result)
        } catch {
            // Unverified transactions are ignored — never grant on them.
        }
    }

    private func handleVerified(_ verification: VerificationResult<Transaction>) async throws {
        switch verification {
        case .verified(let transaction):
            await MainActor.run { self.apply(transaction) }
            await transaction.finish()
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    @MainActor
    private func apply(_ transaction: Transaction) {
        switch transaction.productID {
        case Self.removeAdsID:
            removeAds = true
            UserDefaults.standard.set(true, forKey: Keys.removeAds)
        case Self.extraPoursPackID:
            extraPoursCount += Self.refillsPerPack
            UserDefaults.standard.set(extraPoursCount, forKey: Keys.extraPours)
        default:
            break
        }
    }

    /// Re-reads current entitlements (covers restores and refunds).
    /// Revoked remove-ads (refund) clears the flag so ads return.
    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.removeAdsID,
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        let changed = await MainActor.run { () -> Bool in
            let changed = (self.removeAds != entitled)
            self.removeAds = entitled
            UserDefaults.standard.set(entitled, forKey: Keys.removeAds)
            return changed
        }
        _ = changed
    }
}

enum StoreError: Error {
    case failedVerification
}
