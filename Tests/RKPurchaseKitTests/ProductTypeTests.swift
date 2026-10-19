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

    /// The OS 27 constants cannot be referenced while CI builds with the OS 26 SDKs, so these
    /// kinds are recognised by StoreKit's raw strings, verified against the 27.1 SDK.
    @Test(
        "maps the OS 27 subscription kinds by raw value",
        arguments: [
            ("Subscription Bundle", ProductType.subscriptionBundle),
            ("Subscription Suite", ProductType.subscriptionSuite)
        ]
    )
    func mapsBundleAndSuite(rawValue: String, expected: ProductType) {
        #expect(ProductType(rawValue: rawValue) == expected)
        #expect(ProductType(Product.ProductType(rawValue: rawValue)) == expected)
    }

    /// Bundles and suites renew like any subscription; code that compared with
    /// `.autoRenewable` alone would quietly treat them as one-off purchases.
    @Test(
        "every renewing kind counts as an auto-renewable subscription",
        arguments: [
            (ProductType.autoRenewable, true),
            (.subscriptionBundle, true),
            (.subscriptionSuite, true),
            (.nonRenewable, false),
            (.consumable, false),
            (.nonConsumable, false),
            (.unknown, false)
        ]
    )
    func flagsAutoRenewableKinds(type: ProductType, expected: Bool) {
        #expect(type.isAutoRenewableSubscription == expected)
    }
}
