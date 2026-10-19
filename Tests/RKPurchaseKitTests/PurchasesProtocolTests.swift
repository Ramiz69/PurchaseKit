//
//  PurchasesProtocolTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import Synchronization
import Testing
#if os(visionOS)
import UIKit
#endif
import StoreKit
@testable import RKPurchaseKit

/// Covers the conveniences on ``PurchasesProtocol`` and what a stand-in can represent.
@Suite("PurchasesProtocol", .timeLimit(.minutes(1)))
struct PurchasesProtocolTests {

    /// A stand-in implementation, which is what this protocol exists to make possible.
    private final class SpyPurchases: PurchasesProtocol {
        let receivedIncludingCache = Mutex<[Bool]>([])
        let receivedOptions = Mutex<[PurchaseOptions]>([])
        let receivedStatusGroups = Mutex<[String]>([])
        let catalogue: [StoreProduct]
        let statuses: [StoreSubscriptionStatus]

        init(catalogue: [StoreProduct] = [], statuses: [StoreSubscriptionStatus] = []) {
            self.catalogue = catalogue
            self.statuses = statuses
        }

        func requestProducts(includingCache: Bool) async throws -> [StoreProduct] {
            receivedIncludingCache.withLock { $0.append(includingCache) }

            return catalogue
        }

        #if os(visionOS)
        @MainActor
        func purchase(
            productID: String,
            options: PurchaseOptions,
            confirmIn scene: UIScene
        ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
            try buy(productID, options)
        }
        #else
        func purchase(
            productID: String,
            options: PurchaseOptions
        ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
            try buy(productID, options)
        }
        #endif

        private func buy(
            _ productID: String,
            _ options: PurchaseOptions
        ) throws -> (product: StoreProduct, transaction: StoreTransaction) {
            receivedOptions.withLock { $0.append(options) }
            guard let product = catalogue.first(where: { $0.productID == productID }) else {
                throw PurchasesError.invalidProductID(productID)
            }

            return (
                product: product,
                transaction: StoreTransaction(
                    id: 1,
                    productID: productID,
                    purchaseDate: Date(timeIntervalSince1970: 1_000_000)
                )
            )
        }

        func restore() async throws {}

        func hasEntitlement(for productID: String) async -> Bool {
            catalogue.contains { $0.productID == productID && $0.isPurchased }
        }

        func entitlementProductIDs() async -> Set<String> {
            Set(catalogue.filter(\.isPurchased).map(\.productID))
        }

        func activeSubscriptions() async -> [StoreProduct] {
            catalogue.filter { $0.isPurchased && $0.type == .autoRenewable }
        }

        func activeSubscription(inGroup groupID: String) async -> StoreProduct? {
            catalogue.first { $0.subscriptionGroupID == groupID && $0.isPurchased }
        }

        func subscriptionStatuses(inGroup groupID: String) async throws -> [StoreSubscriptionStatus] {
            receivedStatusGroups.withLock { $0.append(groupID) }

            return statuses.filter { $0.groupID == groupID }
        }

        func isEligibleForIntroOffer(inGroup groupID: String) async -> Bool {
            statuses.allSatisfy { $0.groupID != groupID }
        }

        func appPurchaseInfo() async throws -> AppPurchaseInfo {
            AppPurchaseInfo(
                originalAppVersion: "1.0",
                originalPurchaseDate: Date(timeIntervalSince1970: 1_000_000),
                appVersion: "4.0"
            )
        }
    }

    /// Regression test for an infinite recursion.
    ///
    /// The default implementation used to repeat the requirement's own signature and add
    /// only a default argument value. For a conformer that did not implement the
    /// requirement, that overload became the witness and called itself forever, so any mock
    /// written against this protocol hung. The overload now takes no parameters, which also
    /// makes the same omission a compile-time conformance error rather than a runtime hang.
    ///
    /// Guarded by a timeout so a regression fails the suite instead of hanging it.
    @Test("the no-argument overload forwards instead of recursing")
    func convenienceOverloadForwards() async throws {
        let spy = SpyPurchases()

        let finished = await completes(within: .seconds(5)) {
            _ = try? await spy.requestProducts()
        }

        #expect(finished, "requestProducts() did not return — the default implementation is recursing")
        #expect(spy.receivedIncludingCache.withLock { $0 } == [true])
    }

