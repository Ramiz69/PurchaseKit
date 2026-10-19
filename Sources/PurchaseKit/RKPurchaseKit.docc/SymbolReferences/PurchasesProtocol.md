# ``PurchasesProtocol``

An abstraction that lets you swap ``PurchasesManager`` for a mock implementation in unit tests or previews.

The protocol mirrors the public surface of the manager and adds high-level helpers for entitlements and subscriptions.

## Overview

A conforming type implements the requirements; everything listed under
*Conveniences* is provided by an extension and forwards to a requirement. In particular,
`purchase(productID:)` is not a requirement: it calls
``purchase(productID:options:)`` with ``PurchaseOptions/none``. A mock implements the
options-based call and gets the short one for free.

```swift
struct PurchasesMock: PurchasesProtocol {
    func requestProducts(includingCache: Bool) async throws -> [StoreProduct] { [] }
    func purchase(
        productID: String,
        options: PurchaseOptions
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
        throw PurchasesError.purchaseCancelled
    }
    func restore() async throws { }
    func hasEntitlement(for productID: String) async -> Bool { productID == "com.myapp.pro" }
    func entitlementProductIDs() async -> Set<String> { ["com.myapp.pro"] }
    func activeSubscriptions() async -> [StoreProduct] { [] }
    func activeSubscription(inGroup groupID: String) async -> StoreProduct? { nil }
    func subscriptionStatuses(inGroup groupID: String) async throws -> [StoreSubscriptionStatus] { [] }
    func isEligibleForIntroOffer(inGroup groupID: String) async -> Bool { true }
    func appPurchaseInfo() async throws -> AppPurchaseInfo { throw PurchasesError.unsupported }
}
```

> Important: Do not keep a `purchase(productID:)` of your own in a conformer. It no longer
> satisfies a requirement, so a call made through `any PurchasesProtocol` skips it and runs
> the extension, which calls your ``purchase(productID:options:)``.

On visionOS the purchase requirement is `purchase(productID:options:confirmIn:)`, which takes
the `UIScene` that presents the App Store confirmation, and the convenience is
`purchase(productID:confirmIn:)`.

## Topics

### Core Methods
- ``requestProducts(includingCache:)``
- ``purchase(productID:options:)``
- ``restore()``

### Entitlements & Subscriptions
- ``hasEntitlement(for:)``
- ``entitlementProductIDs()``
- ``activeSubscriptions()``
- ``activeSubscription(inGroup:)``

### Subscription status
- ``subscriptionStatuses(inGroup:)``
- ``isEligibleForIntroOffer(inGroup:)``

### App purchase
- ``appPurchaseInfo()``

### Conveniences
- ``requestProducts()``
- ``purchase(productID:)``
- ``subscriptionStatus(inGroup:)``
