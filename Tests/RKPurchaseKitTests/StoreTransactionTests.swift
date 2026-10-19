//
//  StoreTransactionTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit
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
        #expect(transaction.productType == .unknown)
        #expect(transaction.ownershipType == .purchased)
        #expect(!transaction.isFamilyShared)
        #expect(transaction.environment == .production)
        #expect(transaction.reason == .purchase)
        #expect(transaction.offer == nil)
        #expect(transaction.revocationReason == nil)
        #expect(transaction.revocationType == nil)
        #expect(transaction.billingPlanType == nil)
        #expect(transaction.storefrontCountryCode.isEmpty)
        #expect(transaction.price == nil)
        #expect(transaction.currencyCode == nil)
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

    @Test("the 4.0 details can be supplied")
    func buildsExtendedDetails() {
        let offer = StoreTransaction.Offer(id: "winback.half", type: .winBack, paymentMode: .payAsYouGo)

        let transaction = StoreTransaction(
            id: 5,
            productID: "pro.monthly",
            purchaseDate: purchasedAt,
            revocationDate: purchasedAt.addingTimeInterval(60),
            productType: .autoRenewable,
            ownershipType: .familyShared,
            environment: .sandbox,
            reason: .renewal,
            offer: offer,
            revocationReason: .developerIssue,
            revocationType: .proratedRefund,
            billingPlanType: .monthly,
            storefrontCountryCode: "DEU",
            price: 2.49,
            currencyCode: "EUR"
        )

        #expect(transaction.productType == .autoRenewable)
        #expect(transaction.ownershipType == .familyShared)
        #expect(transaction.isFamilyShared)
        #expect(transaction.environment == .sandbox)
        #expect(transaction.reason == .renewal)
        #expect(transaction.offer == offer)
        #expect(transaction.revocationReason == .developerIssue)
        #expect(transaction.revocationType == .proratedRefund)
        #expect(transaction.billingPlanType == .monthly)
        #expect(transaction.storefrontCountryCode == "DEU")
        #expect(transaction.price == 2.49)
        #expect(transaction.currencyCode == "EUR")
    }

    // MARK: StoreKit raw values

    // The kit maps these kinds by passing StoreKit's raw value through, so its constants must
    // carry exactly StoreKit's raw values. Comparing against the real constants catches a
    // typo here or a change on Apple's side.

    @Test("ownership, reason and environment match StoreKit's raw values")
    func matchesStoreKitRawValues() {
        #expect(StoreTransaction.OwnershipType.purchased.rawValue == Transaction.OwnershipType.purchased.rawValue)
        #expect(StoreTransaction.OwnershipType.familyShared.rawValue == Transaction.OwnershipType.familyShared.rawValue)
        #expect(StoreTransaction.Reason.purchase.rawValue == Transaction.Reason.purchase.rawValue)
        #expect(StoreTransaction.Reason.renewal.rawValue == Transaction.Reason.renewal.rawValue)
        #expect(StoreTransaction.RevocationReason.developerIssue.rawValue == Transaction.RevocationReason.developerIssue.rawValue)
        #expect(StoreTransaction.RevocationReason.other.rawValue == Transaction.RevocationReason.other.rawValue)
        #expect(StoreEnvironment(AppStore.Environment.production) == .production)
        #expect(StoreEnvironment(AppStore.Environment.sandbox) == .sandbox)
        #expect(StoreEnvironment(AppStore.Environment.xcode) == .xcode)
    }

    /// Both types are new in 26.4, so the comparison only runs where the system has them.
    @Test("revocation and billing plan kinds match StoreKit's raw values")
    func matchesStoreKit264RawValues() {
        guard #available(iOS 26.4, macOS 26.4, tvOS 26.4, watchOS 26.4, visionOS 26.4, *) else {
            return
        }

        #expect(StoreTransaction.RevocationType.fullRefund.rawValue == Transaction.RevocationType.fullRefund.rawValue)
        #expect(StoreTransaction.RevocationType.proratedRefund.rawValue == Transaction.RevocationType.proratedRefund.rawValue)
        #expect(StoreTransaction.RevocationType.familyRevocation.rawValue == Transaction.RevocationType.familyRevocation.rawValue)
        #expect(StoreTransaction.BillingPlanType.monthly.rawValue == Product.SubscriptionInfo.BillingPlanType.monthly.rawValue)
        #expect(StoreTransaction.BillingPlanType.upFront.rawValue == Product.SubscriptionInfo.BillingPlanType.upFront.rawValue)
    }

    /// A kind Apple adds later has to survive the trip, not collapse into a known one.
    @Test("an unfamiliar raw value is kept as reported")
    func keepsUnknownRawValues() {
        let ownership = StoreTransaction.OwnershipType(rawValue: "ASSIGNED")

        #expect(ownership.rawValue == "ASSIGNED")
        #expect(ownership != .purchased)
        #expect(ownership != .familyShared)
        #expect(StoreTransaction(id: 1, productID: "a", purchaseDate: purchasedAt, ownershipType: ownership).isFamilyShared == false)
    }
}
