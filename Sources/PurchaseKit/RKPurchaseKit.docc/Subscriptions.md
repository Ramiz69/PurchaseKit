# Subscriptions

Read renewal state, react to billing problems, and sell introductory, promotional and
win-back offers.

## Overview

An entitlement check answers one question: may the customer use the feature right now? A
subscription app usually needs more - whether the subscription will renew, whether a payment
is failing, which offer this customer may see. ``StoreSubscriptionStatus``, ``SubscriptionOffer``
and ``PurchaseOptions`` cover that ground.

The examples use one subscription group:

```swift
let groupID = "com.myapp.subscriptions.premium"
```

The group ID is configured in App Store Connect and available as
``StoreProduct/subscriptionGroupID``.

## Read the subscription status

``PurchasesProtocol/subscriptionStatus(inGroup:)`` returns the status that matters most for a
group, or `nil` when the customer has never subscribed to it:

```swift
let status = try await PurchasesManager.shared.subscriptionStatus(inGroup: groupID)

if let status {
    print(status.state.rawValue, status.isActive)
    print("Renews:", status.willAutoRenew, "on", status.renewalDate ?? .distantPast)
    print("Into:", status.autoRenewProductID ?? "-")
}
```

``StoreSubscriptionStatus/isActive`` follows the App Store's rule for access: subscribed or in a
grace period. ``StoreSubscriptionStatus/transaction`` is the latest transaction behind the status,
so its ``StoreTransaction/expirationDate`` and ``StoreTransaction/offer`` describe the current
period.

When ``StoreSubscriptionStatus/autoRenewProductID`` differs from the transaction's
``StoreTransaction/productID``, the customer has scheduled an upgrade, downgrade or
crossgrade that takes effect at the next renewal.

With Family Sharing a customer can hold more than one status in a group. Read them all with
``PurchasesManager/subscriptionStatuses(inGroup:)``.

## Show billing problems

When a renewal payment fails, the App Store retries it for up to 60 days. If you enabled
Billing Grace Period in App Store Connect, the customer keeps access for the first part of
that window.

```swift
switch status.state {
case .inGracePeriod:
    // Still has access. Ask them to fix the payment method before it ends.
    showBanner("Update your payment method to keep Premium",
               until: status.gracePeriodExpirationDate)
case .inBillingRetryPeriod:
    // Access is gone, but the subscription can still recover.
    showBanner("Your payment did not go through")
default:
    break
}
```

On iOS and visionOS, send the customer to the system's subscription screen with the manager's
`showManageSubscriptions(in:groupID:)`, passing the window scene that presents it.

``StoreSubscriptionStatus/expirationReason`` says why an expired subscription ended - turned off
by the customer, a billing error, a declined price increase, or a product no longer sold - so
the win-back message can match the reason.

## Check introductory-offer eligibility

``StoreProduct/introductoryOffer`` describes the trial or intro price that is configured; it
does not say whether this customer may have it. A customer who has already redeemed an
introductory offer in the group is not eligible again:

```swift
let eligible = await PurchasesManager.shared.isEligibleForIntroOffer(inGroup: groupID)

if eligible, let intro = product.introductoryOffer, intro.paymentMode == .freeTrial {
    buyButton.title = "Start free trial"
} else {
    buyButton.title = "Subscribe for \(product.displayPrice)"
}
```

If your server decides eligibility itself - for example, one trial per account across
devices and Apple IDs - it can sign that decision. Pass the signed value in
``PurchaseOptions/introductoryOfferEligibilityJWS`` and the App Store applies it instead of its
own check.

## Sell a promotional offer

Promotional offers are for existing or lapsed subscribers, and each purchase needs a signature
that only your server can produce. The app never holds the In-App Purchase key:

1. The app asks your server for a signature for the offer it wants to present, sending
   ``SubscriptionOffer/id`` and the product ID.
2. The server checks the customer may have the offer and signs a compact JWS with your
   In-App Purchase key, using the App Store Server Library.
3. The app passes the JWS in ``PurchaseOptions/promotionalOffer``.

```swift
guard let offer = product.promotionalOffers.first, let offerID = offer.id else { return }

let jws = try await api.signPromotionalOffer(offerID: offerID, productID: product.productID)
let options = PurchaseOptions(
    appAccountToken: user.id,
    promotionalOffer: PurchaseOptions.PromotionalOffer(offerID: offerID, compactJWS: jws)
)
let (_, transaction) = try await PurchasesManager.shared
    .purchase(productID: product.productID, options: options)
```

A rejected offer throws ``PurchasesError/ineligibleForOffer`` or ``PurchasesError/invalidOffer``.

## Win back lapsed subscribers

Win-back offers are configured in App Store Connect for customers whose subscription has
ended. StoreKit decides eligibility itself, and ``StoreProduct/winBackOffers`` lists only the
offers this customer can redeem right now. Unlike promotional offers, they need no signature:

```swift
let product = try await PurchasesManager.shared
    .requestProducts(includingCache: false)
    .first { $0.productID == "com.myapp.sub.premium.monthly" }

if let product, let offer = product.winBackOffers.first, let offerID = offer.id {
    let options = PurchaseOptions(winBackOfferID: offerID)
    _ = try await PurchasesManager.shared.purchase(productID: product.productID, options: options)
}
```

Fetch with `includingCache: false` before showing a win-back screen: eligibility is evaluated
when StoreKit returns the product, and a cached product can be stale. An ID the product does
not offer throws ``PurchasesError/offerNotFound(_:)`` before the purchase sheet appears.

## Observe status changes

Renewals, expirations, billing failures and plan changes happen while the app is not running
a purchase. ``PurchasesManager/subscriptionStatusUpdates`` delivers each new status:

```swift
Task {
    for await status in PurchasesManager.shared.subscriptionStatusUpdates {
        await MainActor.run { model.apply(status) }
    }
}
```

Like ``PurchasesManager/purchasedProducts``, every access returns a fresh stream and events
are not replayed, so read the current state with
``PurchasesProtocol/subscriptionStatus(inGroup:)`` when a subscriber starts.

## Verify on your server

Decisions with money attached belong on a server. ``StoreSubscriptionStatus/renewalInfoJWS`` and
``StoreTransaction/jwsRepresentation`` are the App Store's signed forms; send those rather
than the decoded fields, which only say what the device read.
