//
//  OfferText.swift
//  PaywallDemo
//

import Foundation
import RKPurchaseKit

/// Turns `StoreSubscriptionPeriod` and `SubscriptionOffer` into the sentences a paywall shows.
///
/// App Review expects the price after an offer to be as clear as the offer itself, so every
/// phrase here ends with what the customer pays afterwards: "3 days free, then $39.99/year".
///
/// A shipping app would localize these through a String Catalog with plural rules. They are
/// spelled out in English here so the logic stays visible.
enum OfferText {
    /// "month", "year", "3 months".
    static func period(_ period: StoreSubscriptionPeriod) -> String {
        duration(period.value, period.unit, singularDropsCount: true)
    }

    /// "$4.99/month", "$39.99/year", "$9.99 every 3 months".
    static func price(of product: StoreProduct) -> String {
        guard let period = product.subscriptionPeriod else { return product.displayPrice }
        return period.value == 1
            ? "\(product.displayPrice)/\(self.period(period))"
            : "\(product.displayPrice) every \(self.period(period))"
    }

    /// What one offer costs and for how long, followed by the regular price.
    ///
    /// - "3 days free, then $39.99/year"
    /// - "$1.99/month for 3 months, then $4.99/month"
    /// - "$0.99 for the first month, then $4.99/month"
    /// - "$9.99 for the first 3 months, then $4.99/month"
    static func describe(_ offer: SubscriptionOffer, then product: StoreProduct) -> String {
        "\(summary(of: offer)), then \(price(of: product))"
    }

    /// The offer on its own, for a badge: "3 days free", "$1.99/month for 3 months".
    static func summary(of offer: SubscriptionOffer) -> String {
        // `periodCount` periods of `period` each: a 1-week trial is one period of one week,
        // "$1.99/month for 3 months" is three periods of one month.
        let total = duration(offer.period.value * offer.periodCount, offer.period.unit)

        switch offer.paymentMode {
        case .freeTrial:
            return "\(total) free"
        case .payAsYouGo where offer.periodCount == 1:
            // "$0.99 for the first month" reads better than "$0.99/month for 1 month".
            return "\(offer.displayPrice) for the first \(period(offer.period))"
        case .payAsYouGo:
            return "\(offer.displayPrice)/\(period(offer.period)) for \(total)"
        case .payUpFront:
            return "\(offer.displayPrice) for the first \(total)"
        default:
            // `PaymentMode` is extensible; never show a price we cannot explain.
            return "\(offer.displayPrice) for \(total)"
        }
    }

    /// "7 days", "1 month", or with `singularDropsCount` just "month".
    private static func duration(
        _ count: Int,
        _ unit: StoreSubscriptionPeriod.Unit,
        singularDropsCount: Bool = false
    ) -> String {
        let word = switch unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        }
        if count == 1 {
            return singularDropsCount ? word : "1 \(word)"
        }
        return "\(count) \(word)s"
    }
}
