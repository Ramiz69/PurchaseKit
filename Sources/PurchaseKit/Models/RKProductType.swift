//
//  RKProductType.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit

/// Maps `StoreKit.Product.ProductType` into an SDK-level enum.
///
/// This stays an enum, unlike the open-ended kinds introduced in 4.0, because callers switch
/// over it to decide what a purchase grants. The price is that a StoreKit release adding a kind
/// is a breaking change here too, which is why 4.0 adds ``subscriptionBundle`` and
/// ``subscriptionSuite``; ``unknown`` absorbs anything newer than this build.
/// - See <doc:ProductType>
public enum ProductType: Sendable {
    case nonConsumable
    case consumable
    case nonRenewable
    case autoRenewable
    /// An auto-renewable subscription that bundles subscriptions from several groups.
    ///
    /// Introduced in the OS 27 SDKs. Recognised by its raw value so the package still builds
    /// with the OS 26 SDKs, where the StoreKit constant does not exist.
    case subscriptionBundle
    /// An auto-renewable subscription that unlocks a suite of subscriptions.
    ///
    /// Introduced in the OS 27 SDKs; recognised by raw value for the same reason as
    /// ``subscriptionBundle``.
    case subscriptionSuite
    /// A `StoreKit.Product.ProductType` this SDK does not know.
    ///
    /// `Product.ProductType` is a non-frozen raw-value type, so a StoreKit release can add a
    /// kind that predates the SDK build. Such a product used to arrive as `nonConsumable`,
    /// which reads as a permanent one-off purchase — the wrong answer to act on, and silent
    /// about being a guess. Treat this case as "do not assume anything about entitlement".
    case unknown

    /// Whether the product renews automatically and therefore has a subscription status.
    ///
    /// Bundles and suites renew like any other subscription, so code that asks "is this a
    /// subscription?" by comparing with ``autoRenewable`` alone silently skips them. Ask this
    /// instead.
    public var isAutoRenewableSubscription: Bool {
        switch self {
        case .autoRenewable, .subscriptionBundle, .subscriptionSuite:
            true
        case .nonConsumable, .consumable, .nonRenewable, .unknown:
            false
        }
    }

    init(_ productType: Product.ProductType) {
        self.init(rawValue: productType.rawValue)
    }

    /// Maps StoreKit's raw value.
    ///
    /// Goes through the string rather than the StoreKit constants because the bundle and suite
    /// constants only exist in the OS 27 SDKs, which CI does not build with. The strings are
    /// StoreKit's own raw values, read from the framework at runtime.
    init(rawValue: String) {
        switch rawValue {
        case "Non-Consumable":
            self = .nonConsumable
        case "Consumable":
            self = .consumable
        case "Non-Renewing Subscription":
            self = .nonRenewable
        case "Auto-Renewable Subscription":
            self = .autoRenewable
        case "Subscription Bundle":
            self = .subscriptionBundle
        case "Subscription Suite":
            self = .subscriptionSuite
        default:
            self = .unknown
        }
    }
}
