//
//  DemoPurchases.swift
//  PaywallDemo
//

import Foundation
import RKPurchaseKit
import Synchronization
import UIKit

/// The states demo mode can put the paywall in.
enum DemoScenario: String, CaseIterable, Identifiable, Sendable {
    /// Real StoreKit, configured by `PaywallDemo.storekit` when run from Xcode.
    case live
    case newCustomer
    case subscribed
    case gracePeriod
    case billingRetry
    case expiredCancelled
    case expiredBillingError
    case revoked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .live: "Live StoreKit"
        case .newCustomer: "New Customer"
        case .subscribed: "Subscribed"
        case .gracePeriod: "Grace Period"
        case .billingRetry: "Billing Retry"
        case .expiredCancelled: "Expired: Cancelled"
        case .expiredBillingError: "Expired: Billing Error"
        case .revoked: "Revoked"
        }
    }

    var symbol: String {
        switch self {
        case .live: "bolt.horizontal.fill"
        case .newCustomer: "person.crop.circle.badge.plus"
        case .subscribed: "checkmark.seal"
        case .gracePeriod: "creditcard.trianglebadge.exclamationmark"
        case .billingRetry: "pause.circle"
        case .expiredCancelled: "hand.wave"
        case .expiredBillingError: "creditcard"
        case .revoked: "xmark.seal"
        }
    }

    /// The store the paywall talks to in this scenario.
    func makeBackend() -> any PurchasesBackend {
        switch self {
        case .live: PurchasesManager.shared
        default: DemoPurchases(scenario: self)
        }
    }
}

/// A stand-in store that answers like StoreKit would for a customer in one `DemoScenario`.
///
/// Everything here is built from the kit's public initializers: `StoreProduct`,
/// `SubscriptionOffer`, `StoreTransaction` and `StoreSubscriptionStatus` all have one, so a
/// mock needs no StoreKit configuration file, no simulator account and no `@testable import`.
/// The same type drives demo mode, the SwiftUI previews, and would drive unit tests.
///
/// Purchases succeed after a short delay and update the subscription state, so the live
/// update streams can be seen working. Showing "manage subscriptions" pretends the customer
/// fixed their payment method, which recovers a grace-period or billing-retry subscription.
final class DemoPurchases: PurchasesBackend {
    static let groupID = "demo.premium"

    private struct State {
        var status: StoreSubscriptionStatus?
        var entitled: Set<String> = []
        var hasUsedIntroOffer = false
        var purchaseContinuations: [UUID: AsyncStream<PurchasedProductEvent>.Continuation] = [:]
        var statusContinuations: [UUID: AsyncStream<StoreSubscriptionStatus>.Continuation] = [:]
    }

    /// `Mutex` keeps the class `Sendable`, which `PurchasesProtocol` requires, without
    /// turning it into an actor the previews would have to `await` into.
    private let state: Mutex<State>
    private let delay: Duration

    init(scenario: DemoScenario, delay: Duration = .milliseconds(700)) {
        let status = Self.status(for: scenario)
        var initial = State(status: status, hasUsedIntroOffer: status != nil)
        if status?.isActive == true, let productID = status?.transaction.productID {
            initial.entitled.insert(productID)
        }
        state = Mutex(initial)
        self.delay = delay
    }

    // MARK: PurchasesProtocol

    func requestProducts(includingCache: Bool) async throws -> [StoreProduct] {
        let entitled = state.withLock { $0.entitled }
        return Self.products(entitled: entitled)
    }

