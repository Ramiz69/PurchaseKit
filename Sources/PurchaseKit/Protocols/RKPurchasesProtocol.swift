//
//  RKPurchasesProtocol.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit
#if os(visionOS)
public import UIKit
#endif

/// Protocol abstraction to allow mocking in tests.
/// Full spec: <doc:PurchasesProtocol>
///
/// Requirements are kept to what a stand-in genuinely has to decide. Every shorter call -
/// a purchase without options, products with the cache, the single status of a group - is an
/// extension method that forwards to a requirement, so a mock cannot answer one differently
/// from the other and every new convenience is free for existing conformers.
public protocol PurchasesProtocol: Sendable {
    /// Fetches products from StoreKit (optionally returns cached values first).
    ///
    /// Internally uses `Product.products(for:)` for the identifiers passed to
    /// ``PurchasesManager/configure(identifiers:finishing:)``.
    ///
    /// - Parameter includingCache: If `true`, returns cached products immediately
    ///   and refreshes entitlements in the background.
    /// - Returns: Array of ``StoreProduct``.
    /// - Throws: ``PurchasesError`` if StoreKit lookup fails.
    func requestProducts(includingCache: Bool) async throws -> [StoreProduct]
    #if !os(visionOS)
    /// Starts a purchase flow for the given product with `options` applied.
    ///
    /// The single purchase requirement: `purchase(productID:)` and
    /// ``ServerVerifiedPurchasesProtocol/purchase(productID:appAccountToken:)`` build the
    /// options and call this. Not part of the protocol on visionOS; see
    /// `purchase(productID:options:confirmIn:)`.
    ///
    /// - Parameters:
    ///   - productID: A product identifier registered in App Store Connect.
    ///   - options: Account token, quantity, offers and sandbox switches. Pass
    ///     ``PurchaseOptions/none`` for a plain purchase.
    /// - Returns: The verified ``StoreProduct`` that has just been purchased, and the
    ///   ``StoreTransaction`` describing the purchase.
    /// - Throws: ``PurchasesError``, for example ``PurchasesError/Code/purchaseCancelled``,
    ///   ``PurchasesError/Code/purchasePending``, ``PurchasesError/Code/verificationFailed``,
    ///   ``PurchasesError/Code/invalidProductID`` or ``PurchasesError/Code/offerNotFound``.
    func purchase(
        productID: String,
        options: PurchaseOptions
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction)
    #endif
    #if os(visionOS)
    /// Starts a purchase flow for the given product with `options` applied, presenting the
    /// App Store confirmation in `scene`.
    ///
    /// visionOS has no scene-less purchase call, so this replaces
    /// `purchase(productID:options:)` there. It is a requirement rather than a manager-only
    /// method so that a stand-in implementation can represent a purchase on visionOS too.
    ///
    /// - Parameters:
    ///   - productID: A product identifier registered in App Store Connect.
    ///   - options: Account token, quantity, offers and sandbox switches. Pass
    ///     ``PurchaseOptions/none`` for a plain purchase.
    ///   - scene: The scene the system uses to show the purchase confirmation.
    /// - Returns: The verified ``StoreProduct`` that has just been purchased, and the
    ///   ``StoreTransaction`` describing the purchase.
    /// - Throws: ``PurchasesError``, for example ``PurchasesError/Code/purchaseCancelled``,
    ///   ``PurchasesError/Code/purchasePending``, ``PurchasesError/Code/verificationFailed``,
    ///   ``PurchasesError/Code/invalidProductID`` or ``PurchasesError/Code/offerNotFound``.
    @MainActor
    func purchase(
        productID: String,
        options: PurchaseOptions,
        confirmIn scene: UIScene
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction)
    #endif
    /// Synchronizes with the App Store and re-evaluates the current entitlements.
    ///
    /// You typically call this from a "Restore Purchases" button.
    ///
    /// - Throws: ``PurchasesError`` on sync failure.
    func restore() async throws
    /// Returns `true` if the user currently has an active entitlement for `productID`.
    ///
    /// Uses `Transaction.currentEntitlements(for:)` under the hood.
    /// - Parameter productID: Product identifier to check.
    func hasEntitlement(for productID: String) async -> Bool
    /// Returns the set of all product identifiers for which the user has an active entitlement.
    ///
    /// The result reflects **current** rights only (including grace period).
    func entitlementProductIDs() async -> Set<String>
    /// Returns all active auto-renewable subscriptions - bundles and suites included - mapped
    /// to your ``StoreProduct`` model.
    ///
    /// If a product is not cached yet, it will be fetched from StoreKit on demand.
    func activeSubscriptions() async -> [StoreProduct]
    /// Returns the active subscription within a specific subscription group, if any.
    ///
    /// If multiple are present, the subscription with the latest expiration date is returned.
    /// - Parameter groupID: The subscription group identifier from App Store Connect.
    func activeSubscription(inGroup groupID: String) async -> StoreProduct?
    /// Returns every renewal status StoreKit holds for a subscription group.
    ///
    /// Usually one; Family Sharing or a plan change can produce several. Use
    /// ``subscriptionStatus(inGroup:)`` for the one that describes the customer's access.
    /// Statuses whose transaction fails verification are left out.
    ///
    /// - Parameter groupID: The subscription group identifier from App Store Connect.
    /// - Returns: An empty array when the customer has never subscribed to the group.
    /// - Throws: ``PurchasesError`` if StoreKit cannot read the statuses.
    func subscriptionStatuses(inGroup groupID: String) async throws -> [StoreSubscriptionStatus]
    /// Returns whether the customer may still redeem an introductory offer in the group.
    ///
    /// ``StoreProduct/introductoryOffer`` says what is configured; this says whether this
    /// customer can have it. Someone who has already redeemed one in the group cannot.
    ///
    /// - Parameter groupID: The subscription group identifier from App Store Connect.
    func isEligibleForIntroOffer(inGroup groupID: String) async -> Bool
    /// Returns how and when the customer got the app itself.
    ///
    /// - Throws: ``PurchasesError/Code/verificationFailed`` if the app transaction fails
    ///   verification, or another ``PurchasesError`` if StoreKit cannot read it.
    func appPurchaseInfo() async throws -> AppPurchaseInfo
}

