//
//  RKStoreProduct.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

public import Foundation
public import StoreKit

/// Immutable value describing a `StoreKit` product.
/// See <doc:StoreProduct> for full details.
public struct StoreProduct: Sendable {

    // MARK: Properties
    /// The raw StoreKit product this value was read from.
    ///
    /// `nil` for a value you construct yourself — a test double, a SwiftUI preview fixture,
    /// or a mock implementation of ``PurchasesProtocol``. `StoreKit.Product` has no public
    /// initializer and cannot be created outside StoreKit, so a `StoreProduct` that always
    /// carried one was impossible to build in a test, which left ``PurchasesProtocol``
    /// unmockable despite existing to be mocked.
    public let product: Product?
    /// The product identifier from App Store Connect.
    public let productID: String
    /// High-level product type (mapped from `Product.ProductType`).
    public let type: ProductType
    /// Localized display name as presented by App Store.
    public let displayName: String
    /// Localized description as presented by App Store.
    public let description: String
    /// Numeric price, in ``currencyCode``.
    public let price: Decimal
    /// Localized formatted price (e.g. `"$4.99"`).
    public let displayPrice: String
    /// ISO 4217 code of the currency ``price`` is in (e.g. `"USD"`).
    ///
    /// ``price`` alone is a bare number, and analytics or a server that records it without the
    /// currency records something meaningless. StoreKit only exposes the code through
    /// `priceFormatStyle`, which is one reach too far for most callers.
    public let currencyCode: String
    /// Whether family sharing is allowed.
    public let isFamilyShareable: Bool
    /// Convenience flag reflecting whether the user currently holds an entitlement
    /// for this product (derived from `Transaction.currentEntitlements`).
    public private(set) var isPurchased: Bool
    /// Subscription group identifier for auto-renewable subscriptions.
    ///
    /// `nil` for non-subscription products and non-grouped items.
    public let subscriptionGroupID: String?
    /// How often an auto-renewable subscription bills. `nil` for other product types.
    public let subscriptionPeriod: StoreSubscriptionPeriod?
    /// The introductory offer configured for the subscription, if any.
    ///
    /// Configured is not the same as available: whether this customer may still use it is
    /// answered by ``PurchasesProtocol/isEligibleForIntroOffer(inGroup:)``.
    public let introductoryOffer: SubscriptionOffer?
    /// Promotional offers configured for the subscription. Buying one needs a signature from
    /// your server, passed through ``PurchaseOptions/promotionalOffer``.
    public let promotionalOffers: [SubscriptionOffer]
    /// Win-back offers configured for the subscription, for customers whose subscription
    /// lapsed. Bought by identifier through ``PurchaseOptions/winBackOfferID``.
    public let winBackOffers: [SubscriptionOffer]

    // MARK: Initial methods

    /// Designated initializer. You don't create `StoreProduct` this way in apps —
    /// it is produced by the kit from `StoreKit.Product`.
    init(product: Product, isPurchased: Bool) {
        self.product = product
        productID = product.id
        type = ProductType(product.type)
        displayName = product.displayName
        description = product.description
        price = product.price
        displayPrice = product.displayPrice
        currencyCode = product.priceFormatStyle.currencyCode
        isFamilyShareable = product.isFamilyShareable
        self.isPurchased = isPurchased
        subscriptionGroupID = product.subscription?.subscriptionGroupID
        subscriptionPeriod = product.subscription.flatMap { StoreSubscriptionPeriod($0.subscriptionPeriod) }
        introductoryOffer = product.subscription?.introductoryOffer.flatMap(SubscriptionOffer.init)
        promotionalOffers = product.subscription?.promotionalOffers.compactMap(SubscriptionOffer.init) ?? []
        winBackOffers = product.subscription?.winBackOffers.compactMap(SubscriptionOffer.init) ?? []
    }
    /// Creates a value that is not backed by StoreKit.
    ///
    /// Use this in tests, previews and mock implementations of ``PurchasesProtocol``.
    /// ``product`` is `nil` on the result, so code that reaches through to StoreKit should
    /// treat it as absent rather than force-unwrap it.
    ///
    /// `currencyCode` has no default: any currency the kit picked would be a guess that reads
    /// as fact in the data it ends up in.
    public init(
        productID: String,
        type: ProductType,
        displayName: String,
        description: String,
        price: Decimal,
        displayPrice: String,
        currencyCode: String,
        isFamilyShareable: Bool = false,
        isPurchased: Bool = false,
        subscriptionGroupID: String? = nil,
        subscriptionPeriod: StoreSubscriptionPeriod? = nil,
        introductoryOffer: SubscriptionOffer? = nil,
        promotionalOffers: [SubscriptionOffer] = [],
        winBackOffers: [SubscriptionOffer] = []
    ) {
        product = nil
        self.productID = productID
        self.type = type
        self.displayName = displayName
        self.description = description
        self.price = price
        self.displayPrice = displayPrice
        self.currencyCode = currencyCode
        self.isFamilyShareable = isFamilyShareable
        self.isPurchased = isPurchased
        self.subscriptionGroupID = subscriptionGroupID
        self.subscriptionPeriod = subscriptionPeriod
        self.introductoryOffer = introductoryOffer
        self.promotionalOffers = promotionalOffers
        self.winBackOffers = winBackOffers
    }

    // MARK: Internal methods

    /// Returns a copy with an updated `isPurchased` flag.
    ///
    /// - Parameter isPurchased: New entitlement state.
    /// - Returns: A new ``StoreProduct`` instance.
    func setPurchasingFlag(_ isPurchased: Bool) -> StoreProduct {
        // Copy and adjust rather than rebuild from `product`, which is absent on values that
        // did not come from StoreKit.
        var updated = self
        updated.isPurchased = isPurchased

        return updated
    }
}
