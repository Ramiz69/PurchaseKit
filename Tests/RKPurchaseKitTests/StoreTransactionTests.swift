//
//  StoreTransactionTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import Testing
@testable import RKPurchaseKit

/// Covers the initializer that lets a ``StoreTransaction`` exist without StoreKit behind it.
@Suite("StoreTransaction", .timeLimit(.minutes(1)))
struct StoreTransactionTests {

    private let purchasedAt = Date(timeIntervalSince1970: 1_700_000_000)

    /// `StoreKit.Transaction` has no public initializer, so before this type existed a
    /// successful purchase could not be represented outside StoreKit at all.
    @Test("can be constructed without StoreKit")
    func buildsWithoutStoreKit() {
        let expires = purchasedAt.addingTimeInterval(2_592_000)
        let token = UUID()

        let transaction = StoreTransaction(
            id: 42,
            productID: "pro.monthly",
            purchaseDate: purchasedAt,
            originalID: 7,
            originalPurchaseDate: purchasedAt.addingTimeInterval(-86_400),
            expirationDate: expires,
            isUpgraded: true,
            purchasedQuantity: 3,
            appAccountToken: token,
            subscriptionGroupID: "group.pro"
        )

        #expect(transaction.transaction == nil)
        #expect(transaction.id == 42)
        #expect(transaction.originalID == 7)
        #expect(transaction.productID == "pro.monthly")
        #expect(transaction.purchaseDate == purchasedAt)
        #expect(transaction.expirationDate == expires)
        #expect(transaction.revocationDate == nil)
        #expect(transaction.isUpgraded)
        #expect(transaction.purchasedQuantity == 3)
        #expect(transaction.appAccountToken == token)
        #expect(transaction.subscriptionGroupID == "group.pro")
    }

    /// A one-off purchase has no original transaction distinct from itself, and repeating
    /// both identifiers at every call site would be noise.
    @Test("identity defaults fall back to the transaction itself")
    func defaultsIdentityToItself() {
        let transaction = StoreTransaction(id: 99, productID: "tip.small", purchaseDate: purchasedAt)

        #expect(transaction.originalID == 99)
        #expect(transaction.originalPurchaseDate == purchasedAt)
    }

    @Test("subscription details default to absent")
    func appliesDefaults() {
        let transaction = StoreTransaction(id: 1, productID: "tip.small", purchaseDate: purchasedAt)

        #expect(transaction.expirationDate == nil)
        #expect(transaction.revocationDate == nil)
        #expect(transaction.subscriptionGroupID == nil)
        #expect(transaction.appAccountToken == nil)
        #expect(!transaction.isUpgraded)
        #expect(transaction.purchasedQuantity == 1)
    }

    /// A revoked transaction is the case entitlement code has to notice, so it has to be
    /// expressible in a test.
    @Test("a revocation can be represented")
    func representsRevocation() {
        let revokedAt = purchasedAt.addingTimeInterval(3_600)

        let transaction = StoreTransaction(
            id: 1,
            productID: "pro.monthly",
            purchaseDate: purchasedAt,
            revocationDate: revokedAt
        )

        #expect(transaction.revocationDate == revokedAt)
    }
}
