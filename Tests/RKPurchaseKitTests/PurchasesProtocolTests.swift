//
//  PurchasesProtocolTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import Synchronization
import Testing
import StoreKit
@testable import RKPurchaseKit

/// Covers the convenience overload on ``PurchasesProtocol``.
@Suite("PurchasesProtocol", .timeLimit(.minutes(1)))
struct PurchasesProtocolTests {

    /// A stand-in implementation, which is what this protocol exists to make possible.
    private final class SpyPurchases: PurchasesProtocol {
        let receivedIncludingCache = Mutex<[Bool]>([])
        let catalogue: [StoreProduct]

        init(catalogue: [StoreProduct] = []) {
            self.catalogue = catalogue
        }

        func requestProducts(includingCache: Bool) async throws -> [StoreProduct] {
            receivedIncludingCache.withLock { $0.append(includingCache) }

            return catalogue
        }

        func purchase(productID: String) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
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
            isPurchased: true,
            subscriptionGroupID: "group.pro"
        )
        let lifetime = StoreProduct(
            productID: "pro.lifetime",
            type: .nonConsumable,
            displayName: "Lifetime",
            description: "Pay once",
            price: 49.99,
            displayPrice: "$49.99"
        )
        let spy = SpyPurchases(catalogue: [subscription, lifetime])

        #expect(try await spy.requestProducts().map(\.productID) == ["pro.monthly", "pro.lifetime"])
        #expect(await spy.hasEntitlement(for: "pro.monthly"))
        #expect(!(await spy.hasEntitlement(for: "pro.lifetime")))
        #expect(await spy.entitlementProductIDs() == ["pro.monthly"])
        #expect(await spy.activeSubscriptions().map(\.productID) == ["pro.monthly"])
        #expect(await spy.activeSubscription(inGroup: "group.pro")?.productID == "pro.monthly")
    }

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
            displayPrice: "$4.99"
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

    // MARK: Helpers

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
