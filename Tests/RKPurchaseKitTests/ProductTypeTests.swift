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
    /// introduce a case this SDK has never seen. It currently lands on `.nonConsumable`,
    /// which is silent: this test pins that behaviour so a change to it is deliberate.
    @Test("an unknown StoreKit type falls back to nonConsumable")
    func mapsUnknownTypeToNonConsumable() {
        let unknown = Product.ProductType(rawValue: "future-store-kit-type")

        #expect(ProductType(unknown) == .nonConsumable)
    }
}
