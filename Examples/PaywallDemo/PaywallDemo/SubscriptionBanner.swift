//
//  SubscriptionBanner.swift
//  PaywallDemo
//

import Foundation
import RKPurchaseKit

/// What the paywall tells the customer about their subscription, decided from one
/// `StoreSubscriptionStatus`.
///
/// This is the heart of the demo. A paywall that only asks "is the customer entitled?" sees
/// two worlds: paying and not paying. The App Store reports five, and each one deserves a
/// different screen:
///
/// | State                  | Access | What to say                                            |
/// |------------------------|--------|--------------------------------------------------------|
/// | subscribed             | yes    | Nothing to sell. Show when it renews.                  |
/// | in grace period        | yes    | Payment failed. Fix it by a date, access is kept.      |
/// | in billing retry       | no     | Payment failed. Access is paused, the plan can recover.|
/// | expired                | no     | Depends on *why*: cancelled, card declined, price rise.|
/// | revoked                | no     | Refunded or removed from Family Sharing.               |
///
/// Keeping the decision in a plain value type, away from the view, makes it easy to read,
/// to preview and to unit test.
struct SubscriptionBanner: Equatable {
    enum Tone: Equatable {
        /// Everything is fine.
        case positive
        /// Access is kept, but the customer needs to act.
        case warning
        /// Access is gone.
        case critical
        /// Access is gone and the customer is someone to win back.
        case invitation
    }

    enum Action: Equatable {
        /// Open Apple's subscription settings, where a payment method can be fixed.
        case manageSubscription
        /// Sell the plan again with the given win-back offer.
        case winBack(offerID: String)
        /// Sell the plan again with a promotional offer your server signs.
        case promotionalOffer(offerID: String)
        /// Plain resubscribe: scroll to the plans.
        case resubscribe
    }

    var symbol: String
    var title: String
    var message: String
    var tone: Tone
    var action: Action?
    var actionTitle: String?

    /// The subscription still exists and only needs a working payment method: grace period
    /// and billing retry. Selling a new plan to this customer is the classic mistake, so the
    /// paywall swaps its purchase button for the banner's action.
    var isRecoverable = false
}

extension SubscriptionBanner {
    /// The banner for a status, or `nil` for a customer who has never subscribed.
    ///
    /// - Parameters:
    ///   - status: The group's most relevant status, from `subscriptionStatus(inGroup:)` or
    ///     `subscriptionStatusUpdates`.
    ///   - plan: The product the status belongs to, used for its win-back and promotional
    ///     offers. StoreKit lists a win-back offer only while this customer may redeem it.
    init?(status: StoreSubscriptionStatus?, plan: StoreProduct?) {
        guard let status else { return nil }
        let planName = plan?.displayName ?? "Premium"

        switch status.state {
        case .subscribed:
            let date = status.renewalDate ?? status.transaction.expirationDate
            if status.willAutoRenew {
                self.init(
                    symbol: "checkmark.seal.fill",
                    title: "\(planName) is active",
                    message: date.map { "Renews on \($0.formatted(date: .long, time: .omitted))." }
                        ?? "Thanks for subscribing.",
                    tone: .positive
                )
            } else {
                // Still paid up, but the customer turned off renewal. A gentle nudge now is
                // cheaper than a win-back campaign later.
                self.init(
                    symbol: "calendar.badge.exclamationmark",
                    title: "\(planName) ends soon",
                    message: date.map { "Auto-renew is off. Access ends on \($0.formatted(date: .long, time: .omitted))." }
                        ?? "Auto-renew is off.",
                    tone: .positive,
                    action: .manageSubscription,
                    actionTitle: "Keep Premium"
                )
            }

        case .inGracePeriod:
            // The renewal charge failed, but you enabled Billing Grace Period, so the App Store
            // keeps the customer subscribed while it retries. Do not lock anything. Do ask them
            // to fix the card, and say by when.
            let deadline = status.gracePeriodExpirationDate
                .map { " by \($0.formatted(date: .long, time: .omitted))" } ?? ""
            self.init(
                symbol: "creditcard.trianglebadge.exclamationmark",
                title: "Payment issue",
                message: "We couldn't renew your subscription. Update your payment method\(deadline) to keep Premium. Your access is unchanged until then.",
                tone: .warning,
                action: .manageSubscription,
                actionTitle: "Update Payment Method",
                isRecoverable: true
            )

        case .inBillingRetryPeriod:
            // The grace period is over (or was never enabled). Access is paused, but the
            // subscription is not gone: the App Store keeps retrying for up to 60 days, and
            // a fixed payment method resumes it without a new purchase. Selling a new plan
            // here would be wrong; sending the customer to their payment settings is right.
            self.init(
                symbol: "pause.circle.fill",
                title: "Premium is paused",
                message: "Your last payment didn't go through, so Premium is paused. Update your payment method and it resumes right away. No need to subscribe again.",
                tone: .critical,
                action: .manageSubscription,
                actionTitle: "Update Payment Method",
                isRecoverable: true
            )

        case .expired:
            self.init(expiredBecause: status.expirationReason, plan: plan, planName: planName)

        case .revoked:
            // The App Store refunded the purchase, or a family organizer stopped sharing it.
            // Access must go, and there is nothing to fix: just make resubscribing easy.
            let date = status.transaction.revocationDate
                .map { " on \($0.formatted(date: .long, time: .omitted))" } ?? ""
            self.init(
                symbol: "xmark.seal.fill",
                title: "Access removed",
                message: "Your \(planName) purchase was refunded\(date), so its features are no longer available.",
                tone: .critical,
                action: .resubscribe,
                actionTitle: "See Plans"
            )

        default:
            // `State` is an extensible struct: a future StoreKit release can add a state this
            // app predates. Fall back to the rule the App Store gives us.
            self.init(
                symbol: status.isActive ? "checkmark.seal.fill" : "questionmark.circle",
                title: status.isActive ? "\(planName) is active" : "Subscription inactive",
                message: "Status code \(status.state.rawValue).",
                tone: status.isActive ? .positive : .critical
            )
        }
    }

