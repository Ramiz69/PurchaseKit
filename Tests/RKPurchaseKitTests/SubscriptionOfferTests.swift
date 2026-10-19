//
//  SubscriptionOfferTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 19.10.2026.
//

import Foundation
import StoreKit
import Testing
@testable import RKPurchaseKit

/// Covers ``StoreSubscriptionPeriod`` and ``SubscriptionOffer``: the values a paywall shows, and the
/// mappings from StoreKit's two different encodings of the same offer kinds.
@Suite("SubscriptionOffer", .timeLimit(.minutes(1)))
struct SubscriptionOfferTests {

    // MARK: StoreSubscriptionPeriod

    @Test(
        "maps each StoreKit period unit",
        arguments: [
            (Product.SubscriptionPeriod.Unit.day, StoreSubscriptionPeriod.Unit.day),
            (.week, .week),
            (.month, .month),
            (.year, .year)
        ]
    )
    func mapsUnits(storeKitUnit: Product.SubscriptionPeriod.Unit, expected: StoreSubscriptionPeriod.Unit) {
        #expect(StoreSubscriptionPeriod.Unit(storeKitUnit) == expected)
    }

    @Test("periods compare by value and unit")
    func comparesPeriods() {
        #expect(StoreSubscriptionPeriod(value: 1, unit: .month) == StoreSubscriptionPeriod(value: 1, unit: .month))
        #expect(StoreSubscriptionPeriod(value: 1, unit: .month) != StoreSubscriptionPeriod(value: 3, unit: .month))
        #expect(StoreSubscriptionPeriod(value: 7, unit: .day) != StoreSubscriptionPeriod(value: 1, unit: .week))
    }

    // MARK: SubscriptionOffer

    @Test("can be constructed without StoreKit")
    func buildsWithoutStoreKit() {
        let offer = SubscriptionOffer(
            id: "promo.half",
            type: .promotional,
            paymentMode: .payAsYouGo,
            price: 2.49,
            displayPrice: "$2.49",
            period: StoreSubscriptionPeriod(value: 1, unit: .month),
            periodCount: 3
        )

        #expect(offer.id == "promo.half")
        #expect(offer.type == .promotional)
        #expect(offer.paymentMode == .payAsYouGo)
        #expect(offer.price == 2.49)
        #expect(offer.displayPrice == "$2.49")
        #expect(offer.period == StoreSubscriptionPeriod(value: 1, unit: .month))
        #expect(offer.periodCount == 3)
    }

    /// Products and transactions encode the same offer kind differently; both must land on
    /// the same shared constant, or a transaction's offer would never equal the product's.
    @Test("product offer types map onto the shared constants")
    func mapsProductOfferTypes() {
        #expect(SubscriptionOffer.OfferType(productRawValue: Product.SubscriptionOffer.OfferType.introductory.rawValue) == .introductory)
        #expect(SubscriptionOffer.OfferType(productRawValue: Product.SubscriptionOffer.OfferType.promotional.rawValue) == .promotional)
        #expect(SubscriptionOffer.OfferType(productRawValue: Product.SubscriptionOffer.OfferType.winBack.rawValue) == .winBack)
    }

    @Test("transaction offer types map onto the shared constants")
    func mapsTransactionOfferTypes() {
        #expect(SubscriptionOffer.OfferType(transactionRawValue: Transaction.OfferType.introductory.rawValue) == .introductory)
        #expect(SubscriptionOffer.OfferType(transactionRawValue: Transaction.OfferType.promotional.rawValue) == .promotional)
        #expect(SubscriptionOffer.OfferType(transactionRawValue: Transaction.OfferType.code.rawValue) == .code)
        #expect(SubscriptionOffer.OfferType(transactionRawValue: Transaction.OfferType.winBack.rawValue) == .winBack)
    }

    @Test("payment modes from products and transactions map onto the shared constants")
    func mapsPaymentModes() {
        typealias ProductMode = Product.SubscriptionOffer.PaymentMode
        typealias TransactionMode = Transaction.Offer.PaymentMode

        #expect(SubscriptionOffer.PaymentMode(productRawValue: ProductMode.freeTrial.rawValue) == .freeTrial)
        #expect(SubscriptionOffer.PaymentMode(productRawValue: ProductMode.payAsYouGo.rawValue) == .payAsYouGo)
        #expect(SubscriptionOffer.PaymentMode(productRawValue: ProductMode.payUpFront.rawValue) == .payUpFront)
        #expect(SubscriptionOffer.PaymentMode(transactionRawValue: TransactionMode.freeTrial.rawValue) == .freeTrial)
        #expect(SubscriptionOffer.PaymentMode(transactionRawValue: TransactionMode.payAsYouGo.rawValue) == .payAsYouGo)
        #expect(SubscriptionOffer.PaymentMode(transactionRawValue: TransactionMode.payUpFront.rawValue) == .payUpFront)
    }

    /// The point of a raw-value struct: a kind StoreKit adds later is carried, not dropped
    /// and not mistaken for a known one.
    @Test("unfamiliar offer kinds are kept rather than guessed")
    func keepsUnknownKinds() {
        let productType = SubscriptionOffer.OfferType(productRawValue: "FutureOffer")
        let transactionType = SubscriptionOffer.OfferType(transactionRawValue: 99)
        let mode = SubscriptionOffer.PaymentMode(transactionRawValue: "ONE_TIME")

        #expect(productType.rawValue == "FutureOffer")
        #expect(transactionType.rawValue == "99")
        #expect(mode.rawValue == "ONE_TIME")
        #expect(![.introductory, .promotional, .winBack, .code].contains(transactionType))
        #expect(![.freeTrial, .payAsYouGo, .payUpFront].contains(mode))
    }
}
