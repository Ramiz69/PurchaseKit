//
//  RKStoreSubscriptionStatus.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 19.10.2026.
//

public import Foundation
import StoreKit

/// The renewal state of one subscription in a group, with what it will do next.
///
/// An entitlement only says "has access right now". A status also says why access ended
/// (billing failure, cancellation, refund), whether it is about to end, and what it renews
/// into — what a paywall, a "your payment failed" banner, or a win-back screen needs.
///
/// Mirrors `Product.SubscriptionInfo.Status`, which cannot be built outside StoreKit.
public struct StoreSubscriptionStatus: Sendable {

    // MARK: Nested types

    /// Where the subscription is in its lifecycle.
    ///
    /// A raw-value struct, the same pattern StoreKit uses, so a state Apple adds later does
    /// not break an exhaustive `switch`. The raw values are StoreKit's integers.
    public struct State: RawRepresentable, Hashable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Active and paid up.
        public static let subscribed = State(rawValue: 1)
        /// Ended: cancelled, or billing retry gave up.
        public static let expired = State(rawValue: 2)
        /// Renewal failed and the App Store is retrying the charge. Access is gone unless a
        /// grace period is configured.
        public static let inBillingRetryPeriod = State(rawValue: 3)
        /// Renewal failed but access continues while the App Store retries the charge.
        public static let inGracePeriod = State(rawValue: 4)
        /// Refunded or revoked by the App Store, or withdrawn by Family Sharing.
        public static let revoked = State(rawValue: 5)
    }

    /// Why a subscription expired or will expire.
    ///
    /// A raw-value struct for the same reason as ``State``; the raw values are StoreKit's
    /// integers.
    public struct ExpirationReason: RawRepresentable, Hashable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// The customer turned auto-renew off.
        public static let autoRenewDisabled = ExpirationReason(rawValue: 1)
        /// The renewal could not be charged.
        public static let billingError = ExpirationReason(rawValue: 2)
        /// The customer did not agree to a price increase.
        public static let didNotConsentToPriceIncrease = ExpirationReason(rawValue: 3)
        /// The product was no longer for sale at renewal time.
        public static let productUnavailable = ExpirationReason(rawValue: 4)
    }

    // MARK: Properties
    /// Where the subscription is in its lifecycle.
    public let state: State
    /// The subscription group this status belongs to.
    public let groupID: String
    /// The latest transaction of the subscription.
    public let transaction: StoreTransaction
    /// Whether the subscription is set to renew at the end of the current period.
    ///
    /// `false` while renewal information is missing or failed verification: claiming a
    /// renewal that cannot be confirmed would hide a cancellation.
    public let willAutoRenew: Bool
    /// The product the subscription renews into, which differs from
    /// ``StoreTransaction/productID`` after a scheduled upgrade or downgrade.
    public let autoRenewProductID: String?
    /// When the next renewal is due.
    public let renewalDate: Date?
    /// When the billing grace period ends, if the subscription is in one.
    public let gracePeriodExpirationDate: Date?
    /// Whether the App Store is still trying to charge a failed renewal.
    public let isInBillingRetry: Bool
    /// Why the subscription expired or will expire, if it did or will.
    public let expirationReason: ExpirationReason?
    /// The renewal information as the App Store signed it, for your server to verify.
    ///
    /// `nil` when it failed verification on the device, for the same reason the decoded
    /// renewal fields are then empty.
    public let renewalInfoJWS: String?

    /// Whether the customer should have access right now.
    ///
    /// A grace period is active on purpose: the App Store keeps access open while it retries
    /// the charge, and cutting the customer off would undo that.
    public var isActive: Bool {
        state == .subscribed || state == .inGracePeriod
    }

    // MARK: Initial methods

    /// Creates a value that is not backed by StoreKit, for tests, previews and mock
    /// implementations of ``PurchasesProtocol``.
    public init(
        state: State,
        groupID: String,
        transaction: StoreTransaction,
        willAutoRenew: Bool = false,
        autoRenewProductID: String? = nil,
        renewalDate: Date? = nil,
        gracePeriodExpirationDate: Date? = nil,
        isInBillingRetry: Bool = false,
        expirationReason: ExpirationReason? = nil,
        renewalInfoJWS: String? = nil
    ) {
        self.state = state
        self.groupID = groupID
        self.transaction = transaction
        self.willAutoRenew = willAutoRenew
        self.autoRenewProductID = autoRenewProductID
        self.renewalDate = renewalDate
        self.gracePeriodExpirationDate = gracePeriodExpirationDate
        self.isInBillingRetry = isInBillingRetry
        self.expirationReason = expirationReason
        self.renewalInfoJWS = renewalInfoJWS
    }

    /// Reads a StoreKit status.
    ///
    /// Returns `nil` when the transaction fails verification: a status is a claim about
    /// access, and one built on an unverified transaction is a claim nobody signed. Renewal
    /// information is checked separately and, when unverified, contributes nothing rather
    /// than discarding an otherwise valid status.
    init?(_ status: Product.SubscriptionInfo.Status) {
        guard case .verified(let transaction) = status.transaction else {
            return nil
        }

        let renewalInfo: Product.SubscriptionInfo.RenewalInfo?
        if case .verified(let info) = status.renewalInfo {
            renewalInfo = info
        } else {
            renewalInfo = nil
        }

        self.init(
            state: State(rawValue: status.state.rawValue),
            // A status always belongs to an auto-renewable subscription, which always has a
            // group; the empty fallback only keeps the initializer total.
            groupID: transaction.subscriptionGroupID ?? "",
            transaction: StoreTransaction(transaction: transaction, jwsRepresentation: status.transaction.jwsRepresentation),
            willAutoRenew: renewalInfo?.willAutoRenew ?? false,
            autoRenewProductID: renewalInfo?.autoRenewPreference,
            renewalDate: renewalInfo?.renewalDate,
            gracePeriodExpirationDate: renewalInfo?.gracePeriodExpirationDate,
            isInBillingRetry: renewalInfo?.isInBillingRetry ?? false,
            expirationReason: renewalInfo?.expirationReason.map { ExpirationReason(rawValue: $0.rawValue) },
            renewalInfoJWS: renewalInfo == nil ? nil : status.renewalInfo.jwsRepresentation
        )
    }

    // MARK: Internal methods

    /// Picks the status that best describes the customer's access to a group.
    ///
    /// StoreKit returns one status per subscription in the group, and with Family Sharing or
    /// a plan change there can be several. The one that grants the most access wins:
    /// subscribed, then grace period, then billing retry, then expired, then revoked. Ties go
    /// to the later expiration date, the more current of two otherwise equal subscriptions.
    static func best(of statuses: [StoreSubscriptionStatus]) -> StoreSubscriptionStatus? {
        statuses.max { lhs, rhs in
            let lhsRank = lhs.accessRank
            let rhsRank = rhs.accessRank
            guard lhsRank == rhsRank else {
                return lhsRank < rhsRank
            }

            return (lhs.transaction.expirationDate ?? .distantPast) < (rhs.transaction.expirationDate ?? .distantPast)
        }
    }

    /// Higher means more access. An unknown state ranks below everything known, so a value
    /// this build cannot interpret never displaces one it can.
    private var accessRank: Int {
        switch state {
        case .subscribed: 5
        case .inGracePeriod: 4
        case .inBillingRetryPeriod: 3
        case .expired: 2
        case .revoked: 1
        default: 0
        }
    }
}
