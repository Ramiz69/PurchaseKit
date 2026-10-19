//
//  RKProductType.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit

/// The kind of an App Store product, mirroring `StoreKit.Product.ProductType`.
///
/// A raw-value struct rather than an enum, the same pattern StoreKit uses. Up to 4.0 this was
/// an enum, and every kind StoreKit added — as the OS 27 SDKs did with subscription bundles
/// and suites — was a breaking change for every client with an exhaustive `switch`. As a
/// struct, a kind Apple adds later simply arrives with its own ``rawValue``, and adding a
/// constant for it here is not a breaking change. The cost is that a `switch` over it needs
/// a `default` branch.
///
/// The raw values are StoreKit's own, read from the framework at runtime, so a kind this
/// build has no constant for reads exactly as StoreKit reported it — instead of being
/// collapsed into a guess.
/// - See <doc:ProductType>
public struct ProductType: RawRepresentable, Hashable, Sendable {
    /// StoreKit's raw value for the kind, for example `"Consumable"`.
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// A product bought once that stays owned, such as a premium unlock.
    public static let nonConsumable = ProductType(rawValue: "Non-Consumable")
    /// A product that is used up and can be bought again, such as in-game currency.
    public static let consumable = ProductType(rawValue: "Consumable")
    /// A subscription for a fixed period that does not renew on its own.
    public static let nonRenewable = ProductType(rawValue: "Non-Renewing Subscription")
    /// A subscription that renews automatically until the customer cancels it.
    public static let autoRenewable = ProductType(rawValue: "Auto-Renewable Subscription")
    /// An auto-renewable subscription that bundles subscriptions from several groups.
    ///
    /// Introduced in the OS 27 SDKs. Spelled as a raw value so the package still builds with
    /// the OS 26 SDKs, where the StoreKit constant does not exist.
    public static let subscriptionBundle = ProductType(rawValue: "Subscription Bundle")
    /// An auto-renewable subscription that unlocks a suite of subscriptions.
    ///
    /// Introduced in the OS 27 SDKs; spelled as a raw value for the same reason as
    /// ``subscriptionBundle``.
    public static let subscriptionSuite = ProductType(rawValue: "Subscription Suite")

    /// Whether the product renews automatically and therefore has a subscription status.
    ///
    /// Bundles and suites renew like any other subscription, so code that asks "is this a
    /// subscription?" by comparing with ``autoRenewable`` alone silently skips them. Ask this
    /// instead.
    ///
    /// A kind this build has no constant for answers `false`: the kit cannot know that it
    /// renews, and claiming it does would report a subscription status that may not exist.
    public var isAutoRenewableSubscription: Bool {
        self == .autoRenewable || self == .subscriptionBundle || self == .subscriptionSuite
    }

    /// Maps StoreKit's value by passing its raw value through.
    ///
    /// Goes through the string rather than the StoreKit constants because the bundle and suite
    /// constants only exist in the OS 27 SDKs, which CI does not build with — and because a
    /// kind newer than this build then arrives as itself rather than as a wrong guess.
    init(_ productType: Product.ProductType) {
        self.init(rawValue: productType.rawValue)
    }
}
