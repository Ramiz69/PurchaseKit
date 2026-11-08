//
//  CurrentEntitlementTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 08.11.2026.
//

import Foundation
import Testing
@testable import RKPurchaseKit
#if os(visionOS)
import UIKit
#endif

/// Covers which transaction ``PurchasesProtocol/currentEntitlement(for:)`` reports.
///
/// Reading `Transaction.currentEntitlements(for:)` needs a host app and a StoreKit
/// configuration, so the live path is not exercised here. Everything that decides the answer
/// once StoreKit has handed the transactions over is: the rule lives in
/// `StoreTransaction.preferredEntitlement(among:)`, which takes constructed values.
@Suite("currentEntitlement(for:)", .timeLimit(.minutes(1)))
struct CurrentEntitlementTests {

    private let trialStarted = Date(timeIntervalSince1970: 1_790_000_000)

    private func transaction(
        id: UInt64,
        purchaseDate: Date,
        ownership: StoreTransaction.OwnershipType = .purchased,
        revoked: Date? = nil
    ) -> StoreTransaction {
        StoreTransaction(
            id: id,
            productID: "kinboard.trial",
            productType: .nonConsumable,
            purchaseDate: purchaseDate,
            revocationDate: revoked,
            ownershipType: ownership
        )
    }

    // MARK: Selection rule

    @Test("no entitlement gives nil")
    func noEntitlement() {
        #expect(StoreTransaction.preferredEntitlement(among: []) == nil)
    }

    /// The case the API exists for: a free trial unlocked through a non-consumable, whose end
    /// the app computes from the purchase date.
    @Test("a purchased non-consumable is reported with its purchase date")
    func purchasedNonConsumable() throws {
        let trial = transaction(id: 1, purchaseDate: trialStarted)

        let entitlement = try #require(StoreTransaction.preferredEntitlement(among: [trial]))

        #expect(entitlement.id == 1)
        #expect(entitlement.purchaseDate == trialStarted)
        #expect(entitlement.productType == .nonConsumable)
        #expect(entitlement.isFamilyShared == false)
    }

    @Test("a revoked transaction gives nil")
    func revokedOnly() {
        let refunded = transaction(id: 1, purchaseDate: trialStarted, revoked: trialStarted.addingTimeInterval(3_600))

        #expect(StoreTransaction.preferredEntitlement(among: [refunded]) == nil)
    }

    @Test("a revoked transaction is skipped in favour of a live one")
    func revokedIsSkipped() throws {
        let refunded = transaction(id: 1, purchaseDate: trialStarted, revoked: trialStarted.addingTimeInterval(60))
        let live = transaction(id: 2, purchaseDate: trialStarted.addingTimeInterval(86_400))

        let entitlement = try #require(StoreTransaction.preferredEntitlement(among: [refunded, live]))

        #expect(entitlement.id == 2)
    }

    /// The customer's own purchase cannot be withdrawn by someone else, so it wins even when
    /// a family member's grant is older.
    @Test("the customer's own purchase wins over an older family-shared one")
    func ownBeatsFamily() throws {
        let shared = transaction(id: 1, purchaseDate: trialStarted, ownership: .familyShared)
        let own = transaction(id: 2, purchaseDate: trialStarted.addingTimeInterval(86_400))

        let entitlement = try #require(StoreTransaction.preferredEntitlement(among: [shared, own]))

        #expect(entitlement.id == 2)
    }

    @Test("among equals the earliest purchase wins, whatever StoreKit's order")
    func earliestWins() throws {
        let later = transaction(id: 1, purchaseDate: trialStarted.addingTimeInterval(86_400), ownership: .familyShared)
        let earlier = transaction(id: 2, purchaseDate: trialStarted, ownership: .familyShared)

        #expect(StoreTransaction.preferredEntitlement(among: [later, earlier])?.id == 2)
        #expect(StoreTransaction.preferredEntitlement(among: [earlier, later])?.id == 2)
    }

