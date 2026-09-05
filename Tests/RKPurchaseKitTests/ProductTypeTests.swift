//
//  ProductTypeTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Testing
import StoreKit
@testable import RKPurchaseKit

/// Covers the mapping from `StoreKit.Product.ProductType` onto the SDK-level enum.
@Suite("ProductType", .timeLimit(.minutes(1)))
struct ProductTypeTests {

    @Test(
        "maps each StoreKit product type",
        arguments: [
            (Product.ProductType.consumable, ProductType.consumable),
            (Product.ProductType.nonConsumable, ProductType.nonConsumable),
            (Product.ProductType.nonRenewable, ProductType.nonRenewable),
            (Product.ProductType.autoRenewable, ProductType.autoRenewable)
        ]
    )
    func mapsKnownTypes(storeKitType: Product.ProductType, expected: ProductType) {
        #expect(ProductType(storeKitType) == expected)
    }

    /// `Product.ProductType` is a non-frozen raw-value type, so a future StoreKit release can
    /// introduce a kind this SDK has never seen. It used to land on `.nonConsumable`, which
    /// reads as a permanent one-off purchase and hid the fact that the SDK was guessing.
    @Test("an unknown StoreKit type maps to unknown, not to a real kind")
    func mapsUnknownTypeToUnknown() {
        let future = Product.ProductType(rawValue: "future-store-kit-type")

        #expect(ProductType(future) == .unknown)
        #expect(ProductType(future) != .nonConsumable)
    }
}
