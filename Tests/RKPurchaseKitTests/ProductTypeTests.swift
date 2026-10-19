//
//  ProductTypeTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Testing
import StoreKit
@testable import RKPurchaseKit

/// Covers the mapping from `StoreKit.Product.ProductType` onto the SDK-level kind.
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

    /// The kit maps by passing StoreKit's raw value through, so the constants must carry
    /// exactly StoreKit's raw values. Comparing against the real constants catches a typo here
    /// or a change on Apple's side.
    @Test(
        "the constants carry StoreKit's raw values",
        arguments: [
            (ProductType.consumable, Product.ProductType.consumable),
            (ProductType.nonConsumable, Product.ProductType.nonConsumable),
            (ProductType.nonRenewable, Product.ProductType.nonRenewable),
            (ProductType.autoRenewable, Product.ProductType.autoRenewable)
        ]
    )
    func matchesStoreKitRawValues(type: ProductType, storeKitType: Product.ProductType) {
        #expect(type.rawValue == storeKitType.rawValue)
    }

    /// `Product.ProductType` is a non-frozen raw-value type, so a future StoreKit release can
    /// introduce a kind this SDK has never seen. It has to arrive as itself: collapsing it into
    /// a known kind would be a guess about what the purchase grants.
    @Test("an unfamiliar StoreKit type is kept as reported")
    func keepsUnfamiliarType() {
        let future = ProductType(Product.ProductType(rawValue: "future-store-kit-type"))

        #expect(future.rawValue == "future-store-kit-type")
        #expect(future == ProductType(rawValue: "future-store-kit-type"))
        #expect(future != .nonConsumable)
        #expect(!future.isAutoRenewableSubscription)
    }

    /// The OS 27 constants cannot be referenced while CI builds with the OS 26 SDKs, so these
    /// kinds are spelled with StoreKit's raw strings, verified against the 27.1 SDK.
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
        #expect(expected.rawValue == rawValue)
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
            (ProductType(rawValue: "Future Kind"), false)
        ]
    )
    func flagsAutoRenewableKinds(type: ProductType, expected: Bool) {
        #expect(type.isAutoRenewableSubscription == expected)
    }
}