    @Test("the explicit argument is passed through unchanged")
    func explicitArgumentIsForwarded() async throws {
        let spy = SpyPurchases()

        _ = try await spy.requestProducts(includingCache: false)
        _ = try await spy.requestProducts(includingCache: true)

        #expect(spy.receivedIncludingCache.withLock { $0 } == [false, true])
    }

    /// The protocol is documented as existing so it can be mocked. Until `StoreProduct` had
    /// a public initializer that was not actually possible: a conformer outside the module
    /// could not produce a single return value.
    @Test("a stand-in can serve a catalogue through the protocol")
    func mockCanReturnProducts() async throws {
        let subscription = StoreProduct(
            productID: "pro.monthly",
            type: .autoRenewable,
            displayName: "Pro Monthly",
            description: "Everything, billed monthly",
            price: 4.99,
            displayPrice: "$4.99",
            currencyCode: "USD",
            isPurchased: true,
            subscriptionGroupID: "group.pro"
        )
        let lifetime = StoreProduct(
            productID: "pro.lifetime",
            type: .nonConsumable,
            displayName: "Lifetime",
            description: "Pay once",
            price: 49.99,
            displayPrice: "$49.99",
            currencyCode: "USD"
        )
        let spy = SpyPurchases(catalogue: [subscription, lifetime])

        #expect(try await spy.requestProducts().map(\.productID) == ["pro.monthly", "pro.lifetime"])
        #expect(await spy.hasEntitlement(for: "pro.monthly"))
        #expect(!(await spy.hasEntitlement(for: "pro.lifetime")))
        #expect(await spy.entitlementProductIDs() == ["pro.monthly"])
        #expect(await spy.activeSubscriptions().map(\.productID) == ["pro.monthly"])
        #expect(await spy.activeSubscription(inGroup: "group.pro")?.productID == "pro.monthly")
    }

    #if !os(visionOS)
    /// The last thing that kept `PurchasesProtocol` from being fully mockable.
    ///
    /// `purchase(productID:)` used to return a `StoreKit.Transaction`, which has no public
    /// initializer, so a stand-in could only ever throw from it — the successful path was
    /// impossible to represent, and therefore impossible to test against.
    @Test("a stand-in can return a successful purchase")
    func mockCanReturnSuccessfulPurchase() async throws {
        let product = StoreProduct(
            productID: "pro.monthly",
            type: .autoRenewable,
            displayName: "Pro Monthly",
            description: "Everything, billed monthly",
            price: 4.99,
            displayPrice: "$4.99",
            currencyCode: "USD"
        )
        let spy = SpyPurchases(catalogue: [product])

        let result = try await spy.purchase(productID: "pro.monthly")

        #expect(result.product.productID == "pro.monthly")
        #expect(result.transaction.productID == "pro.monthly")
        #expect(result.transaction.id == 1)
        #expect(result.transaction.transaction == nil)
    }

