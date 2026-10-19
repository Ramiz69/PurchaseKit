//
//  RKPurchasesManager.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit
import Synchronization
#if os(visionOS)
public import UIKit
#endif

/// ``PurchasesManager`` – entry point to `RKPurchaseKit`.
///
/// The manager is an `actor` and is therefore safe to use from concurrent contexts.
/// It holds a product cache, listens for `Transaction.updates` and subscription status
/// updates, and exposes a simple API for fetching products, purchasing, restoring, and
/// querying current entitlements and subscription state.
/// See <doc:PurchasesManager> for the overview.
///
/// Split across files by topic: subscriptions live in `RKPurchasesManager+Subscriptions.swift`
/// and the scene-based App Store sheets in `RKPurchasesManager+StoreSheets.swift`. The state
/// they share is therefore `internal` rather than `private`.
public actor PurchasesManager: ServerVerifiedPurchasesProtocol {

    // MARK: Properties

    /// Global singleton configured via ``configure(identifiers:finishing:)``.
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
    /// that may run before ``configure(identifiers:finishing:)``.
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
    /// Every verified transaction StoreKit delivers outside a purchase call.
    ///
    /// Under ``FinishPolicy/manual`` these arrive unfinished: forward each to your server
    /// and call ``finish(_:)`` once it has been accepted. Under ``FinishPolicy/automatic``
    /// they are already finished and the stream is informational.
    ///
    /// Each access returns a fresh stream; events are not replayed and a slow subscriber
    /// drops the oldest. Nothing is lost under ``FinishPolicy/manual``: an unfinished
    /// transaction stays in StoreKit and ``unfinishedTransactions()`` returns it.
    public nonisolated var transactionUpdates: AsyncStream<StoreTransaction> {
        transactionBroadcaster.makeStream()
    }
    /// Every renewal status StoreKit reports while the app runs: renewals, expirations,
    /// billing failures, plan changes, refunds.
    ///
    /// Same delivery rules as ``purchasedProducts``: every access returns a fresh stream,
    /// events are not replayed, and a slow subscriber drops the oldest. Read the current
    /// state with ``PurchasesProtocol/subscriptionStatus(inGroup:)`` when a subscriber
    /// starts. Statuses whose transaction fails verification are not delivered.
    public nonisolated var subscriptionStatusUpdates: AsyncStream<StoreSubscriptionStatus> {
        statusBroadcaster.makeStream()
    }
    /// Who finishes transactions, fixed at ``configure(identifiers:finishing:)``.
    public nonisolated let finishPolicy: FinishPolicy
    /// Configured identifiers StoreKit did not return on the last fetch by
    /// ``requestProducts(includingCache:)``.
    ///
    /// `Product.products(for:)` drops an unknown identifier silently instead of failing, so a
    /// typo or a product that is not yet "Ready to Submit" otherwise shows up only as a
    /// paywall that is one row short. Empty until the first fetch.
    public private(set) var unavailableProductIDs: Set<String> = []
    private let identifiers: [String]
    var productsCache: [String: StoreProduct] = [:]
    private let broadcaster = EventBroadcaster<PurchasedProductEvent>()
    private let transactionBroadcaster = EventBroadcaster<StoreTransaction>()
    private let statusBroadcaster = EventBroadcaster<StoreSubscriptionStatus>()
    private var updateListenerTask: Task<Void, Never>?
    private var statusListenerTask: Task<Void, Never>?
    /// Backing store for ``shared``.
    ///
    /// `nonisolated(unsafe)` opted the singleton out of the compiler's checking without
    /// putting anything in its place: `configure(identifiers:)` wrote this while other
    /// threads read it through ``shared``, which ThreadSanitizer reports as a data race, and
    /// racing reference-count traffic on an unsynchronised reference can leave a dangling
    /// one. A mutex makes the access checked and lets configure's test-and-set be atomic.
    private static let storage = Mutex<PurchasesManager?>(nil)

    // MARK: Initial methods

    private init(identifiers: [String], finishing finishPolicy: FinishPolicy) {
        self.finishPolicy = finishPolicy
        // Keep the caller's order but drop repeats: the order is what `requestProducts`
        // returns, and a duplicated identifier would surface the same product twice.
        var seen: Set<String> = []
        self.identifiers = identifiers.filter { seen.insert($0).inserted }
    }

    deinit {
        updateListenerTask?.cancel()
        statusListenerTask?.cancel()
        broadcaster.finish()
        transactionBroadcaster.finish()
        statusBroadcaster.finish()
    }

    // MARK: Public methods

    /// Creates the singleton and starts the StoreKit transaction listener.
    ///
    /// - Parameters:
    ///   - identifiers: Product IDs registered in App Store Connect.
    ///   - finishing: Who finishes transactions. Use ``FinishPolicy/manual`` when your server
    ///     credits purchases, so nothing is finished before the server has accepted it.
    /// - Returns: The configured singleton instance.
    @discardableResult
    public nonisolated static func configure(
        identifiers: [String],
        finishing: FinishPolicy = .automatic
    ) -> PurchasesManager {
        // Test and set under one lock. Checking `instance == nil` and assigning separately is
        // a check-then-act on unsynchronised memory: two concurrent calls could both pass the
        // check, and the precondition that is supposed to forbid that would not fire.
        let instance = storage.withLock { stored -> PurchasesManager in
            precondition(
                stored == nil,
                "PurchasesManager.configure(_:) has already been called. Double configuration is not allowed."
            )
            let instance = PurchasesManager(identifiers: identifiers, finishing: finishing)
            stored = instance

            return instance
        }
        Task.detached {
            await instance.startListener()
            await instance.startStatusListener()
        }

        return instance
    }
    /// Fetches products from StoreKit (optionally returns cache first).
    ///
    /// If cache is used, entitlements are refreshed asynchronously so the
    /// `isPurchased` flag remains accurate. A fetch also updates ``unavailableProductIDs``.
    ///
    /// - Throws: ``PurchasesError`` if StoreKit lookup fails.
    public func requestProducts(includingCache: Bool = true) async throws -> [StoreProduct] {
        if includingCache {
            let cachedProducts = configuredProducts
            if !cachedProducts.isEmpty {
                Task { await self.refreshEntitlements() }
                return cachedProducts
            }
        }
        let storeProducts: [Product]
        do {
            storeProducts = try await Product.products(for: identifiers)
        } catch {
            throw PurchasesError.mapping(error)
        }
        for product in storeProducts {
            // Keep the flag the cache already holds. Re-caching as unpurchased made the
            // refresh below see every entitled product flip back to `true` and announce it
            // as a new purchase on every uncached fetch.
            cache(product, purchased: productsCache[product.id]?.isPurchased ?? false)
        }
        unavailableProductIDs = Set(identifiers).subtracting(storeProducts.map(\.id))
        await updateCustomerProductStatus()

        return configuredProducts
    }
    #if !os(visionOS)
    /// Performs a purchase flow for the given product identifier with `options` applied.
    ///
    /// The one purchase path: `purchase(productID:)` and `purchase(productID:appAccountToken:)`
    /// are protocol conveniences that build the options and land here.
    ///
    /// With an ``PurchaseOptions/appAccountToken`` StoreKit signs the token into the
    /// transaction, so a server can refuse to credit a purchase made for a different account.
    /// Under ``FinishPolicy/manual`` the returned transaction is unfinished: send
    /// ``StoreTransaction/jwsRepresentation`` to the server, then call ``finish(_:)``.
    ///
    /// Not available on visionOS, where StoreKit has no purchase call without a scene to
    /// present the confirmation in. Use `purchase(productID:options:confirmIn:)` there.
    ///
    /// - Throws: ``PurchasesError``; StoreKit's own errors are translated into its cases.
    public func purchase(
        productID: String,
        options: PurchaseOptions
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
        do {
            let product = try await storeKitProduct(for: productID)
            // Resolved before StoreKit is asked, so an unknown win-back offer fails by name
            // instead of the sheet appearing at full price.
            let storeKitOptions = try options.storeKitOptions(for: product)

            return try await finishPurchase(try await product.purchase(options: storeKitOptions), of: product)
        } catch {
            throw PurchasesError.mapping(error)
        }
    }
    #endif

    #if os(visionOS)
    /// Performs a purchase flow for the given product identifier with `options` applied,
    /// presenting the App Store confirmation in `scene`.
    ///
    /// visionOS has no purchase call without a scene: `Product.purchase(options:)` is
    /// unavailable there, because a spatial app can show several windows and the system has
    /// to be told which one owns the confirmation sheet. Pass the scene the customer
    /// interacted with. In SwiftUI, prefer StoreKit's `PurchaseAction` from the environment,
    /// which resolves the scene for you.
    ///
    /// The one purchase path on visionOS: `purchase(productID:confirmIn:)` and
    /// `purchase(productID:appAccountToken:confirmIn:)` are protocol conveniences that land
    /// here.
    ///
    /// Runs on the main actor because StoreKit presents UI in `scene`; the entitlement
    /// bookkeeping afterwards still happens on this actor.
    ///
    /// - Throws: ``PurchasesError``; StoreKit's own errors are translated into its cases.
    @MainActor
    public func purchase(
        productID: String,
        options: PurchaseOptions,
        confirmIn scene: UIScene
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
        do {
            let product = try await storeKitProduct(for: productID)
            // Resolved before StoreKit is asked, so an unknown win-back offer fails by name
            // instead of the sheet appearing at full price.
            let storeKitOptions = try options.storeKitOptions(for: product)
            let result = try await product.purchase(confirmIn: scene, options: storeKitOptions)

            return try await finishPurchase(result, of: product)
        } catch {
            throw PurchasesError.mapping(error)
        }
    }
    #endif
    /// Finishes `transaction`, telling the App Store it has been delivered.
    ///
    /// Call under ``FinishPolicy/manual`` after your server has accepted the transaction.
    /// A value built by the kit carries its StoreKit transaction; one you built yourself is
    /// looked up in `Transaction.unfinished` by ``StoreTransaction/id``. Finishing a
    /// transaction that is already finished does nothing.
    public func finish(_ transaction: StoreTransaction) async {
        if let storeKitTransaction = transaction.transaction {
            await storeKitTransaction.finish()
        } else {
            for await result in Transaction.unfinished {
                guard let unfinished = try? checkVerified(result), unfinished.id == transaction.id else {
                    continue
                }

                await unfinished.finish()
                break
            }
        }
        await refreshEntitlements()
    }
    /// Verified transactions StoreKit still holds as unfinished.
    ///
    /// Under ``FinishPolicy/manual`` this is the list of purchases the server has not yet
    /// accepted. Read it at launch and after sign-in. Transactions that fail verification
    /// are left out: a server that checks the signature would reject them anyway.
    public func unfinishedTransactions() async -> [StoreTransaction] {
        var transactions: [StoreTransaction] = []
        for await result in Transaction.unfinished {
            guard let transaction = try? checkVerified(result) else { continue }

            transactions.append(StoreTransaction(transaction: transaction, jwsRepresentation: result.jwsRepresentation))
        }

        return transactions
    }
    /// Settles a purchase result: verifies and finishes the transaction, updates the cache
    /// and emits the event. Shared by every purchase entry point so they cannot drift apart.
    private func finishPurchase(
        _ purchaseResult: Product.PurchaseResult,
        of product: Product
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
        switch purchaseResult {
        case .success(let result):
            let transaction = try checkVerified(result)
            // Under `.manual` the app finishes once its server has credited the purchase.
            // Finishing here first would lose a consumable for good if that request then fails:
            // a finished consumable is never redelivered.
            if finishPolicy == .automatic {
                await transaction.finish()
            }
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

            return (
                product: purchased,
                transaction: StoreTransaction(transaction: transaction, jwsRepresentation: result.jwsRepresentation)
            )
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
    ///
    /// - Throws: ``PurchasesError``; a dismissed sign-in prompt is
    ///   ``PurchasesError/purchaseCancelled``.
    public func restore() async throws {
        do {
            try await AppStore.sync()
        } catch {
            throw PurchasesError.mapping(error)
        }
        await refreshEntitlements()
    }
    /// Returns `true` if the user currently has an active entitlement for `productID`.
    ///
    /// Always resolved against `Transaction.currentEntitlements(for:)`, and the cached flag is
    /// brought into line with the answer in both directions.
    public func hasEntitlement(for productID: String) async -> Bool {
        // StoreKit is asked every time. A cached `false` may only mean the entitlement has not
        // been read yet — a purchase made on another device, or a cold start before the first
        // refresh. A cached `true` used to be taken at face value, but it can outlive the
        // entitlement too: a revocation StoreKit never announces through `Transaction.updates`,
        // such as a cleared `SKTestSession`, left the product looking purchased for as long as
        // the process ran.
        //
        // Asked per product: scanning every entitlement to find one cost a full walk of the
        // customer's purchases on every check. A product can hold several entitlements (a
        // family-shared one beside an own purchase), so any unrevoked one answers yes.
        var isEntitled = false
        for await result in Transaction.currentEntitlements(for: productID) {
            guard let transaction = try? checkVerified(result) else { continue }

            if transaction.revocationDate == nil {
                isEntitled = true
                break
            }
        }

        if let cached = productsCache[productID], cached.isPurchased != isEntitled {
            let updated = cached.setPurchasingFlag(isEntitled)
            productsCache[productID] = updated
            if isEntitled {
                broadcaster.yield(PurchasedProductEvent(product: updated))
            }
        }

        return isEntitled
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
    /// Returns how and when the customer got the app itself.
    ///
    /// - Throws: ``PurchasesError/verificationFailed`` if the app transaction fails
    ///   verification, or another ``PurchasesError`` if StoreKit cannot read it.
    public nonisolated func appPurchaseInfo() async throws -> AppPurchaseInfo {
        do {
            let result = try await AppTransaction.shared

            return AppPurchaseInfo(appTransaction: try checkVerified(result), jwsRepresentation: result.jwsRepresentation)
        } catch {
            throw PurchasesError.mapping(error)
        }
    }
    /// The ISO 3166-1 alpha-3 country code of the App Store storefront the customer uses, or
    /// `nil` when StoreKit cannot tell (no account signed in, no connection).
    ///
    /// Prices and the availability of a product follow the storefront, not the device
    /// region, so this is the value to branch on for storefront-specific offers or copy.
    public nonisolated func currentStorefrontCountryCode() async -> String? {
        await Storefront.current?.countryCode
    }

    // MARK: Internal and private methods

    /// Cached products for the configured identifiers, in the order passed to
    /// ``configure(identifiers:finishing:)``.
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
    /// Starts relaying `Product.SubscriptionInfo.Status.updates` to
    /// ``subscriptionStatusUpdates``.
    ///
    /// A second task rather than a branch of the transaction listener: the two sequences are
    /// independent and never end, so one loop cannot wait on both. Same weak-`self` capture,
    /// for the same reason as ``startListener()``.
    private func startStatusListener() {
        guard statusListenerTask == nil else { return }

        statusListenerTask = Task { [weak self] in
            for await status in Product.SubscriptionInfo.Status.updates {
                guard let self else { return }
                // An unverified transaction makes the status a claim nobody signed; dropping
                // it matches what `subscriptionStatuses(inGroup:)` returns for the same input.
                guard let mapped = StoreSubscriptionStatus(status) else { continue }

                self.statusBroadcaster.yield(mapped)
            }
        }
    }

    @discardableResult
    func cache(_ product: Product, purchased: Bool = false) -> StoreProduct {
        let stored = map(product, purchased)
        productsCache[product.id] = stored

        return stored
    }

    private func map(_ product: Product, _ isPurchased: Bool) -> StoreProduct {
        StoreProduct(product: product, isPurchased: isPurchased)
    }
    /// Verifies StoreKit's `VerificationResult` and returns the signed value.
    ///
    /// `nonisolated` because it reads no state, so the calls that touch nothing else on the
    /// actor need not hop onto it.
    nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
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

        // Same rule as a purchase: under `.manual` the app finishes after its server has
        // accepted the transaction. Ask to Buy approvals and payments that completed later
        // arrive only here, so finishing them unconditionally would skip the server entirely.
        if finishPolicy == .automatic {
            await transaction.finish()
        }
        transactionBroadcaster.yield(StoreTransaction(transaction: transaction, jwsRepresentation: result.jwsRepresentation))
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
        }
        await cacheMissingProducts(entitled)

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
    /// Caches every product in `productIDs` that the cache does not hold yet, with one
    /// `Product.products(for:)` request.
    ///
    /// Entitlements used to be resolved one product per request, so a customer with many
    /// purchases cost as many round trips on every refresh. A failed fetch leaves the cache as
    /// it was; the next refresh tries again.
    ///
    /// - Parameter purchased: The flag to cache new products with.
    func cacheMissingProducts(_ productIDs: Set<String>, purchased: Bool = false) async {
        let missing = productIDs.filter { productsCache[$0] == nil }
        guard !missing.isEmpty, let fetched = try? await Product.products(for: missing) else { return }

        // Re-checked after the suspension: another call on this actor may have cached one of
        // these meanwhile, and its flag is newer than the one this call was given.
        for product in fetched where productsCache[product.id] == nil {
            cache(product, purchased: purchased)
        }
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
}