    func purchase(
        productID: String,
        options: PurchaseOptions
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
        try await Task.sleep(for: delay)

        // Mirror what StoreKit does with the same options, so the paywall's error handling
        // is exercised for real.
        if options.simulatesAskToBuyInSandbox {
            throw PurchasesError(.purchasePending, productID: productID)
        }
        guard let product = Self.products(entitled: []).first(where: { $0.productID == productID }) else {
            throw PurchasesError(.invalidProductID, productID: productID)
        }
        if let offerID = options.winBackOfferID, !product.winBackOffers.contains(where: { $0.id == offerID }) {
            throw PurchasesError(.offerNotFound, productID: productID, offerID: offerID)
        }

        let transaction = Self.transaction(for: product, purchased: .now)
        let (purchaseListeners, statusListeners, status) = state.withLock { state in
            if product.type != .consumable {
                state.entitled.insert(productID)
            }
            if product.type.isAutoRenewableSubscription {
                // A new subscription replaces whatever plan in the group came before.
                state.entitled.subtract(Self.subscriptionIDs.subtracting([productID]))
                state.hasUsedIntroOffer = true
                state.status = StoreSubscriptionStatus(
                    state: .subscribed,
                    groupID: Self.groupID,
                    transaction: transaction,
                    willAutoRenew: true,
                    autoRenewProductID: productID,
                    renewalDate: transaction.expirationDate
                )
            }
            return (
                Array(state.purchaseContinuations.values),
                Array(state.statusContinuations.values),
                state.status
            )
        }
        let purchased = Self.products(entitled: [productID]).first { $0.productID == productID } ?? product
        purchaseListeners.forEach { $0.yield(PurchasedProductEvent(product: purchased)) }
        if product.type.isAutoRenewableSubscription, let status {
            statusListeners.forEach { $0.yield(status) }
        }
        return (purchased, transaction)
    }

    func restore() async throws {
        try await Task.sleep(for: delay)
    }

    func hasEntitlement(for productID: String) async -> Bool {
        state.withLock { $0.entitled.contains(productID) }
    }

    func entitlementProductIDs() async -> Set<String> {
        state.withLock { $0.entitled }
    }

    func activeSubscriptions() async -> [StoreProduct] {
        let entitled = state.withLock { $0.entitled }
        return Self.products(entitled: entitled).filter { $0.isPurchased && $0.type.isAutoRenewableSubscription }
    }

    func activeSubscription(inGroup groupID: String) async -> StoreProduct? {
        await activeSubscriptions().first { $0.subscriptionGroupID == groupID }
    }

    func subscriptionStatuses(inGroup groupID: String) async throws -> [StoreSubscriptionStatus] {
        guard groupID == Self.groupID else { return [] }
        return state.withLock { $0.status.map { [$0] } ?? [] }
    }

    func isEligibleForIntroOffer(inGroup groupID: String) async -> Bool {
        state.withLock { !$0.hasUsedIntroOffer }
    }

    func appPurchaseInfo() async throws -> AppPurchaseInfo {
        AppPurchaseInfo(originalAppVersion: "1.0", originalPurchaseDate: .now, appVersion: "1.0", environment: .xcode)
    }

    // MARK: PurchasesBackend

    var purchasedProducts: AsyncStream<PurchasedProductEvent> {
        // One stream per access, like `PurchasesManager`: a single `AsyncStream` iterated
        // twice would split its events between the two loops.
        let (stream, continuation) = AsyncStream.makeStream(of: PurchasedProductEvent.self)
        let id = UUID()
        state.withLock { $0.purchaseContinuations[id] = continuation }
        continuation.onTermination = { [weak self] _ in
            _ = self?.state.withLock { $0.purchaseContinuations.removeValue(forKey: id) }
        }
        return stream
    }

    var subscriptionStatusUpdates: AsyncStream<StoreSubscriptionStatus> {
        let (stream, continuation) = AsyncStream.makeStream(of: StoreSubscriptionStatus.self)
        let id = UUID()
        state.withLock { $0.statusContinuations[id] = continuation }
        continuation.onTermination = { [weak self] _ in
            _ = self?.state.withLock { $0.statusContinuations.removeValue(forKey: id) }
        }
        return stream
    }

