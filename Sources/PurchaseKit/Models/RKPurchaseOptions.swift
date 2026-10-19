//
//  RKPurchaseOptions.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 19.10.2026.
//

public import Foundation
import StoreKit

/// Everything a purchase can carry besides the product: an account token, a quantity, an
/// offer, and sandbox switches.
///
/// One value instead of a growing list of `purchase` overloads, so a new option is a new
/// defaulted property rather than another protocol requirement every mock has to implement.
/// Pass ``none`` for a plain purchase.
public struct PurchaseOptions: Sendable, Equatable {

    /// A promotional offer signed by your server.
    ///
    /// The signature is a compact JWS your server creates with its In-App Purchase key. The
    /// key must never ship in the app, which is why the kit takes the finished signature
    /// rather than the parts to make one.
    public struct PromotionalOffer: Sendable, Hashable {
        /// The promotional offer identifier from App Store Connect.
        public var offerID: String
        /// The compact JWS your server signed for this offer.
        public var compactJWS: String

        public init(offerID: String, compactJWS: String) {
            self.offerID = offerID
            self.compactJWS = compactJWS
        }
    }

    // MARK: Properties
    /// A UUID that ties the purchase to an account on your server.
    ///
    /// The App Store stores it in the signed transaction, so a server can credit the right
    /// account from the JWS alone.
    public var appAccountToken: UUID?
    /// How many units to buy. Only meaningful for consumables.
    public var quantity: Int
    /// A server-signed promotional offer to apply.
    public var promotionalOffer: PromotionalOffer?
    /// The identifier of one of the product's ``StoreProduct/winBackOffers`` to apply.
    ///
    /// The purchase throws ``PurchasesError/Code/offerNotFound`` if the product has no such
    /// offer.
    public var winBackOfferID: String?
    /// A compact JWS from your server that overrides the App Store's own introductory offer
    /// eligibility decision for this purchase.
    public var introductoryOfferEligibilityJWS: String?
    /// Makes the sandbox treat the purchase as an Ask to Buy request, so the pending path can
    /// be tested. Ignored in production.
    public var simulatesAskToBuyInSandbox: Bool

    // MARK: Initial methods

    public init(
        appAccountToken: UUID? = nil,
        quantity: Int = 1,
        promotionalOffer: PromotionalOffer? = nil,
        winBackOfferID: String? = nil,
        introductoryOfferEligibilityJWS: String? = nil,
        simulatesAskToBuyInSandbox: Bool = false
    ) {
        self.appAccountToken = appAccountToken
        self.quantity = quantity
        self.promotionalOffer = promotionalOffer
        self.winBackOfferID = winBackOfferID
        self.introductoryOfferEligibilityJWS = introductoryOfferEligibilityJWS
        self.simulatesAskToBuyInSandbox = simulatesAskToBuyInSandbox
    }

    /// A plain purchase: one unit, no token, no offer.
    public static let none = PurchaseOptions()

    // MARK: Internal methods

    /// Translates the options into the set StoreKit's `purchase` takes.
    ///
    /// - Throws: ``PurchasesError/Code/offerNotFound`` when ``winBackOfferID`` names an offer
    ///   the product does not have.
    func storeKitOptions(for product: Product) throws -> Set<Product.PurchaseOption> {
        try storeKitOptions(winBackOffers: product.subscription?.winBackOffers ?? [])
    }

    /// The body of ``storeKitOptions(for:)``, taking the win-back offers instead of the
    /// product, because a `Product` cannot be built in a test and the offers list is all of
    /// it this needs.
    func storeKitOptions(winBackOffers: [Product.SubscriptionOffer]) throws -> Set<Product.PurchaseOption> {
        var options: Set<Product.PurchaseOption> = []

        if let appAccountToken {
            options.insert(.appAccountToken(appAccountToken))
        }
        // StoreKit's default is one; leaving the option out keeps the set identical to a
        // plain purchase, which is what an unchanged default should mean.
        if quantity != 1 {
            options.insert(.quantity(quantity))
        }
        if let promotionalOffer {
            // The JWS variant: the signature-based one is deprecated in OS 26, and its key
            // material is exactly what should stay on the server.
            options.formUnion(Product.PurchaseOption.promotionalOffer(promotionalOffer.offerID, compactJWS: promotionalOffer.compactJWS))
        }
        if let winBackOfferID {
            // StoreKit wants the offer itself. Failing here, by name, beats letting the
            // purchase go through at full price because the offer was silently dropped.
            guard let offer = winBackOffers.first(where: { $0.id == winBackOfferID }) else {
                throw PurchasesError(.offerNotFound, offerID: winBackOfferID)
            }
            options.insert(.winBackOffer(offer))
        }
        if let introductoryOfferEligibilityJWS {
            options.insert(.introductoryOfferEligibility(compactJWS: introductoryOfferEligibilityJWS))
        }
        if simulatesAskToBuyInSandbox {
            options.insert(.simulatesAskToBuyInSandbox(true))
        }

        return options
    }
}
