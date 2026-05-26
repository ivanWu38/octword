import Foundation
import StoreKit

/// Subscription service using StoreKit 2
@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    private let productIds = [
        "com.octordle.premium.monthly.v1",
        "com.octordle.premium.quarterly.v1",
        "com.octordle.premium.yearly.v1"
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIds: Set<String> = []
    @Published private(set) var isLoading = false

    var isPremium: Bool {
        !purchasedProductIds.isEmpty
    }

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: productIds)
            self.products = products.sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
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

    func restore() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }

    // MARK: - Transaction Handling

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        self.purchasedProductIds = purchased
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
