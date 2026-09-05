//
//  RKPurchasesProtocol.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit

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
    /// Starts a purchase flow for the given product.
    ///
    /// - Parameter productID: A product identifier registered in App Store Connect.
    /// - Returns: A verified ``StoreProduct`` that has just been purchased.
    /// - Throws: ``PurchasesError/purchaseCancelled``, ``PurchasesError/purchasePending``,
    ///           ``PurchasesError/verificationFailed``, or ``PurchasesError/invalidProductID(_:)``.
    func purchase(productID: String) async throws -> (product: StoreProduct, transaction: Transaction)
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
