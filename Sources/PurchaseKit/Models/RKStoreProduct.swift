//
//  RKStoreProduct.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit

/// Immutable value describing a `StoreKit` product.
/// See <doc:StoreProduct> for full details.
public struct StoreProduct: Sendable {

    // MARK: Properties
    /// The raw StoreKit product this value was read from.
    ///
    /// `nil` for a value you construct yourself — a test double, a SwiftUI preview fixture,
    /// or a mock implementation of ``PurchasesProtocol``. `StoreKit.Product` has no public
    /// initializer and cannot be created outside StoreKit, so a `StoreProduct` that always
    /// carried one was impossible to build in a test, which left ``PurchasesProtocol``
    /// unmockable despite existing to be mocked.
    public let product: Product?
    /// The product identifier from App Store Connect.
    public let productID: String
    /// High-level product type (mapped from `Product.ProductType`).
    public let type: ProductType
    /// Localized display name as presented by App Store.
    public let displayName: String
    /// Localized description as presented by App Store.
    public let description: String
    /// Numeric price (ISO currency via `product.priceFormatStyle.currencyCode`).
    public let price: Decimal
    /// Localized formatted price (e.g. `"$4.99"`).
    public let displayPrice: String
    /// Whether family sharing is allowed.
    public let isFamilyShareable: Bool
    /// Convenience flag reflecting whether the user currently holds an entitlement
    /// for this product (derived from `Transaction.currentEntitlements`).
    public private(set) var isPurchased: Bool
    /// Subscription group identifier for auto-renewable subscriptions.
    ///
    /// `nil` for non-subscription products and non-grouped items.
    public let subscriptionGroupID: String?

    // MARK: Initial methods

    /// Designated initializer. You don't create `StoreProduct` this way in apps —
    /// it is produced by the kit from `StoreKit.Product`.
    init(product: Product, isPurchased: Bool) {
        self.product = product
        productID = product.id
        type = ProductType(product.type)
        displayName = product.displayName
        description = product.description
        price = product.price
        displayPrice = product.displayPrice
        isFamilyShareable = product.isFamilyShareable
        self.isPurchased = isPurchased
        subscriptionGroupID = product.subscription?.subscriptionGroupID
    }
    /// Creates a value that is not backed by StoreKit.
    ///
    /// Use this in tests, previews and mock implementations of ``PurchasesProtocol``.
    /// ``product`` is `nil` on the result, so code that reaches through to StoreKit should
    /// treat it as absent rather than force-unwrap it.
    public init(
        productID: String,
        type: ProductType,
        displayName: String,
        description: String,
        price: Decimal,
        displayPrice: String,
        isFamilyShareable: Bool = false,
        isPurchased: Bool = false,
        subscriptionGroupID: String? = nil
    ) {
        product = nil
        self.productID = productID
        self.type = type
        self.displayName = displayName
        self.description = description
        self.price = price
        self.displayPrice = displayPrice
        self.isFamilyShareable = isFamilyShareable
        self.isPurchased = isPurchased
        self.subscriptionGroupID = subscriptionGroupID
    }

    // MARK: Internal methods

    /// Returns a copy with an updated `isPurchased` flag.
    ///
    /// - Parameter isPurchased: New entitlement state.
    /// - Returns: A new ``StoreProduct`` instance.
    func setPurchasingFlag(_ isPurchased: Bool) -> StoreProduct {
        // Copy and adjust rather than rebuild from `product`, which is absent on values that
        // did not come from StoreKit.
        var updated = self
        updated.isPurchased = isPurchased

        return updated
    }
}