    @Test("a stand-in still reports an unknown identifier")
    func mockRejectsUnknownProduct() async {
        let spy = SpyPurchases()

        await #expect(throws: PurchasesError.invalidProductID("nope")) {
            try await spy.purchase(productID: "nope")
        }
    }

    /// `purchase(productID:)` is an extension in 4.0, not a requirement. It has to reach the
    /// options-based requirement with nothing added, or a plain purchase would silently
    /// carry a token, a quantity or an offer.
    @Test("purchase(productID:) forwards PurchaseOptions.none")
    func shortPurchaseForwardsNoOptions() async throws {
        let spy = SpyPurchases(catalogue: [Self.monthly])

        _ = try await spy.purchase(productID: "pro.monthly")

        #expect(spy.receivedOptions.withLock { $0 } == [PurchaseOptions.none])
    }

    @Test("purchase(productID:options:) passes the options through unchanged")
    func optionsArePassedThrough() async throws {
        let spy = SpyPurchases(catalogue: [Self.monthly])
        let options = PurchaseOptions(
            appAccountToken: UUID(),
            quantity: 3,
            winBackOfferID: "winback.1",
            simulatesAskToBuyInSandbox: true
        )

        _ = try await spy.purchase(productID: "pro.monthly", options: options)

        #expect(spy.receivedOptions.withLock { $0 } == [options])
    }

    /// Called through an existential, which is how app code holds a mock. The extension
    /// method is what runs, and it still lands on the conformer's requirement.
    @Test("the convenience reaches the requirement through any PurchasesProtocol")
    func convenienceWorksThroughExistential() async throws {
        let spy = SpyPurchases(catalogue: [Self.monthly])
        let purchases: any PurchasesProtocol = spy

        let result = try await purchases.purchase(productID: "pro.monthly")

        #expect(result.product.productID == "pro.monthly")
        #expect(spy.receivedOptions.withLock { $0 } == [PurchaseOptions.none])
    }
    #endif

    @Test("subscriptionStatus(inGroup:) picks the status granting the most access")
    func subscriptionStatusPicksBest() async throws {
        let expired = makeStatus(.expired, id: 1, expiresIn: 86_400 * 30)
        let subscribed = makeStatus(.subscribed, id: 2, expiresIn: 86_400)
        let revoked = makeStatus(.revoked, id: 3, expiresIn: 86_400 * 60)
        let spy = SpyPurchases(statuses: [expired, subscribed, revoked])

        let status = try await spy.subscriptionStatus(inGroup: "group.pro")

        #expect(status?.transaction.id == 2)
        #expect(status?.isActive == true)
        #expect(spy.receivedStatusGroups.withLock { $0 } == ["group.pro"])
    }

    @Test("subscriptionStatus(inGroup:) breaks a tie by the later expiration")
    func subscriptionStatusBreaksTieByExpiration() async throws {
        let sooner = makeStatus(.subscribed, id: 1, expiresIn: 86_400)
        let later = makeStatus(.subscribed, id: 2, expiresIn: 86_400 * 365)
        let spy = SpyPurchases(statuses: [later, sooner])

        #expect(try await spy.subscriptionStatus(inGroup: "group.pro")?.transaction.id == 2)
    }

    @Test("subscriptionStatus(inGroup:) is nil for a group the customer never joined")
    func subscriptionStatusIsNilWithoutStatuses() async throws {
        let spy = SpyPurchases(statuses: [makeStatus(.subscribed, id: 1, expiresIn: 86_400)])

        #expect(try await spy.subscriptionStatus(inGroup: "group.other") == nil)
        #expect(spy.receivedStatusGroups.withLock { $0 } == ["group.other"])
    }

    @Test("a stand-in can answer the 4.0 requirements")
    func mockAnswersNewRequirements() async throws {
        let spy = SpyPurchases(statuses: [makeStatus(.expired, id: 1, expiresIn: -86_400)])

        #expect(try await spy.subscriptionStatuses(inGroup: "group.pro").map(\.state) == [.expired])
        #expect(!(await spy.isEligibleForIntroOffer(inGroup: "group.pro")))
        #expect(await spy.isEligibleForIntroOffer(inGroup: "group.other"))
        #expect(try await spy.appPurchaseInfo().originalAppVersion == "1.0")
    }

    // MARK: Helpers

    private static let monthly = StoreProduct(
        productID: "pro.monthly",
        type: .autoRenewable,
        displayName: "Pro Monthly",
        description: "Everything, billed monthly",
        price: 4.99,
        displayPrice: "$4.99",
        currencyCode: "USD",
        subscriptionGroupID: "group.pro"
    )

    private func makeStatus(
        _ state: StoreSubscriptionStatus.State,
        id: UInt64,
        expiresIn interval: TimeInterval
    ) -> StoreSubscriptionStatus {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        return StoreSubscriptionStatus(
            state: state,
            groupID: "group.pro",
            transaction: StoreTransaction(
                id: id,
                productID: "pro.monthly",
                purchaseDate: now,
                expirationDate: now.addingTimeInterval(interval),
                subscriptionGroupID: "group.pro",
                productType: .autoRenewable
            )
        )
    }

    /// Runs `operation`, returning `false` if it has not finished within `limit`.
    private func completes(
        within limit: Duration,
        _ operation: @escaping @Sendable () async -> Void
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await operation()

                return true
            }
            group.addTask {
                try? await Task.sleep(for: limit)

                return false
            }

            let finished = await group.next() ?? false
            group.cancelAll()

            return finished
        }
    }
}
