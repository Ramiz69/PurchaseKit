# ``PurchasesManager``

The central `actor` that drives all StoreKit 2 operations.

It handles product fetching, purchases, restoration, entitlement evaluation, subscription
status and continuous transaction updates. Being an `actor`, it is safe to use from concurrent
contexts (Swift Concurrency).

## Overview

Every purchase goes through one path, ``purchase(productID:options:)``. The shorter calls you
already know - `purchase(productID:)` and `purchase(productID:appAccountToken:)` - are
conveniences on ``PurchasesProtocol`` and ``ServerVerifiedPurchasesProtocol`` that forward to
it, so they cannot drift apart from the options-based call.

Every throwing method throws ``PurchasesError``; StoreKit's own errors are translated into
its cases.

On iOS and visionOS the manager also wraps StoreKit's scene-based sheets. They run on the
main actor and take the `UIWindowScene` that presents them:

- `showManageSubscriptions(in:groupID:)` – the system's manage-subscriptions sheet,
  optionally focused on one subscription group.
- `beginRefundRequest(for:in:)` – the refund sheet for a transaction ID; returns a
  ``RefundRequestStatus``.
- `presentOfferCodeRedeemSheet(in:)` – the sheet for redeeming an offer code.

## Topics

### Configuration
- ``configure(identifiers:finishing:)``
- ``finishPolicy``
- ``shared``
- ``resolved()``

### Products
- ``requestProducts(includingCache:)``
- ``unavailableProductIDs``
- ``currentStorefrontCountryCode()``

### Purchasing
- ``purchase(productID:options:)``
- ``restore()``

### Server-verified purchases
- ``finish(_:)``
- ``unfinishedTransactions()``
- ``transactionUpdates``

### Entitlements & Subscriptions
- ``hasEntitlement(for:)``
- ``entitlementProductIDs()``
- ``activeSubscriptions()``
- ``activeSubscription(inGroup:)``

### Subscription status
- ``subscriptionStatuses(inGroup:)``
- ``isEligibleForIntroOffer(inGroup:)``
- ``subscriptionStatusUpdates``

### App purchase
- ``appPurchaseInfo()``

### Events
- ``purchasedProducts``

## Usage

```swift
// Configure once at app launch
let purchases = PurchasesManager.configure(identifiers: [
    "com.myapp.sub.premium.monthly",
    "com.myapp.sub.premium.yearly",
    "com.myapp.tip.small"
])

// Check entitlement
let hasPro = await purchases.hasEntitlement(for: "com.myapp.sub.premium.yearly")

// List active subscriptions (bundles and suites included)
let active = await purchases.activeSubscriptions()

// Pick the active subscription in a group
let best = await purchases.activeSubscription(inGroup: "com.myapp.subscriptions.premium")

// Read the renewal state of that group
if let status = try await purchases.subscriptionStatus(inGroup: "com.myapp.subscriptions.premium"),
   status.state == .inBillingRetryPeriod {
    showUpdatePaymentBanner()
}

// Configured identifiers StoreKit did not return - usually a typo or a product
// that is not "Ready to Submit" in App Store Connect
let missing = await purchases.unavailableProductIDs
```

See <doc:Subscriptions> for status, offers and intro-offer eligibility.
