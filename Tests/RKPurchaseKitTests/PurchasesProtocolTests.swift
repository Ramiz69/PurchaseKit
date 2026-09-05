//
//  PurchasesProtocolTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Synchronization
import Testing
import StoreKit
@testable import RKPurchaseKit

/// Covers the convenience overload on ``PurchasesProtocol``.
@Suite("PurchasesProtocol", .timeLimit(.minutes(1)))
struct PurchasesProtocolTests {

    /// Records how the requirement was called, without ever producing a `StoreProduct` —
    /// that type wraps a `StoreKit.Product`, which cannot be constructed in a test.
    private final class SpyPurchases: PurchasesProtocol {
        let receivedIncludingCache = Mutex<[Bool]>([])

        func requestProducts(includingCache: Bool) async throws -> [StoreProduct] {
            receivedIncludingCache.withLock { $0.append(includingCache) }

            return []
        }

        func purchase(productID: String) async throws -> (product: StoreProduct, transaction: Transaction) {
            throw PurchasesError.invalidProductID(productID)
        }

        func restore() async throws {}
        func hasEntitlement(for productID: String) async -> Bool { false }
        func entitlementProductIDs() async -> Set<String> { [] }
        func activeSubscriptions() async -> [StoreProduct] { [] }
        func activeSubscription(inGroup groupID: String) async -> StoreProduct? { nil }
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