    @MainActor
    func showManageSubscriptions(in scene: UIWindowScene, groupID: String?) async throws {
        try await Task.sleep(for: delay)
        // Pretend the customer fixed their card in Settings. A billing problem resolves into
        // a renewed subscription, which arrives on `subscriptionStatusUpdates` exactly the way
        // a real recovery does.
        let (listeners, recovered) = state.withLock { state -> ([AsyncStream<StoreSubscriptionStatus>.Continuation], StoreSubscriptionStatus?) in
            guard let current = state.status,
                  current.state == .inGracePeriod || current.state == .inBillingRetryPeriod
                  || (current.state == .subscribed && !current.willAutoRenew)
            else { return ([], nil) }
            let product = Self.products(entitled: []).first { $0.productID == current.transaction.productID }
            let transaction = product.map { Self.transaction(for: $0, purchased: .now) } ?? current.transaction
            let renewed = StoreSubscriptionStatus(
                state: .subscribed,
                groupID: Self.groupID,
                transaction: transaction,
                willAutoRenew: true,
                autoRenewProductID: transaction.productID,
                renewalDate: transaction.expirationDate
            )
            state.status = renewed
            state.entitled.insert(transaction.productID)
            return (Array(state.statusContinuations.values), renewed)
        }
        if let recovered {
            listeners.forEach { $0.yield(recovered) }
        }
    }

    deinit {
        state.withLock { state in
            state.purchaseContinuations.values.forEach { $0.finish() }
            state.statusContinuations.values.forEach { $0.finish() }
        }
    }
}

// MARK: - Fixtures

extension DemoPurchases {
    private static let subscriptionIDs: Set<String> = [Catalog.premiumMonthly, Catalog.premiumYearly]
    private static let month = StoreSubscriptionPeriod(value: 1, unit: .month)
    private static let year = StoreSubscriptionPeriod(value: 1, unit: .year)

    /// The same catalog as `PaywallDemo.storekit`, built by hand.
    static func products(entitled: Set<String>) -> [StoreProduct] {
        [
            StoreProduct(
                productID: Catalog.premiumYearly,
                type: .autoRenewable,
                displayName: "Premium Yearly",
                description: "Premium, billed once a year",
                price: 39.99,
                displayPrice: "$39.99",
                currencyCode: "USD",
                isPurchased: entitled.contains(Catalog.premiumYearly),
                subscriptionGroupID: groupID,
                subscriptionPeriod: year,
                introductoryOffer: SubscriptionOffer(
                    id: nil,
                    type: .introductory,
                    paymentMode: .freeTrial,
                    price: 0,
                    displayPrice: "$0.00",
                    period: StoreSubscriptionPeriod(value: 3, unit: .day),
                    periodCount: 1
                )
            ),
            StoreProduct(
                productID: Catalog.premiumMonthly,
                type: .autoRenewable,
                displayName: "Premium Monthly",
                description: "Premium, billed every month",
                price: 4.99,
                displayPrice: "$4.99",
                currencyCode: "USD",
                isPurchased: entitled.contains(Catalog.premiumMonthly),
                subscriptionGroupID: groupID,
                subscriptionPeriod: month,
                promotionalOffers: [
                    SubscriptionOffer(
                        id: "dev.purchasekit.premium.monthly.retry",
                        type: .promotional,
                        paymentMode: .payAsYouGo,
                        price: 0.99,
                        displayPrice: "$0.99",
                        period: month,
                        periodCount: 1
                    )
                ],
                winBackOffers: [
                    SubscriptionOffer(
                        id: "dev.purchasekit.premium.monthly.winback",
                        type: .winBack,
                        paymentMode: .payAsYouGo,
                        price: 1.99,
                        displayPrice: "$1.99",
                        period: month,
                        periodCount: 3
                    )
                ]
            ),
            StoreProduct(
                productID: Catalog.lifetime,
                type: .nonConsumable,
                displayName: "Lifetime Unlock",
                description: "Every Premium feature, paid once",
                price: 79.99,
                displayPrice: "$79.99",
                currencyCode: "USD",
                isFamilyShareable: true,
                isPurchased: entitled.contains(Catalog.lifetime)
            ),
            StoreProduct(
                productID: Catalog.coins,
                type: .consumable,
                displayName: "100 Coins",
                description: "A pouch of 100 coins to spend in the app",
                price: 0.99,
                displayPrice: "$0.99",
                currencyCode: "USD"
            ),
        ]
    }

