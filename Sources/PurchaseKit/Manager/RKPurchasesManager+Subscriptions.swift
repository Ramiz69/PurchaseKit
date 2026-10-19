//
//  RKPurchasesManager+Subscriptions.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 19.10.2026.
//

import Foundation
import StoreKit

/// Active subscriptions, renewal status and introductory-offer eligibility.
extension PurchasesManager {

    // MARK: Public methods

    /// Returns all active auto-renewable subscriptions mapped to ``StoreProduct``.
    ///
    /// "Auto-renewable" is ``ProductType/isAutoRenewableSubscription``, so subscription
    /// bundles and suites count; comparing against ``ProductType/autoRenewable`` alone made a
    /// bundle subscriber look unsubscribed. Products not cached yet are fetched from StoreKit,
    /// all in one request, and cached.
    public func activeSubscriptions() async -> [StoreProduct] {
        await entitledProducts()
            .map(\.product)
            .filter { $0.type.isAutoRenewableSubscription }
    }
    /// Returns the best active subscription for the given subscription group.
    ///
    /// If multiple entitlements from the same group are present, the one with the latest
    /// expiration date is returned. Bundles and suites count, as in ``activeSubscriptions()``.
    /// - Parameter groupID: Subscription group identifier as configured in App Store Connect.
    public func activeSubscription(inGroup groupID: String) async -> StoreProduct? {
        var best: (product: StoreProduct, expires: Date?)?
        for (product, transaction) in await entitledProducts() {
            // Keep only auto-renewable subscriptions belonging to the requested group.
            guard product.type.isAutoRenewableSubscription, product.subscriptionGroupID == groupID else {
                continue
            }

            // Auto-renewable transactions normally carry an expiration date.
            let expiration = transaction.expirationDate
            if best == nil || compare(expiration, isLaterThan: best?.expires) {
                best = (product, expiration)
            }
        }

        return best?.product
    }
    /// Returns every renewal status StoreKit holds for a subscription group.
    ///
    /// Statuses whose transaction fails verification are left out; renewal information that
    /// fails verification only empties the renewal fields. See
    /// ``StoreSubscriptionStatus`` for the rules.
    ///
    /// - Parameter groupID: Subscription group identifier as configured in App Store Connect.
    /// - Throws: ``PurchasesError``; StoreKit's own errors are translated into its cases.
    public nonisolated func subscriptionStatuses(inGroup groupID: String) async throws -> [StoreSubscriptionStatus] {
        do {
            return try await Product.SubscriptionInfo.status(for: groupID).compactMap(StoreSubscriptionStatus.init)
        } catch {
            throw PurchasesError.mapping(error)
        }
    }
    /// Returns whether the customer may still redeem an introductory offer in the group.
    ///
    /// Asked of StoreKit every time rather than cached: redeeming an offer on another device
    /// ends eligibility here too, and a stale `true` would advertise a trial the purchase
    /// sheet then refuses.
    ///
    /// - Parameter groupID: Subscription group identifier as configured in App Store Connect.
    public nonisolated func isEligibleForIntroOffer(inGroup groupID: String) async -> Bool {
        await Product.SubscriptionInfo.isEligibleForIntroOffer(for: groupID)
    }

    // MARK: Private methods

    /// The current, unrevoked entitlements paired with their products, in StoreKit's order.
    ///
    /// Shared by the two active-subscription queries so they read entitlements the same way.
    /// Products the cache does not hold are fetched in one request and cached as purchased -
    /// each has an entitlement this very moment. One that StoreKit does not return is left
    /// out rather than guessed at.
    private func entitledProducts() async -> [(product: StoreProduct, transaction: Transaction)] {
        var transactions: [Transaction] = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  transaction.revocationDate == nil
            else { continue }

            transactions.append(transaction)
        }
        await cacheMissingProducts(Set(transactions.map(\.productID)), purchased: true)

        return transactions.compactMap { transaction in
            productsCache[transaction.productID].map { (product: $0, transaction: transaction) }
        }
    }

    private func compare(_ lhs: Date?, isLaterThan rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case let (l?, r?): l > r
        case (.some, .none): true
        default: false
        }
    }
}
