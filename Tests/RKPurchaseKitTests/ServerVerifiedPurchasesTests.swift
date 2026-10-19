//
//  ServerVerifiedPurchasesTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 09.10.2026.
//

import Foundation
import Synchronization
import Testing
#if os(visionOS)
import UIKit
#endif
@testable import RKPurchaseKit

/// Covers the server-verified flow: buy for an account, hand the signed transaction to a
/// server, finish only after it accepts.
///
/// StoreKit itself cannot run here: `SKTestSession` reports `invalidApp` outside an app host,
/// so these tests pin down the public surface an app codes against - the protocol a stand-in
/// implements and the values it passes around.
@Suite("ServerVerifiedPurchases", .timeLimit(.minutes(1)))
struct ServerVerifiedPurchasesTests {

    /// A stand-in that behaves like a manual-finishing manager backed by a fake App Store.
    private final class FakeStore: ServerVerifiedPurchasesProtocol {
        private let state = Mutex<(unfinished: [StoreTransaction], finished: [UInt64], nextID: UInt64)>(([], [], 1))
        let receivedOptions = Mutex<[PurchaseOptions]>([])
        let coins = StoreProduct(
            productID: "coins.100",
            type: .consumable,
            displayName: "100 coins",
            description: "A pack of coins",
            price: 0.99,
            displayPrice: "$0.99",
            currencyCode: "USD"
        )

        var transactionUpdates: AsyncStream<StoreTransaction> {
            AsyncStream { $0.finish() }
        }

        func requestProducts(includingCache: Bool) async throws -> [StoreProduct] { [coins] }

        // The 4.0 shape: the token arrives inside the options, and the account-token
        // purchase is a protocol convenience this type does not implement.
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

        func finish(_ transaction: StoreTransaction) async {
            state.withLock { state in
                guard state.unfinished.contains(where: { $0.id == transaction.id }) else { return }

                state.unfinished.removeAll { $0.id == transaction.id }
                state.finished.append(transaction.id)
            }
        }

        func unfinishedTransactions() async -> [StoreTransaction] {
            state.withLock { $0.unfinished }
        }

        func restore() async throws {}
        func hasEntitlement(for productID: String) async -> Bool { false }
        func entitlementProductIDs() async -> Set<String> { [] }
        func activeSubscriptions() async -> [StoreProduct] { [] }
        func activeSubscription(inGroup groupID: String) async -> StoreProduct? { nil }
        func subscriptionStatuses(inGroup groupID: String) async throws -> [StoreSubscriptionStatus] { [] }
        func isEligibleForIntroOffer(inGroup groupID: String) async -> Bool { true }
        func appPurchaseInfo() async throws -> AppPurchaseInfo { throw PurchasesError.unsupported }

        var finishedIDs: [UInt64] { state.withLock { $0.finished } }

        private func buy(
            _ productID: String,
            _ options: PurchaseOptions
        ) throws -> (product: StoreProduct, transaction: StoreTransaction) {
            receivedOptions.withLock { $0.append(options) }
            let token = options.appAccountToken
            guard productID == coins.productID else { throw PurchasesError.invalidProductID(productID) }

            let transaction = state.withLock { state -> StoreTransaction in
                let transaction = StoreTransaction(
                    id: state.nextID,
                    productID: productID,
                    purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
                    appAccountToken: token,
                    jwsRepresentation: "header.payload-\(state.nextID).signature"
                )
                state.nextID += 1
                state.unfinished.append(transaction)

                return transaction
            }

            return (product: coins, transaction: transaction)
        }
    }

    @Test("the signed form survives the stand-in initializer and defaults to nil")
    func jwsRepresentationIsCarried() {
        let signed = StoreTransaction(
            id: 1,
            productID: "coins.100",
            purchaseDate: Date(timeIntervalSince1970: 0),
            jwsRepresentation: "a.b.c"
        )
        let unsigned = StoreTransaction(id: 2, productID: "coins.100", purchaseDate: Date(timeIntervalSince1970: 0))

        #expect(signed.jwsRepresentation == "a.b.c")
        #expect(unsigned.jwsRepresentation == nil)
    }

    #if !os(visionOS)
    /// The whole point of the flow: nothing is finished until the server has the purchase,
    /// and a purchase whose server call failed is still there to retry.
    @Test("a purchase stays unfinished until the app finishes it")
    func purchaseStaysUnfinishedUntilFinished() async throws {
        let store = FakeStore()
        let account = UUID()

        let bought = try await store.purchase(productID: "coins.100", appAccountToken: account).transaction

        #expect(bought.appAccountToken == account)
        #expect(bought.jwsRepresentation != nil)
        #expect(await store.unfinishedTransactions().map(\.id) == [bought.id])
        #expect(store.finishedIDs.isEmpty)

        await store.finish(bought)

        #expect(await store.unfinishedTransactions().isEmpty)
        #expect(store.finishedIDs == [bought.id])
    }

    @Test("finishing twice is harmless")
    func finishingTwiceIsANoOp() async throws {
        let store = FakeStore()
        let bought = try await store.purchase(productID: "coins.100", appAccountToken: UUID()).transaction

        await store.finish(bought)
        await store.finish(bought)

        #expect(store.finishedIDs == [bought.id])
    }

    /// The account-token purchase is an extension in 4.0. It must hand the token to the
    /// options-based requirement and add nothing else, so the purchase is otherwise plain.
    @Test("purchase(productID:appAccountToken:) forwards the token as the only option")
    func accountTokenPurchaseForwardsToken() async throws {
        let store = FakeStore()
        let account = UUID()

        _ = try await store.purchase(productID: "coins.100", appAccountToken: account)
        _ = try await store.purchase(productID: "coins.100", appAccountToken: nil)

        #expect(store.receivedOptions.withLock { $0 } == [PurchaseOptions(appAccountToken: account), PurchaseOptions.none])
    }

    @Test("the convenience reaches the requirement through any ServerVerifiedPurchasesProtocol")
    func accountTokenPurchaseWorksThroughExistential() async throws {
        let store = FakeStore()
        let purchases: any ServerVerifiedPurchasesProtocol = store
        let account = UUID()

        let bought = try await purchases.purchase(productID: "coins.100", appAccountToken: account).transaction

        #expect(bought.appAccountToken == account)
        #expect(await purchases.unfinishedTransactions().map(\.id) == [bought.id])
    }
    #endif

    @Test("manual and automatic are distinct policies")
    func policiesAreDistinct() {
        #expect(FinishPolicy.manual != FinishPolicy.automatic)
    }
}
