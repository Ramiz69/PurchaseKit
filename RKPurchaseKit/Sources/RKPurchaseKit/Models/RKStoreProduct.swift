//
//  RKStoreProduct.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation

/// Immutable value describing a `StoreKit` product.
/// See <doc:StoreProduct> for full details.
public struct StoreProduct: Sendable {

    // MARK: Properties

    public let productID: String
    public let type: ProductType
    public let displayName: String
    public let description: String
    public let price: Decimal
    public let displayPrice: String
    public let isFamilyShareable: Bool
    public let isPurchased: Bool

    // MARK: Initial method

    public init(
        productID: String,
        type: ProductType,
        displayName: String,
        description: String,
        price: Decimal,
        displayPrice: String,
        isFamilyShareable: Bool,
        isPurchased: Bool
    ) {
        self.productID = productID
        self.type = type
        self.displayName = displayName
        self.description = description
        self.price = price
        self.displayPrice = displayPrice
        self.isFamilyShareable = isFamilyShareable
        self.isPurchased = isPurchased
    }

    // MARK: Internal methods
    
    /// Convenience copy-initializer that toggles the `isPurchased` flag.
    /// - Returns: New ``StoreProduct`` instance.
    func setPurchasingFlag(_ isPurchased: Bool) -> StoreProduct {
        StoreProduct(
            productID: productID,
            type: type,
            displayName: displayName,
            description: description,
            price: price,
            displayPrice: displayPrice,
            isFamilyShareable: isFamilyShareable,
            isPurchased: isPurchased
        )
    }
}
