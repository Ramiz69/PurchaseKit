//
//  StoreProductTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Testing
@testable import RKPurchaseKit

/// Covers the initializer that lets a ``StoreProduct`` exist without StoreKit behind it.
@Suite("StoreProduct", .timeLimit(.minutes(1)))
struct StoreProductTests {

    private func makeSubscription(isPurchased: Bool = false) -> StoreProduct {
        StoreProduct(
            productID: "pro.monthly",
            type: .autoRenewable,
            displayName: "Pro Monthly",
            description: "Everything, billed monthly",
            price: 4.99,
            displayPrice: "$4.99",
            isFamilyShareable: true,
            isPurchased: isPurchased,
            subscriptionGroupID: "group.pro"
        )
    }

    /// `StoreKit.Product` has no public initializer, so before this initializer existed a
    /// `StoreProduct` could not be built in a test or a preview at all.
    @Test("can be constructed without StoreKit")
    func buildsWithoutStoreKit() {
        let product = makeSubscription(isPurchased: true)

        #expect(product.product == nil)
        #expect(product.productID == "pro.monthly")
        #expect(product.type == .autoRenewable)
        #expect(product.displayName == "Pro Monthly")
        #expect(product.description == "Everything, billed monthly")
        #expect(product.price == 4.99)
        #expect(product.displayPrice == "$4.99")
        #expect(product.isFamilyShareable)
        #expect(product.isPurchased)
        #expect(product.subscriptionGroupID == "group.pro")
    }

    @Test("optional details default to absent")
    func appliesDefaults() {
        let product = StoreProduct(
            productID: "tip.small",
            type: .consumable,
            displayName: "Small Tip",
            description: "Thanks",
            price: 0.99,
            displayPrice: "$0.99"
        )

        #expect(!product.isFamilyShareable)
        #expect(!product.isPurchased)
        #expect(product.subscriptionGroupID == nil)
    }

    /// `setPurchasingFlag` used to rebuild the value from its backing `StoreKit.Product`,
    /// which a synthesized product does not have. It now copies and adjusts instead.
    @Test("the entitlement flag moves on a product with no StoreKit backing", arguments: [true, false])
    func updatesFlagWithoutStoreKit(startingPurchased: Bool) {
        let product = makeSubscription(isPurchased: startingPurchased)

        let updated = product.setPurchasingFlag(!startingPurchased)

        #expect(updated.isPurchased == !startingPurchased)
        #expect(product.isPurchased == startingPurchased, "the original value must not change")
    }

    @Test("only the entitlement flag changes")
    func preservesEveryOtherField() {
        let product = makeSubscription()

        let updated = product.setPurchasingFlag(true)

        #expect(updated.productID == product.productID)
        #expect(updated.type == product.type)
        #expect(updated.displayName == product.displayName)
        #expect(updated.description == product.description)
        #expect(updated.price == product.price)
        #expect(updated.displayPrice == product.displayPrice)
        #expect(updated.isFamilyShareable == product.isFamilyShareable)
        #expect(updated.subscriptionGroupID == product.subscriptionGroupID)
    }

    @Test("an event can be built around a product")
    func wrapsIntoEvent() {
        let product = makeSubscription(isPurchased: true)

        let event = PurchasedProductEvent(product: product)

        #expect(event.product.productID == product.productID)
        #expect(event.product.isPurchased)
    }
}
