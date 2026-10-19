//
//  PurchasesBackend.swift
//  PaywallDemo
//

import RKPurchaseKit
import UIKit

/// Everything the paywall needs from the store, as a protocol the screen can be handed.
///
/// `PurchasesProtocol` already covers products, purchases, entitlements and subscription
/// status. The paywall also wants to *react* when those change while it is on screen, and to
/// send the customer to Apple's subscription settings. Those live on `PurchasesManager` itself
/// rather than on the kit's protocol, so this app adds them in a small refinement of its own.
///
/// Depending on a protocol instead of on `PurchasesManager.shared` is what lets the same
/// screen run against real StoreKit, against `DemoPurchases` in demo mode, and inside
/// SwiftUI previews.
protocol PurchasesBackend: PurchasesProtocol {
    /// A fresh stream of products that became entitled (purchases, restores, Ask to Buy
    /// approvals, purchases made on another device).
    var purchasedProducts: AsyncStream<PurchasedProductEvent> { get }

    /// A fresh stream of renewal statuses: renewals, expirations, billing failures, refunds.
    var subscriptionStatusUpdates: AsyncStream<StoreSubscriptionStatus> { get }

    /// Shows the system's manage-subscriptions sheet, where the customer can fix a payment
    /// method, change plan or cancel.
    @MainActor
    func showManageSubscriptions(in scene: UIWindowScene, groupID: String?) async throws
}

/// The real thing. `PurchasesManager` already has every member above with these exact
/// signatures, so the conformance is empty.
extension PurchasesManager: PurchasesBackend {}
