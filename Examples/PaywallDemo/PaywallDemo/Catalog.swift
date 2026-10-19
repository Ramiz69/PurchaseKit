//
//  Catalog.swift
//  PaywallDemo
//

/// The product identifiers this app sells.
///
/// They match `PaywallDemo.storekit`, which the `PaywallDemo` scheme loads on Run, and they
/// would match App Store Connect in a shipping app. Keeping them in one place means a typo
/// fails to compile instead of silently producing a paywall that is one row short.
enum Catalog {
    static let premiumMonthly = "dev.purchasekit.premium.monthly"
    static let premiumYearly = "dev.purchasekit.premium.yearly"
    static let coins = "dev.purchasekit.coins.100"
    static let lifetime = "dev.purchasekit.lifetime"

    /// Everything handed to `PurchasesManager.configure(identifiers:)`, in display order.
    static let all = [premiumYearly, premiumMonthly, lifetime, coins]

    /// How many coins one `coins` purchase credits.
    static let coinsPerPurchase = 100
}
