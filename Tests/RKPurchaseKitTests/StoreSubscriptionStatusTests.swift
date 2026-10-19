//
//  SubscriptionStatusTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 19.10.2026.
//

import Foundation
import StoreKit
import Testing
@testable import RKPurchaseKit

/// Covers ``StoreSubscriptionStatus``: the values a mock can build, what counts as access, and how
/// one status is chosen to stand for a whole group.
@Suite("StoreSubscriptionStatus", .timeLimit(.minutes(1)))
struct SubscriptionStatusTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeStatus(
        _ state: StoreSubscriptionStatus.State,
        id: UInt64 = 1,
        expiresIn interval: TimeInterval? = 86_400
    ) -> StoreSubscriptionStatus {
        StoreSubscriptionStatus(
            state: state,
            groupID: "group.pro",
            transaction: StoreTransaction(
                id: id,
                productID: "pro.monthly",
                productType: .autoRenewable,
                purchaseDate: now,
                expirationDate: interval.map { now.addingTimeInterval($0) },
                subscriptionGroupID: "group.pro"
            )
        )
    }

    @Test("can be constructed without StoreKit")
    func buildsWithoutStoreKit() {
        let renewal = now.addingTimeInterval(86_400)
        let grace = now.addingTimeInterval(3_600)

        let status = StoreSubscriptionStatus(
            state: .inGracePeriod,
            groupID: "group.pro",
            transaction: StoreTransaction(id: 9, productID: "pro.monthly", productType: .autoRenewable, purchaseDate: now),
            willAutoRenew: true,
            autoRenewProductID: "pro.yearly",
            renewalDate: renewal,
            gracePeriodExpirationDate: grace,
            isInBillingRetry: true,
            expirationReason: .billingError,
            renewalInfoJWS: "renewal.jws"
        )

        #expect(status.state == .inGracePeriod)
        #expect(status.groupID == "group.pro")
        #expect(status.transaction.id == 9)
        #expect(status.willAutoRenew)
        #expect(status.autoRenewProductID == "pro.yearly")
        #expect(status.renewalDate == renewal)
        #expect(status.gracePeriodExpirationDate == grace)
        #expect(status.isInBillingRetry)
        #expect(status.expirationReason == .billingError)
        #expect(status.renewalInfoJWS == "renewal.jws")
    }

    @Test("renewal details default to absent")
    func appliesDefaults() {
        let status = makeStatus(.subscribed)

        #expect(!status.willAutoRenew)
        #expect(status.autoRenewProductID == nil)
        #expect(status.renewalDate == nil)
        #expect(status.gracePeriodExpirationDate == nil)
        #expect(!status.isInBillingRetry)
        #expect(status.expirationReason == nil)
        #expect(status.renewalInfoJWS == nil)
    }

    /// The grace period exists so the customer keeps access while the charge is retried;
    /// billing retry without one does not grant access.
    @Test(
        "only subscribed and grace period grant access",
        arguments: [
            (StoreSubscriptionStatus.State.subscribed, true),
            (.inGracePeriod, true),
            (.inBillingRetryPeriod, false),
            (.expired, false),
            (.revoked, false),
            (StoreSubscriptionStatus.State(rawValue: 99), false)
        ]
    )
    func reportsAccess(state: StoreSubscriptionStatus.State, expected: Bool) {
        #expect(makeStatus(state).isActive == expected)
    }

    // MARK: StoreKit raw values

    @Test("states and expiration reasons match StoreKit's raw values")
    func matchesStoreKitRawValues() {
        typealias RenewalState = Product.SubscriptionInfo.RenewalState
        typealias Reason = Product.SubscriptionInfo.RenewalInfo.ExpirationReason

        #expect(StoreSubscriptionStatus.State.subscribed.rawValue == RenewalState.subscribed.rawValue)
        #expect(StoreSubscriptionStatus.State.expired.rawValue == RenewalState.expired.rawValue)
        #expect(StoreSubscriptionStatus.State.inBillingRetryPeriod.rawValue == RenewalState.inBillingRetryPeriod.rawValue)
        #expect(StoreSubscriptionStatus.State.inGracePeriod.rawValue == RenewalState.inGracePeriod.rawValue)
        #expect(StoreSubscriptionStatus.State.revoked.rawValue == RenewalState.revoked.rawValue)
        #expect(StoreSubscriptionStatus.ExpirationReason.autoRenewDisabled.rawValue == Reason.autoRenewDisabled.rawValue)
        #expect(StoreSubscriptionStatus.ExpirationReason.billingError.rawValue == Reason.billingError.rawValue)
        #expect(
            StoreSubscriptionStatus.ExpirationReason.didNotConsentToPriceIncrease.rawValue
                == Reason.didNotConsentToPriceIncrease.rawValue
        )
        #expect(StoreSubscriptionStatus.ExpirationReason.productUnavailable.rawValue == Reason.productUnavailable.rawValue)
    }

    // MARK: best(of:)

    @Test("no statuses means no best status")
    func bestOfNothing() {
        #expect(StoreSubscriptionStatus.best(of: []) == nil)
    }

    /// Shuffled input pins down that the order StoreKit happens to return does not matter.
    @Test("the status granting the most access wins")
    func prefersMostAccess() {
        let ranked: [StoreSubscriptionStatus.State] = [.subscribed, .inGracePeriod, .inBillingRetryPeriod, .expired, .revoked]

        for (index, expected) in ranked.enumerated() {
            let candidates = ranked[index...].enumerated().map { offset, state in
                makeStatus(state, id: UInt64(offset + 1))
            }

            #expect(StoreSubscriptionStatus.best(of: candidates.shuffled())?.state == expected)
        }
    }

    @Test("a tie goes to the later expiration")
    func breaksTiesByExpiration() {
        let earlier = makeStatus(.subscribed, id: 1, expiresIn: 3_600)
        let later = makeStatus(.subscribed, id: 2, expiresIn: 86_400)
        let undated = makeStatus(.subscribed, id: 3, expiresIn: nil)

        #expect(StoreSubscriptionStatus.best(of: [earlier, later, undated])?.transaction.id == 2)
        #expect(StoreSubscriptionStatus.best(of: [undated, later, earlier])?.transaction.id == 2)
    }

    /// A later expiration must not lift a status above one that grants more access.
    @Test("access outranks expiration")
    func ranksAccessAboveExpiration() {
        let expiredLate = makeStatus(.expired, id: 1, expiresIn: 1_000_000)
        let subscribedSoon = makeStatus(.subscribed, id: 2, expiresIn: 60)

        #expect(StoreSubscriptionStatus.best(of: [expiredLate, subscribedSoon])?.transaction.id == 2)
    }

    /// A state this build does not know cannot be interpreted, so it must not displace one
    /// that can.
    @Test("an unknown state ranks below every known one")
    func ranksUnknownStateLast() {
        let unknown = makeStatus(StoreSubscriptionStatus.State(rawValue: 99), id: 1)
        let revoked = makeStatus(.revoked, id: 2)

        #expect(StoreSubscriptionStatus.best(of: [unknown, revoked])?.transaction.id == 2)
    }
}
