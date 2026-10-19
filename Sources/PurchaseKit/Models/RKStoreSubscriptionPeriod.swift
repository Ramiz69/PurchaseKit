//
//  RKStoreSubscriptionPeriod.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 19.10.2026.
//

import StoreKit

/// A length of time a subscription or an offer runs for, such as "1 month" or "3 days".
///
/// Mirrors `Product.SubscriptionPeriod`, which has no public initializer and so cannot appear
/// in a test, a preview or a mock product.
public struct StoreSubscriptionPeriod: Hashable, Sendable {

    /// The calendar unit of a period.
    ///
    /// An enum, unlike the open-ended kinds elsewhere in the kit: days, weeks, months and years
    /// are not going to grow a fifth member, and an exhaustive `switch` is what formatting
    /// code wants.
    public enum Unit: Hashable, Sendable {
        case day
        case week
        case month
        case year
    }

    // MARK: Properties
    /// How many ``unit``s the period spans.
    public let value: Int
    /// The calendar unit ``value`` counts.
    public let unit: Unit

    // MARK: Initial methods

    /// Creates a period of `value` `unit`s.
    public init(value: Int, unit: Unit) {
        self.value = value
        self.unit = unit
    }

    /// Reads a StoreKit period. `nil` only if StoreKit reports a unit this build does not know.
    init?(_ period: Product.SubscriptionPeriod) {
        guard let unit = Unit(period.unit) else {
            return nil
        }

        self.init(value: period.value, unit: unit)
    }
}

extension StoreSubscriptionPeriod.Unit {
    /// Maps StoreKit's unit.
    ///
    /// Failable because `Product.SubscriptionPeriod.Unit` is non-frozen: there is no honest
    /// stand-in for a unit that does not exist yet, and guessing would misstate a price.
    init?(_ unit: Product.SubscriptionPeriod.Unit) {
        switch unit {
        case .day:
            self = .day
        case .week:
            self = .week
        case .month:
            self = .month
        case .year:
            self = .year
        @unknown default:
            return nil
        }
    }
}
