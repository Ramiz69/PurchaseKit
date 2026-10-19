//
//  RKSubscriptionOffer.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 19.10.2026.
//

public import Foundation
import StoreKit

/// A discount a subscription product can be bought with: an introductory, promotional or
/// win-back offer.
///
/// Mirrors `Product.SubscriptionOffer`, which has no public initializer, so a paywall that
/// shows offers can be previewed and tested with values built by hand.
public struct SubscriptionOffer: Hashable, Sendable {

    // MARK: Nested types

    /// What kind of offer this is.
    ///
    /// A raw-value struct rather than an enum, the same pattern StoreKit uses: when Apple adds
    /// a kind, it arrives as a value with an unfamiliar ``rawValue`` instead of breaking every
    /// exhaustive `switch` in client code.
    ///
    /// Shared with ``StoreTransaction/Offer``. StoreKit encodes the kind differently on
    /// products (strings) and on transactions (integers), so the raw values here are the
    /// kit's own names rather than either of StoreKit's.
    public struct OfferType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Offered to customers who have not subscribed in the group before.
        public static let introductory = OfferType(rawValue: "introductory")
        /// Offered by the app to chosen customers, signed by your server.
        public static let promotional = OfferType(rawValue: "promotional")
        /// Offered to lapsed subscribers to bring them back.
        public static let winBack = OfferType(rawValue: "winBack")
        /// Redeemed with an offer code. Seen only on transactions; a product never lists one.
        public static let code = OfferType(rawValue: "code")
    }

    /// How the customer pays during the offer.
    ///
    /// A raw-value struct for the same reason as ``OfferType``, and with the kit's own raw
    /// values for the same reason: StoreKit spells them differently on products and
    /// transactions.
    public struct PaymentMode: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Nothing is charged for the offer's duration.
        public static let freeTrial = PaymentMode(rawValue: "freeTrial")
        /// The discounted price is charged every period, ``SubscriptionOffer/periodCount`` times.
        public static let payAsYouGo = PaymentMode(rawValue: "payAsYouGo")
        /// The discounted price is charged once for the whole offer.
        public static let payUpFront = PaymentMode(rawValue: "payUpFront")
    }

    // MARK: Properties
    /// The offer identifier from App Store Connect. `nil` for an introductory offer, which
    /// has none.
    public let id: String?
    /// What kind of offer this is.
    public let type: OfferType
    /// How the customer pays during the offer.
    public let paymentMode: PaymentMode
    /// The offer price per period, in the product's ``StoreProduct/currencyCode``.
    public let price: Decimal
    /// The offer price formatted for display (e.g. `"$0.99"`).
    public let displayPrice: String
    /// The length of one offer period.
    public let period: StoreSubscriptionPeriod
    /// How many ``period``s the offer lasts.
    public let periodCount: Int

    // MARK: Initial methods

    /// Creates an offer that is not backed by StoreKit, for tests, previews and mocks.
    public init(
        id: String?,
        type: OfferType,
        paymentMode: PaymentMode,
        price: Decimal,
        displayPrice: String,
        period: StoreSubscriptionPeriod,
        periodCount: Int
    ) {
        self.id = id
        self.type = type
        self.paymentMode = paymentMode
        self.price = price
        self.displayPrice = displayPrice
        self.period = period
        self.periodCount = periodCount
    }

    /// Reads a StoreKit offer. `nil` only when its period uses a unit this build does not know,
    /// since an offer whose length cannot be stated cannot be presented honestly.
    init?(_ offer: Product.SubscriptionOffer) {
        guard let period = StoreSubscriptionPeriod(offer.period) else {
            return nil
        }

        self.init(
            id: offer.id,
            type: OfferType(productRawValue: offer.type.rawValue),
            paymentMode: PaymentMode(productRawValue: offer.paymentMode.rawValue),
            price: offer.price,
            displayPrice: offer.displayPrice,
            period: period,
            periodCount: offer.periodCount
        )
    }
}

// MARK: - StoreKit raw values

// The mappings take StoreKit's raw values, not its types, so they can be tested with values
// StoreKit has not shipped yet. The literals were read from StoreKit at runtime; a test
// compares them against the StoreKit constants so a change on Apple's side is caught.

extension SubscriptionOffer.OfferType {
    /// Maps `Product.SubscriptionOffer.OfferType.rawValue`. An unknown value is kept as is.
    init(productRawValue: String) {
        switch productRawValue {
        case "IntroOffer":
            self = .introductory
        case "AdhocOffer":
            self = .promotional
        case "Winback":
            self = .winBack
        default:
            self.init(rawValue: productRawValue)
        }
    }

    /// Maps `Transaction.OfferType.rawValue`. An unknown value is kept as its decimal string.
    init(transactionRawValue: Int) {
        switch transactionRawValue {
        case 1:
            self = .introductory
        case 2:
            self = .promotional
        case 3:
            self = .code
        case 4:
            self = .winBack
        default:
            self.init(rawValue: String(transactionRawValue))
        }
    }
}

extension SubscriptionOffer.PaymentMode {
    /// Maps `Product.SubscriptionOffer.PaymentMode.rawValue`. An unknown value is kept as is.
    init(productRawValue: String) {
        switch productRawValue {
        case "FreeTrial":
            self = .freeTrial
        case "PayAsYouGo":
            self = .payAsYouGo
        case "PayUpFront":
            self = .payUpFront
        default:
            self.init(rawValue: productRawValue)
        }
    }

    /// Maps `Transaction.Offer.PaymentMode.rawValue`. An unknown value is kept as is.
    init(transactionRawValue: String) {
        switch transactionRawValue {
        case "FREE_TRIAL":
            self = .freeTrial
        case "PAY_AS_YOU_GO":
            self = .payAsYouGo
        case "PAY_UP_FRONT":
            self = .payUpFront
        default:
            self.init(rawValue: transactionRawValue)
        }
    }
}
