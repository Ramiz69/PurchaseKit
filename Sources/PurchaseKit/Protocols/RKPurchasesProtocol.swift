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
public protocol PurchasesProtocol: Sendable {
    /// Fetches products from StoreKit (optionally returns cached values first).
    ///
    /// Internally uses `Product.products(for:)` for the identifiers passed to
    /// ``PurchasesManager/configure(identifiers:)``.
    ///
    /// - Parameter includingCache: If `true`, returns cached products immediately
    ///   and refreshes entitlements in the background.
    /// - Returns: Array of ``StoreProduct``.
    /// - Throws: ``PurchasesError`` if StoreKit lookup fails.
    func requestProducts(includingCache: Bool) async throws -> [StoreProduct]
    #if !os(visionOS)
    /// Starts a purchase flow for the given product.
    ///
    /// Not part of the protocol on visionOS; see `purchase(productID:confirmIn:)`.
    ///
    /// - Parameter productID: A product identifier registered in App Store Connect.
    /// - Returns: The verified ``StoreProduct`` that has just been purchased, and the
    ///   ``StoreTransaction`` describing the purchase.
    /// - Throws: ``PurchasesError/purchaseCancelled``, ``PurchasesError/purchasePending``,
    ///           ``PurchasesError/verificationFailed``, or ``PurchasesError/invalidProductID(_:)``.
    func purchase(productID: String) async throws -> (product: StoreProduct, transaction: StoreTransaction)
    #endif
    #if os(visionOS)
    /// Starts a purchase flow for the given product, presenting the App Store confirmation
    /// in `scene`.
    ///
    /// visionOS has no scene-less purchase call, so this replaces
    /// `purchase(productID:)` there. It is a requirement rather than a manager-only method
    /// so that a stand-in implementation can represent a purchase on visionOS too.
    ///
    /// - Parameters:
    ///   - productID: A product identifier registered in App Store Connect.
    ///   - scene: The scene the system uses to show the purchase confirmation.
    /// - Returns: The verified ``StoreProduct`` that has just been purchased, and the
    ///   ``StoreTransaction`` describing the purchase.
    /// - Throws: ``PurchasesError/purchaseCancelled``, ``PurchasesError/purchasePending``,
    ///           ``PurchasesError/verificationFailed``, or ``PurchasesError/invalidProductID(_:)``.
    @MainActor
    func purchase(
        productID: String,
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
    /// Uses `Transaction.currentEntitlements` under the hood.
    /// - Parameter productID: Product identifier to check.
    func hasEntitlement(for productID: String) async -> Bool
    /// Returns the set of all product identifiers for which the user has an active entitlement.
    ///
    /// The result reflects **current** rights only (including grace period).
    func entitlementProductIDs() async -> Set<String>
    /// Returns all active **auto-renewable** subscriptions mapped to your ``StoreProduct`` model.
    ///
    /// If a product is not cached yet, it will be fetched from StoreKit on demand.
    func activeSubscriptions() async -> [StoreProduct]
    /// Returns the active subscription within a specific subscription group, if any.
    ///
    /// If multiple are present, the subscription with the latest expiration date is returned.
    /// - Parameter groupID: The subscription group identifier from App Store Connect.
    func activeSubscription(inGroup groupID: String) async -> StoreProduct?
}

/// Default wrapper that keeps source compatibility.
/// - SeeAlso: ``PurchasesProtocol/requestProducts(includingCache:)``
public extension PurchasesProtocol {
    /// Calls ``PurchasesProtocol/requestProducts(includingCache:)`` with caching enabled.
    ///
    /// Takes no parameters on purpose. An overload that repeats the requirement's signature
    /// and only adds a default value becomes the witness for any conformer that does not
    /// implement the requirement itself, and then calls itself forever.
    func requestProducts() async throws -> [StoreProduct] {
        try await requestProducts(includingCache: true)
    }
}