    @Test("a tie on date is broken by id, so the answer never depends on order")
    func tieBrokenByID() {
        let first = transaction(id: 5, purchaseDate: trialStarted)
        let second = transaction(id: 3, purchaseDate: trialStarted)

        #expect(StoreTransaction.preferredEntitlement(among: [first, second])?.id == 3)
        #expect(StoreTransaction.preferredEntitlement(among: [second, first])?.id == 3)
    }

    // MARK: Protocol default

    /// A conformer written against 4.0, which knows nothing of the 4.1 requirement.
    private struct FourOhStandIn: PurchasesProtocol {
        func requestProducts(includingCache: Bool) async throws -> [StoreProduct] { [] }
        #if os(visionOS)
        @MainActor
        func purchase(
            productID: String,
            options: PurchaseOptions,
            confirmIn scene: UIScene
        ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
            throw PurchasesError(.purchaseCancelled)
        }
        #else
        func purchase(
            productID: String,
            options: PurchaseOptions
        ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
            throw PurchasesError(.purchaseCancelled)
        }
        #endif
        func restore() async throws {}
        func hasEntitlement(for productID: String) async -> Bool { false }
        func entitlementProductIDs() async -> Set<String> { [] }
        func activeSubscriptions() async -> [StoreProduct] { [] }
        func activeSubscription(inGroup groupID: String) async -> StoreProduct? { nil }
        func subscriptionStatuses(inGroup groupID: String) async throws -> [StoreSubscriptionStatus] { [] }
        func isEligibleForIntroOffer(inGroup groupID: String) async -> Bool { false }
        func appPurchaseInfo() async throws -> AppPurchaseInfo { throw PurchasesError(.unsupported) }
    }

    /// A stand-in that models a trial, the way an app's tests would.
    private struct TrialStandIn: PurchasesProtocol {
        let trial: StoreTransaction

        func requestProducts(includingCache: Bool) async throws -> [StoreProduct] { [] }
        #if os(visionOS)
        @MainActor
        func purchase(
            productID: String,
            options: PurchaseOptions,
            confirmIn scene: UIScene
        ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
            throw PurchasesError(.purchaseCancelled)
        }
        #else
        func purchase(
            productID: String,
            options: PurchaseOptions
        ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
            throw PurchasesError(.purchaseCancelled)
        }
        #endif
        func restore() async throws {}
        func hasEntitlement(for productID: String) async -> Bool { productID == trial.productID }
        func currentEntitlement(for productID: String) async -> StoreTransaction? {
            productID == trial.productID ? trial : nil
        }
        func entitlementProductIDs() async -> Set<String> { [trial.productID] }
        func activeSubscriptions() async -> [StoreProduct] { [] }
        func activeSubscription(inGroup groupID: String) async -> StoreProduct? { nil }
        func subscriptionStatuses(inGroup groupID: String) async throws -> [StoreSubscriptionStatus] { [] }
        func isEligibleForIntroOffer(inGroup groupID: String) async -> Bool { false }
        func appPurchaseInfo() async throws -> AppPurchaseInfo { throw PurchasesError(.unsupported) }
    }

    @Test("a 4.0 conformer still compiles and reports no entitlement")
    func defaultIsNil() async {
        let purchases: any PurchasesProtocol = FourOhStandIn()

        #expect(await purchases.currentEntitlement(for: "kinboard.trial") == nil)
    }

    /// The method is a requirement with a default, not an extension-only method, so a
    /// conformer's own implementation is what a caller holding `any PurchasesProtocol` gets.
    @Test("a stand-in's own implementation is reached through any PurchasesProtocol")
    func overrideIsDispatched() async throws {
        let purchases: any PurchasesProtocol = TrialStandIn(trial: transaction(id: 9, purchaseDate: trialStarted))

        let entitlement = try #require(await purchases.currentEntitlement(for: "kinboard.trial"))

        #expect(entitlement.purchaseDate == trialStarted)
        #expect(await purchases.currentEntitlement(for: "other.product") == nil)
    }
}
