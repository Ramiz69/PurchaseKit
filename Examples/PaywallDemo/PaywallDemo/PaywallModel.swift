//
//  PaywallModel.swift
//  PaywallDemo
//

import Foundation
import Observation
import RKPurchaseKit
import UIKit

/// The paywall's state and the calls that change it.
///
/// The model talks to `any PurchasesBackend`, never to `PurchasesManager.shared` directly, so
/// the exact same code path runs against StoreKit, against `DemoPurchases`, and in previews.
@MainActor
@Observable
final class PaywallModel {
    enum Phase: Equatable {
        case loading
        case loaded
        /// StoreKit returned no products. When run outside Xcode's Run action, the StoreKit
        /// configuration file is not applied and this is what the customer would see.
        case empty
        case failed(String)
    }

    /// A message that stays on screen, as opposed to an error alert.
    struct Notice: Equatable {
        var symbol: String
        var title: String
        var message: String
    }

    let backend: any PurchasesBackend

    private(set) var phase: Phase = .loading
    private(set) var plans: [StoreProduct] = []
    private(set) var extras: [StoreProduct] = []
    private(set) var status: StoreSubscriptionStatus?
    private(set) var entitledProductIDs: Set<String> = []
    private(set) var isEligibleForIntroOffer = false
    /// The product a purchase is running for, so only its button shows progress.
    private(set) var purchasingProductID: String?
    private(set) var isRestoring = false
    private(set) var coinBalance = 0

    var selectedPlanID: String?
    var notice: Notice?
    var errorMessage: String?
    /// Passed to every purchase as `PurchaseOptions.simulatesAskToBuyInSandbox`.
    var simulatesAskToBuy = false

    init(backend: any PurchasesBackend) {
        self.backend = backend
    }

    // MARK: Derived state

    /// The subscription group, read from the products rather than hard-coded: the group ID
    /// differs between the `.storekit` file, the sandbox and production.
    var groupID: String? { plans.first?.subscriptionGroupID }

    /// The plan the current status belongs to, for its offers and its name.
    var statusPlan: StoreProduct? {
        guard let status else { return nil }
        return plans.first { $0.productID == status.transaction.productID }
    }

    var banner: SubscriptionBanner? { SubscriptionBanner(status: status, plan: statusPlan) }

    /// Premium access: an active subscription, which includes a grace period, or the
    /// lifetime unlock.
    var hasPremium: Bool {
        (status?.isActive ?? false) || entitledProductIDs.contains(Catalog.lifetime)
    }

    /// Whether `product` is the plan the customer currently pays for.
    func isCurrentPlan(_ product: StoreProduct) -> Bool {
        guard let status, status.isActive else { return false }
        return status.transaction.productID == product.productID
    }

    /// The introductory offer to advertise, or `nil` when this customer may not have one.
    ///
    /// `StoreProduct.introductoryOffer` says what is configured; only
    /// `isEligibleForIntroOffer(inGroup:)` says whether *this* customer gets it. Advertising
    /// a trial to someone who already used one is a broken promise at the payment sheet.
    func introOffer(for product: StoreProduct) -> SubscriptionOffer? {
        isEligibleForIntroOffer ? product.introductoryOffer : nil
    }

    // MARK: Loading

    /// Loads everything, then keeps the screen in sync until the task is cancelled.
    ///
    /// Run it from `.task`: SwiftUI cancels it when the view goes away, which ends the
    /// `for await` loops and drops the streams.
    func run() async {
        await load()
        await observeChanges()
    }