// MARK: - Conveniences

/// Shorter calls that forward to a requirement.
///
/// None of them repeats a requirement's signature. An overload that only adds a default
/// value to a requirement becomes the witness for any conformer that does not implement the
/// requirement itself, and then calls itself forever.
public extension PurchasesProtocol {
    /// Calls ``PurchasesProtocol/requestProducts(includingCache:)`` with caching enabled.
    ///
    /// Takes no parameters on purpose; see the note on this extension.
    func requestProducts() async throws -> [StoreProduct] {
        try await requestProducts(includingCache: true)
    }
    #if !os(visionOS)
    /// Buys `productID` with ``PurchaseOptions/none``.
    ///
    /// Forwards to ``PurchasesProtocol/purchase(productID:options:)``. Not a requirement: a
    /// conformer that declares its own copy is bypassed by calls made through the protocol.
    func purchase(productID: String) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
        try await purchase(productID: productID, options: .none)
    }
    #endif
    #if os(visionOS)
    /// Buys `productID` with ``PurchaseOptions/none``, presenting the App Store confirmation
    /// in `scene`.
    ///
    /// Forwards to `purchase(productID:options:confirmIn:)`.
    @MainActor
    func purchase(
        productID: String,
        confirmIn scene: UIScene
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
        try await purchase(productID: productID, options: .none, confirmIn: scene)
    }
    #endif
    /// Returns the status that best describes the customer's access to a group, or `nil`
    /// when the customer has never subscribed to it.
    ///
    /// Picks from ``PurchasesProtocol/subscriptionStatuses(inGroup:)``: subscribed beats a
    /// grace period, which beats billing retry, then expired, then revoked; a tie goes to the
    /// later expiration date. Living here rather than in each conformer keeps a mock's answer
    /// consistent with the manager's for the same statuses.
    ///
    /// - Parameter groupID: The subscription group identifier from App Store Connect.
    /// - Throws: Whatever ``PurchasesProtocol/subscriptionStatuses(inGroup:)`` throws.
    func subscriptionStatus(inGroup groupID: String) async throws -> StoreSubscriptionStatus? {
        StoreSubscriptionStatus.best(of: try await subscriptionStatuses(inGroup: groupID))
    }
}
