//
//  PurchaseOptionsTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 19.10.2026.
//

import Foundation
import StoreKit
import Testing
@testable import RKPurchaseKit

/// Covers ``PurchaseOptions`` and its translation into StoreKit's purchase options.
///
/// The translation takes the product's win-back offers rather than the product, because a
/// `Product` cannot be built in a test. A matching win-back offer cannot be built either, so
/// the success path for win-back offers is left to StoreKit testing.
@Suite("PurchaseOptions", .timeLimit(.minutes(1)))
struct PurchaseOptionsTests {

    @Test("defaults describe a plain purchase")
    func appliesDefaults() {
        let options = PurchaseOptions()

        #expect(options.appAccountToken == nil)
        #expect(options.quantity == 1)
        #expect(options.promotionalOffer == nil)
        #expect(options.winBackOfferID == nil)
        #expect(options.introductoryOfferEligibilityJWS == nil)
        #expect(!options.simulatesAskToBuyInSandbox)
        #expect(options == .none)
    }

    /// An untouched value must reach StoreKit as an untouched purchase, not as a set that
    /// restates StoreKit's own defaults.
    @Test("a plain purchase passes no options to StoreKit")
    func translatesNoneToEmptySet() throws {
        #expect(try PurchaseOptions.none.storeKitOptions(winBackOffers: []).isEmpty)
    }

    @Test("each option reaches StoreKit")
    func translatesEveryOption() throws {
        let token = UUID()
        let options = PurchaseOptions(
            appAccountToken: token,
            quantity: 3,
            promotionalOffer: .init(offerID: "promo.half", compactJWS: "header.payload.signature"),
            introductoryOfferEligibilityJWS: "eligibility.jws.token",
            simulatesAskToBuyInSandbox: true
        )

        let translated = try options.storeKitOptions(winBackOffers: [])

        var expected: Set<Product.PurchaseOption> = [
            .appAccountToken(token),
            .quantity(3),
            .introductoryOfferEligibility(compactJWS: "eligibility.jws.token"),
            .simulatesAskToBuyInSandbox(true)
        ]
        expected.formUnion(Product.PurchaseOption.promotionalOffer("promo.half", compactJWS: "header.payload.signature"))
        #expect(translated == expected)
    }

    @Test("the default quantity and sandbox flag are left out")
    func omitsDefaults() throws {
        let token = UUID()

        let translated = try PurchaseOptions(appAccountToken: token).storeKitOptions(winBackOffers: [])

        #expect(translated == [.appAccountToken(token)])
    }

    /// Silently dropping an unknown win-back offer would charge full price for a purchase the
    /// customer started from a discount.
    @Test("an unknown win-back offer fails before StoreKit is asked")
    func rejectsUnknownWinBackOffer() {
        let options = PurchaseOptions(winBackOfferID: "winback.half")

        #expect(throws: PurchasesError(.offerNotFound, offerID: "winback.half")) {
            try options.storeKitOptions(winBackOffers: [])
        }
    }

    @Test("options compare by value")
    func comparesByValue() {
        let token = UUID()

        #expect(PurchaseOptions(appAccountToken: token) == PurchaseOptions(appAccountToken: token))
        #expect(PurchaseOptions(appAccountToken: token) != PurchaseOptions(appAccountToken: UUID()))
        #expect(PurchaseOptions(quantity: 2) != .none)
        #expect(
            PurchaseOptions(promotionalOffer: .init(offerID: "a", compactJWS: "x"))
                != PurchaseOptions(promotionalOffer: .init(offerID: "a", compactJWS: "y"))
        )
    }
}
