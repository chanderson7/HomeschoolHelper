import SwiftUI
import StoreKit

// MARK: - Subscription Manager

@MainActor
public final class SubscriptionManager: ObservableObject {
    public static let shared = SubscriptionManager()

    nonisolated public static let annualProductIDs: [String] = [
        "com.andersonsites.ezhomeschool.pro.annual",
        "com.chanderson7.HomeSchoolHelper.pro.annual",
        "com.andersonsites.ezhomeschool.annual",
        "ezhomeschool.pro.annual",
        "pro.annual",
        "annual"
    ]
    nonisolated public static let monthlyProductIDs: [String] = [
        "com.andersonsites.ezhomeschool.pro.monthly",
        "com.chanderson7.HomeSchoolHelper.pro.monthly",
        "com.andersonsites.ezhomeschool.monthly",
        "ezhomeschool.pro.monthly",
        "pro.monthly",
        "monthly"
    ]
    nonisolated public static let annualProductID = annualProductIDs[0]
    nonisolated public static let monthlyProductID = monthlyProductIDs[0]

    nonisolated public static let defaultProductIDs: Set<String> = Set(annualProductIDs + monthlyProductIDs)

    public static var isSandboxEnvironment: Bool {
        #if DEBUG
        return true
        #else
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
        return receiptURL.lastPathComponent == "sandboxReceipt"
        #endif
    }

    nonisolated public static func isAnnualProduct(_ id: String) -> Bool {
        annualProductIDs.contains(id) || id.localizedCaseInsensitiveContains("annual")
    }

    nonisolated public static func isMonthlyProduct(_ id: String) -> Bool {
        monthlyProductIDs.contains(id) || id.localizedCaseInsensitiveContains("monthly")
    }

    private let testFlightBypassKey = "HSH_TESTFLIGHT_PRO_BYPASS"

    @Published public private(set) var isPro: Bool = false
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var purchasedProductIDs: Set<String> = []
    @Published public private(set) var isPurchasing: Bool = false
    @Published public private(set) var isLoadingProducts: Bool = false
    @Published public private(set) var lastLoadError: String? = nil
    @Published public var purchaseError: String? = nil

    // Diagnostics
    @Published public private(set) var lastQueryDate: Date? = nil
    @Published public private(set) var queriedProductIDs: [String] = []
    @Published public private(set) var customProductIDs: [String] = []
    @Published public private(set) var isTestFlightBypassActive: Bool = false

    public var effectiveProductIDs: Set<String> {
        Self.defaultProductIDs.union(customProductIDs)
    }

    private var transactionListenerTask: Task<Void, Never>?

    public init() {
        if Self.isSandboxEnvironment && UserDefaults.standard.bool(forKey: testFlightBypassKey) {
            self.isTestFlightBypassActive = true
            self.isPro = true
        }

        #if DEBUG
        if ProcessInfo.processInfo.environment["HSH_PRO_OVERRIDE"] == "1" || ProcessInfo.processInfo.environment["HSH_UI_TEST_ID"] != nil {
            self.isPro = true
        }
        #endif

        transactionListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    public func addCustomProductID(_ id: String) async {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !customProductIDs.contains(trimmed) else { return }
        customProductIDs.append(trimmed)
        await loadProducts()
    }

    public func toggleTestFlightBypass(enabled: Bool) {
        guard Self.isSandboxEnvironment else { return }
        isTestFlightBypassActive = enabled
        UserDefaults.standard.set(enabled, forKey: testFlightBypassKey)
        if enabled {
            isPro = true
        } else {
            Task {
                await updatePurchasedProducts()
            }
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
        isLoadingProducts = true
        lastLoadError = nil
        lastQueryDate = Date()
        queriedProductIDs = Array(effectiveProductIDs).sorted()
        defer { isLoadingProducts = false }

        do {
            let loaded = try await Product.products(for: effectiveProductIDs)
            self.products = loaded.sorted { lhs, rhs in
                // Sort annual first
                Self.isAnnualProduct(lhs.id)
            }
            if loaded.isEmpty {
                self.lastLoadError = "No in-app products were returned by the App Store for IDs: \(queriedProductIDs.joined(separator: ", ")). Please verify that subscriptions are active in App Store Connect."
            }
        } catch {
            self.lastLoadError = error.localizedDescription
            print("StoreKit: Failed to load products: \(error.localizedDescription)")
        }
    }

    public func updatePurchasedProducts() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["HSH_PRO_OVERRIDE"] == "1" || ProcessInfo.processInfo.environment["HSH_UI_TEST_ID"] != nil {
            self.isPro = true
            return
        }
        #endif

        if isTestFlightBypassActive {
            self.isPro = true
            return
        }

        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if let transaction = try? Self.checkVerified(result) {
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            }
        }

        self.purchasedProductIDs = purchased
        let hasActivePro = purchased.contains { effectiveProductIDs.contains($0) || Self.isAnnualProduct($0) || Self.isMonthlyProduct($0) }
        self.isPro = hasActivePro || isTestFlightBypassActive
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

public extension Product {
    var isAnnual: Bool {
        SubscriptionManager.isAnnualProduct(id) || subscription?.subscriptionPeriod.unit == .year
    }
    var isMonthly: Bool {
        SubscriptionManager.isMonthlyProduct(id) || subscription?.subscriptionPeriod.unit == .month
    }
}
