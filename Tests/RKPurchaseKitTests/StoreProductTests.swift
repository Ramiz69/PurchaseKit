//
//  StoreProductTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
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
            currencyCode: "USD",
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
        #expect(product.currencyCode == "USD")
    }

    @Test("subscription details can be supplied")
    func buildsSubscriptionDetails() {
        let month = StoreSubscriptionPeriod(value: 1, unit: .month)
        let trial = SubscriptionOffer(
            id: nil,
            type: .introductory,
            paymentMode: .freeTrial,
            price: 0,
            displayPrice: "$0.00",
            period: StoreSubscriptionPeriod(value: 1, unit: .week),
            periodCount: 1
        )
        let comeBack = SubscriptionOffer(
            id: "winback.half",
            type: .winBack,
            paymentMode: .payAsYouGo,
            price: 2.49,
            displayPrice: "$2.49",
            period: month,
            periodCount: 3
        )

        let product = StoreProduct(
            productID: "pro.monthly",
            type: .autoRenewable,
            displayName: "Pro Monthly",
            description: "Everything, billed monthly",
            price: 4.99,
            displayPrice: "$4.99",
            currencyCode: "USD",
            subscriptionGroupID: "group.pro",
            subscriptionPeriod: month,
            introductoryOffer: trial,
            promotionalOffers: [],
            winBackOffers: [comeBack]
        )

        #expect(product.subscriptionPeriod == month)
        #expect(product.introductoryOffer == trial)
        #expect(product.promotionalOffers.isEmpty)
        #expect(product.winBackOffers == [comeBack])
    }

    @Test("optional details default to absent")
    func appliesDefaults() {
        let product = StoreProduct(
            productID: "tip.small",
            type: .consumable,
            displayName: "Small Tip",
            description: "Thanks",
            price: 0.99,
            displayPrice: "$0.99",
            currencyCode: "USD"
        )

        #expect(!product.isFamilyShareable)
        #expect(!product.isPurchased)
        #expect(product.subscriptionGroupID == nil)
        #expect(product.subscriptionPeriod == nil)
        #expect(product.introductoryOffer == nil)
        #expect(product.promotionalOffers.isEmpty)
        #expect(product.winBackOffers.isEmpty)
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
        #expect(updated.currencyCode == product.currencyCode)
    }

    @Test("an event can be built around a product")
    func wrapsIntoEvent() {
        let product = makeSubscription(isPurchased: true)

        let event = PurchasedProductEvent(product: product)

        #expect(event.product.productID == product.productID)
        #expect(event.product.isPurchased)
    }
}