    /// An expired subscription is several different customers. The reason decides the pitch.
    private init(
        expiredBecause reason: StoreSubscriptionStatus.ExpirationReason?,
        plan: StoreProduct?,
        planName: String
    ) {
        switch reason {
        case .autoRenewDisabled?:
            // They chose to leave. This is the audience win-back offers were made for, and
            // StoreKit only lists a win-back offer while this customer is eligible for it.
            if let offer = plan?.winBackOffers.first, let offerID = offer.id, let plan {
                self.init(
                    symbol: "gift.fill",
                    title: "We'd love to have you back",
                    message: "Come back to \(planName): \(OfferText.describe(offer, then: plan)).",
                    tone: .invitation,
                    action: .winBack(offerID: offerID),
                    actionTitle: "Redeem Offer"
                )
            } else {
                self.init(
                    symbol: "hand.wave.fill",
                    title: "We'd love to have you back",
                    message: "Your \(planName) subscription has ended. Pick a plan below to pick up where you left off.",
                    tone: .invitation,
                    action: .resubscribe,
                    actionTitle: "See Plans"
                )
            }

        case .billingError?:
            // They never meant to leave: the App Store gave up on a failing card. Do not
            // pitch them like a churned customer. Say what happened, and make the way back
            // cheap, here with a promotional offer your server signs.
            if let offer = plan?.promotionalOffers.first, let offerID = offer.id, let plan {
                self.init(
                    symbol: "creditcard.fill",
                    title: "Your payment didn't go through",
                    message: "Premium ended because the App Store couldn't charge your payment method. Resubscribe and get \(OfferText.describe(offer, then: plan)).",
                    tone: .critical,
                    action: .promotionalOffer(offerID: offerID),
                    actionTitle: "Resubscribe"
                )
            } else {
                self.init(
                    symbol: "creditcard.fill",
                    title: "Your payment didn't go through",
                    message: "Premium ended because the App Store couldn't charge your payment method. Update it and resubscribe to continue.",
                    tone: .critical,
                    action: .resubscribe,
                    actionTitle: "See Plans"
                )
            }

        case .didNotConsentToPriceIncrease?:
            self.init(
                symbol: "tag.fill",
                title: "Premium has ended",
                message: "Your subscription ended because the new price wasn't accepted. You can resubscribe at the current price at any time.",
                tone: .invitation,
                action: .resubscribe,
                actionTitle: "See Plans"
            )

        default:
            self.init(
                symbol: "clock.badge.xmark",
                title: "Premium has ended",
                message: "Your \(planName) subscription has expired.",
                tone: .invitation,
                action: .resubscribe,
                actionTitle: "See Plans"
            )
        }
    }
}
