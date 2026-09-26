import SwiftUI
import StoreKit

// MARK: - Subscription Manager

@MainActor
public final class SubscriptionManager: ObservableObject {
    public static let shared = SubscriptionManager()

    public static let annualProductID = "com.chanderson7.HomeSchoolHelper.pro.annual"
    public static let monthlyProductID = "com.chanderson7.HomeSchoolHelper.pro.monthly"

    public static let allProductIDs: Set<String> = [
        annualProductID,
        monthlyProductID
    ]

    @Published public private(set) var isPro: Bool = false
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var purchasedProductIDs: Set<String> = []
    @Published public private(set) var isPurchasing: Bool = false
    @Published public var purchaseError: String? = nil

    private var transactionListenerTask: Task<Void, Never>?

    public init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["HSH_PRO_OVERRIDE"] == "1" {
            self.isPro = true
        }
        #endif

        transactionListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? Self.checkVerified(result) {
                    await transaction.finish()
                    await self?.updatePurchasedProducts()
                }
            }
        }
    }

    // MARK: - Products & Entitlements

    public func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.allProductIDs)
            self.products = loaded.sorted { lhs, rhs in
                // Sort annual first
                lhs.id == Self.annualProductID
            }
        } catch {
            print("StoreKit: Failed to load products: \(error.localizedDescription)")
        }
    }

    public func updatePurchasedProducts() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["HSH_PRO_OVERRIDE"] == "1" {
            self.isPro = true
            return
        }
        #endif

        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if let transaction = try? Self.checkVerified(result) {
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            }
        }

        self.purchasedProductIDs = purchased
        self.isPro = !purchased.isEmpty
    }

    // MARK: - Purchase

    public func purchase(_ product: Product) async throws -> Bool {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Restore

    public func restorePurchases() async throws {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        try await AppStore.sync()
        await updatePurchasedProducts()
    }

    // MARK: - Verification Helper

    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
