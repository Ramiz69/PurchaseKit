# ``RKPurchaseKit``

@Metadata {
    @DisplayName("PurchaseKit")
    @SupportedLanguage(swift)
    @Available(iOS, introduced: "26.0")
    @Available(tvOS, introduced: "26.0")
    @Available(macOS, introduced: "26.0")
    @Available(macCatalyst, introduced: "26.0")
    @Available(watchOS, introduced: "26.0")
    @Available(visionOS, introduced: "26.0")
    @PageColor(green)
}

`RKPurchaseKit` is a lightweight, actor-based convenience layer on top of **StoreKit 2**.

@Links(visualStyle: detailedGrid) {
    - <doc:GettingStarted>
    - <doc:Subscriptions>
    - <doc:MigratingTo4>
}

## Features

- Actor-based, Swift Concurrency–first API
- Product caching with instant repeat calls
- Purchase & restore flows with typed errors - StoreKit's own errors arrive as ``PurchasesError`` cases
- **Purchase options**: account token, quantity, promotional and win-back offers - ``PurchaseOptions``
- Live transaction listening via `AsyncStream`
- **Entitlement helpers**:
  - ``PurchasesManager/hasEntitlement(for:)``
  - ``PurchasesManager/entitlementProductIDs()``
  - ``PurchasesManager/activeSubscriptions()``
  - ``PurchasesManager/activeSubscription(inGroup:)``
- **Subscription status**: renewal info, grace period and billing retry, intro-offer
  eligibility and live status updates - ``StoreSubscriptionStatus``,
  ``PurchasesManager/subscriptionStatusUpdates``
- Simple value model: ``StoreProduct`` (with ``StoreProduct/subscriptionGroupID``, price
  currency, subscription period and ``SubscriptionOffer``s) and ``StoreTransaction``
- **Server-verified consumables**: buy with an `appAccountToken`, send
  ``StoreTransaction/jwsRepresentation`` to your server and finish only after it accepts -
  ``FinishPolicy/manual``, ``ServerVerifiedPurchasesProtocol``
- App purchase info from `AppTransaction` - ``AppPurchaseInfo``
- Mockable through ``PurchasesProtocol``: every model has a public initializer

## Requirements

- iOS 26 / iPadOS 26 / Mac Catalyst 26 / macOS 26 / tvOS 26 / watchOS 26 / visionOS 26
- Swift 6.2 tools or later (Xcode 26), StoreKit 2
- Some fields need a newer OS at run time and are `nil` before it:
  ``StoreTransaction/revocationType`` and ``StoreTransaction/billingPlanType`` (26.4)

## Notes

- Entitlement state is derived from `Transaction.currentEntitlements` and reflected in ``StoreProduct/isPurchased``.
- The manager refreshes entitlements after fetching products and after ``PurchasesManager/restore()``.
- When you update UI from callbacks or streams, hop to `MainActor`.
- Upgrading from 3.x? Start with <doc:MigratingTo4>.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Subscriptions>
- <doc:MigratingTo4>

### Purchasing

- ``PurchasesManager``
- ``PurchasesProtocol``
- ``ServerVerifiedPurchasesProtocol``
- ``PurchaseOptions``
- ``FinishPolicy``
- ``PurchasesError``

### Products and transactions

- ``StoreProduct``
- ``ProductType``
- ``StoreTransaction``
- ``StoreEnvironment``
- ``PurchasedProductEvent``
- ``AppPurchaseInfo``
- ``RefundRequestStatus``

### Subscriptions

- ``StoreSubscriptionStatus``
- ``SubscriptionOffer``
- ``StoreSubscriptionPeriod``
