//
//  RKPurchasesManager.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit

/// ``PurchasesManager`` – entry point to `RKPurchaseKit`.
///
/// The manager is an `actor` and is therefore safe to use from concurrent contexts.
/// It holds a product cache, listens for `Transaction.updates`, and exposes a simple
/// API for fetching products, purchasing, restoring, and querying current entitlements.
/// See <doc:PurchasesManager> for the overview.
public actor PurchasesManager: PurchasesProtocol {

    // MARK: Properties

    /// Global singleton configured via ``configure(identifiers:)``.
    public nonisolated static var shared: PurchasesManager {
        guard let instance else {
            fatalError("❗️ PurchasesActor.configure(identifiers:) must be called before first use.")
        }

        return instance
    }
    /// Async stream of purchase events emitted when a product becomes entitled.
    ///
    /// You can `for await` this stream to reactively update UI or unlock features.
    public nonisolated let purchasedProducts: AsyncStream<PurchasedProductEvent>
    private let identifiers: [String]
    private var productsCache: [String: StoreProduct] = [:]
    private let continuation: AsyncStream<PurchasedProductEvent>.Continuation
    private var updateListenerTask: Task<Void, Never>?
    nonisolated(unsafe) private static var instance: PurchasesManager?

    // MARK: Initial methods

    private init(identifiers: [String]) {
        self.identifiers = identifiers
        let pair = AsyncStream.makeStream(of: PurchasedProductEvent.self)
        self.purchasedProducts = pair.stream
        self.continuation = pair.continuation
    }

    deinit {
        updateListenerTask?.cancel()
        continuation.finish()
    }

    // MARK: Public methods

    /// Creates the singleton and starts the StoreKit transaction listener.
    ///
    /// - Parameter identifiers: Product IDs registered in App Store Connect.
    /// - Returns: The configured singleton instance.
    @discardableResult
    public nonisolated static func configure(identifiers: [String]) -> PurchasesManager {
        precondition(instance == nil, "PurchasesActor.configure(_:) has already been called. Double configuration is not allowed.")
        let instance = PurchasesManager(identifiers: identifiers)
        self.instance = instance
        Task.detached {
            await instance.startListener()
        }

        return instance
    }
    /// Fetches products from StoreKit (optionally returns cache first).
    ///
    /// If cache is used, entitlements are refreshed asynchronously so the
    /// `isPurchased` flag remains accurate.
    public func requestProducts(includingCache: Bool = true) async throws -> [StoreProduct] {
        if includingCache {
            let cachedProducts = productsCache.values.map { $0 }
            if !cachedProducts.isEmpty {
                Task { await self.refreshEntitlements() }
                return cachedProducts
            }
        }
        let storeProducts = try await Product.products(for: identifiers)
        for product in storeProducts {
            cache(product)
        }
        await updateCustomerProductStatus()

        return productsCache.values.map { $0 }
    }
    /// Performs a purchase flow for the given product identifier.
    public func purchase(productID: String) async throws -> (product: StoreProduct, transaction: Transaction) {
        guard let product = try await Product.products(for: [productID]).first else {
            throw PurchasesError.invalidProductID(productID)
        }

        switch try await product.purchase() {
        case .success(let result):
            let transaction = try checkVerified(result)
            await transaction.finish()
            cache(product)
            try await markPurchased(productID: product.id)

            return (product: productsCache[product.id]!, transaction: transaction)
        case .userCancelled:
            throw PurchasesError.purchaseCancelled
        case .pending:
            throw PurchasesError.purchasePending
        default:
            throw PurchasesError.unknown(PurchasesError.unknown(NSError(domain: "unknown", code: -1)))
        }
    }
    /// Syncs with the App Store and refreshes current entitlements.
    public func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }
    /// Returns `true` if the user currently has an active entitlement for `productID`.
    ///
    /// Uses `Transaction.currentEntitlements` under the hood and falls back to the cache
    /// if available for fast checks.
    public func hasEntitlement(for productID: String) async -> Bool {
        if let cached = productsCache[productID] {
            return cached.isPurchased
        }
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result), transaction.productID == productID {
                return true
            }
        }
        return false
    }
    /// Returns the set of product identifiers for which the user has an active entitlement.
    public func entitlementProductIDs() async -> Set<String> {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                ids.insert(transaction.productID)
            }
        }
        return ids
    }
    /// Returns all active **auto-renewable** subscriptions mapped to ``StoreProduct``.
    ///
    /// If a product is not yet cached, it will be fetched from StoreKit and cached.
    public func activeSubscriptions() async -> [StoreProduct] {
        if productsCache.isEmpty {
            _ = try? await requestProducts(includingCache: true)
        }
        var result: [StoreProduct] = []
        for await resultTransaction in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(resultTransaction) else { continue }

            if let product = productsCache[transaction.productID], product.type == .autoRenewable {
                result.append(product)
            } else if productsCache[transaction.productID] == nil {
                if let fetched = try? await Product.products(for: [transaction.productID]).first {
                    cache(fetched, purchased: true)
                    if let storeProduct = productsCache[transaction.productID], storeProduct.type == .autoRenewable {
                        result.append(storeProduct)
                    }
                }
            }
        }
        return result
    }
    /// Returns the best active subscription for the given subscription group.
    ///
    /// If multiple entitlements from the same group are present, the one with the latest
    /// expiration date is returned.
    /// - Parameter groupID: Subscription group identifier as configured in App Store Connect.
    public func activeSubscription(inGroup groupID: String) async -> StoreProduct? {
        var best: (product: StoreProduct, expires: Date?)?
        if productsCache.isEmpty {
            _ = try? await requestProducts(includingCache: true)
        }
        for await resultTransaction in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(resultTransaction) else { continue }
            // Проверяем, что это подписка в нужной группе
            if let product = try? await storeProduct(for: transaction.productID),
               product.type == .autoRenewable,
               product.subscriptionGroupID == groupID
            {
                // У auto-renewable подписок у транзакции обычно есть expirationDate
                let expiration = transaction.expirationDate
                if best == nil || compare(expiration, isLaterThan: best?.expires) {
                    best = (product, expiration)
                }
            }
        }
        return best?.product
    }

    // MARK: Private methods

    private func startListener() async {
        guard updateListenerTask == nil else { return }

        updateListenerTask = Task { await listenForTransactions() }
    }

    private func cache(_ product: Product, purchased: Bool = false) {
        productsCache[product.id] = map(product, purchased)
    }

    private func map(_ product: Product, _ isPurchased: Bool) -> StoreProduct {
        StoreProduct(product: product, isPurchased: isPurchased)
    }
    /// Verifies StoreKit's `VerificationResult` and returns the signed value.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let signed): signed
        case .unverified: throw PurchasesError.verificationFailed
        }
    }
    /// Marks the given product as purchased and emits a ``PurchasedProductEvent``.
    private func markPurchased(productID: String) async throws {
        guard let cached = productsCache[productID] else { return }

        let updated = cached.setPurchasingFlag(true)
        productsCache[productID] = updated
        continuation.yield(PurchasedProductEvent(product: updated))
    }

    private func updateCustomerProductStatus() async {
        await refreshEntitlements()
    }
    /// Listens to live transaction updates and finishes them.
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? checkVerified(result) else { continue }

            try? await markPurchased(productID: transaction.productID)
            await transaction.finish()
        }
    }
    /// Rebuilds the entitlement state:
    /// 1) Clears `isPurchased` on all cached products.
    /// 2) Sets it to `true` for anything present in `Transaction.currentEntitlements`.
    private func refreshEntitlements() async {
        // 1) Clear all flags
        if !productsCache.isEmpty {
            for (index, storeProduct) in productsCache where storeProduct.isPurchased {
                productsCache[index] = storeProduct.setPurchasingFlag(false)
            }
        }
        // 2) Apply current entitlements
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            if productsCache[transaction.productID] == nil {
                if let fetched = try? await Product.products(for: [transaction.productID]).first {
                    cache(fetched, purchased: true)
                    continue
                }
            }
            try? await markPurchased(productID: transaction.productID)
        }
    }
    /// Ensures a ``StoreProduct`` for `productID`, fetching it if needed.
    private func storeProduct(for productID: String) async throws -> StoreProduct {
        if let cached = productsCache[productID] {
            return cached
        }
        guard let fetched = try await Product.products(for: [productID]).first else {
            throw PurchasesError.invalidProductID(productID)
        }

        cache(fetched)

        return productsCache[productID]!
    }

    private func compare(_ lhs: Date?, isLaterThan rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case let (l?, r?): l > r
        case (.some, .none): true
        default: false
        }
    }
}