    func load() async {
        do {
            // `includingCache: false` asks StoreKit again instead of answering from the
            // cache: win-back eligibility is decided when StoreKit returns the product.
            let products = try await backend.requestProducts(includingCache: false)
            plans = products.filter { $0.type.isAutoRenewableSubscription }
            extras = products.filter { !$0.type.isAutoRenewableSubscription }
            phase = products.isEmpty ? .empty : .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
        await refreshStatus()
        if selectedPlanID == nil {
            // A returning customer sees the plan they had. A new one sees the plan with a
            // free trial, usually the one worth recommending.
            selectedPlanID = (statusPlan ?? plans.first { introOffer(for: $0) != nil } ?? plans.first)?.productID
        }
    }

    /// Re-reads entitlements and the group's status. Cheap enough to call after any event.
    func refreshStatus() async {
        entitledProductIDs = await backend.entitlementProductIDs()
        guard let groupID else {
            status = nil
            return
        }
        // `subscriptionStatus(inGroup:)` picks the status that matters most when Family
        // Sharing gives the customer more than one.
        status = try? await backend.subscriptionStatus(inGroup: groupID)
        isEligibleForIntroOffer = await backend.isEligibleForIntroOffer(inGroup: groupID)
    }

    private func observeChanges() async {
        // Both loops run until `run()` is cancelled.
        async let statuses: Void = observeStatusUpdates()
        async let purchases: Void = observePurchasedProducts()
        _ = await (statuses, purchases)
    }

    /// Renewals, billing failures, recoveries and refunds happen while the app is open,
    /// often without any purchase. Each one arrives here.
    private func observeStatusUpdates() async {
        for await _ in backend.subscriptionStatusUpdates {
            // The update carries one status; re-reading picks the best of the group's.
            await refreshStatus()
        }
    }

    /// Purchases that complete outside a `purchase` call: Ask to Buy approvals, restores,
    /// purchases made on another device.
    private func observePurchasedProducts() async {
        for await _ in backend.purchasedProducts {
            notice = nil
            await load()
        }
    }

    // MARK: Purchasing

    func purchase(_ product: StoreProduct, offer: PurchaseOptions? = nil) async {
        guard purchasingProductID == nil else { return }
        purchasingProductID = product.productID
        defer { purchasingProductID = nil }

        var options = offer ?? .none
        options.simulatesAskToBuyInSandbox = simulatesAskToBuy
        do {
            let (purchased, _) = try await backend.purchase(productID: product.productID, options: options)
            notice = nil
            if purchased.type == .consumable {
                // A real app credits consumables on its server, keyed by the transaction.
                coinBalance += Catalog.coinsPerPurchase
            }
            await load()
        } catch PurchasesError.purchaseCancelled {
            // The customer closed the payment sheet. That is a decision, not an error:
            // no alert, no log noise, the paywall simply stays as it was.
        } catch PurchasesError.purchasePending {
            // Ask to Buy, or a payment that needs extra approval. The purchase is not lost:
            // it arrives on `purchasedProducts` once approved, and `observeChanges` reloads.
            notice = Notice(
                symbol: "hourglass",
                title: "Waiting for approval",
                message: "\(product.displayName) will unlock as soon as the purchase is approved. You can keep using the app."
            )
        } catch {
            // `PurchasesError` is a `LocalizedError`, so its description is ready to show.
            errorMessage = error.localizedDescription
        }
    }

    /// Buys a plan with a win-back offer. No signature needed: StoreKit decides eligibility.
    func redeemWinBack(offerID: String) async {
        guard let plan = statusPlan else { return }
        await purchase(plan, offer: PurchaseOptions(winBackOfferID: offerID))
    }

    /// Buys a plan with a promotional offer.
    ///
    /// Promotional offers must be signed with your In-App Purchase key, which never ships in
    /// the app. The app asks its server for a compact JWS and passes it on.
    func redeemPromotionalOffer(offerID: String) async {
        guard let plan = statusPlan else { return }
        do {
            let jws = try await PromotionalOfferSigner.signature(
                offerID: offerID,
                productID: plan.productID,
                isDemo: backend is DemoPurchases
            )
            let offer = PurchaseOptions.PromotionalOffer(offerID: offerID, compactJWS: jws)
            await purchase(plan, offer: PurchaseOptions(promotionalOffer: offer))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            // `AppStore.sync()` under the hood: it may ask the customer to sign in, so only
            // call it from a button, never on launch.
            try await backend.restore()
            await load()
            notice = hasPremium ? nil : Notice(
                symbol: "magnifyingglass",
                title: "Nothing to restore",
                message: "No active purchases were found for this Apple Account."
            )
        } catch PurchasesError.purchaseCancelled {
            // The customer dismissed the sign-in prompt.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Opens Apple's subscription settings, where a failing payment method is fixed.
    func manageSubscription() async {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }
        do {
            try await backend.showManageSubscriptions(in: scene, groupID: groupID)
        } catch {
            errorMessage = error.localizedDescription
        }
        // The sheet is where problems get fixed; read the outcome when it closes.
        await refreshStatus()
    }
}

/// Where a real app would call its server.
enum PromotionalOfferSigner {
    struct NoServerError: LocalizedError {
        var errorDescription: String? {
            "Promotional offers need a signature from your server. Sign the offer there with your In-App Purchase key and pass the JWS in PurchaseOptions.promotionalOffer."
        }
    }

    static func signature(offerID: String, productID: String, isDemo: Bool) async throws -> String {
        // Demo mode accepts any value; real StoreKit verifies it.
        guard isDemo else { throw NoServerError() }
        return "demo.signature"
    }
}
