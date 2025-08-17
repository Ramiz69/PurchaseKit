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

    public let product: Product
    public let productID: String
    public let type: ProductType
    public let displayName: String
    public let description: String
    public let price: Decimal
    public let displayPrice: String
    public let isFamilyShareable: Bool
    public let isPurchased: Bool

    // MARK: Initial method

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
    }

    // MARK: Internal methods
    
    /// Convenience copy-initializer that toggles the `isPurchased` flag.
    /// - Returns: New ``StoreProduct`` instance.
    func setPurchasingFlag(_ isPurchased: Bool) -> StoreProduct {
        StoreProduct(product: product, isPurchased: isPurchased)
    }
}