    private static func transaction(for product: StoreProduct, purchased: Date) -> StoreTransaction {
        let calendar = Calendar.current
        let expiration: Date? = switch product.subscriptionPeriod?.unit {
        case .year?: calendar.date(byAdding: .year, value: 1, to: purchased)
        case .month?: calendar.date(byAdding: .month, value: 1, to: purchased)
        default: nil
        }
        return StoreTransaction(
            id: UInt64(purchased.timeIntervalSince1970 * 1000),
            productID: product.productID,
            productType: product.type,
            purchaseDate: purchased,
            expirationDate: expiration,
            subscriptionGroupID: product.subscriptionGroupID,
            environment: .xcode
        )
    }

    /// The renewal status a customer in `scenario` would have.
    static func status(for scenario: DemoScenario) -> StoreSubscriptionStatus? {
        let now = Date.now
        let day: TimeInterval = 86_400
        func monthly(purchased: Date, expires: Date, revoked: Date? = nil) -> StoreTransaction {
            StoreTransaction(
                id: 2_000_000_001,
                productID: Catalog.premiumMonthly,
                productType: .autoRenewable,
                purchaseDate: purchased,
                originalPurchaseDate: purchased.addingTimeInterval(-90 * day),
                expirationDate: expires,
                revocationDate: revoked,
                subscriptionGroupID: groupID,
                environment: .xcode,
                revocationReason: revoked == nil ? nil : .other,
                revocationType: revoked == nil ? nil : .fullRefund
            )
        }

        switch scenario {
        case .live, .newCustomer:
            return nil

        case .subscribed:
            let transaction = monthly(purchased: now.addingTimeInterval(-10 * day), expires: now.addingTimeInterval(20 * day))
            return StoreSubscriptionStatus(
                state: .subscribed,
                groupID: groupID,
                transaction: transaction,
                willAutoRenew: true,
                autoRenewProductID: Catalog.premiumMonthly,
                renewalDate: transaction.expirationDate
            )

        case .gracePeriod:
            // The renewal was due yesterday and failed. With a 16-day grace period the
            // customer keeps access until the grace period expires.
            return StoreSubscriptionStatus(
                state: .inGracePeriod,
                groupID: groupID,
                transaction: monthly(purchased: now.addingTimeInterval(-31 * day), expires: now.addingTimeInterval(-1 * day)),
                willAutoRenew: true,
                autoRenewProductID: Catalog.premiumMonthly,
                renewalDate: now.addingTimeInterval(-1 * day),
                gracePeriodExpirationDate: now.addingTimeInterval(15 * day),
                isInBillingRetry: true
            )

        case .billingRetry:
            return StoreSubscriptionStatus(
                state: .inBillingRetryPeriod,
                groupID: groupID,
                transaction: monthly(purchased: now.addingTimeInterval(-50 * day), expires: now.addingTimeInterval(-20 * day)),
                willAutoRenew: true,
                autoRenewProductID: Catalog.premiumMonthly,
                renewalDate: now.addingTimeInterval(-20 * day),
                isInBillingRetry: true
            )

        case .expiredCancelled:
            return StoreSubscriptionStatus(
                state: .expired,
                groupID: groupID,
                transaction: monthly(purchased: now.addingTimeInterval(-75 * day), expires: now.addingTimeInterval(-45 * day)),
                autoRenewProductID: Catalog.premiumMonthly,
                expirationReason: .autoRenewDisabled
            )

        case .expiredBillingError:
            return StoreSubscriptionStatus(
                state: .expired,
                groupID: groupID,
                transaction: monthly(purchased: now.addingTimeInterval(-95 * day), expires: now.addingTimeInterval(-65 * day)),
                willAutoRenew: false,
                autoRenewProductID: Catalog.premiumMonthly,
                expirationReason: .billingError
            )

        case .revoked:
            return StoreSubscriptionStatus(
                state: .revoked,
                groupID: groupID,
                transaction: monthly(
                    purchased: now.addingTimeInterval(-12 * day),
                    expires: now.addingTimeInterval(18 * day),
                    revoked: now.addingTimeInterval(-2 * day)
                ),
                autoRenewProductID: Catalog.premiumMonthly
            )
        }
    }
}
