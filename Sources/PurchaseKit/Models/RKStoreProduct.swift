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
    /// The raw StoreKit product object.
    public let product: Product
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
    public let isPurchased: Bool
    /// Subscription group identifier for auto-renewable subscriptions.
    ///
    /// `nil` for non-subscription products and non-grouped items.
    public let subscriptionGroupID: String?

    // MARK: Initial method

    /// Designated initializer. You don't create `StoreProduct` manually in apps —
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

    // MARK: Internal methods
    
    /// Returns a copy with an updated `isPurchased` flag.
    ///
    /// - Parameter isPurchased: New entitlement state.
    /// - Returns: A new ``StoreProduct`` instance.
    func setPurchasingFlag(_ isPurchased: Bool) -> StoreProduct {
        StoreProduct(product: product, isPurchased: isPurchased)
    }
}
