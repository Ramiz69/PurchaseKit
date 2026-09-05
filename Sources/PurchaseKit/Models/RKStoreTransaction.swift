//
//  RKStoreTransaction.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit

/// Immutable value describing a completed `StoreKit` transaction.
///
/// The kit builds these from `StoreKit.Transaction`. You can also build one directly, which
/// `StoreKit.Transaction` does not allow — it has no public initializer — and that is what
/// makes ``PurchasesProtocol/purchase(productID:)`` mockable: a stand-in can return a
/// successful purchase instead of only being able to throw.
public struct StoreTransaction: Sendable {

    // MARK: Properties
    /// The raw StoreKit transaction this value was read from.
    ///
    /// `nil` for a value you construct yourself, so treat it as absent rather than force
    /// unwrapping it. Reach for it when you need something this type does not surface.
    public let transaction: Transaction?
    /// Identifier of this transaction.
    public let id: UInt64
    /// Identifier of the original transaction for the product or subscription.
    public let originalID: UInt64
    /// The product this transaction is for.
    public let productID: String
    /// When the App Store charged the account.
    public let purchaseDate: Date
    /// When the original transaction for this product occurred.
    public let originalPurchaseDate: Date
    /// When an auto-renewable subscription expires. `nil` for other product types.
    public let expirationDate: Date?
    /// When the App Store refunded or revoked the transaction, if it did.
    ///
    /// A non-`nil` value means the entitlement is gone: a refund, a family-sharing grant
    /// withdrawn, or a revocation by App Store support.
    public let revocationDate: Date?
    /// Whether the subscription was upgraded and this transaction superseded.
    public let isUpgraded: Bool
    /// How many consumable units this transaction covers.
    public let purchasedQuantity: Int
    /// The token your app supplied to associate the purchase with an account.
    public let appAccountToken: UUID?
    /// Subscription group of an auto-renewable subscription. `nil` for other product types.
    public let subscriptionGroupID: String?

    // MARK: Initial methods

    /// Designated initializer. You don't create `StoreTransaction` this way in apps —
    /// it is produced by the kit from `StoreKit.Transaction`.
    init(transaction: Transaction) {
        self.transaction = transaction
        id = transaction.id
        originalID = transaction.originalID
        productID = transaction.productID
        purchaseDate = transaction.purchaseDate
        originalPurchaseDate = transaction.originalPurchaseDate
        expirationDate = transaction.expirationDate
        revocationDate = transaction.revocationDate
        isUpgraded = transaction.isUpgraded
        purchasedQuantity = transaction.purchasedQuantity
        appAccountToken = transaction.appAccountToken
        subscriptionGroupID = transaction.subscriptionGroupID
    }
    /// Creates a value that is not backed by StoreKit.
    ///
    /// Use this in tests, previews and mock implementations of ``PurchasesProtocol``.
    /// ``transaction`` is `nil` on the result.
    public init(
        id: UInt64,
        productID: String,
        purchaseDate: Date,
        originalID: UInt64? = nil,
        originalPurchaseDate: Date? = nil,
        expirationDate: Date? = nil,
        revocationDate: Date? = nil,
        isUpgraded: Bool = false,
        purchasedQuantity: Int = 1,
        appAccountToken: UUID? = nil,
        subscriptionGroupID: String? = nil
    ) {
        transaction = nil
        self.id = id
        self.originalID = originalID ?? id
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.originalPurchaseDate = originalPurchaseDate ?? purchaseDate
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
        self.isUpgraded = isUpgraded
        self.purchasedQuantity = purchasedQuantity
        self.appAccountToken = appAccountToken
        self.subscriptionGroupID = subscriptionGroupID
    }
}
