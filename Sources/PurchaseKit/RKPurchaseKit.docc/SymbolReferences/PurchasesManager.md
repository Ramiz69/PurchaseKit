# ``PurchasesManager``

The central `actor` that drives all StoreKit 2 operations.

It handles product fetching, purchases, restoration, entitlement evaluation, and continuous transaction updates. Being an `actor`, it is safe to use from concurrent contexts (Swift Concurrency).

## Topics

### Configuration
- ``configure(identifiers:)``
- ``shared``

### Operations
- ``requestProducts(includingCache:)``
- ``purchase(productID:)``
- ``restore()``

### Entitlements & Subscriptions
- ``hasEntitlement(for:)``
- ``entitlementProductIDs()``
- ``activeSubscriptions()``
- ``activeSubscription(inGroup:)``

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

// List active subscriptions
let active = await purchases.activeSubscriptions()

// Pick the active subscription in a group
let best = await purchases.activeSubscription(inGroup: "com.myapp.subscriptions.premium")
```
