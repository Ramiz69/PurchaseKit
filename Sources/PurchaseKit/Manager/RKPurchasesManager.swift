//
//  RKPurchasesManager.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit
import Synchronization

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
        guard let instance = storage.withLock({ $0 }) else {
            fatalError("❗️ PurchasesManager.configure(identifiers:) must be called before first use.")
        }

        return instance
    }
    /// The configured singleton, without trapping when there is none.
    ///
    /// ``shared`` is the convenient form and treats a missing configuration as a programmer
    /// error. Use this where the caller can react instead — a plug-in surface, or a path
    /// that may run before ``configure(identifiers:)``.
    ///
    /// - Throws: ``PurchasesError/notConfigured``.
    public nonisolated static func resolved() throws -> PurchasesManager {
        guard let instance = storage.withLock({ $0 }) else {
            throw PurchasesError.notConfigured
        }

        return instance
    }
    /// Async stream of purchase events emitted when a product becomes entitled.
    ///
    /// You can `for await` this stream to reactively update UI or unlock features.
    ///
    /// Every access returns a fresh stream that receives every event, so several observers
    /// can watch at once. Reading this once and iterating the result twice does not: a
    /// single `AsyncStream` splits its events between iterators. Events are not replayed,
    /// so read the current state with ``hasEntitlement(for:)`` or ``requestProducts(includingCache:)``
    /// when a subscriber starts.
    public nonisolated var purchasedProducts: AsyncStream<PurchasedProductEvent> {
        broadcaster.makeStream()
    }
    private let identifiers: [String]
    private var productsCache: [String: StoreProduct] = [:]
    private let broadcaster = EventBroadcaster<PurchasedProductEvent>()
    private var updateListenerTask: Task<Void, Never>?
    /// Backing store for ``shared``.
    ///
    /// `nonisolated(unsafe)` opted the singleton out of the compiler's checking without
    /// putting anything in its place: `configure(identifiers:)` wrote this while other
    /// threads read it through ``shared``, which ThreadSanitizer reports as a data race, and
    /// racing reference-count traffic on an unsynchronised reference can leave a dangling
    /// one. A mutex makes the access checked and lets configure's test-and-set be atomic.
    private static let storage = Mutex<PurchasesManager?>(nil)

    // MARK: Initial methods

    private init(identifiers: [String]) {
        // Keep the caller's order but drop repeats: the order is what `requestProducts`
        // returns, and a duplicated identifier would surface the same product twice.
        var seen: Set<String> = []
        self.identifiers = identifiers.filter { seen.insert($0).inserted }
    }

    deinit {
        updateListenerTask?.cancel()
        broadcaster.finish()
    }

    // MARK: Public methods

    /// Creates the singleton and starts the StoreKit transaction listener.
    ///
    /// - Parameter identifiers: Product IDs registered in App Store Connect.
    /// - Returns: The configured singleton instance.
    @discardableResult
    public nonisolated static func configure(identifiers: [String]) -> PurchasesManager {
        // Test and set under one lock. Checking `instance == nil` and assigning separately is
        // a check-then-act on unsynchronised memory: two concurrent calls could both pass the
        // check, and the precondition that is supposed to forbid that would not fire.
        let instance = storage.withLock { stored -> PurchasesManager in
            precondition(
                stored == nil,
                "PurchasesManager.configure(_:) has already been called. Double configuration is not allowed."
            )
            let instance = PurchasesManager(identifiers: identifiers)
            stored = instance

            return instance
        }
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
            let cachedProducts = configuredProducts
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

        return configuredProducts
    }
    /// Performs a purchase flow for the given product identifier.
    public func purchase(productID: String) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
        let product = try await storeKitProduct(for: productID)

        switch try await product.purchase() {
        case .success(let result):
            let transaction = try checkVerified(result)
            await transaction.finish()
            // Read the flag *after* the suspension above. The transaction listener may have
            // rebuilt entitlements while this was suspended and already emitted for this
            // product; re-reading here keeps a purchase to one event. Caching straight to
            // `true` also avoids the old reset-to-`false`-then-set-`true` pass, which made
            // the product look briefly unentitled.
            let wasEntitled = productsCache[product.id]?.isPurchased ?? false
            let purchased = cache(product, purchased: true)
            if !wasEntitled {
                broadcaster.yield(PurchasedProductEvent(product: purchased))
            }

            return (product: purchased, transaction: StoreTransaction(transaction: transaction))
        case .userCancelled:
            throw PurchasesError.purchaseCancelled
        case .pending:
            throw PurchasesError.purchasePending
        default:
            // `Product.PurchaseResult` is non-frozen, so a StoreKit release can add a case
            // this SDK predates.
            throw PurchasesError.unhandledPurchaseResult
        }
    }
    /// Syncs with the App Store and refreshes current entitlements.
    public func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }
    /// Returns `true` if the user currently has an active entitlement for `productID`.
    ///
    /// A cached `true` is taken at face value as a fast path. Anything else is resolved
    /// against `Transaction.currentEntitlements`, because a cached `false` only means the
    /// entitlement has not been observed yet.
    public func hasEntitlement(for productID: String) async -> Bool {
        // The cache is authoritative only when it says yes. A cached `false` may simply mean
        // the entitlement has not been read yet — a purchase made on another device, or a cold
        // start before the first refresh — so that case has to reach StoreKit. Returning the
        // cached `false` directly made those users look unentitled.
        if productsCache[productID]?.isPurchased == true {
            return true
        }

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            if transaction.productID == productID, transaction.revocationDate == nil {
                return true
            }
        }

        return false
    }
    /// Returns the set of product identifiers for which the user has an active entitlement.
    public func entitlementProductIDs() async -> Set<String> {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  transaction.revocationDate == nil
            else { continue }

            ids.insert(transaction.productID)
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
            guard let transaction = try? checkVerified(resultTransaction),
                  transaction.revocationDate == nil
            else { continue }

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
            guard let transaction = try? checkVerified(resultTransaction),
                  transaction.revocationDate == nil
            else { continue }

            // Keep only auto-renewable subscriptions belonging to the requested group.
            if let product = try? await storeProduct(for: transaction.productID),
               product.type == .autoRenewable,
               product.subscriptionGroupID == groupID
            {
                // Auto-renewable transactions normally carry an expiration date.
                let expiration = transaction.expirationDate
                if best == nil || compare(expiration, isLaterThan: best?.expires) {
                    best = (product, expiration)
                }
            }
        }
        return best?.product
    }

    // MARK: Private methods

    /// Cached products for the configured identifiers, in the order passed to
    /// ``configure(identifiers:)``.
    ///
    /// `productsCache` is keyed by identifier, so iterating it yields a different order on
    /// every run and shuffles the paywall. It also holds products cached opportunistically
    /// from entitlements, which were never part of `identifiers` and must not be returned.
    private var configuredProducts: [StoreProduct] {
        identifiers.compactMap { productsCache[$0] }
    }

    private func startListener() {
        guard updateListenerTask == nil else { return }

        // `self` is captured weakly and re-acquired per update. Wrapping an isolated call
        // in a plain `Task { ... }` captures it strongly instead, and because
        // `Transaction.updates` never ends, that kept the actor alive forever: `deinit` was
        // unreachable, so the cancel and finish it performs could never run.
        updateListenerTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }

                await self.handle(result)
            }
        }
    }

    @discardableResult
    private func cache(_ product: Product, purchased: Bool = false) -> StoreProduct {
        let stored = map(product, purchased)
        productsCache[product.id] = stored

        return stored
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
    private func updateCustomerProductStatus() async {
        await refreshEntitlements()
    }
    /// Finishes one live transaction update and rebuilds entitlement state.
    private func handle(_ result: VerificationResult<Transaction>) async {
        guard let transaction = try? checkVerified(result) else { return }

        await transaction.finish()
        // `Transaction.updates` also delivers revocations: refunds, a family-sharing grant
        // being withdrawn, an entitlement expiring. Marking the product purchased could only
        // ever set the flag to `true`, so a refund arrived here as a purchase — and emitted a
        // `PurchasedProductEvent` for it. Rebuilding from `currentEntitlements` moves the
        // flag in both directions.
        await refreshEntitlements()
    }
    /// Rebuilds the entitlement state from `Transaction.currentEntitlements`.
    ///
    /// Collects the entitled identifiers, caching any product not seen before, then applies
    /// the difference against the cache. Flags move in both directions, and
    /// ``purchasedProducts`` only emits for a product that has actually become entitled.
    private func refreshEntitlements() async {
        var entitled: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  transaction.revocationDate == nil
            else { continue }

            entitled.insert(transaction.productID)
            if productsCache[transaction.productID] == nil,
               let fetched = try? await Product.products(for: [transaction.productID]).first {
                cache(fetched)
            }
        }

        // Apply the difference rather than clearing every flag and setting it again. The
        // clear-then-reapply pass left every entitled product looking newly purchased on each
        // refresh, so the event stream repeated itself for products the subscriber already
        // knew about — and it never cleared a flag that had genuinely gone away.
        for productID in productsCache.keys.sorted() {
            guard let storeProduct = productsCache[productID] else { continue }

            let isEntitled = entitled.contains(productID)
            guard storeProduct.isPurchased != isEntitled else { continue }

            let updated = storeProduct.setPurchasingFlag(isEntitled)
            productsCache[productID] = updated
            if isEntitled {
                broadcaster.yield(PurchasedProductEvent(product: updated))
            }
        }
    }
    /// Ensures a ``StoreProduct`` for `productID`, fetching it if needed.
    private func storeProduct(for productID: String) async throws -> StoreProduct {
        if let cached = productsCache[productID] {
            return cached
        }

        return cache(try await fetchProduct(for: productID))
    }
    /// Returns the StoreKit product for `productID`, reusing the cached one when there is one.
    ///
    /// Purchasing used to re-fetch unconditionally, spending a network round trip on a
    /// product the cache was already holding.
    private func storeKitProduct(for productID: String) async throws -> Product {
        if let cached = productsCache[productID], let product = cached.product {
            return product
        }

        return try await fetchProduct(for: productID)
    }

    private func fetchProduct(for productID: String) async throws -> Product {
        guard let fetched = try await Product.products(for: [productID]).first else {
            throw PurchasesError.invalidProductID(productID)
        }

        return fetched
    }

    private func compare(_ lhs: Date?, isLaterThan rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case let (l?, r?): l > r
        case (.some, .none): true
        default: false
        }
    }
}
