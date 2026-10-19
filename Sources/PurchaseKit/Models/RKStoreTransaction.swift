//
//  RKStoreTransaction.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

public import Foundation
public import StoreKit

/// Immutable value describing a completed `StoreKit` transaction.
///
/// The kit builds these from `StoreKit.Transaction`. You can also build one directly, which
/// `StoreKit.Transaction` does not allow — it has no public initializer — and that is what
/// makes ``PurchasesProtocol`` mockable: a stand-in can return a successful purchase instead
/// of only being able to throw.
public struct StoreTransaction: Sendable {

    // MARK: Nested types
    //
    // Every kind below is a raw-value struct rather than an enum, the same pattern StoreKit
    // uses: a value Apple adds later arrives with an unfamiliar `rawValue` instead of breaking
    // an exhaustive `switch` in client code. Where StoreKit's raw values are unambiguous they
    // are reused verbatim, so an unknown value reads exactly as StoreKit reported it.

    /// How the customer came to own the product.
    public struct OwnershipType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// The customer bought it.
        public static let purchased = OwnershipType(rawValue: "PURCHASED")
        /// A family member bought it and shares it through Family Sharing.
        public static let familyShared = OwnershipType(rawValue: "FAMILY_SHARED")
    }

    /// Why the transaction happened.
    public struct Reason: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// The customer bought the product, or upgraded or crossgraded a subscription.
        public static let purchase = Reason(rawValue: "PURCHASE")
        /// An auto-renewable subscription renewed on its own.
        public static let renewal = Reason(rawValue: "RENEWAL")
    }

    /// The offer a subscription transaction was bought with.
    public struct Offer: Hashable, Sendable {
        /// The offer identifier. `nil` for an introductory offer.
        public let id: String?
        /// What kind of offer it was.
        public let type: SubscriptionOffer.OfferType
        /// How the customer paid. `nil` when StoreKit does not report one.
        public let paymentMode: SubscriptionOffer.PaymentMode?

        public init(
            id: String?,
            type: SubscriptionOffer.OfferType,
            paymentMode: SubscriptionOffer.PaymentMode?
        ) {
            self.id = id
            self.type = type
            self.paymentMode = paymentMode
        }
    }

    /// Why the App Store revoked the transaction.
    ///
    /// The raw values are StoreKit's integers.
    public struct RevocationReason: RawRepresentable, Hashable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Refunded because of a problem with the app, such as content that did not work.
        /// Worth looking into: it points at a bug on your side.
        public static let developerIssue = RevocationReason(rawValue: 1)
        /// Refunded or revoked for any other reason.
        public static let other = RevocationReason(rawValue: 0)
    }

    /// What kind of revocation removed the entitlement.
    ///
    /// Reported by StoreKit from OS 26.4; always `nil` on earlier systems.
    public struct RevocationType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// The whole purchase was refunded.
        public static let fullRefund = RevocationType(rawValue: "REFUND_FULL")
        /// Part of the purchase was refunded, pro rata.
        public static let proratedRefund = RevocationType(rawValue: "REFUND_PRORATED")
        /// The family member who shared the product stopped sharing it.
        public static let familyRevocation = RevocationType(rawValue: "FAMILY_REVOKE")
        /// An assigned license was withdrawn.
        ///
        /// StoreKit's own constant exists only in the OS 27 SDKs, so the value is spelled out.
        public static let assignmentRevocation = RevocationType(rawValue: "ASSIGNMENT_REVOKE")
    }

    /// How a subscription with a commitment is billed.
    ///
    /// Reported by StoreKit from OS 26.4; always `nil` on earlier systems and for ordinary
    /// subscriptions.
    public struct BillingPlanType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// The commitment is billed in monthly instalments.
        public static let monthly = BillingPlanType(rawValue: "MONTHLY")
        /// The commitment is billed in full at the start.
        public static let upFront = BillingPlanType(rawValue: "BILLED_UPFRONT")
    }

    // MARK: Properties
    /// The raw StoreKit transaction this value was read from.
    ///
    /// `nil` for a value you construct yourself, so treat it as absent rather than force
    /// unwrapping it. Reach for it when you need something this type does not surface.
    public let transaction: Transaction?
    /// Identifier of this transaction.
    public let id: UInt64
    /// Identifier of the original transaction for the product or subscription.
    public let originalID: UInt64
    /// The product this transaction is for.
    public let productID: String
    /// When the App Store charged the account.
    public let purchaseDate: Date
    /// When the original transaction for this product occurred.
    public let originalPurchaseDate: Date
    /// When an auto-renewable subscription expires. `nil` for other product types.
    public let expirationDate: Date?
    /// When the App Store refunded or revoked the transaction, if it did.
    ///
    /// A non-`nil` value means the entitlement is gone: a refund, a family-sharing grant
    /// withdrawn, or a revocation by App Store support.
    public let revocationDate: Date?
    /// Whether the subscription was upgraded and this transaction superseded.
    public let isUpgraded: Bool
    /// How many consumable units this transaction covers.
    public let purchasedQuantity: Int
    /// The token your app supplied to associate the purchase with an account.
    public let appAccountToken: UUID?
    /// Subscription group of an auto-renewable subscription. `nil` for other product types.
    public let subscriptionGroupID: String?
    /// The transaction as the App Store signed it: a JWS your server can verify with the App
    /// Store Server Library before it grants anything.
    ///
    /// Send this, not the decoded fields: the fields above are what the device read, and a
    /// server that trusts them trusts the device. `nil` for a value you construct yourself
    /// unless you pass one.
    public let jwsRepresentation: String?
    /// The type of the product this transaction is for.
    ///
    /// Carried on the transaction so code handling ``PurchasesManager/transactionUpdates``
    /// can tell a consumable from a subscription without fetching the product.
    public let productType: ProductType
    /// Whether the customer bought the product or has it through Family Sharing.
    public let ownershipType: OwnershipType
    /// The App Store environment that signed the transaction.
    public let environment: StoreEnvironment
    /// Whether this is a purchase or an automatic renewal.
    public let reason: Reason
    /// The subscription offer the transaction was bought with, if any.
    public let offer: Offer?
    /// Why the transaction was revoked. `nil` unless ``revocationDate`` is set.
    public let revocationReason: RevocationReason?
    /// What kind of revocation removed the entitlement. `nil` before OS 26.4.
    public let revocationType: RevocationType?
    /// How a subscription with a commitment is billed. `nil` before OS 26.4.
    public let billingPlanType: BillingPlanType?
    /// The three-letter ISO 3166-1 code of the storefront the purchase was made in
    /// (e.g. `"USA"`). Empty for a value you construct without one.
    public let storefrontCountryCode: String
    /// What the customer paid, in ``currencyCode``. `nil` when StoreKit does not report it.
    public let price: Decimal?
    /// ISO 4217 code of the currency ``price`` is in.
    public let currencyCode: String?

    /// Whether the entitlement comes from a family member's purchase.
    ///
    /// A family-shared entitlement can disappear without the customer doing anything, and
    /// a refund or a cancellation is not theirs to make, so UI often has to word it apart.
    public var isFamilyShared: Bool {
        ownershipType == .familyShared
    }

    // MARK: Initial methods

    /// Designated initializer. You don't create `StoreTransaction` this way in apps —
    /// it is produced by the kit from `StoreKit.Transaction`.
    init(transaction: Transaction, jwsRepresentation: String? = nil) {
        self.transaction = transaction
        self.jwsRepresentation = jwsRepresentation
        id = transaction.id
        originalID = transaction.originalID
        productID = transaction.productID
        purchaseDate = transaction.purchaseDate
        originalPurchaseDate = transaction.originalPurchaseDate
        expirationDate = transaction.expirationDate
        revocationDate = transaction.revocationDate
        isUpgraded = transaction.isUpgraded
        purchasedQuantity = transaction.purchasedQuantity
        appAccountToken = transaction.appAccountToken
        subscriptionGroupID = transaction.subscriptionGroupID
        productType = ProductType(transaction.productType)
        ownershipType = OwnershipType(rawValue: transaction.ownershipType.rawValue)
        environment = StoreEnvironment(transaction.environment)
        reason = Reason(rawValue: transaction.reason.rawValue)
        offer = transaction.offer.map { offer in
            Offer(
                id: offer.id,
                type: SubscriptionOffer.OfferType(transactionRawValue: offer.type.rawValue),
                paymentMode: offer.paymentMode.map { SubscriptionOffer.PaymentMode(transactionRawValue: $0.rawValue) }
            )
        }
        revocationReason = transaction.revocationReason.map { RevocationReason(rawValue: $0.rawValue) }
        // Both properties are new in 26.4 while the deployment target is 26.0. Earlier systems
        // do not report them, so `nil` is the truth there, not a lossy fallback.
        if #available(iOS 26.4, macOS 26.4, tvOS 26.4, watchOS 26.4, visionOS 26.4, *) {
            revocationType = transaction.revocationType.map { RevocationType(rawValue: $0.rawValue) }
            billingPlanType = transaction.billingPlanType.map { BillingPlanType(rawValue: $0.rawValue) }
        } else {
            revocationType = nil
            billingPlanType = nil
        }
        storefrontCountryCode = transaction.storefront.countryCode
        price = transaction.price
        currencyCode = transaction.currency?.identifier
    }
    /// Creates a value that is not backed by StoreKit.
    ///
    /// Use this in tests, previews and mock implementations of ``PurchasesProtocol``.
    /// ``transaction`` is `nil` on the result.
    ///
    /// `productType` is required: a transaction is always for some kind of product, and any
    /// default would be a guess that code under test could silently branch on.
    public init(
        id: UInt64,
        productID: String,
        productType: ProductType,
        purchaseDate: Date,
        originalID: UInt64? = nil,
        originalPurchaseDate: Date? = nil,
        expirationDate: Date? = nil,
        revocationDate: Date? = nil,
        isUpgraded: Bool = false,
        purchasedQuantity: Int = 1,
        appAccountToken: UUID? = nil,
        subscriptionGroupID: String? = nil,
        jwsRepresentation: String? = nil,
        ownershipType: OwnershipType = .purchased,
        environment: StoreEnvironment = .production,
        reason: Reason = .purchase,
        offer: Offer? = nil,
        revocationReason: RevocationReason? = nil,
        revocationType: RevocationType? = nil,
        billingPlanType: BillingPlanType? = nil,
        storefrontCountryCode: String = "",
        price: Decimal? = nil,
        currencyCode: String? = nil
    ) {
        transaction = nil
        self.jwsRepresentation = jwsRepresentation
        self.id = id
        self.originalID = originalID ?? id
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.originalPurchaseDate = originalPurchaseDate ?? purchaseDate
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
        self.isUpgraded = isUpgraded
        self.purchasedQuantity = purchasedQuantity
        self.appAccountToken = appAccountToken
        self.subscriptionGroupID = subscriptionGroupID
        self.productType = productType
        self.ownershipType = ownershipType
        self.environment = environment
        self.reason = reason
        self.offer = offer
        self.revocationReason = revocationReason
        self.revocationType = revocationType
        self.billingPlanType = billingPlanType
        self.storefrontCountryCode = storefrontCountryCode
        self.price = price
        self.currencyCode = currencyCode
    }
}
